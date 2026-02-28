defmodule Lms.Accounts.UserNotifierTest do
  use Lms.DataCase, async: true

  alias Lms.Accounts.UserNotifier

  describe "deliver_invitation_instructions/2" do
    test "sends invitation email with URL" do
      user = %Lms.Accounts.User{email: "jane@example.com", name: "Jane"}
      url = "https://example.com/invitations/some-token"

      assert {:ok, email} = UserNotifier.deliver_invitation_instructions(user, url)

      assert email.subject == "You've been invited to join Lms"
      assert email.text_body =~ url
      assert email.text_body =~ "Jane"
      assert email.text_body =~ "7 days"
    end
  end
end
