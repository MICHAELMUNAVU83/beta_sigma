// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import Cropper from "cropperjs";
import Sortable from "sortablejs";
import topbar from "../vendor/topbar";

const showDialog = (id) => {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.remove("hidden");
};

const hideDialog = (id) => {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.add("hidden");
};
import AptitudeProctoring from "./hooks/aptitude_proctoring";
import MeetingRecorder from "./hooks/meeting_recorder";
import MentionInput from "./hooks/mention_input";
import FormatToolbar from "./hooks/format_toolbar";

let Hooks = {};

Hooks.ChartJS = {
  mounted() {
    this.renderChart();
  },

  updated() {
    this.renderChart();
  },

  destroyed() {
    this.destroyChart();
  },

  destroyChart() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  },

  renderChart() {
    // Chart.js is loaded globally via a script tag in the root layout.
    if (!window.Chart) {
      clearTimeout(this.retryTimer);
      this.retryTimer = setTimeout(() => this.renderChart(), 60);
      return;
    }

    let rawConfig = this.el.dataset.chart || "{}";
    if (rawConfig === this.lastConfig) {
      return;
    }

    let config;
    try {
      config = JSON.parse(rawConfig);
    } catch (_error) {
      return;
    }

    this.lastConfig = rawConfig;

    // One-time global defaults
    if (!window.__betaSigmaChartDefaults) {
      window.__betaSigmaChartDefaults = true;
      window.Chart.defaults.font.family =
        "Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif";
      window.Chart.defaults.color = "#404040";
      window.Chart.defaults.plugins.tooltip.padding = 12;
      window.Chart.defaults.plugins.tooltip.backgroundColor =
        "rgba(10, 10, 10, 0.92)";
      window.Chart.defaults.plugins.tooltip.titleColor = "#f8fafc";
      window.Chart.defaults.plugins.tooltip.bodyColor = "#f8fafc";
    }

    this.destroyChart();

    let ctx = this.el.getContext("2d");
    if (!ctx) {
      return;
    }

    this.chart = new window.Chart(ctx, config);
  },
};

Hooks.KanbanColumn = {
  mounted() {
    this.initSortable();
  },

  updated() {
    // Reinitialize after LiveView patches the DOM so SortableJS
    // stays in sync with the server-rendered element order.
    if (this.sortable) {
      this.sortable.destroy();
    }
    this.initSortable();
  },

  destroyed() {
    this.sortable?.destroy();
  },

  initSortable() {
    this.sortable = Sortable.create(this.el, {
      group: "project-kanban",
      animation: 180,
      ghostClass: "kanban-ghost",
      dragClass: "kanban-drag",
      onEnd: (event) => {
        let taskId = event.item?.dataset?.taskId;
        let toColumn = event.to?.dataset?.status;
        let fromColumn = event.from?.dataset?.status;

        if (!taskId || !toColumn) {
          return;
        }

        // Skip server round-trip when dropped back in the same column
        if (fromColumn === toColumn) {
          return;
        }

        this.pushEvent("move_task", { "task-id": taskId, status: toColumn });
      },
    });
  },
};

Hooks.ProcessAccordion = {
  mounted() {
    const cards = this.el.querySelectorAll(".proc-card");

    const activate = (index) => {
      cards.forEach((card, idx) => {
        card.dataset.active = idx === index ? "true" : "false";
      });
    };

    const initialIndex = Array.from(cards).findIndex(
      (card) => card.dataset.active === "true",
    );
    activate(initialIndex >= 0 ? initialIndex : 0);

    cards.forEach((card, idx) => {
      card.addEventListener("mouseenter", () => activate(idx));
      card.addEventListener("focusin", () => activate(idx));
      card.addEventListener("click", () => activate(idx));
    });
  },
};

Hooks.CopyToClipboard = {
  mounted() {
    this.handleClick = async () => {
      const selector = this.el.dataset.copyTarget;
      const source = selector ? document.querySelector(selector) : null;
      const text = source ? source.value || source.textContent || "" : "";

      if (!text.trim()) {
        return;
      }

      try {
        await navigator.clipboard.writeText(text);
        this.flashLabel(this.el.dataset.successLabel || "Copied");
      } catch (_error) {
        this.fallbackCopy(text);
        this.flashLabel(this.el.dataset.successLabel || "Copied");
      }
    };

    this.el.addEventListener("click", this.handleClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick);
  },

  fallbackCopy(text) {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "absolute";
    area.style.left = "-9999px";
    document.body.appendChild(area);
    area.select();
    document.execCommand("copy");
    document.body.removeChild(area);
  },

  flashLabel(label) {
    const target = this.el.querySelector("[data-copy-label]");

    if (!target) {
      return;
    }

    clearTimeout(this.resetTimer);

    const original = target.dataset.originalLabel || target.textContent;
    target.dataset.originalLabel = original;
    target.textContent = label;

    this.resetTimer = setTimeout(() => {
      target.textContent = original;
    }, 1600);
  },
};

Hooks.AvatarCropUpload = {
  mounted() {
    this.objectUrls = [];
    this.cropper = null;
    this.suspendInputEvent = false;
    this.previewImage = this.el.querySelector("[data-avatar-preview-image]");
    this.previewFallback = this.el.querySelector(
      "[data-avatar-preview-fallback]",
    );
    this.triggerButtons = this.el.querySelectorAll("[data-avatar-trigger]");
    this.resetButtons = this.el.querySelectorAll("[data-avatar-reset]");
    this.menuToggle = this.el.querySelector("[data-avatar-menu-toggle]");
    this.menu = this.el.querySelector("[data-avatar-menu]");
    this.deleteButton = this.el.querySelector("[data-avatar-delete]");
    this.cropperState = this.el.querySelector("[data-avatar-cropper-state]");
    this.modal = this.el.querySelector("[data-avatar-modal]");
    this.viewModal = this.el.querySelector("[data-avatar-view-modal]");
    this.viewModalImage = this.el.querySelector("[data-avatar-view-image]");
    this.viewModalClose = this.el.querySelector("[data-avatar-view-close]");
    this.saveButton = this.el.querySelector("[data-avatar-save]");
    this.floatingSaveButton = this.el.querySelector(
      "[data-avatar-save-floating]",
    );
    this.zoomInButton = this.el.querySelector("[data-avatar-zoom-in]");
    this.zoomOutButton = this.el.querySelector("[data-avatar-zoom-out]");
    this.cropperCanvasEl = null;
    this.cropperSelection = null;
    this.cropperImageEl = null;
    this.modalId = "avatar-crop-modal";
    this.isEditing = false;
    this.cropperImage = this.el.querySelector("[data-avatar-cropper-image]");
    this.croppedPreview = this.el.querySelector("[data-avatar-preview-crop]");
    this.errorTarget = this.el.querySelector("[data-avatar-error]");
    this.inlineErrorTarget = this.el.querySelector(
      "[data-avatar-inline-error]",
    );

    this.localFileInput = this.el.querySelector("[data-avatar-local-input]");
    this.uploadInput = this.el.querySelector("[data-avatar-upload-input]");
    this.pendingUploadFile = null;
    this.originalFile = null;
    this.originalFilename = "avatar";
    this.previewSrc = this.el.dataset.previewImage || "";
    this.normalizedPreviewSrc = "";
    this.submitAfterPrepare = false;
    this.hasCropChanges = false;
    this.isApplyingInitialCrop = false;
    this.isSubmitting = false;
    this.baseZoomRatio = 1;
    this.zoomFactor = 1;
    this.bindInput();
    this.bindTriggers();
    this.bindMenu();
    this.bindCropControls();
    this.bindFormSubmit();
    this.bindModalDismiss();
    this.bindViewModal();
    this.syncPreview(this.previewSrc);
    this.syncEditingUI();
    hideDialog(this.modalId);
  },

  updated() {
    const latestPreviewSrc = this.el.dataset.previewImage || "";

    if (
      this.isSubmitting &&
      latestPreviewSrc &&
      latestPreviewSrc !== this.previewSrc
    ) {
      this.previewSrc = latestPreviewSrc;
      this.normalizedPreviewSrc = "";
      this.syncPreview(latestPreviewSrc);
      this.isSubmitting = false;
      this.resetCropperState();
      this.hideError();
    }

    this.bindInput();
    this.bindTriggers();
    this.bindMenu();
    this.bindCropControls();
    this.bindFormSubmit();
    this.bindModalDismiss();
    this.bindViewModal();
    this.syncEditingUI();

    if (this.viewModalImage) {
      this.viewModalImage.src = latestPreviewSrc || this.previewSrc || "";
    }
  },

  destroyed() {
    this.destroyCropper();
    this.cleanupObjectUrls();
    if (this.localFileInput && this.onChange) {
      this.localFileInput.removeEventListener("change", this.onChange);
    }
    if (this.form && this.onSubmit) {
      this.form.removeEventListener("submit", this.onSubmit);
    }
    this.triggerButtons?.forEach((button) => {
      if (this.onTriggerClick)
        button.removeEventListener("click", this.onTriggerClick);
    });
    this.resetButtons?.forEach((button) => {
      if (this.onResetClick)
        button.removeEventListener("click", this.onResetClick);
    });
    if (this.modal && this.onModalClick) {
      this.modal.removeEventListener("click", this.onModalClick);
    }
    if (this.menuToggle && this.onMenuToggleClick) {
      this.menuToggle.removeEventListener("click", this.onMenuToggleClick);
    }
    if (this.deleteButton && this.onDeleteClick) {
      this.deleteButton.removeEventListener("click", this.onDeleteClick);
    }
    if (this.onDocumentClick) {
      document.removeEventListener("click", this.onDocumentClick);
    }
    if (this.zoomInButton && this.onZoomInClick) {
      this.zoomInButton.removeEventListener("click", this.onZoomInClick);
    }
    if (this.zoomOutButton && this.onZoomOutClick) {
      this.zoomOutButton.removeEventListener("click", this.onZoomOutClick);
    }
    if (this.viewModal && this.onViewModalClick) {
      this.viewModal.removeEventListener("click", this.onViewModalClick);
    }
    if (this.viewModalClose && this.onViewModalCloseClick) {
      this.viewModalClose.removeEventListener(
        "click",
        this.onViewModalCloseClick,
      );
    }
  },

  bindInput() {
    this.localFileInput = this.el.querySelector("[data-avatar-local-input]");
    this.uploadInput = this.el.querySelector("[data-avatar-upload-input]");

    if (!this.localFileInput) {
      return;
    }

    if (this.onChange) {
      this.localFileInput.removeEventListener("change", this.onChange);
    }

    this.onChange = (event) => this.handleFileChange(event);
    this.localFileInput.addEventListener("change", this.onChange);
  },

  openMenu() {
    if (!this.menu) {
      return;
    }

    this.menu.classList.remove(
      "invisible",
      "opacity-0",
      "translate-y-1",
      "scale-95",
      "pointer-events-none",
    );
    this.menu.classList.add(
      "visible",
      "opacity-100",
      "translate-y-0",
      "scale-100",
      "pointer-events-auto",
    );
  },

  closeMenu() {
    if (!this.menu) {
      return;
    }

    this.menu.classList.remove(
      "visible",
      "opacity-100",
      "translate-y-0",
      "scale-100",
      "pointer-events-auto",
    );
    this.menu.classList.add(
      "invisible",
      "opacity-0",
      "translate-y-1",
      "scale-95",
      "pointer-events-none",
    );
  },

  bindMenu() {
    this.menuToggle = this.el.querySelector("[data-avatar-menu-toggle]");
    this.menu = this.el.querySelector("[data-avatar-menu]");
    this.deleteButton = this.el.querySelector("[data-avatar-delete]");

    if (this.menuToggle) {
      if (this.onMenuToggleClick) {
        this.menuToggle.removeEventListener("click", this.onMenuToggleClick);
      }

      this.onMenuToggleClick = (event) => {
        event.preventDefault();
        event.stopPropagation();

        if (this.menu?.classList.contains("invisible")) {
          this.openMenu();
        } else {
          this.closeMenu();
        }
      };

      this.menuToggle.addEventListener("click", this.onMenuToggleClick);
    }

    if (this.deleteButton) {
      if (this.onDeleteClick) {
        this.deleteButton.removeEventListener("click", this.onDeleteClick);
      }

      this.onDeleteClick = () => {
        this.closeMenu();
      };

      this.deleteButton.addEventListener("click", this.onDeleteClick);
    }

    if (this.onDocumentClick) {
      document.removeEventListener("click", this.onDocumentClick);
    }

    this.onDocumentClick = (event) => {
      if (!this.el.contains(event.target)) {
        this.closeMenu();
      }
    };

    document.addEventListener("click", this.onDocumentClick);
  },

  bindCropControls() {
    this.zoomInButton = this.el.querySelector("[data-avatar-zoom-in]");
    this.zoomOutButton = this.el.querySelector("[data-avatar-zoom-out]");

    if (this.zoomInButton) {
      if (this.onZoomInClick) {
        this.zoomInButton.removeEventListener("click", this.onZoomInClick);
      }

      this.onZoomInClick = () => this.nudgeZoom(0.15);
      this.zoomInButton.addEventListener("click", this.onZoomInClick);
    }

    if (this.zoomOutButton) {
      if (this.onZoomOutClick) {
        this.zoomOutButton.removeEventListener("click", this.onZoomOutClick);
      }

      this.onZoomOutClick = () => this.nudgeZoom(-0.15);
      this.zoomOutButton.addEventListener("click", this.onZoomOutClick);
    }

    this.syncZoomControls();
  },

  bindViewModal() {
    this.viewModal = this.el.querySelector("[data-avatar-view-modal]");
    this.viewModalImage = this.el.querySelector("[data-avatar-view-image]");
    this.viewModalClose = this.el.querySelector("[data-avatar-view-close]");

    if (this.viewModalClose) {
      if (this.onViewModalCloseClick) {
        this.viewModalClose.removeEventListener(
          "click",
          this.onViewModalCloseClick,
        );
      }

      this.onViewModalCloseClick = () => hideDialog("avatar-view-modal");
      this.viewModalClose.addEventListener("click", this.onViewModalCloseClick);
    }

    if (this.viewModal) {
      if (this.onViewModalClick) {
        this.viewModal.removeEventListener("click", this.onViewModalClick);
      }

      this.onViewModalClick = (event) => {
        if (event.target === this.viewModal) {
          hideDialog("avatar-view-modal");
        }
      };

      this.viewModal.addEventListener("click", this.onViewModalClick);
    }
  },

  bindFormSubmit() {
    this.form = this.el;

    if (!this.form) return;

    if (this.onSubmit) {
      this.form.removeEventListener("submit", this.onSubmit);
    }

    this.onSubmit = async (event) => {
      event.preventDefault();

      if (this.isSubmitting) {
        return;
      }

      if (!this.cropperSelection) {
        this.showError("Please choose an image first.");
        return;
      }

      this.hideError();
      this.isSubmitting = true;
      this.syncEditingUI();

      const prepared = await this.prepareAvatarUpload();

      if (!prepared.ok) {
        this.isSubmitting = false;
        this.syncEditingUI();
        this.showError(prepared.error);
        return;
      }

      this.pushEvent(
        "save_avatar_from_client",
        {
          avatar_data_url: prepared.dataUrl,
          filename: this.buildFilename(),
        },
        (reply) => {
          if (!reply?.ok) {
            this.isSubmitting = false;
            this.syncEditingUI();
            this.showError(
              reply?.error || "Profile picture could not be updated.",
            );
          }
        },
      );
    };

    this.form.addEventListener("submit", this.onSubmit);
  },

  bindModalDismiss() {
    this.modal = this.el.querySelector("[data-avatar-modal]");

    if (!this.modal) return;

    if (this.onModalClick) {
      this.modal.removeEventListener("click", this.onModalClick);
    }

    this.onModalClick = (event) => {
      if (event.target === this.modal) {
        this.resetInput();
      }
    };

    this.modal.addEventListener("click", this.onModalClick);
  },

  bindTriggers() {
    this.triggerButtons = this.el.querySelectorAll("[data-avatar-trigger]");
    this.resetButtons = this.el.querySelectorAll("[data-avatar-reset]");

    if (!this.onTriggerClick) {
      this.onTriggerClick = () => {
        this.closeMenu();
        this.localFileInput?.click();
      };
    }

    if (!this.onResetClick) {
      this.onResetClick = () => this.resetInput();
    }

    this.triggerButtons.forEach((button) => {
      button.removeEventListener("click", this.onTriggerClick);
      button.addEventListener("click", this.onTriggerClick);
    });

    this.resetButtons.forEach((button) => {
      button.removeEventListener("click", this.onResetClick);
      button.addEventListener("click", this.onResetClick);
    });
  },

  handleFileChange(event) {
    const [file] = Array.from(event.target.files || []);

    if (!file) {
      this.resetCropperState();
      this.hideError();
      this.syncPreview(this.el.dataset.previewImage || "");
      return;
    }

    if (!this.isAcceptedImageFile(file)) {
      this.showError("Please choose a JPG, PNG, or WebP image.");
      this.resetInput();
      return;
    }

    this.hideError();
    this.originalFile = file;
    this.originalFilename = file.name || "avatar";
    this.pendingUploadFile = null;
    this.normalizedPreviewSrc = "";
    this.hasCropChanges = false;
    this.isApplyingInitialCrop = false;
    this.startCropFlow(file);
  },

  startCropFlow(file) {
    this.destroyCropper();
    this.cleanupObjectUrls();

    const url = URL.createObjectURL(file);
    this.objectUrls.push(url);
    this.isEditing = true;
    this.zoomFactor = 1;
    this.closeMenu();
    this.cropperState?.classList.remove("hidden");
    this.modal?.classList.remove("hidden");
    this.syncEditingUI();
    this.cropperImage.src = url;

    this.cropperImage.onload = () => {
      this.destroyCropper();
      this.cropper = new Cropper(this.cropperImage);

      requestAnimationFrame(() => {
        this.bindCropperStage();
      });
    };
  },

  bindCropperStage() {
    if (!this.cropper) {
      return;
    }

    this.cropperCanvasEl = this.cropper.getCropperCanvas();
    this.cropperSelection = this.cropper.getCropperSelection();
    this.cropperImageEl = this.cropper.getCropperImage();

    if (
      !this.cropperSelection ||
      !this.cropperImageEl ||
      !this.cropperCanvasEl
    ) {
      this.showError("We couldn't open the image editor.");
      return;
    }

    this.cropperSelection.movable = false;
    this.cropperSelection.resizable = false;
    this.cropperSelection.zoomable = false;
    this.cropperSelection.keyboard = false;
    this.cropperSelection.outlined = false;
    this.cropperSelection.precise = true;
    this.cropperSelection.aspectRatio = 1;
    this.cropperSelection.initialAspectRatio = 1;

    const surface = this.el.querySelector("[data-avatar-crop-surface]");
    const frameSize = Math.round(
      Math.min(surface?.clientWidth || 0, surface?.clientHeight || 0) * 0.72,
    );
    const safeSize = Math.max(frameSize, 220);
    const x = Math.round(((surface?.clientWidth || safeSize) - safeSize) / 2);
    const y = Math.round(((surface?.clientHeight || safeSize) - safeSize) / 2);

    this.cropperSelection.$change(x, y, safeSize, safeSize, 1, true);

    this.cropperImageEl.$ready(() => {
      this.cropperImageEl?.$center("cover");
      this.zoomFactor = 1;
      this.syncZoomControls();
    });
  },

  applyZoomFactor(factor) {
    const clampedFactor = Math.max(1, Math.min(factor, 3));
    const delta = clampedFactor - (this.zoomFactor || 1);

    if (!this.cropperImageEl) {
      this.zoomFactor = clampedFactor;
      this.syncZoomControls();
      return;
    }

    if (Math.abs(delta) > 0.001) {
      this.cropperImageEl.$zoom(delta);
    }

    this.zoomFactor = clampedFactor;
    this.syncZoomControls();
  },

  nudgeZoom(step) {
    this.applyZoomFactor((this.zoomFactor || 1) + step);
  },

  syncZoomControls() {
    const disabled =
      !this.isEditing || !this.cropperImageEl || this.isSubmitting;

    if (this.zoomInButton) {
      this.zoomInButton.disabled = disabled;
      this.zoomInButton.classList.toggle("opacity-50", disabled);
    }

    if (this.zoomOutButton) {
      this.zoomOutButton.disabled = disabled;
      this.zoomOutButton.classList.toggle("opacity-50", disabled);
    }
  },

  async prepareAvatarUpload() {
    if (!this.cropperSelection) {
      return { ok: false, error: "Please choose an image first." };
    }

    try {
      const canvas = await this.cropperSelection.$toCanvas({
        width: 400,
        height: 400,
        beforeDraw: (context) => {
          context.imageSmoothingEnabled = true;
          context.imageSmoothingQuality = "high";
        },
      });

      const dataUrl = canvas.toDataURL("image/jpeg", 0.9);
      const blob = await new Promise((resolve) =>
        canvas.toBlob(resolve, "image/jpeg", 0.9),
      );

      if (!blob) {
        return {
          ok: false,
          error: "We couldn't prepare that image for upload.",
        };
      }

      this.pendingUploadFile = new File([blob], this.buildFilename(), {
        type: "image/jpeg",
      });
      this.normalizedPreviewSrc = dataUrl;

      return { ok: true, dataUrl };
    } catch (_error) {
      return {
        ok: false,
        error: "We couldn't prepare that image for upload.",
      };
    }
  },

  buildFilename() {
    const original = this.originalFilename || "avatar";
    return original.replace(/\.[^.]+$/, "") + "-avatar-400x400.jpg";
  },

  syncPreview(src) {
    if (this.previewImage) {
      if (src) {
        this.previewImage.src = src;
        this.previewImage.classList.remove("hidden");
      } else {
        this.previewImage.removeAttribute("src");
        this.previewImage.classList.add("hidden");
      }
    }

    if (this.previewFallback) {
      this.previewFallback.classList.toggle("hidden", Boolean(src));
    }
  },

  resetCropperState() {
    this.destroyCropper();
    this.cleanupObjectUrls();
    this.isEditing = false;
    this.baseZoomRatio = 1;
    this.zoomFactor = 1;
    this.cropperCanvasEl = null;
    this.cropperSelection = null;
    this.cropperImageEl = null;
    this.cropperState?.classList.add("hidden");
    this.syncEditingUI();
    this.modal?.classList.add("hidden");
    if (this.cropperImage) this.cropperImage.removeAttribute("src");
    if (this.croppedPreview) this.croppedPreview.removeAttribute("src");
  },

  resetInput() {
    if (this.localFileInput) {
      this.localFileInput.value = "";
    }
    if (this.uploadInput) {
      this.uploadInput.value = "";
    }
    this.pendingUploadFile = null;
    this.originalFile = null;
    this.originalFilename = "avatar";
    this.normalizedPreviewSrc = "";
    this.submitAfterPrepare = false;
    this.hasCropChanges = false;
    this.isApplyingInitialCrop = false;
    this.isSubmitting = false;
    this.resetCropperState();
    this.hideError();
    this.syncPreview(this.el.dataset.previewImage || "");
  },

  destroyCropper() {
    if (this.cropper) {
      this.cropper.destroy();
      this.cropper = null;
    }
  },

  cleanupObjectUrls() {
    this.objectUrls.forEach((url) => URL.revokeObjectURL(url));
    this.objectUrls = [];
  },

  setReady(isReady) {
    if (this.readyInput) {
      this.readyInput.value = isReady ? "true" : "false";
    }
  },

  syncEditingUI() {
    this.resetButtons = this.el.querySelectorAll("[data-avatar-reset]");
    this.resetButtons.forEach((button) => {
      button.classList.toggle("hidden", !this.isEditing);
    });

    if (this.saveButton) {
      this.saveButton.disabled = !this.isEditing;
      this.saveButton.classList.toggle("opacity-50", !this.isEditing);
    }

    if (this.floatingSaveButton) {
      const saveDisabled = !this.isEditing || this.isSubmitting;
      this.floatingSaveButton.disabled = saveDisabled;
      this.floatingSaveButton.classList.toggle("opacity-50", saveDisabled);
    }

    this.syncZoomControls();
  },

  isAcceptedImageFile(file) {
    if (!file) {
      return false;
    }

    if (file.type && file.type.startsWith("image/")) {
      return ["image/jpeg", "image/png", "image/webp"].includes(file.type);
    }

    const name = (file.name || "").toLowerCase();
    return [".jpg", ".jpeg", ".png", ".webp"].some((ext) => name.endsWith(ext));
  },

  showError(message) {
    if (this.errorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove("hidden");
    }

    if (this.inlineErrorTarget) {
      this.inlineErrorTarget.textContent = message;
      this.inlineErrorTarget.classList.remove("hidden");
    }
  },

  hideError() {
    if (this.errorTarget) {
      this.errorTarget.textContent = "";
      this.errorTarget.classList.add("hidden");
    }

    if (this.inlineErrorTarget) {
      this.inlineErrorTarget.textContent = "";
      this.inlineErrorTarget.classList.add("hidden");
    }
  },
};

Hooks.UploadPreview = {
  mounted() {
    this.objectUrls = [];
    this.previewContainer = this.el.querySelector("[data-upload-preview]");
    this.bindInput();
    this.renderPreviews();
  },

  updated() {
    this.bindInput();
    this.renderPreviews();
  },

  destroyed() {
    this.cleanupPreviews();
    if (this.fileInput && this.onChange) {
      this.fileInput.removeEventListener("change", this.onChange);
    }
  },

  bindInput() {
    const input = this.el.querySelector("input[type=file]");

    if (input === this.fileInput) {
      return;
    }

    if (this.fileInput && this.onChange) {
      this.fileInput.removeEventListener("change", this.onChange);
    }

    this.fileInput = input;

    if (!this.fileInput) {
      return;
    }

    this.onChange = () => this.renderPreviews();
    this.fileInput.addEventListener("change", this.onChange);
  },

  cleanupPreviews() {
    this.objectUrls.forEach((url) => URL.revokeObjectURL(url));
    this.objectUrls = [];

    if (this.previewContainer) {
      this.previewContainer.innerHTML = "";
    }
  },

  renderPreviews() {
    if (!this.previewContainer || !this.fileInput) {
      return;
    }

    const files = Array.from(this.fileInput.files || []);

    this.cleanupPreviews();

    files.forEach((file) => {
      const url = URL.createObjectURL(file);
      this.objectUrls.push(url);

      const card = document.createElement("div");
      card.className =
        "overflow-hidden rounded-2xl border border-stone-200 bg-white";

      if (file.type.startsWith("video/")) {
        const video = document.createElement("video");
        video.src = url;
        video.controls = true;
        video.muted = true;
        video.playsInline = true;
        video.className = "h-40 w-full object-cover";
        card.appendChild(video);
      } else if (file.type.startsWith("image/")) {
        const img = document.createElement("img");
        img.src = url;
        img.loading = "lazy";
        img.className = "h-40 w-full object-cover";
        card.appendChild(img);
      } else {
        const label = document.createElement("div");
        label.className = "p-3 text-xs font-semibold text-slate-700";
        label.textContent = file.name || "Selected file";
        card.appendChild(label);
      }

      this.previewContainer.appendChild(card);
    });
  },
};

Hooks.ScrollToBottom = {
  mounted() {
    this.chatKey = this.el.dataset.chatKey;
    this.wasNearBottom = true;
    this.scrollToBottom();
  },
  beforeUpdate() {
    this.wasNearBottom = this.isNearBottom();
  },
  updated() {
    const nextChatKey = this.el.dataset.chatKey;
    const changedChat = nextChatKey !== this.chatKey;

    this.chatKey = nextChatKey;

    if (changedChat || this.wasNearBottom) this.scrollToBottom();
  },
  isNearBottom() {
    const el = this.el;
    return el.scrollHeight - el.scrollTop - el.clientHeight < 200;
  },
  scrollToBottom() {
    requestAnimationFrame(() => {
      this.el.scrollTop = this.el.scrollHeight;
    });
  },
};

Hooks.ChatCompose = {
  mounted() {
    this.users = this.parseUsers();
    this.activeIndex = 0;
    this.matches = [];
    this.queryStart = null;
    // name -> user: tracks who was picked from the dropdown so we can
    // encode the token just before the form is submitted.
    this.mentionMap = new Map();
    this.typingTimer = null;
    this.lastTypingPush = 0;

    this.menu = document.createElement("ul");
    this.menu.className =
      "hidden fixed z-[1000] max-h-56 overflow-y-auto rounded-2xl border border-stone-200 bg-white py-1 text-sm shadow-xl";
    document.body.appendChild(this.menu);

    this.el.addEventListener("input", () => {
      this.handleMentionInput();
      this.pushTyping();
    });
    this.el.addEventListener("keydown", (e) => this.handleKeyDown(e));
    this.el.addEventListener("blur", () =>
      setTimeout(() => this.hideMentionMenu(), 120),
    );

    // Intercept form submit: swap display names back to tokens so the
    // server receives @[Name](user:ID) even though the textarea shows @Name.
    this.form = this.el.closest("form");
    if (this.form) {
      this.onSubmit = () => this.encodeMentions();
      this.form.addEventListener("submit", this.onSubmit);
    }
  },

  updated() {
    this.users = this.parseUsers();
    if (
      Object.prototype.hasOwnProperty.call(this.el.dataset, "draftValue") &&
      this.el.value !== this.el.dataset.draftValue
    ) {
      this.el.value = this.el.dataset.draftValue;
    }
  },

  destroyed() {
    this.menu && this.menu.remove();
    if (this.form && this.onSubmit) {
      this.form.removeEventListener("submit", this.onSubmit);
    }
    clearTimeout(this.typingTimer);
  },

  pushTyping() {
    const now = Date.now();

    if (now - this.lastTypingPush > 1200) {
      this.pushEvent("typing", { typing: true });
      this.lastTypingPush = now;
    }

    clearTimeout(this.typingTimer);
    this.typingTimer = setTimeout(() => {
      this.pushEvent("typing", { typing: false });
    }, 1800);
  },

  parseUsers() {
    try {
      return JSON.parse(this.el.dataset.mentionUsers || "[]");
    } catch (_) {
      return [];
    }
  },

  // Replace display-only "@Name" text with "@[Name](user:ID)" tokens.
  encodeMentions() {
    if (this.mentionMap.size === 0) return;
    let body = this.el.value;
    this.mentionMap.forEach((user, name) => {
      if (body.includes(`@${name}`)) {
        body = body.replaceAll(`@${name}`, `@[${name}](user:${user.id})`);
      }
    });
    this.el.value = body;
    this.mentionMap.clear();
  },

  handleKeyDown(e) {
    if (!this.menu.classList.contains("hidden")) {
      switch (e.key) {
        case "ArrowDown":
          e.preventDefault();
          this.activeIndex = (this.activeIndex + 1) % this.matches.length;
          this.renderMentionMenu();
          return;
        case "ArrowUp":
          e.preventDefault();
          this.activeIndex =
            (this.activeIndex - 1 + this.matches.length) % this.matches.length;
          this.renderMentionMenu();
          return;
        case "Enter":
        case "Tab":
          e.preventDefault();
          this.selectMention(this.matches[this.activeIndex]);
          return;
        case "Escape":
          e.preventDefault();
          this.hideMentionMenu();
          return;
      }
    }

    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      const form = this.el.closest("form");
      const fileInput = form && form.querySelector("input[type=file]");
      const hasFiles =
        fileInput && fileInput.files && fileInput.files.length > 0;
      if (form && (this.el.value.trim() || hasFiles)) {
        form.dispatchEvent(
          new Event("submit", { bubbles: true, cancelable: true }),
        );
      }
    }
  },

  handleMentionInput() {
    const caret = this.el.selectionStart;
    const before = this.el.value.slice(0, caret);
    const match = before.match(/@([\p{L}\p{N}._-]*)$/u);

    if (!match) {
      this.hideMentionMenu();
      return;
    }

    const query = match[1].toLowerCase();
    this.queryStart = caret - match[0].length;
    this.matches = this.users
      .filter((u) => {
        const name = (u.name || "").toLowerCase();
        return name.includes(query) || (u.id === "all" && "all".includes(query));
      })
      .slice(0, 6);

    if (this.matches.length === 0) {
      this.hideMentionMenu();
      return;
    }

    this.activeIndex = 0;
    this.renderMentionMenu();
  },

  // Insert display text "@Name " and track the user in mentionMap.
  selectMention(user) {
    if (!user) return;
    const value = this.el.value;
    const caret = this.el.selectionStart;
    const displayName = user.id === "all" ? "all" : user.name;
    const display = `@${displayName} `;
    const next = value.slice(0, this.queryStart) + display + value.slice(caret);
    const cursor = this.queryStart + display.length;

    if (user.id !== "all") {
      this.mentionMap.set(user.name, user);
    }
    this.el.value = next;
    this.el.setSelectionRange(cursor, cursor);
    this.el.dispatchEvent(new Event("input", { bubbles: true }));
    this.hideMentionMenu();
    this.el.focus();
  },

  renderMentionMenu() {
    this.menu.innerHTML = "";
    this.matches.forEach((user, index) => {
      const item = document.createElement("li");
      item.textContent =
        user.id === "all" ? "Everyone (@all)" : user.name;
      item.className =
        "cursor-pointer px-3 py-2 " +
        (index === this.activeIndex
          ? "bg-stone-100 text-slate-900"
          : "text-slate-600");
      item.addEventListener("mousedown", (e) => {
        e.preventDefault();
        this.selectMention(user);
      });
      this.menu.appendChild(item);
    });

    const rect = this.el.getBoundingClientRect();
    this.menu.classList.remove("hidden");
    const menuHeight = this.menu.offsetHeight;
    // Show above the input so it never overlaps the send button area.
    this.menu.style.top = `${rect.top - menuHeight - 4}px`;
    this.menu.style.left = `${rect.left}px`;
    this.menu.style.width = `${Math.min(rect.width, 320)}px`;
  },

  hideMentionMenu() {
    this.matches = [];
    this.queryStart = null;
    this.menu.classList.add("hidden");
  },
};

Hooks.AptitudeProctoring = AptitudeProctoring;
Hooks.MeetingRecorder = MeetingRecorder;
Hooks.MentionInput = MentionInput;
Hooks.FormatToolbar = FormatToolbar;

window.addEventListener("phx:download:file", (event) => {
  const { filename, content, content_type } = event.detail || {};

  if (!filename || typeof content !== "string") {
    return;
  }

  const blob = new Blob([content], {
    type: content_type || "text/plain;charset=utf-8",
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");

  link.href = url;
  link.download = filename;
  link.style.display = "none";

  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  window.setTimeout(() => URL.revokeObjectURL(url), 0);
});

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#171717" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// Chat notifications: play a chime and badge the favicon whenever a new
// message/mention arrives for the current user, on any page in the app.
// The tab title badge is handled server-side via <.live_title prefix=...>.
let chatNotificationAudioContext = null;

function playChatNotificationSound() {
  try {
    chatNotificationAudioContext ||= new (
      window.AudioContext || window.webkitAudioContext
    )();

    const ctx = chatNotificationAudioContext;
    if (ctx.state === "suspended") ctx.resume();

    const now = ctx.currentTime;
    [
      { freq: 880, start: 0 },
      { freq: 1108, start: 0.09 },
    ].forEach(({ freq, start }) => {
      const oscillator = ctx.createOscillator();
      const gain = ctx.createGain();

      oscillator.type = "sine";
      oscillator.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, now + start);
      gain.gain.exponentialRampToValueAtTime(0.18, now + start + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + start + 0.28);

      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.start(now + start);
      oscillator.stop(now + start + 0.3);
    });
  } catch (_error) {
    // Web Audio isn't available/allowed yet (e.g. no user gesture) - skip the chime.
  }
}

const faviconBadge = {
  link: document.getElementById("app-favicon"),
  baseImage: null,
  baseHref: null,

  update(count) {
    if (!this.link) return;

    this.baseHref ||= this.link.href;

    if (!count) {
      this.link.href = this.baseHref;
      return;
    }

    if (this.baseImage) {
      this.render(count);
      return;
    }

    const image = new Image();
    image.onload = () => {
      this.baseImage = image;
      this.render(count);
    };
    image.src = this.baseHref;
  },

  render(count) {
    const size = 64;
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const context = canvas.getContext("2d");

    context.drawImage(this.baseImage, 0, 0, size, size);

    const radius = size * 0.28;
    const cx = size - radius - 2;
    const cy = radius + 2;

    context.beginPath();
    context.arc(cx, cy, radius, 0, 2 * Math.PI);
    context.fillStyle = "#e11d48";
    context.fill();

    context.fillStyle = "#ffffff";
    context.font = `${radius}px system-ui, sans-serif`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.fillText(count > 9 ? "9+" : String(count), cx, cy + 1);

    this.link.href = canvas.toDataURL("image/png");
  },
};

window.addEventListener("phx:chat:notify", (event) => {
  if (!event.detail.initial) playChatNotificationSound();
  faviconBadge.update(event.detail.unread_count);
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
