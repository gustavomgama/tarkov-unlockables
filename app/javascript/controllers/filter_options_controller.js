import { Controller } from "@hotwired/stimulus"

// Narrows a long filter menu (Category has ~100 options) as you type. The
// options are already in the DOM, so this only toggles visibility. Without
// JavaScript the menu still scrolls, which is what it did before.
export default class extends Controller {
  static targets = ["input", "option"]

  filter() {
    const term = this.inputTarget.value.trim().toLowerCase()

    this.optionTargets.forEach((option) => {
      option.hidden = term !== "" && !option.dataset.label.includes(term)
    })
  }

  clear() {
    this.inputTarget.value = ""
    this.filter()
  }

  // The box lives inside the filter form; Enter would submit it.
  stopEnter(event) {
    if (event.key === "Enter") event.preventDefault()
  }
}
