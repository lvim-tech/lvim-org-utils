local M = {
    links = {
        active = true,
        org_path = { "~/Org/" },
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
    codeblock = {
        active = true,
        hl = "OrgTSCode",
    },
}

return M
