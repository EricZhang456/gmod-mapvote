local cvarDontDeleteRecentMaps = CreateConVar("gm_mapvote_dont_delete_recent_maps", "0", nil,
    "Don't delete recent maps on shutdown", 0, 1)


util.AddNetworkString("RAM_MapVoteStart")
util.AddNetworkString("RAM_MapVoteUpdate")
util.AddNetworkString("RAM_MapVoteCancel")
util.AddNetworkString("RTV_Delay")
-- MapVote.Continued = false
net.Receive("RAM_MapVoteUpdate", function(len, ply)
    if MapVote.Allow and IsValid(ply) then
        local update_type = net.ReadUInt(3)
        if update_type == MapVote.UPDATE_VOTE then
            local map_id = net.ReadUInt(32)
            if MapVote.CurrentMaps[map_id] then
                MapVote.Votes[ply:SteamID()] = map_id
                net.Start("RAM_MapVoteUpdate")
                    net.WriteUInt(MapVote.UPDATE_VOTE, 3)
                    net.WriteEntity(ply)
                    net.WriteUInt(map_id, 32)
                net.Broadcast()
            end
        end
    end
end)

local function IsTableEmptyOrNil(t)
    return not t or next(t) == nil
end

local recentmaps = {}
do
    local fileContent = file.Read("mapvote/recentmaps.json", "DATA")
    if fileContent then
        local jsonContent = util.JSONToTable(fileContent)
        if jsonContent then
            recentmaps = jsonContent
        else
            error("Cannot parse recentmaps.json as JSON")
        end
    end
end

local function CoolDownDoStuff()
    local cooldownnum = MapVote.Config.MapsBeforeRevote or 3
    while #recentmaps > cooldownnum do
        table.remove(recentmaps)
    end
    local curmap = game.GetMap():lower()
    if not table.HasValue(recentmaps, curmap) then
        table.insert(recentmaps, 1, curmap)
    end
    file.Write("mapvote/recentmaps.json", util.TableToJSON(recentmaps))
end

MapVote.GetCurrentGameModeMapcycle = function ()
    local gameModeMapcycle = MapVote.Mapcycle[engine.ActiveGamemode()]
    if IsTableEmptyOrNil(gameModeMapcycle) then
        ErrorNoHalt("Current game mode " .. engine.ActiveGamemode() .. " has no mapcycle, falling back to map discovery\n")
        gameModeMapcycle = {}
        local gamemodeFile = file.Read(GAMEMODE.Folder .. "/" .. GAMEMODE.FolderName .. ".txt", "GAME")
        if gamemodeFile then
            local gamemodeInfo = util.KeyValuesToTable(gamemodeFile)
            local mapPrefix = gamemodeInfo.maps
            if not mapPrefix then
                error("Game mode " .. engine.ActiveGamemode() .. " has no map prefix specified!")
            end
            local gameMaps = file.Find("maps/*.bsp", "GAME")
            for _, filename in ipairs(gameMaps) do
                local mapName = string.StripExtension(string.GetFileFromFilename(filename)):lower()
                if string.find(mapName, mapPrefix) then
                    table.insert(gameModeMapcycle, mapName)
                end
            end
        end
    end

    return gameModeMapcycle
end

MapVote.GetRecentMaps = function ()
    return recentmaps
end

MapVote.Start = function (length, current, limit, prefix, callback)
    local current = current or MapVote.Config.AllowCurrentMap or false
    local length = length or MapVote.Config.TimeLimit or 28
    local limit = limit or MapVote.Config.MapLimit or 24
    local cooldown = MapVote.Config.EnableCooldown or MapVote.Config.EnableCooldown == nil and true
    -- local prefix = prefix or MapVote.Config.MapPrefixes
    -- local autoGamemode = MapVote.Config.AutoGamemode or MapVote.Config.AutoGamemode == nil and true

    local nominations = Nomination.CurrentNominations or {}

    local mapCycle = MapVote.GetCurrentGameModeMapcycle()
    local vote_maps = {}

    if #nominations >= 0 then
        for _, val in ipairs(nominations) do
            table.insert(vote_maps, val)
        end
    end

    local mapcycleHasEnoughMaps = true
    if limit then
        local cooldownnum = MapVote.Config.MapsBeforeRevote or 3
        mapcycleHasEnoughMaps = #mapCycle >= limit + cooldownnum
    end

    if limit and #vote_maps < limit then
        for _, map in RandomPairs(mapCycle) do
            local map = map:lower()
            local currentMap = game.GetMap():lower()
            if not current and currentMap == map then
                continue
            end
            if mapcycleHasEnoughMaps and cooldown and table.HasValue(recentmaps, map) then
                continue
            end
            table.insert(vote_maps, map)
            if limit and limit > 0 and #vote_maps >= limit then
                break
            end
        end
    end

    net.Start("RAM_MapVoteStart")
        net.WriteUInt(#vote_maps, 32)
        for _, val in ipairs(vote_maps) do
            net.WriteString(val)
        end
        net.WriteUInt(length, 32)
    net.Broadcast()
    MapVote.Allow = true
    MapVote.CurrentMaps = vote_maps
    MapVote.Votes = {}
    timer.Create("RAM_MapVote", length, 1, function()
        MapVote.Allow = false
        local map_results = {}
        for k, v in pairs(MapVote.Votes) do
            if not map_results[v] then
                map_results[v] = 0
            end
            for k2, v2 in pairs(player.GetAll()) do
                if v2:SteamID() == k then
                    if MapVote.HasExtraVotePower(v2) then
                        map_results[v] = map_results[v] + 2
                    else
                        map_results[v] = map_results[v] + 1
                    end
                end
            end
        end
        CoolDownDoStuff()
        local winner = table.GetWinningKey(map_results) or 1
        net.Start("RAM_MapVoteUpdate")
            net.WriteUInt(MapVote.UPDATE_WIN, 3)
            net.WriteUInt(winner, 32)
        net.Broadcast()
        local map = MapVote.CurrentMaps[winner]
        --[[
        local gamemode = nil
        if autoGamemode then
            -- check if map matches a gamemode's map pattern
            for k, gm in pairs(engine.GetGamemodes()) do
                -- ignore empty patterns
                if gm.maps and gm.maps ~= "" then
                    -- patterns are separated by "|"
                    for k2, pattern in pairs(string.Split(gm.maps, "|")) do
                        if string.match(map, pattern) then
                            gamemode = gm.name
                            break
                        end
                    end
                end
            end
        else
            ServerLog("autoGamemode not enabled\n")
        end
        ]]--
        timer.Simple(4, function()
            if hook.Run("MapVoteChange", map) ~= false then
                if callback then
                    callback(map)
                else
                    -- if map requires another gamemode then switch to it
                    -- if gamemode and gamemode ~= engine.ActiveGamemode() then
                    --     RunConsoleCommand("gamemode", gamemode)
                    -- end
                    RunConsoleCommand("changelevel", map)
                end
            end
        end)
    end)
end

hook.Add( "Shutdown", "RemoveRecentMaps", function()
    if cvarDontDeleteRecentMaps:GetBool() then
        return
    end
    if file.Exists( "mapvote/recentmaps.json", "DATA" ) then
        file.Delete( "mapvote/recentmaps.json" )
    end
end )

MapVote.Cancel = function ()
    if MapVote.Allow then
        MapVote.Allow = false
        net.Start("RAM_MapVoteCancel")
        net.Broadcast()
        timer.Remove("RAM_MapVote")
    end
end
