defmodule Lms.Training.Lesson do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lessons" do
    field :title, :string
    field :content, :map
    field :position, :integer

    belongs_to :chapter, Lms.Training.Chapter

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating or updating a lesson.
  """
  def changeset(lesson, attrs) do
    lesson
    |> cast(attrs, [:title, :content, :position, :chapter_id])
    |> validate_required([:title, :position, :chapter_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:chapter_id)
    |> unique_constraint([:chapter_id, :position])
  end
end
