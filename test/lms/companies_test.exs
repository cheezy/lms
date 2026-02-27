defmodule Lms.CompaniesTest do
  use Lms.DataCase, async: true

  import Lms.CompaniesFixtures

  alias Lms.Companies
  alias Lms.Companies.Company

  describe "list_companies/0" do
    test "returns all companies" do
      company = company_fixture()
      assert Companies.list_companies() == [company]
    end

    test "returns empty list when no companies exist" do
      assert Companies.list_companies() == []
    end
  end

  describe "get_company!/1" do
    test "returns the company with given id" do
      company = company_fixture()
      assert Companies.get_company!(company.id) == company
    end

    test "raises when company does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Companies.get_company!(0) end
    end
  end

  describe "get_company_by_slug/1" do
    test "returns the company with given slug" do
      company = company_fixture()
      assert Companies.get_company_by_slug(company.slug) == company
    end

    test "returns nil when no company matches" do
      assert Companies.get_company_by_slug("nonexistent") == nil
    end
  end

  describe "create_company/1" do
    test "with valid attrs creates a company" do
      attrs = %{name: "Acme Corp", slug: "acme-corp"}
      assert {:ok, %Company{} = company} = Companies.create_company(attrs)
      assert company.name == "Acme Corp"
      assert company.slug == "acme-corp"
    end

    test "with missing name returns error changeset" do
      assert {:error, changeset} = Companies.create_company(%{slug: "test"})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "with missing slug returns error changeset" do
      assert {:error, changeset} = Companies.create_company(%{name: "Test"})
      assert %{slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "with duplicate slug returns error changeset" do
      company = company_fixture()
      attrs = %{name: "Other Company", slug: company.slug}
      assert {:error, changeset} = Companies.create_company(attrs)
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "with invalid slug format returns error changeset" do
      attrs = %{name: "Test", slug: "Invalid Slug!"}
      assert {:error, changeset} = Companies.create_company(attrs)

      assert %{slug: ["must contain only lowercase letters, numbers, and hyphens"]} =
               errors_on(changeset)
    end
  end

  describe "update_company/2" do
    test "with valid attrs updates the company" do
      company = company_fixture()
      assert {:ok, %Company{} = updated} = Companies.update_company(company, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "with invalid attrs returns error changeset" do
      company = company_fixture()
      assert {:error, changeset} = Companies.update_company(company, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert company == Companies.get_company!(company.id)
    end
  end

  describe "delete_company/1" do
    test "deletes the company" do
      company = company_fixture()
      assert {:ok, %Company{}} = Companies.delete_company(company)
      assert_raise Ecto.NoResultsError, fn -> Companies.get_company!(company.id) end
    end
  end

  describe "change_company/2" do
    test "returns a changeset" do
      company = company_fixture()
      assert %Ecto.Changeset{} = Companies.change_company(company)
    end
  end
end
