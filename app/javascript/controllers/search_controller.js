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
    this._hotkey = (event) => this.focusOnSlash(event)
    document.addEventListener("click", this._outside)
    document.addEventListener("keydown", this._hotkey)
  }

  disconnect() {
    document.removeEventListener("click", this._outside)
    document.removeEventListener("keydown", this._hotkey)
    clearTimeout(this.timer)
  }

  // "/" jumps to the search field, the way a docs site does it. Skipped while
  // the user is already typing somewhere.
  focusOnSlash(event) {
    if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey) return
    const active = document.activeElement
    if (active && (active.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(active.tagName))) return

    event.preventDefault()
    this.inputTarget.focus()
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
  }

  hide() {
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.add("hidden")
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
    const current = links.indexOf(document.activeElement)
    const step = event.key === "ArrowDown" ? 1 : -1
    // Nothing in the list is focused yet (current is -1): down starts at the
    // first entry, up wraps onto the last.
    const next = current === -1 ? (step === 1 ? 0 : links.length - 1) : current + step
    links[(next + links.length) % links.length].focus()
  }
}
