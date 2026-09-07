local M = {}

local themes = {
  ["catppuccin-mocha"] = "Catppuccin Mocha",
  ["tokyonight-moon"] = "Tokyo Night Moon",
  gruvbox = "GruvboxDark",
  ["rose-pine"] = "rose-pine",
}

local function sync_theme()
  local wezterm_theme = themes[vim.g.colors_name]

  if not wezterm_theme then
    return
  end

  vim.api.nvim_ui_send(
    ("\27]1337;SetUserVar=THEME_SYNC=%s\7"):format(
      vim.base64.encode(wezterm_theme)
    )
  )
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
