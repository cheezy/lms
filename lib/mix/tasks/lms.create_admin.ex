defmodule Mix.Tasks.Lms.CreateAdmin do
  @shortdoc "Creates a system admin user"

  @moduledoc """
  Creates a system admin user with the given email.

      $ mix lms.create_admin admin@example.com

  A random password will be generated and displayed. The user will be
  pre-confirmed and assigned the system_admin role with no company association.

  If a user with the given email already exists, no changes are made.
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    case args do
      [email] ->
        create_admin(email)

      _ ->
        Mix.shell().error("Usage: mix lms.create_admin <email>")
    end
  end

  defp create_admin(email) do
    case Lms.Accounts.get_user_by_email(email) do
      nil ->
        password = generate_password()

        case Lms.Accounts.create_system_admin(%{email: email, password: password}) do
          {:ok, _user} ->
            Mix.shell().info("System admin created successfully!")
            Mix.shell().info("  Email: #{email}")
            Mix.shell().info("  Password: #{password}")
            Mix.shell().info("")
            Mix.shell().info("Please change this password after first login.")

          {:error, changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
            Mix.shell().error("Failed to create admin: #{inspect(errors)}")
        end

      _user ->
        Mix.shell().info("User with email #{email} already exists.")
    end
  end

  defp generate_password do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 20)
  end
end
