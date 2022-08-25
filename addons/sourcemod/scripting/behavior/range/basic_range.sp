BehaviorActionEntry basic_range_action;

void basic_range_action_init()
{
	basic_range_action = new BehaviorActionEntry("BasicRange");
	basic_range_action.set_function("OnStart", basic_range_start);
	basic_range_action.set_function("Update", basic_range_update);
	basic_range_action.set_function("OnEnd", shared_end_chase);
	basic_range_action.set_function("OnStuck", shared_stuck_chase);
	basic_range_action.set_function("OnKilled", shared_killed);
}

static BehaviorResultType basic_range_start(BehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("victim", INVALID_ENT_REFERENCE);
	action.set_data("victim_time", 0.0);

	action.set_data("attack_time", 0.0);

	return shared_start_chase(action, bot, entity, prior, result);
}

static bool basic_range_is_victim_chaseable(int victim)
{
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

	int ground = GetEntPropEnt(victim, Prop_Send, "m_hGroundEntity");
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

	return true;
}

static int basic_range_select_victim(INextBot bot)
{
	float victim_range = 9999999999.0;
	float visible_victim_range = 999999999.0;

	int closest_victim = -1;
	int new_victim = -1;

	IVision vision = bot.VisionInterface;

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i)) {
			continue;
		}

		if(!basic_range_is_victim_chaseable(i)) {
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

static BehaviorResultType basic_range_update(BehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	int victim = EntRefToEntIndex(action.get_data("victim"));
	float victim_time = action.get_data("victim_time");

	if(victim == -1 || !basic_range_is_victim_chaseable(victim) || (GetGameTime() - victim_time) > 10.0) {
		victim = basic_range_select_victim(bot);
		action.set_data("victim", victim == -1 ? INVALID_ENT_REFERENCE : EntIndexToEntRef(victim));
		action.set_data("victim_time", GetGameTime());
	}

	IVision vision = bot.VisionInterface;
	IBody body = bot.BodyInterface;
	IBodyCustom body_custom = view_as<IBodyCustom>(body);
	ILocomotion locomotion = bot.LocomotionInterface;

	float chase_range = 20.0;
	float attack_range = 70.0;

	if(victim != -1) {
		if(bot.IsRangeGreaterThanEntity(victim, chase_range)) {
			shared_update_chase(action, entity, bot, locomotion, body, victim);
			body.Arousal = ALERT;
		}

		bool in_attack_range = (bot.IsRangeLessThanEntity(victim, attack_range));
		bool in_face_range = (in_attack_range);

		if(in_attack_range && vision.IsLineOfSightClearToEntity(victim)) {
			float attack_time = action.get_data("attack_time");
			if(attack_time < GetGameTime()) {
				if(body.StartActivity(ACT_MELEE_ATTACK1, NO_ACTIVITY_FLAGS)) {
					int sequence = body_custom.Sequence;
					if(sequence != -1) {
						float duration = AnimatingSequenceDuration(entity, sequence);
						attack_time = (GetGameTime() + duration);
						action.set_data("attack_time", attack_time);
					}
				}
			}

			body.Arousal = INTENSE;
		}

		if(false && in_face_range && vision.IsLineOfSightClearToEntity(victim)) {
			float victim_center[3];
			EntityWorldSpaceCenter(victim, victim_center);

			//locomotion.FaceTowards(victim_center);
		}
	} else {
		body.Arousal = NEUTRAL;
	}

	float attack_time = action.get_data("attack_time");
	if(attack_time < GetGameTime()) {
		float ground_speed = locomotion.GroundSpeed;
		if(ground_speed > 0.1) {
			if(locomotion.Running) {
				if(!body.IsActivity(ACT_RUN)) {
					body.StartActivity(ACT_RUN, NO_ACTIVITY_FLAGS);
				}
			} else {
				if(!body.IsActivity(ACT_WALK)) {
					body.StartActivity(ACT_WALK, NO_ACTIVITY_FLAGS);
				}
			}
		} else {
			if(!body.IsActivity(ACT_IDLE)) {
				body.StartActivity(ACT_IDLE, NO_ACTIVITY_FLAGS);
			}
		}
	}

	return BEHAVIOR_CONTINUE;
}