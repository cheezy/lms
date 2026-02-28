import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Link from "@tiptap/extension-link"

const TipTapEditor = {
  mounted() {
    const content = JSON.parse(this.el.dataset.content || '{"type":"doc","content":[]}')

    this.editor = new Editor({
      element: this.el.querySelector("[data-editor]"),
      extensions: [
        StarterKit.configure({
          heading: { levels: [1, 2, 3] },
        }),
        Link.configure({
          openOnClick: false,
          HTMLAttributes: { class: "link link-primary" },
        }),
      ],
      content,
      editorProps: {
        attributes: {
          class: "prose prose-sm max-w-none min-h-[400px] p-4 focus:outline-none bg-base-100 text-base-content rounded-b-lg border border-t-0 border-base-300",
        },
      },
      onUpdate: ({ editor }) => {
        this.pushEventTo(this.el, "editor_updated", {
          content: JSON.stringify(editor.getJSON()),
        })
      },
    })

    this.handleEvent("set_editor_content", ({ content }) => {
      const json = typeof content === "string" ? JSON.parse(content) : content
      this.editor.commands.setContent(json)
    })

    this._renderToolbar()
  },

  updated() {
    // Re-read readOnly state from data attribute
    const readOnly = this.el.dataset.readonly === "true"
    this.editor.setEditable(!readOnly)

    // Toggle toolbar visibility
    const toolbar = this.el.querySelector("[data-toolbar]")
    if (toolbar) {
      toolbar.style.display = readOnly ? "none" : ""
    }
  },

  destroyed() {
    if (this.editor) {
      this.editor.destroy()
    }
  },

  _renderToolbar() {
    const toolbar = this.el.querySelector("[data-toolbar]")
    if (!toolbar) return

    const buttons = [
      { label: "H1", command: () => this.editor.chain().focus().toggleHeading({ level: 1 }).run(), active: () => this.editor.isActive("heading", { level: 1 }) },
      { label: "H2", command: () => this.editor.chain().focus().toggleHeading({ level: 2 }).run(), active: () => this.editor.isActive("heading", { level: 2 }) },
      { label: "H3", command: () => this.editor.chain().focus().toggleHeading({ level: 3 }).run(), active: () => this.editor.isActive("heading", { level: 3 }) },
      { type: "separator" },
      { label: "B", command: () => this.editor.chain().focus().toggleBold().run(), active: () => this.editor.isActive("bold"), style: "font-weight:bold" },
      { label: "I", command: () => this.editor.chain().focus().toggleItalic().run(), active: () => this.editor.isActive("italic"), style: "font-style:italic" },
      { label: "S", command: () => this.editor.chain().focus().toggleStrike().run(), active: () => this.editor.isActive("strike"), style: "text-decoration:line-through" },
      { label: "Code", command: () => this.editor.chain().focus().toggleCode().run(), active: () => this.editor.isActive("code") },
      { type: "separator" },
      { label: "UL", command: () => this.editor.chain().focus().toggleBulletList().run(), active: () => this.editor.isActive("bulletList") },
      { label: "OL", command: () => this.editor.chain().focus().toggleOrderedList().run(), active: () => this.editor.isActive("orderedList") },
      { type: "separator" },
      { label: "Blockquote", command: () => this.editor.chain().focus().toggleBlockquote().run(), active: () => this.editor.isActive("blockquote") },
      { label: "Code Block", command: () => this.editor.chain().focus().toggleCodeBlock().run(), active: () => this.editor.isActive("codeBlock") },
      { label: "HR", command: () => this.editor.chain().focus().setHorizontalRule().run(), active: () => false },
      { type: "separator" },
      { label: "Link", command: () => this._toggleLink(), active: () => this.editor.isActive("link") },
    ]

    buttons.forEach(btn => {
      if (btn.type === "separator") {
        const sep = document.createElement("div")
        sep.className = "w-px h-5 bg-base-300 mx-0.5"
        toolbar.appendChild(sep)
        return
      }

      const button = document.createElement("button")
      button.type = "button"
      button.textContent = btn.label
      button.className = "btn btn-ghost btn-xs text-xs"
      if (btn.style) button.style.cssText = btn.style
      button.addEventListener("click", (e) => {
        e.preventDefault()
        btn.command()
        this._updateToolbarState(toolbar, buttons)
      })
      toolbar.appendChild(button)
    })

    // Update active states on selection change
    this.editor.on("selectionUpdate", () => this._updateToolbarState(toolbar, buttons))
    this.editor.on("transaction", () => this._updateToolbarState(toolbar, buttons))
  },

  _updateToolbarState(toolbar, buttons) {
    let btnIndex = 0
    toolbar.childNodes.forEach(node => {
      if (node.className && node.className.includes("w-px")) return
      const btn = buttons[btnIndex]
      if (btn && !btn.type) {
        if (btn.active()) {
          node.classList.add("btn-active")
        } else {
          node.classList.remove("btn-active")
        }
      }
      btnIndex++
    })
  },

  _toggleLink() {
    if (this.editor.isActive("link")) {
      this.editor.chain().focus().unsetLink().run()
    } else {
      const url = window.prompt("Enter URL:")
      if (url) {
        this.editor.chain().focus().extendMarkRange("link").setLink({ href: url }).run()
      }
    }
  },
}

export default TipTapEditor
