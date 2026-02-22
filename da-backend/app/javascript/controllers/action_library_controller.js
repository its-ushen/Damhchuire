import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "title", "credSelect", "useBtn"]

  #activeSlug = null

  async openModal(event) {
    const card = event.currentTarget
    this.#activeSlug = card.dataset.actionSlug

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

  use() {
    if (!this.credSelectTarget.value || !this.#activeSlug) return
    this.closeModal()
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
