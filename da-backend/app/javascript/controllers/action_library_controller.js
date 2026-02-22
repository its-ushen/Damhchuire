import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "title", "credSelect", "useBtn"]

  #activeSlug = null
  #activePayload = null

  async openModal(event) {
    const card = event.currentTarget
    this.#activeSlug   = card.dataset.actionSlug
    this.#activePayload = JSON.parse(card.dataset.actionPayload)

    this.titleTarget.textContent      = card.dataset.actionName
    this.useBtnTarget.disabled        = true
    this.credSelectTarget.disabled    = true
    this.credSelectTarget.innerHTML   = '<option value="">Loading…</option>'
    this.backdropTarget.classList.add("modal-backdrop--open")

    try {
      const res   = await fetch("/credentials", { headers: { Accept: "application/json" } })
      const creds = await res.json()
      this.#renderCreds(creds)
    } catch (_) {
      this.credSelectTarget.innerHTML = '<option value="">Could not load credentials</option>'
    }
  }

  closeModal() {
    this.backdropTarget.classList.remove("modal-backdrop--open")
    this.#activeSlug = null
  }

  backdropClose(event) {
    if (event.target === this.backdropTarget) this.closeModal()
  }

  credChange() {
    this.useBtnTarget.disabled = !this.credSelectTarget.value
  }

  async use() {
    if (!this.credSelectTarget.value || !this.#activePayload) return

    const btn      = this.useBtnTarget
    const original = btn.textContent
    btn.disabled   = true
    btn.textContent = "Adding…"

    try {
      const res = await fetch("/actions", {
        method:  "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body:    JSON.stringify(this.#activePayload),
      })

      if (res.ok) {
        window.location.href = "/actions/manage"
      } else {
        const data = await res.json().catch(() => ({}))
        alert((data.errors || []).join(", ") || "Something went wrong.")
        btn.disabled  = false
        btn.textContent = original
      }
    } catch (_) {
      btn.disabled  = false
      btn.textContent = original
    }
  }

  // ── Private ─────────────────────────────────────────────

  #renderCreds(creds) {
    this.credSelectTarget.disabled = false

    if (creds.length === 0) {
      this.credSelectTarget.innerHTML = '<option value="">No credentials stored yet</option>'
      return
    }

    this.credSelectTarget.innerHTML = [
      '<option value="">Select a credential…</option>',
      ...creds.map(c => `<option value="${c.id}">${c.name}</option>`)
    ].join("")
  }
}
