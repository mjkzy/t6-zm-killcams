/*

	mikey's zm mod (source)

    by: @mjkzys

*/

#include maps/mp/_utility;
#include common_scripts/utility;
#include maps/mp/gametypes_zm/_hud_util;
#include maps/mp/gametypes_zm/_hud_message;
#include maps/mp/zombies/_zm;
#include maps/mp/zombies/_zm_audio;
#include maps/mp/zombies/_zm_score;
#include maps/mp/zombies/_zm_spawner;
#include maps/mp/gametypes_zm/_globallogic_spawn;
#include maps/mp/gametypes_zm/_spectating;
#include maps/mp/_challenges;
#include maps/mp/gametypes_zm/_globallogic;
#include maps/mp/gametypes_zm/_globallogic_audio;
#include maps/mp/gametypes_zm/_spawnlogic;
#include maps/mp/gametypes_zm/_rank;
#include maps/mp/gametypes_zm/_weapons;
#include maps/mp/gametypes_zm/_spawning;
#include maps/mp/gametypes_zm/_globallogic_utils;
#include maps/mp/gametypes_zm/_globallogic_player;
#include maps/mp/gametypes_zm/_globallogic_ui;
#include maps/mp/gametypes_zm/_globallogic_score;
#include maps/mp/gametypes_zm/_persistence;
#include maps/mp/zombies/_zm_weapons;
#include maps/mp/zombies/_zm_utility;

main()
{
    replacefunc(maps/mp/zombies/_zm_laststand::is_reviving, ::is_reviving_hook);
}

init()
{
    setdvar("scr_killcam_time", 5);

    init_precache();
    init_dvars();

    // variables
    level.perk_purchase_limit = 20;
    level.zombie_vars["zombie_use_failsafe"] = false;
    set_zombie_var( "zombie_use_failsafe", 0 );
    level.player_out_of_playable_area_monitor = false;
    level.player_too_many_weapons_monitor = false;

    level.actor_killed_stub = level.callbackactorkilled;
    level.callbackactorkilled = ::actor_killed;
    level._zombies_round_spawn_failsafe = undefined;
    level.onTeamOutcomeNotify = ::teamOutcomeNotify;

    // vars
    level.enemy_score = randomintrange(0, 4); // default is random
    level.round_based = false;                // victory by default

    maps/mp/zombies/_zm_spawner::register_zombie_damage_callback(::do_hitmarker);
    maps/mp/zombies/_zm_spawner::register_zombie_death_event_callback(::do_hitmarker_death);

    level thread init_killfeed();
    level thread onplayerconnect();
    level thread endgamewhenhit();
    level thread open_seseme();
    level thread drawZombiesCounter();
    level thread monitorlastcooldown();

    // lil changes
    level thread set_pap_price();
    level thread buildbuildables();
    level thread buildcraftables();

    level.debug_mode = getdvarintdefault("debug_mode", 0);
    level.result = 0;

    level thread initfinalkillcam();
    level thread doFinalKillcam();
}

set_pap_price()
{
    precachestring(&"ZOMBIE_PERK_PACKAPUNCH");
    precachestring(&"ZOMBIE_PERK_PACKAPUNCH_ATT");

    level waittill( "Pack_A_Punch_on" );

    pap_triggers = getentarray( "specialty_weapupgrade", "script_noteworthy" );
    pap_trigger = pap_triggers[0];
    pap_trigger.cost = 0;
    pap_trigger.attachment_cost = 0;
    pap_trigger sethintstring( &"ZOMBIE_PERK_PACKAPUNCH", pap_trigger.cost ); // reset hint msg to new price
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);

        if (!isDefined(player.hud_damagefeedback))
            player thread init_player_hitmarkers();

        player thread onPlayerSpawned();
        player thread verifyOnConnect();
        player thread spawn_on_join();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    //level endon("game_ended");

    self.first = true;
    self.menuname = "main menu";
    self.menuxpos = 0;
    self.MenuInit = false;
    self.defaultTeam = self.team;
    self.ufospeed = 20;

    self.killcam_rank = "zombies_rank_5"; // max rank by default

    init_afterhit();

    for(;;)
    {
        self waittill("spawned_player");

        if (isdefined(level.intermission) && level.intermission)
        {
            if (isalive(self))
            {
                self enableInvulnerability();
                self freezecontrols(true);
            }
            continue;
        }

        self setperk("specialty_fallheight");
        self setperk("specialty_unlimitedsprint");

        if (self.status == "Host" || self.status == "Co-Host" || self.status == "Admin" || self.status == "VIP" || self.status == "Verified")
        {
            if (!self.MenuInit)
            {
                self.MenuInit = true;
                self thread MenuInit();
                self thread initOverFlowFix();
                self.menu.backgroundinfo = self drawShader(level.icontest, -25, -100, 250, 1000, (0, 1, 0), 1, 0);
                self.menu.backgroundinfo.alpha = 0;
            }
        }

        // save and load
        if (self.a != undefined && self.o != undefined)
        {
            self setplayerangles(self.a);
            self setorigin(self.o);
        }

        // first spawn
        if (isdefined(self.first) && self.first)
        {
            if (!flag("initial_blackscreen_passed"))
            {
                flag_wait("initial_blackscreen_passed");
            }

            self thread saveandload(false);
            self thread monitor_reviving();

            self iPrintLn("^7hello ^1" + self.name + " ^7& welcome to ^1mikey's zm mod^7!");
            self iPrintLn("^7hold [{+speed_throw}] & press [{+actionslot 1}] to open menu");
            self iPrintLn("'last' is when ^11 ^7zombie are alive.");

            self.first = false;
        }
    }
}
