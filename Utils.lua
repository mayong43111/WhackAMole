local addon, ns = ...
local WhackAMole = _G[addon]

-- Utils.lua
local lower = string.lower

-- Converts `s' to a SimC-like key
function ns.formatKey( s )
    return ( lower( s or '' ):gsub( "[^a-z0-9_ ]", "" ):gsub( "%s", "_" ) )
end

function ns.deepCopy( orig )
    local orig_type = type( orig )
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[ ns.deepCopy( orig_key ) ] = ns.deepCopy( orig_value )
        end
        setmetatable( copy, ns.deepCopy( getmetatable( orig ) ) )
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Simple error printing
function ns.Error(...)
    print("|cffff0000WhackAMole Error:|r", ...)
end
