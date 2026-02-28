# Employee Invitation Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow company admins to invite employees by email with secure token-based acceptance flow.

**Architecture:** Add a `:status` field to User schema, then build invitation functions in the Accounts context using hashed tokens stored directly on the user record. Create admin LiveView for employee listing/inviting and a public LiveView for invitation acceptance. Follow existing phx.gen.auth token patterns for security.

**Tech Stack:** Phoenix 1.8, LiveView, Ecto, Swoosh, Bcrypt, Tailwind/daisyUI

---

### Task 1: Add status field to User schema

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_status_to_users.exs`
- Modify: `lib/lms/accounts/user.ex:7-22`

**Step 1: Create migration**

```bash
mix ecto.gen.migration add_status_to_users
```

Then edit the generated migration file:

```elixir
defmodule Lms.Repo.Migrations.AddStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :string, null: false, default: "active"
    end
  end
end
```

**Step 2: Run migration**

Run: `mix ecto.migrate`
Expected: Migration succeeds

**Step 3: Add status field to User schema**

In `lib/lms/accounts/user.ex`, add `@statuses` module attribute and the `:status` field to the schema:

```elixir
@statuses [:active, :invited, :deactivated]
```

Add to schema block after `:role`:

```elixir
field :status, Ecto.Enum, values: @statuses, default: :active
```

Add a public accessor:

```elixir
def statuses, do: @statuses
```

**Step 4: Add invitation_changeset to User**

Add a new changeset function in `lib/lms/accounts/user.ex` for creating invited users:

```elixir
@doc """
A changeset for creating an invited user.

Creates a user with status :invited, no password, and an invitation token.
The token is stored as a SHA-256 hash; the raw token is returned separately.
"""
def invitation_changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :name, :role, :company_id, :status])
  |> validate_required([:email, :name, :company_id])
  |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
    message: "must have the @ sign and no spaces"
  )
  |> validate_length(:email, max: 160)
  |> validate_length(:name, min: 1, max: 255)
  |> unsafe_validate_unique(:email, Lms.Repo)
  |> unique_constraint(:email)
  |> foreign_key_constraint(:company_id)
  |> put_invitation_token()
end

defp put_invitation_token(changeset) do
  if changeset.valid? do
    raw_token = :crypto.strong_rand_bytes(32)
    hashed_token = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
    encoded_token = Base.url_encode64(raw_token, padding: false)

    changeset
    |> put_change(:invitation_token, hashed_token)
    |> put_change(:invitation_sent_at, DateTime.utc_now(:second))
    |> put_change(:status, :invited)
    |> put_change(:confirmed_at, nil)
    |> Ecto.Changeset.prepare_changes(fn changeset ->
      Ecto.Changeset.put_change(changeset, :raw_invitation_token, encoded_token)
    end)
  else
    changeset
  end
end
```

Note: We need a virtual field for `raw_invitation_token`. Add to schema:

```elixir
field :raw_invitation_token, :string, virtual: true
```

Actually, we cannot use `prepare_changes` to set a virtual field after insert. Instead, we'll return the raw token separately from the changeset. Remove the `prepare_changes` call. The `invite_employee` function in Accounts will handle returning the raw token.

Revised `put_invitation_token`:

```elixir
defp put_invitation_token(changeset) do
  if changeset.valid? do
    raw_token = :crypto.strong_rand_bytes(32)
    hashed_token = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)

    changeset
    |> put_change(:invitation_token, hashed_token)
    |> put_change(:invitation_sent_at, DateTime.utc_now(:second))
    |> put_change(:status, :invited)
  else
    changeset
  end
end
```

The raw token will be generated in the Accounts context function instead.

**Step 5: Add accept_invitation_changeset to User**

```elixir
@doc """
A changeset for accepting an invitation.

Sets the password, clears the invitation token, marks the invitation as accepted,
sets status to :active, and confirms the user.
"""
def accept_invitation_changeset(user, attrs) do
  now = DateTime.utc_now(:second)

  user
  |> password_changeset(attrs)
  |> put_change(:invitation_token, nil)
  |> put_change(:invitation_accepted_at, now)
  |> put_change(:status, :active)
  |> put_change(:confirmed_at, now)
end
```

**Step 6: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors

**Step 7: Commit**

```bash
git add priv/repo/migrations/*add_status* lib/lms/accounts/user.ex
git commit -m "Add status field to users and invitation changesets"
```

---

### Task 2: Add invitation functions to Accounts context

**Files:**
- Modify: `lib/lms/accounts.ex`
- Test: `test/lms/accounts_test.exs`

**Step 1: Write failing tests for invite_employee**

Add to `test/lms/accounts_test.exs`:

```elixir
describe "invite_employee/2" do
  setup do
    company = Lms.CompaniesFixtures.company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    scope = Lms.Accounts.Scope.for_user(admin)
    %{scope: scope, company: company, admin: admin}
  end

  test "creates an invited user with invitation token", %{scope: scope} do
    attrs = %{name: "Jane Doe", email: "jane@example.com"}
    assert {:ok, user, _raw_token} = Accounts.invite_employee(scope, attrs)
    assert user.email == "jane@example.com"
    assert user.name == "Jane Doe"
    assert user.role == :employee
    assert user.status == :invited
    assert user.company_id == scope.user.company_id
    assert user.invitation_token != nil
    assert user.invitation_sent_at != nil
    assert is_nil(user.hashed_password)
    assert is_nil(user.confirmed_at)
  end

  test "returns raw token that is base64url encoded", %{scope: scope} do
    attrs = %{name: "Jane Doe", email: "jane@example.com"}
    assert {:ok, _user, raw_token} = Accounts.invite_employee(scope, attrs)
    assert {:ok, decoded} = Base.url_decode64(raw_token, padding: false)
    assert byte_size(decoded) == 32
  end

  test "invitation token in DB is SHA-256 hash of raw token", %{scope: scope} do
    attrs = %{name: "Jane Doe", email: "jane@example.com"}
    assert {:ok, user, raw_token} = Accounts.invite_employee(scope, attrs)
    {:ok, decoded} = Base.url_decode64(raw_token, padding: false)
    expected_hash = :crypto.hash(:sha256, decoded) |> Base.encode16(case: :lower)
    assert user.invitation_token == expected_hash
  end

  test "scopes invitation to admin's company", %{scope: scope} do
    attrs = %{name: "Jane Doe", email: "jane@example.com"}
    {:ok, user, _raw_token} = Accounts.invite_employee(scope, attrs)
    assert user.company_id == scope.user.company_id
  end

  test "returns error for duplicate email in same company", %{scope: scope} do
    attrs = %{name: "Jane Doe", email: "jane@example.com"}
    {:ok, _user, _raw_token} = Accounts.invite_employee(scope, attrs)
    assert {:error, changeset} = Accounts.invite_employee(scope, attrs)
    assert "has already been taken" in errors_on(changeset).email
  end

  test "returns error for invalid email", %{scope: scope} do
    attrs = %{name: "Jane Doe", email: "not-valid"}
    assert {:error, changeset} = Accounts.invite_employee(scope, attrs)
    assert "must have the @ sign and no spaces" in errors_on(changeset).email
  end

  test "returns error for empty name", %{scope: scope} do
    attrs = %{name: "", email: "jane@example.com"}
    assert {:error, changeset} = Accounts.invite_employee(scope, attrs)
    assert errors_on(changeset).name != []
  end

  test "sends invitation email", %{scope: scope} do
    attrs = %{name: "Jane Doe", email: "jane@example.com"}
    {:ok, _user, _raw_token} = Accounts.invite_employee(scope, attrs)
    assert_received {:email, %Swoosh.Email{to: [{"Jane Doe", "jane@example.com"}]}}
  end
end
```

Note: The `assert_received {:email, ...}` pattern depends on how Swoosh test adapter works. Check the test config. We may need to use `Swoosh.TestAssertions` instead. Let me use the actual Swoosh test pattern used in this project. Looking at the existing test, `extract_user_token` captures the email via a callback URL function — the notifier returns `{:ok, email}`. We'll verify email delivery by checking the return value and using `Swoosh.TestAssertions.assert_email_sent/1`.

Revised email test:

```elixir
test "sends invitation email", %{scope: scope} do
  attrs = %{name: "Jane Doe", email: "jane@example.com"}
  {:ok, _user, _raw_token} = Accounts.invite_employee(scope, attrs)
  assert_email_sent(subject: "You've been invited to join Lms")
end
```

Actually, let's keep it simpler — `invite_employee` will call the notifier internally and we verify the full flow works. We can test email separately via the notifier tests or check the invitation was created properly.

**Step 2: Run tests to verify they fail**

Run: `mix test test/lms/accounts_test.exs --max-failures 1`
Expected: FAIL — `invite_employee/2` is not defined

**Step 3: Implement invite_employee in Accounts**

Add to `lib/lms/accounts.ex`:

```elixir
## Employee Invitation

@invitation_validity_in_days 7

@doc """
Invites an employee to the admin's company.

Creates a user record with role :employee, status :invited, and a hashed
invitation token. Sends an invitation email with the raw token URL.

Returns `{:ok, user, raw_token}` or `{:error, changeset}`.
"""
def invite_employee(%Lms.Accounts.Scope{user: admin}, attrs) when is_map(attrs) do
  raw_token = :crypto.strong_rand_bytes(32)
  encoded_token = Base.url_encode64(raw_token, padding: false)
  hashed_token = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)

  invitation_attrs =
    attrs
    |> Map.put(:role, :employee)
    |> Map.put(:company_id, admin.company_id)
    |> Map.put(:status, :invited)

  changeset =
    %User{}
    |> User.invitation_changeset(invitation_attrs)
    |> Ecto.Changeset.put_change(:invitation_token, hashed_token)
    |> Ecto.Changeset.put_change(:invitation_sent_at, DateTime.utc_now(:second))

  case Repo.insert(changeset) do
    {:ok, user} ->
      {:ok, user, encoded_token}

    {:error, changeset} ->
      {:error, changeset}
  end
end
```

Wait — the `invitation_changeset` already sets `invitation_token` and `invitation_sent_at` via `put_invitation_token/1`. But we want the Accounts context to control the raw token so it can return it. Let me simplify: have the `invitation_changeset` NOT generate the token (just validate fields), and let the context function handle token generation.

Revised approach — simplify `invitation_changeset` in User to just validate, context handles token:

```elixir
# In User module:
def invitation_changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :name, :role, :company_id, :status, :invitation_token, :invitation_sent_at])
  |> validate_required([:email, :name, :company_id])
  |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
    message: "must have the @ sign and no spaces"
  )
  |> validate_length(:email, max: 160)
  |> validate_length(:name, min: 1, max: 255)
  |> unsafe_validate_unique(:email, Lms.Repo)
  |> unique_constraint(:email)
  |> foreign_key_constraint(:company_id)
end
```

Then in Accounts context:

```elixir
def invite_employee(%Lms.Accounts.Scope{user: admin}, attrs) when is_map(attrs) do
  raw_token = :crypto.strong_rand_bytes(32)
  encoded_token = Base.url_encode64(raw_token, padding: false)
  hashed_token = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)

  result =
    %User{}
    |> User.invitation_changeset(%{
      email: attrs[:email] || attrs["email"],
      name: attrs[:name] || attrs["name"],
      role: :employee,
      company_id: admin.company_id,
      status: :invited,
      invitation_token: hashed_token,
      invitation_sent_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()

  case result do
    {:ok, user} -> {:ok, user, encoded_token}
    {:error, changeset} -> {:error, changeset}
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/lms/accounts_test.exs`
Expected: All invitation tests pass (except possibly the email test — we'll add email delivery in Task 3)

**Step 5: Write failing tests for get_user_by_invitation_token**

Add to `test/lms/accounts_test.exs`:

```elixir
describe "get_user_by_invitation_token/1" do
  setup do
    company = Lms.CompaniesFixtures.company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    scope = Lms.Accounts.Scope.for_user(admin)
    attrs = %{name: "Jane Doe", email: unique_user_email()}
    {:ok, user, raw_token} = Accounts.invite_employee(scope, attrs)
    %{user: user, raw_token: raw_token}
  end

  test "returns user for valid token", %{user: user, raw_token: raw_token} do
    assert found_user = Accounts.get_user_by_invitation_token(raw_token)
    assert found_user.id == user.id
  end

  test "returns nil for invalid token" do
    refute Accounts.get_user_by_invitation_token("invalid-token")
  end

  test "returns nil for expired token", %{user: user, raw_token: raw_token} do
    expired_at = DateTime.utc_now(:second) |> DateTime.add(-8, :day)

    Lms.Accounts.User
    |> Ecto.Query.where(id: ^user.id)
    |> Lms.Repo.update_all(set: [invitation_sent_at: expired_at])

    refute Accounts.get_user_by_invitation_token(raw_token)
  end
end
```

**Step 6: Run tests to verify they fail**

Run: `mix test test/lms/accounts_test.exs --max-failures 1`
Expected: FAIL — `get_user_by_invitation_token/1` not defined

**Step 7: Implement get_user_by_invitation_token**

Add to `lib/lms/accounts.ex`:

```elixir
@doc """
Gets a user by their invitation token.

The raw (base64url-encoded) token is hashed and compared against the stored hash.
Returns nil if the token is invalid or expired (older than 7 days).
"""
def get_user_by_invitation_token(encoded_token) do
  with {:ok, decoded_token} <- Base.url_decode64(encoded_token, padding: false) do
    hashed_token = :crypto.hash(:sha256, decoded_token) |> Base.encode16(case: :lower)
    cutoff = DateTime.utc_now(:second) |> DateTime.add(-@invitation_validity_in_days, :day)

    User
    |> where([u], u.invitation_token == ^hashed_token)
    |> where([u], u.invitation_sent_at > ^cutoff)
    |> where([u], u.status == :invited)
    |> Repo.one()
  else
    :error -> nil
  end
end
```

**Step 8: Run tests to verify they pass**

Run: `mix test test/lms/accounts_test.exs`
Expected: PASS

**Step 9: Write failing tests for accept_invitation**

Add to `test/lms/accounts_test.exs`:

```elixir
describe "accept_invitation/2" do
  setup do
    company = Lms.CompaniesFixtures.company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    scope = Lms.Accounts.Scope.for_user(admin)
    attrs = %{name: "Jane Doe", email: unique_user_email()}
    {:ok, user, raw_token} = Accounts.invite_employee(scope, attrs)
    %{user: user, raw_token: raw_token}
  end

  test "accepts invitation and sets password", %{user: user} do
    assert {:ok, accepted_user} =
             Accounts.accept_invitation(user, %{password: "valid password 123"})

    assert accepted_user.status == :active
    assert accepted_user.confirmed_at != nil
    assert accepted_user.invitation_token == nil
    assert accepted_user.invitation_accepted_at != nil
    assert accepted_user.hashed_password != nil
    assert User.valid_password?(accepted_user, "valid password 123")
  end

  test "returns error for short password", %{user: user} do
    assert {:error, changeset} = Accounts.accept_invitation(user, %{password: "short"})
    assert "should be at least 12 character(s)" in errors_on(changeset).password
  end
end
```

**Step 10: Run tests to verify they fail**

Run: `mix test test/lms/accounts_test.exs --max-failures 1`
Expected: FAIL — `accept_invitation/2` not defined

**Step 11: Implement accept_invitation**

Add to `lib/lms/accounts.ex`:

```elixir
@doc """
Accepts an invitation by setting the user's password and activating the account.

Clears the invitation token, sets invitation_accepted_at, status to :active,
and confirms the user.
"""
def accept_invitation(%User{} = user, attrs) do
  user
  |> User.accept_invitation_changeset(attrs)
  |> Repo.update()
end
```

**Step 12: Run tests to verify they pass**

Run: `mix test test/lms/accounts_test.exs`
Expected: PASS

**Step 13: Commit**

```bash
git add lib/lms/accounts.ex test/lms/accounts_test.exs
git commit -m "Add invitation functions to Accounts context"
```

---

### Task 3: Add invitation email to UserNotifier

**Files:**
- Modify: `lib/lms/accounts/user_notifier.ex`
- Test: `test/lms/accounts/user_notifier_test.exs`

**Step 1: Write failing test**

Create `test/lms/accounts/user_notifier_test.exs`:

```elixir
defmodule Lms.Accounts.UserNotifierTest do
  use Lms.DataCase, async: true

  import Swoosh.TestAssertions

  alias Lms.Accounts.UserNotifier

  describe "deliver_invitation_instructions/2" do
    test "sends invitation email with URL" do
      user = %Lms.Accounts.User{email: "jane@example.com", name: "Jane"}
      url = "https://example.com/invitations/some-token"

      assert {:ok, email} = UserNotifier.deliver_invitation_instructions(user, url)

      assert email.to == [{"", "jane@example.com"}]
      assert email.subject == "You've been invited to join Lms"
      assert email.text_body =~ url
      assert email.text_body =~ "invited"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/lms/accounts/user_notifier_test.exs`
Expected: FAIL — function not defined

**Step 3: Implement deliver_invitation_instructions**

Add to `lib/lms/accounts/user_notifier.ex`:

```elixir
@doc """
Deliver invitation instructions to a new employee.
"""
def deliver_invitation_instructions(user, url) do
  deliver(user.email, "You've been invited to join Lms", """

  ==============================

  Hi #{user.name},

  You've been invited to join Lms. You can set up your account by visiting the URL below:

  #{url}

  This invitation will expire in 7 days.

  If you weren't expecting this invitation, please ignore this email.

  ==============================
  """)
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/lms/accounts/user_notifier_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/lms/accounts/user_notifier.ex test/lms/accounts/user_notifier_test.exs
git commit -m "Add invitation email to UserNotifier"
```

---

### Task 4: Wire up email delivery in invite_employee

**Files:**
- Modify: `lib/lms/accounts.ex`
- Test: `test/lms/accounts_test.exs`

**Step 1: Update invite_employee to accept a URL function and deliver email**

Modify `invite_employee` in `lib/lms/accounts.ex` to take a URL function parameter and call the notifier:

```elixir
def invite_employee(%Lms.Accounts.Scope{user: admin}, attrs, invitation_url_fun)
    when is_map(attrs) and is_function(invitation_url_fun, 1) do
  raw_token = :crypto.strong_rand_bytes(32)
  encoded_token = Base.url_encode64(raw_token, padding: false)
  hashed_token = :crypto.hash(:sha256, decoded_token) |> Base.encode16(case: :lower)

  result =
    %User{}
    |> User.invitation_changeset(%{
      email: attrs[:email] || attrs["email"],
      name: attrs[:name] || attrs["name"],
      role: :employee,
      company_id: admin.company_id,
      status: :invited,
      invitation_token: hashed_token,
      invitation_sent_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()

  case result do
    {:ok, user} ->
      UserNotifier.deliver_invitation_instructions(user, invitation_url_fun.(encoded_token))
      {:ok, user, encoded_token}

    {:error, changeset} ->
      {:error, changeset}
  end
end
```

**Step 2: Update tests to pass URL function**

Update all `invite_employee` calls in tests to pass a URL function:

```elixir
# Helper at top of test module or in setup
defp invitation_url_fun(token), do: "https://example.com/invitations/#{token}"

# In tests, change:
Accounts.invite_employee(scope, attrs)
# to:
Accounts.invite_employee(scope, attrs, &invitation_url_fun/1)
```

**Step 3: Run tests**

Run: `mix test test/lms/accounts_test.exs`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/lms/accounts.ex test/lms/accounts_test.exs
git commit -m "Wire up email delivery in invite_employee"
```

---

### Task 5: Add list_employees function to Accounts

**Files:**
- Modify: `lib/lms/accounts.ex`
- Test: `test/lms/accounts_test.exs`

**Step 1: Write failing test**

```elixir
describe "list_employees/1" do
  setup do
    company = Lms.CompaniesFixtures.company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    scope = Lms.Accounts.Scope.for_user(admin)
    %{scope: scope, company: company}
  end

  test "returns employees for the admin's company", %{scope: scope, company: company} do
    employee = user_with_role_fixture(:employee, company.id)
    _other_company_employee = user_with_role_fixture(:employee, Lms.CompaniesFixtures.company_fixture().id)

    employees = Accounts.list_employees(scope)
    assert length(employees) == 1
    assert hd(employees).id == employee.id
  end

  test "includes invited employees", %{scope: scope} do
    {:ok, invited, _token} = Accounts.invite_employee(scope, %{name: "New", email: unique_user_email()}, &"http://test/#{&1}")

    employees = Accounts.list_employees(scope)
    employee_ids = Enum.map(employees, & &1.id)
    assert invited.id in employee_ids
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/lms/accounts_test.exs --max-failures 1`
Expected: FAIL

**Step 3: Implement list_employees**

Add to `lib/lms/accounts.ex`:

```elixir
@doc """
Lists all employees (including invited) for the given scope's company.
"""
def list_employees(%Lms.Accounts.Scope{user: admin}) do
  User
  |> where([u], u.company_id == ^admin.company_id)
  |> where([u], u.role == :employee)
  |> order_by([u], asc: u.name)
  |> Repo.all()
end
```

**Step 4: Run tests**

Run: `mix test test/lms/accounts_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/lms/accounts.ex test/lms/accounts_test.exs
git commit -m "Add list_employees function to Accounts context"
```

---

### Task 6: Build admin employee list LiveView

**Files:**
- Create: `lib/lms_web/live/admin/employee_live/index.ex`
- Test: `test/lms_web/live/admin/employee_live/index_test.exs`
- Modify: `lib/lms_web/router.ex`

**Step 1: Add route**

In `lib/lms_web/router.ex`, add the employee route inside the existing `:company_admin` live_session:

```elixir
live_session :company_admin,
  on_mount: [
    {LmsWeb.Plugs.AuthorizationHooks, {:require_role, [:company_admin, :system_admin]}}
  ] do
  live "/dashboard", DashboardLive
  live "/admin/employees", Admin.EmployeeLive.Index
end
```

**Step 2: Write failing LiveView test**

Create `test/lms_web/live/admin/employee_live/index_test.exs`:

```elixir
defmodule LmsWeb.Admin.EmployeeLive.IndexTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  setup %{conn: conn} do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    conn = log_in_user(conn, admin)
    %{conn: conn, company: company, admin: admin}
  end

  describe "Index" do
    test "lists employees for the admin's company", %{conn: conn, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Employees"
      assert html =~ employee.email
    end

    test "shows invite button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/employees")
      assert html =~ "Invite Employee"
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `mix test test/lms_web/live/admin/employee_live/index_test.exs --max-failures 1`
Expected: FAIL

**Step 4: Create the LiveView**

Create `lib/lms_web/live/admin/employee_live/index.ex`:

```elixir
defmodule LmsWeb.Admin.EmployeeLive.Index do
  use LmsWeb, :live_view

  alias Lms.Accounts

  @impl true
  def mount(_params, _session, socket) do
    employees = Accounts.list_employees(socket.assigns.current_scope)

    socket =
      socket
      |> assign(:page_title, gettext("Employees"))
      |> assign(:employees, employees)
      |> assign(:show_invite_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _action, _params), do: socket

  @impl true
  def handle_info({LmsWeb.Admin.EmployeeLive.InviteFormComponent, {:invited, _user}}, socket) do
    employees = Accounts.list_employees(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign(:employees, employees)
     |> assign(:show_invite_modal, false)}
  end

  @impl true
  def handle_event("open_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("close_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-base-content">{gettext("Employees")}</h1>
            <p class="mt-1 text-sm text-base-content/60">
              {gettext("Manage your team members and send invitations.")}
            </p>
          </div>
          <.button variant="primary" phx-click="open_invite_modal">
            <.icon name="hero-plus" class="size-4 mr-1" />
            {gettext("Invite Employee")}
          </.button>
        </div>

        <div :if={@employees == []} class="text-center py-12">
          <.icon name="hero-users" class="size-12 text-base-content/30 mx-auto mb-4" />
          <p class="text-base-content/60">{gettext("No employees yet. Invite your first team member!")}</p>
        </div>

        <.table :if={@employees != []} id="employees" rows={@employees}>
          <:col :let={employee} label={gettext("Name")}>{employee.name}</:col>
          <:col :let={employee} label={gettext("Email")}>{employee.email}</:col>
          <:col :let={employee} label={gettext("Status")}>
            <span class={[
              "badge badge-sm",
              employee.status == :active && "badge-success",
              employee.status == :invited && "badge-warning"
            ]}>
              {employee.status}
            </span>
          </:col>
        </.table>

        <.live_component
          :if={@show_invite_modal}
          module={LmsWeb.Admin.EmployeeLive.InviteFormComponent}
          id="invite-form"
          current_scope={@current_scope}
        />
      </div>
    </Layouts.app>
    """
  end
end
```

**Step 5: Run tests**

Run: `mix test test/lms_web/live/admin/employee_live/index_test.exs`
Expected: May fail due to missing InviteFormComponent — that's fine, basic rendering tests should pass

**Step 6: Commit**

```bash
git add lib/lms_web/live/admin/employee_live/index.ex test/lms_web/live/admin/employee_live/index_test.exs lib/lms_web/router.ex
git commit -m "Add admin employee list LiveView with route"
```

---

### Task 7: Build invite form LiveComponent

**Files:**
- Create: `lib/lms_web/live/admin/employee_live/invite_form_component.ex`
- Modify: `test/lms_web/live/admin/employee_live/index_test.exs`

**Step 1: Write failing test for invite flow**

Add to `test/lms_web/live/admin/employee_live/index_test.exs`:

```elixir
describe "Invite Employee" do
  test "opens invite modal and submits invitation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/employees")

    view |> element("button", "Invite Employee") |> render_click()
    assert render(view) =~ "Invite a New Employee"

    view
    |> form("#invite-form", invite: %{name: "Alice Smith", email: "alice@example.com"})
    |> render_submit()

    flash = assert_redirect(view, ~p"/admin/employees")
    assert flash["info"] =~ "Invitation sent"
  end

  test "shows validation errors for invalid input", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/employees")

    view |> element("button", "Invite Employee") |> render_click()

    html =
      view
      |> form("#invite-form", invite: %{name: "", email: "bad"})
      |> render_submit()

    assert html =~ "can&#39;t be blank" || html =~ "must have the @ sign"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/lms_web/live/admin/employee_live/index_test.exs --max-failures 1`
Expected: FAIL

**Step 3: Create InviteFormComponent**

Create `lib/lms_web/live/admin/employee_live/invite_form_component.ex`:

```elixir
defmodule LmsWeb.Admin.EmployeeLive.InviteFormComponent do
  use LmsWeb, :live_component

  alias Lms.Accounts

  @impl true
  def mount(socket) do
    changeset = Accounts.User.invitation_changeset(%Accounts.User{}, %{})
    {:ok, assign(socket, form: to_form(changeset, as: "invite"))}
  end

  @impl true
  def handle_event("validate", %{"invite" => params}, socket) do
    changeset =
      %Accounts.User{}
      |> Accounts.User.invitation_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "invite"))}
  end

  @impl true
  def handle_event("save", %{"invite" => params}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.invite_employee(scope, params, &url(~p"/invitations/#{&1}")) do
      {:ok, user, _raw_token} ->
        notify_parent({:invited, user})

        {:noreply,
         socket
         |> put_flash(:info, gettext("Invitation sent to %{email}.", email: user.email))
         |> push_navigate(to: ~p"/admin/employees")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "invite"))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box">
        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click="close_invite_modal"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </button>

        <h3 class="text-lg font-bold mb-4">{gettext("Invite a New Employee")}</h3>

        <.form
          for={@form}
          id="invite-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="space-y-1"
        >
          <.input
            field={@form[:name]}
            type="text"
            label={gettext("Full name")}
            placeholder={gettext("Jane Smith")}
            required
          />
          <.input
            field={@form[:email]}
            type="email"
            label={gettext("Email address")}
            placeholder={gettext("jane@company.com")}
            required
          />
          <div class="modal-action">
            <button type="button" class="btn" phx-click="close_invite_modal">
              {gettext("Cancel")}
            </button>
            <.button variant="primary" phx-disable-with={gettext("Sending...")}>
              <.icon name="hero-paper-airplane" class="size-4 mr-1" />
              {gettext("Send Invitation")}
            </.button>
          </div>
        </.form>
      </div>
      <div class="modal-backdrop" phx-click="close_invite_modal"></div>
    </div>
    """
  end
end
```

**Step 4: Run tests**

Run: `mix test test/lms_web/live/admin/employee_live/index_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/lms_web/live/admin/employee_live/invite_form_component.ex test/lms_web/live/admin/employee_live/index_test.exs
git commit -m "Add invite form LiveComponent with modal"
```

---

### Task 8: Build invitation acceptance LiveView

**Files:**
- Create: `lib/lms_web/live/invitation_live/accept.ex`
- Create: `test/lms_web/live/invitation_live/accept_test.exs`
- Modify: `lib/lms_web/router.ex`

**Step 1: Add route**

In `lib/lms_web/router.ex`, add the invitation acceptance route in the public browser scope (no auth required). Add a new `live_session` block:

```elixir
scope "/", LmsWeb do
  pipe_through [:browser]

  live_session :invitation do
    live "/invitations/:token", InvitationLive.Accept
  end

  get "/users/log-in", UserSessionController, :new
  # ... rest of existing routes
end
```

**Step 2: Write failing test**

Create `test/lms_web/live/invitation_live/accept_test.exs`:

```elixir
defmodule LmsWeb.InvitationLive.AcceptTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.AccountsFixtures
  import Lms.CompaniesFixtures

  alias Lms.Accounts

  setup do
    company = company_fixture()
    admin = user_with_role_fixture(:company_admin, company.id)
    scope = Accounts.Scope.for_user(admin)
    attrs = %{name: "Jane Doe", email: unique_user_email()}
    {:ok, user, raw_token} = Accounts.invite_employee(scope, attrs, &"/invitations/#{&1}")
    %{user: user, raw_token: raw_token, company: company}
  end

  describe "Accept invitation" do
    test "renders password form for valid token", %{conn: conn, raw_token: raw_token} do
      {:ok, _view, html} = live(conn, ~p"/invitations/#{raw_token}")
      assert html =~ "Set Your Password"
      assert html =~ "password"
    end

    test "redirects for invalid token", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: %{"error" => _}}}} =
        live(conn, ~p"/invitations/invalid-token")
    end

    test "accepts invitation with valid password", %{conn: conn, raw_token: raw_token, user: user} do
      {:ok, view, _html} = live(conn, ~p"/invitations/#{raw_token}")

      view
      |> form("#accept-invitation-form", user: %{password: "valid password 123"})
      |> render_submit()

      assert_redirect(view, ~p"/users/log-in")

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.status == :active
      assert updated_user.invitation_token == nil
      assert updated_user.invitation_accepted_at != nil
    end

    test "shows error for short password", %{conn: conn, raw_token: raw_token} do
      {:ok, view, _html} = live(conn, ~p"/invitations/#{raw_token}")

      html =
        view
        |> form("#accept-invitation-form", user: %{password: "short"})
        |> render_submit()

      assert html =~ "should be at least 12 character"
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `mix test test/lms_web/live/invitation_live/accept_test.exs --max-failures 1`
Expected: FAIL

**Step 4: Create the acceptance LiveView**

Create `lib/lms_web/live/invitation_live/accept.ex`:

```elixir
defmodule LmsWeb.InvitationLive.Accept do
  use LmsWeb, :live_view

  alias Lms.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_invitation_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Invitation link is invalid or has expired."))
         |> redirect(to: ~p"/")}

      user ->
        changeset = Accounts.change_user_password(user)

        socket =
          socket
          |> assign(:current_scope, nil)
          |> assign(:user, user)
          |> assign(:token, token)
          |> assign(:page_title, gettext("Set Your Password"))
          |> assign(:form, to_form(changeset))

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.accept_invitation(socket.assigns.user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Account activated! Please log in."))
         |> redirect(to: ~p"/users/log-in")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-primary/10 mb-4">
            <.icon name="hero-envelope-open" class="size-7 text-primary" />
          </div>
          <h1 class="text-2xl font-bold text-base-content">
            {gettext("Set Your Password")}
          </h1>
          <p class="mt-2 text-sm text-base-content/60">
            {gettext("Welcome, %{name}! Set a password to activate your account.", name: @user.name)}
          </p>
        </div>

        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
            <.form
              for={@form}
              id="accept-invitation-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-1"
            >
              <.input
                field={@form[:password]}
                type="password"
                label={gettext("Password")}
                placeholder={gettext("Minimum 12 characters")}
                required
              />
              <.button
                variant="primary"
                class="btn btn-primary w-full mt-4"
                phx-disable-with={gettext("Activating...")}
              >
                {gettext("Activate Account")}
              </.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
```

**Step 5: Run tests**

Run: `mix test test/lms_web/live/invitation_live/accept_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/lms_web/live/invitation_live/accept.ex test/lms_web/live/invitation_live/accept_test.exs lib/lms_web/router.ex
git commit -m "Add invitation acceptance LiveView"
```

---

### Task 9: Add test fixture helper for invited users

**Files:**
- Modify: `test/support/fixtures/accounts_fixtures.ex`

**Step 1: Add invited_user_fixture**

Add to `test/support/fixtures/accounts_fixtures.ex`:

```elixir
def invited_user_fixture(scope, attrs \\ %{}) do
  attrs =
    Enum.into(attrs, %{
      name: "Invited User #{System.unique_integer([:positive])}",
      email: unique_user_email()
    })

  {:ok, user, raw_token} =
    Accounts.invite_employee(scope, attrs, &"/invitations/#{&1}")

  {user, raw_token}
end
```

**Step 2: Commit**

```bash
git add test/support/fixtures/accounts_fixtures.ex
git commit -m "Add invited_user_fixture test helper"
```

---

### Task 10: Run full test suite and precommit

**Step 1: Run all tests**

Run: `mix test`
Expected: All tests pass

**Step 2: Run precommit checks**

Run: `mix precommit`
Expected: All checks pass (format, credo, sobelow, tests)

**Step 3: Fix any issues found by precommit**

If formatting, credo, or sobelow issues arise, fix them and re-run.

**Step 4: Final commit with all fixes**

```bash
git add -A
git commit -m "Completed task W6: Build individual employee invitation flow with email delivery"
```
