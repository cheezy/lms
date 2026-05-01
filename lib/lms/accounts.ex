defmodule Lms.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Lms.Repo

  alias Lms.Accounts.User
  alias Lms.Accounts.UserNotifier
  alias Lms.Accounts.UserToken

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user with an email and password.

  The user is confirmed immediately because they have provided a credential
  (the password) at registration time — there is no separate confirmation step.

  ## Examples

      iex> register_user(%{email: "...", password: "..."})
      {:ok, %User{}}

      iex> register_user(%{email: "bad", password: "short"})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> User.password_changeset(attrs)
    |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
    |> Repo.insert()
  end

  @doc """
  Creates a system admin user with email and password.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def create_system_admin(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> User.password_changeset(attrs)
    |> Ecto.Changeset.put_change(:role, :system_admin)
    |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Lms.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Lms.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  @doc """
  Updates the user's locale preference.

  ## Examples

      iex> update_user_locale(user, %{locale: "fr"})
      {:ok, %User{}}

      iex> update_user_locale(user, %{locale: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_locale(%User{} = user, attrs) do
    user
    |> User.locale_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for updating the user's profile (name + locale).
  """
  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  @doc """
  Updates the user's profile (name + locale).

  Returns `{:ok, user}` on success or `{:error, changeset}` on failure.
  """
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    UserToken
    |> from(where: [token: ^token, context: "session"])
    |> Repo.delete_all()

    :ok
  end

  ## Employee Management

  @promotable_roles [:employee, :course_creator]

  @doc """
  Updates an employee's role within the admin's company.

  Only allows promoting/demoting between :employee and :course_creator.
  Returns `{:error, :cannot_change_own_role}` if the admin tries to change their own role.
  Returns `{:error, :invalid_role}` if the target role is not promotable.
  Returns `{:error, :not_in_company}` if the user is not in the admin's company.
  """
  def update_user_role(%Lms.Accounts.Scope{user: admin}, %User{} = user, new_role) do
    cond do
      user.id == admin.id ->
        {:error, :cannot_change_own_role}

      user.company_id != admin.company_id ->
        {:error, :not_in_company}

      new_role not in @promotable_roles ->
        {:error, :invalid_role}

      true ->
        user
        |> Ecto.Changeset.change(%{role: new_role})
        |> Repo.update()
    end
  end

  ## Employee Invitation

  @invitation_validity_in_days 7

  @employees_per_page 20

  @doc """
  Lists employees for the given scope's company with search, sort, filter, and pagination.

  ## Options

    * `:search` - Search by name or email (case-insensitive)
    * `:sort_by` - Sort field: `:name`, `:email`, `:status`, or `:role` (default: `:name`)
    * `:sort_order` - Sort direction: `:asc` or `:desc` (default: `:asc`)
    * `:status` - Filter by status: `:active`, `:invited`, etc.
    * `:page` - Page number (default: `1`)

  Returns `{employees, total_count}`.
  """
  def list_employees(%Lms.Accounts.Scope{user: admin}, opts \\ %{}) do
    search = opts[:search]
    sort_by = opts[:sort_by] || :name
    sort_order = opts[:sort_order] || :asc
    status = opts[:status]
    page = max(opts[:page] || 1, 1)
    offset = (page - 1) * @employees_per_page

    base_query =
      User
      |> where([u], u.company_id == ^admin.company_id)
      |> where([u], u.role in [:employee, :course_creator])
      |> maybe_search(search)
      |> maybe_filter_status(status)

    total_count = Repo.aggregate(base_query, :count, :id)

    employees =
      base_query
      |> order_by([u], [{^sort_order, ^sort_by}])
      |> limit(^@employees_per_page)
      |> offset(^offset)
      |> Repo.all()

    {employees, total_count}
  end

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, search) do
    search_term = "%#{search}%"
    where(query, [u], ilike(u.name, ^search_term) or ilike(u.email, ^search_term))
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, ""), do: query
  defp maybe_filter_status(query, status), do: where(query, [u], u.status == ^status)

  @doc """
  Invites an employee to the admin's company.

  Creates a user record with role :employee, status :invited, and a hashed
  invitation token. Returns `{:ok, user, encoded_token}` or `{:error, changeset}`.
  The encoded token is the raw base64url-encoded value to include in the invitation URL.
  """
  def invite_employee(%Lms.Accounts.Scope{user: admin}, attrs) when is_map(attrs) do
    raw_token = :crypto.strong_rand_bytes(32)
    encoded_token = Base.url_encode64(raw_token, padding: false)
    hashed_token = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)

    result =
      %User{}
      |> User.invitation_changeset(%{
        email: attrs[:email] || attrs["email"],
        name: attrs[:name] || attrs["name"],
        role: :employee,
        company_id: admin.company_id,
        status: :invited,
        invitation_token: hashed_token,
        invitation_sent_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    case result do
      {:ok, user} -> {:ok, user, encoded_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Invites an employee and delivers the invitation email.

  Wraps `invite_employee/2` and sends the invitation email using the
  given URL function to build the invitation link.
  """
  def deliver_employee_invitation(%Lms.Accounts.Scope{} = scope, attrs, invitation_url_fun)
      when is_function(invitation_url_fun, 1) do
    case invite_employee(scope, attrs) do
      {:ok, user, encoded_token} ->
        UserNotifier.deliver_invitation_instructions(user, invitation_url_fun.(encoded_token))
        {:ok, user, encoded_token}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a user by their invitation token.

  The raw (base64url-encoded) token is hashed and compared against the
  stored hash. Returns nil if the token is invalid or expired.
  """
  def get_user_by_invitation_token(encoded_token) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(:sha256, decoded_token) |> Base.encode16(case: :lower)
        cutoff = DateTime.utc_now(:second) |> DateTime.add(-@invitation_validity_in_days, :day)

        User
        |> where([u], u.invitation_token == ^hashed_token)
        |> where([u], u.invitation_sent_at > ^cutoff)
        |> where([u], u.status == :invited)
        |> Repo.one()

      :error ->
        nil
    end
  end

  @doc """
  Checks whether an invitation token has already been accepted.

  Decodes and hashes the token, then looks for a user with that token hash
  who has status :active (meaning the invitation was already accepted and
  the token was cleared, or the user was activated).
  """
  def invitation_already_accepted?(encoded_token) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(:sha256, decoded_token) |> Base.encode16(case: :lower)

        User
        |> where([u], u.invitation_token == ^hashed_token)
        |> where([u], u.status != :invited)
        |> Repo.exists?()

      :error ->
        false
    end
  end

  @doc """
  Resends an invitation email for an invited user.

  Generates a new token and updates the invitation_sent_at timestamp,
  then sends the email. Only works for users with status :invited.
  """
  def resend_invitation(%User{status: :invited} = user, invitation_url_fun)
      when is_function(invitation_url_fun, 1) do
    raw_token = :crypto.strong_rand_bytes(32)
    encoded_token = Base.url_encode64(raw_token, padding: false)
    hashed_token = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)

    changeset =
      user
      |> Ecto.Changeset.change(%{
        invitation_token: hashed_token,
        invitation_sent_at: DateTime.utc_now(:second)
      })

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        UserNotifier.deliver_invitation_instructions(
          updated_user,
          invitation_url_fun.(encoded_token)
        )

        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def resend_invitation(%User{}, _invitation_url_fun), do: {:error, :not_invited}

  @doc """
  Accepts an invitation by setting the user's password and activating the account.
  """
  def accept_invitation(%User{} = user, attrs) do
    user
    |> User.accept_invitation_changeset(attrs)
    |> Repo.update()
  end

  ## CSV Bulk Invite

  @email_regex ~r/^[^@,;\s]+@[^@,;\s]+$/

  @doc """
  Parses CSV content and validates each row for bulk employee invitation.

  Expects CSV with columns: name, email (with or without header row).
  Returns a list of maps with `:name`, `:email`, `:valid?`, and `:errors` keys.

  Validates:
  - Name is present
  - Email format
  - Duplicate emails within the CSV
  - Emails already registered in the system
  """
  def parse_and_validate_csv(%Lms.Accounts.Scope{user: admin}, csv_content)
      when is_binary(csv_content) do
    csv_content
    |> String.trim()
    |> strip_bom()
    |> String.split(~r/\r?\n/)
    |> maybe_skip_header()
    |> Enum.map(&parse_csv_row/1)
    |> validate_rows(admin.company_id)
  end

  defp strip_bom(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: rest
  defp strip_bom(content), do: content

  defp maybe_skip_header([first | rest] = rows) do
    trimmed = first |> String.trim() |> String.downcase()

    if trimmed =~ ~r/^name\s*[,]\s*email/ do
      rest
    else
      rows
    end
  end

  defp maybe_skip_header([]), do: []

  defp parse_csv_row(line) do
    case String.split(line, ",", parts: 2) do
      [name, email] ->
        %{name: String.trim(name), email: String.trim(email)}

      _ ->
        %{name: "", email: String.trim(line)}
    end
  end

  defp validate_rows(rows, company_id) do
    existing_emails =
      User
      |> where([u], u.company_id == ^company_id)
      |> select([u], u.email)
      |> Repo.all()
      |> MapSet.new(&String.downcase/1)

    {validated, _seen} =
      Enum.reduce(rows, {[], MapSet.new()}, fn row, {acc, seen} ->
        errors = []
        lower_email = String.downcase(row.email)

        errors =
          if String.trim(row.name) == "",
            do: ["Name is required" | errors],
            else: errors

        errors =
          if Regex.match?(@email_regex, row.email),
            do: errors,
            else: ["Invalid email format" | errors]

        errors =
          if lower_email in seen,
            do: ["Duplicate email in CSV" | errors],
            else: errors

        errors =
          if lower_email in existing_emails,
            do: ["Employee already exists" | errors],
            else: errors

        validated_row = Map.merge(row, %{valid?: errors == [], errors: Enum.reverse(errors)})
        {acc ++ [validated_row], MapSet.put(seen, lower_email)}
      end)

    validated
  end

  @doc """
  Bulk invites employees from a list of validated rows.

  Takes only the valid rows, creates user records and sends invitation emails.
  Returns `{invited_count, skipped_count, results}` where results is a list
  of `{:ok, user}` or `{:error, reason}` tuples.
  """
  def bulk_invite_employees(%Lms.Accounts.Scope{} = scope, validated_rows, invitation_url_fun)
      when is_function(invitation_url_fun, 1) do
    valid_rows = Enum.filter(validated_rows, & &1.valid?)
    skipped_count = length(validated_rows) - length(valid_rows)

    results =
      Enum.map(valid_rows, fn row ->
        case deliver_employee_invitation(
               scope,
               %{name: row.name, email: row.email},
               invitation_url_fun
             ) do
          {:ok, user, _token} -> {:ok, user}
          {:error, changeset} -> {:error, changeset}
        end
      end)

    invited_count = Enum.count(results, &match?({:ok, _}, &1))
    {invited_count, skipped_count, results}
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
