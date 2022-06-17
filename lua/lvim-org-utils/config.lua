local M = {
    links = {
        active = true,
        org_path = { "/home/biserstoilov/BS/" },
        keymaps = {
            create_or_follow = "<CR>",
            traverse_back = "<BS>",
            go_to_next = "n",
            go_to_prev = "N",
            hover = "K",
        },
    },
    style = {
        active = true,
        show_current_line = false,
        symbols = {
            headlines = { "", "", "" },
            checkboxes = {
                half = { "", "OrgTSCheckboxHalfChecked" },
                done = { "", "OrgTSCheckboxChecked" },
                undone = { "", "OrgTSCheckbox" },
            },
            bullet = "",
        },
        indent = true,
        concealcursor = true,
    },
}

return M
