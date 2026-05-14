import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]

  openIfModal(e) {
    if (e.target.id === "modal") this.element.removeAttribute("hidden")
  }

  close() {
    this.element.setAttribute("hidden", "")
    this.frameTarget.innerHTML = ""
  }

  closeOnBackdrop(e) {
    if (e.target === this.element) this.close()
  }
}
