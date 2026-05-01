defmodule LmsWeb.SharedComponents do
  @moduledoc """
  HEEx function components shared across multiple LiveViews.

  Use sparingly: components that belong to a single feature stay in
  their own LiveView. Lift here only when 2+ unrelated pages need the
  same markup.
  """

  use Phoenix.Component

  import LmsWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders an up/down arrow next to a sortable column header when that
  column is the active sort field.

  ## Attributes

    * `:sort_by` (required) — the currently-sorted field (atom).
    * `:sort_order` (required) — `:asc` or `:desc`.
    * `:field` (required) — the field this header represents.
  """
  attr :sort_by, :atom, required: true
  attr :sort_order, :atom, required: true
  attr :field, :atom, required: true

  def sort_indicator(assigns) do
    ~H"""
    <span :if={@sort_by == @field} class="ml-1">
      <.icon
        :if={@sort_order == :asc}
        name="hero-chevron-up"
        class="size-3 inline"
      />
      <.icon
        :if={@sort_order == :desc}
        name="hero-chevron-down"
        class="size-3 inline"
      />
    </span>
    """
  end
end
