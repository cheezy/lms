defmodule Lms.Accounts.UserNotifier do
  import Swoosh.Email

  alias Lms.Accounts.User
  alias Lms.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Lms", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver invitation instructions to a new employee.
  """
  def deliver_invitation_instructions(user, url) do
    deliver(user.email, "You've been invited to join Lms", """

    ==============================

    Hi #{user.name},

    You've been invited to join Lms. You can set up your account by visiting the URL below:

    #{url}

    This invitation will expire in 7 days.

    If you weren't expecting this invitation, please ignore this email.

    ==============================
    """)
  end

  @doc """
  Deliver enrollment notification to an employee.
  """
  def deliver_enrollment_notification(user, course_title) do
    deliver(user.email, "You've been enrolled in #{course_title}", """

    ==============================

    Hi #{user.name || user.email},

    You have been enrolled in the course "#{course_title}".

    Log in to your account to start learning.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
