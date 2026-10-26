-- {{< csv-table data/file.csv caption="..." >}}
--
-- Renders a CSV (path relative to the project root) as an accessible HTML
-- table at build time, so it works without JavaScript. csv-table.js then adds
-- sorting and filtering on top.
--
-- Options:
--   caption="..."        table caption (strongly recommended)
--   row-headers="false"  don't treat the first column as row headers
--   download="false"     hide the "Download CSV" link
--   interactive="false"  no sorting / filtering

local table_count = 0

-- RFC 4180 parser: quoted fields, "" escapes, embedded commas and newlines.
local function parse_csv(text)
  text = text:gsub("^\239\187\191", ""):gsub("\r\n?", "\n")
  local rows, row, field = {}, {}, {}
  local i, n, in_quotes = 1, #text, false
  while i <= n do
    local c = text:sub(i, i)
    if in_quotes then
      if c == '"' then
        if text:sub(i + 1, i + 1) == '"' then
          field[#field + 1] = '"'
          i = i + 1
        else
          in_quotes = false
        end
      else
        field[#field + 1] = c
      end
    elseif c == '"' then
      in_quotes = true
    elseif c == "," then
      row[#row + 1] = table.concat(field)
      field = {}
    elseif c == "\n" then
      row[#row + 1] = table.concat(field)
      rows[#rows + 1] = row
      row, field = {}, {}
    else
      field[#field + 1] = c
    end
    i = i + 1
  end
  if #field > 0 or #row > 0 then
    row[#row + 1] = table.concat(field)
    rows[#rows + 1] = row
  end
  return rows
end

local function escape_html(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- Cells may contain inline Markdown (links, emphasis, code). Bare URLs become
-- links, and "@name" stays literal rather than being read as a citation.
local function cell_html(text)
  if text == "" then
    return ""
  end
  local doc = pandoc.read(text, "markdown+autolink_bare_uris-citations")
  local blocks = doc.blocks
  if #blocks == 1 and blocks[1].t == "Para" then
    blocks = { pandoc.Plain(blocks[1].content) }
  end
  return (pandoc.write(pandoc.Pandoc(blocks), "html"):gsub("%s+$", ""))
end

local function option(kwargs, name, default)
  local value = pandoc.utils.stringify(kwargs[name] or "")
  if value == "" then
    return default
  end
  return value
end

return {
  ["csv-table"] = function(args, kwargs)
    if not quarto.doc.is_format("html") then
      return pandoc.Null()
    end
    local rel_path = pandoc.utils.stringify(args[1] or "")
    if rel_path == "" then
      error("csv-table: give the CSV path, e.g. {{< csv-table data/tools.csv >}}")
    end

    local abs_path = pandoc.path.join({ quarto.project.directory, rel_path })
    local file = io.open(abs_path, "r")
    if not file then
      error("csv-table: cannot read " .. rel_path .. " (paths are relative to the project root)")
    end
    local rows = parse_csv(file:read("a"))
    file:close()
    if #rows == 0 then
      error("csv-table: " .. rel_path .. " is empty")
    end

    quarto.doc.add_html_dependency({
      name = "csv-table",
      version = "1.0.0",
      scripts = { "csv-table.js" },
      stylesheets = { "csv-table.css" },
    })

    table_count = table_count + 1
    local id = "csv-table-" .. table_count
    local caption = option(kwargs, "caption", "")
    local row_headers = option(kwargs, "row-headers", "true") == "true"
    local interactive = option(kwargs, "interactive", "true") == "true"
    local download = option(kwargs, "download", "true") == "true"
    local header = rows[1]

    local out = {}
    local function add(s) out[#out + 1] = s end

    add('<div class="csv-table"' .. (interactive and ' data-csv-table' or '') .. '>')
    -- Quarto would otherwise re-parse this raw HTML and drop our attributes.
    add('<div class="csv-table__scroll" role="region" tabindex="0" aria-labelledby="'
      .. id .. (caption ~= "" and '-caption' or '-label') .. '">')
    add('<table class="table table-sm csv-table__table" id="' .. id
      .. '" data-quarto-disable-processing="true">')
    if caption ~= "" then
      add('<caption id="' .. id .. '-caption">' .. escape_html(caption) .. '</caption>')
    else
      add('<caption id="' .. id .. '-label" class="visually-hidden">'
        .. escape_html(rel_path) .. '</caption>')
    end
    add("<thead><tr>")
    for _, name in ipairs(header) do
      add('<th scope="col">' .. escape_html(name) .. "</th>")
    end
    add("</tr></thead><tbody>")
    for r = 2, #rows do
      local row = rows[r]
      if not (#row == 1 and row[1] == "") then -- skip blank lines
        add("<tr>")
        for c = 1, #header do
          local tag = (c == 1 and row_headers) and 'th scope="row"' or "td"
          add("<" .. tag .. ">" .. cell_html(row[c] or "") .. "</" .. tag:match("^%a+") .. ">")
        end
        add("</tr>")
      end
    end
    add("</tbody></table></div>")
    if download then
      local page_dir = pandoc.path.directory(quarto.doc.input_file)
      local href = pandoc.path.make_relative(abs_path, page_dir, true)
      add('<p class="csv-table__meta"><a href="' .. escape_html(href)
        .. '" download>Download CSV<span class="visually-hidden"> ('
        .. escape_html(caption ~= "" and caption or rel_path) .. ')</span></a></p>')
    end
    add("</div>")

    return pandoc.RawBlock("html", table.concat(out, "\n"))
  end,
}
