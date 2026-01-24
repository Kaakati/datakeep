import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.isOpen = false
    document.addEventListener("click", this.closeOnClickOutside.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside.bind(this))
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen = !this.isOpen
    this.updateMenu()
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target) && this.isOpen) {
      this.isOpen = false
      this.updateMenu()
    }
  }

  updateMenu() {
    if (this.hasMenuTarget) {
      if (this.isOpen) {
        this.menuTarget.classList.remove("hidden")
      } else {
        this.menuTarget.classList.add("hidden")
      }
    }
  }
}
