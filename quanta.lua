local quanta = {}

local function dump(thing, depth)
    if type(thing) ~= "table" then return type(thing) == "string" and "\""..thing.."\"" or tostring(thing) end
    depth = depth or 1
    local build = "{"
    local prefix = ("  "):rep(depth)
    local any = false
    for i,v in pairs(thing) do
        any = true
        build = build.."\n"..prefix
              .."["..(type(i) == "string" and "\""..i.."\"" or tostring(i)).."]"
              .." = "..dump(v, depth + 1)..","
    end
    return any and build:sub(1, -2).."\n"..prefix:sub(1, -2).."}" or "{}"
end
quanta.dump = dump;

quanta.types = {
    word         = 0,
    string       = 1,
    modifier     = 2,
    object       = 3,
    attribute    = 4,
    flag         = 5,
}

function quanta.parse(str)
    local function errchar(at, err)
        at = at + 1
        str = "\n"..str
        local _, lines = str:sub(0, at):gsub("\n", "\n")
        local    chars = str:sub(0, at):match(".*\n()")
        error("Error at "..lines..":"..(at - chars + 1)..": "..err, 3)
    end

    local aliases = {}
    local tokens = {}
    local at = 1

    local function push(token, type, offset)
        table.insert(tokens, {token = token, type = type, at = at})
        at = at + #token + (offset or 0)
    end
    
    local types = quanta.types
    repeat
        local uh = str:sub(at):match("^%s+()") -- skip whitespace
        at = at + (uh and (uh - 1) or 0)       -- offset
        local strn = str:sub(at)
        if strn:sub(1, 2) == "::" then -- handle strings
            local from, to = strn:gsub("\\.", "__"):match("^::().-()::") -- we only need to worry about the last backslash
            if not from then errchar(at, "Unclosed string") end
            push(strn:sub(from, to - 1), types.string, 4)
            table.insert(aliases, strn:sub(from, to - 1))
        elseif strn:sub(1, 1) == "[" then -- handle objects
            if not strn:match("^%b[]") then errchar(at, "Unclosed object definition") end
            push(strn:match("^%b[]"):sub(2, -2), types.object, 2)
        elseif strn:sub(1, 1) == "{" then -- handle attributes
            if not strn:match("^%b{}") then errchar(at, "Unclosed attribute definition") end
            push(strn:match("^%b{}"):sub(2, -2), types.attribute, 2)
        elseif strn:sub(1, 1) == "<" then -- handle modifiers
            if not strn:match("^%b<>") then errchar(at, "Unclosed modifier definition") end
            push(strn:match("^%b<>"):sub(2, -2), types.modifier, 2)
        elseif strn:sub(1, 1) == "@" then -- handle flags
            local ah = strn:match("^@([^@%[%]{}<>%s]+)"):gsub("([-:])%1.*$", "") -- same as word pattern, plus the at symbol
            if not ah then push("@", types.word, 0); goto continue end -- can just be a word instead if invalid, not that critical
            push(ah, types.flag, 1)
        elseif strn:sub(1, 2) == "--" then -- comment handling
            local at2 = 3
            -- case where there's no strings in the line
            if not (strn:match("^%-%-(.-)\n") or ""):match("::") then at = at + (strn:match("^%-%-.-()\n") or #strn); goto continue end
            while strn:sub(at2):match("^.-::.-\n") do -- otherwise...
                local set = strn:sub(at2)
                local first = set:match("()::") -- find the first string
                local from, to = set:sub(first):gsub("\\.", "__"):match("^::().-()::") -- same method as before
                if not from then errchar(at, "Unclosed block comment string") end
                table.insert(aliases, set:sub(from, to))
                at2 = at2 + to + 2 -- this time we keep going
            end
            at2 = at2 + #(strn:sub(at2):match("^(.-)\n") or "") -- final case
            at = at + at2
        else -- handle words
            local word = (strn:match("^([^@%[{<%s]+)") or ""):gsub("([-:])%1.*$", "") -- matches up until any special characters, then trim off the start of a string or comment
            if #word > 0 then push(word, types.word, 0) end
        end
        ::continue::
    until at >= #str

    local function parsetype(thing)
            if thing == "true" or thing == "false" then return thing == true
        elseif thing == "none" then return nil
        elseif thing:match("^%$.-;$") then
            local a = thing:match("%$(.-);")
            return aliases[tonumber(a) or a] -- compatibility
        elseif thing:match("^%-?%d-%.?%d+$")                     -- base 10
            or thing:match("^%-?0x[0-9a-fA-F]-%.?[0-9a-fA-F]+$") -- base 16
            or thing:match("^%-?0b[01]-%.?[01]+$")               -- base 2
            or thing:match("^%-?0t[012]-%.?[012]+$")             -- base 3
            or thing:match("^%-?0s[012345]-%.?[012345]+$")       -- base 6 (hello jan misali)
            or thing:match("^%-?0i1-%.?1+$")                     -- tally marks
            or thing:match("^%-?0d[0-9abAB]-%.?[0-9abAB]$")      -- base 12
            or thing:match("^%-?%d-%.?%d+[eE][%+%-]?%d+$") then  -- base 10 w/ E notation
            local base = ({x=16, b=2, t=3, s=6, i=1, d=12})[thing:match("0([xbtid])") or ""] or 10
            if base == 10 then return tonumber(thing) end
            if base == 1 then
                return (thing:sub(1, 1) == "-" and -1 or 1) *
                       #thing:match("0i(1+)") +
                       1 / (#(thing:match("%.(1+)$") or "") + 1) -- enjoy the jank :)
            end
            if thing:match("^%-?0[xbtsid].-%..-$") then
                local num = tonumber(thing:match("^(.-)%."), base)
                local frac = thing:match("%.(.-)$")
                for i=1, #frac do num = num + tonumber(frac:sub(i, i), base) / base end
                return num
            else
                return tonumber(thing:gsub("^(%-?)0.", "%1"), base)
            end
        else return thing end
    end
    local function parsestring(str)
        local nstr = ""
        local i = 1
        local function s() return s end
        local function try(pattern, with, offset)
            local match = str:sub(i):match("^"..pattern)
            if match then
                nstr = nstr..with(match)
                i = i + #match + offset
                return s
            end
            return try
        end
        repeat
            try ("\\u{(%x+)}", function(a)    
                    return utf8.char(tonumber(a, 16))
                end, 4 -- looks stupid but lua doesn't know how to parse it otherwise
                )("\\x(%x%x)", function(a)
                    return utf8.char(tonumber(a, 16))
                end, 2
                )("\\c(.)", function(a)
                    return string.char(string.byte(a) % 32) -- same as a && 31
                end, 2
                )("\\([ntrbf0vae])", function(a)
                    return ({
                        ["0"] = "\0",
                            n = "\n",
                            t = "\t",
                            r = "\r",
                            b = "\b",
                            f = "\f",
                            v = "\v",
                            a = "\a",
                            e = "\x1B",
                    })[a]
                end, 1
                )("\\(.)",    function(a) return a end, 1
                )("([^\\]+)", function(a) return a end, 0)
        until i > #str
        return nstr
    end

    local gpath = ""
    local function set(t, path, v)
        if path:sub(2):gsub("\\.", "__"):match("[:#]") then
            local to  = path:gsub("\\.", "__"):match("^[:#].-()[:#]") or #path + 1
            local index = parsestring(path:sub(2, to - 1))
            if path:sub(1, 1) == "#" then index = tonumber(index) or index end
            if type(t[index]) ~= "table" then t[index] = {} end
            return set(t[index], path:sub(to), v)
        else
            local at = path:sub(2)
            t[path:sub(1, 1) == "#" and tonumber(at) or at] = v
            return t, path, v
        end
    end

    local build = {}
    local current = build
    local containers = {}

    function searchpossible(key)
        for i=#containers, 1, -1 do
            local v = containers[i]
            if v.token == key then return i, v end
        end
        return nil
    end

    local tid = 1
    function collectattributes()
        local words = {}
        local sid = 0
        local exit = false
        while true do
            local after = (tokens[tid+sid] or {})
            if after.type == types.word then
                local possi = searchpossible(after.token)
                local after2 = tokens[tid+sid+1] or {}
                if after2.type  == types.object and possi then break
                elseif after2.type  == types.modifier
                and after2.token == "end" and possi then
                    exit = possi
                    break
                end
                table.insert(words, parsetype(after.token))
            elseif after.type == types.modifier then
                table.insert(words, "<"..after.token..">")
            elseif after.type == types.string then
                table.insert(words, parsestring(after.token))
            else break end
            sid = sid + 1
        end
        tid = tid + sid
        return words, exit
    end

    local collection = {}
    local collectids = {}
    repeat
        local v = tokens[tid]
        tid = tid + 1
        local exit = false
        if v.type == types.object then
            current = setmetatable({}, {__type = v.token}) -- store the type in metatable
            collection[v.token] = collection[v.token] or {}
            table.insert(collection[v.token], current)
            local before = (tokens[tid-2] or {})
            local _, possv = searchpossible(before.token)
            if before.type == types.word and possv then
                table.insert(possv.container, current)
            else
                table.insert(build, current)
            end
            local after = (tokens[tid] or {})
            if after.type == types.word and after.token:match("^!") then -- object ids?!
                getmetatable(current).__id = after.token
                collectids[after.token] = current
                tid = tid + 1
            end
        elseif v.type == types.attribute then
            if v.token:sub(1, 3):match("%.%.[:#]") then
                v.token = v.token:sub(3)
                gpath = gpath:match("^(.-)[:#].-$") or ""
            end
            if v.token:sub(1, 1):match("[:#]") then
                v.token = (gpath ~= "" and gpath..v.token or v.token:sub(2))
            end
            if v.token:sub(-1):match("[:#]") then
                gpath = v.token:sub(1, -2)
                set(current, ":"..v.token:sub(1, -2), {})
            else
                local after = (tokens[tid] or {})
                if after.type == types.word or after.type == types.string then -- for lists or single attributes
                    local words, doexit = collectattributes()
                    exit = doexit
                    if not words[1] then set(current, ":"..v.token, nil) 
                                    else set(current, ":"..v.token, #words == 1 and words[1] or words)
                                    end
                elseif after.type == types.modifier then
                    local words, doexit = collectattributes()
                    exit = doexit
                    if words[1] == "<container>" and words[2] then
                        -- because this is lua I don't need to worry about mixing lists and dicts,
                        -- but for other languages this will be an important distinction
                        local _, _, container = set(current, ":"..v.token, {})
                        table.insert(containers, {container = container, token = words[2], parent = current})
                    end
                else
                    set(current, ":"..v.token, {})
                end
            end
        elseif v.type == types.flag then
            local words, doexit = collectattributes()
            exit = doexit
            if v.token == "alias" and words[1] and words[2] then
                aliases[words[1]] = words[2]
            end
        end
        if exit then
            current = containers[exit].parent
            for i=exit, #containers do
                containers[i] = nil
            end
        end
    until tid >= #tokens

    return build, collection, collectids
end

return quanta