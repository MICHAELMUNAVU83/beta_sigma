#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
SOURCE_DIR = File.join(ROOT, "docs", "project-docs")
OUTPUT_DIR = File.join(SOURCE_DIR, "html")

def inline(text)
  escaped = CGI.escapeHTML(text)
  escaped = escaped.gsub(/`([^`]+)`/, '<code>\1</code>')
  escaped = escaped.gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
  escaped.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do
    label = Regexp.last_match(1)
    href = CGI.escapeHTML(Regexp.last_match(2))
    href = href.sub(/\.md\z/, ".html")
    href = href.sub(/\Ahtml\//, "")
    %(<a href="#{href}">#{label}</a>)
  end
end

def render_markdown(markdown)
  lines = markdown.lines
  html = []
  paragraph = []
  list_type = nil
  in_code = false
  code = []
  table = []

  flush_paragraph = lambda do
    unless paragraph.empty?
      html << "<p>#{inline(paragraph.join(" ").strip)}</p>"
      paragraph.clear
    end
  end

  close_list = lambda do
    if list_type
      html << "</#{list_type}>"
      list_type = nil
    end
  end

  flush_table = lambda do
    next if table.empty?

    rows = table.map { |line| line.strip.sub(/^\|/, "").sub(/\|$/, "").split("|").map(&:strip) }
    if rows.length > 1 && rows[1].all? { |cell| cell.match?(/\A:?-{3,}:?\z/) }
      header = rows.shift
      rows.shift
      html << "<div class=\"table-wrap\"><table><thead><tr>"
      header.each { |cell| html << "<th>#{inline(cell)}</th>" }
      html << "</tr></thead><tbody>"
      rows.each do |row|
        html << "<tr>"
        row.each { |cell| html << "<td>#{inline(cell)}</td>" }
        html << "</tr>"
      end
      html << "</tbody></table></div>"
    else
      table.each { |line| html << "<p>#{inline(line.strip)}</p>" }
    end
    table.clear
  end

  lines.each do |raw|
    line = raw.chomp

    if line.start_with?("```")
      flush_paragraph.call
      close_list.call
      flush_table.call
      if in_code
        html << "<pre><code>#{CGI.escapeHTML(code.join("\n"))}</code></pre>"
        code.clear
        in_code = false
      else
        in_code = true
      end
      next
    end

    if in_code
      code << line
      next
    end

    if line.start_with?("|")
      flush_paragraph.call
      close_list.call
      table << line
      next
    else
      flush_table.call
    end

    if (match = line.match(/\A(\#{1,6})\s+(.+)\z/))
      flush_paragraph.call
      close_list.call
      level = match[1].length
      id = match[2].downcase.gsub(/<[^>]+>/, "").gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-?\z/, "")
      html << "<h#{level} id=\"#{id}\">#{inline(match[2])}</h#{level}>"
    elsif (match = line.match(/\A-\s+(.+)\z/))
      flush_paragraph.call
      if list_type != "ul"
        close_list.call
        html << "<ul>"
        list_type = "ul"
      end
      html << "<li>#{inline(match[1])}</li>"
    elsif (match = line.match(/\A\d+\.\s+(.+)\z/))
      flush_paragraph.call
      if list_type != "ol"
        close_list.call
        html << "<ol>"
        list_type = "ol"
      end
      html << "<li>#{inline(match[1])}</li>"
    elsif line.strip.empty?
      flush_paragraph.call
      close_list.call
    else
      close_list.call
      paragraph << line.strip
    end
  end

  flush_paragraph.call
  close_list.call
  flush_table.call
  html.join("\n")
end

STYLE = <<~CSS
  :root { color-scheme: light; --ink:#172033; --muted:#5e6b7e; --line:#dfe5ee;
    --brand:#3157d5; --surface:#f6f8fb; --code:#eef2f8; }
  * { box-sizing:border-box; }
  body { margin:0; color:var(--ink); background:var(--surface);
    font:16px/1.65 Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  header { position:sticky; top:0; z-index:2; border-bottom:1px solid var(--line);
    background:rgba(255,255,255,.94); backdrop-filter:blur(10px); }
  header div { max-width:1100px; margin:auto; padding:12px 28px; display:flex;
    justify-content:space-between; gap:20px; align-items:center; }
  header a { color:var(--brand); text-decoration:none; font-weight:650; }
  main { max-width:1100px; margin:32px auto 80px; padding:42px 56px; background:#fff;
    border:1px solid var(--line); border-radius:18px; box-shadow:0 18px 50px rgba(29,43,76,.07); }
  h1 { font-size:2.25rem; line-height:1.2; letter-spacing:-.035em; margin-top:0; }
  h2 { font-size:1.55rem; margin-top:2.2em; padding-top:.2em; border-top:1px solid var(--line); }
  h3 { font-size:1.17rem; margin-top:1.8em; }
  h1,h2,h3 { scroll-margin-top:72px; }
  p,li { max-width:82ch; }
  a { color:var(--brand); }
  code { padding:.15em .35em; background:var(--code); border-radius:5px; font-size:.9em; }
  pre { overflow:auto; padding:18px; background:#111827; color:#eef2ff; border-radius:10px; }
  pre code { padding:0; background:none; }
  .table-wrap { overflow-x:auto; margin:1.2em 0; }
  table { width:100%; border-collapse:collapse; font-size:.94rem; }
  th,td { padding:11px 13px; border:1px solid var(--line); text-align:left; vertical-align:top; }
  th { background:#f1f4f9; }
  strong { color:#101827; }
  footer { color:var(--muted); text-align:center; margin:24px; font-size:.88rem; }
  @media (max-width:700px) { main { margin:0; padding:28px 20px; border-width:0; border-radius:0; }
    header div { padding:10px 18px; } h1 { font-size:1.8rem; } }
  @media print { header,footer { display:none; } body,main { background:#fff; }
    main { margin:0; padding:0; border:0; box-shadow:none; max-width:none; } }
CSS

FileUtils.mkdir_p(OUTPUT_DIR)
sources = Dir.glob(File.join(SOURCE_DIR, "*.md")).sort

sources.each do |path|
  markdown = File.read(path)
  title = markdown[/\A#\s+(.+)$/, 1] || File.basename(path, ".md")
  body = render_markdown(markdown)
  filename = "#{File.basename(path, ".md")}.html"
  index_href = File.basename(path) == "README.md" ? "README.html" : "README.html"

  document = <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <meta name="description" content="#{CGI.escapeHTML(title)}">
      <title>#{CGI.escapeHTML(title)}</title>
      <style>#{STYLE}</style>
    </head>
    <body>
      <header><div><a href="#{index_href}">BetaSigma · PRD guides</a><a href="../#{File.basename(path)}">Markdown source</a></div></header>
      <main>#{body}</main>
      <footer>Generated from #{CGI.escapeHTML(File.basename(path))}. Edit the Markdown source, then rerun the renderer.</footer>
    </body>
    </html>
  HTML

  File.write(File.join(OUTPUT_DIR, filename), document)
end

puts "Rendered #{sources.length} project documents to #{OUTPUT_DIR}"
