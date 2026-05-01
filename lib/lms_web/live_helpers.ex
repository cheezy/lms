defmodule LmsWeb.LiveHelpers do
  @moduledoc """
  Shared helper functions for LiveViews and LiveComponents.

  Includes formatters and URL parameter helpers used across multiple
  list pages (employees, enrollments, courses).
  """

  @doc """
  Formats a progress value (float 0-100) as a whole-percent string.

      iex> LmsWeb.LiveHelpers.format_progress(42.7)
      "43%"
  """
  def format_progress(progress) do
    :erlang.float_to_binary(progress, decimals: 0) <> "%"
  end

  @doc """
  Returns a list of page numbers around `current_page`, clamped to the
  valid range `1..total_pages`. Used to render pagination controls.
  """
  def pagination_range(current_page, total_pages) do
    start_page = max(1, current_page - 2)
    end_page = min(total_pages, current_page + 2)
    Enum.to_list(start_page..end_page)
  end

  @doc """
  Adds `{key, value}` to `params` unless the value is nil or an empty string.
  Used to build clean URL query strings without empty filter parameters.
  """
  def maybe_put(params, _key, nil), do: params
  def maybe_put(params, _key, ""), do: params
  def maybe_put(params, key, value), do: Map.put(params, key, value)

  @doc """
  Adds `{key, value}` to `params` unless `value` matches `default`.
  Used to omit query parameters that are at their default state.
  """
  def maybe_put(params, _key, default, default), do: params
  def maybe_put(params, key, value, _default), do: Map.put(params, key, value)
end
