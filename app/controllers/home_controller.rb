class HomeController < ApplicationController
  def index
    @upcoming_lifts = BridgeLift.upcoming
  end
end
