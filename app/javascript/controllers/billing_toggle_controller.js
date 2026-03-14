import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyPrice", "annualPrice", "monthlyBtn", "annualBtn", "intervalField"]

  connect() {
    this.showMonthly()
  }

  showMonthly() {
    this.monthlyPriceTargets.forEach(el => el.classList.remove("hidden"))
    this.annualPriceTargets.forEach(el => el.classList.add("hidden"))
    this.monthlyBtnTarget.classList.add("bg-white", "shadow-sm", "dark:bg-gray-700")
    this.monthlyBtnTarget.classList.remove("text-gray-500")
    this.annualBtnTarget.classList.remove("bg-white", "shadow-sm", "dark:bg-gray-700")
    this.annualBtnTarget.classList.add("text-gray-500")
    this.intervalFieldTargets.forEach(el => el.value = "monthly")
  }

  showAnnual() {
    this.annualPriceTargets.forEach(el => el.classList.remove("hidden"))
    this.monthlyPriceTargets.forEach(el => el.classList.add("hidden"))
    this.annualBtnTarget.classList.add("bg-white", "shadow-sm", "dark:bg-gray-700")
    this.annualBtnTarget.classList.remove("text-gray-500")
    this.monthlyBtnTarget.classList.remove("bg-white", "shadow-sm", "dark:bg-gray-700")
    this.monthlyBtnTarget.classList.add("text-gray-500")
    this.intervalFieldTargets.forEach(el => el.value = "annual")
  }
}
