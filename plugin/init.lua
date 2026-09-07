if vim then
  return
end

local wezterm = require("wezterm")

local M = {}

local themes = {
  catppuccin = "Catppuccin Mocha",
  tokyonight = "Tokyo Night Moon",
  gruvbox = "GruvboxDark",
  rose_pine = "rose-pine",
}

local function load_saved_theme()
  local local_appdata = os.getenv("LOCALAPPDATA")

  if not local_appdata then
    return themes.catppuccin
  end

  local path = local_appdata .. "\\theme-sync\\theme"
  local file = io.open(path, "r")

  if not file then
    return themes.catppuccin
  end

  local id = file:read("*l")
  file:close()

  return themes[id] or themes.catppuccin
end

local function apply_dynamic_scheme(pane, scheme_name)
  local schemes = wezterm.color.get_builtin_schemes()
  local scheme = schemes[scheme_name]

  if not scheme then
    wezterm.log_error("theme-sync: unknown color scheme: " .. scheme_name)
    return
  end

  local sequences = {}

  for i, color in ipairs(scheme.ansi or {}) do
    table.insert(
      sequences,
      string.format("\27]4;%d;%s\27\\", i - 1, color)
    )
  end

  for i, color in ipairs(scheme.brights or {}) do
    table.insert(
      sequences,
      string.format("\27]4;%d;%s\27\\", i + 7, color)
    )
  end

  if scheme.foreground then
    table.insert(sequences, "\27]10;" .. scheme.foreground .. "\27\\")
  end

  if scheme.background then
    table.insert(sequences, "\27]11;" .. scheme.background .. "\27\\")
  end

  local cursor = scheme.cursor_bg or scheme.cursor_border

  if cursor then
    table.insert(sequences, "\27]12;" .. cursor .. "\27\\")
  end

  pane:inject_output(table.concat(sequences))
end

function M.apply_to_config(config)
  config.color_scheme = load_saved_theme()

  wezterm.on("user-var-changed", function(window, pane, name, value)
    if name ~= "THEME_SYNC" then
      return
    end

    apply_dynamic_scheme(pane, value)
  end)
end

return M
