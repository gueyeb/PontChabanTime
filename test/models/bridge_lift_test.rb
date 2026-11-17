require "test_helper"

class BridgeLiftTest < ActiveSupport::TestCase
  test "parses a same-day closure" do
    lift = BridgeLift.from_record(
      "bateau" => "BALMORAL",
      "date_passage" => "2026-04-11",
      "fermeture_a_la_circulation" => "14:19",
      "re_ouverture_a_la_circulation" => "15:42",
      "type_de_fermeture" => "Totale",
      "fermeture_totale" => "oui"
    )

    assert_equal "BALMORAL", lift.vessel
    assert_equal Date.new(2026, 4, 11), lift.date
    assert_equal "14:19", lift.closes_at.strftime("%H:%M")
    assert_equal "15:42", lift.reopens_at.strftime("%H:%M")
  end

  test "rolls the reopening time to the next day when the closure crosses midnight" do
    lift = BridgeLift.from_record(
      "bateau" => "MAINTENANCE",
      "date_passage" => "2026-02-15",
      "fermeture_a_la_circulation" => "23:00",
      "re_ouverture_a_la_circulation" => "05:00",
      "type_de_fermeture" => "Totale",
      "fermeture_totale" => "oui"
    )

    assert_equal Date.new(2026, 2, 15), lift.closes_at.to_date
    assert_equal Date.new(2026, 2, 16), lift.reopens_at.to_date
  end

  test "upcoming keeps only future closures, soonest first" do
    past = BridgeLift.new(vessel: "PAST", date: 1.day.ago.to_date, closes_at: 1.day.ago, reopens_at: 1.day.ago + 1.hour)
    soon = BridgeLift.new(vessel: "SOON", date: 1.day.from_now.to_date, closes_at: 1.day.from_now, reopens_at: 1.day.from_now + 1.hour)
    later = BridgeLift.new(vessel: "LATER", date: 2.days.from_now.to_date, closes_at: 2.days.from_now, reopens_at: 2.days.from_now + 1.hour)

    BridgeLift.stub :schedule, [ later, past, soon ] do
      assert_equal [ soon, later ], BridgeLift.upcoming
    end
  end

  test "fetch_all returns an empty list when the HTTP request errors out" do
    Net::HTTP.stub :get_response, ->(*) { raise SocketError, "no route to host" } do
      assert_equal [], BridgeLift.fetch_all
    end
  end

  test "fetch_all returns an empty list on a non-success HTTP response" do
    not_found = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    Net::HTTP.stub :get_response, ->(*) { not_found } do
      assert_equal [], BridgeLift.fetch_all
    end
  end
end
