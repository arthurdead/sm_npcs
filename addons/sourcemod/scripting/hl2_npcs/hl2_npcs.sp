#include "zombie/npc.sp"
#include "antlion/npc.sp"
#include "helicopter/npc.sp"

void hl2_npcs_init()
{
	hl2_zombie_init();
	hl2_antlion_init();
	hl2_helicopter_init();
}

void hl2_npcs_precache(int entity)
{
	hl2_zombie_precache(entity);
	hl2_antlion_precache(entity);
	hl2_helicopter_precache(entity);
}

void hl2_npcs_entity_created(int entity, const char[] classname)
{
	if(StrEqual(classname, "npc_hl2_zombie")) {
		hl2_zombie_created(entity);
	} else if(StrEqual(classname, "npc_hl2_antlion")) {
		hl2_antlion_created(entity);
	} else if(StrEqual(classname, "npc_hl2_helicopter")) {
		hl2_helicopter_created(entity);
	}
}

stock void hl2_npcs_entity_destroyed(int entity, const char[] classname)
{
	
}

void hl2_npcs_plugin_end()
{
	remove_entities_of_classname("npc_hl2_zombie");
	remove_entities_of_classname("npc_hl2_antlion");
	remove_entities_of_classname("npc_hl2_helicopter");
}