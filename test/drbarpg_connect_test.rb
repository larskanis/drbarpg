require 'test_helper'
require 'drb/ar_pg'
require 'logger'
require 'rbconfig'

class DrbarpgConnectTest < ActiveSupport::TestCase
  test "default connect timeout" do
    obj = DRbObject.new_with_uri("drbarpg://notstarted")
    st = Time.now
    assert_raise(DRb::DRbConnError) do
      obj.test
    end
    assert_operator 1..20, :===, Time.now-st
  end

  test "set connect timeout" do
    DRb.start_service("drbarpg://", nil, {:connect_timeout => 0.2})

    obj = DRbObject.new_with_uri("drbarpg://notstarted")
    st = Time.now
    assert_raise(DRb::DRbConnError) do
      obj.test
    end
    dt = Time.now-st
    assert_operator 0.2..0.9, :===, dt
  end
end
