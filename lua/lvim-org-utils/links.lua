local M = {}
local config = require("lvim-org-utils.config")
local actions = require("lvim-org-utils.actions")

M.init = function()
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "org",
        callback = function()
            vim.keymap.set(
                "n",
                config.links.keymaps.create_or_follow,
                actions.follow_or_create,
                { buffer = true, desc = "create/follow link under cursor" }
            )
            vim.keymap.set(
                "n",
                config.links.keymaps.traverse_back,
                actions.back,
                { buffer = true, desc = "Go to parent link" }
            )
            vim.keymap.set("n", config.links.keymaps.go_to_next, actions.go_to_next, {
                buffer = true,
                desc = "Go to next link",
            })
            vim.keymap.set(
                "n",
                config.links.keymaps.go_to_prev,
                actions.go_to_prev,
                { buffer = true, desc = "Go to previous link" }
            )
            vim.keymap.set(
                "n",
                config.links.keymaps.hover,
                actions.hover,
                { buffer = true, desc = "Preview link in popup window" }
            )
        end,
        group = "LvimOrgUtils",
    })
end

return M