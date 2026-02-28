defmodule Lms.Training.LessonImage do
  use Ecto.Schema
  import Ecto.Changeset

  @allowed_types ~w(image/jpeg image/png image/gif image/webp)
  @max_file_size 5_000_000

  schema "lesson_images" do
    field :filename, :string
    field :file_path, :string
    field :content_type, :string
    field :file_size, :integer

    belongs_to :lesson, Lms.Training.Lesson

    timestamps()
  end

  def changeset(lesson_image, attrs) do
    lesson_image
    |> cast(attrs, [:filename, :file_path, :content_type, :file_size, :lesson_id])
    |> validate_required([:filename, :file_path, :content_type, :file_size, :lesson_id])
    |> validate_inclusion(:content_type, @allowed_types,
      message: "must be an image (JPEG, PNG, GIF, or WebP)"
    )
    |> validate_number(:file_size,
      greater_than: 0,
      less_than_or_equal_to: @max_file_size,
      message: "must be less than 5MB"
    )
    |> foreign_key_constraint(:lesson_id)
  end

  def allowed_types, do: @allowed_types
  def max_file_size, do: @max_file_size
end
