bool TyrantEnumStagger(int entity, int attacker)
{
	if(entity >= 1 && entity <= MaxClients) {
		if(L4D2_IsSurvivorBusy(entity)) {
			return true;
		}

		L4D_StaggerPlayer(entity, attacker, NULL_VECTOR);
	}
	return true;
}

bool TyrantEnumKockback(int entity, DataPack data)
{
	if(entity >= 1 && entity <= MaxClients) {
		if(L4D2_IsSurvivorBusy(entity)) {
			return true;
		}

		BehaviorAction action = data.ReadCell();
		int type = data.ReadCell();
		int attacker = data.ReadCell();
		float ang[3];
		data.ReadFloatArray(ang, sizeof(ang));
		data.Reset();

		float dir[3];
		GetAngleVectors(ang, dir, NULL_VECTOR, NULL_VECTOR);

		if(type == 20) {
			ScaleVector(dir, 200.0);
		} else if(type == 21) {
			ScaleVector(dir, 100.0);
		}

		SDKHooks_TakeDamage(entity, attacker, attacker, 5.0, DMG_CRUSH|DMG_CLUB);
		L4D2_CTerrorPlayer_Fling(entity, entity, dir);
		SetEntProp(entity, Prop_Send, "m_knockdownReason", 0);

		action.set_data("hit", true);
	}
	return true;
}

void DoTyrantStagger(INextBot bot, int entity)
{
	float mins[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	float maxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

	float end[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", end);

	if(bot.IsDebugging(NEXTBOT_BEHAVIOR)) {
		DrawHull(end, _, mins, maxs);
	}

	TR_EnumerateEntitiesHull(end, end, mins, maxs, PARTITION_SOLID_EDICTS, TyrantEnumStagger, entity);
}

void DoTyrantAttack(BehaviorAction action, INextBot bot, int entity, float pos[3], float ang[3], int type)
{
	float mins[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	float maxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

	float end[3];
	end = pos;

	if(type == 20) {
		VectorAddRotatedOffset(ang, end, view_as<float>({70.0, 0.0, 0.0}));
	} else if(type == 21) {
		VectorAddRotatedOffset(ang, end, view_as<float>({100.0, 0.0, 0.0}));
	}

	if(bot.IsDebugging(NEXTBOT_BEHAVIOR)) {
		DrawHull(end, _, mins, maxs);
	}

	//EmitSoundToAll(tyrantswing[GetRandomInt(0, sizeof(tyrantswing)-1)], entity);

	DataPack data = new DataPack();
	data.WriteCell(action);
	data.WriteCell(type);
	data.WriteCell(entity);
	data.WriteFloatArray(ang, sizeof(ang));
	data.Reset();
	TR_EnumerateEntitiesHull(end, end, mins, maxs, PARTITION_SOLID_EDICTS, TyrantEnumKockback, data);
	delete data;
}

void TyrantWalking(INextBot bot, int entity, int target = -1)
{
	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);

	int sequence = 1;
	if(locomotion.AttemptingToMove) {
		if(target != -1) {
			if(bot.GetRangeToEntity(target) >= 200.0) {
				sequence = 4;
				DoTyrantStagger(bot, entity);
			} else {
				sequence = 3;
			}
		} else {
			sequence = 2;
		}

		/*if(GetEntPropFloat(entity, Prop_Data, "m_flLastStep") <= GetGameTime()) {
			EmitSoundToAll(tyrantstep[GetRandomInt(0, sizeof(tyrantstep)-1)], entity);
			SetEntPropFloat(entity, Prop_Data, "m_flLastStep", GetGameTime() + 0.1);
		}*/
	}

	BaseAnimating anim = BaseAnimating(entity);
	anim.ResetSequenceEx(sequence);

	float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed == 0.0) {
		m_flGroundSpeed = 0.1;
	}

	locomotion.RunSpeed = m_flGroundSpeed;
	locomotion.WalkSpeed = m_flGroundSpeed;
}