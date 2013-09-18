#!/usr/bin/env lua

indent_per_level = 5

function debug(fmt, ...)
    --print(string.format(fmt, ...))
end

function output(fmt, ...)
    print(string.format(fmt, ...))
end

function walk_table(t, indent)
    indent = indent or 0
    local indent_str = string.rep(' ', indent)
    for k, v in pairs(t) do
        print( string.format('%skey : %q', indent_str, k) )
        if type(v) == 'table' then
            walk_table(v, indent + indent_per_level)
        else
            print( string.format('%svalue : %q', indent_str, v) )
        end
    end
end

function read_file() 
    local file_content = ''
    if #arg == 1 then
        local file, errmsg = io.open(arg[1], 'r')
        if errmsg then
            debug('cannot open file, %s', errmsg)
        else
            file_content = file:read('*a')
        end
    else
        file_content = io.read('*a')
    end
    return file_content
end

function strip_all_white_chars(file_content)
    return string.gsub(file_content, '[\n\t ]', '')
end

function read_until(content, sep, start)
    return string.find(content, sep, start, true)
end

function next_char(content, start)
    return string.sub(content, start, start)
end

function read_comment(content, start)
    local tag_start, tag_end = read_until(content, "-->", start)
    if tag_start then
        output('remove comment "%s"', string.sub(content, start, tag_end) )
        return tag_end + 1
    else
        assert( false )
    end
end

--input  : the file content and the pos where to start
--output : if succeed, first param return begin of this tag, then the second is the end of this tag
--         else first param is false
function try_read_tag(content, start)
    debug("try_read_tag processing : '%s'", string.sub(content, start) )
    if string.match(content, "^</", start) then
        return false
    end
    if string.match(content, "^<!--", start) then
        start = read_comment(content, start)
    end
    local tag_start, tag_end = read_until(content, '>', start)
    if tag_start then
        local pos, next_tag_end = read_until(content, '/>', start)
        local tag_name = string.sub(content, start+1 , tag_end-1)
        local is_single_tag = false
        if string.sub(tag_name, string.len(tag_name) ) == '/' then
            tag_name = string.sub(tag_name, 0, string.len(tag_name) -1 )
            is_single_tag = true
        end
        return tag_name, tag_end + 1, is_single_tag
    else
        return false
    end
end

function read_tag_content(content, start)
    debug("read_tag_content processing : '%s'", string.sub(content, start) )
    local value = {}
    if next_char(content, start) == '<' then
        local pos = start
        while true do
            local tagname, next_start, this_tag_value, is_single_tag
            tagname, next_start, is_single_tag = try_read_tag(content, pos)
            if is_single_tag then
                output('%s is single tag', tagname)
            end
            if tagname then
                if not is_single_tag then
                    this_tag_value, next_start = read_tag_content(content, next_start)
                else
                    this_tag_value = ""
                end
                if value[tagname] and value[tagname][1]then
                    value[tagname][#value[tagname]+1] = this_tag_value
                elseif value[tagname] then
                    local tmp_table = value[tagname]
                    value[tagname] = {}
                    value[tagname][1] = tmp_table
                    value[tagname][2] = this_tag_value
                else
                    value[tagname] = this_tag_value
                end
                if not is_single_tag then
                    next_start = read_tag_end(content, next_start, tagname)
                end
                pos = next_start
            else
                break
            end
        end
        return value, pos
    else
        local value_start, value_end = read_until(content, "<", start)
        if value_start then
            return string.sub(content, start, value_end - 1), value_end
        else
            assert( false )
        end

    end
end

function read_tag_end(content, start, tagname)
    debug("read_tag_end, tagname=%s, processing : '%s'", tagname, string.sub(content, start) )
    local s, e = read_until(content, string.format("%s>", tagname), start)
    if s then
        return e + 1
    else
        assert( false )
    end
end


function main()
    local file_content = read_file()
    file_content = strip_all_white_chars(file_content)
    local tagname, next_start = try_read_tag(file_content, 1)
    if tagname then
        local value, next_pos = read_tag_content(file_content, next_start)
        next_pos = read_tag_end(file_content, next_pos, tagname)
        if type(value) == 'string' then
            output('value=%s', value)
        elseif type(value) == 'table' then
            walk_table(value)
        end
    end
end

main()
