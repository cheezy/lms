defmodule Lms.Accounts.UserRoleTest do
  use Lms.DataCase, async: true

  import Lms.CompaniesFixtures

  alias Lms.Accounts.User

  describe "role_changeset/2" do
    test "validates role enum values" do
      company = company_fixture()

      changeset =
        User.role_changeset(%User{}, %{role: :company_admin, company_id: company.id})

      assert changeset.valid?
    end

    test "rejects invalid role values" do
      changeset = User.role_changeset(%User{}, %{role: :superuser})
      refute changeset.valid?
      assert %{role: ["is invalid"]} = errors_on(changeset)
    end

    test "requires company_id for non-system_admin roles" do
      for role <- [:company_admin, :course_creator, :employee] do
        changeset = User.role_changeset(%User{}, %{role: role, company_id: nil})
        refute changeset.valid?
        assert %{company_id: ["is required for non-system admin users"]} = errors_on(changeset)
      end
    end

    test "allows system_admin without company_id" do
      changeset = User.role_changeset(%User{}, %{role: :system_admin, company_id: nil})
      assert changeset.valid?
    end

    test "allows system_admin with company_id" do
      company = company_fixture()

      changeset =
        User.role_changeset(%User{}, %{role: :system_admin, company_id: company.id})

      assert changeset.valid?
    end
  end

  describe "roles/0" do
    test "returns the list of valid roles" do
      assert User.roles() == [:system_admin, :company_admin, :course_creator, :employee]
    end
  end

  describe "schema" do
    test "default role is employee" do
      user = %User{}
      assert user.role == :employee
    end
  end
end
