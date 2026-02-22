import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["code", "btn"]

  copy() {
    const text = this.codeTarget.innerText
    navigator.clipboard.writeText(text).then(() => {
      this.btnTarget.textContent = "Copied"
      this.btnTarget.classList.add("copied")
      setTimeout(() => {
        this.btnTarget.textContent = "Copy"
        this.btnTarget.classList.remove("copied")
      }, 2000)
    })
  }
}
