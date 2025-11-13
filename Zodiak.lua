if host:isHost() then  
local files = listFiles("", true)
local Promise_module

for _, file in ipairs(files) do
    -- ищем SquAPI
    if not Promise_module and string.find(file, "Promise") then
        Promise_module = file:gsub("%.lua$", ""):gsub("[/\\]", ".")
    end

    -- если оба найдены — можно выйти
    if Promise_module then
        break
    end
end

-- если хотя бы один модуль не найден — выходим
if not (Promise_module) then
    return
end


-- подключаем найденный модуль
local Promise = require(Promise_module)


-- Настройки
local searchNick = "Temp"
local Role1 = ""

local roleNames = {
    ["1384918844262453318"] = '[{"text":"З!одиак","color":"#9b2226"}]',
    ["1392122819290071120"] = '[{"text":"Аркана","color":"#bb3e03"}]',
    ["1386034227321241683"] = '[{"text":"Созвездие","color":"#ca6702"}]',
    ["1384918146053570570"] = '[{"text":"Звезда","color":"#ee9b00"}]',
}

local function getRoleIndex(roleId)
    local index = 1
    for id, _ in pairs(roleNames) do
        if id == roleId then
            return index
        end
        index = index + 1
    end
    return math.huge
end

local function wrapRoleWithNick(roleJson, nick)
    local roleTable = {}
    for text, color in roleJson:gmatch('"text":"(.-)".-"color":"(.-)"') do
        table.insert(roleTable, {text=text, color=color})
    end

    local wrapped = {}
    table.insert(wrapped, {text="> "..nick.." ", color="#C0C0C0"})
    for _, item in ipairs(roleTable) do
        table.insert(wrapped, item)
    end
    table.insert(wrapped, {text=" <", color="#C0C0C0"})

    local parts = {}
    for _, item in ipairs(wrapped) do
        table.insert(parts, string.format('{"text":"%s","color":"%s"}', item.text, item.color))
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local tickCounter = 0
local lastRole = '[{"text":"> '..searchNick..' <","color":"#C0C0C0"}]'
local isRequesting = false -- флаг, что запрос в процессе

function events.mouse_press(button, action, modifier)
    if button == 1 then
        local targeted = player:getTargetedEntity(3)
        if targeted ~= nil and targeted:isPlayer() then
            pings.Search()
            Role1 = ""
            searchNick = ""
            searchNick = targeted:getName()
            lastRole = ""
        end
    end
end

function pings.Search()
    -- Если запрос уже идет, ничего не делаем
    if isRequesting then return end


    -- Отправляем запрос
    isRequesting = true
    local url = "https://splexxhqfig.splexxhqfig.workers.dev/"
    local req = net.http:request(url)
        :method("GET")

    Promise.await(req:send())
        :thenString(function(response)
            local users = {}
            for userStr in response:gmatch('{(.-)}') do
                local user = {}
                user.nick = userStr:match('"nick":"(.-)"')
                user.username = userStr:match('"username":"(.-)"')
                user.roles = {}
                for role in userStr:gmatch('"roles":%s*%[(.-)%]') do
                    for r in role:gmatch('"(%d+)"') do
                        table.insert(user.roles, r)
                    end
                end
                table.insert(users, user)
            end

            local found = false
            local searchLower = searchNick:lower()
            for _, user in ipairs(users) do
                if user.nick and user.nick:lower():find(searchLower, 1, true) then
                    local filteredRoles = {}
                    for _, roleId in ipairs(user.roles) do
                        if roleNames[roleId] then
                            table.insert(filteredRoles, roleId)
                        end
                    end
                    table.sort(filteredRoles, function(a, b)
                        return getRoleIndex(a) < getRoleIndex(b)
                    end)

                    local highestRole = filteredRoles[1] and roleNames[filteredRoles[1]] or nil
                    if highestRole then
                        lastRole = wrapRoleWithNick(highestRole, searchNick)
                    end
                    found = true
                    break
                end
            end

            -- Только здесь обновляем actionbar
            if lastRole ~= "" then 
                host:setActionbar(lastRole)
            end
                isRequesting = false
        end)
        :catch(function(err)
            -- Ошибка запроса — оставляем lastRole без изменений
            if lastRole ~= "" then
            host:setActionbar(lastRole)
            end
            isRequesting = false
        end)
end
end
