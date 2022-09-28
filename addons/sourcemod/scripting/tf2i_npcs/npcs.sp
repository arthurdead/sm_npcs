#include "alien_commando/npc.sp"

void tf2i_npcs_init()
{
	tf2i_alien_commando_init();
}

void tf2i_npcs_precache(int entity)
{
	tf2i_alien_commando_precache(entity);
}

void tf2i_npcs_entity_created(int entity, const char[] classname)
{
	if(StrContains(classname, "npc_tf2i_alien_commando") != -1) {
		tf2i_alien_commando_created(entity);
	}
}

void tf2i_npcs_entity_destroyed(int entity, const char[] classname)
{
	
}

void tf2i_npcs_plugin_end()
{
	remove_entities_of_classname("npc_tf2i_alien_commando*");
}