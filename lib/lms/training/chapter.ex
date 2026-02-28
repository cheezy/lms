defmodule Lms.Training.Chapter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chapters" do
    field :title, :string
    field :description, :string
    field :position, :integer

    belongs_to :course, Lms.Training.Course

    has_many :lessons, Lms.Training.Lesson

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating or updating a chapter.
  """
  def changeset(chapter, attrs) do
    chapter
    |> cast(attrs, [:title, :description, :position, :course_id])
    |> validate_required([:title, :position, :course_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:course_id)
    |> unique_constraint([:course_id, :position])
  end
end
