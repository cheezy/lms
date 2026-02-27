# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Lms.Repo.insert!(%Lms.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Lms.Accounts

# Create default system admin for development
admin_email = "admin@lms.dev"

case Accounts.get_user_by_email(admin_email) do
  nil ->
    {:ok, _admin} =
      Accounts.create_system_admin(%{
        email: admin_email,
        password: "password1234"
      })

    IO.puts("Created system admin: #{admin_email}")

  _user ->
    IO.puts("System admin already exists: #{admin_email}")
end
