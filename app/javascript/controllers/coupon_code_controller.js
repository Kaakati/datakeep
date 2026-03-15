import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "feedback", "hiddenFields"]

  apply() {
    const code = this.inputTarget.value.trim().toUpperCase()

    if (!code) {
      this.showFeedback("Please enter a coupon code.", "text-red-500")
      return
    }

    this.inputTarget.value = code
    this.hiddenFieldsTargets.forEach(field => field.value = code)
    this.showFeedback(`Coupon "${code}" will be applied at checkout.`, "text-green-600 dark:text-green-400")
  }

  clear() {
    this.inputTarget.value = ""
    this.hiddenFieldsTargets.forEach(field => field.value = "")
    this.hideFeedback()
  }

  showFeedback(message, cssClass) {
    this.feedbackTarget.textContent = message
    this.feedbackTarget.className = `text-sm ${cssClass}`
    this.feedbackTarget.classList.remove("hidden")
  }

  hideFeedback() {
    this.feedbackTarget.classList.add("hidden")
  }
}
