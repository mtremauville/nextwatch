# frozen_string_literal: true

class RecommendationService
  MAX_HISTORY = 20      # nb de WatchItems envoyés au LLM
  MAX_SUGGESTIONS = 5   # nb de recommandations retournées

  def initialize(user)
    @user     = user
    @tmdb     = TmdbService.new
  end

  # Point d'entrée principal
  # Retourne un tableau de Recommendation (non sauvegardés)
  def call(mood: nil, media_type: nil)
    history  = build_history
    prompt   = build_prompt(history, mood: mood, media_type: media_type)
    raw      = ask_llm(prompt)
    suggestions = parse_suggestions(raw)
    enrich_with_tmdb(suggestions)
  end

  private

  # -------------------------------------------------------
  # HISTORIQUE UTILISATEUR
  # -------------------------------------------------------

  def build_history
    items = @user.watch_items
                 .where(status: %w[watching completed])
                 .order(updated_at: :desc)
                 .limit(MAX_HISTORY)

    {
      completed: items.select(&:completed?).map { |i| format_item(i) },
      watching:  items.select(&:watching?).map  { |i| format_item(i) },
      genres:    extract_top_genres(items)
    }
  end

  def format_item(item)
    {
      title:      item.title,
      media_type: item.media_type,
      genres:     item.genres_list,
      rating:     item.vote_average
    }
  end

  def extract_top_genres(items)
    items
      .flat_map(&:genres_list)
      .tally
      .sort_by { |_, count| -count }
      .first(5)
      .map(&:first)
  end

  # -------------------------------------------------------
  # PROMPT
  # -------------------------------------------------------

  def build_prompt(history, mood: nil, media_type: nil)
    type_filter = case media_type
    when "movie" then "Suggère uniquement des FILMS."
    when "tv"    then "Suggère uniquement des SÉRIES."
    else              "Mélange films et séries selon ce qui correspond le mieux."
    end

    mood_context = mood.present? ? "L'utilisateur est d'humeur : #{mood}." : ""

    <<~PROMPT
      Tu es un expert en recommandations de films et séries. Analyse le profil de cet utilisateur et suggère #{MAX_SUGGESTIONS} œuvres qu'il va adorer.

      ## Profil utilisateur

      Genres favoris : #{history[:genres].join(", ")}

      Séries/films terminés :
      #{format_list(history[:completed])}

      En cours de visionnage :
      #{format_list(history[:watching])}

      ## Contraintes
      #{type_filter}
      #{mood_context}
      - Ne suggère JAMAIS une œuvre déjà présente dans l'historique ci-dessus.
      - Priorise des œuvres de qualité (note > 7/10 sur TMDB si possible).
      - Inclus au moins une œuvre moins connue / pépite.
      - Varie les origines (pas uniquement américain).

      ## Format de réponse OBLIGATOIRE
      Réponds UNIQUEMENT avec un tableau JSON valide, sans markdown, sans texte avant ou après.
      Chaque objet doit avoir exactement ces clés :
      {
        "title": "Titre exact en VO",
        "media_type": "movie" ou "tv",
        "year": 2019,
        "reason": "Explication courte en français (max 120 caractères) pourquoi cet utilisateur va aimer"
      }
    PROMPT
  end

  def format_list(items)
    return "  (aucun)" if items.empty?
    items.map { |i| "  - #{i[:title]} (#{i[:media_type]}, genres: #{i[:genres].join(', ')})" }.join("\n")
  end

  # -------------------------------------------------------
  # LLM
  # -------------------------------------------------------

  def ask_llm(prompt)
    RubyLLM.chat do |chat|
      chat.ask(prompt)
    end
  rescue RubyLLM::Error => e
    Rails.logger.error("[RecommendationService] LLM error : #{e.message}")
    raise RecommendationError, "Impossible de générer des recommandations : #{e.message}"
  end

  # -------------------------------------------------------
  # PARSING JSON
  # -------------------------------------------------------

  def parse_suggestions(raw_response)
    text = raw_response.to_s.strip

    # Extrait le JSON même si le LLM a ajouté du texte autour
    json_match = text.match(/\[.*\]/m)
    raise RecommendationError, "Réponse LLM invalide (pas de JSON trouvé)" unless json_match

    suggestions = JSON.parse(json_match[0])
    raise RecommendationError, "Réponse LLM vide" if suggestions.empty?

    suggestions
  rescue JSON::ParserError => e
    Rails.logger.error("[RecommendationService] JSON parse error : #{e.message}\nRaw: #{raw_response}")
    raise RecommendationError, "Erreur de parsing de la réponse IA"
  end

  # -------------------------------------------------------
  # ENRICHISSEMENT TMDB
  # -------------------------------------------------------

  # Pour chaque suggestion du LLM, on cherche les données TMDB réelles
  # (poster, tmdb_id, overview, note…)
  def enrich_with_tmdb(suggestions)
    suggestions.filter_map do |suggestion|
      tmdb_data = find_on_tmdb(suggestion["title"], suggestion["media_type"])
      next if tmdb_data.nil?

      # Évite les doublons avec l'historique existant
      next if already_in_watchlist?(tmdb_data[:tmdb_id], tmdb_data[:media_type])

      build_recommendation(tmdb_data, suggestion["reason"])
    end
  end

  def find_on_tmdb(title, media_type)
    results = case media_type
    when "movie" then @tmdb.search_movies(title)
    when "tv"    then @tmdb.search_tv(title)
    else              @tmdb.search_multi(title)
    end

    results.first
  rescue TmdbError => e
    Rails.logger.warn("[RecommendationService] TMDB lookup failed for '#{title}': #{e.message}")
    nil
  end

  def already_in_watchlist?(tmdb_id, media_type)
    @user.watch_items.exists?(tmdb_id: tmdb_id, media_type: media_type)
  end

  def build_recommendation(tmdb_data, reason)
    Recommendation.new(
      user:        @user,
      tmdb_id:     tmdb_data[:tmdb_id],
      media_type:  tmdb_data[:media_type],
      title:       tmdb_data[:title],
      poster_path: tmdb_data[:poster_path],
      overview:    tmdb_data[:overview],
      vote_average: tmdb_data[:vote_average],
      reason:      reason,
      seen:        false
    )
  end
end

class RecommendationError < StandardError; end
