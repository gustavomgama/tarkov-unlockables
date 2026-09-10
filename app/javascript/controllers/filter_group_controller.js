import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]
  static values = { open: Boolean }

  toggle(event) {
    event.stopPropagation()
    if (this.openValue) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.positionDropdown()
    this.dropdownTarget.classList.remove("hidden")
    this.openValue = true
  }

  close() {
    this.dropdownTarget.classList.add("hidden")
    this.openValue = false
  }

  positionDropdown() {
    const button = this.element.querySelector("button")
    const rect = button.getBoundingClientRect()
    this.dropdownTarget.style.left = `${rect.left}px`
    this.dropdownTarget.style.top = `${rect.bottom + 4}px`
  }

  hide(event) {
    if (this.openValue && !this.element.contains(event.target)) {
      this.close()
    }
  }

  onScroll() {
    if (this.openValue) {
      this.close()
    }
  }

  connect() {
    this._hideHandler = (e) => this.hide(e)
    this._scrollHandler = () => this.onScroll()
    document.addEventListener("click", this._hideHandler)
    window.addEventListener("scroll", this._scrollHandler, { passive: true })
  }

  disconnect() {
    document.removeEventListener("click", this._hideHandler)
    window.removeEventListener("scroll", this._scrollHandler)
  }
}
