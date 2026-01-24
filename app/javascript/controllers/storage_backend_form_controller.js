import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "localFields", "s3Fields"]

  connect() {
    this.toggleStorageType()
  }

  toggleStorageType() {
    const storageType = this.typeSelectTarget?.value || ""

    // Hide and disable all storage-specific fields first
    this.hideAllFields()

    // Show and enable the relevant fields based on type
    if (storageType === "s3") {
      if (this.hasS3FieldsTarget) this.showFields(this.s3FieldsTarget)
    } else {
      if (this.hasLocalFieldsTarget) this.showFields(this.localFieldsTarget)
    }
  }

  hideAllFields() {
    if (this.hasLocalFieldsTarget) this.hideFields(this.localFieldsTarget)
    if (this.hasS3FieldsTarget) this.hideFields(this.s3FieldsTarget)
  }

  hideFields(container) {
    container.classList.add("hidden")
    // Disable all inputs so they don't get submitted
    container.querySelectorAll("input, select, textarea").forEach(input => {
      input.disabled = true
    })
  }

  showFields(container) {
    container.classList.remove("hidden")
    // Re-enable all inputs
    container.querySelectorAll("input, select, textarea").forEach(input => {
      input.disabled = false
    })
  }
}
