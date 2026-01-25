import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: String }

  connect() {
    // Set initial active tab from URL hash or default to first tab
    const hash = window.location.hash.replace("#", "")
    if (hash && this.hasTab(hash)) {
      this.activeTabValue = hash
    } else if (!this.activeTabValue && this.tabTargets.length > 0) {
      this.activeTabValue = this.tabTargets[0].dataset.tab
    }
    this.showTab()
  }

  hasTab(name) {
    return this.tabTargets.some(tab => tab.dataset.tab === name)
  }

  switch(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tab
    this.activeTabValue = tab

    // Update URL hash without scrolling
    history.replaceState(null, null, `#${tab}`)
    this.showTab()
  }

  // Keyboard navigation for accessibility (roving tabindex)
  handleKeydown(event) {
    const currentIndex = this.tabTargets.findIndex(tab => tab === event.currentTarget)
    let newIndex = currentIndex

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        event.preventDefault()
        newIndex = (currentIndex + 1) % this.tabTargets.length
        break
      case "ArrowLeft":
      case "ArrowUp":
        event.preventDefault()
        newIndex = (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length
        break
      case "Home":
        event.preventDefault()
        newIndex = 0
        break
      case "End":
        event.preventDefault()
        newIndex = this.tabTargets.length - 1
        break
      default:
        return
    }

    // Focus and activate the new tab
    const newTab = this.tabTargets[newIndex]
    newTab.focus()
    this.activeTabValue = newTab.dataset.tab
    history.replaceState(null, null, `#${this.activeTabValue}`)
    this.showTab()
  }

  showTab() {
    // Update tab styles and ARIA attributes
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === this.activeTabValue

      if (isActive) {
        tab.classList.add("border-primary-500", "text-primary-600")
        tab.classList.remove("border-transparent", "text-gray-500", "hover:border-gray-300", "hover:text-gray-700")
        tab.setAttribute("aria-selected", "true")
        tab.setAttribute("tabindex", "0")
      } else {
        tab.classList.remove("border-primary-500", "text-primary-600")
        tab.classList.add("border-transparent", "text-gray-500", "hover:border-gray-300", "hover:text-gray-700")
        tab.setAttribute("aria-selected", "false")
        tab.setAttribute("tabindex", "-1")
      }
    })

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.tab === this.activeTabValue) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}
