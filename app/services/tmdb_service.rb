# frozen_string_literal: true

class TmdbService
  BASE_URL = "https://api.themoviedb.org/3"
  IMAGE_BASE_URL = "https://image.tmdb.org/t/p"
  POSTER_SIZE = "w500"
  BACKDROP_SIZE = "w1280"

  def initialize
    @api_key = ENV["TMDB_API_KEY"]
    raise "TMDB_API_KEY manquant dans .env" if @api_key.blank?
  end

  # -------------------------------------------------------
  # SEARCH
  # -------------------------------------------------------

  # Recherche multi (films + séries en une requête)
  def search_multi(query, page: 1)
    response = get("/search/multi", query: query, page: page, include_adult: false)
    results = response["results"] || []
    results
      .select { |r| %w[movie tv].include?(r["media_type"]) }
      .map { |r| format_result(r) }
  end

  # Recherche films uniquement
  def search_movies(query, page: 1)
    response = get("/search/movie", query: query, page: page)
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => "movie")) }
  end

  # Recherche séries uniquement
  def search_tv(query, page: 1)
    response = get("/search/tv", query: query, page: page)
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => "tv")) }
  end

  # -------------------------------------------------------
  # DETAILS
  # -------------------------------------------------------

  def movie_details(tmdb_id)
    response = get("/movie/#{tmdb_id}", append_to_response: "credits,similar,videos")
    format_movie_details(response)
  end

  def tv_details(tmdb_id)
    response = get("/tv/#{tmdb_id}", append_to_response: "credits,similar,videos")
    format_tv_details(response)
  end

  # Détails d'une saison spécifique
  def season_details(tmdb_id, season_number)
    response = get("/tv/#{tmdb_id}/season/#{season_number}")
    format_season(response)
  end

  # Détails d'un épisode spécifique
  def episode_details(tmdb_id, season_number, episode_number)
    get("/tv/#{tmdb_id}/season/#{season_number}/episode/#{episode_number}")
  end

  # -------------------------------------------------------
  # DISCOVER / TRENDING
  # -------------------------------------------------------

  def trending_movies(time_window: "week")
    response = get("/trending/movie/#{time_window}")
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => "movie")) }
  end

  def trending_tv(time_window: "week")
    response = get("/trending/tv/#{time_window}")
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => "tv")) }
  end

  # Films similaires à un film donné
  def similar_movies(tmdb_id, page: 1)
    response = get("/movie/#{tmdb_id}/similar", page: page)
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => "movie")) }
  end

  # Séries similaires à une série donnée
  def similar_tv(tmdb_id, page: 1)
    response = get("/tv/#{tmdb_id}/similar", page: page)
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => "tv")) }
  end

  # Recommandations TMDB (différent de "similar" — algo TMDB)
  def recommendations(tmdb_id, media_type)
    response = get("/#{media_type}/#{tmdb_id}/recommendations")
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => media_type)) }
  end

  # Discover avec filtres (genre, note, année)
  def discover(media_type, genre_ids: nil, min_rating: nil, year: nil, page: 1)
    params = { page: page, sort_by: "popularity.desc" }
    params[:with_genres]             = Array(genre_ids).join(",") if genre_ids.present?
    params["vote_average.gte"]       = min_rating if min_rating.present?
    params[media_type == "movie" ? :primary_release_year : :first_air_date_year] = year if year.present?

    response = get("/discover/#{media_type}", **params)
    (response["results"] || []).map { |r| format_result(r.merge("media_type" => media_type)) }
  end

  # -------------------------------------------------------
  # GENRES
  # -------------------------------------------------------

  def movie_genres
    response = get("/genre/movie/list")
    response["genres"] || []
  end

  def tv_genres
    response = get("/genre/tv/list")
    response["genres"] || []
  end

  # -------------------------------------------------------
  # HELPERS PUBLICS
  # -------------------------------------------------------

  def poster_url(path, size: POSTER_SIZE)
    return nil if path.blank?
    "#{IMAGE_BASE_URL}/#{size}#{path}"
  end

  def backdrop_url(path)
    return nil if path.blank?
    "#{IMAGE_BASE_URL}/#{BACKDROP_SIZE}#{path}"
  end

  private

  # -------------------------------------------------------
  # HTTP
  # -------------------------------------------------------

  def get(endpoint, **params)
    url = "#{BASE_URL}#{endpoint}"
    query = default_params.merge(params.transform_values(&:to_s))

    response = HTTParty.get(url, query: query, timeout: 10)

    unless response.success?
      Rails.logger.error("[TmdbService] #{response.code} — #{response.body}")
      raise TmdbError.new("TMDB API error #{response.code}", response.code)
    end

    response.parsed_response
  rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[TmdbService] Timeout/réseau : #{e.message}")
    raise TmdbError.new("TMDB inaccessible : #{e.message}")
  end

  def default_params
    {
      api_key: @api_key,
      language: "fr-FR"
    }
  end

  # -------------------------------------------------------
  # FORMATTERS
  # -------------------------------------------------------

  def format_result(raw)
    is_tv = raw["media_type"] == "tv"
    {
      tmdb_id:      raw["id"],
      media_type:   raw["media_type"],
      title:        is_tv ? raw["name"] : raw["title"],
      original_title: is_tv ? raw["original_name"] : raw["original_title"],
      overview:     raw["overview"],
      poster_path:  raw["poster_path"],
      poster_url:   poster_url(raw["poster_path"]),
      backdrop_url: backdrop_url(raw["backdrop_path"]),
      vote_average: raw["vote_average"]&.round(1),
      popularity:   raw["popularity"],
      release_date: is_tv ? raw["first_air_date"] : raw["release_date"],
      genre_ids:    raw["genre_ids"] || []
    }
  end

  def format_movie_details(raw)
    format_result(raw.merge("media_type" => "movie")).merge(
      runtime:      raw["runtime"],
      genres:       raw["genres"]&.map { |g| g["name"] },
      tagline:      raw["tagline"],
      status:       raw["status"],
      budget:       raw["budget"],
      revenue:      raw["revenue"],
      similar:      (raw.dig("similar", "results") || []).first(6).map { |r| format_result(r.merge("media_type" => "movie")) },
      trailer_key:  extract_trailer_key(raw["videos"])
    )
  end

  def format_tv_details(raw)
    format_result(raw.merge("media_type" => "tv")).merge(
      number_of_seasons:  raw["number_of_seasons"],
      number_of_episodes: raw["number_of_episodes"],
      episode_run_time:   raw["episode_run_time"]&.first,
      genres:             raw["genres"]&.map { |g| g["name"] },
      status:             raw["status"],
      networks:           raw["networks"]&.map { |n| n["name"] },
      seasons:            format_seasons_summary(raw["seasons"]),
      similar:            (raw.dig("similar", "results") || []).first(6).map { |r| format_result(r.merge("media_type" => "tv")) },
      trailer_key:        extract_trailer_key(raw["videos"])
    )
  end

  def format_seasons_summary(seasons)
    return [] if seasons.blank?
    seasons
      .reject { |s| s["season_number"] == 0 } # ignore "Specials"
      .map do |s|
        {
          season_number:  s["season_number"],
          name:           s["name"],
          episode_count:  s["episode_count"],
          air_date:       s["air_date"],
          poster_url:     poster_url(s["poster_path"])
        }
      end
  end

  def format_season(raw)
    {
      season_number: raw["season_number"],
      name:          raw["name"],
      overview:      raw["overview"],
      air_date:      raw["air_date"],
      episodes:      (raw["episodes"] || []).map { |e| format_episode(e) }
    }
  end

  def format_episode(raw)
    {
      episode_number: raw["episode_number"],
      name:           raw["name"],
      overview:       raw["overview"],
      air_date:       raw["air_date"],
      runtime:        raw["runtime"],
      still_url:      poster_url(raw["still_path"], size: "w300")
    }
  end

  def extract_trailer_key(videos_data)
    return nil if videos_data.blank?
    results = videos_data["results"] || []
    trailer = results.find { |v| v["type"] == "Trailer" && v["site"] == "YouTube" }
    trailer ||= results.find { |v| v["site"] == "YouTube" }
    trailer&.dig("key")
  end
end

# Exception custom pour rescue propre dans les contrôleurs
class TmdbError < StandardError
  attr_reader :status_code
  def initialize(message, status_code = nil)
    super(message)
    @status_code = status_code
  end
end
