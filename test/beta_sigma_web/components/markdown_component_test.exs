defmodule BetaSigmaWeb.MarkdownComponentTest do
  use BetaSigmaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders inline bold markers inside markdown blocks" do
    html =
      render_component(&BetaSigmaWeb.MarkdownComponent.markdown_viewer/1,
        body: """
        Comprehensive ERP Solution for Orbit TV

        - **Finance Management**: Modules for requisitions.
        """
      )

    assert html =~ "Comprehensive ERP Solution for Orbit TV"
    assert html =~ "<strong>Finance Management</strong>"
    assert html =~ "Modules for requisitions."
  end
end
