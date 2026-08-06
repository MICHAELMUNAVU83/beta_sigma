defmodule BetaSigmaWeb.UserSettingsLive do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Accounts
  alias BetaSigma.Uploads

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl space-y-6">
      <section class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 class="text-2xl font-semibold tracking-tight text-n100">Account settings</h2>
          <p class="mt-1 text-sm text-n600">
            Signed in as {display_name(@current_user)} · {@current_email} · {humanize(
              @current_user.role
            )} access
          </p>
        </div>
      </section>

      <section class="grid gap-4 md:grid-cols-3">
        <article class="rounded-lg border border-white/10 bg-ink p-4">
          <p class="text-sm font-medium text-n600">
            Current email
          </p>
          <p class="mt-1 text-base font-semibold text-n100 break-all">
            {@current_email}
          </p>
        </article>
        <article class="rounded-lg border border-white/10 bg-ink p-4">
          <p class="text-sm font-medium text-n600">
            Access level
          </p>
          <p class="mt-1 text-2xl font-semibold text-n100">
            {humanize(@current_user.role)}
          </p>
        </article>
        <article class="rounded-lg border border-white/10 bg-ink p-4">
          <p class="text-sm font-medium text-n600">
            Security check
          </p>
          <p class="mt-1 text-base font-semibold text-n100">
            Current password required
          </p>
          <p class="mt-2 text-sm text-n600 leading-6">
            Both account changes verify your existing credentials before they are applied.
          </p>
        </article>
      </section>

      <div class="grid gap-6">
        <div class="space-y-6">
          <section class="rounded-lg border border-white/10 bg-ink p-4 sm:p-5">
            <h3 class="text-center text-sm font-semibold text-n100">Profile picture</h3>
            <p class="mt-1 text-center text-sm text-n600">
              Update your avatar to personalize your account across the workspace.
            </p>

            <form
              id="avatar-form"
              phx-submit="save_avatar"
              phx-change="validate_avatar"
              phx-hook="AvatarCropUpload"
              data-preview-image={@current_user.avatar_url || ""}
              data-preview-fallback={
                display_name(@current_user) |> String.slice(0, 1) |> String.upcase()
              }
              class="mx-auto mt-4 flex w-full max-w-sm flex-col gap-4"
            >
              <div class="flex flex-col items-center gap-3">
                <div class="relative">
                  <div class="relative flex h-36 w-36 items-center justify-center overflow-hidden rounded-full bg-white/10 text-4xl font-semibold text-n600 ring-2 ring-white/10">
                    <img
                      data-avatar-preview-image
                      src={@current_user.avatar_url || ""}
                      alt="Avatar preview"
                      class={[
                        "h-full w-full object-cover",
                        if(@current_user.avatar_url, do: "", else: "hidden")
                      ]}
                    />
                    <span data-avatar-preview-fallback class={[@current_user.avatar_url && "hidden"]}>
                      {display_name(@current_user) |> String.slice(0, 1) |> String.upcase()}
                    </span>
                  </div>

                  <div class="absolute bottom-1 right-1 z-20">
                    <div class="relative">
                      <button
                        type="button"
                        data-avatar-menu-toggle
                        class="inline-flex h-11 w-11 items-center justify-center rounded-full bg-accent text-white shadow-lg transition hover:bg-accentDeep focus:outline-none focus:ring-2 focus:ring-accent/30"
                        aria-label="Profile photo actions"
                      >
                        <.icon name="hero-camera" class="h-5 w-5" />
                      </button>

                      <div
                        data-avatar-menu
                        class="pointer-events-none absolute right-0 top-[calc(100%+0.35rem)] z-20 min-w-[10rem] origin-top-right overflow-hidden rounded-xl border border-white/10 bg-ink py-1 text-left opacity-0 shadow-xl shadow-black/30 transition duration-150 ease-out translate-y-1 scale-95 invisible"
                      >
                        <button
                          type="button"
                          data-avatar-trigger
                          class="flex w-full items-center gap-2 px-3 py-2 text-sm font-medium text-n600 transition hover:bg-white/5 hover:text-n100"
                        >
                          <.icon name="hero-pencil-square" class="h-4 w-4" /> Edit
                        </button>

                        <button
                          :if={@current_user.avatar_url}
                          type="button"
                          phx-click="remove_avatar"
                          data-avatar-delete
                          class="flex w-full items-center gap-2 px-3 py-2 text-sm font-medium text-red-400 transition hover:bg-red-500/10"
                        >
                          <.icon name="hero-trash" class="h-4 w-4" /> Delete profile
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="space-y-1 text-center">
                  <p class="text-sm font-medium text-n100">Profile photo</p>
                </div>

                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  class="sr-only"
                  data-avatar-local-input
                />

                <div class="sr-only" phx-drop-target={@uploads.avatar.ref}>
                  <.live_file_input
                    upload={@uploads.avatar}
                    accept="image/jpeg,image/png,image/webp"
                    data-avatar-upload-input
                  />
                </div>
              </div>

              <div class="space-y-1 text-center">
                <p :for={err <- upload_errors(@uploads.avatar)} class="text-sm text-red-400">
                  {error_to_string(err)}
                </p>
                <p :for={entry <- @uploads.avatar.entries} class="hidden">
                  {entry.client_name}
                </p>
                <p class="hidden text-sm text-red-400" data-avatar-inline-error></p>
              </div>

              <div
                id="avatar-crop-modal"
                class="fixed inset-0 z-50 hidden overflow-y-auto bg-black/60 backdrop-blur-[2px]"
                data-avatar-modal
              >
                <div class="flex min-h-full items-center justify-center p-4 sm:p-6">
                  <div class="w-full max-w-[26rem] rounded-[24px] border border-white/10 bg-ink shadow-2xl shadow-black/40">
                    <div
                      id="avatar-cropper-state"
                      phx-update="ignore"
                      data-avatar-cropper-state
                      class="hidden"
                    >
                      <div class="relative flex items-center justify-center border-b border-white/10 px-4 py-2.5">
                        <button
                          type="button"
                          data-avatar-reset
                          class="absolute left-3 top-1/2 inline-flex h-9 w-9 -translate-y-1/2 items-center justify-center rounded-full text-n600 transition hover:bg-white/10 hover:text-n100"
                          aria-label="Close avatar editor"
                        >
                          <.icon name="hero-x-mark" class="h-5 w-5" />
                        </button>

                        <p class="truncate px-10 text-center text-sm font-semibold text-n100">
                          Drag the image to adjust
                        </p>
                      </div>

                      <div class="px-4 pb-3 pt-4">
                        <div class="relative mx-auto w-full max-w-[22rem]">
                          <div
                            data-avatar-crop-surface
                            class="relative h-[22rem] w-full overflow-hidden rounded-[18px] bg-n800 shadow-inner shadow-black/30"
                          >
                            <img
                              data-avatar-cropper-image
                              alt="Avatar crop area"
                              class="block h-full w-full object-contain"
                            />
                          </div>

                          <div class="pointer-events-none absolute inset-y-0 right-0 z-10 flex items-center pr-2.5">
                            <div class="pointer-events-auto flex flex-col items-center gap-2 rounded-[20px] border border-white/10 bg-ink/95 px-2 py-2.5 shadow-lg shadow-black/30 backdrop-blur">
                              <button
                                type="button"
                                data-avatar-zoom-in
                                class="inline-flex h-8 w-8 items-center justify-center rounded-full text-n600 transition hover:bg-white/10 hover:text-n100"
                                aria-label="Zoom in"
                              >
                                <.icon name="hero-plus" class="h-4 w-4" />
                              </button>

                              <button
                                type="button"
                                data-avatar-zoom-out
                                class="inline-flex h-8 w-8 items-center justify-center rounded-full text-n600 transition hover:bg-white/10 hover:text-n100"
                                aria-label="Zoom out"
                              >
                                <.icon name="hero-minus" class="h-4 w-4" />
                              </button>
                            </div>
                          </div>
                        </div>

                        <p class="mt-2 hidden text-center text-sm text-red-400" data-avatar-error></p>
                      </div>

                      <div class="flex items-center justify-end border-t border-white/10 bg-white/5 px-4 pb-4 pt-3">
                        <button
                          type="submit"
                          data-avatar-save-floating
                          class="inline-flex h-12 w-12 items-center justify-center rounded-full bg-accent text-white shadow-lg shadow-accent/25 transition hover:scale-[1.02] hover:bg-accentDeep disabled:cursor-not-allowed disabled:opacity-50"
                          aria-label="Save profile photo"
                        >
                          <.icon name="hero-check" class="h-6 w-6" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div
                id="avatar-view-modal"
                class="fixed inset-0 z-50 hidden overflow-y-auto bg-black/60 backdrop-blur-sm"
                data-avatar-view-modal
              >
                <div class="flex min-h-full items-center justify-center p-4 sm:p-6">
                  <div class="w-full max-w-2xl rounded-lg border border-white/10 bg-ink shadow-2xl">
                    <div class="flex items-center justify-between border-b border-white/10 px-4 py-3 text-n100 sm:px-5">
                      <p class="text-sm font-semibold text-n100">Profile photo</p>
                      <button
                        type="button"
                        data-avatar-view-close
                        class="inline-flex items-center gap-2 rounded-md border border-white/10 bg-transparent px-3 py-1.5 text-sm font-medium text-n100 transition hover:bg-white/5"
                      >
                        <.icon name="hero-x-mark" class="h-4 w-4" /> Close
                      </button>
                    </div>

                    <div class="bg-white/5 p-4 sm:p-5">
                      <div class="mx-auto flex h-[400px] w-[400px] max-w-full items-center justify-center overflow-hidden rounded-lg bg-n800">
                        <img
                          data-avatar-view-image
                          src={@current_user.avatar_url || ""}
                          alt="Full profile photo"
                          class="block h-full w-full object-contain"
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </form>
          </section>

          <section class="rounded-lg border border-white/10 bg-ink p-4">
            <h3 class="text-sm font-semibold text-n100">Update email address</h3>
            <p class="mt-1 text-sm text-n600">
              Change the address used for sign-in and notifications. A confirmation link will be sent to the new inbox before the update is finalized.
            </p>

            <div class="mt-6 rounded-lg border border-white/10 bg-white/5 p-4">
              <p class="text-sm font-medium text-n600">
                Current address on file
              </p>
              <p class="mt-1 text-base font-semibold text-n100 break-all">{@current_email}</p>
            </div>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
              class="mt-6 space-y-6"
            >
              <div class="grid gap-6 md:grid-cols-2">
                <.input field={@email_form[:email]} type="email" label="New email" required />
                <.input
                  field={@email_form[:current_password]}
                  name="current_password"
                  id="current_password_for_email"
                  type="password"
                  label="Current password"
                  value={@email_form_current_password}
                  required
                />
              </div>

              <div class="flex flex-col gap-4 border-t border-white/10 pt-5 sm:flex-row sm:items-center sm:justify-between">
                <p class="text-sm text-n600 leading-6">
                  You will keep using your current email until the confirmation link is opened.
                </p>

                <.button type="submit" phx-disable-with="Saving...">
                  Change email
                </.button>
              </div>
            </.form>
          </section>

          <section class="rounded-lg border border-white/10 bg-ink p-4">
            <h3 class="text-sm font-semibold text-n100">Update password</h3>
            <p class="mt-1 text-sm text-n600">
              Set a new password for this account. The password update posts back through the authenticated flow once the change succeeds.
            </p>

            <.form
              for={@password_form}
              id="password_form"
              action={~p"/users/log_in?_action=password_updated"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
              class="mt-6 space-y-6"
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                value={@current_email}
              />

              <div class="grid gap-6 md:grid-cols-2">
                <.input
                  field={@password_form[:password]}
                  type="password"
                  label="New password"
                  required
                />
                <.input
                  field={@password_form[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                />
              </div>

              <.input
                field={@password_form[:current_password]}
                name="current_password"
                type="password"
                label="Current password"
                id="current_password_for_password"
                value={@current_password}
                required
              />

              <div class="rounded-lg border border-white/10 bg-white/5 p-4">
                <p class="text-sm font-medium text-n600">
                  Password guidance
                </p>
                <p class="mt-1 text-sm text-n600 leading-6">
                  Use a unique password for this workspace. You will be asked to sign in again after the update completes.
                </p>
              </div>

              <div class="flex flex-col gap-4 border-t border-white/10 pt-5 sm:flex-row sm:items-center sm:justify-between">
                <p class="text-sm text-n600 leading-6">
                  Keep your current password nearby so the change can be verified.
                </p>

                <.button type="submit" phx-disable-with="Saving...">
                  Change password
                </.button>
              </div>
            </.form>
          </section>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:page_title, "Account Settings")
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> allow_upload(:avatar,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 5_000_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  def handle_event("validate_avatar", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  def handle_event("remove_avatar", _params, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user_avatar_url(user, nil) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> put_flash(:info, "Profile picture removed.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Profile picture could not be removed.")}
    end
  end

  def handle_event("save_avatar", _params, socket) do
    user = socket.assigns.current_user

    socket =
      case consume_uploaded_entries(socket, :avatar, &process_avatar_upload(user, &1, &2)) do
        [updated_user] when is_map(updated_user) ->
          socket
          |> assign(:current_user, updated_user)
          |> put_flash(:info, "Profile picture updated.")

        [{:error, _reason}] ->
          put_flash(socket, :error, "The selected image could not be processed.")

        _other ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "save_avatar_from_client",
        %{"avatar_data_url" => data_url, "filename" => filename},
        socket
      ) do
    user = socket.assigns.current_user

    case persist_client_avatar(user, data_url, filename) do
      {:ok, updated_user} ->
        {:reply, %{ok: true},
         socket
         |> assign(:current_user, updated_user)
         |> put_flash(:info, "Profile picture updated.")}

      {:error, message} ->
        {:reply, %{ok: false, error: message}, socket}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  defp process_avatar_upload(user, %{path: path}, entry) do
    with {:ok, _meta} <- Uploads.validate_avatar_upload(path, entry.client_type),
         url <- Uploads.persist_upload!("avatars", %{path: path}, entry.client_name),
         {:ok, updated_user} <- Accounts.update_user_avatar_url(user, url) do
      {:ok, updated_user}
    else
      {:error, reason} -> {:ok, {:error, reason}}
    end
  end

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp persist_client_avatar(user, data_url, filename) do
    with {:ok, binary, extension, content_type} <- decode_client_avatar_data(data_url),
         :ok <- validate_client_avatar_binary(binary, extension, content_type),
         url <-
           Uploads.persist_binary!(
             "avatars",
             binary,
             extension,
             Path.rootname(filename || "avatar")
           ),
         {:ok, updated_user} <- Accounts.update_user_avatar_url(user, url) do
      {:ok, updated_user}
    else
      {:error, :invalid_data_url} ->
        {:error, "The selected image could not be processed."}

      {:error, :invalid_image_type} ->
        {:error, "Please choose a JPG, PNG, or WebP image."}

      {:error, :image_too_small} ->
        {:error, "The selected image is too small for a profile picture."}

      {:error, _reason} ->
        {:error, "Profile picture could not be updated."}
    end
  end

  defp decode_client_avatar_data("data:" <> rest) do
    with [header, encoded] <- String.split(rest, ",", parts: 2),
         [content_type | ["base64"]] <- String.split(header, ";"),
         true <- content_type in ["image/jpeg", "image/png", "image/webp"],
         {:ok, binary} <- Base.decode64(encoded) do
      {:ok, binary, content_type_to_extension(content_type), content_type}
    else
      _ -> {:error, :invalid_data_url}
    end
  end

  defp decode_client_avatar_data(_), do: {:error, :invalid_data_url}

  defp validate_client_avatar_binary(binary, extension, content_type) do
    temp_path = Path.join(System.tmp_dir!(), "avatar-#{Ecto.UUID.generate()}.#{extension}")

    try do
      File.write!(temp_path, binary)

      case Uploads.validate_avatar_upload(temp_path, content_type) do
        {:ok, _meta} -> :ok
        {:error, reason} -> {:error, reason}
      end
    after
      File.rm(temp_path)
    end
  end

  defp content_type_to_extension("image/jpeg"), do: "jpg"
  defp content_type_to_extension("image/png"), do: "png"
  defp content_type_to_extension("image/webp"), do: "webp"

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "Only JPG, PNG, and WebP images are allowed"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
end
