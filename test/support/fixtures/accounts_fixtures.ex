defmodule Lms.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lms.Accounts` context.
  """

  import Ecto.Query

  alias Lms.Accounts
  alias Lms.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    {1, _} =
      Accounts.User
      |> from(where: [id: ^user.id])
      |> Lms.Repo.update_all(set: [confirmed_at: nil])

    Lms.Repo.get!(Accounts.User, user.id)
  end

  def user_with_role_fixture(role, company_id \\ nil) do
    user = user_fixture()

    {1, _} =
      Lms.Accounts.User
      |> from(where: [id: ^user.id])
      |> Lms.Repo.update_all(set: [role: role, company_id: company_id])

    Lms.Repo.get!(Lms.Accounts.User, user.id)
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Accounts.UserToken
    |> from(where: [token: ^token])
    |> Lms.Repo.update_all(set: [authenticated_at: authenticated_at])
  end

  def invited_user_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Invited User #{System.unique_integer([:positive])}",
        email: unique_user_email()
      })

    {:ok, user, raw_token} =
      Accounts.invite_employee(scope, attrs)

    {user, raw_token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt =
      :second
      |> DateTime.utc_now()
      |> DateTime.add(amount_to_add, unit)

    Accounts.UserToken
    |> from(where: [token: ^token])
    |> Lms.Repo.update_all(set: [inserted_at: dt, authenticated_at: dt])
  end
end
