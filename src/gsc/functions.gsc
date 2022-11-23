/*

	majority of the functions are here

*/

init_precache()
{
    precacheshader("white");
    precacheshader("zombies_rank_1");
    precacheshader("zombies_rank_2");
    precacheshader("zombies_rank_3");
    precacheshader("zombies_rank_4");
    precacheshader("zombies_rank_5");
    precacheshader("emblem_bg_default");
    precacheshader("damage_feedback");
    precacheshader("hud_status_dead");
    precacheshader("specialty_instakill_zombies");
    precacheshader("menu_lobby_icon_twitter");
    precacheshader("faction_cia");
    precacheshader("faction_cdc");

    precachemodel("p6_anim_zm_magic_box");

    precacheitem("zombie_knuckle_crack");
    precacheitem("zombie_perk_bottle_jugg");
    precacheitem("zombie_perk_bottle_sleight");
    precacheitem("zombie_perk_bottle_doubletap");
    precacheitem("zombie_perk_bottle_deadshot");
    precacheitem("zombie_perk_bottle_tombstone");
    precacheitem("zombie_perk_bottle_additionalprimaryweapon");
    precacheitem("zombie_perk_bottle_revive");
    precacheitem("chalk_draw_zm");
    precacheitem("lightning_hands_zm");
}

init_dvars()
{
    setdvar("bot_AllowMovement", 0);
    setdvar("bot_PressAttackBtn", 0);
    setdvar("bot_PressMeleeBtn", 0);
    setdvar("friendlyfire_enabled", 0);
    setdvar("g_friendlyfireDist", 0);
    setdvar("ui_friendlyfire", 1);
    setdvar("jump_slowdownEnable", 0);
    setdvar("sv_enableBounces", 1);
    setdvar("player_lastStandBleedoutTime", 9999);
}

end_game_when_hit()
{
    level endon("game_ended");

    // inital black screen
    if (!flag("initial_blackscreen_passed"))
    {
        flag_wait("initial_blackscreen_passed");
    }

    // wait until a zombie has spawned, then run the loop
    enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
    while (enemies <= 0)
    {
        enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
        wait 0.5;
    }

    for(;;)
    {
        enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
        if (enemies < 1 && level.islast)
        {
            if (int(getDvar("g_ai")) != 1)
                setDvar("g_ai", 1);

            level thread customendgame();

            break;
        }
        wait 0.05;
    }
}

// MP endgame + parts of end_game from _zm
customendgame()
{
    winner = level.last_attacker.team;

    if (game["state"] == "postgame" || level.gameEnded) return;
    if (isdefined(level.onEndGame))
        [[level.onEndGame]](winner);

    // visionSetNaked("mpOutro", 2.0);

    setMatchFlag("enable_popups", 0);
    setmatchflag("cg_drawSpectatorMessages", 0);
    setmatchflag("game_ended", 1);

    players = get_players();
    setmatchflag("disableIngameMenu", 1);
    foreach(player in players)
    {
        player closemenu();
        player closeingamemenu();
        player EnableInvulnerability();
        if (isdefined(player.revivetexthud))
        {
            player.revivetexthud destroy();
        }
    }

    level.zombie_vars["zombie_powerup_insta_kill_time"] = 0;
    level.zombie_vars["zombie_powerup_fire_sale_time"] = 0;
    level.zombie_vars["zombie_powerup_point_doubler_time"] = 0;

    game["state"] = "postgame";
    level.gameEndTime = getTime();
    level.gameEnded = true;
    SetDvar("g_gameEnded", 1);
    level.inGracePeriod = false;
    level notify("game_ended");
    //level notify("game_module_ended"); // fixes killcam fucking up on new round. (for nerds, when a new round occurs, it calls spawn player on spectators and resets archive time, BUT THEY ARE IN KILLCAM.)
    level.allowBattleChatter = true; // battle chatter doesn't even exist lmfao
    maps\mp\gametypes_zm\_globallogic_audio::flushDialog();

    if (!isdefined(game["overtime_round"]) || wasLastRound()) // Want to treat all overtime rounds as a single round
    {
        game["roundsplayed"]++;
        game["roundwinner"][game["roundsplayed"]] = winner;

        if (level.teambased)
        {
            game["roundswon"][winner]++;
        }
    }

    if (isdefined(winner) && isdefined(level.teams[winner]))
    {
        level.finalKillCam_winner = winner;
    }
    else
    {
        level.finalKillCam_winner = "none";
    }

    level.finalKillCam_winnerPicked = true;

    setGameEndTime(0);

    maps\mp\gametypes_zm\_globallogic::updatePlacement();

    maps\mp\gametypes_zm\_globallogic::updateRankedMatch(winner);

    players = level.players;

    newTime = getTime();
    gameLength = getGameLength();

    SetMatchTalkFlag("EveryoneHearsEveryone", 1);

    bbGameOver = 0;
    if (isOneRound() || wasLastRound())
    {
        bbGameOver = 1;

        if (level.teambased)
        {
            if (winner == "tie")
            {
                recordGameResult("draw");
            }
            else
            {
                recordGameResult(winner);
            }
        }
        else
        {
            if (!isdefined(winner))
            {
                recordGameResult("draw");
            }
            else
            {
                recordGameResult(winner.team);
            }
        }
    }

    foreach(player in level.players)
    {
        player thread destroyMenu(player);
        //player maps\mp\gametypes_zm\_globallogic_player::freezePlayerForRoundEnd();
        player thread keep_tryna_freeze();
        player thread roundEndDoF(4.0);

        // zombies think they are tough because we can't move at all
        player EnableInvulnerability();
        player maps\mp\gametypes_zm\_globallogic_ui::freeGameplayHudElems();
        player maps\mp\gametypes_zm\_weapons::updateWeaponTimings(newTime);
        player maps\mp\gametypes_zm\_globallogic::bbPlayerMatchEnd(gameLength, "", bbGameOver);

        if (isPregame())
        {
            index++;
            continue;
        }

        if (level.rankedMatch || level.wagerMatch || level.leagueMatch)
        {
            if (isdefined(player.setPromotion))
            {
                player setDStat("AfterActionReportStats", "lobbyPopup", "promotion");
            }
            else
            {
                player setDStat("AfterActionReportStats", "lobbyPopup", "summary");
            }
        }
    }

    maps\mp\_music::setmusicstate("SILENT");
    thread maps\mp\_challenges::roundEnd(winner);
    if (startNextRound(winner, " "))
    {
        return;
    }

    ///////////////////////////////////////////
    // After this the match is really ending //
    ///////////////////////////////////////////

    if (!isOneRound())
    {
        if (isdefined(level.onRoundEndGame))
        {
            winner = [[level.onRoundEndGame]](winner);
        }
    }

    skillUpdate(winner, level.teamBased);
    recordLeagueWinner(winner);

    maps\mp\gametypes_zm\_globallogic::setTopPlayerStats();
    thread maps\mp\_challenges::gameEnd(winner);

    displayGameEnd(winner);

    stopallrumbles();
    level.zombie_vars["zombie_powerup_insta_kill_time"] = 0;
    level.zombie_vars["zombie_powerup_fire_sale_time"] = 0;
    level.zombie_vars["zombie_powerup_point_doubler_time"] = 0;
    setmatchflag("disableIngameMenu", 1);

    // maps that crash reverting archive time
    level.skip_game_end = false;
    if (level.script == "zm_transit" || level.script == "zm_prison" || level.script == "zm_buried")
    {
        level.skip_game_end = true;
    }

    // load killcam here.
    postRoundFinalKillcam(); // call killcam here?
    while (level.in_final_killcam == 1)
    {
        wait 0.05;
    }

    level.intermission = true;

    //regain players array since some might've disconnected during the wait above
    foreach(player in level.players)
    {
        player closeMenu();
        player closeInGameMenu();
        player notify ("reset_outcome");
        player thread [[level.spawnIntermission]]();
        player overlay(false);
        player setClientUIVisibilityFlag("hud_visible", 1);
    }

    level notify ("sfade");
    level notify("stop_intermission");
    logString("game ended");

    if (!isdefined(level.skip_game_end) || !level.skip_game_end)
        wait 10;

    exitlevel(false);
}

open_seseme()
{
    flag_wait("initial_blackscreen_passed");
    setdvar("zombie_unlock_all", 1);
    flag_set("power_on");
    players = get_players();
    zombie_doors = getentarray("zombie_door", "targetname");
    for(i = 0; i < zombie_doors.size; i++)
    {
        zombie_doors[i] notify("trigger");
        if (is_true(zombie_doors[i].power_door_ignore_flag_wait))
        {
            zombie_doors[i] notify("power_on");
        }
        wait(0.05);
    }
    zombie_airlock_doors = getentarray("zombie_airlock_buy", "targetname");
    for(i = 0; i < zombie_airlock_doors.size; i++)
    {
        zombie_airlock_doors[i] notify("trigger");
        wait(0.05);
    }
    zombie_debris = getentarray("zombie_debris", "targetname");
    for(i = 0; i < zombie_debris.size; i++)
    {
        zombie_debris[i] notify("trigger", players[0]);
        wait(0.05);
    }
    setdvar("zombie_unlock_all", 0);
}

init_player_hitmarkers()
{
    self.hud_damagefeedback = newdamageindicatorhudelem(self);
    self.hud_damagefeedback.horzalign = "center";
    self.hud_damagefeedback.vertalign = "middle";
    self.hud_damagefeedback.x = -12;
    self.hud_damagefeedback.y = -12;
    self.hud_damagefeedback.alpha = 0;
    self.hud_damagefeedback.archived = 1;
    self.hud_damagefeedback.color = (1, 1, 1);
    self.hud_damagefeedback setshader("damage_feedback", 24, 48);
    self.hud_damagefeedback_red = newdamageindicatorhudelem(self);
    self.hud_damagefeedback_red.horzalign = "center";
    self.hud_damagefeedback_red.vertalign = "middle";
    self.hud_damagefeedback_red.x = -12;
    self.hud_damagefeedback_red.y = -12;
    self.hud_damagefeedback_red.alpha = 0;
    self.hud_damagefeedback_red.archived = 1;
    self.hud_damagefeedback_red.color = (1, 0, 0);
    self.hud_damagefeedback_red setshader("damage_feedback", 24, 48);
}

displayGameEnd(winner)
{
    foreach(player in level.players)
    {
        player thread [[level.onTeamOutcomeNotify]](winner, false, "");
        player setClientUIVisibilityFlag("hud_visible", 0);
        player setClientUIVisibilityFlag("g_compassShowEnemies", 0);
    }

    roundEndWait(level.postRoundTime, true);
}

outcome_notify_stub(winner, isround, endreasontext)
{
    self endon("disconnect");
    self notify("reset_outcome");
    team = level.last_attacker.team;

    while (self.doingnotify)
    {
        wait 0.05;
    }
    self endon("reset_outcome");
    headerfont = "extrabig";
    font = "default";
    if (self issplitscreen())
    {
        titlesize = 2;
        textsize = 1.5;
        iconsize = 30;
        spacing = 10;
    }
    else
    {
        titlesize = 3;
        textsize = 2;
        iconsize = 70;
        spacing = 25;
    }
    duration = 60000;
    outcometitle = createfontstring(headerfont, titlesize);
    outcometitle setpoint("TOP", undefined, 0, 30);
    outcometitle.glowalpha = 1;
    outcometitle.hidewheninmenu = 0;
    outcometitle.archived = 0;
    outcometitle.immunetodemogamehudsettings = 1;
    outcometitle.immunetodemofreecamera = 1;
    outcometext = createfontstring(font, 2);
    outcometext setparent(outcometitle);
    outcometext setpoint("TOP", "BOTTOM", 0, 0);
    outcometext.glowalpha = 1;
    outcometext.hidewheninmenu = 0;
    outcometext.archived = 0;
    outcometext.immunetodemogamehudsettings = 1;
    outcometext.immunetodemofreecamera = 1;

    if (level.round_based)
        outcometitle settext(game["strings"]["round_win"]);
    else
        outcometitle settext(game["strings"]["victory"]);
    outcometitle.color = (0.42, 0.68, 0.46);
    outcometext settext("Zombies Eliminated");
    outcometitle setcod7decodefx(200, duration, 600);
    outcometext setpulsefx(100, duration, 1000);
    iconspacing = 100;
    currentx = ((1 * -1) * iconspacing) / 2;

    teamicons = [];
    teamicons[team] = createicon(determineTeamLogo(), iconsize, iconsize);
    teamicons[team] setparent(outcometext);
    teamicons[team] setpoint("TOP", "BOTTOM", currentx, spacing);
    teamicons[team].hidewheninmenu = 0;
    teamicons[team].archived = 0;
    teamicons[team].alpha = 0;
    teamicons[team].immunetodemogamehudsettings = 1;
    teamicons[team].immunetodemofreecamera = 1;
    teamicons[team] fadeovertime(0.5);
    teamicons[team].alpha = 1;

    currentx += iconspacing;

    foreach(enemyteam in level.teams)
    {
        if (enemyteam != team)
        {
            teamicons[enemyteam] = createicon("hud_status_dead", iconsize, iconsize);
            teamicons[enemyteam] setparent(outcometext);
            teamicons[enemyteam] setpoint("TOP", "BOTTOM", currentx, spacing);
            teamicons[enemyteam].hidewheninmenu = 0;
            teamicons[enemyteam].archived = 0;
            teamicons[enemyteam].immunetodemogamehudsettings = 1;
            teamicons[enemyteam].immunetodemofreecamera = 1;
            teamicons[enemyteam] fadeovertime(0.5);
            teamicons[enemyteam].alpha = 1;
            
            currentx += iconspacing;
        }
    }
    teamscores = [];
    teamscores[team] = createfontstring(font, titlesize);
    teamscores[team] setparent(teamicons[team]);
    teamscores[team] setpoint("TOP", "BOTTOM", 0, spacing);
    teamscores[team].glowalpha = 1;
    if (level.round_based)
        teamscores[team] setvalue(randomintrange(0, 4));
    else
        teamscores[team] setvalue(4);
    teamscores[team].hidewheninmenu = 0;
    teamscores[team].archived = 0;
    teamscores[team].immunetodemogamehudsettings = 1;
    teamscores[team].immunetodemofreecamera = 1;
    teamscores[team] setpulsefx(100, duration, 1000);

    foreach(enemyteam in level.teams)
    {
        if (enemyteam != team)
        {
            teamscores[enemyteam] = createfontstring(headerfont, titlesize);
            teamscores[enemyteam] setparent(teamicons[enemyteam]);
            teamscores[enemyteam] setpoint("TOP", "BOTTOM", 0, spacing);
            teamscores[enemyteam].glowalpha = 1;
            teamscores[enemyteam] setvalue(level.enemy_score);
            teamscores[enemyteam].hidewheninmenu = 0;
            teamscores[enemyteam].archived = 0;
            teamscores[enemyteam].immunetodemogamehudsettings = 1;
            teamscores[enemyteam].immunetodemofreecamera = 1;
            teamscores[enemyteam] setpulsefx(100, duration, 1000);
        }
    }
    font = "objective";
    matchbonus = createfontstring(font, 2);
    matchbonus setparent(outcometext);
    matchbonus setpoint("TOP", "BOTTOM", 0, iconsize + (spacing * 3) + teamscores[team].height);
    matchbonus.glowalpha = 1;
    matchbonus.hidewheninmenu = 0;
    matchbonus.archived = 0;
    matchbonus.label = game["strings"]["match_bonus"];
    matchbonus setvalue(randomintrange(2000, 3500));
    self thread maps\mp\gametypes_zm\_hud_message::resetoutcomenotify(teamicons, teamscores, outcometitle, outcometext);
}

// shader, logos, team icons
determineTeamLogo()
{
    mapname = tolower(getdvar("mapname"));
    standard = maps\mp\zombies\_zm_utility::is_standard(); 		// not turned/other shit
    survival = (getDvar("ui_zm_gamemodegroup") == "zsurvival"); // survival (Nuketown, TranZit solos)
    classic = (getDvar("ui_zm_gamemodegroup") == "zclassic"); 	// TranZit, MOTD, Origins, Buried, Die Rise

    if (survival)
    {
        if (is_true(level.should_use_cia))
            return game["icons"]["axis"];
        else
            return game["icons"]["allies"];
    }
    else if (classic)
    {
        return self.killcam_rank;
    }

    if (standard)
        return "hud_status_dead";

    return "hud_status_dead";
}

// a improved updatedamagefeedback
do_hitmarker_internal(mod, death)
{
    if (!isplayer(self))
        return;

    if (!isdefined(death))
        death = false;

    if (isdefined(mod) && mod != "MOD_CRUSH" && mod != "MOD_GRENADE_SPLASH" && mod != "MOD_HIT_BY_OBJECT")
    {
        self.hud_damagefeedback setshader("damage_feedback", 24, 48);
        self.hud_damagefeedback.alpha = 1;
        self.hud_damagefeedback fadeovertime(1);
        self.hud_damagefeedback.alpha = 0;
    }
}

do_hitmarker(mod, hit_location, hit_origin, player, amount)
{
    if (isdefined(player) && isplayer(player) && player != self)
    {
        player thread do_hitmarker_internal(mod);
        player.points += 10; // forgot what this is for, lol?
    }

    return false;
}

do_hitmarker_death()
{
    // self is the zombie victim in this case
    if (isdefined(self.attacker) && isplayer(self.attacker) && self.attacker != self)
        self.attacker thread do_hitmarker_internal(self.damagemod, true);
}

zombies_counter()
{
    level endon("endZmCounter");
    level.zombiesCounter = createServerFontString("hudsmall", 1.2);
    level.zombiesCounter setPoint("CENTER", "CENTER", "CENTER", 210);
    level.zombiesCounter.archived = 0;
    level.zombiesCounter.hideWhenInMenu = true;
    level.zombiesCounter thread waittillEnd();
    for(;;)
    {
        enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
        if (enemies == 0)
            level.zombiesCounter.label = &"Zombies: ^1";
        else if (enemies <= 3)
            level.zombiesCounter.label = &"Zombies: ^3";
        else if (enemies != 0)
            level.zombiesCounter.label = &"Zombies: ^2";
        level.zombiesCounter setValue(enemies);
        wait 0.05;
    }
}

waittillEnd()
{
    level waittill("game_ended");
    self Destroy();
}

dropCanSwap()
{
    weapon = randomGun();
    self giveWeapon(weapon);
    self dropItem(weapon);
}

randomGun() //Credits to @MatrixMods
{
    self.weaponsPick = [];
    self.weaponsPick = self GetWeaponsList();
    return self.weaponsPick[RandomIntRange(0, self.weaponsPick.size)];
}

checkGun(weap)
{
    self.allWeaps = [];
    self.allWeaps = self getWeaponsList();
    foreach(weapon in self.allWeaps)
    {
        if (isSubStr(weapon, weap))
            return true;
    }
    return false;
}

dropWeapon()
{
    self dropItem(self getCurrentWeapon());
}

toggle_save_and_load(announce)
{
    if (!isdefined(announce))
        announce = true;

    if (!self.snl)
    {
        if (announce) self iprintln("save and load ^2on");
        self thread monitor_save_and_load();
    }
    else
    {
        if (announce) self iprintln("save and load ^1off");
        self notify("toggle_save_and_load");
    }

    self.snl = !self.snl;
}

monitor_save_and_load()
{
    self endon("disconnect");
    self endon("toggle_save_and_load");
    level endon("game_ended");

    for(;;)
    {
        if (self actionslottwobuttonpressed() && self GetStance() == "crouch")
        {
            self.saved_origin = self.origin;
            self.saved_angles = self.angles;
            self iprintln("position ^2saved");
            wait 0.05;
        }
        if (self actionslotonebuttonpressed() && self GetStance() == "crouch")
        {
            if (isdefined(self.saved_angles) && isdefined(self.saved_origin))
            {
                self setplayerangles(self.saved_angles);
                self setorigin(self.saved_origin);
            }
            wait 0.04;
        }

        wait 0.05;
    }
}

verification_to_num(status)
{
    if (status == "host")
        return 2;
    if (status == "co")
        return 1;
    else
        return 0;
}

verification_to_color(status)
{
    if (status == "host")
        return "h";
    if (status == "co")
        return "c";
    else
        return "";
}

changeVerificationMenu(player, verlevel)
{
    if (player.status != verlevel && !player ishost())
    {
        player.status = verlevel;

        if (player.status == "Unverified")
            player thread destroyMenu(player);

        self iprintln("set level for " + player get_the_player_name() + " to " + verification_to_color(verlevel));
        player iprintln("your level has been set to " + verification_to_color(verlevel));
    }
    else
    {
        if (player ishost())
            self iprintln("cannot change level to " + verification_to_color(player.status));
        else
            self iprintln("level for " + player get_the_player_name() + " is already " + verification_to_color(verlevel));
    }
}

verification_to_letter(status)
{
    switch(status)
    {
    case "host":
        return "h";
    case "co":
        return "c";
    default:
        return "";
    }
}

get_the_player_name()
{
    level endon("game_ended");
    player_name = self.name;
    for(i = 0; i < self.name.size; i++)
    {
        if (self.name[i] == "]") break;
    }
    if (self.name.size != i)
        player_name = getSubStr(self.name, i + 1, self.name.size);
    return player_name;
}

Iif(bool, rTrue, rFalse)
{
    if (bool)
        return rTrue;
    else
        return rFalse;
}

// get proper names working later
formatLocal(name)
{
    switch (name)
    {
    case "mods":
        return "main";
    case "killcam":
        return "configure settings";
    case "weap":
        return "weapons";
    case "weappistol":
        return "pistols";
    case "weapsnip":
        return "snipers";
    case "weapother":
        return "others";
    case "weapstaff":
        return "staffs";
    case "weapsmg":
        return "smg";
    case "weaplmg":
        return "lmg";
    case "weapar":
        return "ar";
    case "weapar_gl":
        return "ar grenade launcher";
    case "weapsg":
        return "shotguns";
    case "equip":
        return "equipment";
    case "perk":
        return "perks";
    case "lobby":
        return "lobby menu";
    case "bots":
        return "bots menu";
    case "players_menu":
        return "players menu";
    case "zombies_menu":
        return "individual zombies menu";
    case "killcam_rank":
        return "killcam rank";
    case "killcam_length":
        return "killcam length";
    case "end_screen":
        return "end screen";
    default:
        return name;
    }
}

UpgradeWeapon()
{
    baseweapon = get_base_name(self getcurrentweapon());
    weapon = get_upgrade(baseweapon);
    if (isdefined(weapon))
    {
        self takeweapon(baseweapon);
        self giveweapon(weapon, 0, self get_pack_a_punch_weapon_options(weapon));
        self switchtoweapon(weapon);
        self givemaxammo(weapon);
    }
}

DowngradeWeapon()
{
    baseweapon = self getcurrentweapon();
    weapon = get_base_weapon_name(baseweapon, 1);
    if (isdefined(weapon))
    {
        self takeweapon(baseweapon);
        self giveweapon(weapon, 0, self get_pack_a_punch_weapon_options(weapon));
        self switchtoweapon(weapon);
        self givemaxammo(weapon);
    }
}

get_upgrade(weapon)
{
    if (isdefined(level.zombie_weapons[weapon]) && isdefined(level.zombie_weapons[weapon].upgrade_name))
        return get_upgrade_weapon(weapon, 0);
    return get_upgrade_weapon(weapon, 1);
}

CreateMenu()
{
    self add_menu(self.menuname, undefined, "Verified");
    self add_option(self.menuname, "main", ::submenu, "mods", "main");
    self add_option(self.menuname, "teleport", ::submenu, "teleport", "teleport");
    self add_option(self.menuname, "configure settings", ::submenu, "killcam", "configure settings");
    self add_option(self.menuname, "afterhit", ::submenu, "afterhit", "afterhit");
    self add_option(self.menuname, "weapons", ::submenu, "weap", "weapons");
    self add_option(self.menuname, "equipment", ::submenu, "equip", "equipment");
    self add_option(self.menuname, "perks", ::submenu, "perk", "perks");
    self add_option(self.menuname, "bots menu", ::submenu, "bots", "bots menu");
    self add_option(self.menuname, "lobby menu", ::submenu, "lobby", "lobby menu");
    self add_option(self.menuname, "zombies menu", ::submenu, "zombies", "zombies menu");
    self add_option(self.menuname, "players menu", ::submenu, "players_menu", "players menu");

    self add_menu("mods", self.menuname, "Verified");
    self add_option("mods", "god", ::godmode, self);
    self add_option("mods", "ufo", ::ufomode);
    self add_option("mods", "ufo speed", ::ufomodespeed);
    self add_option("mods", "die", ::killplayer, self);
    self add_option("mods", "save and load", ::toggle_save_and_load);
    self add_option("mods", "drop weapon", ::dropweapon);
    self add_option("mods", "switch teams", ::switchteams, self);
    self add_option("main", "empty stock", ::emptyClip);
    if (is_true(level.debug_mode))
        self add_option("mods", "aimbot", ::aimboobs);
    self add_option("mods", "+5000 points", ::addpoints, 5000);
    self add_option("mods", "upgrade weapon (pap)", ::UpgradeWeapon);
    self add_option("mods", "downgrade weapon", ::DowngradeWeapon);
    self add_option("mods", "give ammo", ::maxammo);

    self add_menu("teleport", self.menuname, "Verified");

    // thank you @miyzu!!!
    if (level.script == "zm_transit")
    {
        // oom / custom
        self add_option("teleport", "town bank barrier", ::teleportPlayer, (638.639, -93.0055, 1024.13), (0, -93.3551, 0));
        self add_option("teleport", "town church", ::teleportPlayer, (1318.84, -2634.33, 1023.71), (0, -78.5668, 0));
        self add_option("teleport", "town spot #1", ::teleportPlayer, (1099.07, -819.43, 120.125), (0, 44.6934, 0));
        self add_option("teleport", "town bar barrier", ::teleportPlayer, (2425.03, -128.08, 1029.13), (0, -130.28, 0));
        self add_option("teleport", "top of farm", ::teleportPlayer, (7916.54, -4598.8, 1024.13), (0, -120.618, 0));
        self add_option("teleport", "cool farm spot #1", ::teleportPlayer, (8285.4, -6780.23, 1024.13), (0, -3.36353, 0));
        self add_option("teleport", "cool farm spot #2", ::teleportPlayer, (8211.21, -3589.19, 642.349), (0, -120.462, 0));
        self add_option("teleport", "road spot", ::teleportPlayer, (-9439.18, -6810.59, 576.125), (0, -120.462, 0));
        self add_option("teleport", "tree spot", ::teleportPlayer, (5932.1, 7440.97, 1022.26), (0, 61.7558, 0));

        // base / copy
        self add_option("teleport", "pack a punch", ::teleportPlayer, (1946, -183, -303), (0, -93.3551, 0));
        self add_option("teleport", "bus depot", ::teleportPlayer, (-7108,4680,-65));
        self add_option("teleport", "diner", ::teleportPlayer, (-5010,-7189,-57));
    }
    else if (level.script == "zm_highrise")
    {
        // oom / custom
        self add_option("teleport", "oom #1", ::teleportPlayer, (1456.42, 966.383, 3920.13), (0, -64.9389, 0));
        self add_option("teleport", "oom #2", ::teleportPlayer, (3706.94, 862.985, 3960.13), (0, -159.658, 0));

        // base / copy
        self add_option("teleport", "slide", ::teleportPlayer, (2223.68, 2555.14, 3043.49), (0, -2.5975, 0));
        self add_option("teleport", "roof", ::teleportPlayer, (1965.23, 151.344, 2880.13));
        self add_option("teleport", "spawn", ::teleportPlayer, (1464.25, 1377.69, 3397.46));
        self add_option("teleport", "power", ::teleportPlayer, (2614.06, 30.8681, 1296.13));
        self add_option("teleport", "broken elevator", ::teleportPlayer, (3700.51, 2173.41, 2575.47));
        self add_option("teleport", "red room", ::teleportPlayer, (3176.08, 1426.12, 1298.53));
    }
    else if (level.script == "zm_buried")
    {
        self add_option("teleport", "spawn", ::teleportPlayer, (-2689.08, -761.858, 1360.13));
        self add_option("teleport", "under spawn", ::teleportPlayer, (-2689.08, -761.858, 1360.13));
        self add_option("teleport", "bank", ::teleportPlayer, (2614.06, 30.8681, 1296.13));
        self add_option("teleport", "bar", ::teleportPlayer, (790.854, -1433.25, 56.125));
        self add_option("teleport", "leroy cell", ::teleportPlayer, (-1081.72, 830.04, 8.125));
        self add_option("teleport", "middle of maze", ::teleportPlayer, (4920.74, 454.216, 4.125));
    }
    else
    {
        self add_option("teleport", "coming soon!");
    }

    // configure settings menu
    self add_menu("killcam", self.menuname, "Verified");
    self add_option("killcam", "(self) killcam rank", ::submenu, "killcam_rank", "killcam rank");
    self add_option("killcam", "killcam length", ::submenu, "killcam_length", "killcam length");
    self add_option("killcam", "end game screen", ::submenu, "end_screen", "end screen");

    // killcam:rank
    self add_menu("killcam_rank", "killcam", "Verified");
    self add_option("killcam_rank", "rank 1 (1 bone)", ::changerank, "1");
    self add_option("killcam_rank", "rank 2 (2 bones)", ::changerank, "2");
    self add_option("killcam_rank", "rank 3 (skull)", ::changerank, "3");
    self add_option("killcam_rank", "rank 4 (skull knife)", ::changerank, "4");
    self add_option("killcam_rank", "rank 5 (skull w/ spikes)", ::changerank, "5");
    self add_option("killcam_rank", "random rank", ::changerank);
    self add_option("killcam_rank", "twitter icon", ::changerank, "menu_lobby_icon_twitter", true);

    // killcam:length
    self add_menu("killcam_length", "killcam", "Verified");
    self add_option("killcam_length", "default time", ::changekctime, 5, true);
    self add_option("killcam_length", "+1 second", ::changekctime, 1);
    self add_option("killcam_length", "-1 second", ::changekctime, -1);
    self add_option("killcam_length", "+5 second", ::changekctime, 5);
    self add_option("killcam_length", "-5 second", ::changekctime, -5);

    // end screen
    self add_menu("end_screen", "killcam", "Verified");
    self add_option("end_screen", "round-based", ::change_screen, true);
    self add_option("end_screen", "victory", ::change_screen, false);
    for(i=0; i<5; i++)
    {
        self add_option("end_screen", "set enemy score to " + i, ::change_score, i);
    }

    // afterhit
    self add_menu("afterhit", self.menuname, "Verified");
    self add_option("afterhit", "claymore r-mala", ::afterhitweapon, self.afterhit[0]);
    self add_option("afterhit", "knuckles", ::afterhitweapon, self.afterhit[1]);
    self add_option("afterhit", "random perk bottle", ::afterhitweapon, self.afterhit[2]);
    if (level.script == "zm_tomb" || level.script == "zm_buried")
        self add_option("afterhit", "chalk", ::afterhitweapon, self.afterhit[3]);
    self add_option("afterhit", "syrette", ::afterhitweapon, self.afterhit[4]);
    if (level.script == "zm_prison")
    {
        self add_option("afterhit", "tomahawk", ::afterhitweapon, self.afterhit[5]);
        self add_option("afterhit", "afterlife hands", ::afterhitweapon, self.afterhit[6]);
    }
    if (level.script == "zm_tomb")
        self add_option("afterhit", "iron punch", ::afterhitweapon, self.afterhit[7]);

    // weapons:main
    self add_menu("weap", self.menuname, "Verified");
    self add_option("weap", "ar", ::submenu, "weapar", "ar");
    self add_option("weap", "ar grenade launcher", ::submenu, "weapar_gl", "ar grenade launcher");
    self add_option("weap", "smg", ::submenu, "weapsmg", "smg");
    self add_option("weap", "lmg", ::submenu, "weaplmg", "lmg");
    self add_option("weap", "shotguns", ::submenu, "weapsg", "shotguns");
    self add_option("weap", "pistols", ::submenu, "weappistol", "pistols");
    self add_option("weap", "snipers", ::submenu, "weapsnip", "snipers");
    self add_option("weap", "others", ::submenu, "weapother", "others");
    if (level.script == "zm_tomb")
        self add_option("weap", "^2(origins) ^7staffs", ::submenu, "weapstaff", "staffs");

    // weapons:ar:gl
    self add_menu("weapar_gl", "weap", "Verified");
    self add_option("weapar_gl", "*THESE ARE GLITCHED*");

    // weapons:staff
    if (level.script == "zm_tomb")
    {
        self add_menu("weapstaff", "weap", "Verified");
        self add_option("weapstaff", "air staff", ::g_weapon, "staff_air_zm");
        self add_option("weapstaff", "fire staff", ::g_weapon, "staff_fire_zm");
        self add_option("weapstaff", "ice staff", ::g_weapon, "staff_water_zm");
        self add_option("weapstaff", "lightning staff", ::g_weapon, "staff_lightning_zm");
        self add_option("weapstaff", "upgraded air staff", ::g_staff, "staff_air_upgraded_zm", "upgraded air staff");
        self add_option("weapstaff", "upgraded fire staff", ::g_staff, "staff_fire_upgraded_zm", "upgraded fire staff");
        self add_option("weapstaff", "upgraded ice staff", ::g_staff, "staff_lightning_upgraded_zm", "upgraded ice staff");
        self add_option("weapstaff", "upgraded lightning staff", ::g_staff, "staff_water_upgraded_zm", "upgraded lightning staff");
    }

    // weapons:ar
    self add_menu("weapar", "weap", "Verified");
    self add_option("weapar", "fal", ::g_weapon, "fnfal_zm");
    self add_option("weapar", "m14", ::g_weapon, "m14_zm");
    self add_option("weapar", "galil", ::g_weapon, "galil_zm");
    if (level.script == "zm_transit" || level.script == "zm_nuked")
    {
        if (level.script == "zm_nuked")
            self add_option("weapar", "m27", ::g_weapon, "hk416_zm");
        self add_option("weapar", "m16", ::g_weapon, "m16_zm");
    }
    if (level.script != "zm_buried" && level.script != "zm_prison" && level.script != "zm_tomb")
    {
        self add_option("weapar", "m8a1", ::g_weapon, "xm8_zm");
        self add_option("weapar_gl", "m8a1 gl", ::g_weapon, "gl_xm8_zm");
    }
    if (level.script != "zm_tomb")
    {
        if (level.script != "zm_prison")
        {
            self add_option("weapar", "smr", ::g_weapon, "saritch_zm");
        }
        self add_option("weapar", "mtar", ::g_weapon, "tar21_zm");
        self add_option("weapar_gl", "mtar gl", ::g_weapon, "gl_tar21_zm");
    }
    if (level.script != "zm_prison")
    {
        if (level.script != "zm_buried")
        {
            self add_option("weapar", "type 25", ::g_weapon, "type95_zm");
            self add_option("weapar_gl", "type 25 gl", ::g_weapon, "gl_type95_zm");
        }
        self add_option("weapar", "hamr", ::g_weapon, "hamr_zm");
    }
    if (level.script == "zm_highrise" || level.script == "zm_buried")
    {
        self add_option("weapar", "an94", ::g_weapon, "an94_zm");
    }
    if (level.script == "zm_tomb")
    {
        self add_option("weapar", "stg 44", ::g_weapon, "mp44_zm");
        self add_option("weapar", "scar-h", ::g_weapon, "scar_zm");
    }
    if (level.script == "zm_prison")
    {
        self add_option("weapar", "ak47", ::g_weapon, "ak47_zm");
    }

    // weapons:smg
    self add_menu("weapsmg", "weap", "Verified");
    if (level.script != "zm_tomb" && level.script != "zm_buried")
        self add_option("weapsmg", "mp5", ::g_weapon, "mp5k_zm");
    if (level.script != "zm_prison")
    {
        if (level.script != "zm_buried")
            self add_option("weapsmg", "chicom", ::g_weapon, "qcw05_zm");
        self add_option("weapsmg", "ak74u", ::g_weapon, "ak74u_zm");
    }
    if (level.script == "zm_buried" || level.script == "zm_prison" || level.script == "zm_highrise")
    {
        self add_option("weapsmg", "pdw57", ::g_weapon, "pdw57_zm");
    }
    if (level.script == "zm_tomb")
    {
        self add_option("weapsmg", "mp40", ::g_weapon, "mp40_zm");
        self add_option("weapsmg", "skorpion", ::g_weapon, "evoskorpion_zm");
    }
    if (level.script == "zm_prison")
    {
        self add_option("weapsmg", "uzi", ::g_weapon, "uzi_zm");
        self add_option("weapsmg", "m1927", ::g_weapon, "thompson_zm");
    }

    // weapons:lmg
    self add_menu("weaplmg", "weap", "Verified");
    if (level.script == "zm_transit" || level.script == "zm_nuked" || level.script == "zm_highrise")
        self add_option("weaplmg", "rpd", ::g_weapon, "rpd_zm");
    if (level.script == "zm_buried" || level.script == "zm_prison" || level.script == "zm_nuked")
    {
        self add_option("weaplmg", "lsat", ::g_weapon, "lsat_zm");
    }
    if (level.script == "zm_tomb")
    {
        self add_option("weaplmg", "mg08", ::g_weapon, "mg08_zm");
    }

    // weapons:shotguns
    self add_menu("weapsg", "weap", "Verified");
    self add_option("weapsg", "remington", ::g_weapon, "870mcs_zm");
    if (level.script != "zm_prison")
    {
        self add_option("weapsg", "m1216", ::g_weapon, "srm1216_zm");
    }
    if (level.script != "zm_tomb")
    {
        self add_option("weapsg", "s12", ::g_weapon, "saiga12_zm");
        self add_option("weapsg", "olympia", ::g_weapon, "rottweil72_zm");
    }
    if (level.script == "zm_tomb")
    {
        self add_option("weapsg", "ksg", ::g_weapon, "ksg_zm");
    }

    // weapons:pistols
    self add_menu("weappistol", "weap", "Verified");
    self add_option("weappistol", "five seven", ::g_weapon, "fiveseven_zm");
    self add_option("weappistol", "dw five seven", ::g_weapon, "fivesevendw_zm");
    self add_option("weappistol", "b23r", ::g_weapon, "beretta93r_zm");
    if (level.script != "zm_tomb")
    {
        self add_option("weappistol", "m1911", ::g_weapon, "m1911_zm");
        self add_option("weappistol", "executioner", ::g_weapon, "judge_zm");
    }
    if (level.script != "zm_buried" && level.script != "zm_prison")
        self add_option("weappistol", "python", ::g_weapon, "python_zm");
    if (level.script != "zm_prison")
        self add_option("weappistol", "kap40", ::g_weapon, "kard_zm");
    if (level.script == "zm_buried")
        self add_option("weappistol", "rnma", ::g_weapon, "rnma_zm");
    if (level.script == "zm_tomb")
    {
        self add_option("weappistol", "mauser", ::g_weapon, "c96_zm");
    }

    // weapons:snipers
    self add_menu("weapsnip", "weap", "Verified");
    self add_option("weapsnip", "dsr", ::g_weapon, "dsr50_zm");
    self add_option("weapsnip", "barret", ::g_weapon, "barretm82_zm");
    if (level.script == "zm_buried" || level.script == "zm_highrise")
        self add_option("weapsnip", "svu", ::g_weapon, "svu_zm");
    if (level.script == "zm_tomb")
        self add_option("weapsnip", "ballista", ::g_weapon, "ballista_zm");

    // weapons:others
    self add_menu("weapother", "weap", "Verified");
    self add_option("weapother", "ray gun", ::g_weapon, "ray_gun_zm");
    self add_option("weapother", "ray gun mk2", ::g_weapon, "raygun_mark2_zm");
    if (level.script != "zm_prison")
    {
        self add_option("weapother", "grenade launcher", ::g_weapon, "m32_zm");
        if (level.script != "zm_tomb")
        {
            self add_option("weapother", "ballistic knife 1", ::g_weapon, "knife_ballistic_no_melee_zm");
            self add_option("weapother", "ballistic knife 2", ::g_weapon, "knife_ballistic_bowie_zm");
            self add_option("weapother", "ballistic knife 3", ::g_weapon, "knife_ballistic_zm");
        }
    }
    if (level.script != "zm_transit" || level.script != "zm_tomb")
        self add_option("weapother", "rpg", ::g_weapon, "usrpg_zm");
    if (level.script == "zm_buried")
        self add_option("weapother", "paralyzer", ::g_weapon, "slowgun_zm");
    if (level.script == "zm_highrise")
        self add_option("weapother", "sliquifier", ::g_weapon, "slipgun_zm");
    if (level.script == "zm_prison")
    {
        self add_option("weapother", "blundergat", ::g_weapon, "blundergat_zm");
        self add_option("weapother", "acidgat", ::g_weapon, "blundersplat_zm");
        self add_option("weapother", "death machine", ::g_weapon, "minigun_alcatraz_zm");
        self add_option("weapother", "afterlife hands", ::g_weapon, "lightning_hands_zm");
    }

    // equipment
    self add_menu("equip", self.menuname, "Verified");
    if (is_valid_equipment("sticky_grenade_zm"))
        self add_option("equip", "give semtex", ::g_weapon, "sticky_grenade_zm");
    if (is_valid_equipment("emp_grenade_zm"))
        self add_option("equip", "give emp", ::g_weapon, "emp_grenade_zm");
    if (is_valid_equipment("willy_pete_zm"))
        self add_option("equip", "give smokes", ::g_weapon, "willy_pete_zm");
    if (is_valid_equipment("spoon_zm_alcatraz"))
        self add_option("equip", "give spork", ::g_weapon, "spoon_zm_alcatraz");
    if (is_valid_equipment("cymbal_monkey_zm"))
        self add_option("equip", "give monkey", ::g_weapon, "cymbal_monkey_zm");
    if (is_valid_equipment("time_bomb_zm") && isdefined(level.zombiemode_time_bomb_give_func))
        self add_option("equip", "give time bomb", ::g_timebomb);
    if (is_valid_equipment("beacon_zm"))
        self add_option("equip", "give g strike", ::g_beacon);
    if (is_valid_equipment("claymore_zm"))
        self add_option("equip", "give claymore", ::g_claymore);

    // perks
    self add_menu("perk", self.menuname, "Verified");
    self add_option("perk", "fast hands (weapon switch)", ::fasthands);
    if (is_true(level.zombiemode_using_juggernaut_perk))
        self add_option("perk", "juggernaut", ::doperks, "specialty_armorvest");
    if (is_true(level.zombiemode_using_sleightofhand_perk))
        self add_option("perk", "fast reload", ::doperks, "specialty_fastreload");
    if (is_true(level.zombiemode_using_doubletap_perk))
        self add_option("perk", "double tap", ::doperks, "specialty_rof");
    if (is_true(level.zombiemode_using_deadshot_perk))
        self add_option("perk", "deadshot", ::doperks, "specialty_deadshot");
    if (is_true(level.zombiemode_using_tombstone_perk))
        self add_option("perk", "tombstone", ::doperks, "specialty_scavenger");
    if (is_true(level.zombiemode_using_additionalprimaryweapon_perk))
        self add_option("perk", "mule kick", ::doperks, "specialty_additionalprimaryweapon");
    if (is_true(level.zombiemode_using_chugabud_perk))
        self add_option("perk", "quick revive", ::doperks, "specialty_quickrevive");
    if (is_true(level.zombiemode_using_electric_cherry_perk))
        self add_option("perk", "electric cherry", ::doperks, "specialty_grenadepulldeath");
    if (is_true(level.zombiemode_using_vulture_perk))
        self add_option("perk", "vulture aid", ::doperks, "specialty_nomotionsensor");

    // zombies
    self add_menu("zombies", self.menuname, "Verified");
    self add_option("zombies", "freeze zombie(s)", ::freezezm);
    self add_option("zombies", "zombie(s) ignore you", ::zmignoreme);
    self add_option("zombies", "zombie(s) -> crosshair", ::tp_zombies);
    self add_option("zombies", "individual zombies menu", ::submenu, "zombies_menu", "individual zombies menu");

    self add_menu("zombies_menu", "zombies", "Verified");
    for(i = 0; i < 17; i++)
    {
        self add_menu("zOzt " + i, "zombies_menu", "Verified");
    }

    // bots
    self add_menu("bots", self.menuname, "Verified");
    self add_option("bots", "spawn 1 bot", ::spawnbot);
    self add_option("bots", "bot(s) -> crosshair", ::tpbotstocrosshair);
    self add_option("bots", "toggle invisible bot(s)", ::makebotinvis);
    self add_option("bots", "bot(s) look @ me", ::makebotswatch);
    self add_option("bots", "bot(s) constant look @ me", ::constantlookbot);

    self add_menu("lobby", self.menuname, "Verified");
    self add_option("lobby", "end game", ::customendgame_f);
    self add_option("lobby", "zombie counter", ::togglezmcounter);
    self add_option("lobby", "timescale 0.25", ::timescale, 0.25);
    self add_option("lobby", "timescale 0.5", ::timescale, 0.50);
    self add_option("lobby", "timescale 0.75", ::timescale, 0.75);
    self add_option("lobby", "timescale 1", ::timescale, 1);
    self add_option("lobby", "timescale 2", ::timescale, 2);

    self add_menu("players_menu", self.menuname, "Verified");
    for(i = 0; i < 17; i++)
    {
        self add_menu("pOpt " + i, "players_menu", "Verified");
    }
}

godmode(player, silent)
{
    if (!isdefined(silent))
        silent = false;
    if (!isdefined(player.godmode))
        player.godmode = false;

    if (!player.godmode)
    {
        player enableinvulnerability();
        player iprintln("god mode ^2on");
        player.godmode = true;
    }
    else if (player.godmode)
    {
        player disableinvulnerability();
        player iprintln("god mode ^1off");
        player.godmode = false;
    }

    if (self != player)
    {
        if (!silent)
        {
            if (player.godmode)
                self iprintln(player.name + "'s god mode ^2on");
            else if (!player.godmode)
                self iprintln(player.name + "'s god mode ^1off");
        }
    }
}

ufomode()
{
    if (!self.ufomode)
    {
        self iprintln("ufo ^2on");
        self iprintln("^7press [{+smoke}] to fly");
        self thread doufomode();
        self.ufomode = true;
    }
    else if (self.ufomode)
    {
        self iprintln("ufo ^1off");
        self notify("stopufo");
        self.ufomode = false;
    }
}

doufomode()
{
    self endon("stopufo");
    self.fly = 0;
    ufo = spawn("script_model", self.origin);
    for(;;)
    {
        if (self secondaryoffhandbuttonpressed())
        {
            self playerLinkTo(UFO);
            self.fly = 1;
        }
        else
        {
            self Unlink();
            self.fly = 0;
        }
        if (self.fly)
        {
            fly = self.origin + vector_scal(anglesToForward(self getPlayerAngles()), self.ufospeed);
            UFO moveTo(fly, .03);
        }
        wait 0.001;
    }
}

ufomodespeed()
{
    if (!isdefined(self.ufospeed))
        self.ufospeed = 20;

    speed = self.ufospeed;
    switch (speed)
    {
    case 20:
        self iprintln("ufo speed changed to ^140");
        self.ufospeed = 40;
        break;
    case 40:
        self iprintln("ufo speed changed to ^160");
        self.ufospeed = 60;
        break;
    case 60:
        self iprintln("ufo speed changed to ^180");
        self.ufospeed = 80;
        break;
    case 80:
        self iprintln("ufo speed changed to ^1100");
        self.ufospeed = 100;
        break;
    case 100:
        self iprintln("ufo speed changed to ^120");
        self.ufospeed = 20;
        break;
    default:
        break;
    }
}

switchteams(player)
{
    player.switching_teams = 1;
    if (player.team == "allies")
    {
        player.joining_team = "axis";
        player.leaving_team = player.pers["team"];
        player.team = "axis";
        player.pers["team"] = "axis";
        player.sessionteam = "axis";
        player._encounters_team = "A";
    }
    else
    {
        player.joining_team = "allies";
        player.leaving_team = player.pers["team"];
        player.team = "allies";
        player.pers["team"] = "allies";
        player.sessionteam = "allies";
        player._encounters_team = "B";
    }

    isdefault = "";
    if (player.default_team == player.team)
        isdefault = "(^2default^7)";
    else
        isdefault = "(^1not default^7)";

    player notify("joined_team");
    player iprintln("switched to ^1" + player.team + " ^7team " + isdefault);
    if (self != player)
        self iprintln("changed player team to ^1" + player.team + " ^7team " + isdefault);
}

g_weapon(weapon)
{
    // just found this weapon wrapper lol
    self maps\mp\zombies\_zm_weapons::weapon_give(weapon);
    self givemaxammo(weapon);
}

doperks(perk)
{
    self maps\mp\zombies\_zm_perks::give_perk(perk);
}

freezezm()
{
    if (!isdefined(level.zmfrozen))
        level.zmfrozen = false;

    if (!level.zmfrozen)
    {
        self iprintln("freeze zombies ^2on");
        setdvar("g_ai", "0");
        level.zmfrozen = true;
    }
    else
    {
        self iprintln("freeze zombies ^1off");
        setdvar("g_ai","1");
        level.zmfrozen = false;
    }
}

zmignoreme()
{
    if (!self.ignoreme)
    {
        self iprintln("zombies ignore you ^2on");
        self.ignoreme = true;
    }
    else
    {
        self iprintln("zombies ignore you ^1off");
        self.ignoreme = false;
    }
}

setpoints(points)
{
    self.score = points;
}

addpoints(points)
{
    self.score += points;
}

// rewrote
spawnbot()
{
    spawnpoints = getstructarray("initial_spawn_points", "targetname");
    spawnpoint = getfreespawnpoint(spawnpoints);
    bot = addtestclient();
    if (!isdefined(bot))
        return;

    bot.pers["isBot"] = true;
    bot.equipment_enabled = false;
    yaw = spawnpoint.angles[1];
    bot thread maps\mp\zombies\_zm::zbot_spawn_think(spawnpoint.origin, yaw);

    team = level.players[0].team;
    bot.switching_teams = 1;
    bot.joining_team = team;
    bot.leaving_team = self.pers["team"];
    bot.team = team;
    bot.pers["team"] = team;
    bot.sessionteam = team;
    bot._encounters_team = (team == "axis" ? "A" : "B");
    bot notify("joined_team");

    bot waittill("spawned_player");
    godmode(bot, true);

    iprintln("bot ^2spawned^7 with ^1god mode ^2on^7");
    return bot;
}

makebotinvis()
{
    if (!isdefined(level.invisbot))
        level.invisbot = false;

    if (!level.invisbot)
    {
        foreach(bot in level.players)
        {
            if (isdefined(bot.pers["isBot"]) && bot.pers["isBot"])
            {
                bot hide();
                bot thread keepinpos();
            }
        }
        iprintln("bots invisible ^2on");
        level.invisbot = true;
    }
    else
    {
        foreach(bot in level.players)
        {
            if (isdefined(bot.pers["isBot"]) && bot.pers["isBot"])
            {
                bot show();
                bot notify("bot_keepin");
            }
        }
        iprintln("bots invisible ^1off");
        level.invisbot = false;
    }
}

keepinpos()
{
    self endon("bot_keepin");
    level endon("game_ended");
    org = self.origin;
    for(;;)
    {
        self setorigin(org);
        wait 0.5;
    }
}

tpbotstocrosshair()
{
    foreach(bot in level.players)
    {
        if (isdefined(bot.pers["isBot"]) && bot.pers["isBot"])
        {
            bot setorigin(bullettrace(self gettagorigin("j_head"), self gettagorigin("j_head") + anglestoforward(self getplayerangles()) * 1000000, 0, self)["position"]);
        }
    }
    self iprintln("bots ^1teleported ^7to crosshair^7");
}

// i made this just for jimbo idk if it works lul
tp_zombies(ai_num)
{
    zombies = getaiarray(level.zombie_team);
    if (!isdefined(ai_num))
    {
        foreach(zombie in zombies)
        {
            zombie forceteleport(bullettrace(self gettagorigin("j_head"), self gettagorigin("j_head") + anglestoforward(self getplayerangles()) * 1000000, 0, self)["position"]);
        }
        self iprintln("zombies ^1teleported ^7to crosshair^7");
    }
    else
    {
        foreach(zombie in zombies)
        {
            if (zombie get_ai_number() == ai_num)
            {
                zombie forceteleport(bullettrace(self gettagorigin("j_head"), self gettagorigin("j_head") + anglestoforward(self getplayerangles()) * 1000000, 0, self)["position"]);
                break;
            }
        }
        self iprintln("zombie ^1teleported ^7to crosshair^7");
    }
}

customendgame_f()
{
    level thread customendgame();
}

instantend()
{
    return exitlevel(false);
}

togglezmcounter()
{
    if (!isdefined(level.zombieCounter))
        level.zombieCounter = true;

    if (!level.zombieCounter)
    {
        iprintln("zombies counter ^2on");
        level thread zombies_counter();
    }
    else if (level.zombieCounter)
    {
        iprintln("zombies counter ^1off");
        level notify("endZmCounter");
        level.zombiesCounter delete();
        level.zombiesCounter destroy();
    }
    level.zombieCounter = !level.zombieCounter;
}

add_menu_alt(Menu, prevmenu)
{
    self.menu.getmenu[Menu] = Menu;
    self.menu.menucount[Menu] = 0;
    self.menu.previousmenu[Menu] = prevmenu;
}

add_menu(Menu, prevmenu, status)
{
    self.menu.status[Menu] = status;
    self.menu.getmenu[Menu] = Menu;
    self.menu.scrollerpos[Menu] = 0;
    self.menu.curs[Menu] = 0;
    self.menu.menucount[Menu] = 0;
    self.menu.previousmenu[Menu] = prevmenu;
}

add_option(Menu, Text, Func, arg1, arg2, tolower)
{
    if (!isdefined(tolower))
        tolower = true;

    Menu = self.menu.getmenu[Menu];
    Num = self.menu.menucount[Menu];
    if (tolower)
        self.menu.menuopt[Menu][Num] = ToLower(Text);
    else self.menu.menuopt[Menu][Num] = Text;
    self.menu.menufunc[Menu][Num] = Func;
    self.menu.menuinput[Menu][Num] = arg1;
    self.menu.menuinput1[Menu][Num] = arg2;
    self.menu.menucount[Menu] += 1;
}

updatescrollbar()
{
    self.menu.scroller MoveOverTime(0.10);
    self.menu.scroller.y = 50 + (self.menu.curs[self.menu.currentmenu] * 14.40);
}

openTheMenu()
{
    if (!isdefined(self.firstmenuopen))
        self.firstmenuopen = true;

    if (self.firstmenuopen)
    {
        self iPrintLn("[{+actionslot 1}] / [{+actionslot 2}] - up/down");
        self iPrintLn("[{+gostand}] - select");
        self iPrintLn("[{+activate}] - back");
        self.firstmenuopen = false;
    }

    self.menu.background thread moveItTo("x", 263+self.menuxpos, .4);
    self.menu.scroller thread moveItTo("x", 263+self.menuxpos, .4);
    self.menu.background FadeOverTime(0.6);
    self.menu.background.alpha = 0.55;
    self.menu.scroller FadeOverTime(0.6);
    self.menu.scroller.alpha = 1;
    self.menu.background1 FadeOverTime(0.6);
    self.menu.background1.alpha = 0.08;
    wait 0.5;
    self store_text(self.menuname, self.menuname);
    self.menu.title2 FadeOverTime(0.3);
    self.menu.title2.alpha = 1;
    self.menu.backgroundinfo FadeOverTime(0.3);
    self.menu.backgroundinfo.alpha = 1;
    self.menu.title FadeOverTime(0.3);
    self.swagtext.alpha = 0.90;
    self.menu.counter FadeOverTime(0.3);
    self.menu.counter1 FadeOverTime(0.3);
    self.menu.counter.alpha = 1;
    self.menu.counter1.alpha = 1;
    self.menu.counterSlash FadeOverTime(0.3);
    self.menu.counterSlash.alpha = 1;
    self.menu.line MoveOverTime(0.3);
    self.menu.line.y = -50;
    self.menu.line2 MoveOverTime(0.3);
    self.menu.line2.y = -50;
    self updatescrollbar();
    self.menu.open = true;
}

closeTheMenu()
{
    self.menu.options FadeOverTime(0.3);
    self.menu.options.alpha = 0;
    self.statuss FadeOverTime(0.3);
    self.statuss.alpha = 0;
    self.tez FadeOverTime(0.3);
    self.tez.alpha = 0;
    self.menu.counter FadeOverTime(0.3);
    self.menu.counter1 FadeOverTime(0.3);
    self.menu.counter.alpha = 0;
    self.menu.counter1.alpha = 0;
    self.menu.counterSlash FadeOverTime(0.3);
    self.menu.counterSlash.alpha = 0;
    self.swagtext FadeOverTime(0.30);
    self.swagtext.alpha = 0;
    self.menu.title2 FadeOverTime(0.3);
    self.menu.title2.alpha = 0;
    self.menu.title FadeOverTime(0.30);
    self.menu.title.alpha = 0;
    self.menu.line MoveOverTime(0.30);
    self.menu.line.y = -550;
    self.menu.line2 MoveOverTime(0.30);
    self.menu.line2.y = -550;
    self.menu.backgroundinfo FadeOverTime(0.3);
    self.menu.backgroundinfo.alpha = 0;
    self.menu.open = false;
    wait 0.3;
    self.menu.background1 FadeOverTime(0.3);
    self.menu.background1.alpha = 0;
    self.menu.scroller FadeOverTime(0.3);
    self.menu.scroller.alpha = 0;
    self.menu.background FadeOverTime(0.3);
    self.menu.background.alpha = 0;
    self.menu.background thread moveItTo("x", 800, .4);
    self.menu.scroller thread moveItTo("x", 800, .4);
}

moveItTo(axis, position, time)
{
    self moveOverTime(time);

    if (axis=="x")
        self.x = position;
    else
        self.y = position;
}

destroyMenu(player)
{
    player.menu_init = false;
    player closeTheMenu();
    wait 0.3;
    player.menu.options destroy();
    player.menu.background1 destroy();
    player.menu.backgroundMain destroy();
    player.menu.backgroundMain2 destroy();
    player.menu.scroller destroy();
    player.menu.scroller1 destroy();
    player.infos destroy();
    player.menu.title2 destroy();
    player.menu.counter destroy();
    player.menu.counter1 destroy();
    player.menu.line destroy();
    player.menu.line2 destroy();
    player.menu.counterSlash destroy();
    player.menu.title destroy();
    player notify("destroyMenu");
}

StoreShaders()
{
    // got the color and alpha values from my killcam mod
    //drawShader(shader, x, y, width, height, color, alpha, sort)
    self.menu.background = self drawShader("white", 800, 25, 155, 286, (0, 0, 0), .2, 0);
    self.menu.scroller = self drawShader("white", 800, -100, 155, 12, (0.749, 0, 0), 255, 1);
    self thread flickershaders();
}

flickershaders()
{
    self endon("disconnect");
    level endon("game_ended");
    for(;;)
    {
        if (self.menu.open)
        {
            waittime = randomFloatRange(0.3, 1.4);
            self.statuss.color = (0.2, 0, 0);
            self.menu.scroller.color = (0.2, 0, 0);
            self.menu.scroller.alpha = 1;
            wait waittime;
            self.statuss FadeOverTime(waittime);
            self.statuss.color = (1, 0, 0);
            self.menu.scroller FadeOverTime(waittime);
            self.menu.scroller.color = (1, 0, 0);
            self.menu.scroller.alpha = 0.8;
            wait waittime;
            self.statuss FadeOverTime(waittime);
            self.statuss.color = (0, 0, 0);
            self.menu.scroller FadeOverTime(waittime);
            self.menu.scroller.color = (0, 0, 0);
            self.menu.scroller.alpha = .0;
        }
        wait 0.05;
    }
}

store_text(menu, title)
{
    self.menu.currentmenu = menu;
    string = "";
    self.menu.currentmenu = menu;
    string = "";
    self.menu.title2 destroy();
    self.menu.title2 = drawText(title, "default", 1.2, 255+self.menuxpos, 0, (1, 1, 1), 0, 3);
    self.menu.title2 FadeOverTime(0);
    self.menu.title2.alpha = 1;
    self.menu.title2 setPoint("LEFT", "LEFT", 550+self.menuxpos, -161);
    for(i = 0; i < self.menu.menuopt[menu].size; i++)
    {
        string +=self.menu.menuopt[menu][i] + "\n";
    }
    self.menu.counter destroy();
    self.menu.counter = drawValue(self.menu.curs[menu] + 1, "objective", 1.2, "RIGHT", "CENTER", 325+self.menuxpos, -161, (1, 1, 1), 3);
    self.menu.counter.alpha = 1;
    self.menu.counter1 destroy();
    self.menu.counter1 = drawValue(self.menu.menuopt[menu].size, "objective", 1.2, "RIGHT", "CENTER", 338+self.menuxpos, -161, (1, 1, 1), 3);
    self.menu.counter1.alpha = 1;
    self.statuss destroy();
    self.statuss = drawText("by @mjkzys^7", "default", 1.1, 0+self.menuxpos, 0, (1, 1, 1), 0, 4);
    self.statuss FadeOverTime(0);
    self.statuss.alpha = 1;
    self.statuss setPoint("LEFT", "LEFT", 550+self.menuxpos, 99);
    self.menu.options destroy();
    self.menu.options = drawText(string, "objective", 1.2, 290+self.menuxpos, 90, (1, 1, 1), 0, 4);
    self.menu.options FadeOverTime(0.5);
    self.menu.options.alpha = 1;
    self.menu.options setPoint("LEFT", "LEFT", 550+self.menuxpos, -148);
}

menu_init()
{
    self endon("disconnect");
    self endon("destroyMenu");
    level endon("game_ended");
    level endon("manual_end_game");

    self.menu = spawnstruct();
    self.toggles = spawnstruct();

    self.menu.open = false;

    self StoreShaders();
    self CreateMenu();

    for(;;)
    {
        if (self actionSlotOneButtonPressed() && self adsButtonPressed() && !self.menu.open)
        {
            self openTheMenu();
            self setclientuivisibilityflag("hud_visible", 0);
        }
        if (self.menu.open)
        {
            if (self useButtonPressed())
            {
                if (isdefined(self.menu.previousmenu[self.menu.currentmenu]))
                {
                    self submenu(self.menu.previousmenu[self.menu.currentmenu], formatLocal(self.menu.previousmenu[self.menu.currentmenu]));
                }
                else
                {
                    self closeTheMenu();
                    self setclientuivisibilityflag("hud_visible", 1);
                }
                wait 0.2;
            }
            else if (self actionSlotOneButtonPressed() || self actionSlotTwoButtonPressed())
            {
                self.menu.curs[self.menu.currentmenu] += (Iif(self actionSlotTwoButtonPressed(), 1, -1));
                self.menu.curs[self.menu.currentmenu] = (Iif(self.menu.curs[self.menu.currentmenu] < 0, self.menu.menuopt[self.menu.currentmenu].size-1, Iif(self.menu.curs[self.menu.currentmenu] > self.menu.menuopt[self.menu.currentmenu].size-1, 0, self.menu.curs[self.menu.currentmenu])));
                self.menu.counter setValue(self.menu.curs[self.menu.currentmenu] + 1);
                self.menu.counter1 setValue(self.menu.menuopt[self.menu.currentmenu].size);
                self updatescrollbar();
            }
            else if (self jumpButtonPressed())
            {
                self thread [[self.menu.menufunc[self.menu.currentmenu][self.menu.curs[self.menu.currentmenu]]]](self.menu.menuinput[self.menu.currentmenu][self.menu.curs[self.menu.currentmenu]], self.menu.menuinput1[self.menu.currentmenu][self.menu.curs[self.menu.currentmenu]]);
                wait 0.2;
            }
        }
        wait 0.05;
    }
}

submenu(input, title, lower)
{
    if (!isdefined(lower))
        lower = true;

    if (lower)
        title = tolower(title);

    if (verification_to_num(self.status) >= verification_to_num(self.menu.status[input]))
    {
        self.menu.options destroy();

        if (input == self.menuname)
            self thread store_text(input, self.menuname);
        else
        {
            if (input == "players_menu")
            {
                self update_players_menu();
            }
            else if (input == "zombies_menu")
            {
                zombies = getaiarray(level.zombie_team);
                if (zombies.size < 1)
                {
                    self iprintln("zombies are still spawning in, please try again.");
                    return;
                }

                self update_zombies_menu();
            }

            self thread store_text(input, title);
        }

        self.menu.scrollerpos[input] = self.menu.curs[input];
        self.menu.curs[input] = self.menu.scrollerpos[input];

        self updatescrollbar();
    }
    else
    {
        self iprintln("only players with ^2" + verification_to_color(self.menu.status[input]) + " ^7can use this.");
    }
}

overflow_fix()
{
    self.stringTable = [];
    self.stringTableEntryCount = 0;
    self.textTable = [];
    self.textTableEntryCount = 0;
    if (!isdefined(level.anchorText))
    {
        level.anchorText = createServerFontString("default", 1.5);
        level.anchorText setText("anchor");
        level.anchorText.alpha = 0;
        level.stringCount = 0;
        level thread monitorOverflow();
    }
}

monitorOverflow()
{
    level endon("disconnect");
    for(;;)
    {
        if (level.stringCount >= 60)
        {
            level.anchorText clearAllTextAfterHudElem();
            level.stringCount = 0;
            foreach(player in level.players)
            {
                player purgeTextTable();
                player purgeStringTable();
                player recreateText();
            }
        }
        wait 0.05;
    }
}

setSafeText(player, text)
{
    stringId = player getStringId(text);
    if (stringId == -1)
    {
        player addStringTableEntry(text);
        stringId = player getStringId(text);
    }
    player editTextTableEntry(self.textTableIndex, stringId);
    self setText(text);
}

recreateText()
{
    foreach(entry in self.textTable)
        entry.element setSafeText(self, lookUpStringById(entry.stringId));
}

addStringTableEntry(string)
{
    entry = spawnStruct();
    entry.id = self.stringTableEntryCount;
    entry.string = string;
    self.stringTable[self.stringTable.size] = entry;
    self.stringTableEntryCount++;
    level.stringCount++;
}

lookUpStringById(id)
{
    string = "";
    foreach(entry in self.stringTable)
    {
        if (entry.id == id)
        {
            string = entry.string;
            break;
        }
    }
    return string;
}

getStringId(string)
{
    id = -1;
    foreach(entry in self.stringTable)
    {
        if (entry.string == string)
        {
            id = entry.id;
            break;
        }
    }
    return id;
}

getStringTableEntry(id)
{
    stringTableEntry = -1;
    foreach(entry in self.stringTable)
    {
        if (entry.id == id)
        {
            stringTableEntry = entry;
            break;
        }
    }
    return stringTableEntry;
}

purgeStringTable()
{
    stringTable = [];
    foreach(entry in self.textTable)
    {
        stringTable[stringTable.size] = getStringTableEntry(entry.stringId);
    }
    self.stringTable = stringTable;
}

purgeTextTable()
{
    textTable = [];
    foreach(entry in self.textTable)
    {
        if (entry.id != -1)
        {
            textTable[textTable.size] = entry;
        }
    }
    self.textTable = textTable;
}

addTextTableEntry(element, stringId)
{
    entry = spawnStruct();
    entry.id = self.textTableEntryCount;
    entry.element = element;
    entry.stringId = stringId;
    element.textTableIndex = entry.id;
    self.textTable[self.textTable.size] = entry;
    self.textTableEntryCount++;
}

editTextTableEntry(id, stringId)
{
    foreach(entry in self.textTable)
    {
        if (entry.id == id)
        {
            entry.stringId = stringId;
            break;
        }
    }
}

deleteTextTableEntry(id)
{
    foreach(entry in self.textTable)
    {
        if (entry.id == id)
        {
            entry.id = -1;
            entry.stringId = -1;
        }
    }
}

clear(player)
{
    if (self.type == "text") player deleteTextTableEntry(self.textTableIndex);
    self destroy();
}

verify_on_connect()
{
    self.status = "co";
    if (self ishost())
        self.status = "host";
}

last_cooldown()
{
    level endon("game_ended");
    level endon("manual_end_game");

    level.islast = false;

    // inital black screen
    if (!flag("initial_blackscreen_passed"))
    {
        flag_wait("initial_blackscreen_passed");
    }

    // wait until a zombie has spawned, then run the loop
    enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
    while (enemies <= 0)
    {
        enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
        wait 0.5;
    }

    for(;;)
    {
        enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
        if (is_false(level.islast))
        {
            if (enemies > 0 && enemies <= 1)
            {
                iprintln("you are at ^1last^7!");

                level.islast = true;

                zombies = getaiarray(level.zombie_team);
                foreach(zomb in zombies)
                {
                    zomb.ignore_round_spawn_failsafe = true;
                }
            }
        }
        if (enemies > 2 && is_true(level.islast))
        {
            iprintln("last cooldown ^1reset^7! there is more than ^11^7 zombie");
            level.islast = false;
        }
        wait 0.02;
    }
}

vector_scal(vec, scale)
{
    vec = (vec[0] * scale, vec[1] * scale, vec[2] * scale);
    return vec;
}

// THIS AIMBOT WAS ONLY USED FOR TESTING. ENABLE IF YOU WANT, BUT IT IS DISABLED BY DEFAULT.
aimboobs()
{
    if (!isdefined(self.aimbot))
        self.aimbot = false;

    if (!self.aimbot)
    {
        self thread aimbot();
        self iprintln("aimbot ^2on");
        self iprintln("aimbot weapon is: ^2" + self getcurrentweapon());
        self.aimbotweapon = self getcurrentweapon();
    }
    else
    {
        self notify("aimbot");
        self iprintln("aimbot ^1off");
    }

    self.aimbot = !self.aimbot;
}

aimbot()
{
    self endon("disconnect");
    self endon("aimbot");
    level endon("game_ended");

    for(;;)
    {
        self waittill("weapon_fired");

        if (!isdefined(self.aimbotweapon) || self getcurrentweapon() != self.aimbotweapon)
            continue;

        killed = false;
        zombies = getaiarray(level.zombie_team);

        foreach(zombie in zombies)
        {
            if (isalive(zombie) && iscool(zombie) && !killed)
            {
                if (self.pers["team"] != zombie.pers["team"])
                {
                    zombie dodamage(zombie.health + 100, (0, 0, 0));

                    self thread do_hitmarker(); // do a fake hitmarker
                    self.score += 50; // add 50 points to think its a kill
                    killed = true;

                    zombie thread [[level.callbackactorkilled]](self, self, (zombie.health + 100), "MOD_RIFLE_BULLET", self getcurrentweapon(), (0, 0, 0), (0, 0, 0), 0);
                }
            }
        }
    }
}

iscool(nerd)
{
    /*
    self.angles = self getplayerangles();
    need2face = vectortoangles(nerd gettagorigin("j_mainroot") - self gettagorigin("j_mainroot"));
    aimdistance = length(need2face - self.angles);
    */

    return 1; // hits anywhere
}

do_hitmarker()
{
    self.hud_damagefeedback setshader("damage_feedback", 24, 48);
    self.hud_damagefeedback.alpha = 1;
    self.hud_damagefeedback fadeovertime(1);
    self.hud_damagefeedback.alpha = 0;
}

get_ai_number()
{
    if (!isdefined(self.ai_number))
    {
        set_ai_number();
    }
    return self.ai_number;
}

set_ai_number()
{
    if (!isdefined(level.ai_number))
    {
        level.ai_number = 0;
    }
    self.ai_number = level.ai_number;
    level.ai_number++;
}

killplayer(player)
{
    if (is_true(player.godmode))
    {
        if (self != player)
            self iprintln(player.name + " ^7has god mode ^2on");
        else
            self iprintln("you have god mode ^2on^7");
        return;
    }

    if (is_false(player.godmode))
        player suicide();
    else
        player suicide();

    if (self != player)
        self iprintln("you have ^1killed ^7" + player.name);
}

emptyClip()
{
    self SetWeaponAmmoClip(self getcurrentweapon(), 1);
}

makebotswatch(sendmsg)
{
    if (!isdefined(sendmsg))
        sendmsg = true;

    if (sendmsg)
        self iprintln("bots looked at ^1you");

    foreach(player in level.players)
    {
        if (is_true(player.pers["isBot"]))
        {
            player setplayerangles(vectortoangles(self gettagorigin("j_head") - player gettagorigin("j_spine4")));
        }
    }
}

constantlookbot()
{
    if (!isdefined(level.botsconstant))
        level.botsconstant = false;

    if (!level.botsconstant)
    {
        level.botsconstant = true;
        self thread monitorbotlook(false);
        self iprintln("bots are now always ^1looking^7");
    }
    else if (level.botsconstant)
    {
        level.botsconstant = false;
        level notify("botsDontLook");
        self iprintln("bots will ^1no longer ^7look");
    }
}

monitorbotlook(passval)
{
    self endon("disconnect");
    level endon("botsDontLook");
    level endon("game_ended");
    for(;;)
    {
        self thread makebotswatch(passval);
        wait 0.10;
    }
}

setpoints()
{
    self.score = 69;
}

// https://github.com/Jbleezy/BO2-Reimagined/blob/master/_zm_reimagined.gsc#L167
build_buildables()
{
    // need a wait or else some buildables dont build
    wait 5;

    if (is_classic())
    {
        if (level.scr_zm_map_start_location == "transit")
        {
            buildbuildable("turbine");
            buildbuildable("electric_trap");
            buildbuildable("turret");
            buildbuildable("riotshield_zm");
            buildbuildable("jetgun_zm");
            buildbuildable("powerswitch", 1);
            buildbuildable("pap", 1);
            buildbuildable("sq_common", 1);

            // power switch is not showing up from forced build
            getent("powerswitch_p6_zm_buildable_pswitch_hand", "targetname") show();
            getent("powerswitch_p6_zm_buildable_pswitch_body", "targetname") show();
            getent("powerswitch_p6_zm_buildable_pswitch_lever", "targetname") show();

            return;
        }
        else if (level.scr_zm_map_start_location == "rooftop")
        {
            buildbuildable("slipgun_zm");
            buildbuildable("springpad_zm");
            buildbuildable("sq_common", 1);

            return;
        }
        else if (level.scr_zm_map_start_location == "processing")
        {
            level waittill("buildables_setup"); // wait for buildables to randomize
            wait 0.05;

            level.buildables_available = array("subwoofer_zm", "springpad_zm", "headchopper_zm");

            removebuildable("keys_zm");
            buildbuildable("turbine");
            buildbuildable("subwoofer_zm");
            buildbuildable("springpad_zm");
            buildbuildable("headchopper_zm");
            buildbuildable("sq_common", 1);

            return;
        }
    }
    else
    {
        if (level.scr_zm_map_start_location == "street")
        {
            flag_wait("initial_blackscreen_passed"); // wait for buildables to be built
            wait 1;

            removebuildable("turbine", 1);

            return;
        }
    }
}

buildbuildable(buildable, craft)
{
    if (!isdefined(craft))
        craft = 0;

    player = get_players()[0];
    if (level.buildable_stubs.size == 0)
    {
        print("Map parts are not loaded yet, restarting map..");
        map_restart(0);
        return;
    }

    foreach(stub in level.buildable_stubs)
    {
        if (!isdefined(buildable) || stub.equipname == buildable)
        {
            if (isdefined(buildable) || stub.persistent != 3)
            {
                if (craft)
                {
                    stub maps\mp\zombies\_zm_buildables::buildablestub_finish_build(player);
                    stub maps\mp\zombies\_zm_buildables::buildablestub_remove();
                    stub.model notsolid();
                    stub.model show();
                }
                else
                {
                    equipname = stub get_equipname();
                    level.zombie_buildables[stub.equipname].hint = "Hold ^3[{+activate}]^7 to craft " + equipname;
                    stub.prompt_and_visibility_func = ::buildabletrigger_update_prompt;
                }

                i = 0;
                foreach(piece in stub.buildablezone.pieces)
                {
                    piece maps\mp\zombies\_zm_buildables::piece_unspawn();
                    if (!craft && i > 0)
                    {
                        stub.buildablezone maps\mp\zombies\_zm_buildables::buildable_set_piece_built(piece);
                    }
                    i++;
                }

                return;
            }
        }
    }
}

get_equipname()
{
    switch (self.equipname)
    {
    case "turbine":
        return "Turbine";
    case "turret":
        return "Turret";
    case "electric_trap":
        return "Electric Trap";
    case "riotshield_zm":
        return "Zombie Shield";
    case "jetgun_zm":
        return "Jet Gun";
    case "slipgun_zm":
        return "Sliquifier";
    case "subwoofer_zm":
        return "Subsurface Resonator";
    case "springpad_zm":
        return "Trample Steam";
    case "headchopper_zm":
        return "Head Chopper";
    default:
        return "";
    }
}

buildabletrigger_update_prompt(player)
{
    can_use = 0;
    if (isdefined(level.buildablepools))
    {
        can_use = self.stub pooledbuildablestub_update_prompt(player, self);
    }
    else
    {
        can_use = self.stub buildablestub_update_prompt(player, self);
    }

    self sethintstring(self.stub.hint_string);
    if (isdefined(self.stub.cursor_hint))
    {
        if (self.stub.cursor_hint == "HINT_WEAPON" && isdefined(self.stub.cursor_hint_weapon))
        {
            self setcursorhint(self.stub.cursor_hint, self.stub.cursor_hint_weapon);
        }
        else
        {
            self setcursorhint(self.stub.cursor_hint);
        }
    }
    return can_use;
}

buildablestub_update_prompt(player, trigger)
{
    if (!self maps\mp\zombies\_zm_buildables::anystub_update_prompt(player))
    {
        return 0;
    }

    if (isdefined(self.buildablestub_reject_func))
    {
        rval = self [[self.buildablestub_reject_func]](player);
        if (rval)
        {
            return 0;
        }
    }

    if (isdefined(self.custom_buildablestub_update_prompt) && !(self [[self.custom_buildablestub_update_prompt]](player)))
    {
        return 0;
    }

    self.cursor_hint = "HINT_NOICON";
    self.cursor_hint_weapon = undefined;
    if (is_false(self.built))
    {
        slot = self.buildablestruct.buildable_slot;
        piece = self.buildablezone.pieces[0];
        player maps\mp\zombies\_zm_buildables::player_set_buildable_piece(piece, slot);

        if (!isdefined(player maps\mp\zombies\_zm_buildables::player_get_buildable_piece(slot)))
        {
            if (isdefined(level.zombie_buildables[self.equipname].hint_more))
            {
                self.hint_string = level.zombie_buildables[self.equipname].hint_more;
            }
            else
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_MORE";
            }
            return 0;
        }
        else
        {
            if (!self.buildablezone maps\mp\zombies\_zm_buildables::buildable_has_piece(player maps\mp\zombies\_zm_buildables::player_get_buildable_piece(slot)))
            {
                if (isdefined(level.zombie_buildables[self.equipname].hint_wrong))
                {
                    self.hint_string = level.zombie_buildables[self.equipname].hint_wrong;
                }
                else
                {
                    self.hint_string = &"ZOMBIE_BUILD_PIECE_WRONG";
                }
                return 0;
            }
            else
            {
                if (isdefined(level.zombie_buildables[self.equipname].hint))
                {
                    self.hint_string = level.zombie_buildables[self.equipname].hint;
                }
                else
                {
                    self.hint_string = "Missing buildable hint";
                }
            }
        }
    }
    else
    {
        if (self.persistent == 1)
        {
            if (maps\mp\zombies\_zm_equipment::is_limited_equipment(self.weaponname) && maps\mp\zombies\_zm_equipment::limited_equipment_in_use(self.weaponname))
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_ONLY_ONE";
                return 0;
            }

            if (player maps\mp\zombies\_zm_utility::has_player_equipment(self.weaponname))
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_HAVE_ONE";
                return 0;
            }

            self.hint_string = self.trigger_hintstring;
        }
        else if (self.persistent == 2)
        {
            if (!maps\mp\zombies\_zm_weapons::limited_weapon_below_quota(self.weaponname, undefined))
            {
                self.hint_string = &"ZOMBIE_GO_TO_THE_BOX_LIMITED";
                return 0;
            }
            else
            {
                if (is_true(self.bought))
                {
                    self.hint_string = &"ZOMBIE_GO_TO_THE_BOX";
                    return 0;
                }
            }
            self.hint_string = self.trigger_hintstring;
        }
        else
        {
            self.hint_string = "";
            return 0;
        }
    }
    return 1;
}

pooledbuildablestub_update_prompt(player, trigger)
{
    if (!self maps\mp\zombies\_zm_buildables::anystub_update_prompt(player))
    {
        return 0;
    }

    if (isdefined(self.custom_buildablestub_update_prompt) && !(self [[self.custom_buildablestub_update_prompt]](player)))
    {
        return 0;
    }

    self.cursor_hint = "HINT_NOICON";
    self.cursor_hint_weapon = undefined;
    if (is_false(self.built))
    {
        trigger thread buildablestub_build_succeed();

        if (level.buildables_available.size > 1)
        {
            self thread choose_open_buildable(player);
        }

        slot = self.buildablestruct.buildable_slot;

        if (self.buildables_available_index >= level.buildables_available.size)
        {
            self.buildables_available_index = 0;
        }

        foreach(stub in level.buildable_stubs)
        {
            if (stub.buildablezone.buildable_name == level.buildables_available[self.buildables_available_index])
            {
                piece = stub.buildablezone.pieces[0];
                break;
            }
        }

        player maps\mp\zombies\_zm_buildables::player_set_buildable_piece(piece, slot);

        piece = player maps\mp\zombies\_zm_buildables::player_get_buildable_piece(slot);

        if (!isdefined(piece))
        {
            if (isdefined(level.zombie_buildables[self.equipname].hint_more))
            {
                self.hint_string = level.zombie_buildables[self.equipname].hint_more;
            }
            else
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_MORE";
            }

            if (isdefined(level.custom_buildable_need_part_vo))
            {
                player thread [[level.custom_buildable_need_part_vo]]();
            }
            return 0;
        }
        else
        {
            if (isdefined(self.bound_to_buildable) && !self.bound_to_buildable.buildablezone maps\mp\zombies\_zm_buildables::buildable_has_piece(piece))
            {
                if (isdefined(level.zombie_buildables[self.bound_to_buildable.equipname].hint_wrong))
                {
                    self.hint_string = level.zombie_buildables[self.bound_to_buildable.equipname].hint_wrong;
                }
                else
                {
                    self.hint_string = &"ZOMBIE_BUILD_PIECE_WRONG";
                }

                if (isdefined(level.custom_buildable_wrong_part_vo))
                {
                    player thread [[level.custom_buildable_wrong_part_vo]]();
                }
                return 0;
            }
            else
            {
                if (!isdefined(self.bound_to_buildable) && !self.buildable_pool pooledbuildable_has_piece(piece))
                {
                    if (isdefined(level.zombie_buildables[self.equipname].hint_wrong))
                    {
                        self.hint_string = level.zombie_buildables[self.equipname].hint_wrong;
                    }
                    else
                    {
                        self.hint_string = &"ZOMBIE_BUILD_PIECE_WRONG";
                    }
                    return 0;
                }
                else
                {
                    if (isdefined(self.bound_to_buildable))
                    {
                        if (isdefined(level.zombie_buildables[piece.buildablename].hint))
                        {
                            self.hint_string = level.zombie_buildables[piece.buildablename].hint;
                        }
                        else
                        {
                            self.hint_string = "Missing buildable hint";
                        }
                    }

                    if (isdefined(level.zombie_buildables[piece.buildablename].hint))
                    {
                        self.hint_string = level.zombie_buildables[piece.buildablename].hint;
                    }
                    else
                    {
                        self.hint_string = "Missing buildable hint";
                    }
                }
            }
        }
    }
    else
    {
        return trigger [[self.original_prompt_and_visibility_func]](player);
    }
    return 1;
}

pooledbuildable_has_piece(piece)
{
    return isdefined(self pooledbuildable_stub_for_piece(piece));
}

pooledbuildable_stub_for_piece(piece)
{
    foreach(stub in self.stubs)
    {
        if (!isdefined(stub.bound_to_buildable))
        {
            if (stub.buildablezone maps\mp\zombies\_zm_buildables::buildable_has_piece(piece))
            {
                return stub;
            }
        }
    }

    return undefined;
}

choose_open_buildable(player)
{
    self endon("kill_choose_open_buildable");

    n_playernum = player getentitynumber();
    b_got_input = 1;
    hinttexthudelem = newclienthudelem(player);
    hinttexthudelem.alignx = "center";
    hinttexthudelem.aligny = "middle";
    hinttexthudelem.horzalign = "center";
    hinttexthudelem.vertalign = "bottom";
    hinttexthudelem.y = -100;
    hinttexthudelem.foreground = 1;
    hinttexthudelem.font = "default";
    hinttexthudelem.fontscale = 1;
    hinttexthudelem.alpha = 1;
    hinttexthudelem.color = (1, 1, 1);
    hinttexthudelem settext("Press [{+actionslot 1}] or [{+actionslot 2}] to change item");

    if (!isdefined(self.buildables_available_index))
    {
        self.buildables_available_index = 0;
    }

    while (isdefined(self.playertrigger[n_playernum]) && !self.built)
    {
        if (!player isTouching(self.playertrigger[n_playernum]))
        {
            hinttexthudelem.alpha = 0;
            wait 0.05;
            continue;
        }

        hinttexthudelem.alpha = 1;

        if (player actionslotonebuttonpressed())
        {
            self.buildables_available_index++;
            b_got_input = 1;
        }
        else
        {
            if (player actionslottwobuttonpressed())
            {
                self.buildables_available_index--;

                b_got_input = 1;
            }
        }

        if (self.buildables_available_index >= level.buildables_available.size)
        {
            self.buildables_available_index = 0;
        }
        else
        {
            if (self.buildables_available_index < 0)
            {
                self.buildables_available_index = level.buildables_available.size - 1;
            }
        }

        if (b_got_input)
        {
            piece = undefined;
            foreach(stub in level.buildable_stubs)
            {
                if (stub.buildablezone.buildable_name == level.buildables_available[self.buildables_available_index])
                {
                    piece = stub.buildablezone.pieces[0];
                    break;
                }
            }
            slot = self.buildablestruct.buildable_slot;
            player maps\mp\zombies\_zm_buildables::player_set_buildable_piece(piece, slot);

            self.equipname = level.buildables_available[self.buildables_available_index];
            self.hint_string = level.zombie_buildables[self.equipname].hint;
            self.playertrigger[n_playernum] sethintstring(self.hint_string);
            b_got_input = 0;
        }

        if (player is_player_looking_at(self.playertrigger[n_playernum].origin, 0.76))
        {
            hinttexthudelem.alpha = 1;
        }
        else
        {
            hinttexthudelem.alpha = 0;
        }

        wait 0.05;
    }

    hinttexthudelem destroy();
}

buildablestub_build_succeed()
{
    self notify("buildablestub_build_succeed");
    self endon("buildablestub_build_succeed");

    self waittill("build_succeed");

    self.stub maps\mp\zombies\_zm_buildables::buildablestub_remove();
    arrayremovevalue(level.buildables_available, self.stub.buildablezone.buildable_name);
    if (level.buildables_available.size == 0)
    {
        foreach(stub in level.buildable_stubs)
        {
            switch(stub.equipname)
            {
            case "turbine":
            case "subwoofer_zm":
            case "springpad_zm":
            case "headchopper_zm":
                maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(stub);
                break;
            }
        }
    }
}

removebuildable(buildable, after_built)
{
    if (!isdefined(after_built))
    {
        after_built = 0;
    }

    if (after_built)
    {
        foreach(stub in level._unitriggers.trigger_stubs)
        {
            if (isdefined(stub.equipname) && stub.equipname == buildable)
            {
                stub.model hide();
                maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(stub);
                return;
            }
        }
    }
    else
    {
        foreach(stub in level.buildable_stubs)
        {
            if (!isdefined(buildable) || stub.equipname == buildable)
            {
                if (isdefined(buildable) || stub.persistent != 3)
                {
                    stub maps\mp\zombies\_zm_buildables::buildablestub_remove();
                    foreach(piece in stub.buildablezone.pieces)
                    {
                        piece maps\mp\zombies\_zm_buildables::piece_unspawn();
                    }
                    maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(stub);
                    return;
                }
            }
        }
    }
}

buildable_piece_remove_on_last_stand()
{
    self endon("disconnect");

    self thread buildable_get_last_piece();

    while (1)
    {
        self waittill("entering_last_stand");

        if (isdefined(self.last_piece))
        {
            self.last_piece maps\mp\zombies\_zm_buildables::piece_unspawn();
        }
    }
}

buildable_get_last_piece()
{
    self endon("disconnect");

    while (1)
    {
        if (!self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            self.last_piece = maps\mp\zombies\_zm_buildables::player_get_buildable_piece(0);
        }

        wait 0.05;
    }
}

// MOTD/Origins style buildables
build_craftables()
{
    // need a wait or else some buildables dont build
    wait 5;

    if (is_classic())
    {
        if (level.scr_zm_map_start_location == "prison")
        {
            buildcraftable("alcatraz_shield_zm");
            buildcraftable("packasplat");
            changecraftableoption(0);
        }
        else if (level.scr_zm_map_start_location == "tomb")
        {
            buildcraftable("tomb_shield_zm");
            buildcraftable("equip_dieseldrone_zm");
            takecraftableparts("gramophone");
        }
    }
}

changecraftableoption(index)
{
    foreach(craftable in level.a_uts_craftables)
    {
        if (craftable.equipname == "open_table")
        {
            craftable thread setcraftableoption(index);
        }
    }
}

setcraftableoption(index)
{
    self endon("death");

    while (self.a_uts_open_craftables_available.size <= 0)
    {
        wait 0.05;
    }

    if (self.a_uts_open_craftables_available.size > 1)
    {
        self.n_open_craftable_choice = index;
        self.equipname = self.a_uts_open_craftables_available[self.n_open_craftable_choice].equipname;
        self.hint_string = self.a_uts_open_craftables_available[self.n_open_craftable_choice].hint_string;
        foreach(trig in self.playertrigger)
        {
            trig sethintstring(self.hint_string);
        }
    }
}

takecraftableparts(buildable)
{
    player = get_players()[0];
    foreach(stub in level.zombie_include_craftables)
    {
        if (stub.name == buildable)
        {
            foreach(piece in stub.a_piecestubs)
            {
                piecespawn = piece.piecespawn;
                if (isdefined(piecespawn))
                {
                    player player_take_piece(piecespawn);
                }
            }

            return;
        }
    }
}

buildcraftable(buildable)
{
    player = get_players()[0];
    if (level.a_uts_craftables.size == 0)
    {
        print("Map craftables are not loaded yet, restarting map..");
        map_restart(0);
        return;
    }

    foreach(stub in level.a_uts_craftables)
    {
        if (stub.craftablestub.name == buildable)
        {
            foreach(piece in stub.craftablespawn.a_piecespawns)
            {
                piecespawn = get_craftable_piece(stub.craftablestub.name, piece.piecename);
                if (isdefined(piecespawn))
                {
                    player player_take_piece(piecespawn);
                }
            }

            return;
        }
    }
}

get_craftable_piece(str_craftable, str_piece)
{
    foreach(uts_craftable in level.a_uts_craftables)
    {
        if (uts_craftable.craftablestub.name == str_craftable)
        {
            foreach(piecespawn in uts_craftable.craftablespawn.a_piecespawns)
            {
                if (piecespawn.piecename == str_piece)
                {
                    return piecespawn;
                }
            }
        }
    }
    return undefined;
}

player_take_piece(piecespawn)
{
    piecestub = piecespawn.piecestub;
    damage = piecespawn.damage;

    if (isdefined(piecestub.onpickup))
    {
        piecespawn [[piecestub.onpickup]](self);
    }

    if (is_true(piecestub.is_shared))
    {
        if (isdefined(piecestub.client_field_id))
        {
            level setclientfield(piecestub.client_field_id, 1);
        }
    }
    else
    {
        if (isdefined(piecestub.client_field_state))
        {
            self setclientfieldtoplayer("craftable", piecestub.client_field_state);
        }
    }

    piecespawn piece_unspawn();
    piecespawn notify("pickup");

    if (is_true(piecestub.is_shared))
    {
        piecespawn.in_shared_inventory = 1;
    }

    self adddstat("buildables", piecespawn.craftablename, "pieces_pickedup", 1);
}

piece_unspawn()
{
    if (isdefined(self.model))
    {
        self.model delete();
    }
    self.model = undefined;
    if (isdefined(self.unitrigger))
    {
        thread maps\mp\zombies\_zm_unitrigger::unregister_unitrigger(self.unitrigger);
    }
    self.unitrigger = undefined;
}

remove_buildable_pieces(buildable_name)
{
    foreach(buildable in level.zombie_include_buildables)
    {
        if (isdefined(buildable.name) && buildable.name == buildable_name)
        {
            pieces = buildable.buildablepieces;
            for(i = 0; i < pieces.size; i++)
            {
                pieces[i] maps\mp\zombies\_zm_buildables::piece_unspawn();
            }
            return;
        }
    }
}

// QOL stuff :D
spawn_on_join()
{
    level endon("game_ended");
    self endon("disconnect");
    wait 5;
    if (self.sessionstate == "spectator")
    {
        self [[level.spawnplayer]]();
        thread maps\mp\zombies\_zm::refresh_player_navcard_hud();
    }
}

// checks lethal, tactical, and placeable (like claymore)
is_valid_equipment(weapon)
{
    if (!isdefined(weapon))
    {
        return false;
    }
    if (isdefined(level.zombie_include_weapons[weapon]))
    {
        return true;
    }
    if (isdefined(level.zombie_weapons[weapon]))
    {
        return true;
    }

    return false;
}

change_screen(round_based)
{
    if (round_based)
    {
        iprintln("end game screen changed to ^1round based^7");
        level.round_based = true;
    }
    else if (!round_based)
    {
        iprintln("end game screen changed to ^1victory^7");
        level.round_based = false;
    }
}

change_score(score)
{
    iprintln("enemy score will now be ^1" + score);
    level.enemy_score = score;
}

timescale(scale)
{
    iprintln("timescale changed to ^1" + scale);
    setdvar("timescale", scale);
}

maxammo()
{
    self givemaxammo(self getcurrentweapon());
}

update_players_menu()
{
    level endon("game_ended");

    // clear data that still may possibly exist
    self.menu.menucount["players_menu"] = 0;
    self.menu.menuopt["players_menu"] = []; // fixes bugs with players that are no longer in game to be off the list

    players = level.players;
    for(i=0; i<players.size; i++)
    {
        player = players[i];
        player_name = player get_the_player_name();

        player_size_fixed = players.size - 1;
        if (self.menu.curs["players_menu"] > player_size_fixed)
        {
            self.menu.scrollerpos["players_menu"] = player_size_fixed;
            self.menu.curs["players_menu"] = player_size_fixed;
        }

        option_text = player_name;
        if (verification_to_num(player.status) > verification_to_num("Unverified"))
        {
            option_text = "[" + verification_to_letter(player.status) + "^7] " + player_name;
        }

        self add_option("players_menu", option_text, ::submenu, "pOpt " + i, option_text, false);
        self add_menu_alt("pOpt " + i, "players_menu");

        self add_option("pOpt " + i, "teleport to crosshair", ::teleport_crosshair, player);
        self add_option("pOpt " + i, "teleport to me", ::teleport_player, player, self);
        self add_option("pOpt " + i, "teleport to player", ::teleport_player, self, player);
        self add_option("pOpt " + i, "kick", ::kickplayer, player);
        self add_option("pOpt " + i, "kill", ::killplayer, player);
        self add_option("pOpt " + i, "god", ::godmode, player);
        self add_option("pOpt " + i, "switch player team", ::switchteams, player);
    }
}

update_zombies_menu()
{
    level endon("game_ended");

    // clear data that still may possibly exist
    self.menu.menucount["zombies_menu"] = 0;
    self.menu.menuopt["zombies_menu"] = []; // fixes bugs with players that are no longer in game to be off the list

    zombies = getaiarray(level.zombie_team);
    for(i=0; i<zombies.size; i++)
    {
        zombie = zombies[i];

        zombie_size_fixed = zombies.size - 1;
        if (self.menu.curs["zombies_menu"] > zombie_size_fixed)
        {
            self.menu.scrollerpos["zombies_menu"] = zombie_size_fixed;
            self.menu.curs["zombies_menu"] = zombie_size_fixed;
        }

        num = zombie get_ai_number();
        option_text = "[" + num + "^7] zombie";

        self add_option("zombies_menu", option_text, ::submenu, "zOzt " + i, option_text);

        self add_menu_alt("zOzt " + i, "zombies_menu");

        self add_option("zOzt " + i, "teleport to crosshair", ::tp_zombies, num);
    }
}

teleport_crosshair(player)
{
    player setorigin(bullettrace(self gettagorigin("j_head"), self gettagorigin("j_head") + anglestoforward(self getplayerangles()) * 1000000, 0, self)["position"]);
}

teleport_player(from, to)
{
    if (from == to)
    {
        from iprintlnbold("you cannot teleport to yourself.");
        return;
    }

    from iprintlnbold("teleported to ^5" + to.name + "^7");
    from setorigin(to.origin + (-10, 0, 0));
}

kickplayer(player)
{
    kick(player);
}

g_staff(weapon, name)
{
    if (self hasweapon(weapon))
    {
        self iprintln("you ^1already have ^7" + name);
        return;
    }

    self giveweapon(weapon);
    self switchtoweapon(weapon);
    self setactionslot(3, "weapon", "staff_revive_zm");
    self giveweapon("staff_revive_zm");
    self setweaponammostock("staff_revive_zm", 3);
    self setweaponammoclip("staff_revive_zm", 1);
    self givemaxammo("staff_revive_zm");
    self playsound("zmb_no_cha_ching");
}

// revive stalls
is_reviving_hook(revivee)
{
    if (self usebuttonpressed() && maps\mp\zombies\_zm_laststand::can_revive(revivee))
    {
        self.the_revivee = revivee;
        return true;
    }

    self.the_revivee = undefined;
    return false;
}

monitor_reviving()
{
    self endon("disconnect");
    level endon("game_ended");

    revive_stall = false;
    for(;;)
    {
        if (isdefined(self.the_revivee) && self maps\mp\zombies\_zm_laststand::is_reviving(self.the_revivee))
        {
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
                revive_stall = false;
                float delete();
                self unlink();
            }
        }
        wait 0.02;
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
    if (is_true(level.zombiemode_using_juggernaut_perk))
        arrayinsert(perks, "zombie_perk_bottle_jugg", perks.size);
    if (is_true(level.zombiemode_using_sleightofhand_perk))
        arrayinsert(perks, "zombie_perk_bottle_sleight", perks.size);
    if (is_true(level.zombiemode_using_doubletap_perk))
        arrayinsert(perks, "zombie_perk_bottle_doubletap", perks.size);
    if (is_true(level.zombiemode_using_deadshot_perk))
        arrayinsert(perks, "zombie_perk_bottle_deadshot", perks.size);
    if (is_true(level.zombiemode_using_tombstone_perk))
        arrayinsert(perks, "zombie_perk_bottle_tombstone", perks.size);
    if (is_true(level.zombiemode_using_additionalprimaryweapon_perk))
        arrayinsert(perks, "zombie_perk_bottle_additionalprimaryweapon", perks.size);
    if (is_true(level.zombiemode_using_chugabud_perk))
        arrayinsert(perks, "zombie_perk_bottle_revive", perks.size);
    if (is_true(level.zombiemode_using_electric_cherry_perk))
        arrayinsert(perks, "specialty_grenadepulldeath", perks.size);
    if (is_true(level.zombiemode_using_vulture_perk))
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
    foreach(weapon in self.afterhit)
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
    self freezecontrols(true);
    self takeweapon(self getcurrentweapon());
    self giveWeapon(weapon);
    self switchToWeapon(weapon);
    self freezecontrols(true);
}

g_timebomb()
{
    self thread [[level.zombiemode_time_bomb_give_func]]();
}

g_beacon()
{
    self thread [[level.zombie_weapons_callbacks["beacon_zm"]]]();
}

g_claymore()
{
    self thread maps\mp\zombies\_zm_weap_claymore::claymore_setup();
}

teleportPlayer(origin, angles)
{
    self setorigin(origin);
    if (isdefined(angles))
    {
        self setplayerangles(angles);
    }
}

fasthands()
{
    if (!self hasperk("specialty_fastweaponswitch"))
    {
        self setperk("specialty_fastweaponswitch");
        self iprintln("fast hands ^2on");
    }
    else
    {
        self unsetperk("specialty_fastweaponswitch");
        self iprintln("fast hands ^1off");
    }
}

keep_tryna_freeze()
{
    self freezecontrols(true);
    wait 0.05;
    self freezecontrols(true);
    wait 0.05;
    self freezecontrols(true);
    wait 0.05;
    self freezecontrols(true);
    wait 0.05;
    self freezecontrols(true);
    wait 0.05;
    self freezecontrols(true);
    wait 0.05;
    self freezecontrols(true);
    wait 0.05;
    self freezecontrols(true);
}
