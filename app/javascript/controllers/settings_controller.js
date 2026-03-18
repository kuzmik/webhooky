import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { tokenUuid: String }
  static targets = ["status", "contentType", "content"]

  save() {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    fetch(`/tokens/${this.tokenUuidValue}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({
        default_status: parseInt(this.statusTarget.value),
        default_content_type: this.contentTypeTarget.value,
        default_content: this.contentTarget.value
      })
    }).then(response => {
      if (response.ok) {
        this.showFlash("Settings saved")
      } else {
        this.showFlash("Failed to save settings")
      }
    })
  }

  showFlash(message) {
    const el = document.createElement("div")
    el.className = "flash-message"
    el.textContent = message
    document.body.appendChild(el)
    setTimeout(() => el.remove(), 2500)
  }
}
