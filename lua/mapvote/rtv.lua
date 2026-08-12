util.AddNetworkString("RTV_Requested")

RTV = RTV or {}
RTV.ChatCommands = {
	"!rtv",
	"/rtv",
	"rtv"
}
RTV.TotalVotes = 0
RTV.Wait = MapVote.Config.RTVWaitTime or 60 -- The wait time in seconds. This is how long a player has to wait before voting when the map changes. 
RTV.Percentage = MapVote.Config.RTVPercentage or 0.66
RTV._ActualWait = CurTime() + RTV.Wait
RTV.PlayerCount = MapVote.Config.RTVPlayerCount or 3

RTV.ShouldChange = function ()
	return RTV.TotalVotes >= math.Round(#player.GetAll()*RTV.Percentage)
end

RTV.RemoveVote = function ()
	RTV.TotalVotes = math.Clamp( RTV.TotalVotes - 1, 0, math.huge )
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
		timer.Simple(4, function()
			MapVote.Start(nil, nil, nil, nil)
		end)
	end
end

RTV.AddVote = function ( ply )
	if RTV.CanVote( ply ) then
		RTV.TotalVotes = RTV.TotalVotes + 1
		ply.RtvRequested = true
		ServerLog(ply:Nick() .. " has voted to Rock the Vote.\n")
		net.Start("RTV_Requested")
		net.WriteString(ply:Nick())
		-- current rtv count
		net.WriteUInt(RTV.TotalVotes, 8)
		-- total player count
		net.WriteUInt(math.Round(#player.GetAll() * RTV.Percentage), 8)
		net.Broadcast()
		if RTV.ShouldChange() then
			RTV.Start()
		end
	end
end

RTV.CanVote = function ( ply )
	local plyCount = table.Count(player.GetAll())
	if RTV._ActualWait >= CurTime() then
		return false, "#mapvote.rtv_wait"
	end
	if GetGlobalBool( "In_Voting" ) then
		return false, "#mapvote.rtv_vote_in_progress"
	end
	if ply.RtvRequested then
		return false, "#mapvote.rtv_voted"
	end
	if RTV.ChangingMaps then
		return false, "#mapvote.rtv_map_changing"
	end
	if plyCount < RTV.PlayerCount then
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

hook.Add( "PlayerSay", "MapVoteRtvChatCommand", function( ply, text )
	if table.HasValue( RTV.ChatCommands, string.lower(text) ) then
		RTV.StartVote( ply )
	end
end )

hook.Add( "PlayerDisconnected", "MapVoteRemoveRtvOnDisconnect", function( ply )
	if ply.RtvRequested then
		RTV.RemoveVote()
	end
	timer.Simple( 0.1, function()
		if RTV.ShouldChange() then
			RTV.Start()
		end
	end )
end )
