import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "value", "list", "submit"]

  async connect() {
    await this.#loadCredentials()
  }

  async create() {
    const name  = this.nameTarget.value.trim()
    const value = this.valueTarget.value.trim()

    const btn      = this.submitTarget
    const original = btn.innerHTML
    btn.disabled   = true
    btn.textContent = "Adding…"

    try {
      const res  = await fetch("/credentials", {
        method:  "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body:    JSON.stringify({ name, value }),
      })
      const data = await res.json()

      if (res.ok) {
        this.nameTarget.value  = ""
        this.valueTarget.value = ""
        btn.innerHTML = original
        btn.disabled  = false
        await this.#loadCredentials()
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

  async delete(event) {
    const id = event.currentTarget.dataset.credentialId
    await fetch(`/credentials/${id}`, {
      method:  "DELETE",
      headers: { "Accept": "application/json" },
    })
    await this.#loadCredentials()
  }

  async #loadCredentials() {
    try {
      const res   = await fetch("/credentials", { headers: { "Accept": "application/json" } })
      const creds = await res.json()
      this.#renderList(creds)
    } catch (_) {
      this.listTarget.innerHTML = '<p class="cred-empty">Could not load credentials.</p>'
    }
  }

  #renderList(creds) {
    if (creds.length === 0) {
      this.listTarget.innerHTML = '<p class="cred-empty">No credentials yet.</p>'
      return
    }

    this.listTarget.innerHTML = creds.map(c => `
      <div class="cred-row">
        <span class="cred-row-name">${c.name}</span>
        <button class="cred-row-delete"
          data-credential-id="${c.id}"
          data-action="click->credential-form#delete">Remove</button>
      </div>
    `).join("")
  }
}
