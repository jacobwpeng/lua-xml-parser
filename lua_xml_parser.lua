#!/usr/bin/env lua

require 'node'

indent_per_level = 5

function enable_debug(fmt, ...)
    print(string.format(fmt, ...))
    print(string.rep('-', 160) )
end

function disable_debug(fmt, ...) end

function output(fmt, ...)
    print(string.format(fmt, ...))
end

function is_table_empty(t)
    assert( type(t) == 'table' )
    return next(t) == nil
end

function walk_table(t, indent)
    assert( type(t) == 'table' )
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
            DEBUG('cannot open file, %s', errmsg)
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
    return c == ' ' or c == '\t' or c == '\n' or c == '\r'
end

function strip_heading_ws(content, start)
    while is_next_char_ws(content, start) do
        start = start + 1
    end
    return start
end

function remove_all_comments(content, start)
    local patt = '<!%-%-.-%-%->'
    return string.gsub(content, patt, '')
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
--output : if succeed, return (tagname, next_start, is_single_tag, attrs), single tag is a tag just like '<tagname />', attrs is nil if no attrs
--         else return false
function try_read_tag(content, start)
    DEBUG("try_read_tag processing : '%s', start=%d, len=%d", string.sub(content, start), start, string.len(content))
    if start == string.len(content) then
        return false
    end
    start = strip_heading_ws(content, start)
    assert( next_char(content, start) == '<' )

    if string.match(content, "^</", start) then
        return false
    end

    start = strip_heading_ws(content, start)
    local pos, tag_end = read_until(content, '>', start)
    assert( pos )
    local ws_start, tag_name_end = read_until(content, ' ', start)
    if ws_start and tag_end < tag_name_end then
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
        attrs = read_attrs(attr_part)
    end
        
    local node = Node.Node(tag_name)
    if is_single_tag then
        node:SetSingle()
    end
    if is_table_empty(attrs) == false then
        node:SetAttrs(attrs)
    end
    return node, tag_end + 1
end

function read_tag_content(content, start, tag_name)
    assert( tag_name and type(tag_name) == 'string')
    DEBUG("read_tag_content tag_name=%s, processing : '%s'", tag_name, string.sub(content, start) )
    start = strip_heading_ws(content, start)
    local this_node = Node.Node(tag_name)
    if next_char(content, start) == '<' then
        local pos = start
        while true do
            --read as more tags as possible
            local new_tag_name, next_start, this_tag_value, is_single_tag
            local child, next_start = try_read_tag(content, pos)
            --new_tag_name, next_start, is_single_tag, attrs = try_read_tag(content, pos)
            if child then
                if not child:IsSingle() then
                    this_tag_value, next_start = read_tag_content(content, next_start, child:GetName())
                else
                    this_tag_value = ""
                end
                child:SetValue(this_tag_value)
                this_node:AddChild(child)
                if not child:IsSingle() then
                    next_start = read_tag_end(content, next_start, child:GetName())
                end
                pos = next_start
            else
                break
            end
        end
        return this_node, pos
    else
        local tag_end_str = string.format('</%s>', tag_name)
        local value_start, value_end = read_until(content, tag_end_str, start)
        if value_start then
            local next_start = value_end - string.len(tag_end_str)
            local value = string.sub(content, start, next_start)
            return value, next_start + 1
        else
            assert( false )
        end

    end
end

function read_tag_end(content, start, tagname)
    DEBUG("read_tag_end, tagname=%s, processing : '%s'", tagname, string.sub(content, start) )
    local s, e = read_until(content, string.format("%s>", tagname), start)
    if s then
        return e + 1
    else
        assert( false )
    end
end

function main()
    local file_content = read_file()
    file_content = remove_all_comments(file_content)
    local dec, start = try_read_declaration(file_content, 1)
    start = start and start or 1
    local root, next_start = try_read_tag(file_content, start)
    if root then
        local root_value, next_pos = read_tag_content(file_content, next_start, root:GetName())
        next_pos = read_tag_end(file_content, next_pos, root:GetName())
        if type(root_value) == 'string' then
            root:SetValue(root_value)
        elseif Node.IsNode(root_value) then
            root:AddChild(root_value)
        else
            assert(false)
        end
    end
end

function trace (event, line)
    local s = debug.getinfo(2).short_src
    print(s .. ":" .. line)
end
--debug.sethook(trace, "l")
--DEBUG = enable_debug
DEBUG = disable_debug
main()
