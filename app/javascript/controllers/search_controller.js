import { Controller } from "@hotwired/stimulus"

// Typeahead for the item search field. The server renders the result rows and
// this only fetches and shows them, so the row markup has one home. Without
// JavaScript the field is a plain form input and Enter still searches.
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String, minLength: { type: Number, default: 2 } }

  connect() {
    this.hide()
    this._outside = (event) => {
      if (this.element.contains(event.target) && !this.resultsTarget.contains(event.target)) return
      if (!this.element.contains(event.target)) this.hide()
    }
    document.addEventListener("click", this._outside)
  }

  disconnect() {
    document.removeEventListener("click", this._outside)
    clearTimeout(this.timer)
  }

  query() {
    clearTimeout(this.timer)
    const term = this.inputTarget.value.trim()
    if (term.length < this.minLengthValue) return this.hide()

    this.timer = setTimeout(() => this.fetchResults(term), 150)
  }

  async fetchResults(term) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", term)

    let response
    try {
      response = await fetch(url, { headers: { Accept: "text/html" } })
    } catch {
      return this.hide()
    }
    if (!response.ok) return this.hide()

    // A stale response can land after a newer keystroke.
    if (this.inputTarget.value.trim() !== term) return

    if (response.status === 204) return this.showNoMatches(term)

    const html = await response.text()
    if (html.trim() === "") return this.hide()

    this.resultsTarget.innerHTML = html
    this.show()
  }

  showNoMatches(term) {
    const message = document.createElement("p")
    message.className = "px-3 py-2 text-xs text-[var(--text-muted)]"
    // textContent, so a typed angle bracket cannot become markup.
    message.textContent = `No matches for “${term}”`
    this.resultsTarget.replaceChildren(message)
    this.show()
  }

  show() {
    this.resultsTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  hide() {
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.add("hidden")
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.hide()
      return
    }
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return

    const links = Array.from(this.resultsTarget.querySelectorAll("a"))
    if (links.length === 0) return

    event.preventDefault()
    const index = links.indexOf(document.activeElement)
    const next = event.key === "ArrowDown" ? index + 1 : index - 1
    links[(next + links.length) % links.length].focus()
  }
}
