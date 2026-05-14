import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._syntheticEls  = new Set()
    this._items         = []
    this._currentIndex  = 0
    // rAF : lit la largeur réelle après que le flexbox a distribué l'espace
    requestAnimationFrame(() => {
      this.element.setAttribute("data-width", this.element.offsetWidth.toString())
      this._init()
      this._observe()
      this._bindKeys()
      this._bindArrows()
    })
  }

  disconnect() {
    this._observer?.disconnect()
    document.removeEventListener("keydown", this._onKeydown)
  }

  // ── Navigation publique ─────────────────────────────────────

  _navigateTo(index) {
    if (index === this._currentIndex || !this._items.length) return
    const width = parseInt(this.element.style.width) || window.innerWidth
    this.element.scrollTo({
      left: (index / this._items.length) * width,
      behavior: "smooth"
    })
  }

  // ── Flèches de navigation ───────────────────────────────────

  _bindArrows() {
    const wrap = this.element.parentElement
    if (!wrap) return
    wrap.querySelector(".coverflow-shelf__arrow--left")
      ?.addEventListener("click", () =>
        this._navigateTo(Math.max(0, this._currentIndex - 1)))
    wrap.querySelector(".coverflow-shelf__arrow--right")
      ?.addEventListener("click", () =>
        this._navigateTo(Math.min(this._items.length - 1, this._currentIndex + 1)))
  }

  // ── MutationObserver : nouvel item ajouté via Turbo Stream ──

  _observe() {
    this._observer = new MutationObserver((mutations) => {
      const hasNewReal = mutations.some(m =>
        Array.from(m.addedNodes).some(n => n.tagName && !this._syntheticEls.has(n))
      )
      if (hasNewReal) this._reinit()
    })
    this._observer.observe(this.element, { childList: true })
  }

  _reinit() {
    this._syntheticEls.forEach(el => el.remove())
    this._syntheticEls.clear()
    Array.from(this.element.childNodes)
      .filter(n => n.tagName)
      .forEach(n => n.removeAttribute("style"))
    this._currentIndex = 0
    this._init()
  }

  // ── Clavier : flèches gauche / droite ───────────────────────

  _bindKeys() {
    this._onKeydown = (e) => {
      const tag = document.activeElement?.tagName
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return
      if (document.activeElement?.isContentEditable) return

      if (e.key === "ArrowRight") {
        e.preventDefault()
        this._navigateTo(Math.min(this._items.length - 1, this._currentIndex + 1))
      } else if (e.key === "ArrowLeft") {
        e.preventDefault()
        this._navigateTo(Math.max(0, this._currentIndex - 1))
      }
    }
    document.addEventListener("keydown", this._onKeydown)
  }

  // ── Init principale ─────────────────────────────────────────

  _init() {
    const c       = this.element
    const imgSize = parseInt(c.dataset.size)    || 110
    const spacing = parseInt(c.dataset.spacing) || 16
    const shadow  = "shadow" in c.dataset
    const bgColor = c.dataset.bgcolor || "transparent"
    const flat    = "flat" in c.dataset
    const width   = parseInt(c.dataset.width)   || window.innerWidth

    const prefix = navigator.userAgent.includes("Firefox") ? "-moz-" : "-webkit-"

    const setTransform = (el, deg, persp, z) => {
      deg = Math.max(Math.min(deg, 90), -90)
      z  -= 5
      el.style["-webkit-perspective"] = el.style.perspective = persp + "px"
      el.style["-webkit-transform"]   = el.style.transform   = `rotateY(${deg}deg) translateZ(${z}px)`
    }

    const items = Array.from(c.childNodes).filter(n => n.tagName)
    this._items = items

    items.forEach(item => {
      item.style.position   = "absolute"
      item.style.width      = imgSize + "px"
      item.style.height     = "auto"
      item.style.bottom     = "60px"
      item.style.transition = `${prefix}transform .4s ease, margin-left .4s ease, -webkit-filter .4s ease`
      if (!shadow) item.style.boxShadow = "0 10px 30px rgba(0,0,0,0.3)"
    })

    c.style.backgroundColor = bgColor
    c.style.overflowX       = "scroll"
    c.style.position        = "relative"
    c.style.width           = width + "px"

    // Titre centré
    const titleBox = document.createElement("span")
    this._syntheticEls.add(titleBox)
    Object.assign(titleBox.style, {
      position: "absolute", bottom: "28px", textAlign: "center",
      width: (imgSize - 20) + "px", height: "20px", lineHeight: "20px",
      fontSize: "12px", padding: "0 4px",
      color: "#f0f0f5", background: "rgba(10,10,15,0.85)",
      borderRadius: "8px", fontFamily: "'DM Sans', sans-serif",
      letterSpacing: "0.02em", whiteSpace: "nowrap", overflow: "hidden",
      textOverflow: "ellipsis",
    })
    c.appendChild(titleBox)

    // Espace de défilement
    const placeholder = document.createElement("div")
    this._syntheticEls.add(placeholder)
    placeholder.style.cssText = `width:${width * 2}px;height:1px`
    c.appendChild(placeholder)

    setTransform(c, 0, 600, 0)

    const allImgs = items.flatMap(item =>
      item.tagName === "IMG" ? [item] : Array.from(item.querySelectorAll("img"))
    )

    const displayIndex = (index) => {
      this._currentIndex = index
      c.dataset.index    = index
      const mLeft = (width - imgSize) * 0.5 - spacing * (index + 1) - imgSize * 0.5
      const left  = c.scrollLeft

      items.forEach((item, i) => {
        item.style.left   = (left + i * spacing + spacing) + "px"
        item.style.cursor = i === index ? "pointer" : "default"

        if (i < index) {
          item.style.marginLeft        = mLeft + "px"
          item.style["-webkit-filter"] = item.style.filter = "brightness(0.55)"
          item.style.zIndex            = i + 1
          setTransform(item, flat ? 0 : (index - i) * 10 + 45, 300,
            flat ? -(index - i) * 10 : -(index - i) * 30 - 20)
        } else if (i === index) {
          item.style.marginLeft        = (mLeft + imgSize * 0.5) + "px"
          item.style["-webkit-filter"] = item.style.filter = "none"
          item.style.zIndex            = items.length
          setTransform(item, 0, 0, 5)
          titleBox.style.visibility = item.dataset.info ? "visible" : "hidden"
          if (item.dataset.info) {
            titleBox.innerHTML        = item.dataset.info
            titleBox.style.left       = (left + i * spacing + spacing + 10) + "px"
            titleBox.style.marginLeft = (mLeft + imgSize * 0.5) + "px"
          }
        } else {
          item.style.marginLeft        = (mLeft + imgSize) + "px"
          item.style["-webkit-filter"] = item.style.filter = "brightness(0.55)"
          item.style.zIndex            = items.length - i
          setTransform(item, flat ? 0 : (index - i) * 10 - 45, 300,
            flat ? (index - i) * 10 : (index - i) * 30 - 20)
        }
      })
    }

    const doLayout = () => {
      let imgHeight = 0
      items.forEach(item => {
        imgHeight = Math.max(imgHeight, item.getBoundingClientRect().height)
      })

      if (shadow) {
        c.style.height = (imgHeight * 2 + 80) + "px"
        c.style["-webkit-perspective-origin"] = c.style["perspective-origin"] = "50% 25%"
        items.forEach(item => {
          item.style.bottom = (20 + imgHeight) + "px"
          item.style["-webkit-box-reflect"] =
            "below 0 -webkit-gradient(linear, 30% 20%, 30% 100%, from(transparent), color-stop(0.3, transparent), to(rgba(0,0,0,0.85)))"
        })
      } else {
        c.style.height = (imgHeight + 80) + "px"
      }

      displayIndex(this._currentIndex)

      c.addEventListener("scroll", () => {
        const p     = c.scrollLeft / width
        const index = Math.min(Math.floor(p * items.length), items.length - 1)
        displayIndex(index)
      })

      items.forEach((item, i) => {
        item.addEventListener("click", (e) => {
          if (i !== this._currentIndex) {
            e.preventDefault()
            this._navigateTo(i)
          }
        })
      })
    }

    if (allImgs.every(img => img.complete)) {
      doLayout()
    } else {
      let loaded = 0
      const onLoad = () => { if (++loaded >= allImgs.length) doLayout() }
      allImgs.forEach(img => {
        img.addEventListener("load",  onLoad)
        img.addEventListener("error", onLoad)
      })
    }
  }
}
