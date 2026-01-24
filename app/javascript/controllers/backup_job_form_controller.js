import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cronField", "scheduleSelect"]

  connect() {
    this.toggleCronField()
  }

  toggleCronField() {
    const scheduleType = this.scheduleSelectTarget?.value || ""
    const cronField = document.getElementById("cron-field")

    if (cronField) {
      if (scheduleType === "custom") {
        cronField.classList.remove("hidden")
      } else {
        cronField.classList.add("hidden")
      }
    }
  }
}
