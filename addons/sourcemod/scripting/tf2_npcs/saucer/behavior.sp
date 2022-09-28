static void handle_fire(CustomBehaviorAction action, int entity, int victim, const float sight_pos[3])
{
	float attack_time = action.get_data("attack_time");
	if(attack_time < GetGameTime()) {
		FireBulletsInfo_t bullets;
		bullets.Init();

		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", bullets.m_vecSrc);

		SubtractVectors(sight_pos, bullets.m_vecSrc, bullets.m_vecDirShooting);

		bullets.m_vecSpread = view_as<float>({0.0, 0.0, 0.0});
		bullets.m_nFlags |= FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
		bullets.m_pAttacker = entity;
		bullets.m_iTracerFreq = 1;

		bullets.m_flDamage = 0.0;
		bullets.m_iPlayerDamage = RoundToFloor(bullets.m_flDamage);

		strcopy(bullets.tracer_name, MAX_TRACER_NAME, "merasmus_zap");
		//bullets.attachment = TRACER_DONT_USE_ATTACHMENT;
		bullets.forced_tracer_type = TRACER_PARTICLE;

		FireBullets(entity, bullets);

		EmitGameSoundToAll("Weapon_Capper.Single", entity);

		action.set_data("attack_time", GetGameTime() + 0.5);
	}
}

BehaviorAction tf2_saucer_behavior(int entity)
{
	CustomBehaviorAction action = basic_range_action.create();
	action.set_function("handle_fire", handle_fire);
	return action;
}