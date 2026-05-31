import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const selectedMethod = event.currentTarget.dataset.method
    
    // Update tab states
    this.tabTargets.forEach((tab) => {
      tab.dataset.state = tab.dataset.method === selectedMethod ? "active" : "inactive"
    })

    // Show/hide panels
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.method !== selectedMethod)
    })
  }
} 