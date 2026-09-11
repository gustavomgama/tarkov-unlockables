import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "icon"]

  toggle() {
    const open = this.menuTarget.classList.toggle("hidden") === false
    this.element.querySelector("button").setAttribute("aria-expanded", open)
  }
}
