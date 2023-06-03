local M = {
    links = {
        active = true,
        keymaps = {
            open = "<CR>",
            next_file = "m",
            prev_file = "M",
            next_link = "n",
            prev_link = "N",
            preview = "P",
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
