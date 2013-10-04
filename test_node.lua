require 'node'

function main()
    local first = Node.Node()
    local second = Node.Node()
    local third = Node.Node()
    local root = Node.Node()

    local first_attr = { first = '1' }

    first:SetValue('first')
    first:SetAttrs(first_attr)
    second:SetValue('second')
    third:SetValue('third')

    root:AddChild(first)
    root:AddChild(second)
    root:AddChild(third)
    local child = root:FirstChild()
    while child do
        for k, v in pairs(child:GetAttrs()) do
            print( k, v )
        end
        print( child:GetValue() )
        child = child:NextSibling()
    end
end

main()
