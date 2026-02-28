defmodule Lms.LearningFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lms.Learning` context.
  """

  import Lms.AccountsFixtures
  import Lms.TrainingFixtures

  alias Lms.Learning

  def valid_enrollment_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      enrolled_at: DateTime.utc_now(:second)
    })
  end

  def enrollment_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    course = attrs[:course] || course_fixture()

    attrs =
      attrs
      |> Map.drop([:user, :course])
      |> Enum.into(%{user_id: user.id, course_id: course.id})
      |> valid_enrollment_attributes()

    {:ok, enrollment} = Learning.enroll_employee(attrs)
    enrollment
  end
end
