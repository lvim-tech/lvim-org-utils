local config = require("lvim-org-utils.config")
local utils = require("lvim-org-utils.utils")
local links = require("lvim-org-utils.links")
local style = require("lvim-org-utils.style")
local codeblock = require("lvim-org-utils.codeblock")

local M = {}

M.setup = function(user_config)
    vim.api.nvim_create_augroup("LvimOrgUtils", {
        clear = true,
    })
    if user_config ~= nil then
        utils.merge(config, user_config)
    end
    if config.links.active then
        links.init()
    end
    if config.style.active then
        style.init()
    end
    if config.codeblock.active then
        codeblock.init()
    end
end

return M
