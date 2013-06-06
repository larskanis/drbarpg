require 'test_helper'
require 'drb/ar_pg'
require 'logger'
require 'rbconfig'

class DrbarpgTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = false

  attr_reader :drb

  UriServer = "drbarpg://server"
  UriCallback = "drbarpg://"
#   UriServer = "druby://localhost:33333"
#   UriCallback = nil

  def setup
#     ActiveRecord::Base.logger = Logger.new STDERR

    # Start forked server process
#     ActiveRecord::Base.connection_pool.disconnect!
#     rd, wr = IO.pipe
#     fork do
#       DRb.start_service(UriServer, Kernel)
#       wr.puts "started"
#       DRb.thread.join
#     end

    rd = IO.popen(RbConfig::CONFIG['ruby_install_name'], 'w+')
    rd.write <<-EOT
      $: << #{File.expand_path('..', __FILE__).inspect}
      require 'test_helper'
      require 'drb/ar_pg'

#       ActiveRecord::Base.logger = Logger.new $stderr
      DRb.start_service(#{UriServer.inspect}, Kernel)
      $stdout.puts "started"
      $stdout.flush
      $stdout.reopen($stderr)
      DRb.thread.join
    EOT
    rd.close_write

    # Start local server for callbacks
    DRb.start_service(UriCallback)

    # Wait until server process has started
    rd.gets

    # Connect to server object
    @drb = DRbObject.new_with_uri(UriServer)
  end

  def teardown
    drb.eval("DRb.stop_service")
    # Wait until server process has stopped
    Process.wait
    DRb.stop_service
  end

  test "allows two-way communication" do
    remote_hash = drb.eval("@a = {}.extend(DRb::DRbUndumped)")

    # Set local Proc in remote hash, re-fetch it and call it. Works without two-way comms
    remote_hash["a"] = lambda { return 1 }
    assert_equal 1, drb.eval("@a['a']").call

    # Call same Proc in a remote context. This means establishing a connection to the local side, since
    # the Proc is really a DRbObject on the remote side.
    assert_equal 1, drb.eval("@a['a'].call")
  end

  test "allows big params" do
    remote_hash = drb.eval("@a = {}.extend(DRb::DRbUndumped)")

    remote_hash["a"] = "b"*8000
    assert_equal "b"*8000, drb.eval("@a['a']")
  end

  test "runs reasonable fast" do
    2000.times do
      drb.rand
    end
  end
end
