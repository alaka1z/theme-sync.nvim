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

function M.pick()
  local colors = {}

  for _, id in ipairs(theme_order) do
    table.insert(colors, themes[id].nvim)
  end

  require("fzf-lua").colorschemes({
    colors = colors,

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
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ThemeSync", {
      clear = true,
    }),
    callback = sync_theme,
  })
end

function M.loaded()
  return true
end

return M
