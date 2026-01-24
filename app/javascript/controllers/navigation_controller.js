import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu", "openIcon", "closeIcon"]

  connect() {
    this.isOpen = false
  }

  toggle() {
    this.isOpen = !this.isOpen
    this.updateMenu()
  }

  updateMenu() {
    if (this.hasMobileMenuTarget) {
      if (this.isOpen) {
        this.mobileMenuTarget.classList.remove("hidden")
      } else {
        this.mobileMenuTarget.classList.add("hidden")
      }
    }

    if (this.hasOpenIconTarget && this.hasCloseIconTarget) {
      if (this.isOpen) {
        this.openIconTarget.classList.add("hidden")
        this.closeIconTarget.classList.remove("hidden")
      } else {
        this.openIconTarget.classList.remove("hidden")
        this.closeIconTarget.classList.add("hidden")
      }
    }
  }
}
