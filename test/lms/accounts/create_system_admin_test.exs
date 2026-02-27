defmodule Lms.Accounts.CreateSystemAdminTest do
  use Lms.DataCase, async: true

  alias Lms.Accounts

  describe "create_system_admin/1" do
    test "creates a user with system_admin role" do
      attrs = %{email: "admin@example.com", password: "password1234"}
      assert {:ok, user} = Accounts.create_system_admin(attrs)
      assert user.role == :system_admin
      assert user.email == "admin@example.com"
      assert is_nil(user.company_id)
      assert user.confirmed_at
    end

    test "hashes the password" do
      attrs = %{email: "admin2@example.com", password: "password1234"}
      assert {:ok, user} = Accounts.create_system_admin(attrs)
      assert user.hashed_password
      assert is_nil(user.password)
    end

    test "rejects duplicate email" do
      attrs = %{email: "admin@example.com", password: "password1234"}
      {:ok, _} = Accounts.create_system_admin(attrs)
      assert {:error, changeset} = Accounts.create_system_admin(attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "rejects invalid email" do
      attrs = %{email: "not-an-email", password: "password1234"}
      assert {:error, changeset} = Accounts.create_system_admin(attrs)
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "rejects short password" do
      attrs = %{email: "admin@example.com", password: "short"}
      assert {:error, changeset} = Accounts.create_system_admin(attrs)
      assert %{password: [msg]} = errors_on(changeset)
      assert msg =~ "should be at least"
    end
  end
end
