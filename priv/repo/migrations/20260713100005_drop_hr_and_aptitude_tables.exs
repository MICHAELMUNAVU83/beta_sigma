defmodule BetaSigma.Repo.Migrations.DropHrAndAptitudeTables do
  use Ecto.Migration

  def change do
    drop table(:job_aptitude_screenshots)
    drop table(:job_aptitude_answers)
    drop table(:job_aptitude_attempts)
    drop table(:job_aptitude_assessments)
    drop table(:applications)
    drop table(:employees)
    drop table(:job_listings)
  end
end
