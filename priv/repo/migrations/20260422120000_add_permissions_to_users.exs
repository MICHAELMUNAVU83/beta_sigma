defmodule BetaSigma.Repo.Migrations.AddPermissionsToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :permissions, {:array, :string}, null: false, default: []
    end

    flush()

    backfill_role_defaults()
  end

  def down do
    alter table(:users) do
      remove :permissions
    end
  end

  defp backfill_role_defaults do
    Enum.each([:admin, :staff, :applicant], fn role ->
      defaults = BetaSigma.Pages.default_keys_for_role(role)

      execute(
        fn ->
          repo().query!(
            "UPDATE users SET permissions = $1 WHERE role = $2",
            [defaults, Atom.to_string(role)]
          )
        end,
        fn -> :ok end
      )
    end)
  end
end
