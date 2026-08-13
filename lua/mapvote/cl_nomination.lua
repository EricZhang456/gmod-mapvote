local mapStatusLookup = {
    [0] = NominationMapStatus.CanNominate,
    [1] = NominationMapStatus.RecentlyPlayed,
    [2] = NominationMapStatus.Nominated,
    [3] = NominationMapStatus.CurrentMap
}

--- @class NominationMenu
--- @field maps {name: string, status:NominationMapStatus}[]
--- @field panel Panel | nil
local NominationMenu = {}
NominationMenu.__index = NominationMenu

--- Creates a new nomination menu
--- @param maplist {name: string, status:NominationMapStatus}[] List of maps to nominate
--- @return NominationMenu
function NominationMenu:new(maplist)
    local obj = setmetatable({}, self)
    obj.maps = maplist
    obj.panel = nil
    return obj
end

--- Show the menu to the user
function NominationMenu:show()
    self.panel = vgui.Create("DFrame")
    self.panel:Center()
    self.panel:SetText(language.GetPhrase("mapvote.nomination_menu_title"))
    self.panel:SetSize(300, 500)
    self.panel:MakePopup()

    local mapScrollPanel = vgui.Create("DScrollPanel", self.panel)
    mapScrollPanel:Dock(FILL)
    for i, val in ipairs(self.maps) do
        local button = mapScrollPanel:Add("DButton")
        button:SetHeight(50)
        local marginTop = 0
        local marginBottom = 15
        if i == 1 then
            marginTop = 5
        end

        if i == #self.maps then
            marginBottom = 5
        end

        button:DockMargin(5, marginTop, 5, marginBottom)

        local mapEnabled = val.status == NominationMapStatus.CanNominate
        if mapEnabled then
            button:SetText(val.name)
            button:SetConsoleCommand("mapvote_nominate", val.name)
        else
            local statusStr = ""
            if val.status == NominationMapStatus.RecentlyPlayed then
                statusStr = "mapvote.nomination_recently_played"
            elseif val.status == NominationMapStatus.Nominated then
                statusStr = "mapvote.nomination_nominated"
            elseif val.status == NominationMapStatus.CurrentMap then
                statusStr = "mapvote.nomination_current_map"
            end

            button:SetText(string.format("%s (%s)", val.name, language.GetPhrase(statusStr)))
        end
        button:SetEnabled(mapEnabled)
    end
end

net.Receive("Nomination_Requested", function (len, ply)
    local nick = net.ReadString()
    local map = net.ReadString()
    local newNomination = net.ReadBool()
    local targetTranslationStr = "mapvote.nomination_requested"
    if not newNomination then
        targetTranslationStr = "mapvote.nomination_change"
    end
    chat.AddText(color_white, string.format(language.GetPhrase(targetTranslationStr), nick, map))
end)

net.Receive("Nomination_MapList", function (len, ply)
    local length = net.ReadUInt(16)
    local maps = {}
    for _ = 1, length do
        local mapName = net.ReadString()
        local mapStatus = mapStatusLookup[net.ReadUInt(4)]
        table.insert(maps, {name = mapName, status = mapStatus})
    end

    local menu = NominationMenu:new(maps)
    menu:show()
end)
