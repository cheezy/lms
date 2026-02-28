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
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
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

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
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
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
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

  ## Employee Invitation

  @invitation_validity_in_days 7

  @doc """
  Lists all employees for the given scope's company.
  """
  def list_employees(%Lms.Accounts.Scope{user: admin}) do
    User
    |> where([u], u.company_id == ^admin.company_id)
    |> where([u], u.role == :employee)
    |> order_by([u], asc: u.name)
    |> Repo.all()
  end

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
  Accepts an invitation by setting the user's password and activating the account.
  """
  def accept_invitation(%User{} = user, attrs) do
    user
    |> User.accept_invitation_changeset(attrs)
    |> Repo.update()
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
