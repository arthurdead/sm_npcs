CustomBehaviorActionEntry retreat_to_cover_action;

void retreat_to_cover_action_init()
{
	retreat_to_cover_action = new CustomBehaviorActionEntry("RetreatToCover");
	retreat_to_cover_action.set_function("OnStart", action_start);
	retreat_to_cover_action.set_function("OnEnd", action_end);
	retreat_to_cover_action.set_function("Update", action_update);
	retreat_to_cover_action.set_function("OnStuck", action_stuck);
	retreat_to_cover_action.set_function("OnMoveToSuccess", action_movesuccess);
	retreat_to_cover_action.set_function("OnMoveToFailure", action_movefail);
	retreat_to_cover_action.set_function("ShouldHurry", action_hurry);
}

static QueryResultType action_hurry(CustomBehaviorAction action, INextBot bot, int entity)
{
	return ANSWER_YES;
}

static BehaviorResultType action_stuck(CustomBehaviorAction action, INextBot bot, int entity, BehaviorResult result)
{
	return result.TryContinue();
}

static BehaviorResultType action_movesuccess(CustomBehaviorAction action, INextBot bot, int entity, BehaviorResult result)
{
	return result.TryContinue();
}

static BehaviorResultType action_movefail(CustomBehaviorAction action, INextBot bot, int entity, MoveToFailureType type, BehaviorResult result)
{
	return result.TryContinue();
}

enum struct FindCoverAreaInfo
{
	INextBot bot;
	CNavArea m_area;
	ArrayList m_coverAreaVector;
	int m_minExposureCount;
	int m_exposedThreatCount;
}

static FindCoverAreaInfo cover_search_info;

static bool cover_test_threats(CKnownEntity known, any data)
{
	int threat = known.Entity;

	if(cover_search_info.bot.IsEnemy(threat)) {
		CNavArea threatArea = GetEntityLastKnownArea(threat);
		if(threatArea != CNavArea_Null) {
			if(cover_search_info.m_area.IsPotentiallyVisible(threatArea)) {
				++cover_search_info.m_exposedThreatCount;
			}
		}
	}

	return true;
}

static bool cover_search_exec(CNavArea area, CNavArea priorArea, float travelDistanceSoFar, any data)
{
	IVision vision = cover_search_info.bot.VisionInterface;

	cover_search_info.m_area = area;
	cover_search_info.m_exposedThreatCount = 0;
	vision.ForEachKnownEntity(cover_test_threats);

	if(cover_search_info.m_exposedThreatCount <= cover_search_info.m_minExposureCount) {
		if(cover_search_info.m_exposedThreatCount < cover_search_info.m_minExposureCount) {
			cover_search_info.m_coverAreaVector.Clear();
			cover_search_info.m_minExposureCount = cover_search_info.m_exposedThreatCount;
		}

		cover_search_info.m_coverAreaVector.Push(area);
	}

	return true;
}

static bool cover_search_should(CNavArea area, CNavArea priorArea, float travelDistanceSoFar, any data)
{
	if(travelDistanceSoFar > tf_bot_retreat_to_cover_range.FloatValue) {
		return false;
	}

	ILocomotion locomotion = cover_search_info.bot.LocomotionInterface;
	return (priorArea.ComputeAdjacentConnectionHeightChange(area) < locomotion.StepHeight);
}

static CNavArea find_cover_area(INextBot bot, int entity)
{
	CNavArea startArea = GetEntityLastKnownArea(entity);

	cover_search_info.bot = bot;
	cover_search_info.m_area = CNavArea_Null;
	cover_search_info.m_coverAreaVector = new ArrayList();
	cover_search_info.m_minExposureCount = 0;
	cover_search_info.m_exposedThreatCount = 0;

	ISearchSurroundingAreasFunctor funcs;
	funcs.ShouldSearch = cover_search_should;
	funcs.Execute = cover_search_exec;

	SearchSurroundingAreas(startArea, funcs);

	CNavArea coverArea = CNavArea_Null;

	int len = cover_search_info.m_coverAreaVector.Length;
	if(len > 0) {
		if(len > 10) {
			len = 10;
		}
		int idx = GetURandomInt() % len;
		coverArea = cover_search_info.m_coverAreaVector.Get(idx);
	}

	delete cover_search_info.m_coverAreaVector;

	return coverArea;
}

static void action_end(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction next)
{
	PathFollower path = action.get_data("m_path");
	delete path;
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	if(action.has_data("m_actionToChangeToOnceCoverReached")) {
		action.set_data("m_hideDuration", -1.0);
	} else if(action.has_data("m_hideDuration")) {
		action.set_data("m_actionToChangeToOnceCoverReached", BehaviorAction_Null);
	} else {
		action.set_data("m_hideDuration", -1.0);
		action.set_data("m_actionToChangeToOnceCoverReached", BehaviorAction_Null);
	}

	CNavArea coverArea = find_cover_area(bot, entity);
	action.set_data("m_coverArea", coverArea);

	if(coverArea == CNavArea_Null) {
		action.set_data("m_path", INVALID_HANDLE);

		return result.Done("No cover available!");
	}

	float hideDuration = action.get_data("m_hideDuration");
	if(hideDuration < 0.0) {
		hideDuration = GetRandomFloat(tf_bot_wait_in_cover_min_time.FloatValue, tf_bot_wait_in_cover_max_time.FloatValue);
		action.set_data("m_hideDuration", hideDuration);
	}

	action.set_data("m_waitInCoverTimer", GetGameTime() + hideDuration);

	action.set_data("m_repathTimer", GetGameTime());

	PathFollower path = new PathFollower();
	path.MinLookAheadDistance = GetDesiredPathLookAheadRange(entity);
	action.set_data("m_path", path);

	return result.Continue();
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	IVision vision = bot.VisionInterface;
	IIntention intention = bot.IntentionInterface;

	CKnownEntity threat = vision.GetPrimaryKnownThreat(true);

	if(intention.ShouldRetreat(bot) == ANSWER_NO) {
		return result.Done("No longer need to retreat");
	}

	CNavArea coverArea = action.get_data("m_coverArea");
	CNavArea startArea = GetEntityLastKnownArea(entity);

	if(startArea == coverArea || threat == CKnownEntity_Null) {
		if(threat != CKnownEntity_Null) {
			coverArea = find_cover_area(bot, entity);
			action.set_data("m_coverArea", coverArea);

			if(coverArea == CNavArea_Null) {
				return result.Done("My cover is exposed, and there is no other cover available!");
			}
		}

		BehaviorAction next_action = action.get_data("m_actionToChangeToOnceCoverReached");
		if(next_action != BehaviorAction_Null) {
			return result.ChangeTo(next_action, "Doing given action now that I'm in cover");
		}

		float waitInCoverTimer = action.get_data("m_waitInCoverTimer");
		if(waitInCoverTimer <= GetGameTime()) {
			return result.Done("Been in cover long enough");
		}
	} else {
		float hideDuration = action.get_data("m_hideDuration");
		action.set_data("m_waitInCoverTimer", GetGameTime() + hideDuration);

		PathFollower path = action.get_data("m_path");

		float repathTimer = action.get_data("m_repathTimer");
		if(repathTimer <= GetGameTime()) {
			repathTimer = GetRandomFloat(0.3, 0.5);
			action.set_data("m_repathTimer", repathTimer);

			float goal[3];
			coverArea.GetCenter(goal);

			path.ComputeVector(bot, goal, baseline_path_cost, cost_flags_fastest);
		}

		path.Update(bot);
	}

	return result.Continue();
}