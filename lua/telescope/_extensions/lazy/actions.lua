local M = {}

local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local builtin = require("telescope.builtin")

local telescope_lazy_config = require("telescope._extensions.lazy.config")
local lazy_options = require("lazy.core.config").options

local floating_window = require("telescope._extensions.lazy.floating_window")

local function warn_no_selection_action()
  vim.notify(
    "Please make a valid selection before performing the action.",
    vim.log.levels.WARN,
    { title = telescope_lazy_config.extension_name }
  )
end

local function get_selected_entry()
  local selected_entry = actions_state.get_selected_entry()
  if not selected_entry then
    warn_no_selection_action()
  end
  return selected_entry
end

local function attach_mappings(_, map)
  map({ "n", "i" }, telescope_lazy_config.opts.mappings.open_plugins_picker, function()
    builtin.resume()
  end)
  return true
end

function M.change_cwd_to_plugin()
  local selected_entry = get_selected_entry()
  if not selected_entry then
    return
  end

  if vim.fn.getcwd() == selected_entry.path then
    return
  end

  local ok, res = pcall(vim.cmd.cd, selected_entry.path)
  if ok then
    vim.notify(
      string.format("Changed cwd to: '%s'.", selected_entry.path),
      vim.log.levels.INFO,
      { title = telescope_lazy_config.extension_name }
    )
  else
    vim.notify(
      string.format("Could not change cwd to: '%s'.\nError: '%s'" .. selected_entry.path, res),
      vim.log.levels.ERROR,
      { title = telescope_lazy_config.extension_name }
    )
  end
end

function M.open_in_terminal()
  local selected_entry = get_selected_entry()
  if not selected_entry then
    return
  end

  local window = floating_window.new()
  window:open_terminal(selected_entry.path, builtin.resume)
end

function M.open_in_float()
  local selected_entry = get_selected_entry()
  if not selected_entry then
    return
  end

  if selected_entry.readme then
    vim.cmd.stopinsert()
    local lines = vim.fn.readfile(selected_entry.readme)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local width = math.ceil(vim.o.columns * 0.7)
    local height = math.ceil(vim.o.lines * 0.7)
    local opts = {
        relative = "editor",
        width = width,
        height = height,
        col = math.ceil((vim.o.columns - width) / 2),
        row = math.ceil((vim.o.lines - height) / 2),
        style = "minimal",
        border = "single",
    }
    vim.api.nvim_open_win(buf, true, opts)
    vim.wo.conceallevel = 3

    -- Buffer options
    vim.api.nvim_set_option_value("filetype", "readup", { buf = buf })
    vim.api.nvim_buf_set_name(buf, "readup")
    vim.api.nvim_set_option_value("readonly", true, { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "delete", { buf = buf })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  end
end

function M.open_in_browser()
  local open_cmd
  if vim.fn.executable("xdg-open") == 1 then
    open_cmd = "xdg-open"
  elseif vim.fn.executable("explorer") == 1 then
    open_cmd = "explorer"
  elseif vim.fn.executable("open") == 1 then
    open_cmd = "open"
  elseif vim.fn.executable("wslview") == 1 then
    open_cmd = "wslview"
  end

  if not open_cmd then
    vim.notify(
      "Open in browser is not supported by your operating system.",
      vim.log.levels.ERROR,
      { title = telescope_lazy_config.extension_name }
    )
  else
    local selected_entry = get_selected_entry()
    if not selected_entry then
      return
    end

    local ret = vim.fn.jobstart({ open_cmd, selected_entry.url }, { detach = true })
    if ret <= 0 then
      vim.notify(
        string.format("Failed to open '%s'\nwith command: '%s' (ret: '%d')", selected_entry.url, open_cmd, ret),
        vim.log.levels.ERROR,
        { title = telescope_lazy_config.extension_name }
      )
    end
  end
end

function M.open_lazy_root_find_files()
  builtin.find_files({
    prompt_title = "Find files in lazy root",
    cwd = lazy_options.root,
    attach_mappings = attach_mappings,
  })
end

function M.open_lazy_root_live_grep()
  builtin.live_grep({
    prompt_title = "Grep files in lazy root",
    cwd = lazy_options.root,
    attach_mappings = attach_mappings,
  })
end

function M.open_in_find_files()
  local selected_entry = get_selected_entry()
  if not selected_entry then
    return
  end

  builtin.find_files({
    prompt_title = string.format("Find files (%s)", selected_entry.name),
    cwd = selected_entry.path,
    attach_mappings = attach_mappings,
  })
end

function M.open_in_live_grep()
  local selected_entry = get_selected_entry()
  if not selected_entry then
    return
  end

  builtin.live_grep({
    prompt_title = string.format("Grep files (%s)", selected_entry.name),
    cwd = selected_entry.path,
    attach_mappings = attach_mappings,
  })
end

function M.open_in_file_browser()
  local ok, file_browser = pcall(require, "telescope._extensions.file_browser")
  if not ok then
    vim.notify(
      "This action requires 'telescope-file-browser.nvim'. (https://github.com/nvim-telescope/telescope-file-browser.nvim)",
      vim.log.levels.ERROR,
      { title = telescope_lazy_config.extension_name }
    )
    return
  end

  local selected_entry = get_selected_entry()
  if not selected_entry then
    return
  end

  file_browser.exports.file_browser({
    prompt_title = string.format("File browser (%s)", selected_entry.name),
    cwd = selected_entry.path,
    attach_mappings = attach_mappings,
  })
end

function M.default_action_replace(prompt_bufnr)
  actions.select_default:replace(function()
    local selected_entry = get_selected_entry()
    if not selected_entry then
      return
    end

    if selected_entry.readme then
      actions.close(prompt_bufnr)
      vim.cmd.edit(selected_entry.readme)
    else
      vim.notify(
        "Could not perform action. Readme file doesn't exist.",
        vim.log.levels.ERROR,
        { title = telescope_lazy_config.extension_name }
      )
    end
  end)
end

return M
