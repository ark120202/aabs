function CDOTA_PlayerResource:SetPlayerStat(PlayerID, key, value)
	local pd = PLAYER_DATA[PlayerID]
	if not pd.HeroStats then pd.HeroStats = {} end
	pd.HeroStats[key] = value
end

function CDOTA_PlayerResource:GetPlayerStat(PlayerID, key)
	local pd = PLAYER_DATA[PlayerID]
	return pd.HeroStats == nil and 0 or (pd.HeroStats[key] or 0)
end

function CDOTA_PlayerResource:ModifyPlayerStat(PlayerID, key, value)
	local v = self:GetPlayerStat(PlayerID, key) + value
	self:SetPlayerStat(PlayerID, key, v)
	return v
end

function CDOTA_PlayerResource:SetPlayerTeam(playerId, newTeam)
	local oldTeam = self:GetTeam(playerId)
	local player = self:GetPlayer(playerId)
	local hero = self:GetSelectedHeroEntity(playerId)
	PlayerTables:RemovePlayerSubscription("dynamic_minimap_points_" .. oldTeam, playerId)
	local playerPickData = {}
	local tableData = PlayerTables:GetTableValue("hero_selection", oldTeam)
	if tableData and tableData[playerId] then
		table.merge(playerPickData, tableData[playerId])
		tableData[playerId] = nil
		PlayerTables:SetTableValue("hero_selection", oldTeam, tableData)
	end

	for _,v in ipairs(FindAllOwnedUnits(player)) do
		v:SetTeam(newTeam)
	end
	player:SetTeam(newTeam)

	PlayerResource:UpdateTeamSlot(playerId, newTeam, 1)
	PlayerResource:SetCustomTeamAssignment(playerId, newTeam)

	local newTableData = PlayerTables:GetTableValue("hero_selection", newTeam)
	if newTableData and playerPickData then
		newTableData[playerId] = playerPickData
		PlayerTables:SetTableValue("hero_selection", newTeam, newTableData)
	end
	--[[for _, v in ipairs(Entities:FindAllByClassname("npc_dota_courier") ) do
		v:SetControllableByPlayer(playerId, v:GetTeamNumber() == newTeam)
	end]]
	--FindCourier(oldTeam):SetControllableByPlayer(playerId, false)
	local targetCour = FindCourier(newTeam)
	if IsValidEntity(targetCour) then
		targetCour:SetControllableByPlayer(playerId, true)
	end
	PlayerTables:RemovePlayerSubscription("dynamic_minimap_points_" .. oldTeam, playerId)
	PlayerTables:AddPlayerSubscription("dynamic_minimap_points_" .. newTeam, playerId)

	for i = 0, hero:GetAbilityCount() - 1 do
		local skill = hero:GetAbilityByIndex(i)
		if skill then
			--print(skill.GetIntrinsicModifierName and skill:GetIntrinsicModifierName())
			if (
				skill.GetIntrinsicModifierName and
				skill:GetIntrinsicModifierName() and
				skill:GetAbilityName() ~= "meepo_divided_we_stand"
		 	) then
				RecreateAbility(hero, skill)
			end
		end
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "arena_team_changed_update", {})
	PlayerResource:RefreshSelection()

	Teams:RecalculateKillWeight(oldTeam)
	Teams:RecalculateKillWeight(newTeam)
end

function CDOTA_PlayerResource:SetDisableHelpForPlayerID(nPlayerID, nOtherPlayerID, disabled)
	if nPlayerID ~= nOtherPlayerID then
		if not PLAYER_DATA[nPlayerID].DisableHelp then
			PLAYER_DATA[nPlayerID].DisableHelp = {}
		end
		PLAYER_DATA[nPlayerID].DisableHelp[nOtherPlayerID] = disabled

		local disable_help_data = PlayerTables:GetTableValue("disable_help_data", nPlayerID)
		disable_help_data[nOtherPlayerID] = PLAYER_DATA[nPlayerID][nOtherPlayerID]
		PlayerTables:SetTableValue("disable_help_data", disable_help_data)
	end
end

function CDOTA_PlayerResource:IsDisableHelpSetForPlayerID(nPlayerID, nOtherPlayerID)
	return PLAYER_DATA[nPlayerID] ~= nil and PLAYER_DATA[nPlayerID].DisableHelp ~= nil and PLAYER_DATA[nPlayerID].DisableHelp[nOtherPlayerID] and PlayerResource:GetTeam(nPlayerID) == PlayerResource:GetTeam(nOtherPlayerID)
end

function CDOTA_PlayerResource:KickPlayer(nPlayerID)
	local usid = PLAYER_DATA[nPlayerID].UserID
	if usid then
		SendToServerConsole("kickid " .. usid)
		return true
	end
	return false
end

function CDOTA_PlayerResource:IsPlayerAbandoned(playerId)
	return IsPlayerAbandoned(playerId)
end

function CDOTA_PlayerResource:IsBanned(playerId)
	return PLAYER_DATA[playerId].isBanned == true
end

function CDOTA_PlayerResource:MakePlayerAbandoned(playerId)
	if PlayerResource:IsPlayerAbandoned(playerId) then return end
	PlayerResource:RemoveAllUnits(playerId)
	local heroname = HeroSelection:GetSelectedHeroName(playerId)
	--local notLinked = true
	if heroname then
		Notifications:TopToAll({hero=heroname, duration=10})
		Notifications:TopToAll({text=PlayerResource:GetPlayerName(playerId), continue=true, style={color=ColorTableToCss(PLAYER_DATA[playerId].Color or {0, 0, 0})}})
		Notifications:TopToAll({text="#game_player_abandoned_game", continue=true})

		for _,v in ipairs(GetLinkedHeroNames(heroname)) do
			local linkedHeroOwner = HeroSelection:GetSelectedHeroPlayer(v)
			if linkedHeroOwner then
				HeroSelection:ForceChangePlayerHeroMenu(linkedHeroOwner)
			end
		end
	end
	--if notLinked then
		HeroSelection:UpdateStatusForPlayer(playerId, "hover", "npc_dota_hero_abaddon")
	--end
	PLAYER_DATA[playerId].IsAbandoned = true
	PlayerTables:SetTableValue("players_abandoned", playerId, true)
	Teams:RecalculateKillWeight(PlayerResource:GetTeam(playerId))
	if not GameRules:IsCheatMode() then
		local teamLeft = GetOneRemainingTeam()
		if teamLeft then
			Timers:CreateTimer(30, function()
				local teamLeft = GetOneRemainingTeam()
				if teamLeft then
					GameMode:OnOneTeamLeft(teamLeft)
				end
			end)
		end
	end

	Duel:EndIfFinished()
end

function CDOTA_PlayerResource:RemoveAllUnits(playerId)
	RemoveAllOwnedUnits(playerId)
	local hero = PlayerResource:GetSelectedHeroEntity(playerId)
	if not IsValidEntity(hero) then return end
	hero:ClearNetworkableEntityInfo()
	hero:Stop()

	for i = 0, hero:GetAbilityCount() - 1 do
		local ability = hero:GetAbilityByIndex(i)
		if ability then
			if ability:GetKeyValue("NoAbandonCleanup") ~= 1 then
				ability:SetLevel(0)
			end
			ability:SetHidden(true)
			ability:SetActivated(false)
			--UTIL_Remove(ability)
		end
	end
	hero:InterruptMotionControllers(false)
	hero:DestroyAllModifiers()
	hero:AddNewModifier(hero, nil, "modifier_hero_out_of_game", nil)
end

function CDOTA_PlayerResource:GetRealSteamID(PlayerID)
	local id = tostring(PlayerResource:GetSteamID(PlayerID))
	return id == "0" and tostring(PlayerID) or id
end
