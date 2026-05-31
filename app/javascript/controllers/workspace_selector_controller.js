import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.updateForm()
  }

  updateForm() {
    const selectedWorkspace = this.selectTarget.value
    if (selectedWorkspace) {
      this.element.action = `/workspace/${selectedWorkspace}/links`
    }
  }
} 