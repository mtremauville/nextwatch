class RecommendationsController < ApplicationController
  def index
  end

  def generate
    service = RecommendationService.new(current_user)
  @recommendations = service.call(
    mood: params[:mood],           # ex: "fatigué", "envie d'action"
    media_type: params[:media_type] # "movie", "tv", ou nil
  )
  @recommendations.each(&:save!)
    rescue RecommendationError => e
      flash[:alert] = e.message
  end
end
