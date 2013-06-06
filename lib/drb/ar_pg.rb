require 'drb/drb'
require 'stringio'

module DRb

  # Implements DRb over an ActiveRecord connection to a PostgreSQL server
  #
  # DRb PostgreSQL socket URIs look like <code>drbarpg:?<option></code>.  The
  # option is optional.

  class DRbArPg
    attr_reader :uri

    def self.open(uri, config)
      server_channel, = parse_uri(uri)

      self.new(uri, nil, server_channel, :master, config)
    end

    def self.open_server(uri, config)
      channel, = parse_uri(uri)
      self.new(uri, channel, nil, :server, config)
    end

    def accept
      @pgconn.wait_for_notify do |channel, pid, payload|
        return self.class.new(nil, nil, payload, :slave, @config)
      end
    end

    def self.uri_option(uri, config)
      channel, option = parse_uri(uri)
      return "drbarpg://#{channel}", option
    end

    def initialize(uri, listen_channel, notify_connection_id, act_as, config={})
      @notify_connection_id = notify_connection_id
      @config = config
      @msg = DRbMessage.new(@config)
      @conn = Drbarpg::Message.connection_pool.checkout
      @pgconn = @conn.raw_connection

      @listen_connection_id = @conn.exec_query("SELECT nextval('drbarpg_connections_id_seq') AS seq").first['seq']
      @listen_channel = if listen_channel.nil? || listen_channel.empty?
        @conn.quote_table_name("drbarpg__#{@listen_connection_id}")
      else
        @conn.quote_table_name("drbarpg_#{listen_channel}")
      end

      @conn.execute("LISTEN #{@listen_channel}");

      case act_as
      when :server
        # Save the connection to the database to ensure that only one server can listen
        # on a given channel.
        @conn.exec_insert('INSERT INTO drbarpg_connections (id, listen_channel)
                          VALUES ($1::int, $2::text)', nil,
                          [[nil, @listen_connection_id], [nil, @listen_channel]])

        uri_channel, uri_option = self.class.parse_uri(uri) if uri
        uri = "drbarpg://_#{@listen_connection_id}?#{uri_option}" if uri_channel.nil? || uri_channel.empty?
        @uri = uri
      when :master
        # connect to server channel
        @conn.exec_update("NOTIFY #{@conn.quote_table_name("drbarpg_#{@notify_connection_id}")}, #{@conn.quote(@listen_connection_id)}");
        # wait for acknowledgement with peer channel
        @pgconn.wait_for_notify do |channel, pid, payload|
          @notify_connection_id = payload
          @notify_channel = @conn.quote_table_name("drbarpg__#{@notify_connection_id}")
        end
      when :slave
        @notify_channel = @conn.quote_table_name("drbarpg__#{@notify_connection_id}")
        # acknowledge with peer channel
        @conn.exec_update("NOTIFY #{@notify_channel}, #{@conn.quote(@listen_connection_id)}");
      end
    end

    def close
      if @conn
        if @notify_channel
          @conn.exec_update("NOTIFY #{@notify_channel}, 'c'");
        end
        @conn.execute("UNLISTEN #{@listen_channel}");
        @conn.exec_delete('DELETE FROM drbarpg_connections WHERE id=$1::int', nil, [[nil, @listen_connection_id]])
        Drbarpg::Message.connection_pool.checkin(@conn)
        @conn = @pgconn = nil
      end
    end

    def alive?
      @pgconn.consume_input
      if (n=@pgconn.notifies)
        if n[:extra] == 'c'
          close
        else
          raise DRbConnError, "received unexpected notification"
        end
      end
      !!@conn
    end

    def send_request(ref, msg_id, *arg, &b)
      stream = StringIO.new
      @msg.send_request(stream, ref, msg_id, *arg, &b)
      send_message(stream.string)
    end

    def recv_reply
      stream = StringIO.new(wait_for_message)
      return @msg.recv_reply(stream)
    end

    def recv_request
      begin
        stream = StringIO.new(wait_for_message)
        return @msg.recv_request(stream)
      rescue
        close
        raise $!
      end
    end

    def send_reply(succ, result)
      begin
        stream = StringIO.new
        @msg.send_reply(stream, succ, result)
        send_message(stream.string)
      rescue
        close
        raise $!
      end
    end

    private
    def send_message(payload)
      payload_b64 = [payload].pack('m')
      if payload_b64.length >= 8000
        @conn.exec_insert('INSERT INTO drbarpg_messages (drbarpg_connection_id, payload)
                          VALUES ($1::int, $2::text)', nil, [[nil, @notify_connection_id], [nil, payload_b64]])
        @conn.exec_update("NOTIFY #{@notify_channel}");
      else
        @conn.exec_update("NOTIFY #{@notify_channel}, '#{payload_b64}'");
      end
    end

    def check_pending_message
      row = @conn.exec_query('SELECT id, payload FROM drbarpg_messages WHERE drbarpg_connection_id=$1::int LIMIT 1',
                        nil, [ [nil, @listen_connection_id] ]).first
      if row
        @conn.exec_delete('DELETE FROM drbarpg_messages WHERE id=$1::int', nil, [[nil, row['id']]])
        return row['payload'].unpack('m')[0]
      else
        raise DRbConnError, "no message received"
      end
    end

    def wait_for_message()
      @pgconn.wait_for_notify do |channel, pid, payload|
        if payload=='c'
          close
          return ''
        elsif payload
          return payload.unpack('m')[0]
        else
          return check_pending_message
        end
      end
    end

    def self.parse_uri(uri)
      if /^drbarpg:\/\/(.*?)(\?(.*))?$/ =~ uri
        channel = $1
        option = $3
        [channel, option]
      else
        raise(DRbBadScheme, uri) unless uri =~ /^drbarpg:/
        raise(DRbBadURI, 'can\'t parse uri:' + uri)
      end
    end
  end

  DRbProtocol.add_protocol(DRbArPg)
end
