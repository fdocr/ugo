import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "medium", "campaign", "term", "content", "preview", "urlField"]
  static values = { url: String }

  connect() {
    this.parseBaseUrl()
    this.buildUrl()
  }

  update() {
    this.buildUrl()
  }

  // Parse the existing URL, extract UTM params into inputs, store the clean base
  parseBaseUrl() {
    try {
      const url = new URL(this.urlValue)

      this.sourceTarget.value = url.searchParams.get("utm_source") || ""
      this.mediumTarget.value = url.searchParams.get("utm_medium") || ""
      this.campaignTarget.value = url.searchParams.get("utm_campaign") || ""
      this.termTarget.value = url.searchParams.get("utm_term") || ""
      this.contentTarget.value = url.searchParams.get("utm_content") || ""

      // Strip UTM params to get the clean base URL
      const utmKeys = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content"]
      utmKeys.forEach(key => url.searchParams.delete(key))
      this.cleanBaseUrl = url.toString()
    } catch(e) {
      this.cleanBaseUrl = this.urlValue
    }
  }

  // Rebuild the full URL from clean base + current field values
  buildUrl() {
    try {
      const url = new URL(this.cleanBaseUrl)

      const fields = [
        { key: "utm_source", target: this.sourceTarget },
        { key: "utm_medium", target: this.mediumTarget },
        { key: "utm_campaign", target: this.campaignTarget },
        { key: "utm_term", target: this.termTarget },
        { key: "utm_content", target: this.contentTarget }
      ]

      fields.forEach(({ key, target }) => {
        const value = target.value.trim()
        if (value) {
          url.searchParams.set(key, value)
        }
      })

      const fullUrl = url.toString()
      this.urlFieldTarget.value = fullUrl
      this.renderPreview(fullUrl)
    } catch(e) {
      this.previewTarget.innerHTML = `<span class="text-gray-400">${this.urlValue || "No URL set"}</span>`
    }
  }

  // Render the preview with color-coded UTM params
  renderPreview(fullUrl) {
    const [base, query] = fullUrl.split("?")
    if (!query) {
      this.previewTarget.innerHTML = `<span class="text-gray-700">${this.escapeHtml(base)}</span>`
      return
    }

    const params = new URLSearchParams(query)
    const utmKeys = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content"]
    const colors = {
      utm_source: "text-blue-600",
      utm_medium: "text-violet-600",
      utm_campaign: "text-emerald-600",
      utm_term: "text-amber-600",
      utm_content: "text-rose-500"
    }

    let parts = []
    let otherParams = []

    params.forEach((value, key) => {
      if (utmKeys.includes(key)) {
        parts.push(`<span class="${colors[key]} font-medium">${this.escapeHtml(key)}=${this.escapeHtml(value)}</span>`)
      } else {
        otherParams.push(`${this.escapeHtml(key)}=${this.escapeHtml(value)}`)
      }
    })

    let html = `<span class="text-gray-700">${this.escapeHtml(base)}</span>`
    const allParams = [...(otherParams.length ? [`<span class="text-gray-500">${otherParams.join("&amp;")}</span>`] : []), ...parts]
    if (allParams.length) {
      html += `<span class="text-gray-400">?</span>${allParams.join('<span class="text-gray-400">&amp;</span>')}`
    }

    this.previewTarget.innerHTML = html
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
