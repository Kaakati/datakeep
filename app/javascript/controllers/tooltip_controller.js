import { Controller } from "@hotwired/stimulus"

// Tooltip controller for showing contextual help on hover
// Usage:
// <div data-controller="tooltip" data-tooltip-content-value="This is the tooltip text">
//   Hover over me
// </div>
export default class extends Controller {
  static values = {
    content: String,
    position: { type: String, default: "top" }
  }

  connect() {
    this.tooltip = null
    this.element.addEventListener("mouseenter", this.show.bind(this))
    this.element.addEventListener("mouseleave", this.hide.bind(this))
    this.element.addEventListener("focus", this.show.bind(this))
    this.element.addEventListener("blur", this.hide.bind(this))
  }

  disconnect() {
    this.hide()
    this.element.removeEventListener("mouseenter", this.show.bind(this))
    this.element.removeEventListener("mouseleave", this.hide.bind(this))
    this.element.removeEventListener("focus", this.show.bind(this))
    this.element.removeEventListener("blur", this.hide.bind(this))
  }

  show() {
    if (this.tooltip) return

    this.tooltip = document.createElement("div")
    this.tooltip.className = "absolute z-50 px-2 py-1 text-xs font-medium text-white bg-gray-900 rounded shadow-lg whitespace-nowrap dark:bg-gray-700"
    this.tooltip.textContent = this.contentValue
    this.tooltip.setAttribute("role", "tooltip")

    // Position relative to element
    document.body.appendChild(this.tooltip)
    this.positionTooltip()
  }

  hide() {
    if (this.tooltip) {
      this.tooltip.remove()
      this.tooltip = null
    }
  }

  positionTooltip() {
    if (!this.tooltip) return

    const rect = this.element.getBoundingClientRect()
    const tooltipRect = this.tooltip.getBoundingClientRect()

    let top, left

    switch (this.positionValue) {
      case "bottom":
        top = rect.bottom + 8 + window.scrollY
        left = rect.left + (rect.width / 2) - (tooltipRect.width / 2) + window.scrollX
        break
      case "left":
        top = rect.top + (rect.height / 2) - (tooltipRect.height / 2) + window.scrollY
        left = rect.left - tooltipRect.width - 8 + window.scrollX
        break
      case "right":
        top = rect.top + (rect.height / 2) - (tooltipRect.height / 2) + window.scrollY
        left = rect.right + 8 + window.scrollX
        break
      default: // top
        top = rect.top - tooltipRect.height - 8 + window.scrollY
        left = rect.left + (rect.width / 2) - (tooltipRect.width / 2) + window.scrollX
    }

    // Keep tooltip within viewport
    const padding = 8
    if (left < padding) left = padding
    if (left + tooltipRect.width > window.innerWidth - padding) {
      left = window.innerWidth - tooltipRect.width - padding
    }

    this.tooltip.style.top = `${top}px`
    this.tooltip.style.left = `${left}px`
  }
}
