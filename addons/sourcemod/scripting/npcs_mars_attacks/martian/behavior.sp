static void handle_weapon_fire(IIntentionCustom intention, INextBot bot, int entity, int victim, float sight_pos[3])
{
	float next_attack = intention.get_data("next_attack");
	if(next_attack < GetGameTime()) {
		next_attack = GetGameTime() + 1.0;
		intention.set_data("next_attack", next_attack);

		int weapon = GetEntPropEnt(entity, Prop_Data, "m_hWeaponModel");
		if(weapon == -1) {
			return;
		}

		FireBulletsInfo_t bullets;
		bullets.Init();

		int attachment = tf2_shooting_star_muzzle;

		float muzzle_ang[3];
		AnimatingGetAttachment(weapon, attachment, bullets.m_vecSrc, muzzle_ang);

		SubtractVectors(sight_pos, bullets.m_vecSrc, bullets.m_vecDirShooting);

		bullets.m_vecSpread = view_as<float>({0.0, 0.0, 0.0});
		bullets.m_nFlags |= FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
		bullets.m_pAttacker = entity;
		bullets.m_iTracerFreq = 1;

		bullets.m_flDamage = 10.0;
		bullets.m_iPlayerDamage = RoundToFloor(bullets.m_flDamage);

		strcopy(bullets.tracer_name, MAX_TRACER_NAME, "dxhr_sniper_rail_blue");
		bullets.attachment = attachment;
		bullets.forced_tracer_type = TRACER_PARTICLE;

		FireBullets(weapon, bullets);
		weapon_fired(entity);

		EmitGameSoundToAll("Weapon_ShootingStar.SingleCharged", weapon);
	}
}

BehaviorAction mars_attacks_martian_behavior(IIntentionCustom intention, INextBot bot, int entity)
{
	intention.set_function("handle_weapon_fire", handle_weapon_fire);

	intention.set_data("can_taunt", 1);

	intention.set_data("next_attack", GetGameTime());

	CustomBehaviorAction action = main_action.create();
	return action;
}