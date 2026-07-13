// Lightweight @mention typeahead for plain <textarea> fields.
//
// The element this hook is attached to must expose a JSON list of mentionable
// users via `data-mention-users` (e.g. [{"id": 1, "name": "Jane Doe"}]).
// Selecting a person inserts friendly `@Name` text while editing, then encodes
// it back to the stable `@[Name](user:ID)` token before submit.

const QUERY_REGEX = /@([\p{L}\p{N}._-]*)$/u;
const TOKEN_REGEX = /@\[([^\]\n]+)\]\(user:(\d+)\)/g;
const MENTION_BOUNDARY = "(?![\\p{L}\\p{N}._-])";
const MENU_MARGIN = 8;

const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const MentionInput = {
  mounted() {
    this.users = this.parseUsers();
    this.activeIndex = 0;
    this.matches = [];
    this.queryStart = null;
    this.mentionMap = new Map();

    this.menu = document.createElement("ul");
    this.menu.className =
      "mention-menu hidden fixed z-[1000] max-h-64 overflow-y-auto rounded-2xl border border-stone-200 bg-white py-1 text-sm shadow-xl";
    // Append inside the nearest phx-click-away root (e.g. a modal) so clicking
    // a suggestion isn't treated as an "outside click" that closes it.
    const clickAwayRoot = this.el.closest("[phx-click-away]");
    (clickAwayRoot || document.body).appendChild(this.menu);

    this.onInput = () => this.handleInput();
    this.onKeyDown = (event) => this.handleKeyDown(event);
    this.onBlur = () => setTimeout(() => this.hide(), 120);

    this.el.addEventListener("input", this.onInput);
    this.el.addEventListener("keydown", this.onKeyDown);
    this.el.addEventListener("blur", this.onBlur);

    this.form = this.el.closest("form");
    if (this.form) {
      this.onSubmit = () => this.encodeMentions();
      this.form.addEventListener("submit", this.onSubmit, true);
    }

    this.decodeTokens();
  },

  updated() {
    // Keep the menu in sync if the list of users changes between patches.
    this.users = this.parseUsers();
    this.decodeTokens();
  },

  destroyed() {
    this.el.removeEventListener("input", this.onInput);
    this.el.removeEventListener("keydown", this.onKeyDown);
    this.el.removeEventListener("blur", this.onBlur);
    if (this.form && this.onSubmit) {
      this.form.removeEventListener("submit", this.onSubmit, true);
    }
    this.menu && this.menu.remove();
  },

  parseUsers() {
    try {
      return JSON.parse(this.el.dataset.mentionUsers || "[]");
    } catch (_error) {
      return [];
    }
  },

  decodeTokens() {
    const value = this.el.value || "";
    if (!TOKEN_REGEX.test(value)) {
      TOKEN_REGEX.lastIndex = 0;
      return;
    }

    TOKEN_REGEX.lastIndex = 0;
    const decoded = value.replace(TOKEN_REGEX, (_token, name, id) => {
      const user =
        this.users.find((candidate) => String(candidate.id) === String(id)) || {
          id,
          name,
        };

      this.mentionMap.set(name, user);
      return `@${name}`;
    });

    if (decoded !== value) {
      const caret = this.el.selectionStart;
      const cursor = Math.min(caret, decoded.length);
      this.el.value = decoded;
      this.el.setSelectionRange(cursor, cursor);
    }
  },

  encodeMentions() {
    if (this.mentionMap.size === 0) return;

    let body = this.el.value;

    Array.from(this.mentionMap.entries())
      .sort(([leftName], [rightName]) => rightName.length - leftName.length)
      .forEach(([name, user]) => {
        const token = `@[${name}](user:${user.id})`;
        const matcher = new RegExp(
          `@${escapeRegExp(name)}${MENTION_BOUNDARY}`,
          "gu",
        );

        body = body.replace(matcher, token);
      });

    this.el.value = body;
  },

  handleInput() {
    this.pruneMentionMap();

    const caret = this.el.selectionStart;
    const before = this.el.value.slice(0, caret);
    const match = before.match(QUERY_REGEX);

    if (!match) {
      this.hide();
      return;
    }

    const query = match[1].toLowerCase();
    this.queryStart = caret - match[0].length;
    this.matches = this.users.filter((user) =>
      (user.name || "").toLowerCase().includes(query),
    );

    if (this.matches.length === 0) {
      this.hide();
      return;
    }

    this.activeIndex = 0;
    this.render();
  },

  pruneMentionMap() {
    const body = this.el.value || "";

    this.mentionMap.forEach((_user, name) => {
      if (!body.includes(`@${name}`)) {
        this.mentionMap.delete(name);
      }
    });
  },

  handleKeyDown(event) {
    if (this.menu.classList.contains("hidden")) return;

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.activeIndex = (this.activeIndex + 1) % this.matches.length;
        this.render();
        break;
      case "ArrowUp":
        event.preventDefault();
        this.activeIndex =
          (this.activeIndex - 1 + this.matches.length) % this.matches.length;
        this.render();
        break;
      case "Enter":
      case "Tab":
        event.preventDefault();
        this.select(this.matches[this.activeIndex]);
        break;
      case "Escape":
        event.preventDefault();
        this.hide();
        break;
    }
  },

  select(user) {
    if (!user) return;

    const value = this.el.value;
    const caret = this.el.selectionStart;
    const display = `@${user.name} `;
    const next = value.slice(0, this.queryStart) + display + value.slice(caret);
    const cursor = this.queryStart + display.length;

    this.mentionMap.set(user.name, user);
    this.el.value = next;
    this.el.setSelectionRange(cursor, cursor);
    // Let LiveView's phx-change pick up the new value.
    this.el.dispatchEvent(new Event("input", { bubbles: true }));
    this.hide();
    this.el.focus();
  },

  render() {
    this.menu.innerHTML = "";

    const header = document.createElement("li");
    header.textContent = "Mention teammate";
    header.className =
      "px-3 py-2 text-xs font-semibold uppercase tracking-wide text-stone-400";
    this.menu.appendChild(header);

    this.matches.forEach((user, index) => {
      const item = document.createElement("li");
      item.textContent = user.name;
      item.className =
        "cursor-pointer px-3 py-2 " +
        (index === this.activeIndex
          ? "bg-stone-100 text-slate-900"
          : "text-slate-600");
      item.addEventListener("mousedown", (event) => {
        event.preventDefault();
        event.stopPropagation();
        this.select(user);
      });
      this.menu.appendChild(item);
    });

    const rect = this.el.getBoundingClientRect();
    const width = Math.min(rect.width, 360);
    const left = Math.min(
      Math.max(rect.left, MENU_MARGIN),
      window.innerWidth - width - MENU_MARGIN,
    );

    this.menu.style.left = `${left}px`;
    this.menu.style.width = `${width}px`;
    this.menu.classList.remove("hidden");
    this.positionMenu(rect);
  },

  positionMenu(inputRect) {
    const menuHeight = this.menu.offsetHeight;
    const top = Math.min(
      Math.max(inputRect.bottom + 4, MENU_MARGIN),
      window.innerHeight - menuHeight - MENU_MARGIN,
    );

    this.menu.style.top = `${top}px`;
  },

  hide() {
    this.matches = [];
    this.queryStart = null;
    this.menu.classList.add("hidden");
  },
};

export default MentionInput;
