static void handle_fire(CustomBehaviorAction action, int entity, int victim, const float sight_pos[3])
{
	float attack_time = action.get_data("attack_time");
	if(attack_time < GetGameTime()) {
		int weapon = GetEntPropEnt(entity, Prop_Data, "m_hWeaponModel");
		if(weapon == -1) {
			return;
		}

		FireBulletsInfo_t bullets;
		bullets.Init();

		int attachment = tf2_cow_mangler_muzzle;

		float muzzle_ang[3];
		AnimatingGetAttachment(weapon, attachment, bullets.m_vecSrc, muzzle_ang);

		SubtractVectors(sight_pos, bullets.m_vecSrc, bullets.m_vecDirShooting);

		bullets.m_vecSpread = view_as<float>({50.0, 0.0, 0.0});
		bullets.m_nFlags |= FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
		bullets.m_pAttacker = entity;
		bullets.m_iTracerFreq = 1;

		bullets.m_flDamage = sk_tf2i_alien_commando_dmg.FloatValue;
		bullets.m_iPlayerDamage = RoundToFloor(bullets.m_flDamage);

		strcopy(bullets.tracer_name, MAX_TRACER_NAME, "dxhr_sniper_rail_blue");
		bullets.attachment = attachment;
		bullets.forced_tracer_type = TRACER_PARTICLE;

		FireBullets(weapon, bullets);

		EmitGameSoundToAll("Weapon_ShootingStar.SingleCharged", weapon);

		action.set_data("attack_time", GetGameTime() + 1.0);
	}
}

static bool handle_die(int entity)
{
	int weapon = GetEntPropEnt(entity, Prop_Data, "m_hWeaponModel");
	if(weapon != -1) {
		RemoveEntity(weapon);
		SetEntPropEnt(entity, Prop_Data, "m_hWeaponModel", -1);
	}

	return true;
}

BehaviorAction tf2i_alien_commando_behavior(int entity)
{
	CustomBehaviorAction action = basic_range_action.create();
	action.set_function("handle_fire", handle_fire);
	action.set_function("handle_die", handle_die);
	return action;
}