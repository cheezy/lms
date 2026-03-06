# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Lms.Repo.insert!(%Lms.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Lms.Repo
alias Lms.Accounts
alias Lms.Accounts.User
alias Lms.Companies.Company
alias Lms.Training.Course
alias Lms.Learning.Enrollment

now = DateTime.utc_now(:second)

# ── 1. System Admin ──────────────────────────────────────────────────

_admin =
  case Accounts.get_user_by_email("admin@lms.dev") do
    nil ->
      {:ok, user} =
        Accounts.create_system_admin(%{
          email: "admin@lms.dev",
          password: "password1234"
        })

      IO.puts("Created system admin: admin@lms.dev")
      user

    user ->
      IO.puts("System admin already exists: admin@lms.dev")
      user
  end

# ── 2. Company ───────────────────────────────────────────────────────

company =
  case Repo.get_by(Company, slug: "uplift-demo") do
    nil ->
      {:ok, company} =
        Lms.Companies.create_company(%{name: "Uplift Demo", slug: "uplift-demo"})

      IO.puts("Created company: Uplift Demo")
      company

    company ->
      IO.puts("Company already exists: Uplift Demo")
      company
  end

# ── 3. Company Admin (cheezy) ────────────────────────────────────────

cheezy =
  case Accounts.get_user_by_email("cheezy@letstango.ca") do
    nil ->
      {:ok, user} =
        %User{}
        |> User.email_changeset(%{email: "cheezy@letstango.ca"})
        |> User.password_changeset(%{password: "password1234"})
        |> Ecto.Changeset.put_change(:role, :company_admin)
        |> Ecto.Changeset.put_change(:company_id, company.id)
        |> Ecto.Changeset.put_change(:confirmed_at, now)
        |> Repo.insert()

      IO.puts("Created company admin: cheezy@letstango.ca")
      user

    user ->
      IO.puts("Company admin already exists: cheezy@letstango.ca")
      user
  end

# ── 4. Employees ─────────────────────────────────────────────────────

employees = [
  {"Alice Chen", "alice.chen@upliftdemo.com"},
  {"Marcus Johnson", "marcus.johnson@upliftdemo.com"},
  {"Sofia Rodriguez", "sofia.rodriguez@upliftdemo.com"},
  {"James O'Brien", "james.obrien@upliftdemo.com"},
  {"Priya Patel", "priya.patel@upliftdemo.com"},
  {"Liam Foster", "liam.foster@upliftdemo.com"},
  {"Emma Nakamura", "emma.nakamura@upliftdemo.com"},
  {"David Kim", "david.kim@upliftdemo.com"},
  {"Olivia Martin", "olivia.martin@upliftdemo.com"},
  {"Noah Williams", "noah.williams@upliftdemo.com"}
]

for {name, email} <- employees do
  case Accounts.get_user_by_email(email) do
    nil ->
      {:ok, _user} =
        %User{}
        |> User.email_changeset(%{email: email})
        |> User.password_changeset(%{password: "password1234"})
        |> Ecto.Changeset.put_change(:name, name)
        |> Ecto.Changeset.put_change(:role, :employee)
        |> Ecto.Changeset.put_change(:company_id, company.id)
        |> Ecto.Changeset.put_change(:confirmed_at, now)
        |> Repo.insert()

      IO.puts("Created employee: #{name} (#{email})")

    _user ->
      IO.puts("Employee already exists: #{email}")
  end
end

# ── 5. Course ────────────────────────────────────────────────────────

course =
  case Repo.get_by(Course, title: "Using Claude Code Remote Control") do
    nil ->
      {:ok, course} =
        Lms.Training.create_course(%{
          title: "Using Claude Code Remote Control",
          description:
            "This course will demonstrate how you can use the new Remote Control feature of Claude Code.",
          status: :draft,
          company_id: company.id,
          creator_id: cheezy.id
        })

      IO.puts("Created course: Using Claude Code Remote Control")
      course

    course ->
      IO.puts("Course already exists: Using Claude Code Remote Control")
      course
  end

# ── 6. Enroll cheezy in the course ────────────────────────────────

case Repo.get_by(Enrollment, user_id: cheezy.id, course_id: course.id) do
  nil ->
    {:ok, _enrollment} =
      Lms.Learning.enroll_employee(%{
        user_id: cheezy.id,
        course_id: course.id
      })

    IO.puts("Enrolled cheezy@letstango.ca in: Using Claude Code Remote Control")

  _enrollment ->
    IO.puts("Enrollment already exists for cheezy@letstango.ca")
end
