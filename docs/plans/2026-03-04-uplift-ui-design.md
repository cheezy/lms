# Uplift UI Design System

## Product

**Name:** Uplift
**Tagline:** Empower Your Team with Training They'll Actually Complete
**Target audience:** Small business decision-makers (HR directors, training managers, CTOs)

## Design Direction

**Style:** Bold & modern
**Palette:** Deep purple/indigo primary, vibrant electric violet and cyan accents, white text on dark sections, light neutrals on alternating sections
**Typography:** Clean sans-serif, large bold headlines, readable body text
**Feel:** Confident, contemporary, approachable for small businesses

### Color Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `--uplift-indigo-950` | `#1e1045` | Darkest backgrounds, nav on scroll, footers |
| `--uplift-indigo-900` | `#2d1b69` | Dark section backgrounds, sidebar |
| `--uplift-indigo-800` | `#3c2587` | Secondary dark surfaces |
| `--uplift-indigo-700` | `#4c30a5` | Hover states on dark surfaces |
| `--uplift-violet-500` | `#8b5cf6` | Primary accent — buttons, links, highlights |
| `--uplift-violet-400` | `#a78bfa` | Hover state for primary accent |
| `--uplift-cyan-400` | `#22d3ee` | Secondary accent — icons, badges, progress |
| `--uplift-cyan-300` | `#67e8f9` | Hover state for secondary accent |

### Typography Scale

- **Page title:** text-2xl/3xl, font-bold, tracking-tight
- **Section heading:** text-xl, font-semibold
- **Card title:** text-lg, font-semibold
- **Body text:** text-sm/base, text-base-content or white/70 on dark
- **Labels:** text-xs, uppercase, tracking-wider, font-medium
- **Small detail:** text-xs, text-base-content/50

### Shared UI Patterns

- **Buttons (primary):** `rounded-full bg-[var(--uplift-violet-500)] text-white hover:bg-[var(--uplift-violet-400)]` with shadow
- **Buttons (secondary/ghost):** `border border-white/20 text-white hover:bg-white/10` or `text-[var(--uplift-violet-500)] hover:bg-[var(--uplift-violet-500)]/10`
- **Cards:** `rounded-2xl` with subtle border, hover lift (`hover:-translate-y-1 hover:shadow-lg transition-all`)
- **Badges:** Rounded-full, small, colored by status (violet for active, cyan for info, green for success, red for error)
- **Tables:** Clean with `divide-y` rows, hover highlight, no heavy zebra striping
- **Empty states:** Centered icon + heading + description + CTA button
- **Loading states:** Button text changes to "Saving..." / "Loading..." with subtle animation
- **Modals:** Backdrop blur overlay, slide-in from right or centered card
- **Progress bars:** Rounded-full, `bg-[var(--uplift-violet-500)]` fill on `bg-base-200` track

---

## Authentication Model

Two paths into the app:
1. **Federated identity** — company integrates SSO/LDAP, employees are authenticated automatically
2. **Email-domain matching** — no SSO, users register with company email and are matched to their company by domain

---

## Page Inventory

### Page Group 1: Landing Page (Public)

**Route:** `GET /`
**Layout:** Custom `landing` layout (no app chrome)
**File:** `lib/lms_web/controllers/page_html/home.html.heex`

Single page with sectioned layout and sticky navigation. Visitors scroll through all sections or jump via nav links.

#### 1.1 Sticky Navigation Bar

- Transparent on page load, transitions to solid `--uplift-indigo-950` with backdrop blur on scroll
- **Left:** Uplift wordmark (text-2xl font-bold text-white)
- **Center-Right:** Section links — Features, How it Works, Get Started
- **Far Right:** "Log In" text link + "Get Started" solid button (violet accent, rounded-full)
- **Mobile:** Logo + hamburger icon, collapsible menu

#### 1.2 Hero Section

- Full viewport height, deep indigo/purple gradient background
- Decorative blurred gradient orbs (violet, cyan) for depth
- **Headline:** "Empower Your Team with Training They'll Actually Complete" — gradient text (violet → cyan)
- **Subtext:** "Create beautiful courses in minutes, not weeks. Uplift makes it easy for small businesses to build engaging training content their employees love."
- **Buttons:** Primary "Get Started Free" (violet, solid, shadow) + Secondary "See How it Works" (outlined/ghost)
- **Visual:** Stylized mockup of the course editor UI (faux browser window with chapter/lesson sidebar)

#### 1.3 Features Section

White background for contrast. 4 feature cards in a responsive grid (4 cols desktop, 2 tablet, 1 mobile):

1. **Easy Course Builder** (icon: hero-pencil-square) — Create structured courses with chapters and lessons using a simple drag-and-drop editor. No technical skills required.
2. **Progress Tracking** (icon: hero-chart-bar) — See exactly where every employee is in their training. Track completions, identify who needs a nudge.
3. **Team Management** (icon: hero-user-group) — Invite employees individually or in bulk via CSV. Manage enrollments and roles from one dashboard.
4. **Flexible Deployment** (icon: hero-cloud-arrow-up) — Integrate with your company's SSO/LDAP or use simple email-based access. Works with your existing infrastructure.

Each card: hover effect transitions background to `--uplift-indigo-950` with white text.

#### 1.4 How it Works Section

Dark background (`--uplift-indigo-950`). Three-step visual walkthrough, horizontal on desktop, stacked on mobile:

1. **Create** — Build courses with chapters and lessons. Add content, organize, publish.
2. **Invite** — Add your team via email or SSO integration. They're in instantly.
3. **Track** — Monitor progress, see completions, keep your team on track.

Each step: numbered badge with colored border, title, one-sentence description.

#### 1.5 Get Started Section

White background. Centered CTA:
- **Headline:** "Ready to Uplift Your Team?"
- **Subtext:** "Set up in minutes. No credit card required."
- **Button:** "Get Started Free" linking to `/companies/register`

#### 1.6 Footer

`--uplift-indigo-950` background, border-t border-white/10:
- Uplift wordmark, nav links (Features, How it Works, Log In), copyright

---

### Page Group 2: Authentication Pages

All auth pages use the `Layouts.app` wrapper. They share a centered card layout with the Uplift brand.

#### 2.1 Login (`/users/log-in`)

**File:** `lib/lms_web/controllers/user_session_html/new.html.heex`

- Centered card (max-w-md), rounded-2xl, subtle shadow
- **Header:** Uplift wordmark + "Welcome back" heading
- **Magic link section:** Email input + "Send magic link" button (primary)
- **Divider:** "or sign in with password"
- **Password section:** Email + password inputs + "Sign in" button
- **Footer links:** "Sign up" for new accounts, "Forgot password" if applicable
- Buttons use violet accent styling

#### 2.2 Registration (`/users/register`)

**File:** `lib/lms_web/controllers/user_registration_html/new.html.heex`

- Same centered card style as login
- **Header:** Uplift wordmark + "Create your account" heading
- Email input + submit button
- **Footer link:** "Already have an account? Log in"

#### 2.3 Company Registration (`/companies/register`)

**File:** `lib/lms_web/live/company_registration_live.ex`

- Centered card, slightly wider (max-w-lg)
- **Header:** Building icon + "Register Your Company" heading + descriptive subtext
- **Company section:** Company name input
- **Admin section:** Name, email, password, password confirmation
- **Button:** "Create Company" (primary, full-width)
- **Footer link:** "Already have an account? Log in"

#### 2.4 Accept Invitation (`/invitations/:token`)

**File:** `lib/lms_web/live/invitation_live/accept.ex`

- Centered card (max-w-md)
- **Header:** Envelope icon + "Welcome to Uplift" heading
- Display invited email (read-only)
- Password input to activate account
- **Button:** "Activate Account" (primary)

#### 2.5 User Settings (`/users/settings`)

**File:** `lib/lms_web/controllers/user_settings_html/edit.html.heex`

- Two-column or stacked card layout (max-w-2xl)
- **Email change card:** Current email shown, new email input, submit
- **Password change card:** Current password, new password, confirmation, submit
- Cards use subtle border/shadow consistent with design system

---

### Page Group 3: App Layout (Shared Chrome)

**Files:**
- `lib/lms_web/components/layouts.ex` (the `app` function)
- `lib/lms_web/components/layouts/root.html.heex`

The app layout wraps all authenticated pages and provides consistent navigation.

#### 3.1 Root Layout (`root.html.heex`)

- Conditionally show/hide root nav (hidden on landing page via `hide_root_nav` assign)
- When shown: horizontal menu with user email, Settings link, Log out link
- Brand the menu with Uplift styling

#### 3.2 App Layout (`Layouts.app`)

Replace generic Phoenix boilerplate nav with Uplift-branded navigation:

- **Header/Navbar:**
  - **Left:** Uplift wordmark (link to dashboard or landing depending on auth state)
  - **Center:** Role-based navigation links:
    - System admin: Companies
    - Company admin: Dashboard, Employees, Courses, Enrollments
    - Course creator: Courses
    - Employee: My Learning
  - **Right:** User email/avatar, Settings link, theme toggle, Log out
- **Main content:** Padded container with max-width appropriate to content
- Background: subtle `bg-base-100` with the Uplift color tokens integrated into the daisyUI theme

#### 3.3 DaisyUI Theme Update

Update the light and dark themes in `app.css` to use the Uplift palette:

**Light theme adjustments:**
- Primary: `--uplift-violet-500` (`#8b5cf6`)
- Secondary: `--uplift-indigo-700` (`#4c30a5`)
- Accent: `--uplift-cyan-400` (`#22d3ee`)

**Dark theme adjustments:**
- Primary: `--uplift-violet-500` (`#8b5cf6`)
- Base backgrounds: derived from `--uplift-indigo-950` / `--uplift-indigo-900`
- Accent: `--uplift-cyan-400`

This ensures all daisyUI components (buttons, badges, inputs) automatically pick up the Uplift brand colors.

---

### Page Group 4: Dashboard

**Route:** `/dashboard`
**File:** `lib/lms_web/live/dashboard_live.ex`
**Access:** Company admins, system admins

- **Page header:** "Dashboard" title with company name subtitle
- **Stats grid:** 4 cards (2x2 on mobile, 4x1 on desktop)
  - Total Employees, Courses, Enrollments, Completion Rate
  - Each card: icon in a colored circle (`--uplift-violet-500` or `--uplift-cyan-400`), large value, label, detail text
  - Cards have subtle hover lift
- **Quick actions:** Row of 3 buttons (Invite Employee, Create Course, Manage Enrollments)
  - Primary button style for the main action, ghost/outline for others
- **Activity feed:** Two-column layout (recent enrollments, recent completions)
  - Clean list items with avatar placeholder, name, course, timestamp
- **Navigation cards:** 3 cards linking to main sections (Employees, Courses, Enrollments)
  - Icon + title + description + arrow indicator
  - Hover lift effect

---

### Page Group 5: Course Management

#### 5.1 Course List (`/courses`)

**File:** `lib/lms_web/live/courses/course_list_live.ex`
**Access:** Course creators, company admins, system admins

- **Header:** "Courses" title + "New Course" button (primary, violet)
- **Filters row:** Status dropdown (All, Draft, Published, Archived) + Grid/List toggle buttons
- **Grid view (default):** 3 columns (lg), 2 (md), 1 (sm)
  - Card: cover image area (gradient placeholder if no image), title, status badge, truncated description, action buttons (Edit, Publish/Archive/Delete)
  - Cards use rounded-2xl, hover lift
  - Status badges: Draft (neutral), Published (violet), Archived (gray)
- **List view:** Clean table with cover thumbnail, title, status, description, actions
- **Empty state:** Centered icon + "No courses yet" + "Create your first course" button

#### 5.2 Course Form (`/courses/new`, `/courses/:id/edit`)

**File:** `lib/lms_web/live/courses/course_form_live.ex`

- **Header:** Back arrow + "New Course" or "Edit Course" title
- **Form card:** Centered (max-w-2xl), rounded-2xl, subtle shadow
  - Title input (standard `.input` component)
  - Description textarea
  - Cover image upload with drag-drop zone, preview, progress bar
  - File restrictions note (types, max size)
- **Actions:** Cancel (ghost) + Save (primary) buttons

#### 5.3 Course Editor (`/courses/:id/editor`)

**File:** `lib/lms_web/live/courses/course_editor_live.ex`

- **Header bar:** Back button, course title, "Course Editor" label, archived badge if applicable
- **Two-panel layout:**
  - **Left sidebar (w-80):** Chapter/lesson tree
    - "Contents" heading + "Add Chapter" button
    - Collapsible chapters with drag handles
    - Lessons nested under chapters, click to select
    - Selected lesson highlighted with `--uplift-violet-500`/10 background
    - Hover states on items
    - Add lesson button per chapter
  - **Main content area:**
    - Lesson title + move dropdown
    - TipTap rich text editor with toolbar
    - Image upload button + save button (primary)
    - Previous/Next lesson navigation
    - Read-only mode for archived courses

---

### Page Group 6: Employee Management

**Route:** `/admin/employees`
**File:** `lib/lms_web/live/admin/employee_live/index.ex`
**Access:** Company admins, system admins

- **Header:** "Employees" title + "Bulk Upload" (ghost) + "Invite Employee" (primary) buttons
- **Filters row:** Search input (with debounce) + Status dropdown (All, Active, Invited)
- **Table:** Clean table with hover row highlight
  - Columns: Name, Email, Status badge, Role, Actions
  - Status badges: Active (green/success), Invited (violet/info)
  - Actions: Resend invitation (for invited), Promote/Demote buttons
- **Pagination:** "Showing X of Y" + Previous/Next buttons + page numbers
- **Empty states:** No employees, no search results
- **Invite modal:** Slide-in from right, form with name + email inputs
- **Bulk upload modal:** Slide-in, CSV file upload with drag-drop zone

---

### Page Group 7: Enrollment Management

**Route:** `/admin/enrollments`
**File:** `lib/lms_web/live/admin/enrollment_live/index.ex`
**Access:** Company admins, system admins

- **Header:** "Enrollments" title + "Enroll Employees" button (primary)
- **Filters row:** Search input + Course dropdown + Status dropdown (All, Not Started, In Progress, Completed, Overdue)
- **Table:** Clean table
  - Columns: Employee (name + email), Course, Due Date, Progress (bar + percentage), Status badge
  - Progress bars: `--uplift-violet-500` fill
  - Status badges: Not Started (neutral), In Progress (violet), Completed (green), Overdue (red)
- **Pagination:** Same pattern as employees
- **Enroll modal:** Slide-in, multi-select for employees and courses

---

### Page Group 8: System Admin

**Route:** `/admin/companies`
**File:** `lib/lms_web/live/admin/company_list_live.ex`
**Access:** System admins only

- **Header:** "Companies" title + total count badge
- **Search:** Input with debounce
- **Table:** Company name (clickable), Employees count, Courses count, Enrollments count, Created date, View link
  - Count columns use small badges
- **Detail sidebar:** Slides in from right when a company is selected
  - Company name as title
  - 2x2 stat card grid (Employees, Courses, Enrollments, Created)
  - Stat cards use Uplift accent colors for icons
  - Details section with slug and timestamps

---

### Page Group 9: Employee Learning

#### 9.1 My Learning (`/my-learning`)

**File:** `lib/lms_web/live/employee/my_learning_live.ex`
**Access:** All authenticated users

- **Header:** "My Learning" title
- **Sections** (each collapsible with count badge):
  1. **In Progress:** Course cards showing cover image, title, progress bar (violet), lesson count (X of Y), last activity, due date
  2. **Not Started:** Course cards with due date or "No due date"
  3. **Completed:** Course cards with checkmark and completion date
- **Card grid:** 3 columns (lg), 2 (md), 1 (sm)
- Cards: rounded-2xl, cover image with subtle hover zoom, hover lift
- Progress bars: `--uplift-violet-500` fill, rounded-full
- **Empty state:** "No courses assigned yet" with friendly message

#### 9.2 Course Viewer (`/my-learning/:course_id`)

**File:** `lib/lms_web/live/employee/course_viewer_live.ex`
**Access:** All authenticated users

- **Header bar:**
  - Back to My Learning link
  - Course title
  - Overall progress bar (violet) + "X of Y lessons complete"
  - Mobile: hamburger toggle for sidebar
- **Two-panel layout:**
  - **Left sidebar (w-72, sticky):**
    - Chapter tree navigation
    - Chapter headers with title + progress badge (X/Y)
    - Lessons: completion icon (checkmark = done, circle = pending)
    - Current lesson highlighted with `--uplift-violet-500`/10 background
    - Mobile: overlay sidebar with backdrop
  - **Main content area:**
    - Lesson title (text-2xl font-bold)
    - "Mark as Complete" button (primary) or "Completed" badge (green)
    - Rendered lesson content (prose styling)
    - Previous/Next lesson navigation buttons at bottom

---

## Responsive Behavior (Global)

- **Desktop (1024px+):** Full layouts as described, multi-column grids, side-by-side panels
- **Tablet (768-1023px):** Reduced columns, sidebars collapse or stack
- **Mobile (<768px):** Single column, hamburger nav, stacked sections, overlay sidebars, larger touch targets

## Technical Notes

- Landing page: Static Phoenix controller page, custom `landing` layout
- All other pages: LiveView with `Layouts.app` wrapper
- Styling: Tailwind CSS v4 classes with Uplift CSS custom properties
- DaisyUI themes updated to use Uplift palette
- Icons: Heroicons via `<.icon name="hero-*">`
- Animations: CSS transitions only (hover lifts, color changes, sidebar slides)
- No external JS libraries beyond what's already in the project
