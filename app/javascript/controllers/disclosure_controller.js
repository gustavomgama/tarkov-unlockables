import { Controller } from "@hotwired/stimulus"

// Shared behaviour for native <details> disclosures (site menu, filter
// groups, unlock-path chains, feedback). <details>/<summary> already work
// without JavaScript and announce their own expanded state, so this only
// adds the two conveniences the native element lacks: Escape closes and
// returns focus, and a click outside closes.
export default class extends Controller {
  close() {
    this.element.open = false
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.element.open) return

    event.stopPropagation()
    this.close()
    this.summary()?.focus()
  }

  closeOnOutsideClick(event) {
    if (this.element.open && !this.element.contains(event.target)) this.close()
  }

  summary() {
    return this.element.querySelector(":scope > summary")
  }
}
