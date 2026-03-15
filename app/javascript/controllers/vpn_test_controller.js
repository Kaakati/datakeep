import { Controller } from "@hotwired/stimulus"

// Handles the "Test VPN Connection" button in the database config form.
// POSTs VPN params to test_vpn, polls test_vpn_result for status.
export default class extends Controller {
  static targets = ["button", "spinner", "result", "resultText"]
  static values = {
    testUrl: String,
    resultUrl: String
  }

  async test(event) {
    event.preventDefault()

    this.showSpinner()

    const form = this.element.closest("form")
    const formData = new FormData(form)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.testUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: formData
      })

      if (!response.ok) {
        this.showResult("failed", "Server error — please try again")
        return
      }

      const data = await response.json()
      this.pollForResult(data.request_id)
    } catch (error) {
      this.showResult("failed", `Request failed: ${error.message}`)
    }
  }

  pollForResult(requestId) {
    this.pollCount = 0
    this.pollInterval = setInterval(() => {
      this.pollCount++

      if (this.pollCount > 30) {
        clearInterval(this.pollInterval)
        this.showResult("failed", "Timeout — no response after 60s")
        return
      }

      this.checkResult(requestId)
    }, 2000)
  }

  async checkResult(requestId) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const url = `${this.resultUrlValue}?request_id=${requestId}`
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        }
      })

      if (!response.ok) return

      const data = await response.json()

      if (data.status === "pending") return

      clearInterval(this.pollInterval)
      this.showResult(data.status, data.message)
    } catch {
      // Retry on next poll
    }
  }

  showSpinner() {
    this.buttonTarget.disabled = true
    this.spinnerTarget.classList.remove("hidden")
    this.resultTarget.classList.add("hidden")
  }

  showResult(status, message) {
    this.buttonTarget.disabled = false
    this.spinnerTarget.classList.add("hidden")
    this.resultTarget.classList.remove("hidden")

    this.resultTextTarget.textContent = message

    // Reset classes
    this.resultTarget.classList.remove(
      "bg-green-50", "text-green-700", "border-green-200",
      "bg-red-50", "text-red-700", "border-red-200",
      "dark:bg-green-900/20", "dark:text-green-300", "dark:border-green-800",
      "dark:bg-red-900/20", "dark:text-red-300", "dark:border-red-800"
    )

    if (status === "success") {
      this.resultTarget.classList.add(
        "bg-green-50", "text-green-700", "border-green-200",
        "dark:bg-green-900/20", "dark:text-green-300", "dark:border-green-800"
      )
    } else {
      this.resultTarget.classList.add(
        "bg-red-50", "text-red-700", "border-red-200",
        "dark:bg-red-900/20", "dark:text-red-300", "dark:border-red-800"
      )
    }
  }

  disconnect() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }
}
