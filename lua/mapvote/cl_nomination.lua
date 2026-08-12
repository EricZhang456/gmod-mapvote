local mapStatusLookup = {
    [0] = NominationMapStatus.CanNominate,
    [1] = NominationMapStatus.RecentlyPlayed,
    [2] = NominationMapStatus.Nominated,
    [3] = NominationMapStatus.CurrentMap
}

net.Receive("Nomination_Requested", function (len, ply)
    local nick = net.ReadString()
    local map = net.ReadString()
    chat.AddText(color_white, string.format(language.GetPhrase("mapvote.nomination_requested"), nick, map))
end)

net.Receive("Nomination_MapList", function (len, ply)
    local length = net.ReadUInt(16)
    local maps = {}
    for _ = 1, length do
        local mapName = net.ReadString()
        local mapStatus = mapStatusLookup[net.ReadUInt(4)]
        table.insert(maps, {name = mapName, status = mapStatus})
    end

    --- TODO: make a ui and show it to the user
end)
