local M = {}

local themes = {
  catppuccin = {
    nvim = "catppuccin-mocha",
    wezterm = "Catppuccin Mocha",
  },

  tokyonight = {
    nvim = "tokyonight-moon",
    wezterm = "Tokyo Night Moon",
  },

  gruvbox = {
    nvim = "gruvbox",
    wezterm = "GruvboxDark",
  },

  rose_pine = {
    nvim = "rose-pine",
    wezterm = "rose-pine",
  },
}

local theme_order = {
  "catppuccin",
  "tokyonight",
  "gruvbox",
  "rose_pine",
}

local picker_active = false

local function get_theme_by_nvim(name)
  for id, theme in pairs(themes) do
    if theme.nvim == name then
      return id, theme
    end
  end
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
  id = id or "catppuccin"

  vim.cmd.colorscheme(themes[id].nvim)
end

function M.pick()
  local colors = {}

  for _, id in ipairs(theme_order) do
    table.insert(colors, themes[id].nvim)
  end

  picker_active = true

  require("fzf-lua").colorschemes({
    colors = colors,

    fzf_colors = {
      ["bg"] = "-1",
      ["gutter"] = "-1",
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

    actions = {
      ["enter"] = function(selected, opts)
        require("fzf-lua.actions").colorscheme(selected, opts)

        local id = get_theme_by_nvim(vim.g.colors_name)

        if id then
          save_theme(id)
        end
      end,
    },
  })
end

function M.setup()
  load_saved_theme()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ThemeSync", {
      clear = true,
    }),
    callback = handle_colorscheme,
  })
end

function M.loaded()
  return true
end

return M
