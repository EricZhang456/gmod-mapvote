--- Nomination_Requested message structure:
--- string: player name
--- string: map name
util.AddNetworkString("Nomination_Requested")

--- Nomination_MapList message structure:
--- uint16: number of maps
--- repeated:
---     string: map name
---     uint4: map status, see NominationMapStatus
util.AddNetworkString("Nomination_MapList")

Nomination = {
    --- @type string[]
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
    if #Nomination.CurrentNominations >= MapVote.Config.NominationLimit then
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
            table.insert(Nomination.CurrentNominations, targetMap)

            net.Start("Nomination_Requested")
            net.WriteString(ply:Nick())
            net.WriteString(map)
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

    return NominationStatus.Success
end
