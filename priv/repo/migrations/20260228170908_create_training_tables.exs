defmodule Lms.Repo.Migrations.CreateTrainingTables do
  use Ecto.Migration

  def change do
    create table(:courses) do
      add :title, :string, null: false
      add :description, :text
      add :cover_image, :string
      add :status, :string, null: false, default: "draft"
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :creator_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:courses, [:company_id])
    create index(:courses, [:creator_id])
    create index(:courses, [:status])

    create table(:chapters) do
      add :title, :string, null: false
      add :description, :text
      add :position, :integer, null: false
      add :course_id, references(:courses, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chapters, [:course_id])
    create unique_index(:chapters, [:course_id, :position])

    create table(:lessons) do
      add :title, :string, null: false
      add :content, :map
      add :position, :integer, null: false
      add :chapter_id, references(:chapters, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lessons, [:chapter_id])
    create unique_index(:lessons, [:chapter_id, :position])
  end
end
