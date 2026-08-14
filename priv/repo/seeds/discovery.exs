# Seeds the discovery question bank (departments → modules → questions) from
# priv/discovery/question_bank.json.
#
#     mix run priv/repo/seeds/discovery.exs
#
# Idempotent: re-running upserts the bank and leaves captured answers alone.
# Regenerate the JSON from the prototype with:
#
#     node scripts/extract_discovery_bank.mjs

alias BetaSigma.Discovery

Discovery.seed_question_bank!()

departments = Discovery.list_departments()

IO.puts("Seeded #{length(departments)} discovery departments:")

Enum.each(departments, fn department ->
  IO.puts("  #{department.scope}/#{department.slug} — #{Discovery.question_count(department)} questions")
end)
