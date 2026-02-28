# Employee Invitation Flow Design

## Problem

Company admins need to invite individual employees by email. The invited user receives a link to set their password and join the company.

## Schema Changes

Add `:status` field to User as `Ecto.Enum` with values `:active`, `:invited`, `:deactivated`. Default `:active`. New migration required.

Existing fields used: `invitation_token` (stores hashed token), `invitation_sent_at`, `invitation_accepted_at`.

## Accounts Context — New Functions

- `invite_employee(scope, attrs)` — Creates user with `role: :employee`, `status: :invited`, no password. Generates 32-byte crypto-random token, stores SHA-256 hash in `invitation_token`, sets `invitation_sent_at`. Scoped to admin's company. Delivers invitation email. Returns `{:ok, user}` or `{:error, changeset}`.
- `get_user_by_invitation_token(token)` — Hashes raw token, looks up user, checks 7-day expiration. Returns `user` or `nil`.
- `accept_invitation(user, password)` — Sets password, clears `invitation_token`, sets `invitation_accepted_at`, changes status to `:active`, confirms user. Returns `{:ok, user}` or `{:error, changeset}`.

## Email

`UserNotifier.deliver_invitation_instructions(user, url)` — Plain text email with acceptance link. Follows existing notifier patterns.

## LiveView — Admin Employee Management

- `EmployeeLive.Index` — Lists employees for admin's company. "Invite Employee" button opens modal.
- `EmployeeLive.InviteFormComponent` — Modal with name and email fields. Validates, invites, delivers email, closes with flash.

## LiveView — Invitation Acceptance

- `InvitationLive.Accept` — Public (unauthenticated) page at `/invitations/:token`. Validates token, shows password form. On submit accepts invitation, logs user in, redirects to dashboard.

## Routes

- `/admin/employees` — `:company_admin` live_session
- `/invitations/:token` — unauthenticated scope

## Security

- 32-byte crypto-random tokens, base64url encoded
- SHA-256 hashed in DB
- 7-day expiration from `invitation_sent_at`
- Company-scoped (admin invites only to own company)
- Duplicate email check within same company
- No password in invitation email

## Testing

- Unit: token generation, expiration, company scoping, duplicate detection
- LiveView: employee list, invite form, acceptance page
- Edge cases: duplicate email (same company vs different), expired token, invalid email, empty name
