defmodule BetaSigmaWeb.MarketingComponents do
  @moduledoc """
  Shared header/footer chrome for the public BeCorp marketing site
  (home, about, contact).
  """
  use BetaSigmaWeb, :html

  attr :active, :atom, default: nil, values: [nil, :home, :about, :contact]

  def marketing_header(assigns) do
    ~H"""
    <header class="sticky top-0 z-50 border-b border-white/5 bg-ink/95 backdrop-blur">
      <div class="mx-auto w-full max-w-[1290px] px-5">
        <div class="flex items-center justify-between py-6">
          <.link navigate={~p"/"} class="flex items-center gap-3">
            <img
              src={~p"/images/becorp-logo.png"}
              alt="BΣ Corporation"
              class="h-11 w-auto"
              decoding="async"
            />
          </.link>

          <div class="flex items-center gap-6">
            <.link
              navigate={~p"/app/projects"}
              class="flex items-center gap-2 text-base text-n100 transition-colors hover:text-accent"
            >
              <span>Dashboard</span>
            </.link>

            <input type="checkbox" id="nav-toggle" class="peer hidden" />
            <label
              for="nav-toggle"
              aria-label="Toggle navigation menu"
              class="relative z-50 flex h-10 w-10 cursor-pointer flex-col items-center justify-center gap-[7px] peer-checked:[&>span:first-child]:translate-y-[4.5px] peer-checked:[&>span:first-child]:rotate-45 peer-checked:[&>span:last-child]:-translate-y-[4.5px] peer-checked:[&>span:last-child]:-rotate-45"
            >
              <span class="block h-[2px] w-7 bg-n100 transition-transform duration-300"></span>
              <span class="block h-[2px] w-7 bg-n100 transition-transform duration-300"></span>
            </label>

            <nav
              class="fixed inset-x-0 top-[89px] hidden max-h-[calc(100vh-89px)] overflow-y-auto border-t border-white/10 bg-ink px-5 pb-20 pt-12 peer-checked:block"
              aria-label="Main navigation"
            >
              <div class="mx-auto w-full max-w-[1290px]">
                <div class="mb-6 text-2xl font-bold text-n100">Pages</div>
                <ul class="space-y-2">
                  <li>
                    <.link
                      navigate={~p"/"}
                      class={["text-[22px] hover:text-accent", @active == :home && "text-accent", @active != :home && "text-n100"]}
                      aria-current={@active == :home && "page"}
                    >
                      Home
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/about"}
                      class={["text-[22px] hover:text-accent", @active == :about && "text-accent", @active != :about && "text-n100"]}
                      aria-current={@active == :about && "page"}
                    >
                      About
                    </.link>
                  </li>
                  <li>
                    <.link
                      navigate={~p"/contact"}
                      class={["text-[22px] hover:text-accent", @active == :contact && "text-accent", @active != :contact && "text-n100"]}
                      aria-current={@active == :contact && "page"}
                    >
                      Contact
                    </.link>
                  </li>
                </ul>
              </div>
            </nav>
          </div>
        </div>
      </div>
    </header>
    """
  end

  attr :active, :atom, default: nil, values: [nil, :home, :about, :contact]

  def marketing_footer(assigns) do
    ~H"""
    <footer class="relative overflow-hidden border-t border-n600/40">
      <img
        src="https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=1400&q=80"
        alt=""
        loading="lazy"
        aria-hidden="true"
        class="pointer-events-none absolute -bottom-32 right-0 w-[750px] max-w-full opacity-30"
      />
      <div class="pointer-events-none absolute inset-0 bg-gradient-to-t from-ink via-ink/70 to-ink/95"></div>

      <div class="relative mx-auto w-full max-w-[1290px] px-5">
        <div class="flex flex-col gap-10 border-b border-n600/40 py-16 md:flex-row md:items-center md:justify-between">
          <.link navigate={~p"/"} class="flex shrink-0 items-center gap-3">
            <img
              src={~p"/images/becorp-logo.png"}
              alt="BΣ Corporation"
              class="h-16 w-auto"
              decoding="async"
            />
          </.link>
          <p class="max-w-[534px] text-[18px] leading-[1.667]">
            BeCorp builds, scales and manages high-growth businesses across
            entertainment, agriculture, real estate and
            <span class="whitespace-nowrap">professional services.</span>
          </p>
        </div>

        <div class="grid gap-16 py-16 lg:grid-cols-[320px_auto]">
          <div>
            <div class="mb-10 text-xl font-bold text-n100">Pages</div>
            <ul class="space-y-7">
              <li>
                <.link
                  navigate={~p"/"}
                  class={if @active == :home, do: "text-accent", else: "hover:text-n100"}
                >
                  Home
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/about"}
                  class={if @active == :about, do: "text-accent", else: "hover:text-n100"}
                >
                  About
                </.link>
              </li>
              <li>
                <.link
                  navigate={~p"/contact"}
                  class={if @active == :contact, do: "text-accent", else: "hover:text-n100"}
                >
                  Contact
                </.link>
              </li>
            </ul>
          </div>

          <div class="w-full max-w-[522px]">
            <div class="mb-6 text-xl font-bold text-n100">Subscribe to our newsletter</div>
            <form class="relative" method="get" action="#">
              <label for="footer-email" class="sr-only">Email address</label>
              <input
                id="footer-email"
                name="email"
                type="email"
                required
                placeholder="Enter your email address"
                class="w-full border-b border-n600 bg-transparent py-4 pr-40 text-n100 placeholder:text-n600 focus:border-accent focus:outline-none"
              />
              <button
                type="submit"
                class="group absolute right-0 top-1/2 flex -translate-y-1/2 items-center gap-2 border-b border-n100 pb-1 text-lg font-semibold text-n100 transition-colors hover:border-accent hover:text-accent"
              >
                Subscribe
                <svg
                  class="h-5 w-5 shrink-0 transition-transform duration-200 group-hover:translate-x-1"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  aria-hidden="true"
                >
                  <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
                </svg>
              </button>
            </form>
          </div>
        </div>

        <div class="flex flex-col items-center gap-8 border-t border-n600/40 py-10 text-center md:flex-row md:justify-between md:text-left">
          <p class="text-n100">
            Copyright © BeCorp — Designed by
            <a
              href="https://michaelmunavu.com/"
              target="_blank"
              rel="noopener"
              class="underline hover:text-accent"
            >
              Michael Munavu
            </a>
          </p>
          <div class="flex items-center gap-6">
            <a href="https://facebook.com/" target="_blank" rel="noopener" class="text-n100 hover:text-accent" aria-label="Facebook">
              <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M18 2h-3a5 5 0 00-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 011-1h3z" />
              </svg>
            </a>
            <a href="https://twitter.com/" target="_blank" rel="noopener" class="text-n100 hover:text-accent" aria-label="Twitter">
              <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M23 3a10.9 10.9 0 01-3.14 1.53 4.48 4.48 0 00-7.86 3v1A10.66 10.66 0 013 4s-4 9 5 13a11.64 11.64 0 01-7 2c9 5 20 0 20-11.5a4.5 4.5 0 00-.08-.83A7.72 7.72 0 0023 3z" />
              </svg>
            </a>
            <a href="https://www.instagram.com/" target="_blank" rel="noopener" class="text-n100 hover:text-accent" aria-label="Instagram">
              <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <rect x="2" y="2" width="20" height="20" rx="5" /><path d="M16 11.37A4 4 0 1112.63 8 4 4 0 0116 11.37z" /><line x1="17.5" y1="6.5" x2="17.51" y2="6.5" />
              </svg>
            </a>
            <a href="https://www.linkedin.com/" target="_blank" rel="noopener" class="text-n100 hover:text-accent" aria-label="LinkedIn">
              <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M16 8a6 6 0 016 6v7h-4v-7a2 2 0 00-4 0v7h-4v-7a6 6 0 016-6z" /><rect x="2" y="9" width="4" height="12" /><circle cx="4" cy="4" r="2" />
              </svg>
            </a>
            <a href="http://youtube.com/" target="_blank" rel="noopener" class="text-n100 hover:text-accent" aria-label="YouTube">
              <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M22.54 6.42a2.78 2.78 0 00-1.94-2C18.88 4 12 4 12 4s-6.88 0-8.6.46a2.78 2.78 0 00-1.94 2A29 29 0 001 11.75a29 29 0 00.46 5.33A2.78 2.78 0 003.4 19c1.72.46 8.6.46 8.6.46s6.88 0 8.6-.46a2.78 2.78 0 001.94-2 29 29 0 00.46-5.25 29 29 0 00-.46-5.33z" />
                <polygon points="9.75 15.02 15.5 11.75 9.75 8.48 9.75 15.02" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
