require 'drb/drb'
require 'stringio'

module DRb

  # Implements DRb over an ActiveRecord connection to a PostgreSQL server
  #
  # DRb PostgreSQL socket URIs look like <code>drbarpg:?<option></code>.  The
  # option is optional.

  class DRbArPg
    attr_reader :uri

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

    def self.open(uri, config)
      server_channel, = parse_uri(uri)

      self.new(nil, nil, server_channel, :master, config)
    end

    def self.open_server(uri, config)
      channel, = parse_uri(uri)
      self.new(uri, channel, nil, :server, config)
    end

    def self.uri_option(uri, config)
      channel, option = parse_uri(uri)
      return "drbarpg://#{channel}", option
    end

    def initialize(uri, listen_channel, notify_channel, act_as, config={})
      @listen_channel = "drbarpg-#{listen_channel}"
      @notify_channel = notify_channel
      @config = config
      @msg = DRbMessage.new(@config)
      @conn = Drbarpg::Message.connection_pool.checkout
      @pgconn = @conn.raw_connection

      if @listen_channel == 'drbarpg-'
        seq = Drbarpg::Message.find_by_sql("SELECT nextval('drbarpg_connections_id_seq') AS seq").first['seq']
        @listen_channel = "drbarpg_#{seq}"
        @uri = 'drbarpg://' + @listen_channel
      end

      @conn.execute("LISTEN #{@conn.quote_table_name(@listen_channel)}");

      case act_as
      when :master
        # connect to server channel
        server_channel = "drbarpg-#{@notify_channel}"
        @conn.execute("NOTIFY #{@conn.quote_table_name(server_channel)}, '#{@listen_channel}'");
        # wait for acknowledgement with peer channel
        @pgconn.wait_for_notify do |channel, pid, payload|
          @notify_channel = payload
        end
      when :slave
        # acknowledge with peer channel
        @conn.execute("NOTIFY #{@conn.quote_table_name(@notify_channel)}, '#{@listen_channel}'");
      end
    end

    public
    def close
      @conn.execute("UNLISTEN #{@conn.quote_table_name(@listen_channel)}");
      Drbarpg::Message.connection_pool.checkin(@conn)
      @conn = @pgconn = nil
    end

    def accept
      puts "accept: wait for #{@listen_channel}"
      @pgconn.wait_for_notify do |channel, pid, payload|
        puts "accept #{channel} with payload #{payload}"
        return self.class.new(nil, nil, payload, :slave, @config)
      end
    end

    def alive?
      !!@conn
    end

    def send_request(ref, msg_id, *arg, &b)
      stream = StringIO.new
      @msg.send_request(stream, ref, msg_id, *arg, &b)

      @conn.execute("NOTIFY #{@conn.quote_table_name(@notify_channel)}, '#{[stream.string].pack('m')}'");
    end

    def recv_reply
      puts "recv_reply wait for #{@listen_channel}"
      @pgconn.wait_for_notify do |channel, pid, payload|
        puts "recv_reply #{channel}"
        stream = StringIO.new(payload.unpack('m')[0])
        return @msg.recv_reply(stream)
      end
    end

    def recv_request
      begin
        puts "recv_request wait for #{@listen_channel}"
        @pgconn.wait_for_notify do |channel, pid, payload|
          puts "recv_request #{channel}"
          stream = StringIO.new(payload.unpack('m')[0])
          return @msg.recv_request(stream)
        end
      rescue
        close
        raise $!
      end
    end

    def send_reply(succ, result)
      begin
        stream = StringIO.new
        @msg.send_reply(stream, succ, result)
        @conn.execute("NOTIFY #{@conn.quote_table_name(@notify_channel)}, '#{[stream.string].pack('m')}'");
      rescue
        close
        raise $!
      end
    end
  end

  DRbProtocol.add_protocol(DRbArPg)
end
