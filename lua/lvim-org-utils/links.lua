local M = {}
local config = require("lvim-org-utils.config")
local utils = require("lvim-org-utils.utils")
local select = require("lvim-org-utils.select")
local custom_popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local links = {}
local links_index = nil

local check_is_link = function(link_string)
    if link_string ~= nil then
        if string.match(link_string, "[a-z]*://[^ >,;]*") then
            return "external"
        elseif link_string:match("^/") then
            return "full_path"
        elseif link_string:match("^~/") then
            return "home_path"
        elseif link_string:match("^./") then
            return "relative_path"
        elseif link_string:match("^../") then
            return "relative_path_back"
        else
            return false
        end
    else
        return false
    end
end

local check_is_org = function(link)
    if link:match("[^.]+$") == "org" then
        return true
    end
    return false
end

local find_link_string = function(link_string)
    result = string.gsub(link_string, "%[%[(.-)%]%[?(.-)%]?%]", function(link, _)
        return link
    end)
    return result
end

local find_links_position = function(line, linenr)
    local links_position = {}
    local i = 0
    while true do
        i = string.find(line, "%[%[(.-)%]%[?(.-)%]?%]", i + 1)
        if i == nil then
            break
        end
        table.insert(links_position, { i, linenr })
    end
    return links_position
end

local open_external_link = function(link)
    if not vim.g.loaded_netrwPlugin then
        vim.notify("Netrw plugin must be loaded in order to open urls.")
        return
    end
    return vim.fn["netrw#BrowseX"](link, vim.fn["netrw#CheckIfRemote"]())
end

local next_link = function()
    local winnr = vim.api.nvim_get_current_win()
    local cursor_position = vim.api.nvim_win_get_cursor(winnr)
    local lines = vim.api.nvim_buf_get_lines(0, cursor_position[1] - 1, -1, false)
    for i, line in ipairs(lines) do
        local links_position = find_links_position(line, (cursor_position[1] - 1) + i)
        if next(links_position) then
            for _, link_position in ipairs(links_position) do
                if cursor_position[1] == link_position[2] then
                    if cursor_position[2] < link_position[1] - 1 then
                        vim.api.nvim_win_set_cursor(winnr, { link_position[2], link_position[1] })
                        return true
                    end
                else
                    vim.api.nvim_win_set_cursor(winnr, { link_position[2], link_position[1] })
                    return true
                end
            end
        end
    end
    return false
end

local prev_link = function()
    local winnr = vim.api.nvim_get_current_win()
    local cursor_position = vim.api.nvim_win_get_cursor(winnr)
    local _lines = vim.api.nvim_buf_get_lines(0, 0, cursor_position[1], false)
    local lines = utils.reverse_table(_lines)
    for i, line in ipairs(lines) do
        local _links_position = find_links_position(line, (cursor_position[1] + 1) - i)
        local links_position = utils.reverse_table(_links_position)
        if next(links_position) then
            for _, link_position in ipairs(links_position) do
                if cursor_position[1] == link_position[2] then
                    if cursor_position[2] > link_position[1] + 1 then
                        vim.api.nvim_win_set_cursor(winnr, { link_position[2], link_position[1] })
                        return true
                    end
                else
                    vim.api.nvim_win_set_cursor(winnr, { link_position[2], link_position[1] })
                    return true
                end
            end
        end
    end
    return false
end

local create_file = function(file)
    local path = vim.fn.fnamemodify(file, ":p:h")
    vim.api.nvim_command("silent !mkdir -p " .. path .. " && touch " .. file)
    local is_file_exist = utils.file_exists(file)
    if is_file_exist then
        vim.cmd("e " .. file)
    else
        vim.notify("Error creating file:\n" .. file, "error", {
            title = "LVIM ORG",
        })
    end
end

local link_open = function(file)
    local is_file_exist = utils.file_exists(file)
    if is_file_exist then
        if vim.bo.modified then
            select(
                { "Save", "Lose", "Show full path", "Cancel" },
                { prompt = "Save or lose before leave?" },
                function(choice)
                    if choice == "Save" then
                        vim.cmd("write!")
                        vim.cmd("e " .. file)
                    elseif choice == "Lose" then
                        vim.cmd("earlier 1f")
                        vim.cmd("write!")
                        vim.cmd("e " .. file)
                    elseif choice == "Show full path" then
                        vim.notify("Full path of file:\n" .. file, "info", {
                            title = "LVIM ORG",
                        })
                    end
                end
            )
        else
            vim.cmd("e " .. file)
        end
    else
        if vim.bo.modified then
            select({
                "Save this file and create new file",
                "Lose changes of this file and create new file",
                "Show full path",
                "Cancel",
            }, { prompt = "File not exist!" }, function(choice)
                if choice == "Save this file and create new file" then
                    vim.cmd("write!")
                    create_file(file)
                elseif choice == "Lose changes of this file and create new file" then
                    vim.cmd("earlier 1f")
                    vim.cmd("write!")
                    vim.cmd("e " .. file)
                elseif choice == "Show full path" then
                    vim.notify("Full path of file:\n" .. file, "info", {
                        title = "LVIM ORG",
                    })
                end
            end)
        else
            select({ "Create new file", "Show full path", "Cancel" }, { prompt = "File not exist!" }, function(choice)
                if choice == "Create new file" then
                    create_file(file)
                elseif choice == "Show full path" then
                    vim.notify("Full path of file:\n" .. file, "info", {
                        title = "LVIM ORG",
                    })
                end
            end)
        end
    end
end

local word_normalizer = function()
    local winnr = vim.api.nvim_get_current_win()
    local line = vim.api.nvim_get_current_line()
    local word = vim.fn.expand("<cWORD>")
    local word_escape = utils.regex_escape(word)
    local cursor_position = vim.api.nvim_win_get_cursor(winnr)
    local links_position = find_links_position(line, 0)
    local all_links_position = {}
    local all_links_position_reverse = {}
    if next(links_position) then
        for _, link_position in ipairs(links_position) do
            table.insert(all_links_position, link_position[1])
        end
        all_links_position_reverse = utils.reverse_table(all_links_position)

        for _, all_link_position_reverse in ipairs(all_links_position_reverse) do
            if cursor_position[2] >= all_link_position_reverse then
                vim.api.nvim_win_set_cursor(winnr, { cursor_position[1], all_link_position_reverse })
                break
            end
        end
    end
    word = vim.fn.expand("<cWORD>")
    word_escape = utils.regex_escape(word)
    if string.find(word, "%[%[") then
        i, j = string.find(line, word_escape .. "? (.-)%]%]")
    end
    if type(i) == "number" and type(j) == "number" then
        word = string.sub(line, i, j)
        return word
    end
    return nil
end

local link_prepare = function()
    local word = vim.fn.expand("<cWORD>")
    if not string.find(word, "%[%[(.-)%]%[?(.-)%]?%]") then
        word = word_normalizer()
    end
    if word ~= nil then
        local link = find_link_string(word)
        local is_external = false
        local is_link = check_is_link(link)
        if is_link == "external" then
            is_external = true
        elseif check_is_org(link) then
            if is_link == "home_path" then
                local home_path = os.getenv("HOME")
                link = link:gsub("^~", home_path)
            elseif is_link == "relative_path" then
                local current_path = vim.fn.expand("%:p:h")
                link = link:gsub("^.", current_path)
            elseif is_link == "relative_path_back" then
                local current_path = vim.fn.expand("%:p:h")
                local split_current_path = utils.split(current_path, "/")
                table.remove(split_current_path, 1)
                local link_length = string.len(link)
                local counter = 0
                while true do
                    link = link:gsub("^../", "")
                    if string.len(link) < link_length then
                        link_length = string.len(link)
                        counter = counter + 1
                    else
                        break
                    end
                end
                local split_link_length = #split_current_path - counter
                local real_link = ""
                for index, value in ipairs(split_current_path) do
                    if index <= split_link_length then
                        real_link = real_link .. "/" .. value
                    end
                end
                link = real_link .. "/" .. link
            end
        else
            return { nil, nil }
        end
        return { link, is_external }
    end
    return nil
end

local open = function()
    local link = link_prepare()
    if link ~= nil then
        if link[1] ~= nil and link[2] then
            open_external_link(link[1])
        elseif link[1] ~= nil then
            link_open(link[1])
        end
    end
end

local preview_open = function(link)
    assert(popup_reference == nil, "Sorry")
    popup_reference = custom_popup({
        enter = true,
        focusable = false,
        border = {
            highlight = "NuiBorder",
            style = { " ", " ", " ", " ", " ", " ", " ", " " },
            text = {
                top = "PREVIEW",
                top_align = "center",
            },
        },
        position = "50%",
        size = {
            width = "80%",
            height = "60%",
        },
        buf_options = {
            filetype = "org",
            modifiable = true,
            readonly = true,
        },
        win_options = {
            winblend = 10,
            winhighlight = "Normal:NuiBody,FloatBorder:NuiBorder",
        },
    })
    if popup_reference ~= nil then
        local is_file_exist = utils.file_exists(link)
        if is_file_exist then
            local lines = {}
            local link_file = io.open(link, "r")
            if not link_file then
                return
            end
            for line in link_file:lines() do
                table.insert(lines, line)
            end
            io.close(link_file)
            vim.api.nvim_buf_set_lines(popup_reference.bufnr, 0, 1, false, lines)
            popup_reference:mount()
            popup_reference:on(event.BufLeave, function()
                popup_reference:unmount()
                popup_reference = nil
            end)
            popup_reference:map("n", "<esc>", function()
                popup_reference:unmount()
                popup_reference = nil
            end, { noremap = true })
            popup_reference:map("n", "q", function()
                popup_reference:unmount()
                popup_reference = nil
            end, { noremap = true })
        else
            popup_reference = nil
            vim.notify("File is not exist:\n" .. vim.inspect(link), "error", {
                title = "LVIM ORG",
            })
        end
    end
end

local preview = function()
    local link = link_prepare()
    if link ~= nil then
        if link[1] ~= nil and link[2] then
            open_external_link(link[1])
        elseif link[1] ~= nil then
            preview_open(link[1])
        end
    end
end

local next_file = function()
    if links_index == #links then
        vim.notify("This is a last file", "info", {
            title = "LVIM ORG",
        })
    else
        links_index = links_index + 1
        vim.cmd("e " .. links[links_index])
    end
end

local prev_file = function()
    if links_index == 1 then
        vim.notify("This is a first file", "info", {
            title = "LVIM ORG",
        })
    else
        links_index = links_index - 1
        vim.cmd("e " .. links[links_index])
    end
end

M.navigation = function()
    local current_path = vim.fn.expand("%:p")
    if utils.is_contains_value(links, current_path) ~= nil then
        links_index = utils.index_of(links, current_path)
    else
        links_index = #links + 1
        links[links_index] = current_path
    end
end

M.init = function()
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "org",
        callback = function()
            vim.keymap.set("n", config.links.keymaps.open, open, { buffer = true })
            vim.keymap.set("n", config.links.keymaps.next_file, next_file, { buffer = true })
            vim.keymap.set("n", config.links.keymaps.prev_file, prev_file, { buffer = true })
            vim.keymap.set("n", config.links.keymaps.next_link, next_link, { buffer = true })
            vim.keymap.set("n", config.links.keymaps.prev_link, prev_link, { buffer = true })
            vim.keymap.set("n", config.links.keymaps.preview, preview, { buffer = true })
        end,
        group = "LvimOrgUtils",
    })
end

return M
