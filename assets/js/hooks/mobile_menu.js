// Mobile menu hook — controls the slide-out navigation drawer in the global
// header layout. The drawer DOM lives in lib/lms_web/components/layouts.ex.
//
// Why a hook: Layouts.app/1 is a stateless function component (not a LiveView),
// so open/closed state must live in the DOM. We also need keyboard handling
// (Escape) and aria-expanded sync, which require JS.
//
// Events accepted on `window`:
//   - "mobile-menu:toggle" — flips open/closed
//   - "mobile-menu:close"  — closes (idempotent)
//
// Wire-up:
//   - The wrapper element has phx-hook="MobileMenu"
//   - The drawer panel has id="mobile-menu"
//   - The backdrop has id="mobile-menu-backdrop"
//   - The toggle button has id="mobile-menu-toggle"

const HIDDEN = "hidden"

const MobileMenu = {
  mounted() {
    this.toggleBtn = document.getElementById("mobile-menu-toggle")
    this.backdrop = document.getElementById("mobile-menu-backdrop")
    this.panel = document.getElementById("mobile-menu")
    this.previouslyFocused = null

    this.handleToggle = () => this.toggle()
    this.handleClose = () => this.close()
    this.handleKeydown = (e) => {
      if (e.key === "Escape" && this.isOpen()) this.close()
    }

    window.addEventListener("mobile-menu:toggle", this.handleToggle)
    window.addEventListener("mobile-menu:close", this.handleClose)
    window.addEventListener("keydown", this.handleKeydown)
  },

  updated() {
    // After a LiveView patch re-renders the toggle button, re-sync aria-expanded
    // so it matches the actual visual state of the panel.
    this.toggleBtn?.setAttribute("aria-expanded", this.isOpen() ? "true" : "false")
  },

  destroyed() {
    window.removeEventListener("mobile-menu:toggle", this.handleToggle)
    window.removeEventListener("mobile-menu:close", this.handleClose)
    window.removeEventListener("keydown", this.handleKeydown)
  },

  isOpen() {
    return this.panel && !this.panel.classList.contains(HIDDEN)
  },

  toggle() {
    this.isOpen() ? this.close() : this.open()
  },

  open() {
    if (!this.panel) return
    this.previouslyFocused = document.activeElement
    this.panel.classList.remove(HIDDEN)
    this.backdrop?.classList.remove(HIDDEN)
    this.toggleBtn?.setAttribute("aria-expanded", "true")
    // Move focus into the drawer so keyboard users can tab through its links.
    const firstFocusable = this.panel.querySelector(
      "button, [href], [tabindex]:not([tabindex='-1'])"
    )
    firstFocusable?.focus()
  },

  close() {
    if (!this.panel) return
    this.panel.classList.add(HIDDEN)
    this.backdrop?.classList.add(HIDDEN)
    this.toggleBtn?.setAttribute("aria-expanded", "false")
    // Restore focus to the element that had it before the drawer opened.
    if (this.previouslyFocused && typeof this.previouslyFocused.focus === "function") {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  },
}

export default MobileMenu
