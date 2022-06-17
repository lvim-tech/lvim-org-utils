local config = require("lvim-org-utils.config")
local utils = require("lvim-org-utils.utils")
local autocmd = require("lvim-org-utils.autocmd")
local style = require("lvim-org-utils.style")

local M = {}

M.setup = function(user_config)
    if user_config ~= nil then
        utils.merge(config, user_config)
    end
    vim.schedule(function()
        if config.links.active then
            autocmd.setup_keymaps()
        end
        if config.style.active then
            style.init()
        end
    end)
end

return M
