const AutoDismiss = {
  mounted() {
    const delay = parseInt(this.el.dataset.autoDismiss, 10) || 3000
    this.timer = setTimeout(() => this.el.click(), delay)
  },
  destroyed() {
    if (this.timer) clearTimeout(this.timer)
  },
}

export default AutoDismiss
