local utf8 = require 'lua-utf8'

function contains(table, value)
  for i = 1,#table do
    if (table[i] == value) then
      return true
    end
  end
  return false
end

local M = {}

M.github_emoji_loaded = false
M.github_emoji = {}
M.outstanding_buffers = {} -- buffer_id -> 0 (uses key to prevent duplicates)

local NOTIFICATION_NAME = "conceal.nvim"
local function log(msg, level)
    -- Filtering for this plugin only
    if level >= M.opts.notify_min_level then
        vim.notify(NOTIFICATION_NAME.. ": " .. msg, level);
    end
end

local function log_trace(msg)
    log(msg, vim.log.levels.TRACE)
end

local function log_debug(msg)
    log(msg, vim.log.levels.DEBUG)
end

local function log_info(msg)
    log(msg, vim.log.levels.INFO)
end

local function log_warn(msg)
    log(msg, vim.log.levels.WARN)
end

local function log_error(msg)
    log(msg, vim.log.levels.ERROR)
end




local ns_id = vim.api.nvim_create_namespace("conceal.nvim")

M.default_opts = {
    priority=111,

    cchars = {
        ["­"]      = '-',  -- Soft Hyphen
        ["⁠"] = '⌿',  -- Word Joiner
        ["​"] = "~",  -- Zero Width Space
        [" "]      = "n",  -- EN SPACE
        [" "]      = "m",  -- EM SPACE
    },

    filetypes = {
        'markdown',
        'typst',
        'gitcommit',
        'text',
    },

    notify_min_level = vim.log.levels.INFO,
}

M.opts = {}



M.conceal_replace = function(buffer, line_index, find, replace)
    local line = vim.api.nvim_buf_get_lines(buffer, line_index, line_index+1, true)[1]

    -- local s,e = utf8.find(line, find)
    local s,e = string.find(line, find)

    while s ~= nil do
        log_debug(string.format("found %s on line %d at (%d, %d)", find, line_index, s-1, e))

        -- Apply a test conceal to the first character of the document
        vim.api.nvim_buf_set_extmark(
            buffer,
            ns_id,
            line_index, s-1,
            {
                end_col = e, -- Conceal the first character
                conceal = replace,
                priority = 111,
            }
        )
        -- s,e = utf8.find(line, find, e+1)
        s,e = string.find(line, find, e+1)
    end
end

M.conceal_github_emojis = function(buffer, line_index)
    local line = vim.api.nvim_buf_get_lines(buffer, line_index, line_index+1, true)[1]

    log_trace("Looking for emoji in " .. line)
    local s,e = string.find(line, ":[^%s:]+:")

    while s ~= nil do

        local markup = string.sub(line, s, e)
        local cchar = M.github_emoji[markup]
        if cchar == nil then
            log_warn(string.format("No github emoji found for `%s`", markup))
        else
            log_trace(string.format("found %s on line %d at (%d, %d)", string.sub(line, s, e), line_index, s-1, e))
            log_trace("Will replace with: "..cchar)

            -- Apply a test conceal to the first character of the document
            vim.api.nvim_buf_set_extmark(
                buffer,
                ns_id,
                line_index, s-1,
                {
                    end_col = e,
                    conceal = cchar,
                    priority = 111,
                }
            )
        end

        s,e = string.find(line, ":[^%s:]+:", e+1)
    end
end


M.conceal_line = function(buffer, line_index)
    for cchar, cstr in pairs(M.opts.cchars) do
        M.conceal_replace(buffer, line_index, cchar, cstr)
    end

    -- GitHub Emoji
    M.conceal_github_emojis(buffer, line_index)
end


M.conceal = function(buffer)
    vim.schedule(function()
        local count = vim.api.nvim_buf_line_count(buffer)
        for i = 0, count-1 do
            M.conceal_line(buffer, i)
        end
    end)
end


M.conceal_outstanding_buffers = function()
    for buffer, _ in pairs(M.outstanding_buffers) do
        log_info(string.format("Processing outstanding buffer: %d", buffer))
        M.conceal(buffer)
    end
end


-- *last* is the index *after* the last line that changed
M.attach_on_lines = function(_, buffer, _, first_row_index, _, new_last_row_index, _)

    if not M.github_emoji_loaded then
        return
    end

    if new_last_row_index - first_row_index == 0 then
        -- The edit was just a delete and the extmarks would have been deleted with the lines.
        return
    end

    log_trace(string.format("Change Range: (%d, %d)", first_row_index, new_last_row_index))

    -- Remove all extmarks between the line range as we will re-add them.
    local marks = vim.api.nvim_buf_get_extmarks(buffer, ns_id, {first_row_index, 0}, {new_last_row_index-1, -1}, {})
    for _, mark in ipairs(marks) do
        local ex_id = mark[1]
        vim.api.nvim_buf_del_extmark(buffer, ns_id, ex_id)
    end

    -- Re-add the extmarks for the modified lines
    for line_index = first_row_index, new_last_row_index - 1 do
        M.conceal_line(buffer, line_index)
    end
end


M.load_github_emoji = function()

    local file = io.open(os.getenv("HOME").."/.local/share/github/emojis.txt","r")
    if file == nil then
        log_error("could not open emojis.txt")
        return
    end

    for line in file:lines() do
        if utf8.sub(line, 1, 1) ~= "-" then
            local s, e, cchar = string.find(line, "(.+)	")
            if s ~= nil then
                s, e = string.find(line, ":.+:")
                if s ~= nil then
                    local markup = string.sub(line, s, e)
                    log_trace("Parsed markup: "..markup)
                    M.github_emoji[markup] = cchar
                end
            end
        end
    end
    file:close()

    M.github_emoji_loaded = true

    vim.schedule(M.conceal_outstanding_buffers)
end

M.setup = function(opts)
    M.opts = vim.tbl_deep_extend('keep', opts, M.default_opts)

    vim.schedule(M.load_github_emoji)

    vim.api.nvim_create_autocmd("FileType", {
        callback = function()
            local current_filetype = vim.api.nvim_get_option_value('filetype', {buf=0})
            if not contains(M.opts.filetypes, current_filetype) then
                -- not a requested file type
                return
            end

            vim.api.nvim_buf_attach(0, false, {
                on_lines = function(type, buf, changedtick, first_row_index, last_row_index, new_last_row_index, byte_count)
                    vim.schedule(function ()
                        M.attach_on_lines(type, buf, changedtick, first_row_index, last_row_index, new_last_row_index, byte_count)
                    end)
                end

            })

            if M.github_emoji_loaded then
                -- Maybe putting this in schedule helps the file initialize and display quicker
                vim.schedule(function()
                    -- Add extmarks through the whole file
                    M.conceal(0)
                end)
            else
                local buffer_id = vim.api.nvim_get_current_buf()

                M.outstanding_buffers[buffer_id] = 0
            end
        end,
        desc = "Initialize conceal",
    })
end

return M
