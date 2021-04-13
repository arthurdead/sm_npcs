void tyrant_chase_init()
{
	tyrant_chase = new BehaviorActionEntry("tyrant_chase");
	tyrant_chase.set_function("Update", TyrantChaseUpdate);
	tyrant_chase.set_function("OnStart", TyrantChaseStart);
	tyrant_chase.set_function("OnEnd", TyrantChaseEnd);
	tyrant_chase.set_function("OnThreatChanged", TyrantChaseThreatChanged);
	tyrant_chase.set_function("OnContact", TyrantChaseContact);
}

BehaviorResultType TyrantChaseContact(BehaviorAction action, int entity, int threat, BehaviorResult result)
{
	if(threat == 0 ||
		threat >= 1 && threat <= MaxClients) {
		return BEHAVIOR_CONTINUE;
	}

	/*char classname[64];
	GetEntityClassname(threat, classname, sizeof(classname));

	if(StrContains(classname, "prop_door") != -1) {
		result.action = tyrant_kickdoor.create();
		result.action.set_data("entity", EntIndexToEntRef(threat));
		result.set_reason("door in the way");
		return BEHAVIOR_CHANGE_TO;
	}*/

	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantChaseThreatChanged(BehaviorAction action, int entity, int threat, BehaviorResult result)
{
	if(threat == -1) {
		return BEHAVIOR_CONTINUE;
	}

	action.set_data("target", EntIndexToEntRef(threat));
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantChaseStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	int target = action.get_data("target");
	if(target == -1) {
		INextBot bot = INextBot(entity);

		float range = 99999999.0;
		for(int i = 1; i <= MaxClients; ++i) {
			if(!IsClientInGame(i) ||
				!IsPlayerAlive(i)) {
				continue;
			}

			float tmprange = bot.GetRangeToEntity(i);
			if(tmprange < range) {
				range = tmprange;
				target = i;
			}
		}
		if(target == -1) {
			result.set_reason("no target");
			return BEHAVIOR_DONE;
		} else {
			action.set_data("target", EntIndexToEntRef(target));
		}
	}

	action.set_data("path", base_npc_create_chase(entity));
	return BEHAVIOR_CONTINUE;
}

bool TyrantEnumDoor(int entity, DataPack data)
{
	if(entity == 0 ||
		entity >= 1 && entity <= MaxClients)
	{
		return true;
	}

	if(!IsValidEntity(entity)) {
		return true;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	if(StrContains(classname, "prop_door") != -1) {
		if(GetEntProp(entity, Prop_Data, "m_eDoorState") == 0) {
			data.WriteCell(EntIndexToEntRef(entity));
			return false;
		}
	}

	return true;
}

BehaviorResultType TyrantChaseUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	int target = EntRefToEntIndex(action.get_data("target"));
	if(target == -1 ||
		!IsPlayerAlive(target) ||
		L4D2_IsSurvivorBusy(target)) {
		result.set_reason("target lost");
		return BEHAVIOR_DONE;
	}

	INextBot bot = INextBot(entity);
	IVision vision = bot.VisionInterface;

	float range = bot.GetRangeToEntity(target);
	if(range <= 70.0) {
		if(vision.IsInFieldOfViewEntity(target)) {
			result.action = tyrant_attack.create();
			result.action.set_data("sequence", 21);
			result.set_reason("target close");
			return BEHAVIOR_SUSPEND_FOR;
		}
	} else if(range <= 100.0)
	{
		if(vision.IsLookingAtEntity(target)) {
			result.action = tyrant_attack.create();
			result.action.set_data("sequence", 20);
			result.set_reason("target close");
			return BEHAVIOR_SUSPEND_FOR;
		}
	}

	ChasePath path = action.get_data("path");
	path.Update(bot, target, baseline_path_cost, cost_flags_mod);

	TyrantWalking(bot, entity, target);

	float mins[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	float maxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

	float pos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);

	float end[3];
	end = pos;

	float ang[3];
	GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);

	VectorAddRotatedOffset(ang, end, view_as<float>({70.0, 0.0, 0.0}));

	//DrawHull(end, ang, mins, maxs);

	DataPack data = new DataPack();
	data.WriteCell(-1);
	data.Reset();
	TR_EnumerateEntitiesHull(pos, end, mins, maxs, PARTITION_SOLID_EDICTS, TyrantEnumDoor, data);
	data.Reset();
	int door = EntRefToEntIndex(data.ReadCell());
	delete data;

	if(door != -1) {
		result.action = tyrant_kickdoor.create();
		result.action.set_data("entity", door);
		result.set_reason("door in the way");
		return BEHAVIOR_CHANGE_TO;
	}

	return BEHAVIOR_CONTINUE;
}

void TyrantChaseEnd(BehaviorAction action, int entity, BehaviorAction next)
{
	ChasePath path = action.get_data("path");
	delete path;
}