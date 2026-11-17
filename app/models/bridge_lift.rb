require "net/http"

# A scheduled lift of the Pont Jacques-Chaban-Delmas in Bordeaux, which
# raises its central span to let tall ships pass underneath. Data comes
# from Bordeaux Métropole's open data portal rather than our own database,
# since they're the authority on the schedule.
class BridgeLift
  include Comparable

  API_URL = "https://opendata.bordeaux-metropole.fr/api/explore/v2.1/catalog/datasets/previsions_pont_chaban/records"
  CACHE_KEY = "bridge_lift/schedule"
  CACHE_TTL = 15.minutes
  PAGE_SIZE = 100
  MAX_PAGES = 20 # safety cap: 2,000 records is far more than this dataset will ever hold

  attr_reader :vessel, :date, :closes_at, :reopens_at

  def initialize(vessel:, date:, closes_at:, reopens_at:)
    @vessel = vessel
    @date = date
    @closes_at = closes_at
    @reopens_at = reopens_at
  end

  def <=>(other)
    closes_at <=> other.closes_at
  end

  def maintenance?
    vessel == "MAINTENANCE"
  end

  # The feed joins multiple ships passing in the same window with " - ".
  def vessels
    vessel.split(" - ")
  end

  # Upcoming lifts, soonest first. Returns nil (rather than an empty array)
  # when the feed couldn't be fetched at all, so callers can tell "nothing
  # scheduled" apart from "data unavailable right now".
  def self.upcoming(limit: 20)
    data = schedule
    return nil if data.nil?

    data.select { |lift| lift.closes_at.future? }.sort.first(limit)
  end

  def self.schedule
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL, skip_nil: true) { fetch_all }
  end

  # Fetches every record from the feed, paging through it since the API
  # caps each response at PAGE_SIZE. Returns nil if the feed can't be
  # read at all; an empty array is a legitimate "nothing scheduled".
  def self.fetch_all
    records = []

    MAX_PAGES.times do |page|
      response = get(offset: page * PAGE_SIZE)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("BridgeLift fetch failed: HTTP #{response.code}")
        return nil
      end

      payload = JSON.parse(response.body)
      records.concat(payload["results"])
      break if records.size >= payload["total_count"] || payload["results"].empty?
    end

    records.map { |record| from_record(record) }
  rescue StandardError => e
    Rails.logger.error("BridgeLift fetch failed: #{e.class}: #{e.message}")
    nil
  end

  def self.get(offset:)
    uri = URI("#{API_URL}?limit=#{PAGE_SIZE}&offset=#{offset}")
    Net::HTTP.get_response(uri)
  end
  private_class_method :get

  def self.from_record(record)
    date = Date.parse(record["date_passage"])
    closes_at = Time.zone.parse("#{date} #{record['fermeture_a_la_circulation']}")
    reopens_at = Time.zone.parse("#{date} #{record['re_ouverture_a_la_circulation']}")
    # The closure can straddle midnight (e.g. closes 23:00, reopens 05:00).
    reopens_at += 1.day if reopens_at < closes_at

    new(vessel: record["bateau"], date: date, closes_at: closes_at, reopens_at: reopens_at)
  end
end
