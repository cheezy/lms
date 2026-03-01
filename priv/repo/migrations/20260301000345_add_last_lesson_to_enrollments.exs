defmodule Lms.Repo.Migrations.AddLastLessonToEnrollments do
  use Ecto.Migration

  def change do
    alter table(:enrollments) do
      add :last_lesson_id, references(:lessons, on_delete: :nilify_all)
    end

    create index(:enrollments, [:last_lesson_id])
  end
end
