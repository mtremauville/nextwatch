import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]

  connect() {
    this.mediaType = null
    this.debounceTimer = null
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  // ── Filtres ─────────────────────────────────────────────

  filterAll(e) {
    this.mediaType = null
    this.#setActiveFilter(e.target)
    this.#doSearch()
  }

  filterMovies(e) {
    this.mediaType = "movie"
    this.#setActiveFilter(e.target)
    this.#doSearch()
  }

  filterSeries(e) {
    this.mediaType = "tv"
    this.#setActiveFilter(e.target)
    this.#doSearch()
  }

  // ── Recherche avec debounce ──────────────────────────────

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.#doSearch(), 320)
  }

  async #doSearch() {
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    this.#showLoading()

    const params = new URLSearchParams({ q: query })
    if (this.mediaType) params.append("type", this.mediaType)

    try {
      const response = await fetch(`/watch_items/search?${params}`, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) throw new Error("Erreur réseau")
      const results = await response.json()
      this.#renderResults(results)
    } catch (err) {
      this.resultsTarget.innerHTML = `<p class="search-error">Impossible de contacter TMDB</p>`
    }
  }

  // ── Ajout à la watchlist ─────────────────────────────────

  async addToWatchlist(e) {
    const btn  = e.currentTarget
    const data = JSON.parse(btn.dataset.item)

    btn.disabled = true
    btn.textContent = "…"

    try {
      const response = await fetch("/watch_items", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "text/vnd.turbo-stream.html, application/json"
        },
        body: JSON.stringify({
          watch_item: {
            tmdb_id:     data.tmdb_id,
            media_type:  data.media_type,
            title:       data.title,
            poster_path: data.poster_path,
            overview:    data.overview,
            vote_average: data.vote_average,
            genres:      data.genre_ids?.join(", ") || "",
            status:      "watchlist",
            current_season:  1,
            current_episode: 1
          }
        })
      })

      if (response.ok) {
        const contentType = response.headers.get("Content-Type") || ""
        if (contentType.includes("turbo-stream")) {
          const html = await response.text()
          Turbo.renderStreamMessage(html)
        }
        btn.textContent = "✓ Ajouté"
        btn.classList.add("added")
        btn.closest(".search-result-item")?.classList.add("search-result-item--added")
      } else {
        const err = await response.json()
        btn.textContent = "Erreur"
        console.error(err)
      }
    } catch {
      btn.textContent = "Erreur"
      btn.disabled = false
    }
  }

  // ── Rendu ────────────────────────────────────────────────

  #renderResults(results) {
    if (!results.length) {
      this.resultsTarget.innerHTML = `<p class="search-empty">Aucun résultat</p>`
      return
    }

    this.resultsTarget.innerHTML = results.map(item => `
      <div class="search-result-item ${item.in_watchlist ? "search-result-item--added" : ""}">
        <img
          class="search-result-item__poster"
          src="${item.poster_url || "/placeholder.svg"}"
          alt="${this.#escape(item.title)}"
          loading="lazy"
          onerror="this.style.display='none'"
        >
        <div class="search-result-item__body">
          <span class="search-result-item__type">${item.media_type === "movie" ? "Film" : "Série"}</span>
          <h4 class="search-result-item__title">${this.#escape(item.title)}</h4>
          <p class="search-result-item__meta">
            ${item.release_date ? item.release_date.slice(0, 4) : ""}
            ${item.vote_average ? `· ★ ${item.vote_average}` : ""}
          </p>
          <p class="search-result-item__overview">${this.#escape(item.overview?.slice(0, 120) || "")}${item.overview?.length > 120 ? "…" : ""}</p>
        </div>
        <button
          class="search-result-item__add ${item.in_watchlist ? "added" : ""}"
          data-action="click->tmdb-search#addToWatchlist"
          data-item="${JSON.stringify(item).replace(/"/g, '&quot;')}"
          ${item.in_watchlist ? "disabled" : ""}
        >
          ${item.in_watchlist ? "✓ Dans la liste" : "+ Ajouter"}
        </button>
      </div>
    `).join("")
  }

  #showLoading() {
    this.resultsTarget.innerHTML = `
      <div class="search-loading">
        <span class="search-loading__dot"></span>
        <span class="search-loading__dot"></span>
        <span class="search-loading__dot"></span>
      </div>`
  }

  #setActiveFilter(btn) {
    this.element.querySelectorAll(".filter-btn").forEach(b => b.classList.remove("active"))
    btn.classList.add("active")
  }

  #escape(str) {
    if (!str) return ""
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
  }
}
