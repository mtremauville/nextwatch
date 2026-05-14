class WatchItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_watch_item, only: %i[show update destroy]

  def index
    @watch_items = current_user.watch_items.order(updated_at: :desc)
    respond_to do |format|
      format.html
      format.json { render json: @watch_items }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @watch_item }
    end
  end

  def create
    @watch_item = current_user.watch_items.new(watch_item_params)
    if @watch_item.save
      respond_to do |format|
        format.html { redirect_to root_path, notice: "\"#{@watch_item.title}\" ajouté !" }
        format.json { render json: @watch_item, status: :created }
        format.turbo_stream {
          watchlist = current_user.watch_items.watchlist.order(updated_at: :desc).limit(20)
          render turbo_stream: [
            turbo_stream.remove("empty-state"),
            turbo_stream.update("watchlist-count", watchlist.count),
            turbo_stream.update("all-items-count", current_user.watch_items.count),
            turbo_stream.prepend("main-coverflow", partial: "watch_items/coverflow_item", locals: { watch_item: @watch_item })
          ]
        }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: @watch_item.errors.full_messages.join(", ") }
        format.json { render json: { errors: @watch_item.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @watch_item.update(watch_item_params)
      respond_to do |format|
        format.json { render json: @watch_item }
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("watch_item_#{@watch_item.id}", partial: "watch_items/card", locals: { watch_item: @watch_item }),
            turbo_stream.update("watchlist-count", current_user.watch_items.watchlist.count),
            turbo_stream.update("all-items-count", current_user.watch_items.count)
          ]
        }
      end
    else
      render json: { errors: @watch_item.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @watch_item.destroy!
    respond_to do |format|
      format.html { redirect_to root_path, notice: "Supprimé." }
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.remove("watch_item_#{@watch_item.id}"),
          turbo_stream.update("watchlist-count", current_user.watch_items.watchlist.count),
          turbo_stream.update("all-items-count", current_user.watch_items.count)
        ]
      }
      format.json { head :no_content }
    end
  end

  # GET /watch_items/search?q=severance&type=tv
  def search
    query      = params[:q].to_s.strip
    media_type = params[:type]

    return render json: [] if query.length < 2

    tmdb    = TmdbService.new
    results = case media_type
    when "movie" then tmdb.search_movies(query)
    when "tv"    then tmdb.search_tv(query)
    else              tmdb.search_multi(query)
    end

    # Marque ceux déjà dans la watchlist
    existing_ids = current_user.watch_items.pluck(:tmdb_id)
    results.each { |r| r[:in_watchlist] = existing_ids.include?(r[:tmdb_id]) }

    render json: results.first(8)
  rescue TmdbError => e
    render json: { error: e.message }, status: :service_unavailable
  end

  private

  def set_watch_item
    @watch_item = current_user.watch_items.find(params[:id])
  end

  def watch_item_params
    params.require(:watch_item).permit(
      :tmdb_id, :media_type, :title, :poster_path, :overview,
      :status, :current_season, :current_episode, :vote_average, :genres
    )
  end
end
