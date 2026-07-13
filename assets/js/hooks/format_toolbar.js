// Tiny formatting toolbar for a plain <textarea>.
//
// The element this hook is attached to must have `data-target` pointing at
// the id of the textarea it formats. Supports two markdown-lite tokens that
// the server renders back into styled HTML (see
// BetaSigma.Projects.Mentions): "**bold**" and "# heading" lines.

const FormatToolbar = {
  mounted() {
    this.textarea = document.getElementById(this.el.dataset.target);
    if (!this.textarea) return;

    this.onClick = (event) => {
      const button = event.target.closest("[data-format]");
      if (!button) return;

      event.preventDefault();
      this.apply(button.dataset.format);
    };

    this.el.addEventListener("click", this.onClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick);
  },

  apply(format) {
    const textarea = this.textarea;
    const { value, selectionStart, selectionEnd } = textarea;
    const selected = value.slice(selectionStart, selectionEnd);

    let next, cursorStart, cursorEnd;

    if (format === "bold") {
      const text = selected || "bold text";
      next =
        value.slice(0, selectionStart) + `**${text}**` + value.slice(selectionEnd);
      cursorStart = selectionStart + 2;
      cursorEnd = cursorStart + text.length;
    } else if (format === "heading") {
      const lineStart = value.lastIndexOf("\n", selectionStart - 1) + 1;
      const text = selected || value.slice(lineStart, value.indexOf("\n", lineStart) === -1 ? value.length : value.indexOf("\n", lineStart));
      const cleanText = text.replace(/^#+\s*/, "") || "Heading";
      const lineEnd = value.indexOf("\n", lineStart) === -1 ? value.length : value.indexOf("\n", lineStart);

      next = value.slice(0, lineStart) + `# ${cleanText}` + value.slice(lineEnd);
      cursorStart = lineStart + 2;
      cursorEnd = cursorStart + cleanText.length;
    } else {
      return;
    }

    textarea.value = next;
    textarea.setSelectionRange(cursorStart, cursorEnd);
    textarea.focus();
    textarea.dispatchEvent(new Event("input", { bubbles: true }));
  },
};

export default FormatToolbar;
