import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  handleInput() {
    // Strip non-digits
    const value = this.inputTarget.value.replace(/\D/g, "")
    this.inputTarget.value = value

    // Auto-submit when 6 digits entered
    if (value.length === 6) {
      this.element.requestSubmit()
    }
  }
}
