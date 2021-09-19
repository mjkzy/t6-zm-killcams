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
    replacefunc(maps/mp/zombies/_zm_laststand::is_reviving, ::is_reviving);
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

    level.spawnplayerog = level.spawnplayer;
    level.spawnplayer = ::spawnplayer;

    level.custom_intermissionog = level.custom_intermission;
    level.custom_intermission = ::nuked_standard_intermission;

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

/*

    REGISTER AFTER HIT HERE

*/
init_afterhit()
{
    self.afterhit = [];
    for(i=0; i<8; i++)
    {
        self.afterhit[i] = spawnstruct();
        self.afterhit[i].on = false;
    }

    // get random perk bottle, and one that is being used
    perks = [];
    if (isDefined(level.zombiemode_using_juggernaut_perk) && level.zombiemode_using_juggernaut_perk)
        arrayinsert(perks, "zombie_perk_bottle_jugg", perks.size);
    if (isDefined(level.zombiemode_using_sleightofhand_perk) && level.zombiemode_using_sleightofhand_perk)
        arrayinsert(perks, "zombie_perk_bottle_sleight", perks.size);
    if (isDefined(level.zombiemode_using_doubletap_perk) && level.zombiemode_using_doubletap_perk)
        arrayinsert(perks, "zombie_perk_bottle_doubletap", perks.size);
    if (isDefined(level.zombiemode_using_deadshot_perk) && level.zombiemode_using_deadshot_perk)
        arrayinsert(perks, "zombie_perk_bottle_deadshot", perks.size);
    if (isDefined(level.zombiemode_using_tombstone_perk) && level.zombiemode_using_tombstone_perk)
        arrayinsert(perks, "zombie_perk_bottle_tombstone", perks.size);
    if (isDefined(level.zombiemode_using_additionalprimaryweapon_perk) && level.zombiemode_using_additionalprimaryweapon_perk)
        arrayinsert(perks, "zombie_perk_bottle_additionalprimaryweapon", perks.size);
    if (isDefined(level.zombiemode_using_chugabud_perk) && level.zombiemode_using_chugabud_perk)
        arrayinsert(perks, "zombie_perk_bottle_revive", perks.size);
    if (isDefined(level.zombiemode_using_electric_cherry_perk) && level.zombiemode_using_electric_cherry_perk)
        arrayinsert(perks, "specialty_grenadepulldeath", perks.size);
    if (isDefined(level.zombiemode_using_vulture_perk) && level.zombiemode_using_vulture_perk)
        arrayinsert(perks, "specialty_nomotionsensor", perks.size);

    self.afterhit[0].weap = "fivesevendw_zm";
    self.afterhit[1].weap = "zombie_knuckle_crack";
    self.afterhit[2].weap = randomintrange(0, perks.size);
    self.afterhit[3].weap = "chalk_draw_zm";
    self.afterhit[4].weap = "syrette_zm";
    self.afterhit[5].weap = "zombie_tomahawk_flourish";
    self.afterhit[6].weap = "lightning_hands_zm";
    self.afterhit[7].weap = "zombie_one_inch_punch_flourish";
}

canToggleAfter()
{
    foreach (weapon in self.afterhit)
    {
        if (weapon.on)
        {
            return false;
        }
    }
    return true;
}

afterhitweapon(weapon)
{
    if (weapon.on == false)
    {
        if (!canToggleAfter())
        {
            self iprintln("^7cannot have more than ^1one^7 after hit on.");
            return;
        }
        self iprintln("after hit ^2on");
        self thread pullout_weapon(weapon.weap);
        weapon.on = true;
    }
    else if (weapon.on)
    {
        self iprintln("after hit ^1off");
        self notify("KillAfterHit");
        weapon.on = false;
    }
}

pullout_weapon(weapon)
{
    self endon("disconnect");
    self endon("KillAfterHit");
    level waittill("game_ended");
    self takeweapon(self getcurrentweapon());
    self giveWeapon(weapon);
    self switchToWeapon(weapon);
}

// revive stalls
is_reviving(revivee)
{
    if (self usebuttonpressed() && maps/mp/zombies/_zm_laststand::can_revive(revivee))
    {
        print("reviving.");
        self.the_revivee = revivee;
        return 1;
    }
    self.the_revivee = undefined;
    return 0;
}

monitor_reviving()
{
    self endon("disconnect");
    level endon("game_ended");

    revive_stall = false;
    for(;;)
    {
        if (isdefined(self.the_revivee) && self is_reviving(self.the_revivee))
        {
            print("should be doing revive stall");
            if (!revive_stall)
            {
                revive_stall = true;
                float = spawn("script_model", self.origin);
                float setmodel("p6_anim_zm_magic_box");
                float hide();
                self playerlinkto(float);
                self freeze_player_controls(false);
            }
        }
        else
        {
            if (revive_stall)
            {
                print("done doing revive stall");
                revive_stall = false;
                float delete();
                self unlink();
            }
        }
        wait 0.02;
    }
}

spawnplayer()
{
    print("SPAWN PLAYER CALLED, THIS PROBABLY RESET ARCHIVE TIME.");
    thread [[level.spawnplayerog]]();
}

nuked_standard_intermission()
{
    print("NUKED STANDARD INTERMISSION, PROB RESET ARCHIVE TIME.");
    thread [[level.custom_intermissionog]]();
}