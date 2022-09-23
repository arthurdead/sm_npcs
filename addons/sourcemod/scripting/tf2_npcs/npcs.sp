#include "saucer/npc.sp"

void tf2_npcs_init()
{
	tf2_saucer_init();
}

void tf2_npcs_precache(int entity)
{
	tf2_saucer_precache(entity);
}

void tf2_npcs_entity_created(int entity, const char[] classname)
{
	if(StrContains(classname, "npc_tf2_saucer") != -1) {
		tf2_saucer_created(entity);
	}
}

void tf2_npcs_entity_destroyed(int entity, const char[] classname)
{
	
}

void tf2_npcs_plugin_end()
{
	remove_entities_of_classname("npc_tf2_saucer*");
}