import { Controller } from "@hotwired/stimulus"

// Shows/hides VPN configuration fields based on the vpn_enabled checkbox.
export default class extends Controller {
  static targets = ["fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    const checkbox = this.element.querySelector("[data-vpn-checkbox]")
    if (!checkbox) return

    this.fieldsTarget.classList.toggle("hidden", !checkbox.checked)

    // Disable hidden inputs so they aren't submitted with blank values
    const inputs = this.fieldsTarget.querySelectorAll("input, select, textarea")
    inputs.forEach(input => {
      input.disabled = !checkbox.checked
    })
  }
}
