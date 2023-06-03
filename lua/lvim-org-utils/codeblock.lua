local NAMESPACE = vim.api.nvim_create_namespace("lvim-org-utils-codeblock")
SOURCE_PATTERN_START = "#%+[bB][eE][gG][iI][nN]_[sS][rR][cC]"
SOURCE_PATTERN_END = "#%+[eE][nN][dD]_[sS][rR][cC]"

local M = {}

M.code_block = function()
    vim.api.nvim_buf_clear_namespace(0, NAMESPACE, 0, -1)
    local bufnr = vim.api.nvim_get_current_buf()
    local offset = 0
    local range = vim.api.nvim_buf_line_count(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, offset, range, false)
    local is_code = false
    for i = 1, #lines do
        local _, source_start = lines[i]:find(SOURCE_PATTERN_START)
        if source_start then
            is_code = true
        end
        if is_code then
            vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, i - 1 + offset, 0, {
                end_col = 0,
                end_row = i + offset,
                hl_group = "OrgTSBlockCode",
                hl_eol = true,
            })
        end
        local _, source_end = lines[i]:find(SOURCE_PATTERN_END)
        if source_end then
            is_code = false
        end
    end
end

return M
