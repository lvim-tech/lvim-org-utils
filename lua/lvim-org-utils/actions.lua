local M = {}

local not_links = { hasBefore = false, hasAfter = false, before = "", after = "", full = "" }
local stack = {}
local link_lines = {}
local is_indexed = false

local has_win = function(tab, val)
    for index, sub in ipairs(tab) do
        if sub["winid"] == val then
            return true, index
        end
    end
    return false
end

local has_buf = function(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true, index
        end
    end
    return false
end

local new_stack = function(winnr)
    return {
        winid = winnr,
        buffers = {},
    }
end

local is_link = function(link)
    if link ~= nil then
        if link.match(link, "[a-z]*://[^ >,;]*") then
            return "external"
        elseif link:match("/") or link:match("~/") or link:match("./") then
            return "internal"
        else
            return false
        end
    else
        return false
    end
end

local open_external_link = function(link)
    if not vim.g.loaded_netrwPlugin then
        vim.notify("Netrw plugin must be loaded in order to open urls.")
        return
    end
    return vim.fn["netrw#BrowseX"](link, vim.fn["netrw#CheckIfRemote"]())
end

local clear_text_link = function()
    not_links.hasBefore = false
    not_links.before = ""
    not_links.hasAfter = false
    not_links.after = ""
    not_links.full = ""
end

local text_in_link = function(line)
    if line:find(".*%[%[") then
        local before = line:match(".*%[%[")
        before = before:gsub("%[%[", "")
        not_links.hasBefore = true
        not_links.before = before
    end
    if line:find("%]%].*") then
        local after = line:match("%]%].*")
        after = after:gsub("%]%]", "")
        not_links.hasAfter = true
        not_links.after = after
        table.insert(not_links, after)
    end
end

local find_link_string = function(line)
    local output = line:match("%[%[.*%]%[.*%]%]")
    if not output then
        return nil
    end
    text_in_link(line)
    return output
end

local text_without_link = function(line, word)
    if line:find(".*" .. word) then
        local before = line:match(".*" .. word)
        before = before:gsub(word, "")
        not_links.hasBefore = true
        not_links.before = before
    end
    if line:find(word .. ".*") then
        local after = line:match(word .. ".*")
        after = after:gsub(word, "")
        not_links.hasAfter = true
        not_links.after = after
        table.insert(not_links, after)
    end
end

local create_link = function(words)
    local config = require("lvim-orglinks.config")
    if words:match("/") then
        local path = vim.fn.fnamemodify(words, ":p:h")
        vim.api.nvim_command("!mkdir -p " .. path)
        local current_path = config.org_path
        pcall(vim.api.nvim_command("!cp " .. current_path .. ".gitignore " .. path))
        local tag = vim.fn.input("Enter link name: ")
        local link = string.format("[[%s][%s]]", words, tag)
        return link
    elseif not words:match("%.") then
        local filetype = vim.api.nvim_buf_get_option(vim.api.nvim_get_current_buf(), "filetype")
        local link = string.format("[[%s.%s][%s]]", words, filetype, words)
        return link
    else
        local tag = vim.fn.fnamemodify(words, ":r")
        local link = string.format("[[%s][%s]]", words, tag)
        return link
    end
end

local follow_link = function(link)
    local winnr = vim.api.nvim_get_current_win()
    local newwin
    local ok, index = has_win(stack, winnr)
    if not ok then
        newwin = new_stack(winnr)
    end
    if vim.loop.fs_stat(link) then
        vim.cmd("e " .. link)
        -- vim.cmd("lcd %:h:t")
        local bufnr = vim.api.nvim_get_current_buf()
        if not ok then
            table.insert(newwin.buffers, bufnr)
            table.insert(stack, newwin)
        else
            table.insert(stack[index].buffers, bufnr)
        end
    else
        vim.cmd("lcd " .. vim.fn.expand("%:p:h"))
        vim.cmd("e " .. link)
        local bufnr = vim.api.nvim_get_current_buf()
        if not ok then
            table.insert(newwin.buffers, bufnr)
            table.insert(stack, newwin)
        else
            table.insert(stack[index].buffers, bufnr)
        end
    end
end

local find_path = function(link)
    link = link:gsub("%[%[", "")
    if not link then
        vim.notify("Link does not follow proper syntax")
        return nil
    end
    link = link:gsub("%]%[.*", "")
    if not link then
        vim.notify("Syntax error: Wrong formatting of link")
        return nil
    end
    return link
end

local create_path = function(word)
    local link = create_link(word)
    if not_links.hasBefore then
        not_links.full = not_links.before
        not_links.hasBefore = false
        not_links.before = ""
    end
    line = link
    not_links.full = not_links.full .. link
    if not_links.hasAfter then
        not_links.full = not_links.full .. not_links.after

        not_links.hasAfter = false
        not_links.after = ""
    end
    return line
end

local find_all_links = function(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for index, line in ipairs(lines) do
        local linetab = {
            line = "",
            linenr = nil,
            colnr = nil,
        }
        local newline = find_link_string(line)
        if newline then
            linetab.colnr = line:find("%[")
            linetab.line = newline
            linetab.linenr = index
        end
        table.insert(link_lines, linetab)
    end
    is_indexed = true
end

M.follow_or_create = function()
    local line = vim.api.nvim_get_current_line()
    local word = vim.fn.expand("<cWORD>")
    local winnr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    local newwin
    local output = find_link_string(line)
    local type_link = is_link(output)
    if type_link then
        if not output then
            text_without_link(line, word)
            output = create_path(word)
            if not output then
                return
            else
                vim.api.nvim_set_current_line(not_links.full)
                not_links.full = ""
            end
        end
        output = find_path(output)
        if not output then
            return
        end
        if type_link == "external" then
            open_external_link(output)
        elseif type_link == "internal" then
            local ok, index = has_win(stack, winnr)
            if not ok then
                newwin = new_stack(winnr)
                table.insert(newwin.buffers, bufnr)
                table.insert(stack, newwin)
            else
                table.insert(stack[index].buffers, bufnr)
            end
            follow_link(output)
        end
    end
end

M.back = function()
    local new_buf
    local bufnr = vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()
    local w_ok, windex = has_win(stack, winnr)
    if w_ok then
        local b_ok, bindex = has_buf(stack[windex].buffers, bufnr)
        if b_ok then
            if stack[windex].buffers[bufnr] == 1 then
                vim.notify("Bottom of the move stack")
                return
            end
            table.remove(stack[windex].buffers, bindex)
            if stack[windex].buffers[bindex - 1] then
                new_buf = stack[windex].buffers[bindex - 1]
            else
                vim.notify("Bottom of the move stack")
                return
            end
        else
            vim.notify("This buffer is not in the stack")
            return
        end
    else
        vim.notify("Buffers in this window not found on stack")
        return
    end
    vim.cmd("b " .. new_buf)
    vim.cmd("lcd %:p:h")
end

M.go_to_next = function()
    local winnr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local next_link_line, next_link_col
    if not is_indexed then
        find_all_links(bufnr)
    end
    if link_lines then
        for i = cursor[1] + 1, #link_lines do
            if link_lines[i].linenr then
                next_link_line = link_lines[i].linenr
                next_link_col = link_lines[i].colnr
                vim.api.nvim_win_set_cursor(winnr, { next_link_line, next_link_col })
                clear_text_link()
                return
            end
        end
        if not next_link_line then
            vim.notify("No more links in the buffer")
            return
        end
    else
        vim.notify("There are no link in the buffer")
        return
    end
end

M.go_to_prev = function()
    local winnr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local next_link_line, next_link_col
    if not is_indexed then
        find_all_links(bufnr)
    end
    if link_lines then
        for i = cursor[1] - 1, 1, -1 do
            if link_lines[i].linenr then
                next_link_line = link_lines[i].linenr
                next_link_col = link_lines[i].colnr
                vim.api.nvim_win_set_cursor(winnr, { next_link_line, next_link_col })
                clear_text_link()
                return
            end
        end
        if not next_link_line then
            vim.notify("No more links in the buffer")
            return
        end
    else
        vim.notify("There are no link in the buffer")
        return
    end
end

M.hover = function()
    local line = vim.api.nvim_get_current_line()
    local output = find_link_string(line)
    local type_link = is_link(output)
    if type_link then
        output = find_path(output)
        if is_link(output) == "external" then
            return
        end
        if not output then
            vim.notify("Broken or non-existant hyperlink")
            return
        end
        require("lvim-orglinks.preview").open_or_focus(output)
    end
end

return M
