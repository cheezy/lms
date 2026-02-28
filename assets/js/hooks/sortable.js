import Sortable from "sortablejs"

const SortableChapters = {
  mounted() {
    this.sortable = Sortable.create(this.el, {
      handle: "[data-drag-handle]",
      animation: 150,
      ghostClass: "opacity-30",
      dragClass: "shadow-lg",
      group: "chapters",
      onEnd: (_evt) => {
        const ids = Array.from(this.el.querySelectorAll("[data-chapter-id]"))
          .map(el => el.dataset.chapterId)
        this.pushEvent("reorder_chapters", { ids })
      }
    })
  },
  destroyed() {
    if (this.sortable) this.sortable.destroy()
  }
}

const SortableLessons = {
  mounted() {
    this.sortable = Sortable.create(this.el, {
      handle: "[data-drag-handle]",
      animation: 150,
      ghostClass: "opacity-30",
      dragClass: "shadow-lg",
      group: "lessons",
      onEnd: (evt) => {
        const fromChapterId = evt.from.dataset.chapterId
        const toChapterId = evt.to.dataset.chapterId
        const ids = Array.from(evt.to.querySelectorAll("[data-lesson-id]"))
          .map(el => el.dataset.lessonId)

        if (fromChapterId === toChapterId) {
          this.pushEvent("reorder_lessons", {
            chapter_id: toChapterId,
            ids: ids
          })
        } else {
          const lessonId = evt.item.dataset.lessonId
          this.pushEvent("move_lesson_to_chapter_and_reorder", {
            lesson_id: lessonId,
            from_chapter_id: fromChapterId,
            to_chapter_id: toChapterId,
            ids: ids
          })
        }
      }
    })
  },
  destroyed() {
    if (this.sortable) this.sortable.destroy()
  }
}

export { SortableChapters, SortableLessons }
