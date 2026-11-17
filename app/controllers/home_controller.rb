class HomeController < ApplicationController
  def index
    @upcoming_lifts = BridgeLift.upcoming
    @feed_unavailable = @upcoming_lifts.nil?
    @upcoming_lifts ||= []
    @next_lift = @upcoming_lifts.first
    @later_lifts = @upcoming_lifts.drop(1)
  end
end
