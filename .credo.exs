%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/priv/repo/migrations/"
        ]
      },
      strict: false,
      parse_timeout: 5_000,
      color: true,
      checks: []
    }
  ]
}
