import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  toggle() {
    this.dropdownTarget.classList.toggle("hidden")
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
    }
  }

  connect() {
    document.addEventListener("click", (e) => this.hide(e))
  }

  disconnect() {
    document.removeEventListener("click", (e) => this.hide(e))
  }
}
