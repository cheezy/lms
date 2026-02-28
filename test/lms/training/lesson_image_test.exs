defmodule Lms.Training.LessonImageTest do
  use Lms.DataCase, async: true

  import Lms.TrainingFixtures

  alias Lms.Training.LessonImage

  describe "changeset/2" do
    setup do
      lesson = lesson_fixture()
      %{lesson: lesson}
    end

    test "valid attrs", %{lesson: lesson} do
      attrs = %{
        filename: "photo.jpg",
        file_path: "/tmp/photo.jpg",
        content_type: "image/jpeg",
        file_size: 1_000,
        lesson_id: lesson.id
      }

      changeset = LessonImage.changeset(%LessonImage{}, attrs)
      assert changeset.valid?
    end

    test "requires all fields" do
      changeset = LessonImage.changeset(%LessonImage{}, %{})
      errors = errors_on(changeset)

      assert "can't be blank" in errors.filename
      assert "can't be blank" in errors.file_path
      assert "can't be blank" in errors.content_type
      assert "can't be blank" in errors.file_size
      assert "can't be blank" in errors.lesson_id
    end

    test "rejects invalid content types", %{lesson: lesson} do
      attrs = %{
        filename: "doc.pdf",
        file_path: "/tmp/doc.pdf",
        content_type: "application/pdf",
        file_size: 1_000,
        lesson_id: lesson.id
      }

      changeset = LessonImage.changeset(%LessonImage{}, attrs)
      assert "must be an image (JPEG, PNG, GIF, or WebP)" in errors_on(changeset).content_type
    end

    test "accepts all allowed image types", %{lesson: lesson} do
      for type <- ~w(image/jpeg image/png image/gif image/webp) do
        attrs = %{
          filename: "file.img",
          file_path: "/tmp/file.img",
          content_type: type,
          file_size: 1_000,
          lesson_id: lesson.id
        }

        changeset = LessonImage.changeset(%LessonImage{}, attrs)
        assert changeset.valid?, "Expected #{type} to be valid"
      end
    end

    test "rejects file size over 5MB", %{lesson: lesson} do
      attrs = %{
        filename: "huge.jpg",
        file_path: "/tmp/huge.jpg",
        content_type: "image/jpeg",
        file_size: 5_000_001,
        lesson_id: lesson.id
      }

      changeset = LessonImage.changeset(%LessonImage{}, attrs)
      assert errors_on(changeset).file_size != []
    end

    test "rejects file size of zero", %{lesson: lesson} do
      attrs = %{
        filename: "empty.jpg",
        file_path: "/tmp/empty.jpg",
        content_type: "image/jpeg",
        file_size: 0,
        lesson_id: lesson.id
      }

      changeset = LessonImage.changeset(%LessonImage{}, attrs)
      assert errors_on(changeset).file_size != []
    end

    test "accepts file size at limit", %{lesson: lesson} do
      attrs = %{
        filename: "max.jpg",
        file_path: "/tmp/max.jpg",
        content_type: "image/jpeg",
        file_size: 5_000_000,
        lesson_id: lesson.id
      }

      changeset = LessonImage.changeset(%LessonImage{}, attrs)
      assert changeset.valid?
    end
  end

  describe "module attributes" do
    test "allowed_types returns expected types" do
      assert LessonImage.allowed_types() == ~w(image/jpeg image/png image/gif image/webp)
    end

    test "max_file_size returns 5MB" do
      assert LessonImage.max_file_size() == 5_000_000
    end
  end
end
