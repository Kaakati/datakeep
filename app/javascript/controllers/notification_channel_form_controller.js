import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "emailFields", "slackFields", "discordFields", "telegramFields", "webhookFields"]

  connect() {
    this.toggleChannelType()
  }

  toggleChannelType() {
    const channelType = this.typeSelectTarget?.value || ""

    // Hide and disable all channel-specific fields first
    this.hideAllFields()

    // Show and enable the relevant fields based on type
    switch (channelType) {
      case "email":
        if (this.hasEmailFieldsTarget) this.showFields(this.emailFieldsTarget)
        break
      case "slack":
        if (this.hasSlackFieldsTarget) this.showFields(this.slackFieldsTarget)
        break
      case "discord":
        if (this.hasDiscordFieldsTarget) this.showFields(this.discordFieldsTarget)
        break
      case "telegram":
        if (this.hasTelegramFieldsTarget) this.showFields(this.telegramFieldsTarget)
        break
      case "webhook":
        if (this.hasWebhookFieldsTarget) this.showFields(this.webhookFieldsTarget)
        break
    }
  }

  hideAllFields() {
    if (this.hasEmailFieldsTarget) this.hideFields(this.emailFieldsTarget)
    if (this.hasSlackFieldsTarget) this.hideFields(this.slackFieldsTarget)
    if (this.hasDiscordFieldsTarget) this.hideFields(this.discordFieldsTarget)
    if (this.hasTelegramFieldsTarget) this.hideFields(this.telegramFieldsTarget)
    if (this.hasWebhookFieldsTarget) this.hideFields(this.webhookFieldsTarget)
  }

  hideFields(container) {
    container.classList.add("hidden")
    // Disable all inputs so they don't get submitted
    container.querySelectorAll("input, select, textarea").forEach(input => {
      input.disabled = true
    })
  }

  showFields(container) {
    container.classList.remove("hidden")
    // Re-enable all inputs
    container.querySelectorAll("input, select, textarea").forEach(input => {
      input.disabled = false
    })
  }
}
