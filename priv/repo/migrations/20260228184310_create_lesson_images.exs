defmodule Lms.Repo.Migrations.CreateLessonImages do
  use Ecto.Migration

  def change do
    create table(:lesson_images) do
      add :filename, :string, null: false
      add :file_path, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :lesson_id, references(:lessons, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:lesson_images, [:lesson_id])
  end
end
