local nui_prompt = require("nui.menu")
local event = require("nui.utils.autocmd").event

local M = {}

M.prompt = function(data)
    local format_entries = function()
        local results = {}
        results[1] = nui_prompt.separator(" ")
        for _, entry in pairs(data.data.lines) do
            table.insert(results, nui_prompt.item(entry.text))
        end
        return results
    end
    local formatted_lines = format_entries()
    local popup_prompt = nui_prompt({
        relative = "editor",
        position = "50%",
        size = {
            width = 60,
            height = #formatted_lines + 1,
        },
        border = {
            highlight = "NuiBorder",
            style = { " ", " ", " ", " ", " ", " ", " ", " " },
            text = {
                top = data.data.title or "Choice:",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:NuiBody",
        },
    }, {
        lines = formatted_lines,
        on_close = function()
            popup_prompt = nil
        end,
        on_submit = function(item)
            data.data.lines[item["_index"] - 1]["fn"]()
            popup_prompt = nil
        end,
    })
    popup_prompt:mount()
    popup_prompt:on(event.BufLeave, popup_prompt.menu_props.on_close, { once = true })
end

return M
