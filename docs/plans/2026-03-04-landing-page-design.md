# Uplift Landing Page Design

> **Full Design System:** For the complete UI design covering all pages, see `docs/plans/2026-03-04-uplift-ui-design.md`.

## Product

**Name:** Uplift
**Tagline:** Empower Your Team with Training They'll Actually Complete
**Target audience:** Small business decision-makers (HR directors, training managers, CTOs)

## Design Direction

**Style:** Bold & modern
**Palette:** Deep purple/indigo primary, vibrant accent (electric violet or bright cyan), white text on dark sections, light neutrals on alternating sections
**Typography:** Clean sans-serif, large bold headlines, readable body text
**Feel:** Confident, contemporary, approachable for small businesses

## Authentication Model

Two paths into the app:
1. **Federated identity** — company integrates SSO/LDAP, employees are authenticated automatically
2. **Email-domain matching** — no SSO, users register with company email and are matched to their company by domain

## Page Structure

Single page with sectioned layout and sticky navigation. Visitors scroll through all sections or jump via nav links.

### 1. Sticky Navigation Bar

- Transparent on page load, transitions to solid indigo with backdrop blur on scroll
- **Left:** Uplift wordmark/logo
- **Center-Right:** Section links — Features, How it Works, Get Started
- **Far Right:** "Log In" text link + "Get Started" solid button (accent color, rounded)
- **Mobile:** Logo + hamburger menu

### 2. Hero Section

- Full viewport height
- Deep indigo/purple gradient background with subtle geometric shapes or gradient mesh
- **Headline:** "Empower Your Team with Training They'll Actually Complete" — large, bold, white
- **Subtext:** "Create beautiful courses in minutes, not weeks. Uplift makes it easy for small businesses to build engaging training content their employees love."
- **Buttons:** Primary "Get Started Free" (accent color, solid) + Secondary "See How it Works" (outlined/ghost)
- **Visual:** Stylized illustration or screenshot of the course editor UI below the text

### 3. Features Section

Light/white background for contrast. 3-4 feature cards in a grid:

1. **Easy Course Builder** — Create structured courses with chapters and lessons using a simple drag-and-drop editor. No technical skills required.
2. **Progress Tracking** — See exactly where every employee is in their training. Track completions, identify who needs a nudge.
3. **Team Management** — Invite employees individually or in bulk via CSV. Manage enrollments and roles from one dashboard.
4. **Flexible Deployment** — Integrate with your company's SSO/LDAP or use simple email-based access. Works with your existing infrastructure.

Each card: icon (Heroicon), title, brief description. Subtle hover effect (lift/shadow).

### 4. How it Works Section

Dark background (deep indigo). Three-step visual walkthrough with connecting lines or arrows:

1. **Create** — Build courses with chapters and lessons. Add content, organize, publish.
2. **Invite** — Add your team via email or SSO integration. They're in instantly.
3. **Track** — Monitor progress, see completions, keep your team on track.

Each step: large number or icon, title, one-sentence description. Horizontal layout on desktop, vertical stack on mobile.

### 5. Get Started Section

Light background. Final call-to-action:

- **Headline:** "Ready to Uplift Your Team?"
- **Subtext:** Brief reassurance — "Set up in minutes. No credit card required."
- **Button:** "Get Started Free" (large, accent color)
- Optional: small trust indicators (e.g., "Trusted by X small businesses" or security badges) — can add later

### 6. Footer

Minimal footer:
- Uplift wordmark
- Links: Features, How it Works, Log In, Privacy, Terms
- Copyright line

## Messaging Hierarchy

1. **Primary:** Easy content creation — creating courses is fast and simple
2. **Secondary:** Employee engagement — employees actually complete training
3. **Supporting:** Team management, flexible deployment, progress visibility

## Responsive Behavior

- **Desktop (1024px+):** Full layout as described, horizontal feature grid, horizontal how-it-works steps
- **Tablet (768-1023px):** 2-column feature grid, steps stack or remain horizontal
- **Mobile (<768px):** Single column, hamburger nav, stacked sections, larger touch targets

## Technical Notes

- Built as a Phoenix controller page (not LiveView — no interactive state needed)
- Uses Tailwind CSS v4 classes directly (no daisyUI for the landing page to keep it custom)
- Smooth scroll behavior for nav links
- Intersection Observer for scroll-triggered nav background change
- All animations via CSS transitions (no JS animation libraries)
- Hero background: CSS gradient + decorative SVG shapes
