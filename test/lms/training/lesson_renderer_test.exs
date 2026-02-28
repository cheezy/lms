defmodule Lms.Training.LessonRendererTest do
  use ExUnit.Case, async: true

  alias Lms.Training.LessonRenderer

  describe "render/1" do
    test "renders nil as empty string" do
      assert LessonRenderer.render(nil) == ""
    end

    test "renders empty doc" do
      assert LessonRenderer.render(%{"type" => "doc"}) == ""
    end

    test "renders doc with empty content" do
      assert LessonRenderer.render(%{"type" => "doc", "content" => []}) == ""
    end

    test "renders paragraph" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "Hello world"}]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<p>Hello world</p>"
    end

    test "renders headings" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "heading",
            "attrs" => %{"level" => 1},
            "content" => [%{"type" => "text", "text" => "Title"}]
          },
          %{
            "type" => "heading",
            "attrs" => %{"level" => 2},
            "content" => [%{"type" => "text", "text" => "Subtitle"}]
          },
          %{
            "type" => "heading",
            "attrs" => %{"level" => 3},
            "content" => [%{"type" => "text", "text" => "Section"}]
          }
        ]
      }

      result = LessonRenderer.render(doc)
      assert result =~ "<h1>Title</h1>"
      assert result =~ "<h2>Subtitle</h2>"
      assert result =~ "<h3>Section</h3>"
    end

    test "renders bold text" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "text", "text" => "Hello "},
              %{"type" => "text", "text" => "world", "marks" => [%{"type" => "bold"}]}
            ]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<p>Hello <strong>world</strong></p>"
    end

    test "renders italic text" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "text", "text" => "emphasis", "marks" => [%{"type" => "italic"}]}
            ]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<p><em>emphasis</em></p>"
    end

    test "renders strikethrough text" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "text", "text" => "deleted", "marks" => [%{"type" => "strike"}]}
            ]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<p><s>deleted</s></p>"
    end

    test "renders inline code" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "text", "text" => "foo", "marks" => [%{"type" => "code"}]}
            ]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<p><code>foo</code></p>"
    end

    test "renders link" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{
                "type" => "text",
                "text" => "click here",
                "marks" => [
                  %{"type" => "link", "attrs" => %{"href" => "https://example.com"}}
                ]
              }
            ]
          }
        ]
      }

      result = LessonRenderer.render(doc)
      assert result =~ ~s(<a href="https://example.com" rel="noopener noreferrer">click here</a>)
    end

    test "renders multiple marks on same text" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{
                "type" => "text",
                "text" => "both",
                "marks" => [%{"type" => "bold"}, %{"type" => "italic"}]
              }
            ]
          }
        ]
      }

      result = LessonRenderer.render(doc)
      assert result =~ "<strong>"
      assert result =~ "<em>"
      assert result =~ "both"
    end

    test "renders bullet list" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "bulletList",
            "content" => [
              %{
                "type" => "listItem",
                "content" => [
                  %{
                    "type" => "paragraph",
                    "content" => [%{"type" => "text", "text" => "Item 1"}]
                  }
                ]
              },
              %{
                "type" => "listItem",
                "content" => [
                  %{
                    "type" => "paragraph",
                    "content" => [%{"type" => "text", "text" => "Item 2"}]
                  }
                ]
              }
            ]
          }
        ]
      }

      result = LessonRenderer.render(doc)
      assert result =~ "<ul>"
      assert result =~ "<li><p>Item 1</p></li>"
      assert result =~ "<li><p>Item 2</p></li>"
      assert result =~ "</ul>"
    end

    test "renders ordered list" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "orderedList",
            "content" => [
              %{
                "type" => "listItem",
                "content" => [
                  %{
                    "type" => "paragraph",
                    "content" => [%{"type" => "text", "text" => "First"}]
                  }
                ]
              }
            ]
          }
        ]
      }

      result = LessonRenderer.render(doc)
      assert result =~ "<ol>"
      assert result =~ "<li><p>First</p></li>"
    end

    test "renders blockquote" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "blockquote",
            "content" => [
              %{
                "type" => "paragraph",
                "content" => [%{"type" => "text", "text" => "A quote"}]
              }
            ]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<blockquote><p>A quote</p></blockquote>"
    end

    test "renders code block" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "codeBlock",
            "content" => [%{"type" => "text", "text" => "def hello, do: :world"}]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<pre><code>def hello, do: :world</code></pre>"
    end

    test "renders horizontal rule" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Above"}]},
          %{"type" => "horizontalRule"},
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Below"}]}
        ]
      }

      assert LessonRenderer.render(doc) == "<p>Above</p><hr/><p>Below</p>"
    end

    test "renders image node" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "image",
            "attrs" => %{"src" => "/uploads/photo.jpg", "alt" => "A photo"}
          }
        ]
      }

      assert LessonRenderer.render(doc) ==
               ~s(<img src="/uploads/photo.jpg" alt="A photo"/>)
    end

    test "renders image node without alt text" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "image",
            "attrs" => %{"src" => "/uploads/photo.jpg"}
          }
        ]
      }

      assert LessonRenderer.render(doc) ==
               ~s(<img src="/uploads/photo.jpg" alt=""/>)
    end

    test "escapes HTML in image attributes" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "image",
            "attrs" => %{
              "src" => "/uploads/test.jpg\" onload=\"alert(1)",
              "alt" => "bad<script>"
            }
          }
        ]
      }

      html = LessonRenderer.render(doc)
      # Quotes are escaped so the attribute injection is neutralized
      refute html =~ ~s(onload="alert)
      refute html =~ "<script>"
      assert html =~ "&quot;"
      assert html =~ "&lt;script&gt;"
    end

    test "renders hard break" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "text", "text" => "Line 1"},
              %{"type" => "hardBreak"},
              %{"type" => "text", "text" => "Line 2"}
            ]
          }
        ]
      }

      assert LessonRenderer.render(doc) == "<p>Line 1<br/>Line 2</p>"
    end

    test "escapes HTML in text" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "<script>alert('xss')</script>"}]
          }
        ]
      }

      result = LessonRenderer.render(doc)
      assert result =~ "&lt;script&gt;"
      refute result =~ "<script>"
    end

    test "escapes HTML in link href" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{
                "type" => "text",
                "text" => "click",
                "marks" => [
                  %{
                    "type" => "link",
                    "attrs" => %{"href" => "javascript:alert(\"xss\")"}
                  }
                ]
              }
            ]
          }
        ]
      }

      result = LessonRenderer.render(doc)
      assert result =~ "&quot;"
      refute result =~ ~s[href="javascript:alert("xss")"]
    end

    test "renders YouTube video embed" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "videoEmbed",
            "attrs" => %{"src" => "https://www.youtube.com/embed/dQw4w9WgXcQ"}
          }
        ]
      }

      html = LessonRenderer.render(doc)
      assert html =~ ~s(src="https://www.youtube.com/embed/dQw4w9WgXcQ")
      assert html =~ "iframe"
      assert html =~ "allowfullscreen"
      assert html =~ ~s(class="relative w-full pb-[56.25%])
    end

    test "renders Vimeo video embed" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "videoEmbed",
            "attrs" => %{"src" => "https://player.vimeo.com/video/123456789"}
          }
        ]
      }

      html = LessonRenderer.render(doc)
      assert html =~ ~s(src="https://player.vimeo.com/video/123456789")
      assert html =~ "iframe"
    end

    test "rejects invalid video embed URLs" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "videoEmbed",
            "attrs" => %{"src" => "https://evil.com/malware.js"}
          }
        ]
      }

      assert LessonRenderer.render(doc) == ""
    end

    test "rejects video embed with javascript: URL" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "videoEmbed",
            "attrs" => %{"src" => "javascript:alert(1)"}
          }
        ]
      }

      assert LessonRenderer.render(doc) == ""
    end

    test "rejects video embed with tampered YouTube URL" do
      doc = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "videoEmbed",
            "attrs" => %{"src" => "https://www.youtube.com/embed/dQw4w9WgXcQ\" onload=\"alert(1)"}
          }
        ]
      }

      # The URL won't match the strict pattern so it gets rejected
      assert LessonRenderer.render(doc) == ""
    end

    test "renders unknown types gracefully" do
      doc = %{
        "type" => "doc",
        "content" => [%{"type" => "unknownBlock"}]
      }

      assert LessonRenderer.render(doc) == ""
    end

    test "renders invalid input as empty string" do
      assert LessonRenderer.render("not a map") == ""
      assert LessonRenderer.render(42) == ""
    end
  end
end
