# frozen_string_literal: true

class RotationService
  def initialize(rotation)
    @rotation = rotation
    @tmdb     = TmdbService.new
  end

  # -------------------------------------------------------
  # PROCHAIN ÉPISODE À REGARDER
  # Retourne un hash avec toutes les infos pour l'affichage
  # -------------------------------------------------------

  def next_up
    item = current_rotation_item
    return nil unless item

    watch_item = item.watch_item
    episode    = fetch_episode_details(watch_item)

    {
      rotation_item:  item,
      watch_item:     watch_item,
      position:       item.position,
      episode:        episode,
      label:          watch_item.next_episode_label,
      episodes_per_turn: item.episodes_per_turn
    }
  end

  # -------------------------------------------------------
  # MARQUER UN ÉPISODE COMME VU
  # Avance dans la série + passe au suivant dans la rotation
  # -------------------------------------------------------

  def mark_episode_watched!(rotation_item_id)
    item       = @rotation.rotation_items.find(rotation_item_id)
    watch_item = item.watch_item

    ActiveRecord::Base.transaction do
      # Récupère le nb d'épisodes de la saison courante via TMDB
      season_data    = @tmdb.season_details(watch_item.tmdb_id, watch_item.current_season)
      episode_count  = season_data[:episodes].length

      # Vérifie si c'était le dernier épisode de la saison
      last_of_season  = watch_item.current_episode >= episode_count
      # Vérifie si c'était le dernier épisode de la série
      tv_details      = @tmdb.tv_details(watch_item.tmdb_id)
      last_of_series  = last_of_season && watch_item.current_season >= tv_details[:number_of_seasons]

      if last_of_series
        watch_item.update!(status: "completed")
        remove_from_rotation!(item)
      else
        watch_item.advance_episode!(episode_count)
        advance_rotation_turn!
      end
    end
  end

  # -------------------------------------------------------
  # AJOUTER UNE SÉRIE À LA ROTATION
  # -------------------------------------------------------

  def add_series!(watch_item, episodes_per_turn: 1)
    raise RotationError, "Seules les séries peuvent être ajoutées à une rotation" unless watch_item.tv?
    raise RotationError, "Cette série est déjà dans la rotation" if already_in_rotation?(watch_item)

    next_position = @rotation.rotation_items.maximum(:position).to_i + 1

    @rotation.rotation_items.create!(
      watch_item:        watch_item,
      position:          next_position,
      episodes_per_turn: episodes_per_turn
    )
  end

  # -------------------------------------------------------
  # RETIRER UNE SÉRIE DE LA ROTATION
  # -------------------------------------------------------

  def remove_series!(watch_item)
    item = @rotation.rotation_items.find_by(watch_item: watch_item)
    raise RotationError, "Série introuvable dans cette rotation" unless item

    item.destroy!
    reorder_positions!
  end

  # -------------------------------------------------------
  # RÉORDONNER LA ROTATION (drag & drop)
  # positions : { rotation_item_id => new_position }
  # -------------------------------------------------------

  def reorder!(positions)
    ActiveRecord::Base.transaction do
      positions.each do |id, pos|
        @rotation.rotation_items.find(id).update!(position: pos.to_i)
      end
    end
  end

  # -------------------------------------------------------
  # PLANNING : les prochains épisodes à venir
  # Retourne un tableau ordonné des N prochains visionnages
  # -------------------------------------------------------

  def upcoming(count: 10)
    items        = ordered_items
    return []   if items.empty?

    schedule     = []
    cursor       = current_position_index(items)
    turn         = 0

    count.times do
      item       = items[cursor % items.length]
      watch_item = item.watch_item

      item.episodes_per_turn.times do |ep_offset|
        schedule << build_schedule_entry(watch_item, turn, ep_offset)
        break if schedule.length >= count
      end

      cursor += 1
      turn   += 1
      break if schedule.length >= count
    end

    schedule
  end

  # -------------------------------------------------------
  # STATS DE LA ROTATION
  # -------------------------------------------------------

  def stats
    items = ordered_items
    {
      total_series:    items.length,
      active:          @rotation.active,
      series:          items.map { |i| series_stat(i) },
      estimated_cycle: estimated_cycle_duration(items)
    }
  end

  private

  # -------------------------------------------------------
  # HELPERS INTERNES
  # -------------------------------------------------------

  def ordered_items
    @rotation.rotation_items
             .includes(:watch_item)
             .where(watch_items: { status: "watching" })
             .order(:position)
  end

  def current_rotation_item
    ordered_items.first
  end

  def current_position_index(items)
    0
  end

  def advance_rotation_turn!
    items = @rotation.rotation_items.order(:position).to_a
    return if items.length <= 1

    first = items.first
    # Déplace le premier en dernière position (rotation circulaire)
    first.update!(position: items.last.position + 1)
    reorder_positions!
  end

  def remove_from_rotation!(item)
    item.destroy!
    reorder_positions!
  end

  def reorder_positions!
    @rotation.rotation_items.order(:position).each_with_index do |item, idx|
      item.update_column(:position, idx + 1)
    end
  end

  def already_in_rotation?(watch_item)
    @rotation.rotation_items.exists?(watch_item: watch_item)
  end

  def fetch_episode_details(watch_item)
    @tmdb.episode_details(
      watch_item.tmdb_id,
      watch_item.current_season,
      watch_item.current_episode
    )
  rescue TmdbError
    nil
  end

  def build_schedule_entry(watch_item, turn, ep_offset)
    virtual_ep = watch_item.current_episode + ep_offset

    {
      turn:        turn + 1,
      watch_item:  watch_item,
      title:       watch_item.title,
      poster_url:  watch_item.poster_url,
      season:      watch_item.current_season,
      episode:     virtual_ep,
      label:       "S#{watch_item.current_season.to_s.rjust(2, '0')}E#{virtual_ep.to_s.rjust(2, '0')}"
    }
  end

  def series_stat(item)
    w = item.watch_item
    {
      title:             w.title,
      poster_url:        w.poster_url,
      current:           w.next_episode_label,
      episodes_per_turn: item.episodes_per_turn,
      position:          item.position
    }
  end

  def estimated_cycle_duration(items)
    return 0 if items.empty?
    total_episodes = items.sum(&:episodes_per_turn)
    avg_runtime    = 45 # minutes, fallback
    (total_episodes * avg_runtime / 60.0).round(1)
  end
end

class RotationError < StandardError; end
