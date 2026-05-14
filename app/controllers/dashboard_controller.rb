class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @watching  = current_user.watch_items.watching.order(updated_at: :desc)
    @watchlist = current_user.watch_items.watchlist.order(updated_at: :desc).limit(20)
    @completed = current_user.watch_items.completed.order(updated_at: :desc).limit(6)
    @rotation  = current_user.rotations.active.includes(rotation_items: :watch_item).first
    @next_up   = @rotation&.service&.next_up
    @upcoming  = @rotation&.service&.upcoming(count: 5) || []
    @recent_recommendations = current_user.recommendations
                                          .where(seen: false)
                                          .order(created_at: :desc)
                                          .limit(4)
  end
end
