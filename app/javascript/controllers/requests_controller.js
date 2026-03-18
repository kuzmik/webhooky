import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { tokenUuid: String, requestsUrl: String }
  static targets = ["list", "detail", "count"]

  connect() {
    this.selectedUuid = null
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "TokenChannel", token_uuid: this.tokenUuidValue },
      {
        received: (data) => this.handleNewRequest(data)
      }
    )
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown, true)
  }

  disconnect() {
    if (this.subscription) this.subscription.unsubscribe()
    if (this.consumer) this.consumer.disconnect()
    document.removeEventListener("keydown", this.boundKeydown, true)
  }

  handleKeydown(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
    // Don't hijack arrows when typing in an input
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA") return

    event.preventDefault()
    const items = Array.from(this.listTarget.querySelectorAll(".request-item"))
    if (items.length === 0) return

    const currentIndex = items.findIndex(el => el.classList.contains("selected"))
    let nextIndex

    if (event.key === "ArrowUp") {
      nextIndex = currentIndex <= 0 ? 0 : currentIndex - 1
    } else {
      nextIndex = currentIndex >= items.length - 1 ? items.length - 1 : currentIndex + 1
    }

    items[nextIndex].click()
    items[nextIndex].scrollIntoView({ block: "nearest" })
  }

  handleNewRequest(data) {
    this.countTarget.textContent = data.total

    const req = data.request
    const li = document.createElement("li")
    li.className = "request-item new-item"
    li.dataset.action = "click->requests#select"

    if (data.truncated) {
      li.dataset.requestTruncated = "true"
      li.dataset.requestJson = JSON.stringify({ uuid: req.uuid, method_name: req.method_name, url: req.url, ip: req.ip, created_at: req.created_at, content_size: req.content_size })
    } else {
      li.dataset.requestJson = JSON.stringify(req)
    }

    const method = req.method_name.toLowerCase()
    const methodClass = ["get","post","put","patch","delete"].includes(method)
      ? `method-${method}` : "method-other"

    li.innerHTML = `
      <span class="method-badge ${methodClass}">${this.escapeHtml(req.method_name)}</span>
      <div class="request-item-info">
        <div class="request-item-path">${this.escapeHtml(req.ip)}</div>
        <div class="request-item-time">just now</div>
      </div>
    `

    this.listTarget.prepend(li)

    // Auto-select if nothing selected
    if (!this.selectedUuid) {
      li.click()
    }
  }

  select(event) {
    const item = event.currentTarget

    // Deselect previous
    this.listTarget.querySelectorAll(".request-item.selected").forEach(el => el.classList.remove("selected"))
    item.classList.add("selected")

    const reqData = JSON.parse(item.dataset.requestJson)
    this.selectedUuid = reqData.uuid

    if (item.dataset.requestTruncated === "true") {
      this.fetchAndShowDetail(reqData.uuid)
    } else {
      this.showDetail(reqData)
    }
  }

  async fetchAndShowDetail(uuid) {
    const response = await fetch(`${this.requestsUrlValue}/${uuid}`, {
      headers: { "Accept": "application/json" }
    })
    if (response.ok) {
      const data = await response.json()
      this.showDetail(data)
    }
  }

  showDetail(req) {
    const method = req.method_name.toLowerCase()
    const methodClass = ["get","post","put","patch","delete"].includes(method)
      ? `method-${method}` : "method-other"

    let headers = {}
    try { headers = typeof req.headers === "string" ? JSON.parse(req.headers) : (req.headers || {}) } catch(e) {}

    let query = {}
    try { query = typeof req.query === "string" ? JSON.parse(req.query) : (req.query || {}) } catch(e) {}

    let formData = null
    try {
      if (req.form_data && req.form_data !== "null") {
        formData = typeof req.form_data === "string" ? JSON.parse(req.form_data) : req.form_data
      }
    } catch(e) {}

    const createdAt = new Date(req.created_at)
    const timeStr = createdAt.toLocaleString()

    let headersHtml = ""
    for (const [key, value] of Object.entries(headers)) {
      headersHtml += `<tr><td>${this.escapeHtml(key)}</td><td>${this.escapeHtml(String(value))}</td></tr>`
    }

    let queryHtml = ""
    const queryEntries = Object.entries(query)
    if (queryEntries.length > 0) {
      for (const [key, value] of queryEntries) {
        queryHtml += `<tr><td>${this.escapeHtml(key)}</td><td>${this.escapeHtml(String(value))}</td></tr>`
      }
    } else {
      queryHtml = '<tr><td colspan="2" style="color:var(--text-muted)">(none)</td></tr>'
    }

    let formDataSection = ""
    if (formData && Object.keys(formData).length > 0) {
      let formHtml = ""
      for (const [key, value] of Object.entries(formData)) {
        formHtml += `<tr><td>${this.escapeHtml(key)}</td><td>${this.escapeHtml(String(value))}</td></tr>`
      }
      formDataSection = `
        <div class="detail-section">
          <h3>Form Data</h3>
          <table class="headers-table">${formHtml}</table>
        </div>
      `
    }

    const bodyContent = req.content || ""
    const formattedBody = this.formatBody(bodyContent)

    this.detailTarget.innerHTML = `
      <div class="detail-header">
        <div class="detail-method-url">
          <span class="method-badge ${methodClass}">${this.escapeHtml(req.method_name)}</span>
          <code>${this.escapeHtml(req.url)}</code>
        </div>
        <div class="detail-meta">${this.escapeHtml(req.ip)} &middot; ${timeStr} &middot; ${req.content_size} bytes</div>
      </div>

      <div class="detail-section">
        <h3>Headers</h3>
        <table class="headers-table">${headersHtml}</table>
      </div>

      <div class="detail-section">
        <h3>Query String</h3>
        <table class="headers-table">${queryHtml}</table>
      </div>

      ${formDataSection}

      <div class="detail-section">
        <h3>Body</h3>
        <div class="body-content">${formattedBody || '<span style="color:var(--text-muted)">(empty)</span>'}</div>
      </div>
    `
  }

  formatBody(content) {
    if (!content) return ""
    try {
      const parsed = JSON.parse(content)
      const pretty = JSON.stringify(parsed, null, 2)
      const escaped = this.escapeHtml(pretty)
      return this.highlightJson(escaped)
    } catch(e) {
      return this.escapeHtml(content)
    }
  }

  highlightJson(json) {
    return json.replace(/(&quot;(?:[^&]|&(?!quot;))*&quot;)\s*:/g, '<span class="json-key">$1</span>:')
      .replace(/:\s*(&quot;(?:[^&]|&(?!quot;))*&quot;)/g, ': <span class="json-string">$1</span>')
      .replace(/:\s*(\d+\.?\d*)/g, ': <span class="json-number">$1</span>')
      .replace(/:\s*(true|false)/g, ': <span class="json-boolean">$1</span>')
      .replace(/:\s*(null)/g, ': <span class="json-null">$1</span>')
  }

  deleteAll() {
    if (!confirm("Delete all requests?")) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    fetch(`/tokens/${this.tokenUuidValue}/requests`, {
      method: "DELETE",
      headers: { "X-CSRF-Token": csrfToken }
    }).then(response => {
      if (response.ok) {
        this.listTarget.innerHTML = ""
        this.countTarget.textContent = "0"
        this.selectedUuid = null
        this.detailTarget.innerHTML = `
          <div class="empty-state">
            <h2>No request selected</h2>
            <p>Send a webhook to your URL to get started</p>
          </div>
        `
      }
    })
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
