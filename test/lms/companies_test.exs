defmodule Lms.CompaniesTest do
  use Lms.DataCase, async: true

  import Lms.CompaniesFixtures
  import Lms.AccountsFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  alias Lms.Accounts.User
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

  describe "change_registration/1" do
    test "returns a valid changeset with valid attrs" do
      attrs = %{
        "company_name" => "Acme Corp",
        "name" => "Jane Smith",
        "email" => "jane@acme.com",
        "password" => "long_password_123"
      }

      changeset = Companies.change_registration(attrs)
      assert changeset.valid?
    end

    test "validates required fields" do
      changeset = Companies.change_registration(%{})
      refute changeset.valid?
      assert %{company_name: ["can't be blank"]} = errors_on(changeset)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
      assert %{email: ["can't be blank"]} = errors_on(changeset)
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email format" do
      changeset = Companies.change_registration(%{"email" => "invalid"})
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates password length" do
      changeset = Companies.change_registration(%{"password" => "short"})
      assert %{password: ["should be at least 12 character(s)"]} = errors_on(changeset)
    end

    test "validates password confirmation" do
      changeset =
        Companies.change_registration(%{
          "password" => "long_password_123",
          "password_confirmation" => "wrong_password"
        })

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end
  end

  describe "register_company/1" do
    @valid_registration_attrs %{
      "company_name" => "Test Company",
      "name" => "Admin User",
      "email" => "admin@testcompany.com",
      "password" => "long_password_123",
      "password_confirmation" => "long_password_123"
    }

    test "creates company and admin user in a single transaction" do
      assert {:ok, %{company: company, user: user}} =
               Companies.register_company(@valid_registration_attrs)

      assert %Company{name: "Test Company"} = company
      assert company.slug == "test-company"
      assert %User{} = user
      assert user.email == "admin@testcompany.com"
      assert user.name == "Admin User"
      assert user.role == :company_admin
      assert user.company_id == company.id
      assert user.confirmed_at != nil
    end

    test "generates slug from company name" do
      attrs = %{@valid_registration_attrs | "company_name" => "My Awesome Company!"}

      assert {:ok, %{company: company}} = Companies.register_company(attrs)
      assert company.slug == "my-awesome-company"
    end

    test "rolls back both on user validation failure" do
      attrs = %{@valid_registration_attrs | "email" => "invalid"}

      assert {:error, changeset} = Companies.register_company(attrs)
      assert %{email: _} = errors_on(changeset)
      assert Companies.list_companies() == []
    end

    test "rolls back both on company validation failure" do
      attrs = %{@valid_registration_attrs | "company_name" => ""}

      assert {:error, changeset} = Companies.register_company(attrs)
      assert %{company_name: _} = errors_on(changeset)
      assert Companies.list_companies() == []
    end

    test "returns error when email already exists" do
      _existing_user = user_fixture(%{email: "admin@testcompany.com"})

      assert {:error, changeset} = Companies.register_company(@valid_registration_attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
      assert Companies.list_companies() == []
    end

    test "handles special characters in company name for slug" do
      attrs = %{@valid_registration_attrs | "company_name" => "L'Entreprise Café & Co."}

      assert {:ok, %{company: company}} = Companies.register_company(attrs)
      assert company.slug == "lentreprise-caf-co"
    end

    test "handles company name with leading/trailing spaces" do
      attrs = %{@valid_registration_attrs | "company_name" => "  Padded Company  "}

      assert {:ok, %{company: company}} = Companies.register_company(attrs)
      assert company.slug == "padded-company"
    end

    test "handles company name with multiple consecutive spaces" do
      attrs = %{@valid_registration_attrs | "company_name" => "Too   Many    Spaces"}

      assert {:ok, %{company: company}} = Companies.register_company(attrs)
      assert company.slug == "too-many-spaces"
    end

    test "handles duplicate company slug via unique constraint" do
      assert {:ok, _} = Companies.register_company(@valid_registration_attrs)

      # Different email but same company name → same slug
      attrs = %{
        @valid_registration_attrs
        | "email" => "other@testcompany.com"
      }

      assert {:error, changeset} = Companies.register_company(attrs)
      assert %{company_name: _} = errors_on(changeset)
    end
  end

  describe "list_companies_with_stats/1" do
    test "returns companies with zero counts when no data" do
      company = company_fixture()
      [result] = Companies.list_companies_with_stats()

      assert result.company.id == company.id
      assert result.employee_count == 0
      assert result.course_count == 0
      assert result.enrollment_count == 0
    end

    test "returns correct employee count" do
      company = company_fixture()
      _employee1 = user_with_role_fixture(:employee, company.id)
      _employee2 = user_with_role_fixture(:employee, company.id)

      [result] = Companies.list_companies_with_stats()
      assert result.employee_count == 2
    end

    test "returns correct course count" do
      company = company_fixture()
      creator = user_with_role_fixture(:course_creator, company.id)
      _course1 = course_fixture(%{company: company, creator: creator})
      _course2 = course_fixture(%{company: company, creator: creator})

      [result] = Companies.list_companies_with_stats()
      # creator counts as employee too
      assert result.course_count == 2
    end

    test "returns correct enrollment count" do
      company = company_fixture()
      creator = user_with_role_fixture(:course_creator, company.id)
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      [result] = Companies.list_companies_with_stats()
      assert result.enrollment_count == 1
    end

    test "searches by company name" do
      _company1 = company_fixture(%{name: "Acme Corp", slug: "acme-corp"})
      _company2 = company_fixture(%{name: "Beta Inc", slug: "beta-inc"})

      results = Companies.list_companies_with_stats(%{search: "Acme"})
      assert length(results) == 1
      assert hd(results).company.name == "Acme Corp"
    end

    test "returns empty list when search has no matches" do
      _company = company_fixture()
      assert Companies.list_companies_with_stats(%{search: "nonexistent"}) == []
    end

    test "orders by company name" do
      _company_b = company_fixture(%{name: "Beta Corp", slug: "beta-corp"})
      _company_a = company_fixture(%{name: "Alpha Corp", slug: "alpha-corp"})

      results = Companies.list_companies_with_stats()
      names = Enum.map(results, & &1.company.name)
      assert names == ["Alpha Corp", "Beta Corp"]
    end
  end

  describe "get_company_with_stats!/1" do
    test "returns company with stats" do
      company = company_fixture()
      employee = user_with_role_fixture(:employee, company.id)
      creator = user_with_role_fixture(:course_creator, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      result = Companies.get_company_with_stats!(company.id)
      assert result.company.id == company.id
      assert result.employee_count == 2
      assert result.course_count == 1
      assert result.enrollment_count == 1
    end

    test "raises when company does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Companies.get_company_with_stats!(0)
      end
    end
  end

  describe "company_dashboard_stats/1" do
    test "returns zero stats for new company" do
      company = company_fixture()
      stats = Companies.company_dashboard_stats(company.id)

      assert stats.total_employees == 0
      assert stats.active_employees == 0
      assert stats.total_courses == 0
      assert stats.published_courses == 0
      assert stats.draft_courses == 0
      assert stats.total_enrollments == 0
      assert stats.completed_enrollments == 0
      assert stats.overdue_enrollments == 0
      assert stats.completion_rate == 0.0
      assert stats.recent_enrollments == []
      assert stats.recent_completions == []
    end

    test "returns correct employee stats" do
      company = company_fixture()
      _employee = user_with_role_fixture(:employee, company.id)

      stats = Companies.company_dashboard_stats(company.id)
      assert stats.total_employees == 1
      assert stats.active_employees == 1
    end

    test "returns correct course stats" do
      company = company_fixture()
      creator = user_with_role_fixture(:course_creator, company.id)
      _published = course_fixture(%{company: company, creator: creator, status: :published})
      _draft = course_fixture(%{company: company, creator: creator, status: :draft})

      stats = Companies.company_dashboard_stats(company.id)
      assert stats.total_courses == 2
      assert stats.published_courses == 1
      assert stats.draft_courses == 1
    end

    test "returns correct enrollment and completion stats" do
      company = company_fixture()
      creator = user_with_role_fixture(:course_creator, company.id)
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      stats = Companies.company_dashboard_stats(company.id)
      assert stats.total_enrollments == 1
      assert stats.completed_enrollments == 0
      assert stats.completion_rate == 0.0
    end

    test "counts overdue enrollments" do
      company = company_fixture()
      creator = user_with_role_fixture(:course_creator, company.id)
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})

      _enrollment =
        enrollment_fixture(%{
          user: employee,
          course: course,
          due_date: Date.add(Date.utc_today(), -5)
        })

      stats = Companies.company_dashboard_stats(company.id)
      assert stats.overdue_enrollments == 1
    end

    test "returns recent enrollments" do
      company = company_fixture()
      creator = user_with_role_fixture(:course_creator, company.id)
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: creator, status: :published})
      _enrollment = enrollment_fixture(%{user: employee, course: course})

      stats = Companies.company_dashboard_stats(company.id)
      assert length(stats.recent_enrollments) == 1
    end
  end

  describe "change_registration/1 edge cases" do
    test "validates company_name max length" do
      long_name = String.duplicate("a", 256)
      changeset = Companies.change_registration(%{"company_name" => long_name})
      assert %{company_name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "validates name max length" do
      long_name = String.duplicate("a", 256)
      changeset = Companies.change_registration(%{"name" => long_name})
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "validates email max length" do
      long_email = String.duplicate("a", 150) <> "@example.com"
      changeset = Companies.change_registration(%{"email" => long_email})
      assert %{email: ["should be at most 160 character(s)"]} = errors_on(changeset)
    end

    test "validates password max length" do
      long_password = String.duplicate("a", 73)
      changeset = Companies.change_registration(%{"password" => long_password})
      assert %{password: ["should be at most 72 character(s)"]} = errors_on(changeset)
    end

    test "returns changeset with no attrs" do
      changeset = Companies.change_registration()
      assert %Ecto.Changeset{} = changeset
    end
  end
end
