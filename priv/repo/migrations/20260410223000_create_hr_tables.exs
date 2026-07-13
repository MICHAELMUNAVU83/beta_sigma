defmodule BetaSigma.Repo.Migrations.CreateHrTables do
  use Ecto.Migration

  def change do
    create table(:job_listings) do
      add :title, :string, null: false
      add :department, :string
      add :location, :string, null: false, default: "Nairobi, Kenya"
      add :type, :string
      add :description, :text
      add :requirements, :text
      add :status, :string, null: false, default: "open"

      timestamps(type: :utc_datetime)
    end

    create index(:job_listings, [:status])
    create index(:job_listings, [:department])

    create table(:applications) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :cv_url, :string
      add :cover_letter, :text
      add :linkedin_url, :string
      add :stage, :string, null: false, default: "applied"
      add :internal_notes, :text
      add :job_listing_id, references(:job_listings, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:applications, [:job_listing_id])
    create index(:applications, [:email])
    create index(:applications, [:stage])

    create table(:employees) do
      add :department, :string
      add :employment_type, :string
      add :start_date, :date
      add :onboarding_completed_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :manager_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:employees, [:user_id])
    create index(:employees, [:manager_id])
    create index(:employees, [:department])
  end
end
