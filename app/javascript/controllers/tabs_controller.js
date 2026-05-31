import { Controller } from "@hotwired/stimulus"

// Toggles a `data-state="active"` attribute on tab buttons and a `hidden`
// class on panels. All visual styling lives in CSS (.ui-tab) so the design
// system stays in one place.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { default: String }

  connect() {
    this.showTab(this.defaultValue || this.tabTargets[0]?.dataset.tab)
  }

  select(event) {
    event.preventDefault()
    this.showTab(event.currentTarget.dataset.tab)
  }

  showTab(tabName) {
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      if (isActive) {
        tab.dataset.state = "active"
      } else {
        delete tab.dataset.state
      }
    })

    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.tab === tabName
      panel.classList.toggle("hidden", !isActive)

      if (isActive) {
        const frame = panel.querySelector("turbo-frame[loading='lazy']")
        if (frame && !frame.hasAttribute("src-loaded")) {
          frame.setAttribute("src-loaded", "true")
          frame.reload()
        }
      }
    })
  }
}
