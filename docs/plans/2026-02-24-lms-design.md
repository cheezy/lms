# Learning Management System — Design Document

**Date:** 2026-02-24

## Overview

A web-based Learning Management System that allows companies to register, manage employees, create professional training courses, and track employee learning progress. Built with Phoenix 1.8, LiveView, and Tailwind CSS.

## User Roles

Four roles in a clear hierarchy:

- **System Admin** — Platform-level control. Can view and manage all companies. Created via seeds or CLI task (not self-registration).
- **Company Admin** — Manages their company's employees, courses, and enrollments. Has all Course Creator capabilities. Created during company registration.
- **Course Creator** — Creates and manages courses within their company. Cannot manage employees or enrollments. Added by Company Admin.
- **Employee** — Takes courses, tracks their own progress. Invited by Company Admin.

## Authentication & Registration

- Company registration is self-service. A single form collects company name, admin name, admin email, and password. This creates both the Company and the first Company Admin account.
- Employees and Course Creators receive an invitation email with a secure link to set their password. Invitations expire after a configurable period (e.g., 7 days). Admins can resend invitations.
- All users log in through the same login page. After login, they are routed to their role-appropriate dashboard.
- Built on `mix phx.gen.auth`, extended with role field and company association.
- All data is scoped to a company. Employees only see their company's courses. Admins and Creators only manage their own company's content. System Admins can see across companies.

## Company & Employee Management

### Employee Addition

- **Individual invite** — Company Admin enters an employee's name and email. The employee receives an invitation email.
- **Bulk upload** — Company Admin uploads a CSV file (columns: name, email). The system validates all rows, shows a preview with any errors (invalid email format, duplicates, already-existing employees), and lets the admin confirm. Invitation emails are sent to all valid entries.

### Employee List

- Searchable, sortable table of all employees with status (invited, active), enrollment count, and course completion stats.
- Admin can promote an employee to Course Creator or remove that role.
- Admin can resend invitations.

## Course Builder

### Course Structure

- **Course** — Title, description, cover image, status (draft, published, archived). Only published courses can be assigned to employees.
- **Chapter** — Ordered sections within a course. Title and optional description. Reorderable via drag-and-drop.
- **Lesson** — Ordered content within a chapter. Title and rich content body. Reorderable within a chapter or movable between chapters.

### Rich Text Editing

The lesson editor uses TipTap integrated with LiveView. Supports:

- Formatted text (headings, bold, italic, lists, links)
- Image uploads (drag-and-drop or click to upload, stored locally in dev / S3 in production)
- Video embeds (paste a YouTube/Vimeo URL, renders as embedded player)

TipTap editor loaded via app.js, communicating with LiveView via JS hooks. Editor content stored as JSON in the database, rendered to HTML for the course viewer.

### Course Workflow

- Courses start as **draft**. Creators can edit freely.
- When ready, the creator **publishes** the course, making it available for enrollment.
- Published courses can be **archived** to hide them from new enrollments while preserving existing enrollments and progress data.
- Published courses can still be edited (updates are live to enrolled employees).
- Only Company Admins can archive courses.

## Enrollment & Progress Tracking

### Enrollment

- Company Admins enroll employees in published courses, individually or in bulk (select multiple employees for a course).
- Optional due date can be set at enrollment time.
- Upon enrollment, the employee receives an email notification with the course name and due date (if set).
- An employee can only be enrolled once per course.

### Employee Dashboard

Three sections displaying course cards:

- **In Progress** — Courses started but not finished. Shows progress bar (e.g., "4 of 12 lessons complete"), last activity date, and due date if set.
- **Not Started** — Enrolled courses not yet opened. Shows due date if set.
- **Completed** — Finished courses. Shows completion date.

### Progress Tracking

- Progress tracked at the lesson level via an explicit "Mark as Complete" button.
- Course progress = completed lessons / total lessons, displayed as percentage and progress bar.
- Employees can navigate freely between lessons (no enforced order).
- Progress is per-enrollment (each employee has independent progress).

### Completion

- When all lessons are marked complete, the course status changes to "Completed" on the employee dashboard.
- Deleting a course is not allowed if enrollments exist (archive instead).

## Data Model

### Core Entities

- **Company** — name, slug. Has many users, courses, and enrollments.
- **User** — name, email, hashed_password, role (system_admin, company_admin, course_creator, employee), invitation_token, invitation_sent_at, invitation_accepted_at. Belongs to a Company (except system_admin).
- **Course** — title, description, cover_image, status (draft, published, archived). Belongs to a Company. Created by a User. Has many chapters.
- **Chapter** — title, description, position (for ordering). Belongs to a Course. Has many lessons.
- **Lesson** — title, content (rich text JSON from TipTap), position (for ordering). Belongs to a Chapter. Has many lesson images.
- **LessonImage** — file path/URL, metadata. Belongs to a Lesson. Tracks uploaded images for cleanup.
- **Enrollment** — due_date (optional), enrolled_at, completed_at. Belongs to a User and a Course. Has many lesson progresses.
- **LessonProgress** — completed_at. Belongs to an Enrollment and a Lesson. Represents one employee's completion of one lesson.

### Key Constraints

- An employee can only be enrolled once per course (unique index on user_id + course_id).
- Deleting a course is not allowed if enrollments exist.
- All queries scoped to company to prevent data leakage between organizations.

## Key Pages & Navigation

### System Admin
- Company list with stats (employee count, course count)
- Company detail view

### Company Admin Dashboard
- Overview stats (total employees, total courses, enrollment stats)
- Quick actions: add employee, create course, enroll employees
- Navigation to: Employees, Courses, Enrollments

### Company Admin — Employees Page
- Table with name, email, status, role, enrollment count
- Actions: add individual, bulk upload CSV, resend invitation, promote to course creator
- Search and filter

### Company Admin — Courses Page
- Grid or list of courses with cover image, title, status, enrollment count
- Actions: create new course, publish, archive

### Company Admin — Enrollments Page
- Table: employee name, course name, progress percentage, due date, status
- Enroll employees from this page
- Filter by course, employee, status (not started, in progress, completed, overdue)

### Course Creator — Course Editor
- Left sidebar with chapter/lesson tree (drag-and-drop reordering)
- Main content area with TipTap editor for the selected lesson
- Course settings panel (title, description, cover image, publish/archive)

### Employee Dashboard
- Three sections: In Progress, Not Started, Completed
- Course cards with progress bars and due dates
- Click a course to enter the course viewer

### Employee — Course Viewer
- Left sidebar with chapter/lesson navigation, checkmarks on completed lessons
- Main content area rendering the lesson content
- "Mark as Complete" button on each lesson
- Progress bar at the top

## Technical Approach

### Authentication
- `mix phx.gen.auth` as foundation
- Extended with role, company association, and invitation fields
- Authorization plugs/hooks to enforce role-based access per route

### LiveView Architecture
- Employee dashboard and course viewer — LiveView for real-time progress updates
- Course editor — LiveView for TipTap integration, drag-and-drop, image uploads
- Admin pages — LiveView for interactive tables with search/filter/sort
- Bulk CSV upload — LiveView for file upload, validation preview, confirmation

### Contexts
- `Accounts` — Users, authentication, invitations, role management
- `Companies` — Company registration and management
- `Training` — Courses, chapters, lessons, content management
- `Learning` — Enrollments, lesson progress, completion tracking

### File Uploads
- Phoenix LiveView built-in upload support for images and CSV files
- Local storage in development, S3-compatible storage in production
- Images associated with lessons for cleanup when lessons are deleted

### Email
- Swoosh for enrollment notifications and invitation emails
- HTML email templates

### TipTap Integration
- TipTap editor loaded via app.js, communicating with LiveView via JS hooks
- Content stored as JSON, rendered to HTML for viewing
