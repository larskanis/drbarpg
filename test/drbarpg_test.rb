require 'test_helper'
require 'drb/ar_pg'
require 'logger'

class DrbarpgTest < ActiveSupport::TestCase
  test "allows two-way communication" do
    ActiveRecord::Base.logger = Logger.new STDERR

    DRb.start_service("drbarpg://twoway", Kernel)
    drb = DRbObject.new_with_uri("drbarpg://twoway")

#     DRb.start_service("druby://localhost:33333", Kernel)
#     drb = DRbObject.new_with_uri("druby://localhost:33333")

    remote_hash = drb.eval("@a = {}.extend(DRb::DRbUndumped)")

    # remote server gets started in main thread, with binding as front object.
    # server spawns thread to run in, and another thread to run client-connection in.
    # client connects, sends message,

    # Set local Proc in remote hash, re-fetch it and call it. Works without two-way comms
    remote_hash["a"] = lambda { return 1 }
    assert_equal 1, drb.eval("@a['a']").call

    # Call same Proc in a remote context. This means establishing a connection to the local side, since
    # the Proc is really a DRbObject on the remote side.
    assert_equal 1, drb.eval("@a['a'].call")

    DRb.stop_service
  end
end
