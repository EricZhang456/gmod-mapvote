MapVote = {}
MapVote.Config = {}

--Default Config
MapVoteConfigDefault = {
    MapLimit = 24,
    TimeLimit = 28,
    RTVWaitTime = 30,
    AllowCurrentMap = false,
    EnableCooldown = true,
    MapsBeforeRevote = 3,
    RTVPlayerCount = 3,
    UseMapList = false,
    MapPrefixes = {"ttt_"}
    -- AutoGamemode = false
}
--Default Config

MapVote.ReladConfig = function ()
    local fileContent = file.Read("mapvote/config.json", "DATA")
    if fileContent then
        local jsonContent = util.JSONToTable(fileContent)
        if jsonContent then
            MapVote.Config = jsonContent
        else
            ErrorNoHaltWithStack("Cannot parse config.json as JSON")
        end
    end
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
    if not file.IsDir( "mapvote", "DATA") then
        file.CreateDir( "mapvote" )
    end
    if not file.Exists( "mapvote/config.json", "DATA" ) then
        file.Write( "mapvote/config.json", util.TableToJSON( MapVoteConfigDefault, true ) )
    end
    MapVote.ReladConfig()
end )

if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("mapvote/cl_mapvote.lua")

    include("mapvote/sv_mapvote.lua")
    include("mapvote/rtv.lua")
else
    include("mapvote/cl_mapvote.lua")
end
