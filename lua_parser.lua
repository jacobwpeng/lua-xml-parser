#!/usr/bin/env lua

indent_per_level = 5

function debug(fmt, ...)
    --print(string.format(fmt, ...))
    --print(string.rep('-', 160) )
end

function output(fmt, ...)
    print(string.format(fmt, ...))
end

function is_table_empty(t)
    assert( type(t) == 'table' )
    for _, _ in pairs(t) do
        return false
    end
    return true
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

function read_until(content, sep, start, skip_ws)
    return string.find(content, sep, start, true)
end

function next_char(content, start)
    return string.sub(content, start, start)
end

function is_next_char_ws(content, start)
    local c = next_char(content, start)
    return c == ' ' or c == '\t' or c == '\n' or c == '\t'
end

function strip_heading_ws(content, start)
    while is_next_char_ws(content, start) do
        start = start + 1
    end
    return start
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

function read_attr(content, start)
    local patt = '(%w+)="(.+)"'
    return content.match(content, patt, start)
end

function read_attrs(attr_part)
    local value = {}
    for k, v in string.gmatch(attr_part, '(%w+)="(.-)"') do
        value[k] = v
    end
    return value
end

function try_read_declaration(content, start)
    start = strip_heading_ws(content, start)
    local m = string.match(content, '<?xml.+?>', start)
    if not m then
        return nil
    end
    local s, attr_part_start = read_until(content, '<?xml', start)
    local s, attr_part_end = read_until(content, '?>', start)
    local declaration_line_attr_part = string.sub(content, attr_part_start, attr_part_end- 1 )
    return read_attrs(declaration_line_attr_part), attr_part_end + 1
end

--input  : the file content and the pos where to start
--output : if succeed, first param return begin of this tag, then the second is the end of this tag
--         else first param is false
function try_read_tag(content, start)
    debug("try_read_tag processing : '%s', start=%d, len=%d", string.sub(content, start), start, string.len(content))
    if start == string.len(content) then
        return false
    end
    start = strip_heading_ws(content, start)
    assert( next_char(content, start) == '<' )
    if string.match(content, "^</", start) then
        return false
    end
    -- read comment
    if string.match(content, "^<!--", start) then
        start = read_comment(content, start)
    end
    start = strip_heading_ws(content, start)
    local pos, tag_end = read_until(content, '>', start)
    assert( pos )
    local ws_start, tag_name_end = read_until(content, ' ', start)
    if tag_end < tag_name_end then
        --no attrs!
        ws_start = nil
    end
    local tag_name
    local is_single_tag
    local attrs = {}

    if next_char(content, tag_end - 1) == '/' then
        is_single_tag = true
    end
    if not ws_start then
        --this tag has no attrs
        tag_name = string.sub(content, start + 1, tag_end - 1)
    else
        --this tag has some attrs
        local attr_start = ws_start + 1
        local attr_end = tag_end - 1
        if is_single_tag then
            attr_end = attr_end - 1
        end
        tag_name = string.sub(content, start + 1, ws_start - 1)
        local attr_part = string.sub(content, attr_start, attr_end)
        local attrs = read_attrs(attr_part)
        if is_table_empty(attrs) == false then
            output('attrs of %s : ', tag_name)
            walk_table(attrs)
        end
    end
        
    return tag_name, tag_end + 1 , is_single_tag, is_table_empty(attrs) == false and attrs or nil
end

function read_tag_content(content, start, tag_name)
    assert( tag_name and type(tag_name) == 'string')
    debug("read_tag_content tag_name=%s, processing : '%s'", tag_name, string.sub(content, start) )
    local value = {}
    start = strip_heading_ws(content, start)
    if next_char(content, start) == '<' then
        local pos = start
        while true do
            --read as more tags as possible
            local new_tag_name, next_start, this_tag_value, is_single_tag
            new_tag_name, next_start, is_single_tag = try_read_tag(content, pos)
            if is_single_tag then
                output('%s is single tag', new_tag_name)
            end
            if new_tag_name then
                if not is_single_tag then
                    this_tag_value, next_start = read_tag_content(content, next_start, new_tag_name)
                else
                    this_tag_value = ""
                end
                if value[new_tag_name] and type(value[new_tag_name]) == 'table' then
                    value[new_tag_name][(#value[new_tag_name])+1] = this_tag_value

                elseif value[new_tag_name] then
                    local tmp_table = value[new_tag_name]
                    value[new_tag_name] = {}
                    value[new_tag_name][1] = tmp_table
                    value[new_tag_name][2] = this_tag_value
                else
                    value[new_tag_name] = this_tag_value
                end
                if not is_single_tag then
                    next_start = read_tag_end(content, next_start, new_tag_name)
                end
                pos = next_start
            else
                break
            end
        end
        return value, pos
    else
        local tag_end_str = string.format('</%s>', tag_name)
        local value_start, value_end = read_until(content, tag_end_str, start)
        if value_start then
            local next_start = value_end - string.len(tag_end_str)
            local value = string.sub(content, start, next_start)
            -- remove comment in value
            value = string.gsub(value, "<!--.-->", '')
            debug( 'value=%s', value)
            return value, next_start + 1
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
    local dec, start = try_read_declaration(file_content, 1)
    start = start and start or 1
    local tagname, next_start = try_read_tag(file_content, start)
    if tagname then
        local value, next_pos = read_tag_content(file_content, next_start, tagname)
        next_pos = read_tag_end(file_content, next_pos, tagname)
        if type(value) == 'string' then
            output('value=%s', value)
        elseif type(value) == 'table' then
            walk_table(value)
        end
    end
end

main()
