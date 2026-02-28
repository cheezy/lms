defmodule Lms.Learning.LessonProgress do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lesson_progress" do
    field :completed_at, :utc_datetime

    belongs_to :enrollment, Lms.Learning.Enrollment
    belongs_to :lesson, Lms.Training.Lesson

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating or updating lesson progress.
  """
  def changeset(lesson_progress, attrs) do
    lesson_progress
    |> cast(attrs, [:completed_at, :enrollment_id, :lesson_id])
    |> validate_required([:completed_at, :enrollment_id, :lesson_id])
    |> foreign_key_constraint(:enrollment_id)
    |> foreign_key_constraint(:lesson_id)
    |> unique_constraint([:enrollment_id, :lesson_id])
  end
end
