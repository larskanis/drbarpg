require 'test_helper'

class DrbarpgConnectTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = false

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

  test "error if two services are started with equal name" do
    DRb.start_service("drbarpg://myserver", Kernel)
    begin
      st = Time.now
      assert_raise(ActiveRecord::RecordNotUnique) do
        DRb.start_service("drbarpg://myserver")
      end
      assert_operator 1, :>, Time.now-st, "Verify a running service should take less than a second"
    ensure
      DRb.stop_service
    end
  end

  test "detect and drop an orphaned server connection" do
    Drbarpg::Connection.create :listen_channel => "\"drbarpg_oldserver\""
    begin
      st = Time.now
      DRb.start_service("drbarpg://oldserver", Kernel, {:connect_timeout => 0.2})
      assert_operator 0.2..0.9, :===, Time.now-st, "It should take some time to discover that the old service is orphaned"
    ensure
      Drbarpg::Connection.where(:listen_channel => "\"drbarpg_oldserver\"").delete_all
    end
  end

end
