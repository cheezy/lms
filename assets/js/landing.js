// Sticky nav scroll behavior
function initStickyNav() {
  const nav = document.getElementById("landing-nav")
  if (!nav) return

  const onScroll = () => {
    if (window.scrollY > 50) {
      nav.classList.add("bg-[var(--uplift-indigo-950)]", "shadow-lg", "backdrop-blur-md")
      nav.classList.remove("bg-transparent")
    } else {
      nav.classList.remove("bg-[var(--uplift-indigo-950)]", "shadow-lg", "backdrop-blur-md")
      nav.classList.add("bg-transparent")
    }
  }

  window.addEventListener("scroll", onScroll, { passive: true })
  onScroll()
}

// Mobile hamburger menu toggle
function initMobileMenu() {
  const toggle = document.getElementById("mobile-menu-toggle")
  const menu = document.getElementById("mobile-menu")
  if (!toggle || !menu) return

  toggle.addEventListener("click", () => {
    menu.classList.toggle("hidden")
  })

  // Close menu when clicking a nav link
  menu.querySelectorAll("a").forEach(link => {
    link.addEventListener("click", () => {
      menu.classList.add("hidden")
    })
  })
}

// Smooth scroll for anchor links
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener("click", (e) => {
      e.preventDefault()
      const target = document.querySelector(anchor.getAttribute("href"))
      if (target) {
        target.scrollIntoView({ behavior: "smooth", block: "start" })
      }
    })
  })
}

export function initLanding() {
  initStickyNav()
  initMobileMenu()
  initSmoothScroll()
}
