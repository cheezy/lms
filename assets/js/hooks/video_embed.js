import { Node, mergeAttributes } from "@tiptap/core"

/**
 * Custom TipTap node extension for YouTube/Vimeo video embeds.
 *
 * Stores a `src` attribute containing the embed URL.
 * Renders as a responsive 16:9 iframe in the editor.
 */
const VideoEmbed = Node.create({
  name: "videoEmbed",
  group: "block",
  atom: true,

  addAttributes() {
    return {
      src: { default: null },
    }
  },

  parseHTML() {
    return [
      {
        tag: "div[data-video-embed]",
        getAttrs: (dom) => ({
          src: dom.querySelector("iframe")?.getAttribute("src"),
        }),
      },
    ]
  },

  renderHTML({ HTMLAttributes }) {
    return [
      "div",
      {
        "data-video-embed": "",
        class: "relative w-full pb-[56.25%] h-0 overflow-hidden rounded-lg my-4",
      },
      [
        "iframe",
        mergeAttributes(HTMLAttributes, {
          class: "absolute top-0 left-0 w-full h-full",
          frameborder: "0",
          allowfullscreen: "true",
          allow:
            "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture",
        }),
      ],
    ]
  },

  addCommands() {
    return {
      setVideoEmbed:
        (attrs) =>
        ({ commands }) => {
          return commands.insertContent({
            type: this.name,
            attrs,
          })
        },
    }
  },
})

/**
 * Parses a YouTube or Vimeo URL and returns the embed URL.
 * Returns null for unsupported or invalid URLs.
 */
export function parseVideoUrl(url) {
  if (!url || typeof url !== "string") return null

  const trimmed = url.trim()

  // YouTube patterns
  const youtubePatterns = [
    // Standard: youtube.com/watch?v=ID
    /(?:https?:\/\/)?(?:www\.)?youtube\.com\/watch\?.*v=([a-zA-Z0-9_-]{11})/,
    // Short: youtu.be/ID
    /(?:https?:\/\/)?youtu\.be\/([a-zA-Z0-9_-]{11})/,
    // Embed: youtube.com/embed/ID
    /(?:https?:\/\/)?(?:www\.)?youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
    // Shorts: youtube.com/shorts/ID
    /(?:https?:\/\/)?(?:www\.)?youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/,
  ]

  for (const pattern of youtubePatterns) {
    const match = trimmed.match(pattern)
    if (match && match[1]) {
      return `https://www.youtube.com/embed/${match[1]}`
    }
  }

  // Vimeo patterns
  const vimeoPatterns = [
    // Standard: vimeo.com/ID
    /(?:https?:\/\/)?(?:www\.)?vimeo\.com\/(\d+)/,
    // Player: player.vimeo.com/video/ID
    /(?:https?:\/\/)?player\.vimeo\.com\/video\/(\d+)/,
  ]

  for (const pattern of vimeoPatterns) {
    const match = trimmed.match(pattern)
    if (match && match[1]) {
      return `https://player.vimeo.com/video/${match[1]}`
    }
  }

  return null
}

export default VideoEmbed
