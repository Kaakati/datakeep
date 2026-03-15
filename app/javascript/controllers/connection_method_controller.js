import { Controller } from "@hotwired/stimulus"

// Manages the connection method card selector and conditional field visibility.
// Replaces the old vpn-toggle controller with a narrative UI approach.
export default class extends Controller {
  static targets = [
    "card",
    "vpnEnabledField",
    "vpnTypeField",
    "vpnFields",
    "ipsecSimpleFields",
    "sshFields",
    "proxyFields",
    "testSection"
  ]

  static values = {
    selected: { type: String, default: "direct" }
  }

  connect() {
    this.selectedValueChanged()
  }

  select(event) {
    const card = event.currentTarget
    const method = card.dataset.method

    this.selectedValue = method
  }

  selectedValueChanged() {
    // Update card visual states
    this.cardTargets.forEach(card => {
      const isSelected = card.dataset.method === this.selectedValue
      card.dataset.selected = isSelected

      if (isSelected) {
        card.classList.add("border-primary-500", "bg-primary-50/50", "dark:bg-primary-900/10", "dark:border-primary-700")
        card.classList.remove("border-gray-200", "dark:border-gray-700", "hover:border-gray-300")
        card.setAttribute("aria-checked", "true")
        const checkIcon = card.querySelector("[data-check-icon]")
        if (checkIcon) checkIcon.style.display = ""
      } else {
        card.classList.remove("border-primary-500", "bg-primary-50/50", "dark:bg-primary-900/10", "dark:border-primary-700")
        card.classList.add("border-gray-200", "dark:border-gray-700", "hover:border-gray-300")
        card.setAttribute("aria-checked", "false")
        const checkIcon = card.querySelector("[data-check-icon]")
        if (checkIcon) checkIcon.style.display = "none"
      }
    })

    // Set hidden form fields
    const isDirect = this.selectedValue === "direct"
    this.vpnEnabledFieldTarget.value = isDirect ? "0" : "1"
    this.vpnTypeFieldTarget.value = isDirect ? "" : this.selectedValue

    // Show/hide protocol-specific fields
    const vpnProtocols = ["openvpn", "ipsec", "wireguard"]
    const isVpn = vpnProtocols.includes(this.selectedValue)
    const isIpsecSimple = this.selectedValue === "ipsec_simple"
    const isSsh = this.selectedValue === "ssh_tunnel"
    const isProxy = ["socks5_proxy", "http_proxy"].includes(this.selectedValue)

    this.vpnFieldsTarget.classList.toggle("hidden", !isVpn)
    this.ipsecSimpleFieldsTarget.classList.toggle("hidden", !isIpsecSimple)
    this.sshFieldsTarget.classList.toggle("hidden", !isSsh)
    this.proxyFieldsTarget.classList.toggle("hidden", !isProxy)

    // Toggle disabled state on hidden inputs
    this.toggleInputs(this.vpnFieldsTarget, isVpn)
    this.toggleInputs(this.ipsecSimpleFieldsTarget, isIpsecSimple)
    this.toggleInputs(this.sshFieldsTarget, isSsh)
    this.toggleInputs(this.proxyFieldsTarget, isProxy)

    // Show test section for non-direct methods
    this.testSectionTarget.classList.toggle("hidden", isDirect)
  }

  // Extract credentials from a pasted config file (swanctl.conf, strongswan.conf, .ovpn)
  extractCredentials(event) {
    const config = event.target.value
    if (!config.trim()) return

    const form = this.element.closest("form")

    // Try to extract gateway IP/hostname
    const remoteMatch = config.match(/remote_addrs\s*=\s*(.+)/i) ||
                        config.match(/right\s*=\s*(.+)/i) ||
                        config.match(/^remote\s+(\S+)/mi)
    if (remoteMatch) {
      const field = form.querySelector("[name='database_config[vpn_gateway_ip]']")
      if (field && !field.value) field.value = remoteMatch[1].trim()
    }

    // Try to extract pre-shared key
    const pskMatch = config.match(/secret\s*=\s*"?([^"\n]+)"?/i) ||
                     config.match(/ipsec\.secrets.*:\s*PSK\s+"?([^"\n]+)"?/i)
    if (pskMatch) {
      const field = form.querySelector("[name='database_config[vpn_preshared_key]']")
      if (field && !field.value) field.value = pskMatch[1].trim()
    }

    // Try to extract username/identity
    const idMatch = config.match(/\blocal\s*\{[^}]*id\s*=\s*(\S+)/si) ||
                    config.match(/leftid\s*=\s*(\S+)/i)
    if (idMatch) {
      const field = form.querySelector("[name='database_config[vpn_username]']")
      if (field && !field.value) field.value = idMatch[1].trim()
    }
  }

  toggleInputs(container, enabled) {
    container.querySelectorAll("input, select, textarea").forEach(input => {
      input.disabled = !enabled
    })
  }
}
