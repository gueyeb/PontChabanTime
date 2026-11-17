require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows the upcoming lifts" do
    lift = BridgeLift.new(
      vessel: "BALMORAL",
      date: 1.day.from_now.to_date,
      closes_at: 1.day.from_now,
      reopens_at: 1.day.from_now + 1.hour
    )

    BridgeLift.stub :upcoming, [ lift ] do
      get root_path
    end

    assert_response :success
    assert_select "td", text: "BALMORAL"
  end

  test "shows an empty state when there is nothing scheduled" do
    BridgeLift.stub :upcoming, [] do
      get root_path
    end

    assert_response :success
    assert_select "p", text: /Aucune levée/
  end
end
