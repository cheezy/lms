# Uplift UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

> **Design Reference:** See `docs/plans/2026-03-04-uplift-ui-design.md` for the full UI design system.

**Goal:** Rebrand the entire LMS application to the Uplift design system — landing page, app layout, all authenticated pages, and authentication pages.

**Architecture:** The landing page is a static Phoenix controller page with a custom layout. All other pages use LiveView with the shared `Layouts.app` wrapper. The Uplift brand is applied through CSS custom properties, updated daisyUI theme tokens, and consistent Tailwind classes across all templates.

**Tech Stack:** Phoenix 1.8 controller + LiveView, HEEx templates, Tailwind CSS v4, daisyUI themes, Heroicons via `<.icon>`, vanilla JS for landing page interactions.

**Page Groups:**
- Tasks 1-10: Landing page (public marketing)
- Task 11: DaisyUI theme rebrand (affects all authenticated pages)
- Task 12: App layout (shared navigation chrome)
- Task 13: Root layout updates
- Task 14: Authentication pages (login, register, company register, invitation, settings)
- Task 15: Dashboard
- Task 16: Course management (list, form, editor)
- Task 17: Employee management
- Task 18: Enrollment management
- Task 19: System admin (company list)
- Task 20: Employee learning (my learning, course viewer)
- Task 21: Final test suite and precommit

---

### Task 1: Add Landing Page CSS Custom Properties

Add CSS custom properties for the Uplift brand colors to `app.css`. These provide the deep purple/indigo palette and vibrant accents specified in the design.

**Files:**
- Modify: `assets/css/app.css:105` (append after the last line)

**Step 1: Add the CSS custom properties**

Add the following at the end of `assets/css/app.css`:

```css
/* Uplift landing page brand colors */
:root {
  --uplift-indigo-950: #1e1045;
  --uplift-indigo-900: #2d1b69;
  --uplift-indigo-800: #3c2587;
  --uplift-indigo-700: #4c30a5;
  --uplift-violet-500: #8b5cf6;
  --uplift-violet-400: #a78bfa;
  --uplift-cyan-400: #22d3ee;
  --uplift-cyan-300: #67e8f9;
}
```

**Step 2: Verify the app compiles**

Run: `mix phx.routes | head -5`
Expected: Routes listed without compilation errors.

**Step 3: Commit**

```bash
git add assets/css/app.css
git commit -m "feat: add Uplift brand color CSS custom properties"
```

---

### Task 2: Create the Landing Page Layout

The landing page needs its own layout that doesn't include the default app navbar/sidebar. Create a new `landing.html.heex` layout and a `landing/0` function in the Layouts module.

**Files:**
- Create: `lib/lms_web/components/layouts/landing.html.heex`
- Modify: `lib/lms_web/components/layouts.ex`
- Modify: `lib/lms_web/controllers/page_controller.ex`

**Step 1: Create the landing layout template**

Create `lib/lms_web/components/layouts/landing.html.heex` with a minimal wrapper that just renders flash messages and inner content — no navbar, no sidebar:

```heex
<main>
  {render_slot(@inner_block)}
</main>
<.flash_group flash={@flash} />
```

**Step 2: Add the `landing` function to Layouts**

In `lib/lms_web/components/layouts.ex`, add a new function component below the existing `app` function. This function will be called from the landing page template:

```elixir
attr :flash, :map, required: true, doc: "the map of flash messages"
slot :inner_block, required: true

def landing(assigns) do
  ~H"""
  <main>
    {render_slot(@inner_block)}
  </main>
  <.flash_group flash={@flash} />
  """
end
```

**Step 3: Update PageController to use the landing layout**

In `lib/lms_web/controllers/page_controller.ex`, modify the `home` action to use the landing layout:

```elixir
def home(conn, _params) do
  conn
  |> put_layout(html: {LmsWeb.Layouts, :landing})
  |> render(:home)
end
```

**Step 4: Verify the page loads**

Run: `mix phx.routes | grep "GET /"`
Expected: `GET  /  LmsWeb.PageController :home` still present.

Run: `mix compile --warnings-as-errors`
Expected: Compiles without warnings.

**Step 5: Commit**

```bash
git add lib/lms_web/components/layouts/landing.html.heex lib/lms_web/components/layouts.ex lib/lms_web/controllers/page_controller.ex
git commit -m "feat: add landing page layout that bypasses default app chrome"
```

---

### Task 3: Create the Sticky Navigation Bar

Build the sticky nav with transparent-to-solid transition on scroll, section links, and mobile hamburger menu.

**Files:**
- Modify: `lib/lms_web/controllers/page_html/home.html.heex` (full replacement)
- Create: `assets/js/landing.js` (scroll and hamburger behavior)
- Modify: `assets/js/app.js` (import landing.js)

**Step 1: Create the landing.js module**

Create `assets/js/landing.js` with the nav scroll behavior and mobile menu toggle:

```javascript
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
```

**Step 2: Import landing.js in app.js**

Add the following near the top of `assets/js/app.js`, after the existing imports:

```javascript
import { initLanding } from "./landing"

// Initialize landing page behavior if on the landing page
if (document.getElementById("landing-nav")) {
  initLanding()
}
```

**Step 3: Replace home.html.heex — start with the nav section only**

Replace the entire contents of `lib/lms_web/controllers/page_html/home.html.heex` with the sticky nav. We'll add sections in subsequent tasks.

```heex
<div class="min-h-screen bg-[var(--uplift-indigo-950)]">
  <%!-- Sticky Navigation --%>
  <nav
    id="landing-nav"
    class="fixed top-0 left-0 right-0 z-50 bg-transparent transition-all duration-300"
  >
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="flex h-16 items-center justify-between">
        <%!-- Logo --%>
        <a href="#" class="text-2xl font-bold text-white tracking-tight">
          Uplift
        </a>

        <%!-- Desktop nav links --%>
        <div class="hidden md:flex items-center gap-8">
          <a href="#features" class="text-sm font-medium text-white/80 hover:text-white transition-colors">
            Features
          </a>
          <a href="#how-it-works" class="text-sm font-medium text-white/80 hover:text-white transition-colors">
            How it Works
          </a>
          <a href={~p"/users/log-in"} class="text-sm font-medium text-white/80 hover:text-white transition-colors">
            Log In
          </a>
          <a
            href="#get-started"
            class="rounded-full bg-[var(--uplift-violet-500)] px-5 py-2 text-sm font-semibold text-white hover:bg-[var(--uplift-violet-400)] transition-colors"
          >
            Get Started
          </a>
        </div>

        <%!-- Mobile hamburger --%>
        <button
          id="mobile-menu-toggle"
          class="md:hidden text-white p-2"
          aria-label="Toggle menu"
        >
          <.icon name="hero-bars-3" class="size-6" />
        </button>
      </div>

      <%!-- Mobile menu --%>
      <div id="mobile-menu" class="hidden md:hidden pb-4">
        <div class="flex flex-col gap-3">
          <a href="#features" class="text-sm font-medium text-white/80 hover:text-white transition-colors">
            Features
          </a>
          <a href="#how-it-works" class="text-sm font-medium text-white/80 hover:text-white transition-colors">
            How it Works
          </a>
          <a href={~p"/users/log-in"} class="text-sm font-medium text-white/80 hover:text-white transition-colors">
            Log In
          </a>
          <a
            href="#get-started"
            class="rounded-full bg-[var(--uplift-violet-500)] px-5 py-2 text-sm font-semibold text-white hover:bg-[var(--uplift-violet-400)] transition-colors text-center"
          >
            Get Started
          </a>
        </div>
      </div>
    </div>
  </nav>

  <%!-- Placeholder for hero (Task 4) --%>
  <section class="h-screen flex items-center justify-center">
    <h1 class="text-4xl font-bold text-white">Hero section coming next</h1>
  </section>
</div>
```

**Step 4: Verify in browser**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `http://localhost:4000` and verify:
- Nav bar is transparent at top
- Nav becomes solid on scroll
- Mobile hamburger toggles the menu
- Section links exist (Features, How it Works, Log In, Get Started)

**Step 5: Commit**

```bash
git add assets/js/landing.js assets/js/app.js lib/lms_web/controllers/page_html/home.html.heex
git commit -m "feat: add sticky nav with scroll behavior and mobile menu"
```

---

### Task 4: Build the Hero Section

Replace the placeholder hero with the full hero section including headline, subtext, CTA buttons, and decorative background.

**Files:**
- Modify: `lib/lms_web/controllers/page_html/home.html.heex`

**Step 1: Replace the placeholder hero section**

In `home.html.heex`, replace the placeholder `<section class="h-screen ...">` block with:

```heex
  <%!-- Hero Section --%>
  <section class="relative min-h-screen flex items-center overflow-hidden pt-16">
    <%!-- Decorative background elements --%>
    <div class="absolute inset-0">
      <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-[var(--uplift-violet-500)]/20 rounded-full blur-3xl"></div>
      <div class="absolute bottom-1/4 right-1/4 w-80 h-80 bg-[var(--uplift-cyan-400)]/10 rounded-full blur-3xl"></div>
      <div class="absolute top-1/2 right-1/3 w-64 h-64 bg-[var(--uplift-indigo-700)]/30 rounded-full blur-3xl"></div>
    </div>

    <div class="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-20 text-center">
      <h1 class="text-4xl sm:text-5xl lg:text-7xl font-extrabold text-white tracking-tight leading-tight">
        Empower Your Team
        <br />
        <span class="bg-gradient-to-r from-[var(--uplift-violet-400)] to-[var(--uplift-cyan-400)] bg-clip-text text-transparent">
          with Training They'll
        </span>
        <br />
        Actually Complete
      </h1>

      <p class="mt-6 max-w-2xl mx-auto text-lg sm:text-xl text-white/70 leading-relaxed">
        Create beautiful courses in minutes, not weeks. Uplift makes it easy for
        small businesses to build engaging training content their employees love.
      </p>

      <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
        <a
          href="#get-started"
          class="rounded-full bg-[var(--uplift-violet-500)] px-8 py-3.5 text-base font-semibold text-white shadow-lg shadow-[var(--uplift-violet-500)]/25 hover:bg-[var(--uplift-violet-400)] hover:shadow-[var(--uplift-violet-400)]/30 transition-all duration-200"
        >
          Get Started Free
        </a>
        <a
          href="#how-it-works"
          class="rounded-full border border-white/20 px-8 py-3.5 text-base font-semibold text-white hover:bg-white/10 transition-all duration-200"
        >
          See How it Works
        </a>
      </div>

      <%!-- Product preview mockup --%>
      <div class="mt-16 mx-auto max-w-4xl">
        <div class="rounded-xl bg-white/5 border border-white/10 p-2 shadow-2xl backdrop-blur-sm">
          <div class="rounded-lg bg-[var(--uplift-indigo-900)]/80 p-6 sm:p-8">
            <%!-- Fake course editor UI --%>
            <div class="flex items-center gap-3 mb-6">
              <div class="w-3 h-3 rounded-full bg-red-400/60"></div>
              <div class="w-3 h-3 rounded-full bg-yellow-400/60"></div>
              <div class="w-3 h-3 rounded-full bg-green-400/60"></div>
              <span class="ml-3 text-sm text-white/40">Course Editor — Uplift</span>
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div class="sm:col-span-1 space-y-3">
                <div class="rounded-lg bg-white/10 p-3 text-sm text-white/70">
                  <.icon name="hero-book-open" class="size-4 inline mr-2 text-[var(--uplift-violet-400)]" />Chapter 1: Getting Started
                </div>
                <div class="rounded-lg bg-[var(--uplift-violet-500)]/20 border border-[var(--uplift-violet-500)]/30 p-3 text-sm text-white">
                  <.icon name="hero-document-text" class="size-4 inline mr-2 text-[var(--uplift-cyan-400)]" />Lesson 2: Core Concepts
                </div>
                <div class="rounded-lg bg-white/10 p-3 text-sm text-white/70">
                  <.icon name="hero-document-text" class="size-4 inline mr-2 text-[var(--uplift-violet-400)]" />Lesson 3: Best Practices
                </div>
              </div>
              <div class="sm:col-span-2 rounded-lg bg-white/5 p-4">
                <div class="h-3 w-3/4 bg-white/20 rounded mb-3"></div>
                <div class="h-3 w-full bg-white/10 rounded mb-2"></div>
                <div class="h-3 w-full bg-white/10 rounded mb-2"></div>
                <div class="h-3 w-5/6 bg-white/10 rounded mb-4"></div>
                <div class="h-24 w-full bg-white/5 rounded border border-white/10"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
```

**Step 2: Verify in browser**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `http://localhost:4000` and verify:
- Hero fills the viewport
- Gradient background with blurred decorative elements
- Headline with gradient text
- Two CTA buttons
- Faux course editor preview

**Step 3: Commit**

```bash
git add lib/lms_web/controllers/page_html/home.html.heex
git commit -m "feat: add hero section with headline, CTAs, and product preview"
```

---

### Task 5: Build the Features Section

Add the features section with a 4-card grid below the hero.

**Files:**
- Modify: `lib/lms_web/controllers/page_html/home.html.heex`

**Step 1: Add the features section**

In `home.html.heex`, after the closing `</section>` of the hero and before the closing `</div>` of the page wrapper, add:

```heex
  <%!-- Features Section --%>
  <section id="features" class="relative bg-white py-24 sm:py-32">
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="text-center mb-16">
        <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 tracking-tight">
          Everything you need to train your team
        </h2>
        <p class="mt-4 max-w-2xl mx-auto text-lg text-gray-500">
          Simple, powerful tools designed for small businesses that want to invest in their people.
        </p>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
        <%!-- Feature 1: Easy Course Builder --%>
        <div class="group rounded-2xl bg-gray-50 p-8 hover:bg-[var(--uplift-indigo-950)] hover:shadow-xl transition-all duration-300">
          <div class="mb-5 inline-flex items-center justify-center w-12 h-12 rounded-xl bg-[var(--uplift-violet-500)]/10 group-hover:bg-[var(--uplift-violet-500)]/20 transition-colors">
            <.icon name="hero-pencil-square" class="size-6 text-[var(--uplift-violet-500)]" />
          </div>
          <h3 class="text-lg font-semibold text-gray-900 group-hover:text-white transition-colors">
            Easy Course Builder
          </h3>
          <p class="mt-2 text-sm text-gray-500 group-hover:text-white/70 transition-colors leading-relaxed">
            Create structured courses with chapters and lessons using a simple drag-and-drop editor. No technical skills required.
          </p>
        </div>

        <%!-- Feature 2: Progress Tracking --%>
        <div class="group rounded-2xl bg-gray-50 p-8 hover:bg-[var(--uplift-indigo-950)] hover:shadow-xl transition-all duration-300">
          <div class="mb-5 inline-flex items-center justify-center w-12 h-12 rounded-xl bg-[var(--uplift-cyan-400)]/10 group-hover:bg-[var(--uplift-cyan-400)]/20 transition-colors">
            <.icon name="hero-chart-bar" class="size-6 text-[var(--uplift-cyan-400)]" />
          </div>
          <h3 class="text-lg font-semibold text-gray-900 group-hover:text-white transition-colors">
            Progress Tracking
          </h3>
          <p class="mt-2 text-sm text-gray-500 group-hover:text-white/70 transition-colors leading-relaxed">
            See exactly where every employee is in their training. Track completions, identify who needs a nudge.
          </p>
        </div>

        <%!-- Feature 3: Team Management --%>
        <div class="group rounded-2xl bg-gray-50 p-8 hover:bg-[var(--uplift-indigo-950)] hover:shadow-xl transition-all duration-300">
          <div class="mb-5 inline-flex items-center justify-center w-12 h-12 rounded-xl bg-[var(--uplift-violet-500)]/10 group-hover:bg-[var(--uplift-violet-500)]/20 transition-colors">
            <.icon name="hero-user-group" class="size-6 text-[var(--uplift-violet-500)]" />
          </div>
          <h3 class="text-lg font-semibold text-gray-900 group-hover:text-white transition-colors">
            Team Management
          </h3>
          <p class="mt-2 text-sm text-gray-500 group-hover:text-white/70 transition-colors leading-relaxed">
            Invite employees individually or in bulk via CSV. Manage enrollments and roles from one dashboard.
          </p>
        </div>

        <%!-- Feature 4: Flexible Deployment --%>
        <div class="group rounded-2xl bg-gray-50 p-8 hover:bg-[var(--uplift-indigo-950)] hover:shadow-xl transition-all duration-300">
          <div class="mb-5 inline-flex items-center justify-center w-12 h-12 rounded-xl bg-[var(--uplift-cyan-400)]/10 group-hover:bg-[var(--uplift-cyan-400)]/20 transition-colors">
            <.icon name="hero-cloud-arrow-up" class="size-6 text-[var(--uplift-cyan-400)]" />
          </div>
          <h3 class="text-lg font-semibold text-gray-900 group-hover:text-white transition-colors">
            Flexible Deployment
          </h3>
          <p class="mt-2 text-sm text-gray-500 group-hover:text-white/70 transition-colors leading-relaxed">
            Integrate with your company's SSO/LDAP or use simple email-based access. Works with your existing infrastructure.
          </p>
        </div>
      </div>
    </div>
  </section>
```

**Step 2: Verify in browser**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `http://localhost:4000` and scroll to Features:
- 4 cards in a row on desktop, 2 on tablet, 1 on mobile
- Cards have hover effect (background changes to dark indigo, text turns white)
- Icons visible with correct colors

**Step 3: Commit**

```bash
git add lib/lms_web/controllers/page_html/home.html.heex
git commit -m "feat: add features section with 4 interactive cards"
```

---

### Task 6: Build the How it Works Section

Add the 3-step walkthrough section with dark background.

**Files:**
- Modify: `lib/lms_web/controllers/page_html/home.html.heex`

**Step 1: Add the how-it-works section**

In `home.html.heex`, after the features `</section>`, add:

```heex
  <%!-- How it Works Section --%>
  <section id="how-it-works" class="relative bg-[var(--uplift-indigo-950)] py-24 sm:py-32 overflow-hidden">
    <%!-- Subtle background decoration --%>
    <div class="absolute inset-0">
      <div class="absolute top-0 left-1/2 w-96 h-96 bg-[var(--uplift-violet-500)]/5 rounded-full blur-3xl -translate-x-1/2"></div>
    </div>

    <div class="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="text-center mb-16">
        <h2 class="text-3xl sm:text-4xl font-bold text-white tracking-tight">
          Up and running in three steps
        </h2>
        <p class="mt-4 max-w-2xl mx-auto text-lg text-white/60">
          No complex setup. No IT department required. Just start building.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-12 md:gap-8">
        <%!-- Step 1: Create --%>
        <div class="text-center">
          <div class="mx-auto mb-6 flex items-center justify-center w-16 h-16 rounded-2xl bg-[var(--uplift-violet-500)]/20 border border-[var(--uplift-violet-500)]/30">
            <span class="text-2xl font-bold text-[var(--uplift-violet-400)]">1</span>
          </div>
          <h3 class="text-xl font-semibold text-white mb-3">Create</h3>
          <p class="text-white/60 leading-relaxed">
            Build courses with chapters and lessons. Add content, organize your curriculum, and publish when ready.
          </p>
        </div>

        <%!-- Step 2: Invite --%>
        <div class="text-center">
          <div class="mx-auto mb-6 flex items-center justify-center w-16 h-16 rounded-2xl bg-[var(--uplift-cyan-400)]/20 border border-[var(--uplift-cyan-400)]/30">
            <span class="text-2xl font-bold text-[var(--uplift-cyan-300)]">2</span>
          </div>
          <h3 class="text-xl font-semibold text-white mb-3">Invite</h3>
          <p class="text-white/60 leading-relaxed">
            Add your team via email or SSO integration. They're in instantly — no complicated onboarding.
          </p>
        </div>

        <%!-- Step 3: Track --%>
        <div class="text-center">
          <div class="mx-auto mb-6 flex items-center justify-center w-16 h-16 rounded-2xl bg-[var(--uplift-violet-500)]/20 border border-[var(--uplift-violet-500)]/30">
            <span class="text-2xl font-bold text-[var(--uplift-violet-400)]">3</span>
          </div>
          <h3 class="text-xl font-semibold text-white mb-3">Track</h3>
          <p class="text-white/60 leading-relaxed">
            Monitor progress, see completions, and keep your team on track with real-time dashboards.
          </p>
        </div>
      </div>
    </div>
  </section>
```

**Step 2: Verify in browser**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `http://localhost:4000` and scroll to How it Works:
- Dark background section
- 3 steps side by side on desktop, stacked on mobile
- Numbered badges with colored borders

**Step 3: Commit**

```bash
git add lib/lms_web/controllers/page_html/home.html.heex
git commit -m "feat: add how-it-works section with 3-step walkthrough"
```

---

### Task 7: Build the Get Started and Footer Sections

Add the final CTA section and the footer.

**Files:**
- Modify: `lib/lms_web/controllers/page_html/home.html.heex`

**Step 1: Add the get-started section and footer**

In `home.html.heex`, after the how-it-works `</section>`, add:

```heex
  <%!-- Get Started Section --%>
  <section id="get-started" class="relative bg-white py-24 sm:py-32">
    <div class="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 text-center">
      <h2 class="text-3xl sm:text-4xl font-bold text-gray-900 tracking-tight">
        Ready to Uplift Your Team?
      </h2>
      <p class="mt-4 text-lg text-gray-500">
        Set up in minutes. No credit card required.
      </p>
      <div class="mt-10">
        <a
          href={~p"/companies/register"}
          class="rounded-full bg-[var(--uplift-violet-500)] px-10 py-4 text-lg font-semibold text-white shadow-lg shadow-[var(--uplift-violet-500)]/25 hover:bg-[var(--uplift-violet-400)] hover:shadow-[var(--uplift-violet-400)]/30 transition-all duration-200"
        >
          Get Started Free
        </a>
      </div>
    </div>
  </section>

  <%!-- Footer --%>
  <footer class="bg-[var(--uplift-indigo-950)] border-t border-white/10 py-12">
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col md:flex-row items-center justify-between gap-6">
        <span class="text-lg font-bold text-white tracking-tight">Uplift</span>
        <div class="flex items-center gap-6">
          <a href="#features" class="text-sm text-white/60 hover:text-white transition-colors">Features</a>
          <a href="#how-it-works" class="text-sm text-white/60 hover:text-white transition-colors">How it Works</a>
          <a href={~p"/users/log-in"} class="text-sm text-white/60 hover:text-white transition-colors">Log In</a>
        </div>
        <p class="text-sm text-white/40">&copy; {DateTime.utc_now().year} Uplift. All rights reserved.</p>
      </div>
    </div>
  </footer>
```

**Step 2: Verify in browser**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `http://localhost:4000` and scroll to the bottom:
- Get Started section with CTA button linking to `/companies/register`
- Footer with Uplift wordmark, nav links, and copyright

**Step 3: Commit**

```bash
git add lib/lms_web/controllers/page_html/home.html.heex
git commit -m "feat: add get-started CTA section and footer"
```

---

### Task 8: Update Root Layout for Landing Page

The root layout currently renders a top navigation bar with Register/Log in links. When on the landing page, we should hide this since the landing page has its own nav.

**Files:**
- Modify: `lib/lms_web/components/layouts/root.html.heex`
- Modify: `lib/lms_web/controllers/page_controller.ex`

**Step 1: Pass a flag to hide the root nav on the landing page**

In `lib/lms_web/controllers/page_controller.ex`, add an assign to suppress the root nav:

```elixir
def home(conn, _params) do
  conn
  |> put_layout(html: {LmsWeb.Layouts, :landing})
  |> assign(:hide_root_nav, true)
  |> render(:home)
end
```

**Step 2: Conditionally render the root nav**

In `lib/lms_web/components/layouts/root.html.heex`, wrap the `<ul class="menu ...">` block in a conditional:

```heex
<%= unless assigns[:hide_root_nav] do %>
  <ul class="menu menu-horizontal w-full relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
    <%!-- existing content unchanged --%>
  </ul>
<% end %>
```

**Step 3: Verify in browser**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `http://localhost:4000` — the default Register/Log In nav bar should be hidden.
Visit `http://localhost:4000/users/log-in` — the default nav bar should still appear.

**Step 4: Commit**

```bash
git add lib/lms_web/controllers/page_controller.ex lib/lms_web/components/layouts/root.html.heex
git commit -m "feat: hide root nav on landing page"
```

---

### Task 9: Update Page Title and Meta

Update the root layout's default title from "Lms" to "Uplift" and set a page title for the landing page.

**Files:**
- Modify: `lib/lms_web/components/layouts/root.html.heex`
- Modify: `lib/lms_web/controllers/page_controller.ex`

**Step 1: Update the default title in root layout**

In `root.html.heex`, change:

```heex
<.live_title default="Lms" suffix=" · Phoenix Framework">
```

to:

```heex
<.live_title default="Uplift" suffix=" · LMS">
```

**Step 2: Set page title in PageController**

In `page_controller.ex`, update the `home` action to assign a page title:

```elixir
def home(conn, _params) do
  conn
  |> put_layout(html: {LmsWeb.Layouts, :landing})
  |> assign(:hide_root_nav, true)
  |> assign(:page_title, "Empower Your Team with Training They'll Actually Complete")
  |> render(:home)
end
```

**Step 3: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `http://localhost:4000` — browser tab should show: "Empower Your Team with Training They'll Actually Complete · LMS"

**Step 4: Commit**

```bash
git add lib/lms_web/components/layouts/root.html.heex lib/lms_web/controllers/page_controller.ex
git commit -m "feat: update page title and branding to Uplift"
```

---

### Task 10: Run Full Test Suite and Fix Any Failures

Ensure existing tests still pass after all changes.

**Files:**
- Possibly modify: any file with test failures

**Step 1: Run the full test suite**

Run: `mix test`
Expected: All tests pass. If any fail, investigate and fix.

**Step 2: Run precommit checks**

Run: `mix precommit`
Expected: All checks pass (tests, credo, etc.).

**Step 3: Fix any issues found**

If tests fail, the most likely cause is the PageController test expecting the old Phoenix boilerplate content. Look in `test/lms_web/controllers/page_controller_test.exs` and update assertions to match the new landing page content.

For example, change:

```elixir
assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
```

to:

```elixir
assert html_response(conn, 200) =~ "Empower Your Team"
```

**Step 4: Commit fixes if any**

```bash
git add -A
git commit -m "fix: update tests for new landing page content"
```

---

## App-Wide Rebrand (Tasks 11-21)

> **Design Reference:** See `docs/plans/2026-03-04-uplift-ui-design.md` — Page Groups 2-9.

---

### Task 11: Rebrand DaisyUI Themes to Uplift Palette

Update the light and dark daisyUI theme tokens in `app.css` to use the Uplift color palette. This single change propagates the brand to every daisyUI component (buttons, badges, inputs, cards) across all authenticated pages.

**Files:**
- Modify: `assets/css/app.css`

**Step 1: Update the dark theme tokens**

In `assets/css/app.css`, find the `@plugin "../vendor/daisyui-theme"` block with `name: "dark"` and update these color values:

```css
@plugin "../vendor/daisyui-theme" {
  name: "dark";
  default: false;
  prefersdark: true;
  color-scheme: "dark";
  --color-base-100: oklch(22% 0.03 277);
  --color-base-200: oklch(18% 0.025 277);
  --color-base-300: oklch(14% 0.02 277);
  --color-base-content: oklch(95% 0.015 277);
  --color-primary: oklch(65% 0.25 285);
  --color-primary-content: oklch(98% 0.01 285);
  --color-secondary: oklch(55% 0.2 277);
  --color-secondary-content: oklch(98% 0.01 277);
  --color-accent: oklch(75% 0.15 195);
  --color-accent-content: oklch(15% 0.03 195);
  --color-neutral: oklch(30% 0.03 277);
  --color-neutral-content: oklch(95% 0.01 277);
  --color-info: oklch(65% 0.15 240);
  --color-info-content: oklch(98% 0.01 240);
  --color-success: oklch(65% 0.17 155);
  --color-success-content: oklch(98% 0.01 155);
  --color-warning: oklch(75% 0.15 75);
  --color-warning-content: oklch(20% 0.02 75);
  --color-error: oklch(60% 0.22 25);
  --color-error-content: oklch(98% 0.01 25);
  --radius-selector: 0.375rem;
  --radius-field: 0.375rem;
  --radius-box: 0.75rem;
  --size-selector: 0.25rem;
  --size-field: 0.25rem;
  --border: 1px;
  --depth: 1;
  --noise: 0;
}
```

**Step 2: Update the light theme tokens**

Find the `@plugin "../vendor/daisyui-theme"` block with `name: "light"` and update:

```css
@plugin "../vendor/daisyui-theme" {
  name: "light";
  default: true;
  prefersdark: false;
  color-scheme: "light";
  --color-base-100: oklch(99% 0.005 285);
  --color-base-200: oklch(96% 0.005 285);
  --color-base-300: oklch(92% 0.008 285);
  --color-base-content: oklch(20% 0.02 285);
  --color-primary: oklch(58% 0.24 285);
  --color-primary-content: oklch(98% 0.01 285);
  --color-secondary: oklch(48% 0.18 277);
  --color-secondary-content: oklch(98% 0.01 277);
  --color-accent: oklch(70% 0.15 195);
  --color-accent-content: oklch(15% 0.03 195);
  --color-neutral: oklch(40% 0.02 285);
  --color-neutral-content: oklch(98% 0.005 285);
  --color-info: oklch(60% 0.18 255);
  --color-info-content: oklch(98% 0.01 255);
  --color-success: oklch(62% 0.17 155);
  --color-success-content: oklch(98% 0.01 155);
  --color-warning: oklch(75% 0.15 75);
  --color-warning-content: oklch(20% 0.02 75);
  --color-error: oklch(58% 0.22 25);
  --color-error-content: oklch(98% 0.01 25);
  --radius-selector: 0.375rem;
  --radius-field: 0.375rem;
  --radius-box: 0.75rem;
  --size-selector: 0.25rem;
  --size-field: 0.25rem;
  --border: 1px;
  --depth: 1;
  --noise: 0;
}
```

**Step 3: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit any authenticated page — buttons, badges, and inputs should now use the violet/indigo/cyan palette.

**Step 4: Commit**

```bash
git add assets/css/app.css
git commit -m "feat: rebrand daisyUI themes to Uplift violet/indigo palette"
```

---

### Task 12: Rebrand the App Layout (Layouts.app)

Replace the generic Phoenix boilerplate navbar in `Layouts.app` with an Uplift-branded navigation bar that shows role-based links.

**Files:**
- Modify: `lib/lms_web/components/layouts.ex` (the `app` function)

**Step 1: Update the `app` function component**

Replace the existing `app` function's `~H` template in `lib/lms_web/components/layouts.ex`. The new nav should:

- Show the "Uplift" wordmark on the left linking to `/` (or `/dashboard` if authenticated)
- Show role-based navigation links in the center:
  - System admin: Companies
  - Company admin: Dashboard, Employees, Courses, Enrollments
  - Course creator: Courses
  - Employee: My Learning
- Show the theme toggle and user dropdown on the right
- Use `@current_scope` to determine the user's role and which links to show
- Style with Uplift brand colors: `bg-base-100` background, `text-primary` for active links

The nav links should use `<.link navigate={~p"/path"}>` for LiveView navigation. Use the existing `<.theme_toggle />` component.

**Step 2: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Log in and verify the nav shows correct links for the user's role. Check that the Uplift wordmark appears.

**Step 3: Commit**

```bash
git add lib/lms_web/components/layouts.ex
git commit -m "feat: rebrand Layouts.app with Uplift nav and role-based links"
```

---

### Task 13: Update Root Layout

Update the root layout to use Uplift branding in the `<head>` and conditionally show the auth nav.

**Files:**
- Modify: `lib/lms_web/components/layouts/root.html.heex`

**Step 1: Update the root layout**

Changes to make:
1. Update `<.live_title>` default from "Lms" to "Uplift" and suffix to " · LMS"
2. Wrap the `<ul class="menu ...">` in `<%= unless assigns[:hide_root_nav] do %>` conditional
3. Restyle the auth nav bar (Register/Log in links) to match Uplift branding: clean, minimal, with violet accent for primary action

**Step 2: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `/users/log-in` — should see the Uplift-styled auth nav. Visit `/` — root nav should be hidden (landing page has its own).

**Step 3: Commit**

```bash
git add lib/lms_web/components/layouts/root.html.heex
git commit -m "feat: rebrand root layout with Uplift title and styled auth nav"
```

---

### Task 14: Rebrand Authentication Pages

Update all auth page templates to use Uplift branding: centered card layouts, violet accent buttons, Uplift wordmark headers.

**Files:**
- Modify: `lib/lms_web/controllers/user_session_html/new.html.heex` (login)
- Modify: `lib/lms_web/controllers/user_registration_html/new.html.heex` (register)
- Modify: `lib/lms_web/live/company_registration_live.ex` (company register)
- Modify: `lib/lms_web/live/invitation_live/accept.ex` (invitation accept)
- Modify: `lib/lms_web/controllers/user_settings_html/edit.html.heex` (settings)

**Step 1: Update login page**

Restyle `new.html.heex` (user session):
- Add Uplift wordmark text above the form ("Uplift" in text-2xl font-bold text-primary)
- Add "Welcome back" heading below
- Style the form card with `rounded-2xl bg-base-100 shadow-lg p-8` wrapper
- Ensure buttons use `btn-primary` (which is now violet from theme update)
- Keep both login methods (magic link + password) with divider

**Step 2: Update registration page**

Restyle `new.html.heex` (user registration):
- Add Uplift wordmark + "Create your account" heading
- Wrap form in styled card
- Button uses `btn-primary`
- Footer link "Already have an account? Log in"

**Step 3: Update company registration**

In `company_registration_live.ex`, update the render function:
- Replace the generic icon header with "Uplift" wordmark text
- Keep the card layout but ensure it uses `rounded-2xl` and consistent spacing
- Ensure buttons use `btn-primary`

**Step 4: Update invitation accept**

In `accept.ex`, update the render function:
- Replace header with "Welcome to Uplift" text
- Keep envelope icon but style the card consistently
- Button uses `btn-primary`

**Step 5: Update settings page**

Restyle `edit.html.heex`:
- Add "Account Settings" page heading
- Wrap each form section in a styled card (`rounded-2xl bg-base-100 shadow-sm p-6`)
- Buttons use `btn-primary`

**Step 6: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit each auth page and verify consistent Uplift branding.

**Step 7: Commit**

```bash
git add lib/lms_web/controllers/user_session_html/new.html.heex lib/lms_web/controllers/user_registration_html/new.html.heex lib/lms_web/live/company_registration_live.ex lib/lms_web/live/invitation_live/accept.ex lib/lms_web/controllers/user_settings_html/edit.html.heex
git commit -m "feat: rebrand all authentication pages with Uplift design"
```

---

### Task 15: Rebrand Dashboard

Update the company admin dashboard to use the Uplift design language.

**Files:**
- Modify: `lib/lms_web/live/dashboard_live.ex`

**Step 1: Update the dashboard render function**

Changes:
- Stat card icons use `text-primary` (violet) and `text-accent` (cyan) instead of the old Phoenix colors
- Icon backgrounds use `bg-primary/10` and `bg-accent/10`
- Cards use `rounded-2xl` with hover lift effect (`hover:-translate-y-0.5 hover:shadow-md transition-all`)
- Quick action buttons: primary action uses `btn-primary`, others use `btn-ghost` or `btn-outline`
- Navigation cards use `rounded-2xl` with subtle hover effect
- Activity feed items use clean divider styling
- Page heading: "Dashboard" with company context

**Step 2: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Log in as company admin, visit `/dashboard` — verify violet/cyan accent colors on stat cards and consistent card styling.

**Step 3: Commit**

```bash
git add lib/lms_web/live/dashboard_live.ex
git commit -m "feat: rebrand dashboard with Uplift design system"
```

---

### Task 16: Rebrand Course Management Pages

Update course list, form, and editor to use Uplift design.

**Files:**
- Modify: `lib/lms_web/live/courses/course_list_live.ex`
- Modify: `lib/lms_web/live/courses/course_form_live.ex`
- Modify: `lib/lms_web/live/courses/course_editor_live.ex`

**Step 1: Update course list**

In `course_list_live.ex`:
- "New Course" button uses `btn-primary` (violet)
- Filter buttons and dropdowns use consistent styling
- Grid view cards use `rounded-2xl` with hover lift
- Status badges: Draft (`badge-neutral`), Published (`badge-primary`), Archived (`badge-ghost`)
- Cover image placeholders use gradient with Uplift colors
- Empty state icon uses `text-primary`

**Step 2: Update course form**

In `course_form_live.ex`:
- Form wrapper card uses `rounded-2xl bg-base-100 shadow-sm`
- Upload zone uses dashed border with `border-primary/30` accent
- Upload progress bar uses `bg-primary`
- Save button uses `btn-primary`

**Step 3: Update course editor**

In `course_editor_live.ex`:
- Sidebar background uses `bg-base-200`
- Selected lesson highlight uses `bg-primary/10 border-l-2 border-primary`
- Chapter headers use clean typography
- Drag handles styled subtly
- "Add Chapter" and "Add Lesson" buttons use `btn-ghost btn-sm text-primary`
- Save button uses `btn-primary`
- Previous/Next buttons use `btn-outline`

**Step 4: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `/courses`, create/edit a course, open the editor — verify consistent styling.

**Step 5: Commit**

```bash
git add lib/lms_web/live/courses/course_list_live.ex lib/lms_web/live/courses/course_form_live.ex lib/lms_web/live/courses/course_editor_live.ex
git commit -m "feat: rebrand course management pages with Uplift design"
```

---

### Task 17: Rebrand Employee Management

Update the employee list page with modals.

**Files:**
- Modify: `lib/lms_web/live/admin/employee_live/index.ex`

**Step 1: Update employee management**

Changes:
- "Invite Employee" button uses `btn-primary`, "Bulk Upload" uses `btn-ghost`
- Search input uses consistent styling
- Table uses clean `divide-y` with `hover:bg-base-200/50` row highlight
- Status badges: Active (`badge-success`), Invited (`badge-info`)
- Action buttons use `btn-ghost btn-xs`
- Pagination uses `join` button group with `btn-outline`
- Invite modal card uses `rounded-2xl` with proper heading
- Bulk upload modal uses styled drag-drop zone with `border-primary/30`

**Step 2: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `/admin/employees` — verify consistent table and button styling.

**Step 3: Commit**

```bash
git add lib/lms_web/live/admin/employee_live/index.ex
git commit -m "feat: rebrand employee management with Uplift design"
```

---

### Task 18: Rebrand Enrollment Management

Update the enrollment list page.

**Files:**
- Modify: `lib/lms_web/live/admin/enrollment_live/index.ex`

**Step 1: Update enrollment management**

Changes:
- "Enroll Employees" button uses `btn-primary`
- Progress bars use `bg-primary` fill on `bg-base-200` track, `rounded-full`
- Status badges: Not Started (`badge-neutral`), In Progress (`badge-primary`), Completed (`badge-success`), Overdue (`badge-error`)
- Table styling matches employee management (clean dividers, hover highlight)
- Pagination matches employee management
- Enroll modal uses consistent card styling

**Step 2: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Visit `/admin/enrollments` — verify progress bars and badges use Uplift colors.

**Step 3: Commit**

```bash
git add lib/lms_web/live/admin/enrollment_live/index.ex
git commit -m "feat: rebrand enrollment management with Uplift design"
```

---

### Task 19: Rebrand System Admin Pages

Update the company list page.

**Files:**
- Modify: `lib/lms_web/live/admin/company_list_live.ex`

**Step 1: Update company list**

Changes:
- Header count badge uses `badge-primary`
- Table styling matches other admin pages
- Count badges in columns use `badge-ghost badge-sm`
- Detail sidebar card uses `rounded-2xl bg-base-100 shadow-lg`
- Stat cards in detail sidebar use `text-primary` and `text-accent` icon colors
- Close button and action links use consistent styling

**Step 2: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Log in as system admin, visit `/admin/companies` — verify consistent styling.

**Step 3: Commit**

```bash
git add lib/lms_web/live/admin/company_list_live.ex
git commit -m "feat: rebrand system admin pages with Uplift design"
```

---

### Task 20: Rebrand Employee Learning Pages

Update My Learning and Course Viewer.

**Files:**
- Modify: `lib/lms_web/live/employee/my_learning_live.ex`
- Modify: `lib/lms_web/live/employee/course_viewer_live.ex`

**Step 1: Update My Learning**

In `my_learning_live.ex`:
- Section count badges use `badge-primary`
- Course cards use `rounded-2xl` with hover lift effect
- Progress bars use `bg-primary` fill, `rounded-full`
- Cover image area has subtle hover zoom
- Completion checkmarks use `text-success`
- Due date warnings use `text-warning` or `text-error`

**Step 2: Update Course Viewer**

In `course_viewer_live.ex`:
- Header progress bar uses `bg-primary` fill
- Sidebar chapter/lesson navigation:
  - Current lesson: `bg-primary/10` highlight with `border-l-2 border-primary`
  - Completed lessons: `text-success` checkmark icon
  - Pending lessons: `text-base-content/30` circle icon
  - Chapter progress badges use `badge-ghost badge-xs`
- "Mark as Complete" button uses `btn-primary`
- "Completed" badge uses `badge-success`
- Previous/Next buttons use `btn-outline`
- Mobile sidebar overlay uses `bg-base-300/50 backdrop-blur-sm`

**Step 3: Verify**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors.

Log in as employee, visit `/my-learning` and `/my-learning/:course_id` — verify progress bars, badges, and navigation use Uplift colors.

**Step 4: Commit**

```bash
git add lib/lms_web/live/employee/my_learning_live.ex lib/lms_web/live/employee/course_viewer_live.ex
git commit -m "feat: rebrand employee learning pages with Uplift design"
```

---

### Task 21: Final Test Suite and Precommit

Run all tests and precommit checks to ensure nothing is broken.

**Files:**
- Possibly modify: any file with test failures

**Step 1: Run the full test suite**

Run: `mix test`
Expected: All tests pass. If any fail, investigate and fix.

**Step 2: Run precommit checks**

Run: `mix precommit`
Expected: All checks pass.

**Step 3: Fix any issues found**

Common fixes needed:
- Test assertions referencing old text content (Phoenix boilerplate)
- Test assertions referencing old CSS classes
- Any compilation warnings from template changes

**Step 4: Commit fixes if any**

```bash
git add -A
git commit -m "fix: update tests and resolve precommit issues after Uplift rebrand"
```
