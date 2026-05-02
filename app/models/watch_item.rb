# frozen_string_literal: true

class WatchItem < ApplicationRecord
  belongs_to :user

  STATUSES = %w[watchlist watching completed].freeze

  validates :tmdb_id,    presence: true
  validates :media_type, inclusion: { in: %w[movie tv] }
  validates :status,     inclusion: { in: STATUSES }
  validates :title,      presence: true

  scope :completed, -> { where(status: "completed") }
  scope :watching,  -> { where(status: "watching") }
  scope :watchlist, -> { where(status: "watchlist") }
  scope :movies,    -> { where(media_type: "movie") }
  scope :series,    -> { where(media_type: "tv") }

  def completed? = status == "completed"
  def watching?  = status == "watching"
  def watchlist? = status == "watchlist"
  def movie?     = media_type == "movie"
  def tv?        = media_type == "tv"

  def genres_list
    return [] if genres.blank?
    genres.split(",").map(&:strip)
  end

  def genres_list=(arr)
    self.genres = Array(arr).join(", ")
  end

  def poster_url(size: "w500")
    return nil if poster_path.blank?
    "https://image.tmdb.org/t/p/#{size}#{poster_path}"
  end

  # Pour la rotation : épisode suivant
  def next_episode_label
    return nil unless tv?
    "S#{current_season&.to_s&.rjust(2, '0')}E#{current_episode&.to_s&.rjust(2, '0')}"
  end

  def advance_episode!(season_episode_count)
    return unless tv?
    if current_episode < season_episode_count
      increment!(:current_episode)
    else
      increment!(:current_season)
      update!(current_episode: 1)
    end
  end
end
