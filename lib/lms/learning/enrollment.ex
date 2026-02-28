defmodule Lms.Learning.Enrollment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "enrollments" do
    field :due_date, :date
    field :enrolled_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :user, Lms.Accounts.User
    belongs_to :course, Lms.Training.Course

    has_many :lesson_progress, Lms.Learning.LessonProgress

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating or updating an enrollment.
  """
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [:due_date, :enrolled_at, :completed_at, :user_id, :course_id])
    |> validate_required([:enrolled_at, :user_id, :course_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:course_id)
    |> unique_constraint([:user_id, :course_id])
  end
end
