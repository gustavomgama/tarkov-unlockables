import { Controller } from "@hotwired/stimulus"

// Grid/table switch for the items index, remembered across visits.
export default class extends Controller {
  static targets = ["grid", "table", "button"]

  connect() {
    // A search or filter with no matches renders the empty state instead of the
    // grid and table, so the targets are absent: bail out rather than throwing
    // "Missing target element" on every zero-result page.
    if (!this.hasGridTarget || !this.hasTableTarget) return

    this.show(localStorage.getItem("items_view") === "table" ? "table" : "grid")
  }

  toggle(event) {
    this.show(event.currentTarget.dataset.view)
  }

  show(view) {
    const table = view === "table"
    this.gridTarget.classList.toggle("hidden", table)
    this.tableTarget.classList.toggle("hidden", !table)
    localStorage.setItem("items_view", view)

    this.buttonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String((button.dataset.view === "table") === table))
    })
  }
}
