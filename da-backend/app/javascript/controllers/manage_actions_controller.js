import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list", "count",
    "backdrop",
    "editSlug", "editName", "editDescription", "editMethod", "editUrl", "editHeaders",
    "saveBtn", "modalErrors",
  ]

  #editingId = null

  async connect() {
    await this.#loadActions()
  }

  // ── Toggle enable/disable ───────────────────────────────

  async toggle(event) {
    event.stopPropagation()

    const btn    = event.currentTarget
    const id     = btn.dataset.actionId
    const enable = btn.dataset.enable === "true"
    const route  = enable ? "enable" : "disable"

    btn.disabled = true

    try {
      const res  = await fetch(`/actions/${id}/${route}`, {
        method:  "POST",
        headers: { "Accept": "application/json" },
      })
      const data = await res.json()
      if (res.ok) this.#updateRow(id, data)
    } finally {
      btn.disabled = false
    }
  }

  // ── Edit modal ──────────────────────────────────────────

  async openEdit(event) {
    const id = event.currentTarget.dataset.actionId
    this.#editingId = id
    this.#clearErrors()

    // Optimistically populate from row data while we fetch
    const res    = await fetch(`/actions/${id}`, { headers: { "Accept": "application/json" } })
    const action = await res.json()

    this.editSlugTarget.value        = action.slug        || ""
    this.editNameTarget.value        = action.name        || ""
    this.editDescriptionTarget.value = action.description || ""
    this.editMethodTarget.value      = action.http_method || "POST"
    this.editUrlTarget.value         = action.url_template || ""
    this.editHeadersTarget.value     = action.headers_template && Object.keys(action.headers_template).length
      ? JSON.stringify(action.headers_template, null, 2)
      : ""

    this.backdropTarget.classList.add("modal-backdrop--open")
    this.editSlugTarget.focus()
  }

  closeEdit() {
    this.backdropTarget.classList.remove("modal-backdrop--open")
    this.#editingId = null
    this.#clearErrors()
  }

  backdropClose(event) {
    if (event.target === this.backdropTarget) this.closeEdit()
  }

  async saveEdit() {
    const id = this.#editingId
    if (!id) return

    const headersRaw = this.editHeadersTarget.value.trim()

    const body = {
      slug:          this.editSlugTarget.value.trim(),
      name:          this.editNameTarget.value.trim(),
      description:   this.editDescriptionTarget.value.trim(),
      http_method:   this.editMethodTarget.value,
      url_template:  this.editUrlTarget.value.trim(),
      ...(headersRaw ? { headers_template: headersRaw } : {}),
    }

    const btn      = this.saveBtnTarget
    const original = btn.innerHTML
    btn.disabled   = true
    btn.textContent = "Saving…"

    try {
      const res  = await fetch(`/actions/${id}`, {
        method:  "PUT",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body:    JSON.stringify(body),
      })
      const data = await res.json()

      if (res.ok) {
        this.#updateRow(id, data)
        this.closeEdit()
      } else {
        this.#showErrors(data.errors || ["Something went wrong."])
      }
    } finally {
      btn.disabled  = false
      btn.innerHTML = original
    }
  }

  // ── Private ─────────────────────────────────────────────

  async #loadActions() {
    try {
      const res     = await fetch("/actions", { headers: { "Accept": "application/json" } })
      const actions = await res.json()
      this.#render(actions)
    } catch (_) {
      this.listTarget.innerHTML = '<p class="action-list-empty">Could not load actions.</p>'
    }
  }

  #render(actions) {
    if (this.hasCountTarget) {
      this.countTarget.textContent = actions.length === 1
        ? "1 action"
        : `${actions.length} actions`
    }

    if (actions.length === 0) {
      this.listTarget.innerHTML = '<p class="action-list-empty">No actions yet. <a href="/actions" class="form-hint-link">Create one →</a></p>'
      return
    }

    this.listTarget.innerHTML = actions.map(a => this.#rowHTML(a)).join("")
  }

  #updateRow(id, action) {
    const existing = this.listTarget.querySelector(`[data-row-id="${id}"]`)
    if (existing) existing.outerHTML = this.#rowHTML(action)
  }

  #rowHTML(a) {
    const enabled      = a.enabled
    const toggleLabel  = enabled ? "Disable" : "Enable"
    const toggleEnable = !enabled

    return `
      <div class="action-row ${enabled ? "" : "action-row--disabled"}" data-row-id="${a.id}"
           data-action="click->manage-actions#openEdit" data-action-id="${a.id}">
        <div class="action-row-left">
          <span class="action-row-status ${enabled ? "action-row-status--on" : "action-row-status--off"}"></span>
          <div class="action-row-meta">
            <span class="action-row-slug">${a.slug}</span>
            <span class="action-row-name">${a.name || ""}</span>
          </div>
        </div>
        <div class="action-row-right">
          <span class="action-row-method action-row-method--${(a.http_method || "").toLowerCase()}">${a.http_method || ""}</span>
          <span class="action-row-url">${a.url_template || ""}</span>
          <button class="action-toggle action-toggle--${enabled ? "on" : "off"}"
            data-action="click->manage-actions#toggle"
            data-action-id="${a.id}"
            data-enable="${toggleEnable}"
          >${toggleLabel}</button>
        </div>
      </div>
    `
  }

  #showErrors(errors) {
    this.modalErrorsTarget.innerHTML = errors
      .map(e => `<p class="modal-error-item">${e}</p>`)
      .join("")
  }

  #clearErrors() {
    if (this.hasModalErrorsTarget) this.modalErrorsTarget.innerHTML = ""
  }
}
