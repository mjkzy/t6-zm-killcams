// by: @mjkzys

#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm;
#include maps\mp\zombies\_zm_audio;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_spawner;
#include maps\mp\gametypes_zm\_globallogic_spawn;
#include maps\mp\gametypes_zm\_spectating;
#include maps\mp\_challenges;
#include maps\mp\gametypes_zm\_globallogic;
#include maps\mp\gametypes_zm\_globallogic_audio;
#include maps\mp\gametypes_zm\_spawnlogic;
#include maps\mp\gametypes_zm\_rank;
#include maps\mp\gametypes_zm\_weapons;
#include maps\mp\gametypes_zm\_spawning;
#include maps\mp\gametypes_zm\_globallogic_utils;
#include maps\mp\gametypes_zm\_globallogic_player;
#include maps\mp\gametypes_zm\_globallogic_ui;
#include maps\mp\gametypes_zm\_globallogic_score;
#include maps\mp\gametypes_zm\_persistence;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_utility;

main()
{
    replacefunc(maps\mp\zombies\_zm_laststand::is_reviving, ::is_reviving_hook);
}

init()
{
    init_precache();
    init_dvars();

    // variables
    level.perk_purchase_limit = 20;
    level.zombie_vars["zombie_use_failsafe"] = false;
    set_zombie_var("zombie_use_failsafe", 0);
    level.player_out_of_playable_area_monitor = undefined;
    level.player_too_many_weapons_monitor = undefined;
    level._zombies_round_spawn_failsafe = undefined;

    level.callbackactorkilled_og = level.callbackactorkilled;
    level.callbackactorkilled = ::callbackactorkilled_stub; 

    level.callbackplayerkilled_og = level.callbackplayerkilled;
    level.callbackplayerkilled = ::callbackplayerkilled_stub;

    level.onteamoutcomenotify = ::outcome_notify_stub;

    level.spawnplayer_og = level.spawnplayer;
    level.spawnplayer = ::spawnplayer_stub;

    // vars
    level.enemy_score = randomintrange(0, 4); // default is random
    level.round_based = false;                // victory by default

    maps\mp\zombies\_zm_spawner::register_zombie_damage_callback(::do_hitmarker);
    maps\mp\zombies\_zm_spawner::register_zombie_death_event_callback(::do_hitmarker_death);

    level thread on_player_connect();
    level thread end_game_when_hit();
    level thread open_seseme();
    level thread zombies_counter();
    level thread last_cooldown();

    // lil changes
    level thread set_pap_price();
    level thread build_buildables();
    level thread build_craftables();

    level.debug_mode = getdvarintdefault("debug_mode", 0);
    level.result = 0;

    level thread init_killcam();
}

set_pap_price()
{
    precachestring(&"ZOMBIE_PERK_PACKAPUNCH");
    precachestring(&"ZOMBIE_PERK_PACKAPUNCH_ATT");

    level waittill("Pack_A_Punch_on");

    pap_triggers = getentarray("specialty_weapupgrade", "script_noteworthy");
    pap_trigger = pap_triggers[0];
    pap_trigger.cost = 0;
    pap_trigger.attachment_cost = 0;
    pap_trigger sethintstring(&"ZOMBIE_PERK_PACKAPUNCH", pap_trigger.cost); // reset hint msg to new price
}

on_player_connect()
{
    for(;;)
    {
        level waittill("connected", player);

        if (!isdefined(player.hud_damagefeedback))
            player thread init_player_hitmarkers();

        player thread on_player_spawned();
        player thread verify_on_connect();
        player thread spawn_on_join();
    }
}

on_player_spawned()
{
    self endon("disconnect");
    //level endon("game_ended");

    self.first = true;
    self.menuname = "main menu";
    self.menuxpos = 0;
    self.menu_init = false;
    self.default_team = self.team;
    self.ufospeed = 20;

    self.killcam_rank = "zombies_rank_5"; // max rank by default
    self.killcam_length = 5;

    init_afterhit();

    for(;;)
    {
        self waittill("spawned_player");

        if (is_true(level.intermission))
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

        if (verification_to_num(self.status) > verification_to_num("Unverified"))
        {
            if (!self.menu_init)
            {
                self overflow_fix();
                self thread menu_init();
                self.menu_init = true;
            }
        }

        // save and load
        if (isdefined(self.saved_angles) && isdefined(self.saved_origin))
        {
            self setplayerangles(self.saved_angles);
            self setorigin(self.saved_origin);
        }

        // first spawn
        if (is_true(self.first))
        {
            if (!flag("initial_blackscreen_passed"))
            {
                flag_wait("initial_blackscreen_passed");
            }

            self thread toggle_save_and_load(false);
            self thread monitor_reviving();

            self iprintln("^7hello ^1" + self.name + " ^7& welcome to ^1mikey's zm mod^7!");
            self iprintln("^7hold [{+speed_throw}] & press [{+actionslot 1}] to open menu");
            self iprintln("'last' is when ^11 ^7zombie are alive.");

            self.first = false;
        }
    }
}

spawnplayer_stub()
{
    if (is_true(level.in_final_killcam))
    {
        return;
    }
        
    [[level.spawnplayer_og]]();
}
