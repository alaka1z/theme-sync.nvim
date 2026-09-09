local M = {}

local themes = {}
local theme_order = {}

local picker_active = false
local current_transparency = false
local opacity_watcher

local function set_themes(theme_list)
  themes = {}
  theme_order = {}

  for _, theme in ipairs(theme_list or {}) do
    if
      not theme.id
      or not theme.nvim
      or not theme.wezterm
      or type(theme.set_nvim_transparency) ~= "function"
      or type(theme.get_nvim_colors) ~= "function"
    then
      error(
        "theme-sync: each theme requires id, nvim, wezterm, "
          .. "set_nvim_transparency, and get_nvim_colors"
      )
    end

    themes[theme.id] = theme
    table.insert(theme_order, theme.id)
  end

  if #theme_order == 0 then
    error("theme-sync: no themes configured")
  end
end

local function set_transparency(enabled)
  for _, id in ipairs(theme_order) do
    themes[id].set_nvim_transparency(enabled)
  end
end

local function get_theme_by_nvim(name)
  for id, theme in pairs(themes) do
    if theme.nvim == name then
      return id, theme
    end
  end
end

local function get_current_colors()
  local _, theme = get_theme_by_nvim(vim.g.colors_name)

  if not theme then
    return nil
  end

  return theme.get_nvim_colors()
end

local function write_current_colors()
  local colors = get_current_colors()

  if not colors or not colors.background or not colors.foreground then
    return
  end

  local temp = vim.env.TEMP or vim.env.TMP

  if not temp then
    return
  end

  local path = vim.fs.joinpath(temp, "theme-sync-colors")

  vim.fn.writefile({
    colors.background,
    colors.foreground,
  }, path)
end

local function set_theme_normal()
  local colors = get_current_colors()

  if
    not colors
    or not colors.foreground
    or not colors.background
  then
    return
  end

  vim.api.nvim_set_hl(0, "ThemeNormal", {
    fg = colors.foreground,
    bg = colors.background,
  })
end

local function sync_theme()
  local _, theme = get_theme_by_nvim(vim.g.colors_name)

  if not theme then
    return
  end

  vim.api.nvim_ui_send(
    ("\27]1337;SetUserVar=THEME_SYNC=%s\7"):format(
      vim.base64.encode(theme.wezterm)
    )
  )
end

local function save_theme(id)
  local local_appdata = os.getenv("LOCALAPPDATA")

  if not local_appdata then
    return
  end

  local dir = local_appdata .. "\\theme-sync"
  local path = dir .. "\\theme"

  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ id }, path)
end

local function handle_colorscheme()
  set_theme_normal()
  write_current_colors()
  sync_theme()

  if picker_active then
    return
  end

  local id = get_theme_by_nvim(vim.g.colors_name)

  if id then
    save_theme(id)
  end
end

local function load_saved_theme()
  local id
  local local_appdata = os.getenv("LOCALAPPDATA")

  -- First prefer the committed theme
  if local_appdata then
    local path = local_appdata .. "\\theme-sync\\theme"

    if vim.fn.filereadable(path) == 1 then
      local saved = vim.fn.readfile(path)[1]

      if saved and themes[saved] then
        id = saved
      end
    end
  end

  -- If committed state is missing, match the current WezTerm theme
  if not id then
    local temp = os.getenv("TEMP")

    if temp then
      local path = temp .. "\\theme-sync-current"

      if vim.fn.filereadable(path) == 1 then
        local current = vim.fn.readfile(path)[1]

        if current and themes[current] then
          id = current
        end
      end
    end
  end

  -- Final fallback
  id = id or theme_order[1]

  vim.cmd.colorscheme(themes[id].nvim)
end

local function load_transparency()
  local temp = os.getenv("TEMP")

  if not temp then
    return nil
  end

  local path = temp .. "\\theme-sync-opacity"

  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local opacity = tonumber(vim.fn.readfile(path)[1])

  if not opacity then
    return nil
  end

  return opacity < 1
end

local function apply_transparency(enabled)
  if enabled == current_transparency then
    return
  end

  current_transparency = enabled
  set_transparency(enabled)

  local colorscheme = vim.g.colors_name

  if colorscheme and get_theme_by_nvim(colorscheme) then
    vim.cmd.colorscheme(colorscheme)
  end
end

local function watch_transparency()
  local temp = os.getenv("TEMP")

  if not temp then
    return
  end

  local path = temp .. "\\theme-sync-opacity"

  if vim.fn.filereadable(path) ~= 1 then
    return
  end

  if opacity_watcher then
    opacity_watcher:stop()
    opacity_watcher:close()
    opacity_watcher = nil
  end

  local watcher = vim.uv.new_fs_event()

  if not watcher then
    return
  end

  opacity_watcher = watcher

  watcher:start(path, {}, function()
    vim.schedule(function()
      local enabled = load_transparency()

      if enabled ~= nil then
        apply_transparency(enabled)
      end
    end)
  end)
end

function M.pick()
  local fzf = require("fzf-lua")
  local shell = require("fzf-lua.shell")
  local utils = require("fzf-lua.utils")

  local colors = {}

  for _, id in ipairs(theme_order) do
    table.insert(colors, themes[id].nvim)
  end

  local original_colorscheme = vim.g.colors_name
  local original_background = vim.o.background

  -- Keep the current theme at the top, matching fzf-lua's colorscheme picker
  if original_colorscheme then
    for i, color in ipairs(colors) do
      if color == original_colorscheme then
        table.remove(colors, i)
        table.insert(colors, 1, color)
        break
      end
    end
  end

  picker_active = true

  local opts = {
    prompt = "Colorschemes❯ ",

    fzf_colors = {
      ["bg"] = "-1",
      ["gutter"] = "-1",
    },

    fzf_opts = {
      ["--preview-window"] = "nohidden:right:0",
    },

    winopts = {
      on_create = function(e)
        if not e.winid then
          picker_active = false
          return
        end

        vim.api.nvim_create_autocmd("WinClosed", {
          pattern = tostring(e.winid),
          once = true,

          callback = function()
            vim.schedule(function()
              picker_active = false
            end)
          end,
        })
      end,
    },
  }

  opts.preview = shell.stringify_data(function(selected)
    local colorscheme = selected and selected[1]

    if colorscheme and vim.g.colors_name ~= colorscheme then
      vim.cmd.colorscheme(colorscheme)
    end
  end, opts, "{}")

  local function restore_original()
    if
      original_colorscheme
      and vim.g.colors_name ~= original_colorscheme
    then
      vim.cmd.colorscheme(original_colorscheme)
    end

    vim.o.background = original_background
    utils.setup_highlights()
  end

  opts.actions = {
    ["enter"] = function(selected)
      local colorscheme = selected and selected[1]

      if not colorscheme then
        return
      end

      -- Normally already active from live preview
      if vim.g.colors_name ~= colorscheme then
        vim.cmd.colorscheme(colorscheme)
      end

      local id = get_theme_by_nvim(colorscheme)

      if id then
        save_theme(id)
      end

      utils.setup_highlights()
    end,

    ["esc"] = restore_original,
    ["ctrl-c"] = restore_original,
    ["ctrl-q"] = restore_original,
  }

  fzf.fzf_exec(colors, opts)
end

function M.get_colors()
  return get_current_colors()
end

function M.setup(opts)
  opts = opts or {}

  set_themes(opts.themes)

  local transparency = load_transparency()

  if transparency == nil then
    transparency = false
  end

  current_transparency = transparency
  set_transparency(transparency)
  load_saved_theme()
  set_theme_normal()
  write_current_colors()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ThemeSync", {
      clear = true,
    }),
    callback = handle_colorscheme,
  })

  watch_transparency()
end

return M
