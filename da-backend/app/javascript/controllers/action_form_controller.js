import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slug", "name", "description", "httpMethod", "urlTemplate", "headersTemplate", "preview", "previewWindow", "submit", "credentialHints"]

  #credentials = []

  async connect() {
    await this.#fetchCredentials()
    this.update()
  }

  update() {
    const slug        = this.slugTarget.value.trim()
    const name        = this.nameTarget.value.trim()
    const description = this.descriptionTarget.value.trim()
    const httpMethod  = this.httpMethodTarget.value
    const urlTemplate = this.urlTemplateTarget.value.trim()

    let headers = {}
    try {
      const raw = this.headersTemplateTarget.value.trim()
      if (raw) headers = JSON.parse(raw)
    } catch (_) {}

    const config = {
      slug:         slug        || "my-action",
      name:         name        || "My Action",
      ...(description ? { description } : {}),
      enabled:      true,
      http_method:  httpMethod,
      url_template: urlTemplate || "https://api.example.com/endpoint",
      ...(Object.keys(headers).length ? { headers_template: headers } : {}),
    }

    this.previewTarget.innerHTML = this.#colorize(config)
    this.#validateCredentialRefs()
  }

  async submit() {
    const slug        = this.slugTarget.value.trim()
    const name        = this.nameTarget.value.trim()
    const description = this.descriptionTarget.value.trim()
    const httpMethod  = this.httpMethodTarget.value
    const urlTemplate = this.urlTemplateTarget.value.trim()
    const headersRaw  = this.headersTemplateTarget.value.trim()

    const body = {
      slug,
      name,
      ...(description ? { description }              : {}),
      http_method:       httpMethod,
      url_template:      urlTemplate,
      ...(headersRaw  ? { headers_template: headersRaw } : {}),
    }

    const btn      = this.submitTarget
    const original = btn.innerHTML
    btn.disabled   = true
    btn.textContent = "Creating…"

    try {
      const res  = await fetch("/actions", {
        method:  "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body:    JSON.stringify(body),
      })
      const data = await res.json()

      if (res.ok) {
        btn.textContent = "Created ✓"
      } else {
        btn.disabled = false
        btn.innerHTML = original
        alert((data.errors || []).join(", ") || "Something went wrong.")
      }
    } catch (_) {
      btn.disabled = false
      btn.innerHTML = original
    }
  }

  async #fetchCredentials() {
    try {
      const res  = await fetch("/credentials", { headers: { "Accept": "application/json" } })
      const data = await res.json()
      this.#credentials = data.map(c => c.name)
    } catch (_) {
      this.#credentials = []
    }
  }

  #validateCredentialRefs() {
    const raw     = this.headersTemplateTarget.value
    const refs    = [...raw.matchAll(/\{\{credential\.([a-zA-Z0-9_]+)\}\}/g)].map(m => m[1])
    const missing = refs.filter(ref => !this.#credentials.includes(ref))

    if (this.hasPreviewWindowTarget) {
      this.previewWindowTarget.classList.toggle("preview-window--ok",    refs.length > 0 && missing.length === 0)
      this.previewWindowTarget.classList.toggle("preview-window--error", missing.length > 0)
    }

    if (this.hasCredentialHintsTarget) {
      this.credentialHintsTarget.innerHTML = missing.map(ref =>
        `<span class="cred-hint cred-hint--missing">Unrecognized credential ${ref}</span>`
      ).join("")
    }
  }

  #colorize(obj) {
    const raw = JSON.stringify(obj, null, 2)
    return raw
      .replace(/("[\w._-]+")\s*:/g,      '<span style="color:#A8A8FF">$1</span>:')
      .replace(/:\s*(".*?")/g,            ': <span style="color:#8FD4A4">$1</span>')
      .replace(/:\s*(\d[\d._]*)/g,        ': <span style="color:#BD93F9">$1</span>')
      .replace(/:\s*(true|false|null)/g,  ': <span style="color:#FFB86C">$1</span>')
  }
}
