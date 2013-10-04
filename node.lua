Node = { children={}, attrs={}, value='', single=false}
Node.mt = {__index=Node}
local FirstArgIsNotANode = 'first arg is not a node!'
local SecondArgIsNotANode = 'second arg is not a node!'
local ArgIsNotANode = 'arg is not a node!'

function Node.Node(name)
    if type(name) ~= 'string' then
        error('arg name is not string!', 2)
    end
    local node = {}
    node['name'] = name
    setmetatable(node, Node.mt)
    return node
end

function is_a_node(n)
    return getmetatable(n) == Node.mt
end

function Node.IsNode(n)
    return is_a_node(n)
end

function Node.SetParent(parent, child)
    if not is_a_node(parent) then
        error(FirstArgIsNotANode, 2)
    end

    if not is_a_node(child) then
        error(SecondArgIsNotANode, 2)
    end
    child['parent'] = parent
end

function Node.GetParent(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end

    return node['parent']
end

function Node.GetName(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end
    return node['name']
end


function Node.SetAttrs(node, attrs)
    if not is_a_node(node) then
        error(FirstArgIsNotANode, 2)
    end
    if type(attrs) ~= 'table' then
        error('attrs must be a table!', 2)
    end
    node['attrs'] = attrs
end

function Node.GetAttrs(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end
    return node.attrs
end

function Node.SetValue(node, val)
    if not is_a_node(node) then
        error(FirstArgIsNotANode, 2)
    end

    node['value'] = val
end

function Node.GetValue(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end

    return node['value']
end

function Node.FirstChild(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end

    return #node['children'] ~= 0 and node['children'][1] or nil
end

function Node.SetPrev(node, prevNode)
    if not is_a_node(node) then
        error(FirstArgIsNotANode, 2)
    end

    if not is_a_node(prevNode) then
        error(SecondArgIsNotANode, 2)
    end
    node['prev'] = prevNode
end

function Node.SetNext(node, nextNode)
    if not is_a_node(node) then
        error(FirstArgIsNotANode, 2)
    end

    if not is_a_node(nextNode) then
        error(SecondArgIsNotANode, 2)
    end
    node['next'] = nextNode
end

function Node.AddChild(node, childNode)
    if not is_a_node(node) then
        error(FirstArgIsNotANode, 2)
    end
    if not is_a_node(childNode) then
        error(SecondArgIsNotANode, 2)
    end

    childNode:SetParent(node)
    local idx = #node['children'] + 1
    if idx >= 2 then
        local prevNode = node['children'][idx-1]
        childNode:SetPrev(prevNode)
        prevNode:SetNext(childNode)
    end
    node['children'][idx] = childNode
end

function Node.GetChildren(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end
    return node['children']
end

function Node.NextSibling(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end
    return node['next']
end

function Node.PrevSibling(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end
    return node['prev']
end

function Node.SetSingle(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end
    node['single'] = true
end

function Node.IsSingle(node)
    if not is_a_node(node) then
        error(ArgIsNotANode, 2)
    end
    return node['single']
end
