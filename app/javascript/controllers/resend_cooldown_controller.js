import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "countdown"]

  connect() {
    const remaining = this.remainingCooldown()
    if (remaining > 0) {
      this.startTimer(remaining)
    }
  }

  startCooldown() {
    const cooldownSeconds = 60
    sessionStorage.setItem("resend_cooldown_until", Date.now() + cooldownSeconds * 1000)
    this.startTimer(cooldownSeconds)
  }

  startTimer(seconds) {
    this.buttonTarget.disabled = true
    this.countdownTarget.hidden = false
    this.updateCountdown(seconds)

    this.interval = setInterval(() => {
      const remaining = this.remainingCooldown()
      if (remaining <= 0) {
        clearInterval(this.interval)
        this.buttonTarget.disabled = false
        this.countdownTarget.hidden = true
        sessionStorage.removeItem("resend_cooldown_until")
      } else {
        this.updateCountdown(remaining)
      }
    }, 1000)
  }

  updateCountdown(seconds) {
    this.countdownTarget.textContent = `You can resend in ${seconds} seconds`
  }

  remainingCooldown() {
    const until = parseInt(sessionStorage.getItem("resend_cooldown_until"), 10)
    if (!until) return 0
    return Math.max(0, Math.ceil((until - Date.now()) / 1000))
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
  }
}
