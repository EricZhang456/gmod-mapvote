util.AddNetworkString("RTV_Requested")

local RTV = {}
local rtvChatCommands = {
	"!rtv",
	"/rtv",
	"rtv"
}
RTV.VotedClients = {}

RTV.GetPercentage = function ()
	return MapVote.Config.RTVPercentage or 0.66
end

RTV.ShouldChange = function ()
	return #RTV.VotedClients >= math.Round(#player.GetAll() * RTV.GetPercentage())
end

RTV.GetWaitTime = function ()
	return MapVote.Config.RTVWaitTime or 60
end

RTV._RtvAllowedTime = nil

RTV.ResetWaitTime = function ()
	RTV._RtvAllowedTime = CurTime() + RTV.GetWaitTime()
end

RTV.IsRtvAllowedYet = function ()
	if not RTV._RtvAllowedTime then
		return true
	end
	return RTV._RtvAllowedTime < CurTime()
end

--- @param ply Player
--- @return boolean
RTV.HasClientRtved = function (ply)
	local userId = ply:UserID()
	for _, val in ipairs(RTV.VotedClients) do
		if val == userId then
			return true
		end
	end
	return false
end

--- @param ply Player
RTV.RemoveVote = function (ply)
	if not RTV.HasClientRtved(ply) then
		return false
	end

	local userId = ply:UserID()
	for i, val in ipairs(RTV.VotedClients) do
		if val == userId then
			table.remove(RTV.VotedClients, i)
			return true
		end
	end
	return false
end

RTV.Start = function ()
	if GAMEMODE_NAME == "terrortown" then
		net.Start("RTV_Delay")
      	net.Broadcast()
		hook.Add("TTTEndRound", "MapvoteDelayed", function()
			MapVote.Start(nil, nil, nil, nil)
		end)
	elseif GAMEMODE_NAME == "deathrun" then
		net.Start("RTV_Delay")
      	net.Broadcast()
		hook.Add("RoundEnd", "MapvoteDelayed", function()
			MapVote.Start(nil, nil, nil, nil)
		end)
	else
		PrintMessage( HUD_PRINTTALK, "#mapvote.rtv_success_now")
		timer.Simple(3, function()
			MapVote.Start(nil, nil, nil, nil)
		end)
	end
end

--- @param ply Player
RTV.AddVote = function ( ply )
	if RTV.CanVote( ply ) then
		table.insert(RTV.VotedClients, ply:UserID())
		ServerLog(ply:Nick() .. " has voted to Rock the Vote.\n")
		net.Start("RTV_Requested")
		net.WriteString(ply:Nick())
		-- current rtv count
		net.WriteUInt(#RTV.VotedClients, 8)
		-- total player count
		net.WriteUInt(math.Round(#player.GetAll() * RTV.GetPercentage()), 8)
		net.Broadcast()
		if RTV.ShouldChange() then
			RTV.Start()
		end
	end
end

RTV.CanVote = function ( ply )
	local plyCount = table.Count(player.GetAll())
	if not RTV.IsRtvAllowedYet() then
		return false, "#mapvote.rtv_wait"
	end
	if GetGlobalBool( "In_Voting" ) then
		return false, "#mapvote.rtv_vote_in_progress"
	end
	if RTV.HasClientRtved(ply) then
		return false, "#mapvote.rtv_voted"
	end
	if RTV.ChangingMaps then
		return false, "#mapvote.rtv_map_changing"
	end
	local requiedPlayers = MapVote.Config.RTVPlayerCount or 3
	if plyCount < requiedPlayers then
        return false, "#mapvote.rtv_not_enough_players"
    end
	return true
end

RTV.StartVote = function ( ply )
	local can, err = RTV.CanVote(ply)
	if not can then
		ply:PrintMessage( HUD_PRINTTALK, err )
		return
	end
	RTV.AddVote( ply )
end

concommand.Add( "rtv_start", RTV.StartVote )

local function TrimString(s)
    return s:match( "^%s*(.-)%s*$" )
end

hook.Add("Initialize", "MapVoiteRtvResetWaitTime", function ()
	RTV.ResetWaitTime()
end)

hook.Add( "PlayerSay", "MapVoteRtvChatCommand", function( ply, text )
	if table.HasValue( rtvChatCommands, TrimString(text:lower()) ) then
		RTV.StartVote( ply )
		return ""
	end
end )

hook.Add( "PlayerDisconnected", "MapVoteRemoveRtvOnDisconnect", function( ply )
	RTV.RemoveVote(ply)
	timer.Simple( 0.1, function()
		if RTV.ShouldChange() then
			RTV.Start()
		end
	end )
end )
