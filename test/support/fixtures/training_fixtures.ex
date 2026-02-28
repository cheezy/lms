defmodule Lms.TrainingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lms.Training` context.
  """

  import Lms.CompaniesFixtures
  import Lms.AccountsFixtures

  alias Lms.Training

  def unique_course_title, do: "Course #{System.unique_integer([:positive])}"
  def unique_chapter_title, do: "Chapter #{System.unique_integer([:positive])}"
  def unique_lesson_title, do: "Lesson #{System.unique_integer([:positive])}"

  def valid_course_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: unique_course_title(),
      description: "A test course description",
      status: :draft
    })
  end

  def course_fixture(attrs \\ %{}) do
    company = attrs[:company] || company_fixture()
    creator = attrs[:creator] || user_fixture()

    attrs =
      attrs
      |> Map.drop([:company, :creator])
      |> Enum.into(%{company_id: company.id, creator_id: creator.id})
      |> valid_course_attributes()

    {:ok, course} = Training.create_course(attrs)
    course
  end

  def valid_chapter_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: unique_chapter_title(),
      description: "A test chapter description"
    })
  end

  def chapter_fixture(attrs \\ %{}) do
    course = attrs[:course] || course_fixture()

    attrs =
      attrs
      |> Map.drop([:course])
      |> Enum.into(%{course_id: course.id})
      |> valid_chapter_attributes()

    {:ok, chapter} = Training.create_chapter(attrs)
    chapter
  end

  def valid_lesson_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: unique_lesson_title(),
      content: %{"type" => "doc", "content" => []}
    })
  end

  def lesson_fixture(attrs \\ %{}) do
    chapter = attrs[:chapter] || chapter_fixture()

    attrs =
      attrs
      |> Map.drop([:chapter])
      |> Enum.into(%{chapter_id: chapter.id})
      |> valid_lesson_attributes()

    {:ok, lesson} = Training.create_lesson(attrs)
    lesson
  end
end
