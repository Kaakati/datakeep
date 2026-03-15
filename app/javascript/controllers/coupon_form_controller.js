import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["discountType", "currencyField", "durationSelect", "durationMonthsField", "valueHint"]

  toggleDiscountType() {
    const isAmountOff = this.discountTypeTarget.value === "amount_off"
    this.currencyFieldTarget.classList.toggle("hidden", !isAmountOff)

    if (this.hasValueHintTarget) {
      this.valueHintTarget.textContent = isAmountOff
        ? "Amount in cents (e.g. 500 = $5.00)"
        : "Percentage (1-100)"
    }
  }

  toggleDuration() {
    const isRepeating = this.durationSelectTarget.value === "repeating"
    this.durationMonthsFieldTarget.classList.toggle("hidden", !isRepeating)
  }
}
