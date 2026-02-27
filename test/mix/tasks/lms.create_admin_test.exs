defmodule Mix.Tasks.Lms.CreateAdminTest do
  use Lms.DataCase, async: true

  alias Lms.Accounts
  alias Mix.Tasks.Lms.CreateAdmin

  describe "run/1" do
    test "creates a system admin with the given email" do
      CreateAdmin.run(["newadmin@example.com"])

      user = Accounts.get_user_by_email("newadmin@example.com")
      assert user
      assert user.role == :system_admin
      assert user.confirmed_at
      assert is_nil(user.company_id)
    end

    test "is idempotent for existing users" do
      CreateAdmin.run(["existing@example.com"])
      CreateAdmin.run(["existing@example.com"])

      assert Accounts.get_user_by_email("existing@example.com")
    end

    test "shows error for invalid email" do
      CreateAdmin.run(["not-an-email"])
      assert is_nil(Accounts.get_user_by_email("not-an-email"))
    end

    test "shows error with no arguments" do
      CreateAdmin.run([])
    end
  end
end
