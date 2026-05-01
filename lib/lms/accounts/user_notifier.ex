defmodule Lms.Accounts.UserNotifier do
  @moduledoc """
  Sends transactional emails to users.

  Each `deliver_*` function wraps subject and body construction in
  `Gettext.with_locale/2` using the recipient user's stored `locale`. Because
  emails may be delivered asynchronously (Oban-style), the locale must be
  applied at *render time*, not just at delivery time — otherwise the body
  would be built in whatever locale the calling process happened to have.
  """

  use Gettext, backend: LmsWeb.Gettext

  import Swoosh.Email

  alias Lms.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Uplift", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # Run the given function with Gettext locale set to the user's stored
  # locale, falling back to "en" when the user has no locale set.
  defp with_user_locale(user, fun) do
    Gettext.with_locale(LmsWeb.Gettext, user.locale || "en", fun)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    with_user_locale(user, fn ->
      subject = gettext("Update email instructions")

      body = """

      ==============================

      #{gettext("Hi %{email},", email: user.email)}

      #{gettext("You can change your email by visiting the URL below:")}

      #{url}

      #{gettext("If you didn't request this change, please ignore this.")}

      ==============================
      """

      deliver(user.email, subject, body)
    end)
  end

  @doc """
  Deliver invitation instructions to a new employee.
  """
  def deliver_invitation_instructions(user, url) do
    with_user_locale(user, fn ->
      subject = gettext("You've been invited to join Uplift")

      body = """

      ==============================

      #{gettext("Hi %{name},", name: user.name)}

      #{gettext("You've been invited to join Uplift. You can set up your account by visiting the URL below:")}

      #{url}

      #{gettext("This invitation will expire in 7 days.")}

      #{gettext("If you weren't expecting this invitation, please ignore this email.")}

      ==============================
      """

      deliver(user.email, subject, body)
    end)
  end

  @doc """
  Deliver enrollment notification to an employee.
  """
  def deliver_enrollment_notification(user, course_title) do
    with_user_locale(user, fn ->
      subject = gettext("You've been enrolled in %{course}", course: course_title)
      greeting_name = user.name || user.email

      body = """

      ==============================

      #{gettext("Hi %{name},", name: greeting_name)}

      #{gettext("You have been enrolled in the course \"%{course}\".", course: course_title)}

      #{gettext("Log in to your account to start learning.")}

      ==============================
      """

      deliver(user.email, subject, body)
    end)
  end
end
