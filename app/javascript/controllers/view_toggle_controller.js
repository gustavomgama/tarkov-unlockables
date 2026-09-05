import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "table"]

  initialize() {
    const saved = localStorage.getItem("items_view")
    if (saved === "table") {
      this.showTable()
    }
  }

  toggle(event) {
    const view = event.currentTarget.dataset.view
    localStorage.setItem("items_view", view)
    if (view === "table") {
      this.showTable()
    } else {
      this.showGrid()
    }
  }

  showGrid() {
    this.gridTarget.classList.remove("hidden")
    this.tableTarget.classList.add("hidden")
  }

  showTable() {
    this.gridTarget.classList.add("hidden")
    this.tableTarget.classList.remove("hidden")
  }
}
