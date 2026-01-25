import { Controller } from "@hotwired/stimulus"

// Parses database connection URLs and populates form fields
// Supports PostgreSQL URLs in format: postgresql://user:password@host:port/database?sslmode=require
export default class extends Controller {
  static targets = ["url", "host", "port", "database", "username", "password", "sslMode"]

  connect() {
    // Initialize - if URL is filled but fields are empty, parse on load
    if (this.hasUrlTarget && this.urlTarget.value) {
      this.parse()
    }
  }

  parse() {
    const url = this.urlTarget.value.trim()

    if (!url) {
      return
    }

    try {
      const parsed = this.parseConnectionUrl(url)

      if (parsed) {
        this.populateFields(parsed)
        this.showSuccess()
      }
    } catch (error) {
      this.showError(error.message)
    }
  }

  parseConnectionUrl(url) {
    // Handle various URL formats:
    // postgresql://user:pass@host:port/database?sslmode=require
    // postgres://user:pass@host:port/database
    // postgresql://user@host/database (no password)
    // postgresql://host:port/database (no auth)

    // Normalize the protocol
    let normalizedUrl = url
    if (url.startsWith('postgres://')) {
      normalizedUrl = url.replace('postgres://', 'postgresql://')
    }

    if (!normalizedUrl.startsWith('postgresql://')) {
      throw new Error('URL must start with postgresql:// or postgres://')
    }

    try {
      // Use URL API for parsing (need to temporarily change protocol for parsing)
      const tempUrl = normalizedUrl.replace('postgresql://', 'http://')
      const parsedUrl = new URL(tempUrl)

      const result = {
        host: parsedUrl.hostname || '',
        port: parsedUrl.port || '5432',
        database: parsedUrl.pathname.slice(1) || '', // Remove leading /
        username: parsedUrl.username ? decodeURIComponent(parsedUrl.username) : '',
        password: parsedUrl.password ? decodeURIComponent(parsedUrl.password) : '',
        sslMode: ''
      }

      // Parse query params for sslmode
      const sslMode = parsedUrl.searchParams.get('sslmode')
      if (sslMode) {
        result.sslMode = sslMode
      }

      return result
    } catch (e) {
      throw new Error('Invalid URL format. Example: postgresql://user:password@host:port/database')
    }
  }

  populateFields(parsed) {
    if (this.hasHostTarget && parsed.host) {
      this.hostTarget.value = parsed.host
      this.triggerChange(this.hostTarget)
    }

    if (this.hasPortTarget && parsed.port) {
      this.portTarget.value = parsed.port
      this.triggerChange(this.portTarget)
    }

    if (this.hasDatabaseTarget && parsed.database) {
      this.databaseTarget.value = parsed.database
      this.triggerChange(this.databaseTarget)
    }

    if (this.hasUsernameTarget && parsed.username) {
      this.usernameTarget.value = parsed.username
      this.triggerChange(this.usernameTarget)
    }

    if (this.hasPasswordTarget && parsed.password) {
      this.passwordTarget.value = parsed.password
      this.triggerChange(this.passwordTarget)
    }

    if (this.hasSslModeTarget && parsed.sslMode) {
      this.sslModeTarget.value = parsed.sslMode
      this.triggerChange(this.sslModeTarget)
    }
  }

  triggerChange(element) {
    element.dispatchEvent(new Event('change', { bubbles: true }))
  }

  showSuccess() {
    // Brief visual feedback
    this.urlTarget.classList.remove('border-red-500', 'dark:border-red-500')
    this.urlTarget.classList.add('border-green-500', 'dark:border-green-500')

    setTimeout(() => {
      this.urlTarget.classList.remove('border-green-500', 'dark:border-green-500')
    }, 2000)
  }

  showError(message) {
    this.urlTarget.classList.remove('border-green-500', 'dark:border-green-500')
    this.urlTarget.classList.add('border-red-500', 'dark:border-red-500')

    // Could also show a toast or inline error message
    console.warn('Database URL parse error:', message)
  }

  clear() {
    this.urlTarget.value = ''
    this.urlTarget.classList.remove('border-green-500', 'dark:border-green-500', 'border-red-500', 'dark:border-red-500')
  }
}
