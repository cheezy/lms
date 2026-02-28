defmodule Lms.Training.Course do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:draft, :published, :archived]

  schema "courses" do
    field :title, :string
    field :description, :string
    field :cover_image, :string
    field :status, Ecto.Enum, values: @statuses, default: :draft

    belongs_to :company, Lms.Companies.Company
    belongs_to :creator, Lms.Accounts.User

    has_many :chapters, Lms.Training.Chapter

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  A changeset for creating or updating a course.
  """
  def changeset(course, attrs) do
    course
    |> cast(attrs, [:title, :description, :cover_image, :status, :company_id, :creator_id])
    |> validate_required([:title, :company_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:creator_id)
  end
end
