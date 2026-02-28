defmodule Mix.Tasks.Lms.CreateAdminTest do
  use Lms.DataCase, async: false

  alias Lms.Accounts
  alias Mix.Tasks.Lms.CreateAdmin

  setup do
    # Use Mix.Shell.Process to capture all shell output during tests
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    :ok
  end

  defp collect_shell_output do
    collect_shell_output([])
  end

  defp collect_shell_output(acc) do
    receive do
      {:mix_shell, :info, [msg]} -> collect_shell_output([msg | acc])
      {:mix_shell, :error, [msg]} -> collect_shell_output([msg | acc])
    after
      100 -> Enum.reverse(acc) |> Enum.join("\n")
    end
  end

  describe "run/1" do
    test "creates a system admin with the given email" do
      CreateAdmin.run(["newadmin@example.com"])
      _output = collect_shell_output()

      user = Accounts.get_user_by_email("newadmin@example.com")
      assert user
      assert user.role == :system_admin
      assert user.confirmed_at
      assert is_nil(user.company_id)
    end

    test "prints success message with email and password" do
      CreateAdmin.run(["output@example.com"])
      output = collect_shell_output()

      assert output =~ "System admin created successfully!"
      assert output =~ "output@example.com"
      assert output =~ "Password:"
      assert output =~ "Please change this password after first login."
    end

    test "is idempotent for existing users" do
      CreateAdmin.run(["existing@example.com"])
      _output = collect_shell_output()

      CreateAdmin.run(["existing@example.com"])
      output = collect_shell_output()

      assert output =~ "already exists"
      assert Accounts.get_user_by_email("existing@example.com")
    end

    test "shows error for invalid email" do
      CreateAdmin.run(["not-an-email"])
      output = collect_shell_output()

      assert output =~ "Failed to create admin"
      assert is_nil(Accounts.get_user_by_email("not-an-email"))
    end

    test "shows usage error with no arguments" do
      CreateAdmin.run([])
      output = collect_shell_output()

      assert output =~ "Usage: mix lms.create_admin"
    end
  end
end
