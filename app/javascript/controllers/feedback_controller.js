import { Controller } from "@hotwired/stimulus"

// Injects the utterances widget on first expand. Rendering the <script>
// eagerly would pull a third-party iframe into every page view, and an iframe
// sized while hidden inside a closed <details> collapses to zero height.
export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    // Browsers can restore a <details> as open on reload, which fires no toggle.
    this.load()
  }

  load() {
    if (this.loaded || !this.element.open) return

    this.loaded = true
    this.containerTarget.appendChild(this.templateTarget.content.cloneNode(true))
  }
}
