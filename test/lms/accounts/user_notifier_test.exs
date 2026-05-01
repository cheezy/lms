defmodule Lms.Accounts.UserNotifierTest do
  use Lms.DataCase, async: true

  alias Lms.Accounts.User
  alias Lms.Accounts.UserNotifier

  describe "deliver_invitation_instructions/2" do
    test "sends English invitation when user.locale is :en (default)" do
      user = %User{email: "jane@example.com", name: "Jane", locale: "en"}
      url = "https://example.com/invitations/some-token"

      assert {:ok, email} = UserNotifier.deliver_invitation_instructions(user, url)

      assert email.subject == "You've been invited to join Uplift"
      assert email.text_body =~ url
      assert email.text_body =~ "Jane"
      assert email.text_body =~ "7 days"
    end

    test "sends French invitation when user.locale is fr (process locale ignored)" do
      # Force the calling process to English to prove the user's locale wins
      Gettext.put_locale(LmsWeb.Gettext, "en")

      user = %User{email: "jean@example.com", name: "Jean", locale: "fr"}
      url = "https://example.com/invitations/some-token"

      assert {:ok, email} = UserNotifier.deliver_invitation_instructions(user, url)

      # French translations of the new strings (verify French key phrases)
      assert email.subject =~ "Uplift"
      assert email.text_body =~ url
      assert email.text_body =~ "Jean"
      # The exact French phrasing is in priv/gettext/fr/LC_MESSAGES/default.po;
      # we only assert it is NOT the English fallback.
      refute email.text_body =~ "You've been invited to join"
      refute email.text_body =~ "This invitation will expire"
    end

    test "falls back to English when user.locale is nil" do
      user = %User{email: "x@example.com", name: "X", locale: nil}
      url = "https://example.com/invitations/x"

      assert {:ok, email} = UserNotifier.deliver_invitation_instructions(user, url)
      assert email.subject == "You've been invited to join Uplift"
    end
  end

  describe "deliver_update_email_instructions/2" do
    test "respects user.locale even when process locale differs" do
      Gettext.put_locale(LmsWeb.Gettext, "en")

      user = %User{email: "jean@example.com", name: nil, locale: "fr"}
      url = "https://example.com/users/settings/confirm-email/token"

      assert {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)
      assert email.text_body =~ url
      refute email.text_body =~ "Update email instructions"
    end

    test "uses English when user.locale is en" do
      user = %User{email: "jane@example.com", locale: "en"}
      url = "https://example.com/foo"

      assert {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)
      assert email.subject == "Update email instructions"
      assert email.text_body =~ "You can change your email"
    end
  end

  describe "deliver_enrollment_notification/2" do
    test "uses user's stored locale (fr) regardless of process locale" do
      Gettext.put_locale(LmsWeb.Gettext, "en")

      user = %User{email: "jean@example.com", name: "Jean", locale: "fr"}
      course_title = "Sécurité 101"

      assert {:ok, email} = UserNotifier.deliver_enrollment_notification(user, course_title)
      assert email.text_body =~ "Jean"
      assert email.text_body =~ course_title
      refute email.text_body =~ "Log in to your account"
    end

    test "uses English when user.locale is en" do
      user = %User{email: "jane@example.com", name: "Jane", locale: "en"}

      assert {:ok, email} = UserNotifier.deliver_enrollment_notification(user, "Course X")
      assert email.subject =~ "Course X"
      assert email.text_body =~ "Log in to your account"
    end

    test "falls back to email when name is nil" do
      user = %User{email: "x@example.com", name: nil, locale: "en"}

      assert {:ok, email} = UserNotifier.deliver_enrollment_notification(user, "Course Y")
      assert email.text_body =~ "x@example.com"
    end
  end
end
