--- this whole thing fucking sucks, lua sucks, the original plugin sucks,
--- everything sucks, it's over!

MapVote = {}
MapVote.Config = {}
--[[
Mapcycle should look like this
{
    "gamemode1": [
        "map_1",
        "map_2"
    ],
    "gamemode2": [
        "map_3",
        "map_4"
    ]
}
]]--
MapVote.Mapcycle = {}
--Default Config
local MapVoteConfigDefault = {
    MapLimit = 24,
    TimeLimit = 28,
    RTVWaitTime = 30,
    RTVPercentage = 0.66,
    AllowCurrentMap = false,
    EnableCooldown = true,
    MapsBeforeRevote = 3,
    RTVPlayerCount = 3,
    -- AutoGamemode = false
}
--Default Config
MapVote.ReladConfig = function ()
    if not SERVER then
        return
    end
    do
        local fileContent = file.Read("mapvote/config.json", "DATA")
        if fileContent then
            local jsonContent = util.JSONToTable(fileContent)
            if jsonContent then
                MapVote.Config = jsonContent
            else
                error("Cannot parse config.json as JSON")
            end
        end
    end
    do
        local fileContent = file.Read("mapvote/mapcycle.json", "DATA")
        if fileContent then
            local jsonContent = util.JSONToTable(fileContent)
            if jsonContent then
                MapVote.Mapcycle = jsonContent
            else
                error("Cannot parse mapcycle.json as JSON")
            end
        end
    end
    if MapVote.Config.NominationLimit and MapVote.Config.MapLimit then
        if MapVote.Config.NominationLimit > MapVote.Config.MapLimit then
            ErrorNoHalt("NominationLimit is greater than MapLimit, clamping\n")
            MapVote.Config.NominationLimit = MapVote.Config.MapLimit
        end
    end
    ServerLog("Reloaded mapvote config\n")
end
MapVote.HasExtraVotePower = function (ply)
	-- Example that gives admins more voting power
	--[[
    if ply:IsAdmin() then
		return true
	end 
    ]]
	return false
end
MapVote.CurrentMaps = {}
MapVote.Votes = {}
MapVote.Allow = false
MapVote.UPDATE_VOTE = 1
MapVote.UPDATE_WIN = 3

hook.Add( "Initialize", "MapVoteConfigSetup", function()
    if not SERVER then
        return
    end
    if not file.IsDir( "mapvote", "DATA") then
        file.CreateDir( "mapvote" )
    end
    if not file.Exists( "mapvote/config.json", "DATA" ) then
        file.Write( "mapvote/config.json", util.TableToJSON( MapVoteConfigDefault, true ) )
    end
    if not file.Exists("mapvote/mapcycle.json", "DATA") then
        file.Write("mapvote/mapcycle.json", "{}\n")
    end
    MapVote.ReladConfig()
end )

--- @enum NominationStatus
NominationStatus = {
    Success = 0,
    CurrentMap = 1,
    RecentlyPlayed = 2,
    MaxNominationReached = 3,
    NotInMapcycle = 4,
    ClientAlreadyNominated = 5
}

--- @enum NominationMapStatus
NominationMapStatus = {
    CanNominate = 0,
    RecentlyPlayed = 1,
    Nominated = 2,
    CurrentMap = 3
}

if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("mapvote/cl_mapvote.lua")
    AddCSLuaFile("mapvote/cl_nominate.lua")
    include("mapvote/sv_mapvote.lua")
    include("mapvote/rtv.lua")
    include("mapvote/nomination.lua")
    resource.AddFile("resource/localization/en/mapvote.properties")
else
    include("mapvote/cl_mapvote.lua")
end
