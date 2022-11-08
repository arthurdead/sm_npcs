CustomBehaviorActionEntry attack_action;

void attack_action_init()
{
	attack_action = new CustomBehaviorActionEntry("Attack");
	attack_action.set_function("OnStart", action_start);
	attack_action.set_function("OnEnd", action_end);
	attack_action.set_function("Update", action_update);
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	ChasePath chasePath = new ChasePath(LEAD_SUBJECT);
	chasePath.MinLookAheadDistance = GetDesiredPathLookAheadRange(entity);
	action.set_data("m_chasePath", chasePath);

	PathFollower path = new PathFollower();
	path.MinLookAheadDistance = GetDesiredPathLookAheadRange(entity);
	action.set_data("m_path", path);

	action.set_data("m_repathTimer", GetGameTime());

	action.set_data("stopped", false);

	action.set_data("stopped_area", CNavArea_Null);

	float stopped_area_pos[3];
	action.set_data_array("stopped_area_pos", stopped_area_pos, 3);

	action.set_data("stopped_areas", new ArrayList());

	action.set_data("stopped_area_change_time", 0.0);

	action.set_data("stopped_area_pos_change_time", 0.0);

	action.set_data("stopped_target_area", CNavArea_Null);

	return result.Continue();
}

static void action_end(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction next)
{
	ArrayList stopped_areas = action.get_data("stopped_areas");
	delete stopped_areas;

	ChasePath chasePath = action.get_data("m_chasePath");
	delete chasePath;

	PathFollower path = action.get_data("m_path");
	delete path;
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	IVision vision = bot.VisionInterface;
	IIntention intention = bot.IntentionInterface;
	IIntentionCustom intention_custom = view_as<IIntentionCustom>(intention);
	IBody body = bot.BodyInterface;
	ILocomotion locomotion = bot.LocomotionInterface;

	CKnownEntity threat = vision.GetPrimaryKnownThreat();
	if(threat == CKnownEntity_Null || threat.Obsolete || intention.ShouldAttack(bot, threat) == ANSWER_NO) {
		return result.Done("No threat");
	}

	int threat_entity = threat.Entity;

	float threat_pos[3];
	EntityGetAbsOrigin(threat_entity, threat_pos);

	float threat_eye_pos[3];
	EntityEyePosition(threat_entity, threat_eye_pos);

	bool melee = intention_custom.has_data("melee_only");

	float attack_range = 0.0;
	float max_attack_range = 0.0;

	if(melee) {
		attack_range = 100.0;
		max_attack_range = 100.0;
	} else {
		attack_range = 500.0;
		max_attack_range = 9999999.0;
	}

	PathFollower path = action.get_data("m_path");

	float last_known_pos[3];
	threat.GetLastKnownPosition(last_known_pos);

	if(!threat.VisibleRecently ||
		bot.IsRangeGreaterThanVector(threat_pos, attack_range) ||
		!bot.IsLineOfFireClearVec(threat_eye_pos))
	{
		if(action.get_data("stopped")) {
			path.Invalidate();
			action.set_data("stopped", false);
		}

		ChasePath chasePath = action.get_data("m_chasePath");

		if(threat.VisibleRecently) {
			if(melee) {
				chasePath.Update(bot, threat_entity, baseline_path_cost, 0);
			} else {
				chasePath.Update(bot, threat_entity, baseline_path_cost, 0);
			}
		} else {
			chasePath.Invalidate();

			if(bot.IsRangeLessThanVector(last_known_pos, 20.0)) {
				vision.ForgetEntity(threat_entity);
				return result.Done("I lost my target!");
			}

			if(bot.IsRangeLessThanVector(last_known_pos, max_attack_range)) {
				float aim_pos[3];
				aim_pos[0] = last_known_pos[0];
				aim_pos[1] = last_known_pos[1];
				aim_pos[2] = last_known_pos[2] + HUMAN_EYE_HEIGHT;

				body.AimHeadTowardsVec(aim_pos, IMPORTANT, 0.2, INextBotReply_Null, "Looking towards where we lost sight of our victim");
			}

			path.Update(bot);

			float repathTimer = action.get_data("m_repathTimer");
			if(repathTimer <= GetGameTime()) {
				repathTimer = GetRandomFloat(3.0, 5.0);
				action.set_data("m_repathTimer", repathTimer);

				if(melee) {
					path.ComputeVector(bot, last_known_pos, baseline_path_cost, 0);
				} else {
					path.ComputeVector(bot, last_known_pos, baseline_path_cost, 0);
				}
			}
		}
	} else {
		if(!action.get_data("stopped")) {
			path.Invalidate();
			action.set_data("stopped", true);
		}

		path.Update(bot);

		if(!melee) {
			CNavArea stopped_area = action.get_data("stopped_area");

			ArrayList stopped_areas = action.get_data("stopped_areas");

			CNavArea victim_area = GetEntityLastKnownArea(threat_entity);

			float stopped_area_pos_change_time = action.get_data("stopped_area_pos_change_time");
			float stopped_area_change_time = action.get_data("stopped_area_change_time");

			if(stopped_area != victim_area) {
				stopped_areas.Clear();
				stopped_area_change_time = 0.0;
				action.set_data("stopped_area", victim_area);

				CNavArea start_area = victim_area;
				if(start_area != CNavArea_Null) {
					ArrayList tmp_areas = new ArrayList();
					CollectSurroundingAreas(tmp_areas, start_area, attack_range, locomotion.StepHeight, locomotion.DeathDropHeight);
					int len = tmp_areas.Length;
					for(int j = 0; j < len; ++j) {
						CTFNavArea area = tmp_areas.Get(j);

						if(!area.ValidForWanderingPopulation) {
							continue;
						}

						if(victim_area != CNavArea_Null && area == victim_area) {
							continue;
						}

						if(!area.IsCompletelyVisible(victim_area)) {
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

			stopped_area = action.get_data("stopped_target_area");

			if(stopped_area_change_time < GetGameTime()) {
				int len = stopped_areas.Length;
				if(len > 0) {
					stopped_area = stopped_areas.Get(GetURandomInt() % len);
					action.set_data("stopped_target_area", stopped_area);
					stopped_area_pos_change_time = 0.0;
					path.Invalidate();
				}
				action.set_data("stopped_area_change_time", GetGameTime() + 2.0);
			}

			float stopped_area_pos[3];
			action.get_data_array("stopped_area_pos", stopped_area_pos, 3);

			if(stopped_area_pos_change_time < GetGameTime()) {
				if(stopped_area != CNavArea_Null) {
					stopped_area.GetRandomPoint(stopped_area_pos);
					action.set_data_array("stopped_area_pos", stopped_area_pos, 3);
					path.ComputeVector(bot, stopped_area_pos, baseline_path_cost, cost_flags_mod_heavy);
				}
				action.set_data("stopped_area_pos_change_time", GetGameTime() + 0.5);
			}

			//NDebugOverlay_Box(stopped_area_pos, VEC_HULL_MINS, VEC_HULL_MAXS, 0, 0, 255, 255, NDEBUG_PERSIST_TILL_NEXT_SERVER);
		}
	}

	return result.Continue();
}