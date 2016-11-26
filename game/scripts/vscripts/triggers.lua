function ArenaZoneOnStartTouch(trigger)
	if Duel.DuelStatus == DOTA_DUEL_STATUS_IN_PROGRESS then
		table.insert(Heroes_In_Arena_Zone, trigger.activator)
	end
end

function ArenaZoneOnEndTouch(trigger)
	table.removeByValue(Heroes_In_Arena_Zone, trigger.activator)
	if trigger.activator and Duel.DuelStatus == DOTA_DUEL_STATUS_IN_PROGRESS then
		Timers:CreateTimer(function()
			if not table.contains(Heroes_In_Arena_Zone, trigger.activator) and Duel.DuelStatus == DOTA_DUEL_STATUS_IN_PROGRESS then
				trigger.activator:InterruptMotionControllers(true)
				FindClearSpaceForUnit(trigger.activator, Entities:FindByName(nil, "target_mark_arena_team" .. trigger.activator:GetTeamNumber()):GetAbsOrigin(), false)
			end
		end)
	end
end

function FountainOnStartTouch(trigger, team)
	print("asd")
	local unit = trigger.activator
	if unit and unit:GetTeam() == team then
		unit:AddNewModifier(unit, nil, "modifier_fountain_aura_arena", nil)
	elseif not IsBossEntity(unit) then
		local fountain = FindFountain(team)
		if fountain then
			fountain:EmitSound("Ability.LagunaBlade")
			unit:EmitSound("Ability.LagunaBladeImpact")
			local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_lina/lina_spell_laguna_blade.vpcf", PATTACH_ABSORIGIN, fountain)
			ParticleManager:SetParticleControl(pfx, 0, fountain:GetAbsOrigin() + Vector(0,0,224))
			ParticleManager:SetParticleControlEnt(pfx, 1, unit, PATTACH_POINT_FOLLOW, "attach_hitloc", unit:GetAbsOrigin(), true)
		end
		TrueKill(nil, nil, unit)
	end
end
function Fountain2OnStartTouch(trigger)
	FountainOnStartTouch(trigger, DOTA_TEAM_GOODGUYS)
end
function Fountain3OnStartTouch(trigger)
	FountainOnStartTouch(trigger, DOTA_TEAM_BADGUYS)
end

function Fountain2OnEndTouch(trigger)
	local unit = trigger.activator
	if unit and unit:GetTeam() == DOTA_TEAM_GOODGUYS then
		unit:RemoveModifierByName("modifier_fountain_aura_arena")
	end
end

function Fountain3OnEndTouch(trigger)
	local unit = trigger.activator
	if unit and unit:GetTeam() == DOTA_TEAM_BADGUYS then
		unit:RemoveModifierByName("modifier_fountain_aura_arena")
	end
end