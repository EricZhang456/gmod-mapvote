--- Nomination_Requested message structure:
--- string: player name
--- string: map name
--- bool: true if it's a new nomination, false if it's not
util.AddNetworkString("Nomination_Requested")

--- Nomination_MapList message structure:
--- uint16: number of maps
--- repeated:
---     string: map name
---     uint4: map status, see NominationMapStatus
util.AddNetworkString("Nomination_MapList")

Nomination = {
    --- @type {user: number, map: string}[]
    CurrentNominations = {}
}

--- Trims a string.
--- @param s string The string to trim.
--- @return string -- The trimmed string
local function TrimString(s)
    return s:match( "^%s*(.-)%s*$" )
end

--- @param map string
--- @return { map: string, status: NominationMapStatus }[]
local function FindMatchingMaps(map)
    local targetMap = ""
    if map then
        targetMap = TrimString(map:lower())
    end

    local initialMapList = {}
    local mapResults = {}
    local mapcycle = MapVote.GetCurrentGameModeMapcycle()

    if targetMap == "" then
        initialMapList = mapcycle
    else
        for _, mapcycleMap in ipairs(mapcycle) do
            local mapcycleMapLower = mapcycleMap:lower()
            if string.find(mapcycleMapLower, map, 1, true) then
                table.insert(initialMapList, mapcycleMapLower)
            end
        end
    end

    local currentGameMap = game.GetMap():lower()
    for _, currMap in ipairs(initialMapList) do
        local mapStatus = NominationMapStatus.CanNominate

        local currMapLower = currMap:lower()
        if currentGameMap == currMapLower then
            mapStatus = NominationMapStatus.CurrentMap
        elseif table.HasValue(MapVote.GetRecentMaps(), currMapLower) then
            mapStatus = NominationMapStatus.RecentlyPlayed
        elseif table.HasValue(Nomination.CurrentNominations, currMapLower) then
            mapStatus = NominationMapStatus.Nominated
        end

        table.insert(mapResults, {
            map = currMapLower,
            status = mapStatus
        })
    end

    return mapResults
end

--- Try to nominate a map.
--- @param ply Player
--- @param map string
--- @return NominationStatus
Nomination.AttemptToNominateMap = function (ply, map)
    local clientAlreadyNominated = false
    local clientNominationEntry = 0
    local userId = ply:UserID()
    for i, val in ipairs(Nomination.CurrentNominations) do
        if val.user == userId then
            clientAlreadyNominated = true
            clientNominationEntry = i
            break
        end
    end

    if not clientAlreadyNominated and #Nomination.CurrentNominations >= MapVote.Config.NominationLimit then
        return NominationStatus.MaxNominationReached
    end

    local targetMap = ""
    if map then
        targetMap = TrimString(map:lower())
    end

    local nominationSearch = FindMatchingMaps(targetMap)

    if #nominationSearch <= 0 then
        return NominationStatus.NotInMapcycle
    end

    if #nominationSearch == 1 then
        local nominationMap = nominationSearch[1]
        if nominationMap.status == NominationMapStatus.RecentlyPlayed then
            return NominationMapStatus.RecentlyPlayed
        elseif nominationMap.status == NominationMapStatus.Nominated then
            return NominationMapStatus.Nominated
        elseif nominationMap.status == NominationMapStatus.CurrentMap then
            return NominationMapStatus.CurrentMap
        else
            local nominationEntry = {
                client = userId,
                map = targetMap
            }
            if not clientAlreadyNominated then
                table.insert(Nomination.CurrentNominations, nominationEntry)
            else
                Nomination.CurrentNominations[clientNominationEntry] = nominationEntry
            end

            net.Start("Nomination_Requested")
            net.WriteString(ply:Nick())
            net.WriteString(map)
            net.WriteBool(not clientAlreadyNominated)
            net.Broadcast()

            return NominationStatus.Success
        end
    end

    net.Start("Nomination_MapList")
    net.WriteUInt(#nominationSearch, 16)
    for _, value in ipairs(nominationSearch) do
        net.WriteString(value.map)
        net.WriteUInt(value.status, 4)
    end
    net.Send(ply)

    return NominationStatus.Success
end

--- @param ply Player
--- @param map string | nil
local function ClientNominateCommand(ply, map)
    local targetMap = TrimString(string.lower(map or ""))
    local nominationStatus = Nomination.AttemptToNominateMap(ply, targetMap)
    if nominationStatus == NominationStatus.Success then
        return
    end

    local targetErrorStr = ""
    if nominationStatus == NominationStatus.CurrentMap then
        targetErrorStr = "#mapvote.nomination_cant_nominate_current_map"
    elseif nominationStatus == NominationStatus.RecentlyPlayed then
        targetErrorStr = "#mapvote.nomination_recent"
    elseif nominationStatus == NominationStatus.MaxNominationReached then
        targetErrorStr = "#mapvote.nomination_max_reached"
    elseif nominationStatus == NominationStatus.NotInMapcycle then
        targetErrorStr = "mapvote.nomination_not_in_mapcycle"
    end

    ply:PrintMessage(HUD_PRINTTALK, targetErrorStr)
end

concommand.Add("mapvote_nominate", function (ply, cmd, args, argStr)
    if #args > 0 then
        ClientNominateCommand(ply, args[1])
    else
        ClientNominateCommand(ply, "")
    end
end, nil, "Nominates a map.")

hook.Add("PlayerDisconnected", "MapVoteNominationDisconnect", function (ply)
    for i = #Nomination.CurrentNominations, 1, -1 do
        local entry = Nomination.CurrentNominations[i]
        if entry.user == ply:UserID() then
            table.remove(Nomination.CurrentNominations, i)
            break
        end
    end
end)

--- google ai wrote this, it works so whatever
--- @param text string
--- @return string[]
local function parseArgs(text)
    local results = {}
    local pos = 1

    while pos <= #text do
        -- Find the next occurrence of each pattern starting from 'pos'
        local d_start, d_end, d_cap = text:find('"(.-)"', pos)
        local s_start, s_end, s_cap = text:find("'([^']-)'", pos)
        local n_start, n_end, n_cap = text:find("(%S+)", pos)

        -- Find which match appears first in the string
        local min_start = math.huge
        local best_end, best_cap

        if d_start and d_start < min_start then
            min_start, best_end, best_cap = d_start, d_end, d_cap
        end
        if s_start and s_start < min_start then
            min_start, best_end, best_cap = s_start, s_end, s_cap
        end
        if n_start and n_start < min_start then
            min_start, best_end, best_cap = n_start, n_end, n_cap
        end

        -- If a match was found, save it and move the pointer past it
        if min_start ~= math.huge then
            table.insert(results, best_cap)
            pos = best_end + 1
        else
            break -- No more matches found in the remaining text
        end
    end

    return results
end

hook.Add("PlayerSay", "MapVoteNominationPlayerSay", function (sender, text, teamChat)
    local trimmedText = TrimString(text:lower())
    if trimmedText == "" then
        return
    end

    if trimmedText:match("^!nominate") or trimmedText:match("^/nominate") then
        local parsedStr = parseArgs(text)
        local mapParam = parsedStr[2]:lower()

        if mapParam and mapParam ~= "" then
            ClientNominateCommand(sender, mapParam)
        else
            ClientNominateCommand(sender, "")
        end
    end
end)
