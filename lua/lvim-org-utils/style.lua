local M = {}

local config = require("lvim-org-utils.config")
local NAMESPACE = vim.api.nvim_create_namespace("lvim-org-utils-style")
local org_headline_hl = "OrgTSHeadlineLevel"
local list_groups = {
    ["-"] = "OrgTSHeadlineLevel1",
    ["+"] = "OrgTSHeadlineLevel2",
    ["*"] = "OrgTSHeadlineLevel3",
}
local ticks = {}

local function add_symbol_padding(symbol, padding_spaces, padding_in_front)
    if padding_in_front then
        return string.rep(" ", padding_spaces - 1) .. symbol
    else
        return symbol .. string.rep(" ", padding_spaces)
    end
end

local markers = {
    stars = function(str)
        local level = #str <= 0 and 0 or #str
        local symbols = config.style.symbols.headlines
        local symbol =
            add_symbol_padding((symbols[level] or config.style.symbols.headlines[1]), level, config.style.indent)
        local highlight = org_headline_hl .. level
        return { { symbol, highlight } }
    end,
    checkbox = function(str, conf)
        local symbols = config.style.symbols.checkboxes
        local text = symbols.todo
        if str:match("[Xx]") then
            return {
                { "[", "OrgTSCheckboxChecked" },
                symbols.done,
                { "]", "OrgTSCheckboxChecked" },
            }
        elseif str:match("-") then
            return {
                { "[", "OrgTSCheckboxHalfChecked" },
                symbols.half,
                { "]", "OrgTSCheckboxHalfChecked" },
            }
        elseif str:match(" ") then
            return {
                { "[", "OrgTSCheckbox" },
                symbols.undone,
                { "]", "OrgTSCheckbox" },
            }
        end
        return { { "[", "NonText" }, text, { "]", "NonText" } }
    end,
    bullet = function(str)
        if str:match("*") or str:match("+") or str:match("-") then
            local symbol = add_symbol_padding(config.style.symbols.bullet, (#str - 1), true)
            return { { symbol, list_groups[vim.trim(str)] } }
        end
    end,
}

local function set_mark(bufnr, virt_text, lnum, start_col, end_col, highlight)
    local ok, _ = pcall(vim.api.nvim_buf_set_extmark, bufnr, NAMESPACE, lnum, start_col, {
        end_col = end_col,
        hl_group = highlight,
        virt_text = virt_text,
        virt_text_pos = "overlay",
        hl_mode = "combine",
        ephemeral = true,
    })
    if not ok then
        vim.schedule(function()
            vim.notify_once(result, "error", { title = "LVIM ORG" })
        end)
    end
end

local function create_position(bufnr, name, node)
    local type = node:type()
    local row1, col1, row2, col2 = node:range()
    return {
        name = name,
        type = type,
        item = vim.treesitter.get_node_text(node, bufnr),
        start_row = row1,
        start_col = col1,
        end_row = row2,
        end_col = col2,
    }
end

local function add_empty_checkbox(bufnr, name, match, query, position, positions)
    if name:match("left") then
        return
    end
    local next_id, next_match = next(match)
    local next_name = query.captures[next_id]
    local next_position = create_position(bufnr, next_name, next_match)
    local right, left = position, next_position
    positions[#positions + 1] = {
        name = "org_checkbox_empty",
        type = "expr",
        item = left.item .. " " .. right.item,
        start_row = left.start_row,
        start_col = left.start_col,
        end_row = right.end_row,
        end_col = right.end_col,
    }
end

local function get_ts_positions(bufnr, start_row, end_row, root)
    local positions = {}
    local query = vim.treesitter.parse_query(
        "org",
        [[
            (stars) @stars
            ((bullet) @bullet
            (#match? @bullet "[-\*\+]"))
            (checkbox "[ ]") @org_checkbox
            (checkbox status: (expr "str") @_org_checkbox_done_str (#any-of? @_org_checkbox_done_str "x" "X")) @org_checkbox_done
            (checkbox status: (expr "-")) @org_checkbox_half
        ]]
    )
    for _, match, _ in query:iter_matches(root, bufnr, start_row, end_row) do
        for id, node in pairs(match) do
            local name = query.captures[id]
            if not vim.startswith(name, "_") then
                local position = create_position(bufnr, name, node)
                if name:match("org_checkbox%..+") then
                    add_empty_checkbox(bufnr, name, match, query, position, positions)
                else
                    positions[#positions + 1] = position
                end
            end
        end
    end
    return positions
end

local function set_position_marks(bufnr, positions)
    for _, position in ipairs(positions) do
        local str = position.item
        local start_row = position.start_row
        local start_col = position.start_col
        local end_col = position.end_col
        local handler = markers[position.type]
        local is_concealed = true
        if not config.style.concealcursor then
            local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
            is_concealed = start_row ~= (cursor_row - 1)
        end
        if is_concealed and start_col > -1 and end_col > -1 and handler then
            set_mark(bufnr, handler(str, config.style), start_row, start_col, end_col)
        end
    end
end

local get_parser = (function()
    local parsers = {}
    return function(bufnr)
        parsers[bufnr] = vim.treesitter.get_parser(bufnr, "org", {})
        return parsers[bufnr]
    end
end)()

local function get_mark_positions(bufnr, start_row, end_row)
    local parser = get_parser(bufnr)
    local positions = {}
    parser:for_each_tree(function(tstree, _)
        local root = tstree:root()
        local root_start_row, _, root_end_row, _ = root:range()
        if root_start_row > start_row or root_end_row < start_row then
            return
        end
        positions = get_ts_positions(bufnr, start_row, end_row, root)
    end)
    return positions
end

M.init = function()
    vim.api.nvim_set_decoration_provider(NAMESPACE, {
        on_start = function(_, tick)
            local buf = vim.api.nvim_get_current_buf()
            if ticks[buf] == tick then
                return false
            end
            ticks[buf] = tick
            return true
        end,
        on_win = function(_, _, bufnr, topline, botline)
            if vim.bo[bufnr].filetype ~= "org" then
                return false
            end
            local positions = get_mark_positions(bufnr, topline, botline)
            set_position_marks(bufnr, positions)
        end,
        on_line = function(_, _, bufnr, row)
            local positions = get_mark_positions(bufnr, row, row + 1)
            set_position_marks(bufnr, positions)
        end,
    })
end

return M
