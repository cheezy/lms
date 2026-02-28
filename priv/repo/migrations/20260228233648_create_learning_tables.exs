defmodule Lms.Repo.Migrations.CreateLearningTables do
  use Ecto.Migration

  def change do
    create table(:enrollments) do
      add :due_date, :date
      add :enrolled_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :course_id, references(:courses, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:enrollments, [:user_id])
    create index(:enrollments, [:course_id])
    create unique_index(:enrollments, [:user_id, :course_id])

    create table(:lesson_progress) do
      add :completed_at, :utc_datetime, null: false
      add :enrollment_id, references(:enrollments, on_delete: :delete_all), null: false
      add :lesson_id, references(:lessons, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lesson_progress, [:enrollment_id])
    create index(:lesson_progress, [:lesson_id])
    create unique_index(:lesson_progress, [:enrollment_id, :lesson_id])
  end
end
