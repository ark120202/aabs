Events:Register("activate", "custom_events", function ()
	CustomGameEventManager:RegisterListener("custom_chat_send_message", Dynamic_Wrap(GameMode, "CustomChatSendMessage"))
	CustomGameEventManager:RegisterListener("metamorphosis_elixir_cast", Dynamic_Wrap(GameMode, "MetamorphosisElixirCast"))
	CustomGameEventManager:RegisterListener("modifier_clicked_purge", Dynamic_Wrap(GameMode, "ModifierClickedPurge"))
	CustomGameEventManager:RegisterListener("options_vote", Dynamic_Wrap(Options, "OnVote"))
	CustomGameEventManager:RegisterListener("team_select_host_set_player_team", Dynamic_Wrap(GameMode, "TeamSelectHostSetPlayerTeam"))
	CustomGameEventManager:RegisterListener("set_help_disabled", Dynamic_Wrap(GameMode, "SetHelpDisabled"))
	CustomGameEventManager:RegisterListener("on_ads_clicked", Dynamic_Wrap(GameMode, "OnAdsClicked"))
end)

function GameMode:MetamorphosisElixirCast(data)
	local hero = PlayerResource:GetSelectedHeroEntity(data.PlayerID)
	local elixirItem = FindItemInInventoryByName(hero, "item_metamorphosis_elixir", false)
	local newHeroName = tostring(data.hero)
	if IsValidEntity(hero) and
		hero:GetFullName() ~= newHeroName and
		HeroSelection:IsHeroPickAvaliable(newHeroName) and
		(elixirItem or hero.ForcedHeroChange) and
		(hero.ForcedHeroChange or Options:IsEquals("EnableRatingAffection", false) or
		PlayerResource:GetPlayerStat(data.PlayerID, "ChangedHeroAmount") == 0) then
		if not Duel:IsDuelOngoing() then
			if HeroSelection:ChangeHero(data.PlayerID, newHeroName, true, elixirItem and elixirItem:GetSpecialValueFor("transformation_time") or 0, elixirItem) then
				PlayerResource:ModifyPlayerStat(data.PlayerID, "ChangedHeroAmount", 1)
			end
		else
			Containers:DisplayError(data.PlayerID, "#arena_hud_error_cant_change_hero")
		end
	end
end

function GameMode:CustomChatSendMessage(data)
	CustomChatSay(tonumber(data.PlayerID), data.teamOnly == 1, data)
end

function GameMode:ModifierClickedPurge(data)
	if data.PlayerID and data.unit and data.modifier then
		local ent = EntIndexToHScript(data.unit)
		if IsValidEntity(ent) and
			ent:IsAlive() and
			ent:GetPlayerOwner() == PlayerResource:GetPlayer(data.PlayerID) and
			table.contains(ONCLICK_PURGABLE_MODIFIERS, data.modifier) and
			not ent:IsStunned() and
			not ent:IsChanneling() then
			ent:RemoveModifierByName(data.modifier)
		end
	end
end

function GameMode:TeamSelectHostSetPlayerTeam(data)
	if GameRules:PlayerHasCustomGameHostPrivileges(PlayerResource:GetPlayer(data.PlayerID)) and data.player then
		if data.team then
			PlayerResource:SetCustomTeamAssignment(tonumber(data.player), tonumber(data.team))
		end
		if data.player2 then
			local team = PlayerResource:GetCustomTeamAssignment(data.player)
			local team2 = PlayerResource:GetCustomTeamAssignment(data.player2)
			PlayerResource:SetCustomTeamAssignment(tonumber(data.player2), DOTA_TEAM_NOTEAM)
			PlayerResource:SetCustomTeamAssignment(tonumber(data.player), team2)
			PlayerResource:SetCustomTeamAssignment(tonumber(data.player2), team)
		end
	end
end

function GameMode:SetHelpDisabled(data)
	local player = data.player or -1
	if PlayerResource:IsValidPlayerID(player) then
		PlayerResource:SetDisableHelpForPlayerID(data.PlayerID, player, tonumber(data.disabled) == 1)
	end
end

function CustomChatSay(playerId, teamonly, data)
	if PlayerResource:IsValidPlayerID(playerId) and PlayerResource:IsBanned(playerId) then return end
	if GameMode:CustomChatFilter(playerId, teamonly, data) then
		local heroName
		if HeroSelection:GetState() == HERO_SELECTION_PHASE_END then
			heroName = HeroSelection:GetSelectedHeroName(playerId)
		end
		local args = {playerId=playerId, hero=heroName}
		if data.text then
			args.text = data.text
		else
			if type(teamonly) ~= "boolean" and data.localizable then
				args.localizable = data.localizable
				args.variables = data.variables
				args.player = data.player
			else
				teamonly = true
				if data.GoldUnit then
					local unit = EntIndexToHScript(tonumber(data.GoldUnit))
					if IsValidEntity(unit) and unit:GetTeam() == PlayerResource:GetTeam(playerId) then
						args.gold = Gold:GetGold(unit)
						args.player = UnitVarToPlayerID(unit)
					else
						return
					end
				elseif data.ability then
					local ability = EntIndexToHScript(data.ability)
					if IsValidEntity(ability) then
						args.ability = data.ability
						args.unit = ability:GetCaster():GetEntityIndex()
						args.player = UnitVarToPlayerID(ability:GetCaster())
					else
						return
					end
				elseif data.shop_item_name then
					local item = data.shop_item_name
					if item then
						local team = PlayerResource:GetTeam(playerId)
						local stocks = PanoramaShop:GetItemStockCount(team, item)
						if GetKeyValue(item, "ItemPurchasableFilter") == 0 or GetKeyValue(item, "ItemPurchasable") == 0 then
							args.boss_drop = true
						elseif stocks and stocks < 1 then
							args.stock_time = math.round(PanoramaShop:GetItemStockCooldown(team, item))
						elseif data.gold then --relying on client for that
							local gold_required = data.gold - Gold:GetGold(playerId)
							if gold_required > 0 then
								args.gold = gold_required
							end
						end
						args.shop_item_name = item
						args.isQuickbuy = data.isQuickbuy == 1
					end
				elseif data.xpunit then
					local unit = EntIndexToHScript(data.xpunit)
					if IsValidEntity(unit) then
						args.unit = data.xpunit
						args.level = unit:GetLevel()
						args.player = UnitVarToPlayerID(unit)
						args.isNeutral = args.player == -1
						if unit.GetCurrentXP and XP_PER_LEVEL_TABLE[args.level + 1] then
							args.xpToNextLevel = (XP_PER_LEVEL_TABLE[args.level + 1] or 0) - unit:GetCurrentXP()
						end
					end
				end
			end
		end
		local team = type(teamonly) == "number" and teamonly or PlayerResource:GetTeam(playerId)
		args.teamonly = type(teamonly) == "boolean" and teamonly
		if args.teamonly then
			CustomGameEventManager:Send_ServerToTeam(team, "custom_chat_recieve_message", args)
			--CustomGameEventManager:Send_ServerToTeam(1, "custom_chat_recieve_message", args) --TODO: Spect, need test
		else
			CustomGameEventManager:Send_ServerToAllClients("custom_chat_recieve_message", args)
		end
	end
end

function GameMode:OnAdsClicked(data)
	local playerID = data.PlayerID
	local key = data.source == "loading_screen" and "adsClickedLoading" or "adsClicked"
	if not PLAYER_DATA[playerID][key] then
		PLAYER_DATA[playerID][key] = true
	end
end
