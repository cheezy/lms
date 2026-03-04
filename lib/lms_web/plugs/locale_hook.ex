defmodule LmsWeb.Plugs.LocaleHook do
  @moduledoc """
  LiveView on_mount hook that sets the Gettext locale from the session.

  The SetLocale plug handles locale for the initial static render, but LiveView
  processes run in their own process and need the locale set independently.
  """

  @allowed_locales ~w(en fr)

  def on_mount(:default, _params, session, socket) do
    locale = validate_locale(session["locale"])
    Gettext.put_locale(locale)
    {:cont, socket}
  end

  defp validate_locale(locale) when locale in @allowed_locales, do: locale
  defp validate_locale(_), do: Gettext.get_locale()
end
