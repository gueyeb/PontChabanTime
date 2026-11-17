require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "highlights the next lift and lists the ones after it" do
    next_lift = BridgeLift.new(vessel: "BALMORAL", date: 1.day.from_now.to_date, closes_at: 1.day.from_now, reopens_at: 1.day.from_now + 1.hour)
    later_lift = BridgeLift.new(vessel: "MAINTENANCE", date: 2.days.from_now.to_date, closes_at: 2.days.from_now, reopens_at: 2.days.from_now + 1.hour)

    BridgeLift.stub :upcoming, [ next_lift, later_lift ] do
      get root_path
    end

    assert_response :success
    assert_select ".next-vessel", text: "BALMORAL"
    assert_select ".schedule td", text: "Travaux de maintenance"
  end

  test "shows an empty state when nothing is scheduled" do
    BridgeLift.stub :upcoming, [] do
      get root_path
    end

    assert_response :success
    assert_select ".card", text: /Aucune levée/
  end

  test "shows a distinct message when the feed is unavailable" do
    BridgeLift.stub :upcoming, nil do
      get root_path
    end

    assert_response :success
    assert_select ".card--warning", text: /Impossible de récupérer/
  end
end
