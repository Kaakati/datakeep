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

  showTab() {
    // Update tab styles
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === this.activeTabValue) {
        tab.classList.add("border-primary-500", "text-primary-600")
        tab.classList.remove("border-transparent", "text-gray-500", "hover:border-gray-300", "hover:text-gray-700")
      } else {
        tab.classList.remove("border-primary-500", "text-primary-600")
        tab.classList.add("border-transparent", "text-gray-500", "hover:border-gray-300", "hover:text-gray-700")
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
