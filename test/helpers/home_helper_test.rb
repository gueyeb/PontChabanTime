require "test_helper"

class HomeHelperTest < ActionView::TestCase
  test "relative_day_label names today and tomorrow, formats other dates" do
    assert_equal "Aujourd'hui", relative_day_label(Date.current)
    assert_equal "Demain", relative_day_label(Date.tomorrow)
    assert_equal 2.days.from_now.to_date.strftime("%a %-d %b"), relative_day_label(2.days.from_now.to_date)
  end

  test "vessel_label shows a friendly label for maintenance windows" do
    lift = BridgeLift.new(vessel: "MAINTENANCE", date: Date.current, closes_at: Time.current, reopens_at: 1.hour.from_now)
    assert_equal "Travaux de maintenance", vessel_label(lift)
  end

  test "vessel_label joins multiple ships with a comma" do
    lift = BridgeLift.new(vessel: "SILVER DAWN - LA BELLE POULE", date: Date.current, closes_at: Time.current, reopens_at: 1.hour.from_now)
    assert_equal "SILVER DAWN, LA BELLE POULE", vessel_label(lift)
  end

  test "lift_duration_label formats minutes and hours" do
    short = BridgeLift.new(vessel: "X", date: Date.current, closes_at: Time.current, reopens_at: 45.minutes.from_now)
    long = BridgeLift.new(vessel: "X", date: Date.current, closes_at: Time.current, reopens_at: 1.hour.from_now + 23.minutes)

    assert_equal "45 min", lift_duration_label(short)
    assert_equal "1 h 23", lift_duration_label(long)
  end
end
