defmodule Lms.Companies.Company do
  use Ecto.Schema
  import Ecto.Changeset

  schema "companies" do
    field :name, :string
    field :slug, :string

    has_many :users, Lms.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating or updating a company.
  """
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:slug, min: 1, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> unique_constraint(:slug)
  end
end
