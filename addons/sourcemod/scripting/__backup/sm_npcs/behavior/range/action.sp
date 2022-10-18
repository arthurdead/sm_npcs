CustomBehaviorActionEntry basic_range_action;

void basic_range_action_init()
{
	basic_range_action = new CustomBehaviorActionEntry("BasicRange");
	basic_range_action.set_function("OnStart", action_start);
	basic_range_action.set_function("Update", action_update);
	basic_range_action.set_function("OnEnd", action_end);
	basic_range_action.set_function("OnStuck", shared_stuck);
	basic_range_action.set_function("OnKilled", shared_killed);
}

static void action_end(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction next)
{
	ArrayList stopped_areas = action.get_data("stopped_areas");
	delete stopped_areas;

	PathFollower path = action.get_data("path");
	delete path;
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("victim", INVALID_ENT_REFERENCE);
	action.set_data("victim_time", 0.0);

	action.set_data("attack_time", 0.0);

	action.set_data("stopped", false);

	float stopped_pos[3];
	action.set_data_array("stopped_pos", stopped_pos, 3);

	float stopped_area_pos[3];
	action.set_data_array("stopped_area_pos", stopped_area_pos, 3);

	action.set_data("stopped_areas", new ArrayList());

	action.set_data("stopped_area_change_time", 0.0);

	action.set_data("stopped_area_pos_change_time", 0.0);

	action.set_data("stopped_area", CNavArea_Null);

	PathFollower path = new PathFollower();
	shared_path_init(path);
	action.set_data("path", path);

	return result.Continue();
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	int victim = EntRefToEntIndex(action.get_data("victim"));
	float victim_time = action.get_data("victim_time");

	IVision vision = bot.VisionInterface;

	if(victim == -1 || !shared_is_victim_chaseable(bot, entity, victim, false) || (GetGameTime() - victim_time) > 10.0) {
		victim = shared_select_victim(entity, bot, vision, false);
		action.set_data("victim", victim == -1 ? INVALID_ENT_REFERENCE : EntIndexToEntRef(victim));
		action.set_data("victim_time", GetGameTime());
	}

	IBody body = bot.BodyInterface;
	//IBodyCustom body_custom = view_as<IBodyCustom>(body);
	ILocomotion locomotion = bot.LocomotionInterface;

	float chase_range = RANGED_RANGE - 5.0;

	if(sm_npcs_debug_pathing.BoolValue) {
		chase_range = 50.0;
	}

	ArousalType arousal = NEUTRAL;

	bool sight_clear = false;
	float sight_pos[3];

	shared_handle_speed(entity, bot, locomotion, body, victim);

	bool pathing = false;

	PathFollower path = action.get_data("path");

	if(victim != -1) {
		sight_clear = vision.IsLineOfSightClearToEntity(victim, sight_pos);

		arousal = ALERT;

		if(sight_clear) {
			float victim_center[3];
			EntityWorldSpaceCenter(victim, victim_center);

			locomotion.FaceTowards(victim_center);
		}

		if(bot.IsRangeGreaterThanEntity(victim, chase_range) || !sight_clear) {
			if(action.get_data("stopped")) {
				path.Invalidate();
				action.set_data("stopped", false);
			}

			if(path.Age > 1.0) {
				path.ComputeEntity(bot, victim, baseline_path_cost, cost_flags_safest|cost_flags_mod_small);
			}

			pathing = true;
		}

		if(sight_clear) {
			if(!sm_npcs_debug_pathing.BoolValue) {
				Handle pl;
				Function func = action.get_function("handle_fire", pl);
				if(func != INVALID_FUNCTION && pl != null) {
					Call_StartFunction(pl, func);
					Call_PushCell(action);
					Call_PushCell(bot);
					Call_PushCell(entity);
					Call_PushCell(victim);
					Call_PushArray(sight_pos, 3);
					Call_Finish();
				}
			}

			arousal = INTENSE;
		}
	}

	shared_handle_anim(locomotion, body, sight_clear, victim);

	//float ground_speed = locomotion.GroundSpeed;

	if(!pathing) {
		float feet[3];
		locomotion.GetFeet(feet);

		float stopped_pos[3];
		action.get_data_array("stopped_pos", stopped_pos, 3);

		//NDebugOverlay_Box(stopped_pos, VEC_HULL_MINS, VEC_HULL_MAXS, 255, 0, 0, 255, NDEBUG_PERSIST_TILL_NEXT_SERVER);

		bool just_stopped = false;

		if(!action.get_data("stopped")) {
			stopped_pos = feet;
			action.set_data_array("stopped_pos", feet, 3);
			action.set_data("stopped", true);
			just_stopped = true;
		}

		ArrayList stopped_areas = action.get_data("stopped_areas");

		if(just_stopped) {
			stopped_areas.Clear();

			CNavArea victim_area = CNavArea_Null;
			if(victim != -1) {
				victim_area = GetEntityLastKnownArea(victim);
			}

			CNavArea start_area = GetEntityLastKnownArea(entity);
			if(start_area != CNavArea_Null) {
				ArrayList tmp_areas = new ArrayList();
				CollectSurroundingAreas(tmp_areas, start_area, 1000.0, locomotion.StepHeight, locomotion.DeathDropHeight);
				int len = tmp_areas.Length;
				for(int j = 0; j < len; ++j) {
					CTFNavArea area = tmp_areas.Get(j);

					if(!area.ValidForWanderingPopulation) {
						continue;
					}

					if(victim_area != CNavArea_Null && area == victim_area) {
						continue;
					}

					if(stopped_areas.FindValue(area) == -1) {
						stopped_areas.Push(area);
					}
				}
				delete tmp_areas;
			}

			action.set_data("stopped_areas", stopped_areas);
		}

		CNavArea stopped_area = action.get_data("stopped_area");

		float stopped_area_pos_change_time = action.get_data("stopped_area_pos_change_time");

		float stopped_area_change_time = action.get_data("stopped_area_change_time");
		if(stopped_area_change_time < GetGameTime()) {
			int len = stopped_areas.Length;
			if(len > 0) {
				stopped_area = stopped_areas.Get(GetURandomInt() % len);
				action.set_data("stopped_area", stopped_area);
				stopped_area_pos_change_time = 0.0;
				path.Invalidate();
			}
			action.set_data("stopped_area_change_time", GetGameTime() + 5.0);
		}

		float stopped_area_pos[3];
		action.get_data_array("stopped_area_pos", stopped_area_pos, 3);

		if(stopped_area_pos_change_time < GetGameTime()) {
			if(stopped_area != CNavArea_Null) {
				stopped_area.GetRandomPoint(stopped_area_pos);
				action.set_data_array("stopped_area_pos", stopped_area_pos, 3);
				path.ComputeVector(bot, stopped_area_pos, baseline_path_cost, cost_flags_safest|cost_flags_mod_small);
			}
			action.set_data("stopped_area_pos_change_time", GetGameTime() + 0.5);
		}

		//NDebugOverlay_Box(stopped_area_pos, VEC_HULL_MINS, VEC_HULL_MAXS, 0, 0, 255, 255, NDEBUG_PERSIST_TILL_NEXT_SERVER);
	}

	path.AllowFacing = !sight_clear;
	path.Update(bot);
	path.AllowFacing = true;

	body.Arousal = arousal;

	return result.Continue();
}