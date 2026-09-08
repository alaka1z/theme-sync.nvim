if vim then
  return
end

local wezterm = require("wezterm")

local M = {}

local themes = {}
local default_theme_id

local function set_themes(theme_list)
  themes = {}
  default_theme_id = nil

  for _, theme in ipairs(theme_list or {}) do
    if not theme.id or not theme.wezterm then
      error("theme-sync: each theme requires id and wezterm")
    end

    if not default_theme_id then
      default_theme_id = theme.id
    end

    themes[theme.id] = theme.wezterm
  end

  if not default_theme_id then
    error("theme-sync: no themes configured")
  end
end

local function load_saved_theme()
  local id = default_theme_id
  local local_appdata = os.getenv("LOCALAPPDATA")

  if local_appdata then
    local path = local_appdata .. "\\theme-sync\\theme"
    local file = io.open(path, "r")

    if file then
      local saved = file:read("*l")
      file:close()

      if saved and themes[saved] then
        id = saved
      end
    end
  end

  return id, themes[id]
end

local function save_current_theme(id)
  local temp = os.getenv("TEMP")

  if not temp then
    return
  end

  local path = temp .. "\\theme-sync-current"
  local file = io.open(path, "w")

  if not file then
    return
  end

  file:write(id)
  file:close()
end

local function save_current_opacity(window)
  local temp = os.getenv("TEMP")

  if not temp then
    return
  end

  local opacity = window:effective_config().window_background_opacity
  local path = temp .. "\\theme-sync-opacity"
  local file = io.open(path, "w")

  if not file then
    return
  end

  file:write(tostring(opacity))
  file:close()
end

local function get_theme_by_scheme(scheme_name)
  for id, name in pairs(themes) do
    if name == scheme_name then
      return id
    end
  end
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

function M.apply_to_config(config, opts)
  opts = opts or {}

  set_themes(opts.themes)

  local id, scheme = load_saved_theme()

  config.color_scheme = scheme
  save_current_theme(id)

  wezterm.on("user-var-changed", function(_, pane, name, value)
    if name ~= "THEME_SYNC" then
      return
    end

    apply_dynamic_scheme(pane, value)

    local current_id = get_theme_by_scheme(value)

    if current_id then
      save_current_theme(current_id)
    end
  end)

  wezterm.on("window-config-reloaded", function(window)
    save_current_opacity(window)
  end)
end

return M
