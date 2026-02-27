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
  Gets a single company.

  Raises `Ecto.NoResultsError` if the Company does not exist.
  """
  def get_company!(id), do: Repo.get!(Company, id)

  @doc """
  Gets a single company by slug.

  Returns `nil` if no company matches.
  """
  def get_company_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Company, slug: slug)
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
