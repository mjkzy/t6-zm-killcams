#include maps/mp/zombies/_zm_utility;
#include maps/mp/zombies/_zm_audio;
#include maps/mp/zombies/_zm_stats;
#include maps/mp/gametypes_zm/_hud_message;
#include maps/mp/zombies/_zm_equipment;
#include maps/mp/zombies/_zm_powerups;
#include maps/mp/zombies/_zm_power;
#include maps/mp/zombies/_zm_weapons;
#include maps/mp/zombies/_zm_laststand;
#include maps/mp/zombies/_zm_server_throttle;
#include maps/mp/animscripts/zm_utility;
#include maps/mp/animscripts/zm_run;
#include common_scripts/utility;
#include maps/mp/_utility;
#include maps/mp/zombies/_zm;

main()
{
    replaceFunc( maps/mp/zombies/_zm_utility::spawn_zombie, ::spawn_zombie_o );
    replaceFunc( maps/mp/zombies/_zm::round_start, ::round_start_o );
}

round_start_o()
{
	if ( isDefined( level.round_prestart_func ) )
	{
		[[ level.round_prestart_func ]]();
	}
	else
	{
		n_delay = 2;
		if ( isDefined( level.zombie_round_start_delay ) )
		{
			n_delay = level.zombie_round_start_delay;
		}
		wait n_delay;
	}
	level.zombie_health = level.zombie_vars[ "zombie_health_start" ];
	if ( level.zombie_vars[ "game_start_delay" ] > 0 )
	{
		round_pause( level.zombie_vars[ "game_start_delay" ] );
	}
	flag_set( "begin_spawning" ); 
    level thread round_spawning();
}

round_spawning()
{
	while ( level.zombie_spawn_locations.size < 1 )
	{
		wait 0.5;
	}
	ai_calculate_health( level.round_number );
    level.zombie_total = 6 * getPlayers().size;
	level notify( "zombie_total_set" );
	old_spawn = undefined;
	while ( 1 )
	{
		while ( get_current_zombie_count() >= level.zombie_ai_limit || level.zombie_total <= 0 )
		{
			wait 0.1;
		}
		while ( get_current_actor_count() >= level.zombie_actor_limit )
		{
			clear_all_corpses();
			wait 0.1;
		}
		flag_wait( "spawn_zombies" );
		while ( level.zombie_spawn_locations.size <= 0 )
		{
			wait 0.1;
		}
		run_custom_ai_spawn_checks();
		spawn_point = level.zombie_spawn_locations[ randomint( level.zombie_spawn_locations.size ) ];
		if ( !isDefined( old_spawn ) )
		{
			old_spawn = spawn_point;
		}
		else if ( spawn_point == old_spawn )
		{
			spawn_point = level.zombie_spawn_locations[ randomint( level.zombie_spawn_locations.size ) ];
		}
		old_spawn = spawn_point;
		if ( isDefined( level.zombie_spawners ) )
		{
			spawner = random( level.zombie_spawners );
			ai = spawn_zombie( spawner, spawner.targetname, spawn_point );
		}
		if ( isDefined( ai ) )
		{
			level.zombie_total--;
			if ( !isDefined( first_spawn ) )
			{
				first_spawn = true;
				level notify( "first_zombie" );
			}
		}
		wait level.zombie_vars[ "zombie_spawn_delay" ];
		wait_network_frame();
	}
}

spawn_zombie_o( spawner, target_name, spawn_point, round_number )
{
	if ( !isDefined( spawner ) )
	{
		return undefined;
	}
	while ( getfreeactorcount() < 1 )
	{
		wait 0.05;
	}
	spawner.script_moveoverride = 1;
	if ( is_true( spawner.script_forcespawn ) )
	{
		guy = spawner spawnactor();
		guy enableaimassist();
		guy.aiteam = level.zombie_team;
		guy clearentityowner();
		level.zombiemeleeplayercounter = 0;
		guy thread run_spawn_functions();
		guy forceteleport( spawner.origin );
		guy show();
	}
	spawner.count = 666;
	if ( !spawn_failed( guy ) )
	{
		if ( isDefined( target_name ) )
		{
			guy.targetname = target_name;
		}
        guy.electrified = 1; //meme change that should prevent the distance tracking code from being able to delete the zombie.
		return guy;
	}
	return undefined;
}