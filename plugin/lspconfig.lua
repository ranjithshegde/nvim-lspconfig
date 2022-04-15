local version_info = vim.version()
if vim.fn.has 'nvim-0.7' ~= 1 then
  local warning_str = string.format(
    '[lspconfig] requires neovim 0.7 or later. Detected neovim version: 0.%s.%s',
    version_info.minor,
    version_info.patch
  )
  vim.notify_once(warning_str)
  return
end

local util = require 'lspconfig.util'
local configs = require 'lspconfig.configs'

_G.lsp_complete_configured_servers = function()
  return table.concat(vim.tbl_keys(configs), '\n')
end

_G.lsp_get_active_client_ids = function()
  return table.concat(
    vim.tbl_map(function(client)
      return ('%d (%s)'):format(client.id, client.name)
    end, require('lspconfig.util').get_managed_clients()),
    '\n'
  )
end

local get_clients_from_cmd_args = function(arg)
  local result = {}
  for id in (arg or ''):gmatch '(%d+)' do
    result[id] = vim.lsp.get_client_by_id(tonumber(id))
  end
  if vim.tbl_isempty(result) then
    return util.get_managed_clients()
  end
  return vim.tbl_values(result)
end

-- Called from plugin/lspconfig.vim because it requires knowing that the last
-- script in scriptnames to be executed is lspconfig.
vim.api.nvim_create_user_command('LspInfo', function()
  require 'lspconfig.ui.lspinfo'()
end, {
  desc = 'Displays attached, active, and configured language servers',
})

vim.api.nvim_create_user_command('LspStart', function(info)
  local server_name = info.args[1] ~= '' and info.args
  if server_name then
    if configs[server_name] then
      configs[server_name].launch()
    end
  else
    local other_matching_configs = require('lspconfig.util').get_other_matching_providers(vim.bo.filetype)
    for _, config in ipairs(other_matching_configs) do
      config.launch()
    end
  end
end, {
  desc = 'Manually launches a language server',
  nargs = '?',
  complete = 'custom,v:lua.lsp_complete_configured_servers',
})
vim.api.nvim_create_user_command('LspRestart', function(info)
  for _, client in ipairs(get_clients_from_cmd_args(info.args)) do
    client.stop()
    vim.defer_fn(function()
      configs[client.name].launch()
    end, 500)
  end
end, {
  desc = 'Manually restart the given language client(s)',
  nargs = '?',
  complete = 'custom,v:lua.lsp_get_active_client_ids',
})

vim.api.nvim_create_user_command('LspStop', function(info)
  for _, client in ipairs(get_clients_from_cmd_args(info.args)) do
    client.stop()
  end
end, {
  desc = 'Manually stops the given language client(s)',
  nargs = '?',
  complete = 'custom,v:lua.lsp_get_active_client_ids',
})
