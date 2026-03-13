import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "label"]

  copy() {
    const text = this.hasSourceTarget ? this.sourceTarget.value : this.element.dataset.clipboardTextValue
    navigator.clipboard.writeText(text).then(() => {
      if (this.hasLabelTarget) {
        const original = this.labelTarget.textContent
        this.labelTarget.textContent = "Copied!"
        setTimeout(() => { this.labelTarget.textContent = original }, 2000)
      }
    })
  }
}
