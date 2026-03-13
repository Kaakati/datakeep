import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "row"]

  connect() {
    this.index = this.rowTargets.length
    // Add initial row if none exist
    if (this.index === 0) {
      this.addRow()
    }
  }

  addRow() {
    const html = this.templateTarget.innerHTML.replace(/INDEX/g, this.index)
    this.containerTarget.insertAdjacentHTML("beforeend", html)
    this.index++
  }

  removeRow(event) {
    const row = event.target.closest("[data-database-builder-target='row']")
    if (row && this.rowTargets.length > 1) {
      row.remove()
    }
  }
}
