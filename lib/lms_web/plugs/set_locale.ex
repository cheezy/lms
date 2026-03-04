defmodule LmsWeb.Plugs.SetLocale do
  @moduledoc """
  Plug that sets the Gettext locale from the user's session preference.

  Reads the `:locale` key from the session and sets the Gettext locale
  for the current request. Falls back to the configured default locale
  when no preference is stored or the stored locale is not in the
  allowed list.

  ## Usage in router

      plug LmsWeb.Plugs.SetLocale

  Must be placed after `:fetch_session` in the pipeline.
  """

  import Plug.Conn

  @allowed_locales ~w(en fr)

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    locale =
      get_session(conn, :locale)
      |> validate_locale()

    Gettext.put_locale(locale)
    assign(conn, :locale, locale)
  end

  defp validate_locale(locale) when locale in @allowed_locales, do: locale
  defp validate_locale(_), do: Gettext.get_locale()
end
