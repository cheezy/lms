defmodule Lms.Training.LessonRenderer do
  @moduledoc """
  Renders TipTap JSON content to sanitized HTML.

  Converts ProseMirror document nodes to HTML elements, handling
  headings, paragraphs, lists, links, code blocks, and inline marks.
  """

  @doc """
  Renders a TipTap JSON document to an HTML string.

  Returns an empty string for nil or empty content.
  """
  def render(nil), do: ""
  def render(%{"type" => "doc", "content" => content}), do: render_nodes(content)
  def render(%{"type" => "doc"}), do: ""
  def render(_), do: ""

  defp render_nodes(nil), do: ""
  defp render_nodes(nodes) when is_list(nodes), do: Enum.map_join(nodes, "", &render_node/1)

  defp render_node(%{"type" => "heading", "attrs" => %{"level" => level}} = node) do
    tag = "h#{level}"
    content = render_inline(node["content"])
    "<#{tag}>#{content}</#{tag}>"
  end

  defp render_node(%{"type" => "paragraph"} = node) do
    content = render_inline(node["content"])
    "<p>#{content}</p>"
  end

  defp render_node(%{"type" => "bulletList"} = node) do
    items = render_nodes(node["content"])
    "<ul>#{items}</ul>"
  end

  defp render_node(%{"type" => "orderedList"} = node) do
    items = render_nodes(node["content"])
    "<ol>#{items}</ol>"
  end

  defp render_node(%{"type" => "listItem"} = node) do
    content = render_nodes(node["content"])
    "<li>#{content}</li>"
  end

  defp render_node(%{"type" => "blockquote"} = node) do
    content = render_nodes(node["content"])
    "<blockquote>#{content}</blockquote>"
  end

  defp render_node(%{"type" => "codeBlock"} = node) do
    content = render_inline(node["content"])
    "<pre><code>#{content}</code></pre>"
  end

  defp render_node(%{"type" => "image", "attrs" => %{"src" => src}} = node) do
    safe_src = escape_html(src)
    alt = escape_html(node["attrs"]["alt"] || "")
    "<img src=\"#{safe_src}\" alt=\"#{alt}\"/>"
  end

  defp render_node(%{"type" => "horizontalRule"}), do: "<hr/>"

  defp render_node(%{"type" => "hardBreak"}), do: "<br/>"

  defp render_node(_), do: ""

  defp render_inline(nil), do: ""

  defp render_inline(nodes) when is_list(nodes),
    do: Enum.map_join(nodes, "", &render_inline_node/1)

  defp render_inline_node(%{"type" => "text", "text" => text} = node) do
    escaped = escape_html(text)
    apply_marks(escaped, node["marks"] || [])
  end

  defp render_inline_node(%{"type" => "hardBreak"}), do: "<br/>"
  defp render_inline_node(_), do: ""

  defp apply_marks(text, marks) do
    Enum.reduce(marks, text, fn mark, acc ->
      wrap_mark(acc, mark)
    end)
  end

  defp wrap_mark(text, %{"type" => "bold"}), do: "<strong>#{text}</strong>"
  defp wrap_mark(text, %{"type" => "italic"}), do: "<em>#{text}</em>"
  defp wrap_mark(text, %{"type" => "strike"}), do: "<s>#{text}</s>"
  defp wrap_mark(text, %{"type" => "code"}), do: "<code>#{text}</code>"

  defp wrap_mark(text, %{"type" => "link", "attrs" => %{"href" => href}}) do
    safe_href = escape_html(href)
    "<a href=\"#{safe_href}\" rel=\"noopener noreferrer\">#{text}</a>"
  end

  defp wrap_mark(text, _), do: text

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp escape_html(_), do: ""
end
