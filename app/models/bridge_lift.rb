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

  def self.upcoming(limit: 20)
    schedule.select { |lift| lift.closes_at.future? }.sort.first(limit)
  end

  def self.schedule
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_all }
  end

  def self.fetch_all
    uri = URI("#{API_URL}?limit=100")
    response = Net::HTTP.get_response(uri)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("BridgeLift fetch failed: HTTP #{response.code}")
      return []
    end

    JSON.parse(response.body)["results"].map { |record| from_record(record) }
  rescue StandardError => e
    Rails.logger.error("BridgeLift fetch failed: #{e.class}: #{e.message}")
    []
  end

  def self.from_record(record)
    date = Date.parse(record["date_passage"])
    closes_at = Time.zone.parse("#{date} #{record['fermeture_a_la_circulation']}")
    reopens_at = Time.zone.parse("#{date} #{record['re_ouverture_a_la_circulation']}")
    # The closure can straddle midnight (e.g. closes 23:00, reopens 05:00).
    reopens_at += 1.day if reopens_at < closes_at

    new(vessel: record["bateau"], date: date, closes_at: closes_at, reopens_at: reopens_at)
  end
end
