#!/usr/bin/env lua

function Debug(fmt, ...)
    print(string.format(fmt, ...))
end

function is_table_empty(t)
    for _, __ in pairs(t) do
        return true
    end
    return false
end

function read_until(content, sep, s)
    return string.find(content, sep, s, true)
end


function read_tag_start(content, init) 
    local s, e = read_until(content, '>', init)
    if s then
        -- got a match
        local tagname = string.sub(content, init+1, e-1)
        return tagname, e+1
    else
        -- no more new tag !
        -- so we just done our job
        return nil
    end
end

function read_tag_end(content, tagname, init) 
    Debug('read_tag_end, init=%d, tagname=%s', init, tagname)
    local s, e = read_until(content, string.format('</%s>', tagname), init)
    -- we must read every tag end 
    assert(s)
    Debug('read_tag_end return, s=%d, e=%d', s, e)
    return s, e
end

function parse_xml(content, init)
    local next_pos
    if string.sub(content, init, init+1) == '<' then
        -- we met another xml part
        local new_part
        new_part, next_pos = do_process(content, init)
        assert( not is_table_empty(new_part) )
        return new_part, next_pos
    else
        -- this is the value for last tag, read it!
        local s, e = read_until(content, '<', init)
        assert( s )
        local val = ''
        next_pos = e
        if s == e and s == 1 then
           val = ''
       else
           val = string.sub(content, init, s-1)
       end
       return val, next_pos
    end
end

function do_process(content, init) 
    local xml_part = {}
    local next_pos = init
    while 1 do
        local tagname
        tagname, next_pos = read_tag_start(content, next_pos)
        if not tagname then
            -- done for this part of xml
            return xml_part, init
        else
            -- next is tag
            -- so we add part fot this tag
            xml_part[tagname] = {}
            local part
            part, next_pos = parse_xml(content, next_pos)
            if type(part) == 'string' then
                xml_part[tagname]['>value'] = part
            else
                xml_part[tagname] = part
            end
            local s, e = read_tag_end(content, tagname, next_pos)
            next_pos = e+1
        end
    end
    return xml_part, next_pos
end

function main() 
    local file_content = read_file()
    local parsed_xml = do_process( file_content, 1)
    print( parsed_xml['id']['>value'] )
end

function read_file() 
    local file_content = ''
    if #arg == 1 then
        local file, errmsg = io.open(arg[1], 'r')
        if errmsg then
            print('cannot open file ' .. errmsg )
        else
            file_content = file:read('*a')
        end
    else
        file_content = io.read('*a')
    end
    return file_content
end

main()
