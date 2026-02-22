import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "network", "trigger", "triggerValue", "action", "payload", "preview"]

  connect() {
    this.update()
  }

  update() {
    const name        = this.nameTarget.value.trim()        || "my-connector"
    const network     = this.networkTarget.value
    const trigger     = this.triggerTarget.value
    const triggerVal  = this.triggerValueTarget.value.trim()
    const action      = this.actionTarget.value
    const payloadRaw  = this.payloadTarget.value.trim()

    const config = {
      name,
      version: "0.1.0",
      network,
      trigger: {
        type: trigger,
        ...(triggerVal ? { value: triggerVal } : {}),
      },
      action: {
        type: action,
        ...(payloadRaw ? { payload: payloadRaw } : {}),
      },
    }

    this.previewTarget.innerHTML = this.#colorize(config)
  }

  // Lightweight JSON coloriser injecting spans into the preview
  #colorize(obj) {
    const raw = JSON.stringify(obj, null, 2)

    return raw
      .replace(/("[\w.-]+")\s*:/g,       '<span style="color:#A8A8FF">$1</span>:')
      .replace(/:\s*(".*?")/g,            ': <span style="color:#8FD4A4">$1</span>')
      .replace(/:\s*(\d[\d._]*)/g,        ': <span style="color:#BD93F9">$1</span>')
      .replace(/:\s*(true|false|null)/g,  ': <span style="color:#FFB86C">$1</span>')
  }
}
