import { Controller } from "@hotwired/stimulus"

// Hides the source database from the list of target checkboxes
// so a user can't accidentally sync a database to itself.
export default class extends Controller {
  static targets = ["sourceSelect", "targetItem"]

  connect() {
    this.updateTargets()
  }

  updateTargets() {
    const sourceId = this.sourceSelectTarget.value

    this.targetItemTargets.forEach(item => {
      const dbId = item.dataset.dbId
      if (dbId === sourceId) {
        item.classList.add("hidden")
        // Uncheck and disable the hidden input so it isn't submitted
        const input = item.querySelector("input[type='checkbox']")
        if (input) {
          input.checked = false
          input.disabled = true
        }
      } else {
        item.classList.remove("hidden")
        const input = item.querySelector("input[type='checkbox']")
        if (input) {
          input.disabled = false
        }
      }
    })
  }
}
