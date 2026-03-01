defmodule Lms.Companies do
  @moduledoc """
  The Companies context.
  """

  import Ecto.Query, warn: false
  alias Lms.Repo

  alias Lms.Accounts.User
  alias Lms.Companies.Company

  @doc """
  Returns the list of companies.
  """
  def list_companies do
    Repo.all(Company)
  end

  @doc """
  Returns companies with aggregated stats (employee count, course count, enrollment count).

  ## Options

    * `:search` - Filter by company name (case-insensitive)

  Returns a list of maps with `:company`, `:employee_count`, `:course_count`, `:enrollment_count`.
  """
  def list_companies_with_stats(opts \\ %{}) do
    Company
    |> maybe_search_company(opts[:search])
    |> join(:left, [c], u in User, on: u.company_id == c.id)
    |> join(:left, [c, _u], course in Lms.Training.Course, on: course.company_id == c.id)
    |> join(:left, [c, _u, course], e in Lms.Learning.Enrollment, on: e.course_id == course.id)
    |> group_by([c, _u, _course, _e], c.id)
    |> select([c, u, course, e], %{
      company: c,
      employee_count: count(u.id, :distinct),
      course_count: count(course.id, :distinct),
      enrollment_count: count(e.id, :distinct)
    })
    |> order_by([c, _u, _course, _e], asc: c.name)
    |> Repo.all()
  end

  defp maybe_search_company(query, nil), do: query
  defp maybe_search_company(query, ""), do: query

  defp maybe_search_company(query, search) do
    search_term = "%#{search}%"
    where(query, [c], ilike(c.name, ^search_term))
  end

  @doc """
  Gets a single company.

  Raises `Ecto.NoResultsError` if the Company does not exist.
  """
  def get_company!(id), do: Repo.get!(Company, id)

  @doc """
  Gets a single company with aggregated stats.

  Returns a map with `:company`, `:employee_count`, `:course_count`, `:enrollment_count`.
  Raises `Ecto.NoResultsError` if the Company does not exist.
  """
  def get_company_with_stats!(id) do
    Company
    |> where([c], c.id == ^id)
    |> join(:left, [c], u in User, on: u.company_id == c.id)
    |> join(:left, [c, _u], course in Lms.Training.Course, on: course.company_id == c.id)
    |> join(:left, [c, _u, course], e in Lms.Learning.Enrollment, on: e.course_id == course.id)
    |> group_by([c, _u, _course, _e], c.id)
    |> select([c, u, course, e], %{
      company: c,
      employee_count: count(u.id, :distinct),
      course_count: count(course.id, :distinct),
      enrollment_count: count(e.id, :distinct)
    })
    |> Repo.one!()
  end

  @doc """
  Gets a single company by slug.

  Returns `nil` if no company matches.
  """
  def get_company_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Company, slug: slug)
  end

  @doc """
  Returns dashboard stats for a company.

  Returns a map with:
  - `:total_employees` - Total number of users in the company
  - `:active_employees` - Users with active status
  - `:total_courses` - Total courses
  - `:published_courses` - Published courses
  - `:draft_courses` - Draft courses
  - `:total_enrollments` - Total enrollments
  - `:completed_enrollments` - Enrollments with completed_at set
  - `:overdue_enrollments` - Enrollments past due date and not completed
  - `:completion_rate` - Percentage of completed enrollments (float)
  - `:recent_enrollments` - Last 5 enrollments with user and course preloaded
  - `:recent_completions` - Last 5 completed enrollments with user and course preloaded
  """
  def company_dashboard_stats(company_id) do
    employee_stats = employee_stats(company_id)
    course_stats = course_stats(company_id)
    enrollment_stats = enrollment_stats(company_id)
    recent_enrollments = recent_enrollments(company_id)
    recent_completions = recent_completions(company_id)

    Map.merge(employee_stats, course_stats)
    |> Map.merge(enrollment_stats)
    |> Map.put(:recent_enrollments, recent_enrollments)
    |> Map.put(:recent_completions, recent_completions)
  end

  defp employee_stats(company_id) do
    total =
      User
      |> where([u], u.company_id == ^company_id)
      |> select([u], count(u.id))
      |> Repo.one()

    active =
      User
      |> where([u], u.company_id == ^company_id and u.status == :active)
      |> select([u], count(u.id))
      |> Repo.one()

    %{total_employees: total, active_employees: active}
  end

  defp course_stats(company_id) do
    alias Lms.Training.Course

    courses =
      Course
      |> where([c], c.company_id == ^company_id)
      |> group_by([c], c.status)
      |> select([c], {c.status, count(c.id)})
      |> Repo.all()
      |> Map.new()

    total = Enum.reduce(courses, 0, fn {_status, count}, acc -> acc + count end)
    published = Map.get(courses, :published, 0)
    draft = Map.get(courses, :draft, 0)

    %{total_courses: total, published_courses: published, draft_courses: draft}
  end

  defp enrollment_stats(company_id) do
    alias Lms.Learning.Enrollment
    alias Lms.Training.Course

    base_query =
      Enrollment
      |> join(:inner, [e], c in Course, on: e.course_id == c.id and c.company_id == ^company_id)

    total =
      base_query
      |> select([e], count(e.id))
      |> Repo.one()

    completed =
      base_query
      |> where([e], not is_nil(e.completed_at))
      |> select([e], count(e.id))
      |> Repo.one()

    overdue =
      base_query
      |> where(
        [e],
        not is_nil(e.due_date) and is_nil(e.completed_at) and e.due_date < ^Date.utc_today()
      )
      |> select([e], count(e.id))
      |> Repo.one()

    completion_rate = if total > 0, do: completed / total * 100.0, else: 0.0

    %{
      total_enrollments: total,
      completed_enrollments: completed,
      overdue_enrollments: overdue,
      completion_rate: completion_rate
    }
  end

  defp recent_enrollments(company_id) do
    alias Lms.Learning.Enrollment
    alias Lms.Training.Course

    Enrollment
    |> join(:inner, [e], c in Course, on: e.course_id == c.id and c.company_id == ^company_id)
    |> order_by([e], desc: e.enrolled_at)
    |> limit(5)
    |> preload([:user, :course])
    |> Repo.all()
  end

  defp recent_completions(company_id) do
    alias Lms.Learning.Enrollment
    alias Lms.Training.Course

    Enrollment
    |> join(:inner, [e], c in Course, on: e.course_id == c.id and c.company_id == ^company_id)
    |> where([e], not is_nil(e.completed_at))
    |> order_by([e], desc: e.completed_at)
    |> limit(5)
    |> preload([:user, :course])
    |> Repo.all()
  end

  @doc """
  Creates a company.
  """
  def create_company(attrs \\ %{}) do
    %Company{}
    |> Company.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a company.
  """
  def update_company(%Company{} = company, attrs) do
    company
    |> Company.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a company.
  """
  def delete_company(%Company{} = company) do
    Repo.delete(company)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking company changes.
  """
  def change_company(%Company{} = company, attrs \\ %{}) do
    Company.changeset(company, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for the company registration form.

  Uses a schemaless changeset to validate all registration fields together:
  company_name, name, email, password, and password_confirmation.
  """
  def change_registration(attrs \\ %{}) do
    types = %{company_name: :string, name: :string, email: :string, password: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> Ecto.Changeset.validate_required([:company_name, :name, :email, :password])
    |> Ecto.Changeset.validate_length(:company_name, min: 1, max: 255)
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 255)
    |> Ecto.Changeset.validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> Ecto.Changeset.validate_length(:email, max: 160)
    |> Ecto.Changeset.validate_length(:password, min: 12, max: 72)
    |> Ecto.Changeset.validate_confirmation(:password, message: "does not match password")
  end

  @doc """
  Registers a new company with a company admin user in a single transaction.

  Creates the company with an auto-generated slug and the admin user with
  the `:company_admin` role. Returns `{:ok, %{company: company, user: user}}`
  or `{:error, changeset}` with errors mapped to registration form fields.
  """
  def register_company(attrs) do
    case build_registration_multi(attrs) |> Repo.transaction() do
      {:ok, multi} ->
        {:ok, multi}

      {:error, :company, changeset, _changes} ->
        {:error, map_multi_errors(attrs, :company, changeset)}

      {:error, :user, changeset, _changes} ->
        {:error, map_multi_errors(attrs, :user, changeset)}
    end
  end

  defp build_registration_multi(attrs) do
    company_name = attrs["company_name"] || ""
    slug = generate_slug(company_name)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :company,
      Company.changeset(%Company{}, %{name: company_name, slug: slug})
    )
    |> Ecto.Multi.insert(:user, fn %{company: company} ->
      build_admin_changeset(attrs, company)
    end)
  end

  defp build_admin_changeset(attrs, company) do
    %User{}
    |> User.email_changeset(%{email: attrs["email"]})
    |> User.password_changeset(%{
      password: attrs["password"],
      password_confirmation: attrs["password_confirmation"]
    })
    |> Ecto.Changeset.put_change(:name, attrs["name"])
    |> Ecto.Changeset.put_change(:role, :company_admin)
    |> Ecto.Changeset.put_change(:company_id, company.id)
    |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  defp map_multi_errors(attrs, :company, changeset) do
    registration = change_registration(attrs)

    Enum.reduce(changeset.errors, registration, fn
      {:name, {msg, opts}}, cs -> Ecto.Changeset.add_error(cs, :company_name, msg, opts)
      {:slug, {msg, opts}}, cs -> Ecto.Changeset.add_error(cs, :company_name, msg, opts)
      _other, cs -> cs
    end)
    |> Map.put(:action, :validate)
  end

  defp map_multi_errors(attrs, :user, changeset) do
    registration = change_registration(attrs)

    Enum.reduce(changeset.errors, registration, fn
      {field, {msg, opts}}, cs when field in [:email, :password, :name] ->
        Ecto.Changeset.add_error(cs, field, msg, opts)

      _other, cs ->
        cs
    end)
    |> Map.put(:action, :validate)
  end

  defp generate_slug(nil), do: ""

  defp generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
