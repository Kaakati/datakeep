import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "backdrop", "collapseIcon", "expandIcon"]
  static values = { collapsed: Boolean, mobileOpen: Boolean }

  connect() {
    // Restore collapsed state from localStorage (desktop only)
    const savedState = localStorage.getItem("sidebar-collapsed")
    if (savedState !== null) {
      this.collapsedValue = savedState === "true"
    }
    this.updateCollapsedState()

    // Bind escape key handler
    this.boundEscapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.boundEscapeHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundEscapeHandler)
    this.unlockBodyScroll()
  }

  // Desktop: Toggle collapsed state
  toggleCollapse() {
    this.collapsedValue = !this.collapsedValue
    localStorage.setItem("sidebar-collapsed", this.collapsedValue.toString())
    this.updateCollapsedState()
  }

  // Mobile: Open sidebar
  openMobile() {
    this.mobileOpenValue = true
    this.updateMobileState()
    this.lockBodyScroll()
  }

  // Mobile: Close sidebar
  closeMobile() {
    this.mobileOpenValue = false
    this.updateMobileState()
    this.unlockBodyScroll()
  }

  // Handle navigation link click (close mobile sidebar)
  navigate() {
    if (this.mobileOpenValue) {
      this.closeMobile()
    }
  }

  // Close on Escape key
  handleEscape(event) {
    if (event.key === "Escape" && this.mobileOpenValue) {
      this.closeMobile()
    }
  }

  // Close on backdrop click
  backdropClick() {
    this.closeMobile()
  }

  updateCollapsedState() {
    if (!this.hasSidebarTarget) return

    const sidebar = this.sidebarTarget

    if (this.collapsedValue) {
      // Collapsed state - add sidebar-collapsed class for CSS-based hiding
      sidebar.classList.add("sidebar-collapsed")
      sidebar.classList.remove("lg:w-[290px]")
      sidebar.classList.add("lg:w-[90px]")

      // Toggle collapse/expand icons
      if (this.hasCollapseIconTarget) this.collapseIconTarget.classList.add("hidden")
      if (this.hasExpandIconTarget) this.expandIconTarget.classList.remove("hidden")
    } else {
      // Expanded state - remove sidebar-collapsed class
      sidebar.classList.remove("sidebar-collapsed")
      sidebar.classList.remove("lg:w-[90px]")
      sidebar.classList.add("lg:w-[290px]")

      // Toggle collapse/expand icons
      if (this.hasCollapseIconTarget) this.collapseIconTarget.classList.remove("hidden")
      if (this.hasExpandIconTarget) this.expandIconTarget.classList.add("hidden")
    }
  }

  updateMobileState() {
    if (!this.hasSidebarTarget || !this.hasBackdropTarget) return

    const sidebar = this.sidebarTarget
    const backdrop = this.backdropTarget

    if (this.mobileOpenValue) {
      // Open state
      sidebar.classList.remove("-translate-x-full")
      sidebar.classList.add("translate-x-0")
      backdrop.classList.remove("hidden")
      sidebar.setAttribute("aria-hidden", "false")

      // Focus first focusable element in sidebar
      const firstFocusable = sidebar.querySelector('a, button')
      if (firstFocusable) {
        firstFocusable.focus()
      }
    } else {
      // Closed state
      sidebar.classList.remove("translate-x-0")
      sidebar.classList.add("-translate-x-full")
      backdrop.classList.add("hidden")
      sidebar.setAttribute("aria-hidden", "true")
    }
  }

  lockBodyScroll() {
    document.body.classList.add("overflow-hidden", "lg:overflow-auto")
  }

  unlockBodyScroll() {
    document.body.classList.remove("overflow-hidden", "lg:overflow-auto")
  }
}
