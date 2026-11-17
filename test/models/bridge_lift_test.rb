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

  test "maintenance? is true only for maintenance windows, not real vessels" do
    maintenance = BridgeLift.new(vessel: "MAINTENANCE", date: Date.current, closes_at: Time.current, reopens_at: 1.hour.from_now)
    ship = BridgeLift.new(vessel: "BALMORAL", date: Date.current, closes_at: Time.current, reopens_at: 1.hour.from_now)

    assert maintenance.maintenance?
    assert_not ship.maintenance?
  end

  test "vessels splits a multi-ship window into individual names" do
    lift = BridgeLift.new(
      vessel: "WORLD VOYAGER - VIKING SATURN - SEVEN SEAS GRANDEUR",
      date: Date.current, closes_at: Time.current, reopens_at: 1.hour.from_now
    )

    assert_equal [ "WORLD VOYAGER", "VIKING SATURN", "SEVEN SEAS GRANDEUR" ], lift.vessels
  end

  test "upcoming keeps only future closures, soonest first" do
    past = BridgeLift.new(vessel: "PAST", date: 1.day.ago.to_date, closes_at: 1.day.ago, reopens_at: 1.day.ago + 1.hour)
    soon = BridgeLift.new(vessel: "SOON", date: 1.day.from_now.to_date, closes_at: 1.day.from_now, reopens_at: 1.day.from_now + 1.hour)
    later = BridgeLift.new(vessel: "LATER", date: 2.days.from_now.to_date, closes_at: 2.days.from_now, reopens_at: 2.days.from_now + 1.hour)

    BridgeLift.stub :schedule, [ later, past, soon ] do
      assert_equal [ soon, later ], BridgeLift.upcoming
    end
  end

  test "upcoming is nil when the feed is unavailable" do
    BridgeLift.stub :schedule, nil do
      assert_nil BridgeLift.upcoming
    end
  end

  test "fetch_all returns nil when the HTTP request errors out" do
    Net::HTTP.stub :get_response, ->(*) { raise SocketError, "no route to host" } do
      assert_nil BridgeLift.fetch_all
    end
  end

  test "fetch_all returns nil on a non-success HTTP response" do
    not_found = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    Net::HTTP.stub :get_response, ->(*) { not_found } do
      assert_nil BridgeLift.fetch_all
    end
  end

  test "fetch_all pages through the feed until it has every record" do
    full_page = Array.new(BridgeLift::PAGE_SIZE) do |i|
      { "bateau" => "SHIP#{i}", "date_passage" => "2026-01-01", "fermeture_a_la_circulation" => "10:00", "re_ouverture_a_la_circulation" => "11:00" }
    end
    last_record = { "bateau" => "LAST", "date_passage" => "2026-01-02", "fermeture_a_la_circulation" => "10:00", "re_ouverture_a_la_circulation" => "11:00" }
    total = full_page.size + 1

    page_1 = { "total_count" => total, "results" => full_page }
    page_2 = { "total_count" => total, "results" => [ last_record ] }
    responses = [ page_1, page_2 ].map do |payload|
      Net::HTTPOK.new("1.1", "200", "OK").tap { |r| r.define_singleton_method(:body) { payload.to_json } }
    end

    call_count = 0
    Net::HTTP.stub :get_response, ->(*) { responses[call_count].tap { call_count += 1 } } do
      lifts = BridgeLift.fetch_all
      assert_equal total, lifts.size
      assert_equal "LAST", lifts.last.vessel
    end
  end
end
