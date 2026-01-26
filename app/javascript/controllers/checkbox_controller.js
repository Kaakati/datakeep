import { Controller } from "@hotwired/stimulus"

// Checkbox toggle controller for custom styled checkboxes
// Syncs visual state with hidden checkbox input
export default class extends Controller {
  static targets = ["input", "box"]
  static values = { checked: Boolean }
  static classes = ["checked", "unchecked"]

  connect() {
    // Initialize from input's current state
    if (this.hasInputTarget) {
      this.checkedValue = this.inputTarget.checked
      // Listen for changes on the input (triggered by label clicks)
      this.inputTarget.addEventListener("change", this.syncFromInput.bind(this))
    }
    this.updateVisual()
  }

  disconnect() {
    if (this.hasInputTarget) {
      this.inputTarget.removeEventListener("change", this.syncFromInput.bind(this))
    }
  }

  // Sync our state from the actual input value
  syncFromInput() {
    if (this.hasInputTarget) {
      this.checkedValue = this.inputTarget.checked
      this.updateVisual()
    }
  }

  checkedValueChanged() {
    this.updateVisual()
  }

  updateVisual() {
    if (!this.hasBoxTarget) return

    if (this.checkedValue) {
      // Add checked classes, remove unchecked classes
      if (this.hasCheckedClass) {
        this.checkedClasses.forEach(cls => this.boxTarget.classList.add(cls))
      }
      if (this.hasUncheckedClass) {
        this.uncheckedClasses.forEach(cls => this.boxTarget.classList.remove(cls))
      }
      // Show checkmark
      const checkmark = this.boxTarget.querySelector("[data-checkmark]")
      if (checkmark) {
        checkmark.classList.remove("opacity-0")
      }
    } else {
      // Remove checked classes, add unchecked classes
      if (this.hasCheckedClass) {
        this.checkedClasses.forEach(cls => this.boxTarget.classList.remove(cls))
      }
      if (this.hasUncheckedClass) {
        this.uncheckedClasses.forEach(cls => this.boxTarget.classList.add(cls))
      }
      // Hide checkmark
      const checkmark = this.boxTarget.querySelector("[data-checkmark]")
      if (checkmark) {
        checkmark.classList.add("opacity-0")
      }
    }
  }
}
