import { Controller } from "@hotwired/stimulus"
import { useDebounce } from "stimulus-use"

export default class extends Controller {
  static targets = ["input", "results", "loading"]
  static debounceDelay = 300

  connect() {
    useDebounce(this, { wait: this.debounceDelay })
  }

  async search(event) {
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.resultsTarget.classList.add("hidden")
      return
    }

    this.loadingTarget?.classList.remove("hidden")

    try {
      const response = await fetch(`/items/autocomplete?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.resultsTarget.innerHTML = html
        this.resultsTarget.classList.remove("hidden")
      }
    } catch (error) {
      console.error("Search failed:", error)
    } finally {
      this.loadingTarget?.classList.add("hidden")
    }
  }

  hideResults() {
    setTimeout(() => {
      this.resultsTarget.classList.add("hidden")
    }, 200)
  }

  selectResult(event) {
    const link = event.target.closest("a")
    if (link) {
      window.location.href = link.href
    }
  }
}
