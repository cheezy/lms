defmodule Lms.Repo.Migrations.AddCompaniesAndExtendUsers do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:companies, [:slug])

    alter table(:users) do
      add :role, :string, null: false, default: "employee"
      add :company_id, references(:companies, on_delete: :nilify_all)
      add :invitation_token, :string
      add :invitation_sent_at, :utc_datetime
      add :invitation_accepted_at, :utc_datetime
    end

    create index(:users, [:company_id])
    create index(:users, [:role])
  end
end
