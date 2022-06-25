local config = require("lvim-org-utils.config")
local utils = require("lvim-org-utils.utils")
local links = require("lvim-org-utils.links")
local style = require("lvim-org-utils.style")
local codeblock = require("lvim-org-utils.codeblock")
local select = require("lvim-org-utils.select")

local M = {}

M.setup = function(user_config)
    vim.api.nvim_create_augroup("LvimOrgUtils", {
        clear = true,
    })
    vim.api.nvim_create_autocmd({
        "BufWinLeave",
    }, {
        pattern = "*.org",
        callback = function()
            if vim.bo.modified then
                vim.defer_fn(function()
                    pcall(function()
                        select({ "Save", "Lose", "Cancel" }, { prompt = "Save or lose before leave?" },
                            function(choice)
                                if choice == "Save" then
                                    vim.cmd("write!")
                                    vim.cmd("blast")
                                elseif choice == "Lose" then
                                    vim.cmd("edit!")
                                    vim.cmd("blast")
                                end
                            end)
                    end)
                end, 10)
                pcall(function()
                    vim.cmd("last")
                end)
            end
        end,
    })
    vim.api.nvim_create_autocmd({
        "BufWinEnter",
    }, {
        pattern = "*.org",
        callback = function()
            vim.cmd("edit!")
            if config.links.active then
                links.navigation()
            end
        end,
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
