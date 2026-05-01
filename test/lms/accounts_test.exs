defmodule Lms.AccountsTest do
  use Lms.DataCase

  import Lms.AccountsFixtures

  alias Lms.Accounts
  alias Lms.Accounts.User
  alias Lms.Accounts.UserToken

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "requires password to be set" do
      {:error, changeset} = Accounts.register_user(%{email: unique_user_email()})

      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates password length" do
      {:error, changeset} =
        Accounts.register_user(%{email: unique_user_email(), password: "short"})

      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "registers users with email and password and confirms them immediately" do
      email = unique_user_email()

      {:ok, user} =
        [email: email]
        |> valid_user_attributes()
        |> Accounts.register_user()

      assert user.email == email
      refute is_nil(user.hashed_password)
      refute is_nil(user.confirmed_at)
      # Virtual password field is cleared after hashing
      assert is_nil(user.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: :second |> DateTime.utc_now() |> DateTime.add(-3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "update_user_role/3" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      employee = user_with_role_fixture(:employee, company.id)
      %{scope: scope, company: company, admin: admin, employee: employee}
    end

    test "promotes employee to course_creator", %{scope: scope, employee: employee} do
      assert {:ok, updated} = Accounts.update_user_role(scope, employee, :course_creator)
      assert updated.role == :course_creator
    end

    test "demotes course_creator to employee", %{scope: scope, company: company} do
      course_creator = user_with_role_fixture(:course_creator, company.id)
      assert {:ok, updated} = Accounts.update_user_role(scope, course_creator, :employee)
      assert updated.role == :employee
    end

    test "returns error when changing own role", %{scope: scope, admin: admin} do
      assert {:error, :cannot_change_own_role} =
               Accounts.update_user_role(scope, admin, :employee)
    end

    test "returns error for invalid role", %{scope: scope, employee: employee} do
      assert {:error, :invalid_role} =
               Accounts.update_user_role(scope, employee, :company_admin)
    end

    test "returns error for user in different company", %{scope: scope} do
      other_company = Lms.CompaniesFixtures.company_fixture()
      other_employee = user_with_role_fixture(:employee, other_company.id)

      assert {:error, :not_in_company} =
               Accounts.update_user_role(scope, other_employee, :course_creator)
    end
  end

  describe "list_employees/2" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      %{scope: scope, company: company}
    end

    test "returns employees for the admin's company", %{scope: scope, company: company} do
      employee = user_with_role_fixture(:employee, company.id)

      other_company = Lms.CompaniesFixtures.company_fixture()
      _other_employee = user_with_role_fixture(:employee, other_company.id)

      {employees, total_count} = Accounts.list_employees(scope)
      assert total_count == 1
      assert hd(employees).id == employee.id
    end

    test "includes invited employees", %{scope: scope} do
      {invited, _token} = invited_user_fixture(scope)

      {employees, _total_count} = Accounts.list_employees(scope)
      employee_ids = Enum.map(employees, & &1.id)
      assert invited.id in employee_ids
    end

    test "searches by name", %{scope: scope, company: company} do
      emp1 = user_with_role_fixture(:employee, company.id)
      _emp2 = user_with_role_fixture(:employee, company.id)

      {employees, _total_count} = Accounts.list_employees(scope, %{search: emp1.email})
      assert length(employees) == 1
      assert hd(employees).id == emp1.id
    end

    test "filters by status", %{scope: scope, company: company} do
      _active_employee = user_with_role_fixture(:employee, company.id)
      {invited, _token} = invited_user_fixture(scope)

      {employees, total_count} = Accounts.list_employees(scope, %{status: :invited})
      assert total_count == 1
      assert hd(employees).id == invited.id
    end

    test "sorts by email descending", %{scope: scope, company: company} do
      _emp1 = user_with_role_fixture(:employee, company.id)
      _emp2 = user_with_role_fixture(:employee, company.id)

      {employees, _total_count} =
        Accounts.list_employees(scope, %{sort_by: :email, sort_order: :desc})

      emails = Enum.map(employees, & &1.email)
      assert emails == Enum.sort(emails, :desc)
    end

    test "returns total count for pagination", %{scope: scope, company: company} do
      for _ <- 1..3, do: user_with_role_fixture(:employee, company.id)

      {_employees, total_count} = Accounts.list_employees(scope)
      assert total_count == 3
    end
  end

  describe "invite_employee/2" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      %{scope: scope, company: company}
    end

    test "creates an invited user with invitation token", %{scope: scope} do
      attrs = %{name: "Jane Doe", email: "jane@example.com"}
      assert {:ok, user, _raw_token} = Accounts.invite_employee(scope, attrs)
      assert user.email == "jane@example.com"
      assert user.name == "Jane Doe"
      assert user.role == :employee
      assert user.status == :invited
      assert user.company_id == scope.user.company_id
      assert user.invitation_token != nil
      assert user.invitation_sent_at != nil
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
    end

    test "returns raw token that is base64url encoded", %{scope: scope} do
      attrs = %{name: "Jane Doe", email: "jane@example.com"}
      assert {:ok, _user, raw_token} = Accounts.invite_employee(scope, attrs)
      assert {:ok, decoded} = Base.url_decode64(raw_token, padding: false)
      assert byte_size(decoded) == 32
    end

    test "invitation token in DB is SHA-256 hash of raw token", %{scope: scope} do
      attrs = %{name: "Jane Doe", email: "jane@example.com"}
      assert {:ok, user, raw_token} = Accounts.invite_employee(scope, attrs)
      {:ok, decoded} = Base.url_decode64(raw_token, padding: false)
      expected_hash = :crypto.hash(:sha256, decoded) |> Base.encode16(case: :lower)
      assert user.invitation_token == expected_hash
    end

    test "scopes invitation to admin's company", %{scope: scope} do
      attrs = %{name: "Jane Doe", email: "jane@example.com"}
      {:ok, user, _raw_token} = Accounts.invite_employee(scope, attrs)
      assert user.company_id == scope.user.company_id
    end

    test "returns error for duplicate email", %{scope: scope} do
      attrs = %{name: "Jane Doe", email: "jane@example.com"}
      {:ok, _user, _raw_token} = Accounts.invite_employee(scope, attrs)
      assert {:error, changeset} = Accounts.invite_employee(scope, attrs)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "returns error for invalid email", %{scope: scope} do
      attrs = %{name: "Jane Doe", email: "not-valid"}
      assert {:error, changeset} = Accounts.invite_employee(scope, attrs)
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "returns error for empty name", %{scope: scope} do
      attrs = %{name: "", email: "jane@example.com"}
      assert {:error, changeset} = Accounts.invite_employee(scope, attrs)
      assert errors_on(changeset).name != []
    end
  end

  describe "get_user_by_invitation_token/1" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      {user, raw_token} = invited_user_fixture(scope)
      %{user: user, raw_token: raw_token}
    end

    test "returns user for valid token", %{user: user, raw_token: raw_token} do
      assert found_user = Accounts.get_user_by_invitation_token(raw_token)
      assert found_user.id == user.id
    end

    test "returns nil for invalid token" do
      refute Accounts.get_user_by_invitation_token("invalid-token")
    end

    test "returns nil for expired token", %{user: user, raw_token: raw_token} do
      expired_at = DateTime.utc_now(:second) |> DateTime.add(-8, :day)

      User
      |> from(where: [id: ^user.id])
      |> Repo.update_all(set: [invitation_sent_at: expired_at])

      refute Accounts.get_user_by_invitation_token(raw_token)
    end
  end

  describe "accept_invitation/2" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      {user, raw_token} = invited_user_fixture(scope)
      %{user: user, raw_token: raw_token}
    end

    test "accepts invitation and sets password", %{user: user} do
      assert {:ok, accepted_user} =
               Accounts.accept_invitation(user, %{password: "valid password 123"})

      assert accepted_user.status == :active
      assert accepted_user.confirmed_at != nil
      assert accepted_user.invitation_token != nil
      assert accepted_user.invitation_accepted_at != nil
      assert accepted_user.hashed_password != nil
      assert User.valid_password?(accepted_user, "valid password 123")
    end

    test "returns error for short password", %{user: user} do
      assert {:error, changeset} = Accounts.accept_invitation(user, %{password: "short"})
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end
  end

  describe "invitation_already_accepted?/1" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      {user, raw_token} = invited_user_fixture(scope)
      %{user: user, raw_token: raw_token}
    end

    test "returns false for pending invitation", %{raw_token: raw_token} do
      refute Accounts.invitation_already_accepted?(raw_token)
    end

    test "returns true for accepted invitation", %{user: user, raw_token: raw_token} do
      {:ok, _user} = Accounts.accept_invitation(user, %{password: "valid password 123"})
      assert Accounts.invitation_already_accepted?(raw_token)
    end

    test "returns false for invalid token" do
      refute Accounts.invitation_already_accepted?("invalid-token")
    end
  end

  describe "resend_invitation/2" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      {user, _raw_token} = invited_user_fixture(scope)
      %{user: user}
    end

    test "resends invitation for invited user", %{user: user} do
      original_token = user.invitation_token
      url_fun = fn token -> "http://test.com/invitations/#{token}" end

      assert {:ok, updated_user} = Accounts.resend_invitation(user, url_fun)
      assert updated_user.invitation_token != original_token
      assert updated_user.invitation_sent_at != nil
    end

    test "returns error for non-invited user" do
      active_user = user_fixture()
      url_fun = fn token -> "http://test.com/invitations/#{token}" end

      assert {:error, :not_invited} = Accounts.resend_invitation(active_user, url_fun)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "parse_and_validate_csv/2" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      %{scope: scope, company: company}
    end

    test "parses valid CSV with header row", %{scope: scope} do
      csv = "name,email\nAlice Smith,alice@example.com\nBob Jones,bob@example.com"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 2
      assert Enum.all?(result, & &1.valid?)
      assert hd(result).name == "Alice Smith"
      assert hd(result).email == "alice@example.com"
    end

    test "parses valid CSV without header row", %{scope: scope} do
      csv = "Alice Smith,alice@example.com\nBob Jones,bob@example.com"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 2
      assert Enum.all?(result, & &1.valid?)
    end

    test "handles CSV with BOM marker", %{scope: scope} do
      csv = "\uFEFFname,email\nAlice Smith,alice@example.com"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 1
      assert hd(result).valid?
    end

    test "catches invalid email format", %{scope: scope} do
      csv = "Alice Smith,not-an-email"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 1
      refute hd(result).valid?
      assert "Invalid email format" in hd(result).errors
    end

    test "catches missing name", %{scope: scope} do
      csv = ",alice@example.com"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 1
      refute hd(result).valid?
      assert "Name is required" in hd(result).errors
    end

    test "catches duplicate emails within CSV", %{scope: scope} do
      csv = "Alice,alice@example.com\nBob,alice@example.com"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 2
      assert Enum.at(result, 0).valid?
      refute Enum.at(result, 1).valid?
      assert "Duplicate email in CSV" in Enum.at(result, 1).errors
    end

    test "catches existing employees", %{scope: scope, company: company} do
      existing = user_with_role_fixture(:employee, company.id)
      csv = "Existing User,#{existing.email}"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 1
      refute hd(result).valid?
      assert "Employee already exists" in hd(result).errors
    end

    test "handles empty CSV", %{scope: scope} do
      csv = "name,email"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert result == []
    end

    test "handles CSV with Windows line endings", %{scope: scope} do
      csv = "name,email\r\nAlice,alice@example.com\r\nBob,bob@example.com"
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert length(result) == 2
      assert Enum.all?(result, & &1.valid?)
    end

    test "trims whitespace from fields", %{scope: scope} do
      csv = "  Alice Smith  ,  alice@example.com  "
      result = Accounts.parse_and_validate_csv(scope, csv)

      assert hd(result).name == "Alice Smith"
      assert hd(result).email == "alice@example.com"
      assert hd(result).valid?
    end
  end

  describe "bulk_invite_employees/3" do
    setup do
      company = Lms.CompaniesFixtures.company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      scope = Lms.Accounts.Scope.for_user(admin)
      %{scope: scope}
    end

    test "invites valid rows and skips invalid ones", %{scope: scope} do
      validated_rows = [
        %{name: "Alice", email: "alice-bulk@example.com", valid?: true, errors: []},
        %{name: "", email: "bad", valid?: false, errors: ["Invalid email"]},
        %{name: "Bob", email: "bob-bulk@example.com", valid?: true, errors: []}
      ]

      {invited_count, skipped_count, results} =
        Accounts.bulk_invite_employees(scope, validated_rows, &"/invitations/#{&1}")

      assert invited_count == 2
      assert skipped_count == 1
      assert length(results) == 2
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    test "creates users with invited status", %{scope: scope} do
      validated_rows = [
        %{name: "Test User", email: "test-bulk@example.com", valid?: true, errors: []}
      ]

      {1, 0, [{:ok, user}]} =
        Accounts.bulk_invite_employees(scope, validated_rows, &"/invitations/#{&1}")

      assert user.status == :invited
      assert user.role == :employee
      assert user.name == "Test User"
    end

    test "handles empty validated rows", %{scope: scope} do
      {0, 0, []} = Accounts.bulk_invite_employees(scope, [], &"/invitations/#{&1}")
    end
  end

  describe "update_user_locale/2" do
    test "updates locale to a valid value" do
      user = user_fixture()
      assert {:ok, updated_user} = Accounts.update_user_locale(user, %{locale: "fr"})
      assert updated_user.locale == "fr"
    end

    test "rejects invalid locale values" do
      user = user_fixture()
      assert {:error, changeset} = Accounts.update_user_locale(user, %{locale: "de"})
      assert %{locale: ["is invalid"]} = errors_on(changeset)
    end

    test "preserves existing locale when given empty string" do
      user = user_fixture()
      assert {:ok, updated_user} = Accounts.update_user_locale(user, %{locale: ""})
      assert updated_user.locale == "en"
    end

    test "defaults to en for new users" do
      user = user_fixture()
      assert user.locale == "en"
    end
  end
end
