import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mobileMenu", "navbar"]

  connect() {
    this.scrollHandler = this.onScroll.bind(this)
    window.addEventListener("scroll", this.scrollHandler, { passive: true })
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollHandler)
  }

  toggleMenu() {
    this.mobileMenuTarget.classList.toggle("hidden")
  }

  closeMenu() {
    this.mobileMenuTarget.classList.add("hidden")
  }

  onScroll() {
    if (window.scrollY > 20) {
      this.navbarTarget.classList.add("bg-white/95", "dark:bg-gray-900/95", "backdrop-blur-md", "shadow-sm")
      this.navbarTarget.classList.remove("bg-transparent")
    } else {
      this.navbarTarget.classList.remove("bg-white/95", "dark:bg-gray-900/95", "backdrop-blur-md", "shadow-sm")
      this.navbarTarget.classList.add("bg-transparent")
    }
  }

  scrollTo(event) {
    event.preventDefault()
    const targetId = event.currentTarget.getAttribute("href").substring(1)
    const target = document.getElementById(targetId)
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" })
      this.closeMenu()
    }
  }
}
