defmodule Lms.Companies do
  @moduledoc """
  The Companies context.
  """

  import Ecto.Query, warn: false
  alias Lms.Repo

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
end
