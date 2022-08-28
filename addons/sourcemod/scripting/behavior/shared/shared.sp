#define THREAT_SPEED_MULT 1.2
#define THREAT_SPEED_DIV 2.0

void shared_handle_anim(ILocomotion locomotion, IBody body, bool sight_clear, int victim)
{
	float ground_speed = locomotion.GroundSpeed;
	if(ground_speed > 0.1) {
		if(locomotion.Running) {
			if(sight_clear) {
				body.StartActivity(ACT_RUN_AGITATED, NO_ACTIVITY_FLAGS);
			} else if(victim != -1) {
				body.StartActivity(ACT_RUN_STIMULATED, NO_ACTIVITY_FLAGS);
			} else {
				body.StartActivity(ACT_RUN_RELAXED, NO_ACTIVITY_FLAGS);
			}
		} else {
			if(sight_clear) {
				body.StartActivity(ACT_WALK_AGITATED, NO_ACTIVITY_FLAGS);
			} if(victim != -1) {
				body.StartActivity(ACT_WALK_STIMULATED, NO_ACTIVITY_FLAGS);
			} else {
				body.StartActivity(ACT_WALK_RELAXED, NO_ACTIVITY_FLAGS);
			}
		}
	} else {
		if(sight_clear) {
			body.StartActivity(ACT_IDLE_AGITATED, NO_ACTIVITY_FLAGS);
		} else if(victim != -1) {
			body.StartActivity(ACT_IDLE_STIMULATED, NO_ACTIVITY_FLAGS);
		} else {
			body.StartActivity(ACT_IDLE_RELAXED, NO_ACTIVITY_FLAGS);
		}
	}
}

bool shared_is_victim_chaseable(INextBot bot, int entity, int victim, bool check_ground = true)
{
	if(victim == 0 ||
		victim == -1 ||
		victim == entity ||
		bot.IsSelf(victim)) {
		return false;
	}

	if(!EntityIsCombatCharacter(victim)) {
		return false;
	}

	char classname[64];
	GetEntityClassname(victim, classname, sizeof(classname));

	if(StrContains(classname, "obj_") != -1) {
		int builder = GetEntPropEnt(victim, Prop_Send, "m_hBuilder");
		if(builder == -1) {
			return false;
		}
	}

	if(GetEntProp(victim, Prop_Data, "m_takedamage") == DAMAGE_NO ||
		GetEntProp(victim, Prop_Data, "m_lifeState") != LIFE_ALIVE ||
		GetEntProp(entity, Prop_Data, "m_iEFlags") & EFL_KILLME) {
		return false;
	}

	if(victim >= 1 && victim <= MaxClients) {
		if(!IsPlayerAlive(victim) ||
			GetClientTeam(victim) < 2 ||
			TF2_GetPlayerClass(victim) == TFClass_Unknown) {
			return false;
		}

		if(TF2_IsPlayerInCondition(victim, TFCond_HalloweenGhostMode) ||
			TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) ||
			TF2_IsPlayerInCondition(victim, TFCond_UberchargedHidden) ||
			TF2_IsPlayerInCondition(victim, TFCond_UberchargedCanteen) ||
			TF2_IsPlayerInCondition(victim, TFCond_UberchargedOnTakeDamage)) {
			return false;
		}
	}

	Disposition_t disposition = CombatCharacterDisposition(entity, victim);
	if(bot.IsFriend(victim) ||
		GetEntProp(entity, Prop_Data, "m_iTeamNum") == GetEntProp(victim, Prop_Data, "m_iTeamNum") ||
		disposition == D_LI ||
		disposition == D_FR) {
		return false;
	}

	if(check_ground) {
		int ground = GetEntPropEnt(victim, Prop_Data, "m_hGroundEntity");
		if(ground != -1) {
			CNavArea last_area = GetEntityLastKnownArea(victim);
			if(last_area != CNavArea_Null) {
				float victim_pos[3];
				GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", victim_pos);

				float victim_nav_pos[3];
				last_area.GetClosestPointOnArea(victim_pos, victim_nav_pos);

				float victim_pos_delta[3];
				SubtractVectors(victim_pos, victim_nav_pos, victim_pos_delta);

				float length = GetVectorLength2D(victim_pos_delta);
				if(length >= 50.0) {
					return false;
				}
			} else {
				return false;
			}
		}
	}

	return true;
}

int shared_select_victim(int entity, INextBot bot, IVision vision)
{
	float victim_range = 9999999999.0;
	float visible_victim_range = 999999999.0;

	int closest_victim = -1;
	int new_victim = -1;

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i)) {
			continue;
		}

		if(!shared_is_victim_chaseable(bot, entity, i)) {
			continue;
		}

		float range = bot.GetRangeSquaredToEntity(i);
		if(range < visible_victim_range) {
			if(vision.IsLineOfSightClearToEntity(i)) {
				closest_victim = i;
				visible_victim_range = range;
			}
		}

		if(range < victim_range) {
			new_victim = i;
			victim_range = range;
		}
	}

	int i = -1;
	while((i = FindEntityByClassname(i, "*")) != -1) {
		if(!shared_is_victim_chaseable(bot, entity, i)) {
			continue;
		}

		float range = bot.GetRangeSquaredToEntity(i);
		if(range < visible_victim_range) {
			if(vision.IsLineOfSightClearToEntity(i)) {
				closest_victim = i;
				visible_victim_range = range;
			}
		}

		if(range < victim_range) {
			new_victim = i;
			victim_range = range;
		}
	}

	if(closest_victim != -1) {
		return closest_victim;
	} else {
		return new_victim;
	}
}

BehaviorResultType shared_stuck_chase(BehaviorAction action, INextBot bot, int entity, BehaviorResult result)
{
	DirectChasePath path = action.get_data("path");

	if(path.CurrentGoal != Segment_Null) {
		float pos[3];
		path.CurrentGoal.GetPosition(pos);
		TeleportEntity(entity, pos);
	}

	result.priority = RESULT_TRY;
	return BEHAVIOR_CONTINUE;
}

void shared_end_chase(BehaviorAction action, INextBot bot, int entity, BehaviorAction next)
{
	DirectChasePath path = action.get_data("path");
	delete path;
}

BehaviorResultType shared_start_chase(BehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	DirectChasePath path = new DirectChasePath(LEAD_SUBJECT);
	path.GoalTolerance = 0.0;
	path.MinLookAheadDistance = 300.0;
	path.LeadRadius = 500.0;

	action.set_data("path", path);

	return BEHAVIOR_CONTINUE;
}

BehaviorResultType shared_killed(BehaviorAction action, INextBot bot, int entity, const CTakeDamageInfo info, BehaviorResult result)
{
	CombatCharacterEventKilled(entity, info);

	if(AnimatingSelectWeightedSequence(entity, ACT_DIERAGDOLL) == -1) {
		int flags = GetEntProp(entity, Prop_Send, "m_fEffects");
		flags |= EF_NODRAW;
		SetEntProp(entity, Prop_Send, "m_fEffects", flags);

		RequestFrame(frame_remove_npc, EntIndexToEntRef(entity));
	}

	if(action.has_function("handle_die")) {
		Function func = action.get_function("handle_die");
		Call_StartFunction(null, func);
		Call_PushCell(entity);
		Call_Finish();
	}

	result.set_reason("npc killed");
	result.priority = RESULT_IMPORTANT;
	return BEHAVIOR_DONE;
}

void shared_update_chase(BehaviorAction action, int entity, INextBot bot, ILocomotion locomotion, IBody body, int victim)
{
	float targetspeed = 0.0;
	if(victim >= 1 && victim <= MaxClients) {
		targetspeed = get_player_class_speed(victim);
	} else {
		INextBot victim_bot = INextBot(victim);
		if(victim_bot != INextBot_Null) {
			ILocomotion victim_locomotion = victim_bot.LocomotionInterface;
			targetspeed = victim_locomotion.RunSpeed;
		}
	}

	IBodyCustom body_custom = view_as<IBodyCustom>(body);
	AnyLocomotion custom_locomotion = view_as<AnyLocomotion>(locomotion);

	bool running = locomotion.Running;

	float anim_speed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
	if(anim_speed < 0.1) {
		if(running) {
			if(body_custom.has_data("run_anim_speed")) {
				anim_speed = body_custom.get_data("run_anim_speed");
			}
		} else {
			if(body_custom.has_data("walk_anim_speed")) {
				anim_speed = body_custom.get_data("walk_anim_speed");
			}
		}
	}

	float speed = 0.0;

	if(targetspeed > 0.1) {
		if(anim_speed > 0.1) {
			speed = (anim_speed + (targetspeed / THREAT_SPEED_DIV));
		} else {
			speed = (targetspeed * THREAT_SPEED_MULT);
		}
	} else {
		if(anim_speed > 0.1) {
			speed = anim_speed;
		} else {
			if(running) {
				speed = 250.0;
			} else {
				speed = 250.0;
			}
		}
	}

	if(speed > 0.1) {
		if(running) {
			custom_locomotion.RunSpeed = speed;
		} else {
			custom_locomotion.WalkSpeed = speed;
		}
	}

	DirectChasePath path = action.get_data("path");
	path.Update(bot, victim, baseline_path_cost, cost_flags_safest|cost_flags_mod_small);
}