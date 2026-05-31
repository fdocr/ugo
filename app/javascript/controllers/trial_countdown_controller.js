import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]
  static values = { endAt: String }

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  tick() {
    if (!this.hasLabelTarget || !this.endAtValue) return

    const end = Date.parse(this.endAtValue)
    if (Number.isNaN(end)) return

    const ms = Math.max(0, end - Date.now())
    if (ms === 0) {
      this.labelTarget.textContent = "Trial ended"
      if (this.timer) clearInterval(this.timer)
      return
    }

    const totalSeconds = Math.floor(ms / 1000)
    const days = Math.floor(totalSeconds / 86400)
    const hours = Math.floor((totalSeconds % 86400) / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60

    const parts = []
    if (days > 0) parts.push(`${days}d`)
    if (hours > 0 || days > 0) parts.push(`${hours}h`)
    parts.push(`${minutes}m`, `${seconds.toString().padStart(2, "0")}s`)
    this.labelTarget.textContent = parts.join(" ")
  }
}
