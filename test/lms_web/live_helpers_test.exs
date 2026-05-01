defmodule LmsWeb.LiveHelpersTest do
  use ExUnit.Case, async: true

  alias LmsWeb.LiveHelpers

  describe "format_progress/1" do
    test "formats whole-number percent" do
      assert LiveHelpers.format_progress(42.0) == "42%"
    end

    test "rounds to whole percent" do
      assert LiveHelpers.format_progress(42.7) == "43%"
      assert LiveHelpers.format_progress(42.4) == "42%"
    end

    test "formats zero and full progress" do
      assert LiveHelpers.format_progress(0.0) == "0%"
      assert LiveHelpers.format_progress(100.0) == "100%"
    end
  end

  describe "pagination_range/2" do
    test "returns 5-page window centered on current page" do
      assert LiveHelpers.pagination_range(5, 10) == [3, 4, 5, 6, 7]
    end

    test "clamps lower bound to 1" do
      assert LiveHelpers.pagination_range(1, 10) == [1, 2, 3]
      assert LiveHelpers.pagination_range(2, 10) == [1, 2, 3, 4]
    end

    test "clamps upper bound to total_pages" do
      assert LiveHelpers.pagination_range(10, 10) == [8, 9, 10]
      assert LiveHelpers.pagination_range(9, 10) == [7, 8, 9, 10]
    end

    test "handles single-page result" do
      assert LiveHelpers.pagination_range(1, 1) == [1]
    end
  end

  describe "maybe_put/3" do
    test "skips nil values" do
      assert LiveHelpers.maybe_put(%{}, :key, nil) == %{}
    end

    test "skips empty strings" do
      assert LiveHelpers.maybe_put(%{}, :key, "") == %{}
    end

    test "adds non-empty string values" do
      assert LiveHelpers.maybe_put(%{}, :key, "value") == %{key: "value"}
    end

    test "adds non-nil non-string values" do
      assert LiveHelpers.maybe_put(%{}, :key, 42) == %{key: 42}
      assert LiveHelpers.maybe_put(%{}, :key, :atom) == %{key: :atom}
    end

    test "preserves existing keys" do
      assert LiveHelpers.maybe_put(%{a: 1}, :b, "v") == %{a: 1, b: "v"}
    end
  end

  describe "maybe_put/4 with default" do
    test "skips when value matches default" do
      assert LiveHelpers.maybe_put(%{}, :sort, "name", "name") == %{}
    end

    test "adds when value differs from default" do
      assert LiveHelpers.maybe_put(%{}, :sort, "email", "name") == %{sort: "email"}
    end
  end
end
