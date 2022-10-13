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
			} else if(victim != -1) {
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
	if(victim >= 1 && victim <= MaxClients) {
		if(IsClientSourceTV(victim) ||
			IsClientReplay(victim)) {
			return false;
		}
	}

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

	if(!entity_is_damageable(victim, false)) {
		return false;
	}

	int my_team = GetEntProp(entity, Prop_Data, "m_iTeamNum");
	int victim_team = GetEntProp(victim, Prop_Data, "m_iTeamNum");

	Disposition_t disposition = CombatCharacterDisposition(entity, victim);
	if(bot.IsFriend(victim) ||
		TeamManager_AreTeamsFriends(my_team, victim_team) ||
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

BehaviorResultType shared_stuck(CustomBehaviorAction action, INextBot bot, int entity, BehaviorResult result)
{
	bool teleported = false;

	int mask = bot.BodyInterface.SolidMask;

	float pos[3];

	float mins[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
	float maxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

	PathFollower path = bot.CurrentPath;
	if(path == null) {
		return result.TryContinue();
	}

	if(!teleported) {
		Segment goal = path.CurrentGoal;
		while(goal != Segment_Null) {
			goal.GetPosition(pos);

			pos[2] += -mins[2] + STEP_HEIGHT;

			if(can_spawn_here(mask, mins, maxs, pos)) {
				teleported = true;
				TeleportEntity(entity, pos);
				break;
			}

			goal = path.NextSegment(goal);
		}
	}

	if(!teleported) {
		Segment goal = path.CurrentGoal;
		if(goal != Segment_Null) {
			goal.GetPosition(pos);

			pos[2] += -mins[2] + STEP_HEIGHT;

			teleported = true;
			TeleportEntity(entity, pos);
		}
	}

	return result.TryContinue();
}

void shared_path_init(PathFollower path)
{
	path.GoalTolerance = 25.0;
	path.MinLookAheadDistance = 300.0;
}

BehaviorResultType shared_killed(CustomBehaviorAction action, INextBot bot, int entity, const CTakeDamageInfo info, BehaviorResult result)
{
	Handle pl;
	Function func = action.get_function("handle_die", pl);
	if(func != INVALID_FUNCTION && pl != null) {
		Call_StartFunction(pl, func);
		Call_PushCell(entity);
		bool res = true;
		Call_Finish(res);

		if(!res) {
			return result.TryDone(RESULT_CRITICAL, "npc killed");
		}
	}

	CombatCharacterEventKilled(entity, info);

	if(AnimatingSelectWeightedSequence(entity, ACT_DIERAGDOLL) == -1) {
		RequestFrame(frame_remove_npc, EntIndexToEntRef(entity));
	}

	return result.TryDone(RESULT_CRITICAL, "npc killed");
}

void shared_handle_speed(int entity, INextBot bot, ILocomotion locomotion, IBody body, int victim)
{
	float targetspeed = 0.0;
	if(victim != -1) {
		if(victim >= 1 && victim <= MaxClients) {
			targetspeed = get_player_class_speed(victim);
		} else {
			INextBot victim_bot = INextBot(victim);
			if(victim_bot != INextBot_Null) {
				ILocomotion victim_locomotion = victim_bot.LocomotionInterface;
				targetspeed = victim_locomotion.RunSpeed;
			}
		}
	}

	IBodyCustom body_custom = view_as<IBodyCustom>(body);
	AnyLocomotion custom_locomotion = view_as<AnyLocomotion>(locomotion);

	bool running = locomotion.Running;

	float anim_speed = 0.0;
	if(running) {
		if(body_custom.has_data("run_anim_speed")) {
			anim_speed = body_custom.get_data("run_anim_speed");
		}
	} else {
		if(body_custom.has_data("walk_anim_speed")) {
			anim_speed = body_custom.get_data("walk_anim_speed");
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
}