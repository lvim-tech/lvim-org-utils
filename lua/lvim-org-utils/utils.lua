local prompt = require("lvim-org-utils.prompt")

local M = {}

M.merge = function(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            if M.is_array(t1[k]) then
                t1[k] = M.concat(t1[k], v)
            else
                M.merge(t1[k], t2[k])
            end
        else
            t1[k] = v
        end
    end
    return t1
end

M.concat = function(t1, t2)
    for i = 1, #t2 do
        table.insert(t1, t2[i])
    end
    return t1
end

M.is_array = function(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then
            return false
        end
    end
    return true
end

M.table_length = function(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

M.reverse_table = function(t)
    local reversed_table = {}
    local item_count = #t
    for k, v in ipairs(t) do
        reversed_table[item_count + 1 - k] = v
    end
    return reversed_table
end

M.is_contains_value = function(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return { i, v }
        end
    end
    return nil
end

M.index_of = function(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

M.split = function(string, delimiter)
    result = {}
    for match in (string .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

M.file_exists = function(name)
    local f = io.open(name, "r")
    return f ~= nil and io.close(f)
end

M.allow_leave = function()
    prompt.prompt({
        data = {
            title = "Save or lose before leave?",
            lines = {
                {
                    text = "Save",
                    fn = function()
                        vim.cmd([[write!]])
                    end,
                },
                {
                    text = "Lose",
                    fn = function()
                        vim.cmd([[earlier 1f]])
                        vim.cmd([[write!]])
                    end,
                },
                {
                    text = "Cancel",
                    fn = function() end,
                },
            },
        },
        opt = {},
    })
end

M.custom_prompt = function(data)
    prompt.prompt(data)
end

return M
