import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = null
  }

  changed() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.closest("form").requestSubmit()
    }, 400)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
