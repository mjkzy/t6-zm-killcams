/*

	majority of the functions are here

*/

init_precache()
{
    precachestring(&"PLATFORM_PRESS_TO_SKIP");
    precachestring(&"PLATFORM_PRESS_TO_RESPAWN");
    precacheshader("white");
    precacheshader("zombies_rank_1");
    precacheshader("zombies_rank_2");
    precacheshader("zombies_rank_3");
    precacheshader("zombies_rank_4");
    precacheshader("zombies_rank_5");
    precacheshader("emblem_bg_default");
    precacheshader("damage_feedback");
    precacheshader( "hud_status_dead" );
    precacheshader("specialty_instakill_zombies");
    precacheshader("menu_lobby_icon_twitter");

    precacheitem( "zombie_knuckle_crack" );
    precacheitem( "zombie_perk_bottle_jugg" );
    precacheitem( "chalk_draw_zm" );
}

init_dvars()
{
    setdvar("bot_AllowMovement", 0);
    setdvar("bot_PressAttackBtn", 0);
    setdvar("bot_PressMeleeBtn", 0);
    setdvar("friendlyfire_enabled", 0);
    setdvar("g_friendlyfireDist", 0);
    setdvar("ui_friendlyfire", 1);
}

endgamewhenhit()
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
        if ((enemies < 1 || enemies == 1) && level.islast)
        {
            if (getDvar("g_ai") != 1)
                setDvar("g_ai", 1);

            level thread customendgame();

            // kill rest
            zombs = getaiarray( level.zombie_team );
            foreach (zomb in zombs)
                zombs dodamage(zombs[i].health * 5000, (0, 0, 0));
            break;
        }
        wait 0.05;
    }
}

// MP endgame + parts of end_game from _zm
customendgame()
{
    winner = level.last_attacker;

    if (game["state"] == "postgame" || level.gameEnded) return;
    if (isDefined(level.onEndGame)) [[level.onEndGame]](winner);

    visionSetNaked( "mpOutro", 2.0 );

    setMatchFlag( "enable_popups", 0 );
    setmatchflag( "cg_drawSpectatorMessages", 0 );
    setmatchflag( "game_ended", 1 );

    players = get_players();
    setmatchflag( "disableIngameMenu", 1 );
    foreach ( player in players )
    {
        player closemenu();
        player closeingamemenu();
        player EnableInvulnerability();
        if ( isdefined( player.revivetexthud) )
        {
            player.revivetexthud destroy();
        }
    }

    level.zombie_vars[ "zombie_powerup_insta_kill_time" ] = 0;
    level.zombie_vars[ "zombie_powerup_fire_sale_time" ] = 0;
    level.zombie_vars[ "zombie_powerup_point_doubler_time" ] = 0;

    game["state"] = "postgame";
    level.gameEndTime = getTime();
    level.gameEnded = true;
    SetDvar( "g_gameEnded", 1 );
    level.inGracePeriod = false;
    level notify ( "game_ended" );
    level.allowBattleChatter = true;
    maps\mp\gametypes_zm\_globallogic_audio::flushDialog();

    if ( !IsDefined( game["overtime_round"] ) || wasLastRound() ) // Want to treat all overtime rounds as a single round
    {
        game["roundsplayed"]++;
        game["roundwinner"][game["roundsplayed"]] = winner;

        if( level.teambased )
        {
            game["roundswon"][winner]++;
        }
    }

    if ( isdefined( winner ) && isdefined( level.teams[winner] ) )
    {
        level.finalKillCam_winner = winner;
    }
    else
    {
        level.finalKillCam_winner = "none";
    }

    level.finalKillCam_winnerPicked = true;

    setGameEndTime( 0 );

    maps\mp\gametypes_zm\_globallogic::updatePlacement();

    maps\mp\gametypes_zm\_globallogic::updateRankedMatch( winner );

    players = level.players;

    newTime = getTime();
    gameLength = getGameLength();

    SetMatchTalkFlag( "EveryoneHearsEveryone", 1 );

    bbGameOver = 0;
    if ( isOneRound() || wasLastRound() )
    {
        bbGameOver = 1;

        if ( level.teambased )
        {
            if ( winner == "tie" )
            {
                recordGameResult( "draw" );
            }
            else
            {
                recordGameResult( winner );
            }
        }
        else
        {
            if ( !isDefined( winner ) )
            {
                recordGameResult( "draw" );
            }
            else
            {
                recordGameResult( winner.team );
            }
        }
    }

    index = 0;
    while ( index < players.size )
    {
        player = players[index];
        player maps\mp\gametypes_zm\_globallogic_player::freezePlayerForRoundEnd();
        player thread roundEndDoF( 4.0 );

        // zombies think they are tough because we can't move at all
        player EnableInvulnerability();

        player maps\mp\gametypes_zm\_globallogic_ui::freeGameplayHudElems();

        player maps\mp\gametypes_zm\_weapons::updateWeaponTimings( newTime );

        player maps\mp\gametypes_zm\_globallogic::bbPlayerMatchEnd( gameLength, "", bbGameOver );

        if( isPregame() )
        {
            index++;
            continue;
        }

        if( level.rankedMatch || level.wagerMatch || level.leagueMatch )
        {
            if ( isDefined( player.setPromotion ) )
            {
                player setDStat( "AfterActionReportStats", "lobbyPopup", "promotion" );
            }
            else
            {
                player setDStat( "AfterActionReportStats", "lobbyPopup", "summary" );
            }
        }
        index++;
    }

    maps\mp\_music::setmusicstate( "SILENT" );

    thread maps\mp\_challenges::roundEnd( winner );

    if ( startNextRound( winner, " " ) )
    {
        return;
    }

    ///////////////////////////////////////////
    // After this the match is really ending //
    ///////////////////////////////////////////

    if ( !isOneRound() )
    {
        if ( isDefined( level.onRoundEndGame ) )
        {
            winner = [[level.onRoundEndGame]]( winner );
        }

        endReasonText = "";
    }

    skillUpdate( winner, level.teamBased );
    recordLeagueWinner( winner );

    maps\mp\gametypes_zm\_globallogic::setTopPlayerStats();
    thread maps\mp\_challenges::gameEnd( winner );

    if ( ( !isDefined( level.skipGameEnd ) || !level.skipGameEnd ) && IsDefined( winner ) )
    {
        displayGameEnd( winner.team, endReasonText );
        //maps/mp/gametypes_zm/_globallogic::displayGameEnd(winner, "");
    }

    stopallrumbles();
    level.zombie_vars[ "zombie_powerup_insta_kill_time" ] = 0;
    level.zombie_vars[ "zombie_powerup_fire_sale_time" ] = 0;
    level.zombie_vars[ "zombie_powerup_point_doubler_time" ] = 0;
    setmatchflag( "disableIngameMenu", 1 );

    // load killcam here.
    postRoundFinalKillcam(); // call killcam here?
    while (level.infinalkillcam == 1)
    {
        wait 0.05;
    }

    level.intermission = true;

    //regain players array since some might've disconnected during the wait above
    players = level.players;
    for ( index = 0; index < players.size; index++ )
    {
        player = players[index];
        player closeMenu();
        player closeInGameMenu();
    }

    if (level.script == "zm_transit" || level.script == "zm_prison" || level.script == "zm_buried")
    {
        exitlevel(false);
    }

    // custom stuff from zm::endgame()
    // we need to spawn in the player and set them to playing
    players = get_players();
    foreach ( player in players )
    {
        if ( isdefined( player.sessionstate ) && player.sessionstate == "spectator" || player.sessionstate == "dead" )
        {
            // successfully disposes killcam & respawns player
            player thread after_killcam();
        }
    }

    wait 5;
    level notify ("sfade");
    level notify("stop_intermission");
    level notify("exitLevelcalled");

    if ( !isDefined( level.skipGameEnd ) || !level.skipGameEnd )
        wait 5.0;

    exitlevel( 0 );
}

after_killcam()
{
    self overlay(false);
    self takeallweapons();
    self [[ level.spawnplayer ]]();
}

open_seseme()
{
    flag_wait( "initial_blackscreen_passed" );
    setdvar("zombie_unlock_all", 1);
    flag_set("power_on");
    players = get_players();
    zombie_doors = getentarray("zombie_door", "targetname");
    for(i = 0; i < zombie_doors.size; i++)
    {
        zombie_doors[i] notify("trigger");
        if(is_true(zombie_doors[i].power_door_ignore_flag_wait))
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
    self.hud_damagefeedback = newdamageindicatorhudelem( self );
    self.hud_damagefeedback.horzalign = "center";
    self.hud_damagefeedback.vertalign = "middle";
    self.hud_damagefeedback.x = -12;
    self.hud_damagefeedback.y = -12;
    self.hud_damagefeedback.alpha = 0;
    self.hud_damagefeedback.archived = 1;
    self.hud_damagefeedback.color = ( 1, 1, 1 );
    self.hud_damagefeedback setshader( "damage_feedback", 24, 48 );
    self.hitsoundtracker = 1;
    self.hud_damagefeedback_red = newdamageindicatorhudelem( self );
    self.hud_damagefeedback_red.horzalign = "center";
    self.hud_damagefeedback_red.vertalign = "middle";
    self.hud_damagefeedback_red.x = -12;
    self.hud_damagefeedback_red.y = -12;
    self.hud_damagefeedback_red.alpha = 0;
    self.hud_damagefeedback_red.archived = 1;
    self.hud_damagefeedback_red.color = ( 1, 0, 0 );
    self.hud_damagefeedback_red setshader( "damage_feedback", 24, 48 );
}

updatedamagefeedback( mod, inflictor, death ) //checked matches cerberus output
{
    if (!isplayer(self) || isDefined(self.disable_hitmarkers)) return;
    if (isDefined(mod) && mod != "MOD_CRUSH" && mod != "MOD_GRENADE_SPLASH" && mod != "MOD_HIT_BY_OBJECT")
    {
        if (isDefined(inflictor))
        {
            self playlocalsound("mpl_hit_alert");
        }
        self.hud_damagefeedback setshader("damage_feedback", 24, 48);
        self.hud_damagefeedback.alpha = 1;
        self.hud_damagefeedback fadeovertime(1);
        self.hud_damagefeedback.alpha = 0;
    }
    return 1;
}

displayGameEnd( winner, endReasonText )
{
    foreach (player in level.players)
    {
        player thread [[level.onTeamOutcomeNotify]]( winner, false, endReasonText );
        player setClientUIVisibilityFlag( "hud_visible", 0 );
        player setClientUIVisibilityFlag( "g_compassShowEnemies", 0 );
    }

    roundEndWait( level.postRoundTime, true );
}

teamoutcomenotify( winner, isround, endreasontext )
{
    self endon( "disconnect" );
    self notify( "reset_outcome" );
    team = level.last_attacker.team;

    while ( self.doingnotify )
    {
        wait 0.05;
    }
    self endon( "reset_outcome" );
    headerfont = "extrabig";
    font = "default";
    if ( self issplitscreen() )
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
    outcometitle = createfontstring( headerfont, titlesize );
    outcometitle setpoint( "TOP", undefined, 0, 30 );
    outcometitle.glowalpha = 1;
    outcometitle.hidewheninmenu = 0;
    outcometitle.archived = 0;
    outcometitle.immunetodemogamehudsettings = 1;
    outcometitle.immunetodemofreecamera = 1;
    outcometext = createfontstring( font, 2 );
    outcometext setparent( outcometitle );
    outcometext setpoint( "TOP", "BOTTOM", 0, 0 );
    outcometext.glowalpha = 1;
    outcometext.hidewheninmenu = 0;
    outcometext.archived = 0;
    outcometext.immunetodemogamehudsettings = 1;
    outcometext.immunetodemofreecamera = 1;

    outcometitlenum = randomintrange(0, 3);
    if (outcometitlenum < 2)
        outcometitle settext( game[ "strings" ][ "victory" ] );
    else
        outcometitle settext( game[ "strings" ][ "round_win" ] );
    outcometitle.color = ( 0.42, 0.68, 0.46 );
    outcometext settext( "Zombies Eliminated" );
    outcometitle setcod7decodefx( 200, duration, 600 );
    outcometext setpulsefx( 100, duration, 1000 );
    iconspacing = 100;
    currentx = ( (1 * -1) * iconspacing ) / 2;
    teamicons = [];
    teamicons[ team ] = createicon( determineTeamLogo(), iconsize, iconsize );
    teamicons[ team ] setparent( outcometext );
    teamicons[ team ] setpoint( "TOP", "BOTTOM", currentx, spacing );
    teamicons[ team ].hidewheninmenu = 0;
    teamicons[ team ].archived = 0;
    teamicons[ team ].alpha = 0;
    teamicons[ team ].immunetodemogamehudsettings = 1;
    teamicons[ team ].immunetodemofreecamera = 1;
    teamicons[ team ] fadeovertime( 0.5 );
    teamicons[ team ].alpha = 1;
    currentx += iconspacing;
    foreach ( enemyteam in level.teams )
    {
        if ( enemyteam != team )
        {
            teamicons[ enemyteam ] = createicon( "hud_status_dead", iconsize, iconsize );
            teamicons[ enemyteam ] setparent( outcometext );
            teamicons[ enemyteam ] setpoint( "TOP", "BOTTOM", currentx, spacing );
            teamicons[ enemyteam ].hidewheninmenu = 0;
            teamicons[ enemyteam ].archived = 0;
            teamicons[ enemyteam ].immunetodemogamehudsettings = 1;
            teamicons[ enemyteam ].immunetodemofreecamera = 1;
            teamicons[ enemyteam ] fadeovertime( 0.5 );
            teamicons[ enemyteam ].alpha = 1;
            currentx += iconspacing;
        }
    }
    teamscores = [];
    teamscores[ team ] = createfontstring( font, titlesize );
    teamscores[ team ] setparent( teamicons[ team ] );
    teamscores[ team ] setpoint( "TOP", "BOTTOM", 0, spacing );
    teamscores[ team ].glowalpha = 1;
    teamscores[ team ] setvalue( randomintrange(1, 3) );
    teamscores[ team ].hidewheninmenu = 0;
    teamscores[ team ].archived = 0;
    teamscores[ team ].immunetodemogamehudsettings = 1;
    teamscores[ team ].immunetodemofreecamera = 1;
    teamscores[ team ] setpulsefx( 100, duration, 1000 );

    foreach ( enemyteam in level.teams )
    {
        if ( enemyteam != team )
        {
            teamscores[ enemyteam ] = createfontstring( headerfont, titlesize );
            teamscores[ enemyteam ] setparent( teamicons[ enemyteam ] );
            teamscores[ enemyteam ] setpoint( "TOP", "BOTTOM", 0, spacing );
            teamscores[ enemyteam ].glowalpha = 1;
            teamscores[ enemyteam ] setvalue( randomintrange(1, 3) );
            teamscores[ enemyteam ].hidewheninmenu = 0;
            teamscores[ enemyteam ].archived = 0;
            teamscores[ enemyteam ].immunetodemogamehudsettings = 1;
            teamscores[ enemyteam ].immunetodemofreecamera = 1;
            teamscores[ enemyteam ] setpulsefx( 100, duration, 1000 );
        }
    }
    font = "objective";
    matchbonus = createfontstring( font, 2 );
    matchbonus setparent( outcometext );
    matchbonus setpoint( "TOP", "BOTTOM", 0, iconsize + ( spacing * 3 ) + teamscores[ team ].height );
    matchbonus.glowalpha = 1;
    matchbonus.hidewheninmenu = 0;
    matchbonus.archived = 0;
    matchbonus.label = game[ "strings" ][ "match_bonus" ];
    matchbonus setvalue( randomintrange(2000, 3500) );
    self thread maps\mp\gametypes_zm\_hud_message::resetoutcomenotify( teamicons, teamscores, outcometitle, outcometext );
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
        if (isdefined(level.should_use_cia) && level.should_use_cia)
            return game["icons"]["axis"];
        else
            return game["icons"]["allies"];
    }
    else if (classic)
    {
        rank = "zombies_rank_" + randomintrange(0, 5);
        print(rank);
        return rank;
    }

    if (standard)
        return "hud_status_dead";

    return "hud_status_dead";
}

round_spawning_override() //checked changed to match cerberus output
{
    level endon( "intermission" );
    level endon( "end_of_round" );
    level endon( "restart_round" );
    if ( level.intermission )
    {
        return;
    }
    if ( level.zombie_spawn_locations.size < 1 )
    {
        return;
    }
    ai_calculate_health( level.round_number );
    count = 0;
    players = get_players();
    for ( i = 0; i < players.size; i++ )
    {
        players[ i ].zombification_time = 0;
    }
    max = level.zombie_vars[ "zombie_max_ai" ];
    multiplier = level.round_number / 5;
    if ( multiplier < 1 )
    {
        multiplier = 1;
    }
    if ( level.round_number >= 10 )
    {
        multiplier *= level.round_number * 0.15;
    }
    player_num = get_players().size;
    if ( player_num == 1 )
    {
        max += int( 0.5 * level.zombie_vars[ "zombie_ai_per_player" ] * multiplier );
    }
    else
    {
        max += int( ( player_num - 1 ) * level.zombie_vars[ "zombie_ai_per_player" ] * multiplier );
    }
    if ( !isDefined( level.max_zombie_func ) )
    {
        level.max_zombie_func = maps\mp\zombies\_zm::default_max_zombie_func;
    }
    if ( isDefined( level.kill_counter_hud ) && level.zombie_total > 0 )
    {
        level.zombie_total = [[ level.max_zombie_func ]]( max );
        level notify( "zombie_total_set" );
    }
    if ( isDefined( level.zombie_total_set_func ) )
    {
        level thread [[ level.zombie_total_set_func ]]();
    }
    if ( level.round_number < 10 || level.speed_change_max > 0 )
    {
        level thread maps\mp\zombies\_zm::zombie_speed_up();
    }
    level.zombie_total = [[ level.max_zombie_func ]]( max );
    level notify( "zombie_total_set" );
    mixed_spawns = 0;
    old_spawn = undefined;
    while ( 1 )
    {
        while ( maps\mp\zombies\_zm_utility::get_current_zombie_count() >= level.zombie_ai_limit || level.zombie_total <= 0 )
        {
            wait 0.1;
        }
        while ( maps\mp\zombies\_zm_utility::get_current_actor_count() >= level.zombie_actor_limit )
        {
            maps\mp\zombies\_zm_utility::clear_all_corpses();
            wait 0.1;
        }
        flag_wait( "spawn_zombies" );
        while ( level.zombie_spawn_locations.size <= 0 )
        {
            wait 0.1;
        }
        maps\mp\zombies\_zm::run_custom_ai_spawn_checks();
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
        if ( isDefined( level.mixed_rounds_enabled ) && level.mixed_rounds_enabled == 1 )
        {
            spawn_dog = 0;
            if ( level.round_number > 30 )
            {
                if ( randomint( 100 ) < 3 )
                {
                    spawn_dog = 1;
                }
            }
            else if ( level.round_number > 25 && mixed_spawns < 3 )
            {
                if ( randomint( 100 ) < 2 )
                {
                    spawn_dog = 1;
                }
            }
            else if ( level.round_number > 20 && mixed_spawns < 2 )
            {
                if ( randomint( 100 ) < 2 )
                {
                    spawn_dog = 1;
                }
                break;
            }
            else if ( level.round_number > 15 && mixed_spawns < 1 )
            {
                if ( randomint( 100 ) < 1 )
                {
                    spawn_dog = 1;
                }
            }
            if ( spawn_dog )
            {
                keys = getarraykeys( level.zones );
                for ( i = 0; i < keys.size; i++ )
                {
                    if ( level.zones[ keys[ i ] ].is_occupied )
                    {
                        akeys = getarraykeys( level.zones[ keys[ i ] ].adjacent_zones );
                        k = 0;
                        for ( k = 0; k < akeys.size; k++ )
                        {
                            if ( level.zones[ akeys[ k ] ].is_active && !level.zones[ akeys[ k ] ].is_occupied && level.zones[ akeys[ k ] ].dog_locations.size > 0 )
                            {
                                maps/mp/zombies/_zm_ai_dogs::special_dog_spawn( undefined, 1 );
                                level.zombie_total--;

                                wait 0.05;
                            }
                        }
                    }
                }
            }
        }
        if ( isDefined( level.zombie_spawners ) )
        {
            if ( is_true( level.use_multiple_spawns ) )
            {
                if ( isDefined( spawn_point.script_int ) )
                {
                    if ( isDefined( level.zombie_spawn[ spawn_point.script_int ] ) && level.zombie_spawn[ spawn_point.script_int ].size )
                    {
                        spawner = random( level.zombie_spawn[ spawn_point.script_int ] );
                    }
                }
                else if ( isDefined( level.zones[ spawn_point.zone_name ].script_int ) && level.zones[ spawn_point.zone_name ].script_int )
                {
                    spawner = random( level.zombie_spawn[ level.zones[ spawn_point.zone_name ].script_int ] );
                }
                else if ( isDefined( level.spawner_int ) && isDefined( level.zombie_spawn[ level.spawner_int ].size ) && level.zombie_spawn[ level.spawner_int ].size )
                {
                    spawner = random( level.zombie_spawn[ level.spawner_int ] );
                }
                else
                {
                    spawner = random( level.zombie_spawners );
                }
            }
            else
            {
                spawner = random( level.zombie_spawners );
            }
            ai = maps\mp\zombies\_zm_utility::spawn_zombie( spawner, spawner.targetname, spawn_point );
        }
        if ( isDefined( ai ) )
        {
            level.zombie_total--;

            //ai thread round_spawn_failsafe();
            count++;
        }
        wait level.zombie_vars[ "zombie_spawn_delay" ];
        wait 0.05;
    }
}

spawnclient( timealreadypassed )
{
    pixbeginevent( "spawnClient" );
    if ( !self mayspawn() )
    {
        currentorigin = self.origin;
        currentangles = self.angles;
        self showspawnmessage();
        self thread [[ level.spawnspectator ]]( currentorigin + vectorScale( ( 0, 0, 1 ), 60 ), currentangles );
        pixendevent();
        return;
    }
    if ( self.waitingtospawn )
    {
        pixendevent();
        return;
    }
    self.waitingtospawn = 1;
    self.allowqueuespawn = undefined;
    self waitandspawnclient( timealreadypassed );
    if ( isDefined( self ) )
    {
        self.waitingtospawn = 0;
    }
    pixendevent();
}

waitandspawnclient( timealreadypassed )
{
    self endon( "disconnect" );
    self endon( "end_respawn" );
    level endon( "game_ended" );
    if ( !isDefined( timealreadypassed ) )
    {
        timealreadypassed = 0;
    }
    spawnedasspectator = 0;
    if ( is_true( self.teamkillpunish ) )
    {
        teamkilldelay = maps/mp/gametypes_zm/_globallogic_player::teamkilldelay();
        if ( teamkilldelay > timealreadypassed )
        {
            teamkilldelay -= timealreadypassed;
            timealreadypassed = 0;
        }
        else
        {
            timealreadypassed -= teamkilldelay;
            teamkilldelay = 0;
        }
        if ( teamkilldelay > 0 )
        {
            //setlowermessage( &"MP_FRIENDLY_FIRE_WILL_NOT", teamkilldelay );
            self thread respawn_asspectator( self.origin + vectorScale( ( 0, 0, 1 ), 60 ), self.angles );
            spawnedasspectator = 1;
            wait teamkilldelay;
        }
        self.teamkillpunish = 0;
    }
    if ( !isDefined( self.wavespawnindex ) && isDefined( level.waveplayerspawnindex[ self.team ] ) )
    {
        self.wavespawnindex = level.waveplayerspawnindex[ self.team ];
        level.waveplayerspawnindex[ self.team ]++;
    }
    timeuntilspawn = timeuntilspawn( 0 );
    if ( timeuntilspawn > timealreadypassed )
    {
        timeuntilspawn -= timealreadypassed;
        timealreadypassed = 0;
    }
    else
    {
        timealreadypassed -= timeuntilspawn;
        timeuntilspawn = 0;
    }
    if ( timeuntilspawn > 0 )
    {
        if ( level.playerqueuedrespawn )
        {
            //setlowermessage( game[ "strings" ][ "you_will_spawn" ], timeuntilspawn );
        }
        else
        {
            //setlowermessage( game[ "strings" ][ "waiting_to_spawn" ], timeuntilspawn );
        }
        if ( !spawnedasspectator )
        {
            spawnorigin = self.origin + vectorScale( ( 0, 0, 1 ), 60 );
            spawnangles = self.angles;
            if ( isDefined( level.useintermissionpointsonwavespawn ) && [[ level.useintermissionpointsonwavespawn ]]() == 1 )
            {
                spawnpoint = maps/mp/gametypes_zm/_spawnlogic::getrandomintermissionpoint();
                if ( isDefined( spawnpoint ) )
                {
                    spawnorigin = spawnpoint.origin;
                    spawnangles = spawnpoint.angles;
                }
            }
            self thread respawn_asspectator( spawnorigin, spawnangles );
        }
        spawnedasspectator = 1;
        self maps/mp/gametypes_zm/_globallogic_utils::waitfortimeornotify( timeuntilspawn, "force_spawn" );
        self notify( "stop_wait_safe_spawn_button" );
    }
    if ( isDefined( level.gametypespawnwaiter ) )
    {
        if ( !spawnedasspectator )
        {
            self thread respawn_asspectator( self.origin + vectorScale( ( 0, 0, 1 ), 60 ), self.angles );
        }
        spawnedasspectator = 1;
        if ( !( self [[ level.gametypespawnwaiter ]]() ) )
        {
            self.waitingtospawn = 0;
            self clearlowermessage();
            self.wavespawnindex = undefined;
            self.respawntimerstarttime = undefined;
            return;
        }
    }
    wavebased = level.waverespawndelay > 0;
    if ( flag( "start_zombie_round_logic") )
    {
        //setlowermessage( game[ "strings" ][ "press_to_spawn" ] );
        if ( !spawnedasspectator )
        {
            self thread respawn_asspectator( self.origin + vectorScale( ( 0, 0, 1 ), 60 ), self.angles );
        }
        spawnedasspectator = 1;
        self waitrespawnorsafespawnbutton();
    }
    self.waitingtospawn = 0;
    self clearlowermessage();
    self.wavespawnindex = undefined;
    self.respawntimerstarttime = undefined;
    self thread [[ level.spawnplayer ]]();
}

waitrespawnorsafespawnbutton()
{
    self endon( "disconnect" );
    self endon( "end_respawn" );
    while ( 1 )
    {
        if ( self usebuttonpressed() )
        {
            return;
        }
        wait 0.05;
    }
}

spawnqueuedclient( dead_player_team, killer )
{
    maps/mp/gametypes_zm/_globallogic_utils::waittillslowprocessallowed();
    spawn_team = undefined;
    if ( isDefined( killer ) && isDefined( killer.team ) && isDefined( level.teams[ killer.team ] ) )
    {
        spawn_team = killer.team;
    }
    if ( isDefined( spawn_team ) )
    {
        spawnqueuedclientonteam( spawn_team );
        return;
    }
    foreach ( team in level.teams )
    {
        if ( team == dead_player_team )
        {
        }
        else
        {
            spawnqueuedclientonteam( team );
        }
    }
}

spawnqueuedclientonteam( team )
{
    player_to_spawn = undefined;
    for ( i = 0; i < level.deadplayers[ team ].size; i++ )
    {
        player = level.deadplayers[ team ][ i ];
        if ( player.waitingtospawn )
        {
        }
        else
        {
            player_to_spawn = player;
            break;
        }
    }
    if ( isDefined( player_to_spawn ) )
    {
        player_to_spawn.allowqueuespawn = 1;
        player_to_spawn maps/mp/gametypes_zm/_globallogic_ui::closemenus();
        player_to_spawn thread [[ level.spawnclient ]]();
    }
}

mayspawn() //checked partially changed to match cerberus output changed at own discretion
{
    if ( isDefined( level.mayspawn ) && !self [[ level.mayspawn ]]() )
    {
        return 0;
    }
    if ( level.inovertime )
    {
        return 0;
    }
    if ( level.playerqueuedrespawn && !isDefined( self.allowqueuespawn ) && !level.ingraceperiod && !level.usestartspawns )
    {
        return 0;
    }
    if ( level.numlives )
    {
        if ( level.teambased )
        {
            gamehasstarted = allteamshaveexisted();
        }
        else if ( level.maxplayercount > 1 || !isoneround() && !isfirstround() )
        {
            gamehasstarted = 1;
        }
        else
        {
            gamehasstarted = 0;
        }
        if ( !self.pers[ "lives" ] )
        {
            return 0;
        }
        else if ( gamehasstarted )
        {
            if ( !level.ingraceperiod && !self.hasspawned && !level.wagermatch )
            {
                return 0;
            }
        }
    }
    return 1;
}

spawnplayer() //checked matches cerberus output dvars taken from beta dump
{
    pixbeginevent( "spawnPlayer_preUTS" );
    self endon( "disconnect" );
    self endon( "joined_spectators" );
    self notify( "spawned" );
    level notify( "player_spawned" );
    self notify( "end_respawn", "spawnplayer" );
    self setspawnvariables();
    if ( !self.hasspawned )
    {
        self.underscorechance = 70;
        self thread maps/mp/gametypes_zm/_globallogic_audio::sndstartmusicsystem();
    }
    if ( level.teambased )
    {
        self.sessionteam = self.team;
    }
    else
    {
        self.sessionteam = "none";
        self.ffateam = self.team;
    }
    hadspawned = self.hasspawned;
    self.sessionstate = "playing";
    self.spectatorclient = -1;
    self.killcamentity = -1;
    self.archivetime = 0;
    self.psoffsettime = 0;
    self.statusicon = "";
    self.damagedplayers = [];
    if ( getDvarInt( "scr_csmode" ) > 0 )
    {
        self.maxhealth = getDvarInt( "scr_csmode" );
    }
    else
    {
        self.maxhealth = level.playermaxhealth;
    }
    self.health = self.maxhealth;
    self.friendlydamage = undefined;
    self.hasspawned = 1;
    self.spawntime = getTime();
    self.afk = 0;
    if ( self.pers[ "lives" ] && !isDefined( level.takelivesondeath ) || level.takelivesondeath == 0 )
    {
        self.pers[ "lives" ]--;
        if ( self.pers[ "lives" ] == 0 )
        {
            level notify( "player_eliminated" );
            self notify( "player_eliminated" );
        }
    }
    self.laststand = undefined;
    self.revivingteammate = 0;
    self.burning = undefined;
    self.nextkillstreakfree = undefined;
    self.activeuavs = 0;
    self.activecounteruavs = 0;
    self.activesatellites = 0;
    self.deathmachinekills = 0;
    self.disabledweapon = 0;
    self resetusability();
    self maps/mp/gametypes_zm/_globallogic_player::resetattackerlist();
    self.diedonvehicle = undefined;
    if ( !self.wasaliveatmatchstart )
    {
        if ( level.ingraceperiod || maps/mp/gametypes_zm/_globallogic_utils::gettimepassed() < 20000 )
        {
            self.wasaliveatmatchstart = 1;
        }
    }
    self setdepthoffield( 0, 0, 512, 512, 4, 0 );
    self resetfov();
    pixbeginevent( "onSpawnPlayer" );
    if ( isDefined( level.onspawnplayerunified ) )
    {
        self [[ level.onspawnplayerunified ]]();
    }
    else
    {
        self [[ level.onspawnplayer ]]( 0 );
    }
    if ( isDefined( level.playerspawnedcb ) )
    {
        self [[ level.playerspawnedcb ]]();
    }
    pixendevent();
    pixendevent();
    level thread maps/mp/gametypes_zm/_globallogic::updateteamstatus();
    pixbeginevent( "spawnPlayer_postUTS" );
    self thread stoppoisoningandflareonspawn();
    self stopburning();
    self giveloadoutlevelspecific( self.team, self.class );
    if ( level.inprematchperiod )
    {
        self freeze_player_controls( 1 );
        team = self.pers[ "team" ];
        if ( isDefined( self.pers[ "music" ].spawn ) && self.pers[ "music" ].spawn == 0 )
        {
            if ( level.wagermatch )
            {
                music = "SPAWN_WAGER";
            }
            else
            {
                music = game[ "music" ][ "spawn_" + team ];
            }
            self thread maps/mp/gametypes_zm/_globallogic_audio::set_music_on_player( music, 0, 0 );
            self.pers[ "music" ].spawn = 1;
        }
        if ( level.splitscreen )
        {
            if ( isDefined( level.playedstartingmusic ) )
            {
                music = undefined;
            }
            else
            {
                level.playedstartingmusic = 1;
            }
        }
        if ( !isDefined( level.disableprematchmessages ) || level.disableprematchmessages == 0 )
        {
            thread maps/mp/gametypes_zm/_hud_message::showinitialfactionpopup( team );
            hintmessage = getobjectivehinttext( self.pers[ "team" ] );
            if ( isDefined( hintmessage ) )
            {
                self thread maps/mp/gametypes_zm/_hud_message::hintmessage( hintmessage );
            }
            if ( isDefined( game[ "dialog" ][ "gametype" ] ) && !level.splitscreen || self == level.players[ 0 ] )
            {
                if ( !isDefined( level.infinalfight ) || !level.infinalfight )
                {
                    if ( level.hardcoremode )
                    {
                        self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "gametype_hardcore" );
                    }
                    else
                    {
                        self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "gametype" );
                    }
                }
            }
            if ( team == game[ "attackers" ] )
            {
                self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "offense_obj", "introboost" );
            }
            else
            {
                self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "defense_obj", "introboost" );
            }
        }
    }
    else
    {
        self freeze_player_controls( 0 );
        self enableweapons();
        if ( !hadspawned && game[ "state" ] == "playing" )
        {
            //pixbeginevent( "sound" );
            team = self.team;
            if ( isDefined( self.pers[ "music" ].spawn ) && self.pers[ "music" ].spawn == 0 )
            {
                self thread maps/mp/gametypes_zm/_globallogic_audio::set_music_on_player( "SPAWN_SHORT", 0, 0 );
                self.pers[ "music" ].spawn = 1;
            }
            if ( level.splitscreen )
            {
                if ( isDefined( level.playedstartingmusic ) )
                {
                    music = undefined;
                }
                else
                {
                    level.playedstartingmusic = 1;
                }
            }
            if ( !isDefined( level.disableprematchmessages ) || level.disableprematchmessages == 0 )
            {
                thread maps/mp/gametypes_zm/_hud_message::showinitialfactionpopup( team );
                hintmessage = getobjectivehinttext( self.pers[ "team" ] );
                if ( isDefined( hintmessage ) )
                {
                    self thread maps/mp/gametypes_zm/_hud_message::hintmessage( hintmessage );
                }
                if ( isDefined( game[ "dialog" ][ "gametype" ] ) || !level.splitscreen && self == level.players[ 0 ] )
                {
                    if ( !isDefined( level.infinalfight ) || !level.infinalfight )
                    {
                        if ( level.hardcoremode )
                        {
                            self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "gametype_hardcore" );
                        }
                        else
                        {
                            self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "gametype" );
                        }
                    }
                }
                if ( team == game[ "attackers" ] )
                {
                    self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "offense_obj", "introboost" );
                }
                else
                {
                    self maps/mp/gametypes_zm/_globallogic_audio::leaderdialogonplayer( "defense_obj", "introboost" );
                }
            }
            pixendevent();
        }
    }
    if ( getDvar( "scr_showperksonspawn" ) == "" )
    {
        setdvar( "scr_showperksonspawn", "0" );
    }
    if ( level.hardcoremode )
    {
        setdvar( "scr_showperksonspawn", "0" );
    }
    if ( !level.splitscreen && getDvarInt( "scr_showperksonspawn" ) == 1 && game[ "state" ] != "postgame" )
    {
        pixbeginevent( "showperksonspawn" );
        if ( level.perksenabled == 1 )
        {
            self maps/mp/gametypes_zm/_hud_util::showperks();
        }
        self thread maps/mp/gametypes_zm/_globallogic_ui::hideloadoutaftertime( 3 );
        self thread maps/mp/gametypes_zm/_globallogic_ui::hideloadoutondeath();
        pixendevent();
    }
    if ( isDefined( self.pers[ "momentum" ] ) )
    {
        self.momentum = self.pers[ "momentum" ];
    }
    pixendevent();
    waittillframeend;
    self notify( "spawned_player" );
    self logstring( "S " + self.origin[ 0 ] + " " + self.origin[ 1 ] + " " + self.origin[ 2 ] );
    setdvar( "scr_selecting_location", "" );
    self maps/mp/zombies/_zm_perks::perk_set_max_health_if_jugg( "health_reboot", 1, 0 );
    if ( game[ "state" ] == "postgame" )
    {
        self maps/mp/gametypes_zm/_globallogic_player::freezeplayerforroundend();
    }
}

spawnspectator( origin, angles ) //checked matches cerberus output
{
    self notify( "spawned" );
    self notify( "end_respawn", "spawnspectator" );
    in_spawnspectator( origin, angles );
}

respawn_asspectator( origin, angles ) //checked matches cerberus output
{
    in_spawnspectator( origin, angles );
}

in_spawnspectator( origin, angles ) //checked matches cerberus output
{
    pixmarker( "BEGIN: in_spawnSpectator" );
    self setspawnvariables();
    if ( self.pers[ "team" ] == "spectator" )
    {
        self clearlowermessage();
    }
    self.sessionstate = "spectator";
    self.spectatorclient = -1;
    self.killcamentity = -1;
    self.archivetime = 0;
    self.psoffsettime = 0;
    self.friendlydamage = undefined;
    if ( self.pers[ "team" ] == "spectator" )
    {
        self.statusicon = "";
    }
    else
    {
        self.statusicon = "hud_status_dead";
    }
    maps/mp/gametypes_zm/_spectating::setspectatepermissionsformachine();
    [[ level.onspawnspectator ]]( origin, angles );
    if ( level.teambased && !level.splitscreen )
    {
        self thread spectatorthirdpersonness();
    }
    level thread maps/mp/gametypes_zm/_globallogic::updateteamstatus();
    pixmarker( "END: in_spawnSpectator" );
}

do_hitmarker(mod, hitloc, hitorig, player, damage)
{
    if (player != self)
    {
        player thread updatedamagefeedback(mod, player, 0);
        player.points += 10;
    }
    return 1;
}

do_hitmarker_death()
{
    if (self.attacker != self)
    {
        self.attacker thread updatedamagefeedback(self.damagemod, self.attacker, 1);
    }
    return 1;
}

drawZombiesCounter()
{
    level endon("endZmCounter");
    level.zombiesCounter = createServerFontString("hudsmall", 1.5);
    level.zombiesCounter setPoint("CENTER", "CENTER", "CENTER", 210);
    level.zombiesCounter.archived = 0;
    level.zombiesCounter.hideWhenInMenu = true;
    level.zombiesCounter thread waittillEnd();
    for(;;)
    {
        enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
        if ( enemies == 0 )
            level.zombiesCounter.label = &"Zombies: ^1";
        else if ( enemies <= 3 )
            level.zombiesCounter.label = &"Zombies: ^3";
        else if ( enemies != 0 )
            level.zombiesCounter.label = &"Zombies: ^2";
        level.zombiesCounter setValue( enemies );
        wait 0.05;
    }
}

waittillEnd()
{
    level waittill("game_ended");
    self Destroy();
}

/*
ok
*/

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
    foreach (weapon in self.allWeaps)
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

saveandload(announce)
{
    if (!isDefined(announce))
        announce = true;

    if (!self.snl)
    {
        if (announce) self iprintln("save and load ^2on");
        self thread monitorsnl();
        self.snl = 1;
    }
    else
    {
        if (announce) self iprintln("save and load ^1off");
        self.snl = 0;
        self notify("SaveandLoad");
    }
}

monitorsnl()
{
    self endon("disconnect");
    self endon("SaveandLoad");
    level endon("game_ended");

    load = 0;
    for(;;)
    {
        if (self actionslottwobuttonpressed() && self GetStance() == "crouch")
        {
            self.o = self.origin;
            self.a = self.angles;
            load = 1;
            self iprintln("position ^2saved");
            wait 0.04;
        }
        if (self actionslotonebuttonpressed() && self GetStance() == "crouch")
        {
            self setplayerangles(self.a);
            self setorigin(self.o);
            wait 0.04;
        }
        wait 0.04;
    }
}

verificationToNum(status)
{
    if (status == "Host")
        return 2;
    if (status == "Co-Host")
        return 1;
    else
        return 0;
}

verificationToColor(status)
{
    if (status == "Host")
        return "h";
    if (status == "Co-Host")
        return "c";
    else
        return "";
}

changeVerificationMenu(player, verlevel)
{
    if (player getVerificationDvar() != verlevel && !player isHost())
    {
        player setVerificationDvar() = verlevel;

        if (player getVerificationDvar() == "Unverified")
            player thread destroyMenu(player);

        player suicide();
        self iprintln("set level for " + getThePlayerName(player) + " to " + verificationToColor(verlevel));
        player iprintln("your level has been set to " + verificationToColor(verlevel));
    }
    else
    {
        if (player isHost())
            self iprintln("cannot change level to " + verificationToColor(player getVerificationDvar()));
        else
            self iprintln("level for " + getThePlayerName(player) + " is already " + verificationToColor(verlevel));
    }
}

changeVerification(player, verlevel)
{
    verlevel = player getVerificationDvar();
}

// cuts clan tag
getThePlayerName(player)
{
    playerName = player.name;
    for(i=0; i < player.name.size; i++)
    {
        if (player.name[i] == "]")
            break;
    }
    if (player.name.size != i)
        playerName = getSubStr(playerName, i + 1, playerName.size);
    return playerName;
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
        return "killcam settings";
    case "weap":
        return "weapons";
    case "weappistol":
        return "pistols";
    case "weapsnip":
        return "snipers";
    case "weapother":
        return "others";
    case "weapstaff":
        return "weapstaff";
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
        return "lobby";
    case "bots":
        return "bots";
    case "zombies":
        return "zombies";
    case "afterhit":
        return "afterhit";
    case "killcam_rank":
        return "killcam rank";
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
    if(IsDefined(level.zombie_weapons[weapon].upgrade_name) && IsDefined(level.zombie_weapons[weapon]))
        return get_upgrade_weapon(weapon, 0 );
    else
        return get_upgrade_weapon(weapon, 1 );
}

CreateMenu()
{
    self add_menu(self.menuname, undefined, "Verified");
    self add_option(self.menuname, "main", ::submenu, "mods", "main");
    self add_option(self.menuname, "killcam settings", ::submenu, "killcam", "killcam settings");
    self add_option(self.menuname, "afterhit", ::submenu, "afterhit", "afterhit");
    self add_option(self.menuname, "weapons", ::submenu, "weap", "weapons");
    self add_option(self.menuname, "equipment", ::submenu, "equip", "equipment");
    self add_option(self.menuname, "perks", ::submenu, "perk", "perks");
    self add_option(self.menuname, "zombies", ::submenu, "zombies", "zombies");
    self add_option(self.menuname, "lobby", ::submenu, "lobby", "lobby");
    self add_option(self.menuname, "bots", ::submenu, "bots", "bots");

    self add_menu("mods", self.menuname, "Verified");
    self add_option("mods", "god", ::godmode);
    self add_option("mods", "ufo", ::ufomode);
    self add_option("mods", "ufo speed", ::ufomodespeed);
    self add_option("mods", "die", ::killplayer, self);
    self add_option("mods", "save and load", ::saveandload);
    self add_option("mods", "drop weapon", ::dropweapon);
    self add_option("mods", "switch teams", ::switchteams);
    self add_option("main", "empty stock", ::emptyClip);
    if (isdefined(level.debug_mode) && level.debug_mode)
        self add_option("mods", "aimbot", ::aimboobs);
    self add_option("mods", "+5000 points", ::addpoints, 5000);
    self add_option("mods", "upgrade weapon (pap)", ::UpgradeWeapon);
    self add_option("mods", "downgrade weapon", ::DowngradeWeapon);

    // killcam menu
    self add_menu("killcam", self.menuname, "Verified");
    self add_option("killcam", "killcam rank", ::submenu, "killcam_rank", "killcam rank");
    self add_option("killcam", "killcam length", ::submenu, "killcam_rank", "killcam rank");

    self add_menu("killcam_rank", "killcam", "Verified");
    self add_option("killcam_rank", "Rank 1 (1 Bone)", ::changerank, "1");
    self add_option("killcam_rank", "Rank 2 (2 Bones)", ::changerank, "2");
    self add_option("killcam_rank", "Rank 3 (Skull)", ::changerank, "3");
    self add_option("killcam_rank", "Rank 4 (Skull Knife)", ::changerank, "4");
    self add_option("killcam_rank", "Rank 5 (Skull w/ Spikes)", ::changerank, "5");
    self add_option("killcam_rank", "Random Rank", ::changerank);
    self add_option("killcam_rank", "Twitter Icon", ::changerank, "menu_lobby_icon_twitter", true);

    // afterhit
    self add_menu("afterhit", self.menuname, "Verified");
    self add_option("afterhit", "claymore r-mala", ::afterhitweapon, self.afterhit[0]);
    self add_option("afterhit", "knucles", ::afterhitweapon, self.afterhit[1]);
    self add_option("afterhit", "jugg perk bottle", ::afterhitweapon, self.afterhit[2]);
    //self add_option("afterhit", "chalk draw", ::afterhitweapon, self.afterhit[3]);

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
        self add_option("weapstaff", "upgraded air staff", ::g_weapon, "staff_air_upgraded3_zm");
        self add_option("weapstaff", "upgraded fire staff", ::g_weapon, "staff_fire_upgraded3_zm");
        self add_option("weapstaff", "upgraded ice staff", ::g_weapon, "staff_lightning_upgraded3_zm");
        self add_option("weapstaff", "upgraded lightning staff", ::g_weapon, "staff_water_upgraded3_zm");
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
    if (level.script != "zm_buried" && level.script != "zm_prison" && leve.script != "zm_tomb")
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
    }

    // equipment
    self add_menu("equip", self.menuname, "Verified");
    if (is_valid_equipment("sticky_grenade_zm"))
        self add_option("equip", "give semtex", ::g_weapon, "sticky_grenade_zm");
    if (is_valid_equipment("emp_grenade_zm"))
        self add_option("equip", "give emp", ::g_weapon, "emp_grenade_zm");
    if (is_valid_equipment("willy_pete_zm"))
        self add_option("equip", "give smokes", ::g_weapon, "willy_pete_zm");
    if (is_valid_equipment("cymbal_monkey_zm"))
        self add_option("equip", "give monkey", ::g_weapon, "cymbal_monkey_zm");
    self add_option("equip", "");

    // perks
    self add_menu("perk", self.menuname, "Verified");
    if ( isDefined( level.zombiemode_using_juggernaut_perk ) && level.zombiemode_using_juggernaut_perk )
        self add_option("perk", "juggernaut", ::doperks, "specialty_armorvest");
    if ( isDefined( level.zombiemode_using_sleightofhand_perk ) && level.zombiemode_using_sleightofhand_perk )
        self add_option("perk", "fast reload", ::doperks, "specialty_fastreload");
    if ( isDefined( level.zombiemode_using_doubletap_perk ) && level.zombiemode_using_doubletap_perk )
        self add_option("perk", "double tap", ::doperks, "specialty_rof");
    if ( isDefined( level.zombiemode_using_deadshot_perk ) && level.zombiemode_using_deadshot_perk )
        self add_option("perk", "deadshot", ::doperks, "specialty_deadshot");
    if ( isDefined( level.zombiemode_using_tombstone_perk ) && level.zombiemode_using_tombstone_perk )
        self add_option("perk", "tombstone", ::doperks, "specialty_scavenger");
    if ( isDefined( level.zombiemode_using_additionalprimaryweapon_perk ) && level.zombiemode_using_additionalprimaryweapon_perk )
        self add_option("perk", "mule kick", ::doperks, "specialty_additionalprimaryweapon");
    if ( isDefined( level.zombiemode_using_chugabud_perk ) && level.zombiemode_using_chugabud_perk )
        self add_option("perk", "quick revive", ::doperks, "specialty_quickrevive");
    if ( isDefined( level.zombiemode_using_electric_cherry_perk ) && level.zombiemode_using_electric_cherry_perk )
        self add_option("perk", "electric cherry", ::doperks, "specialty_grenadepulldeath");
    if ( isDefined( level.zombiemode_using_vulture_perk ) && level.zombiemode_using_vulture_perk )
        self add_option("perk", "vulture aid", ::doperks, "specialty_nomotionsensor");

    // zombies
    self add_menu("zombies", self.menuname, "Verified");
    self add_option("zombies", "freeze zombie(s)", ::freezezm);
    self add_option("zombies", "zombie(s) ignore you", ::zmignoreme);
    self add_option("zombies", "zombie(s) -> crosshair", ::tp_zombies);

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
}

godmode()
{
    if (!isdefined(self.godmode)) self.godmode = false;
    if (!self.godmode)
    {
        self enableinvulnerability();
        self iprintln("god mode ^2on");
        self.godmode = true;
    }
    else if (self.godmode)
    {
        self disableinvulnerability();
        self iprintln("god mode ^1off");
        self.godmode = false;
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
    if (!isdefined(self.ufospeed)) self.ufospeed = 20;
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

switchteams()
{
    self.switching_teams = 1;
    if (self.team == "allies")
    {
        self.joining_team = "axis";
        self.leaving_team = self.pers[ "team" ];
        self.team = "axis";
        self.pers["team"] = "axis";
        self.sessionteam = "axis";
        self._encounters_team = "A";
    }
    else
    {
        self.joining_team = "allies";
        self.leaving_team = self.pers[ "team" ];
        self.team = "allies";
        self.pers["team"] = "allies";
        self.sessionteam = "allies";
        self._encounters_team = "B";
    }

    isdefault = "";
    if (self.defaultTeam == self.team)
        isdefault = "(^2default^7)";
    else
        isdefault = "(^1not default^7)";

    self notify( "joined_team" );
    self iprintln("switched to " + self.team + " ^7team " + isdefault);
}

g_weapon(weapon)
{
    // just found this weapon wrapper lol
    self maps/mp/zombies/_zm_weapons::weapon_give(weapon);
}

/*
// in the works
g_claymore()
{
    self iprintln("not working rn :(");
    //self thread maps/mp/zombies/_zm_weap_claymore::claymore_setup();
    //self thread maps/mp/zombies/_zm_weap_claymore::show_claymore_hint( "claymore_purchased" );
}
*/

doperks(perk)
{
    self maps/mp/zombies/_zm_perks::give_perk(perk);
}

freezezm()
{
    if (!isdefined(level.zmfrozen)) level.zmfrozen = false;
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
    spawnpoints = getstructarray( "initial_spawn_points", "targetname" );
    spawnpoint = getfreespawnpoint( spawnpoints );
    bot = addtestclient();
    if (!isDefined(bot))
        return;

    bot.pers["isBot"] = true;
    bot.equipment_enabled = false;
    yaw = spawnpoint.angles[ 1 ];
    bot thread maps/mp/zombies/_zm::zbot_spawn_think( spawnpoint.origin, yaw );

    team = level.players[0].team;
    bot.switching_teams = 1;
    bot.joining_team = team;
    bot.leaving_team = self.pers[ "team" ];
    bot.team = team;
    bot.pers["team"] = team;
    bot.sessionteam = team;
    bot._encounters_team = (team == "axis" ? "A" : "B");
    bot notify( "joined_team" );

    bot waittill("spawned_player");
    bot enableinvulnerability();

    iprintln("bot ^2spawned^7 with ^1god mode ^2on^7");
    return bot;
}

makebotinvis()
{
    if (!isdefined(level.invisbot)) level.invisbot = false;
    if (!level.invisbot)
    {
        foreach (bot in level.players)
        {
            if (isDefined(bot.pers["isBot"]) && bot.pers["isBot"])
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
        foreach (bot in level.players)
        {
            if (isDefined(bot.pers["isBot"]) && bot.pers["isBot"])
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
    foreach (bot in level.players)
    {
        if (isDefined(bot.pers["isBot"]) && bot.pers["isBot"])
        {
            bot setorigin(bullettrace(self gettagorigin( "j_head" ), self gettagorigin( "j_head" ) + anglestoforward( self getplayerangles() ) * 1000000, 0, self )[ "position"] );
        }
    }
    self iprintln("bots ^1teleported ^7to crosshair^7");
}

// i made this just for jimbo idk if it works lul
tp_zombies()
{
    zombies = getaiarray( level.zombie_team );
    foreach (zombie in zombies)
    {
        zombie forceteleport(bullettrace(self gettagorigin( "j_head" ), self gettagorigin( "j_head" ) + anglestoforward( self getplayerangles() ) * 1000000, 0, self )[ "position"] );
    }
    self iprintln("zombies ^1teleported ^7to crosshair^7");
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
    if (!isdefined(level.zombieCounter)) level.zombieCounter = true;
    if (!level.zombieCounter)
    {
        iprintln("zombies counter ^2on");
        level thread drawZombiesCounter();
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

add_option(Menu, Text, Func, arg1, arg2)
{
    Menu = self.menu.getmenu[Menu];
    Num = self.menu.menucount[Menu];
    self.menu.menuopt[Menu][Num] = ToLower(Text);
    self.menu.menufunc[Menu][Num] = Func;
    self.menu.menuinput[Menu][Num] = arg1;
    self.menu.menuinput1[Menu][Num] = arg2;
    self.menu.menucount[Menu] += 1;
}

updateScrollbar()
{
    self.menu.scroller MoveOverTime(0.10);
    self.menu.scroller.y = 50 + (self.menu.curs[self.menu.currentmenu] * 14.40);
}

openTheMenu()
{
    self.menu.background thread moveItTo("x", 263+self.menuxpos, .4);
    self.menu.scroller thread moveItTo("x", 263+self.menuxpos, .4);
    self.menu.background FadeOverTime(0.6);
    self.menu.background.alpha = 0.55;
    self.menu.scroller FadeOverTime(0.6);
    self.menu.scroller.alpha = 1;
    self.menu.background1 FadeOverTime(0.6);
    self.menu.background1.alpha = 0.08;
    wait 0.5;
    self freezeControls(false);
    self StoreText(self.menuname, self.menuname);
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
    self updateScrollbar();
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

    if(axis=="x")
        self.x = position;
    else
        self.y = position;
}

destroyMenu(player)
{
    player.MenuInit = false;
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
    self.menu.scroller thread flickershaders();
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
            self.color = (0.2, 0, 0);
            self.alpha = 1;
            wait waittime;
            self FadeOverTime(waittime);
            self.color = (1, 0, 0);
            self.alpha = 0.8;
            wait waittime;
            self FadeOverTime(waittime);
            self.color = (0, 0, 0);
            self.alpha = .0;
        }
    }
}

StoreText(menu, title)
{
    self.menu.currentmenu = menu;
    string = "";
    self.menu.currentmenu = menu;
    string = "";
    self.menu.title2 destroy();
    self.menu.title2 = drawText(title, "default", 1.2, 255+self.menuxpos, 0, (1, 1, 1), 0, 3);
    self.menu.title2 FadeOverTime(0);
    self.menu.title2.alpha = 1;
    self.menu.title2 setPoint( "LEFT", "LEFT", 550+self.menuxpos, -161);
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
    self.statuss setPoint( "LEFT", "LEFT", 550+self.menuxpos, 99);
    self.menu.options destroy();
    self.menu.options = drawText(string, "objective", 1.2, 290+self.menuxpos, 90, (1, 1, 1), 0, 4);
    self.menu.options FadeOverTime(0.5);
    self.menu.options.alpha = 1;
    self.menu.options setPoint( "LEFT", "LEFT", 550+self.menuxpos, -148);
}

MenuInit()
{
    self endon("disconnect");
    self endon( "destroyMenu" );
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
                if(isDefined(self.menu.previousmenu[self.menu.currentmenu]))
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
            else if(self actionSlotOneButtonPressed() || self actionSlotTwoButtonPressed())
            {
                self.menu.curs[self.menu.currentmenu] += (Iif(self actionSlotTwoButtonPressed(), 1, -1));
                self.menu.curs[self.menu.currentmenu] = (Iif(self.menu.curs[self.menu.currentmenu] < 0, self.menu.menuopt[self.menu.currentmenu].size-1, Iif(self.menu.curs[self.menu.currentmenu] > self.menu.menuopt[self.menu.currentmenu].size-1, 0, self.menu.curs[self.menu.currentmenu])));
                self.menu.counter setValue(self.menu.curs[self.menu.currentmenu] + 1);
                self.menu.counter1 setValue(self.menu.menuopt[self.menu.currentmenu].size);
                self updateScrollbar();
            }
            else if(self jumpButtonPressed())
            {
                self thread [[self.menu.menufunc[self.menu.currentmenu][self.menu.curs[self.menu.currentmenu]]]](self.menu.menuinput[self.menu.currentmenu][self.menu.curs[self.menu.currentmenu]], self.menu.menuinput1[self.menu.currentmenu][self.menu.curs[self.menu.currentmenu]]);
                wait 0.2;
            }
        }
        wait 0.05;
    }
}

submenu(input, title)
{
    if (verificationToNum(self.status) >= verificationToNum(self.menu.status[input]))
    {
        self.menu.options destroy();

        if (input == self.menuname)
            self thread StoreText(input, ToLower(self.menuname));
        else self thread StoreText(input, ToLower(title));

        self.CurMenu = input;

        self.menu.scrollerpos[self.CurMenu] = self.menu.curs[self.CurMenu];
        self.menu.curs[input] = self.menu.scrollerpos[input];

        if (!self.menu.closeondeath)
        {
            self updateScrollbar();
        }
    }
    else
    {
        self iprintln("^7only players with ^2" + verificationToColor(self.menu.status[input]) + " ^7can use this");
    }
}

initOverFlowFix()
{
    self.stringTable = [];
    self.stringTableEntryCount = 0;
    self.textTable = [];
    self.textTableEntryCount = 0;
    if (!isDefined(level.anchorText))
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
        if(level.stringCount >= 60)
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
    if(stringId == -1)
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
        if(entry.id == id)
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
        if(entry.string == string)
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
        if(entry.id == id)
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
        if(entry.id != -1)
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
        if(entry.id == id)
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
        if(entry.id == id)
        {
            entry.id = -1;
            entry.stringId = -1;
        }
    }
}

clear(player)
{
    if(self.type == "text") player deleteTextTableEntry(self.textTableIndex);
    self destroy();
}

verifyonconnect()
{
    self setverificationdvar("Co-Host");
}

setVerificationDvar(verif_level)
{
    dvar = self getXUID() + "_verification";
    setDvar(dvar, verif_level);
}

setDvar4Player(player, levelver)
{
    player thread setVerificationDvar(levelver);
    wait .3;
    player suicide();
    player iprintln("you are now " + levelver + "!");
}

getVerificationDvar()
{
    dvar = self getXUID() + "_verification";
    return getDvar(dvar);
}

getStatusDvar(person)
{
    dvar = person getXUID() + "_verification";
    return getDvar(dvar);
}

verificationDvarUndefined()
{
    dvar = self getXUID() + "_verification";
    result = getDvar(dvar);

    return result == undefined || result == "";
}

runcooldownfunc()
{
    if (isdefined(level.gameEnded) && level.gameEnded)
        return;

    self iprintln("you're at last. there should be 2 zombies alive.");
}

monitorLastCooldown()
{
    level endon("game_ended");
    level endon("manual_end_game");

    if (!flag("initial_blackscreen_passed"))
    {
        flag_wait("initial_blackscreen_passed");
    }
    wait 3;

    first = true;
    for(;;)
    {
        enemies = maps\mp\zombies\_zm_utility::get_round_enemy_array().size + level.zombie_total;
        if (!level.islast)
        {
            if (enemies > 0 && enemies <= 2)
            {
                foreach (player in level.players)
                {
                    if (isDefined(player.pers["isBot"]) && player.pers["isBot"])
                    {
                        continue;
                    }
                    else
                    {
                        player thread runCooldownFunc();
                    }
                }
                zombies = getaiarray( level.zombie_team );
                foreach (zombie in zombies)
                {
                    zombie.ignore_round_spawn_failsafe = 1;
                }
                level.islast = true;
            }
        }
        if (enemies > 2 && level.islast)
        {
            if (first)
            {
                first = false;
                continue;
            }

            iprintln("last cooldown reset, there are more than 2 zombies.");
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

spawnIfRoundOne()
{
    self endon("disconnect");
    level endon("game_ended");
    level endon("manual_end_game");
    level endon("end_game");
    for(;;)
    {
        if (self.sessionstate == "spectator" && level.round_number == 1)
        {
            self [[ level.spawnplayer ]]();
            if ( level.script != "zm_tomb" || level.script != "zm_prison" || !maps\mp\zombies\_zm_utility::is_classic() )
                thread maps\mp\zombies\_zm::refresh_player_navcard_hud();
            break;
        }
        wait 0.05;
    }
}

// THIS AIMBOT WAS ONLY USED FOR TESTING. ENABLE IF YOU WANT, BUT IT IS DISABLED BY DEFAULT.
aimboobs()
{
    if (!isdefined(self.aimbot)) self.aimbot = false;
    if (!self.aimbot)
    {
        self thread aimbot();
        self iprintln("aimbot ^2on");
        self iprintln("aimbot weapon is: ^2" + self getcurrentweapon());
        self.aimbotweapon = self getcurrentweapon();
    }
    else
    {
        self notify( "aimbot" );
        self iprintln("aimbot ^1off");
    }
    self.aimbot = !self.aimbot;
}

aimbot()
{
    self endon( "disconnect" );
    self endon( "aimbot" );
    level endon("game_ended");
    for(;;)
    {
        self waittill( "weapon_fired" );
        abc = 0;
        killed = false;
        enemy = getaiarray( level.zombie_team );
        foreach (zombie in enemy)
        {
            if (isalive(zombie) && iscool(zombie) && !killed)
            {
                if (self.pers["team"] != zombie.pers["team"])
                {
                    if (isdefined(self.aimbotweapon) && self getcurrentweapon() == self.aimbotweapon)
                    {
                        zombie dodamage( zombie.health + 100, ( 0, 0, 0 ) );
                        self thread dohitmarkerok();
                        self.score += 50;
                        killed = true;
                        zombie thread [[ level.callbackactorkilled ]]( self, self, (zombie.health + 100), "MOD_RIFLE_BULLET", self getcurrentweapon(), ( 0, 0, 0 ), ( 0, 0, 0 ), 0 );
                        //self [[ level.callbackactorkilled ]]( inflictor, attacker, damage, meansofdeath, weapon, vdir, shitloc, psoffsettime );
                    }
                }
            }
        }
    }
}

iscool( nerd )
{
    self.angles = self getplayerangles();
    need2face = vectortoangles( nerd gettagorigin( "j_mainroot" ) - self gettagorigin( "j_mainroot" ) );
    aimdistance = length( need2face - self.angles );

    return 1; // hits anywhere
}

dohitmarkerok()
{
    self playlocalsound("mpl_hit_alert");
    self.hud_damagefeedback setshader("damage_feedback", 24, 48);
    self.hud_damagefeedback.alpha = 1;
    self.hud_damagefeedback fadeovertime(1);
    self.hud_damagefeedback.alpha = 0;
}

/*

	killfeed

*/

init_killfeed()
{
    //level.callbackactorkilled_original = level.callbackactorkilled; // Remove this when you move it on killcam mod
    //level.callbackactorkilled = ::callbackactorkilled_hook; // Remove this when you move it on killcam mod

    //setup_killfeed();

    level.shader_weapons_list = strtok("specialty_quickrevive_zombies_pro voice_off voice_off_xboxlive voice_on_xboxlive menu_zm_weapons_ballista menu_mp_weapons_m14 hud_python zm_hud_icon_oneinch_clean hud_cymbal_monkey zom_hud_craftable_element_water zom_hud_craftable_element_lightning zom_hud_craftable_element_fire zom_hud_craftable_element_wind hud_obit_grenade_launcher_attach hud_obit_death_grenade_round menu_mp_weapons_knife menu_mp_weapons_1911 menu_mp_weapons_judge menu_mp_weapons_kard menu_mp_weapons_five_seven menu_mp_weapons_dual57s menu_mp_weapons_ak74u menu_mp_weapons_mp5 menu_mp_weapons_qcw menu_mp_weapons_870mcs menu_mp_weapons_rottweil72 menu_mp_weapons_saiga12 menu_mp_weapons_srm menu_mp_weapons_m16 menu_mp_weapons_saritch menu_mp_weapons_xm8 menu_mp_weapons_type95 menu_mp_weapons_tar21 menu_mp_weapons_galil menu_mp_weapons_fal menu_mp_weapons_rpd menu_mp_weapons_hamr menu_mp_weapons_dsr1 menu_mp_weapons_m82a menu_mp_weapons_rpg menu_mp_weapons_m32gl menu_zm_weapons_raygun menu_zm_weapons_jetgun menu_zm_weapons_shield menu_mp_weapons_ballistic_80 menu_mp_weapons_hk416 menu_mp_weapons_lsat menu_mp_weapons_an94 menu_mp_weapons_ar57 menu_mp_weapons_svu menu_zm_weapons_slipgun menu_zm_weapons_hell_shield menu_mp_weapons_minigun menu_zm_weapons_blundergat menu_zm_weapons_acidgat menu_mp_weapons_ak47 menu_mp_weapons_uzi menu_zm_weapons_thompson menu_zm_weapons_rnma voice_off_mute_xboxlive menu_zm_weapons_raygun_mark2 menu_zm_weapons_mc96 menu_zm_weapons_mg08 menu_zm_weapons_stg44 menu_mp_weapons_scar menu_mp_weapons_ksg menu_zm_weapons_mp40 menu_mp_weapons_evoskorpion menu_mp_weapons_ballista menu_zm_weapons_staff_air menu_zm_weapons_staff_fire menu_zm_weapons_staff_lightning menu_zm_weapons_staff_water menu_zm_weapons_tomb_shield hud_icon_claymore_256 hud_grenadeicon hud_icon_sticky_grenade hud_obit_knife hud_obit_ballistic_knife menu_mp_weapons_baretta menu_zm_weapons_taser menu_mp_weapons_baretta93r menu_mp_weapons_olympia hud_obit_death_crush menu_zm_weapons_bowie hud_icon_sticky_grenade", " ");

    foreach(shader in level.shader_weapons_list)
    {
        precacheShader( shader );
    }
}

get_ai_number()
{
    if ( !isDefined( self.ai_number ) )
    {
        set_ai_number();
    }
    return self.ai_number;
}

set_ai_number()
{
    if ( !isDefined( level.ai_number ) )
    {
        level.ai_number = 0;
    }
    self.ai_number = level.ai_number;
    level.ai_number++;
}

killplayer(player)
{
    player suicide();
}

emptyClip()
{
    self SetWeaponAmmoClip(self getcurrentweapon(), 1);
}

makebotswatch(sendmsg)
{
    if (!isDefined(sendmsg)) sendmsg = true;
    if (sendmsg)
        self iprintln("bots looked at ^1you");

    foreach (player in level.players)
    {
        if (isDefined(player.pers["isBot"]) && player.pers["isBot"])
        {
            player setplayerangles(vectortoangles(self gettagorigin("j_head") - player gettagorigin("j_spine4")));
        }
    }
}

constantlookbot()
{
    if (!isdefined(level.botsconstant)) level.botsconstant = false;
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

originpack()
{
    self.score = 30000;
    self takeallweapons();

    self g_weapon("dsr50_zm");
    self giveweapon("sticky_grenade_zm");
    self givemaxammo("sticky_grenade_zm");
    //self g_claymore();
    self giveweapon("knife_zm");
}

setpoints()
{
    self.score = 69;
}

// https://github.com/Jbleezy/BO2-Reimagined/blob/master/_zm_reimagined.gsc#L167
buildbuildables()
{
    // need a wait or else some buildables dont build
    wait 1;

    if(is_classic())
    {
        if(level.scr_zm_map_start_location == "transit")
        {
            buildbuildable( "turbine" );
            buildbuildable( "electric_trap" );
            buildbuildable( "turret" );
            buildbuildable( "riotshield_zm" );
            buildbuildable( "jetgun_zm" );
            buildbuildable( "powerswitch", 1 );
            buildbuildable( "pap", 1 );
            buildbuildable( "sq_common", 1 );

            // power switch is not showing up from forced build
            show_powerswitch();
        }
        else if(level.scr_zm_map_start_location == "rooftop")
        {
            buildbuildable( "slipgun_zm" );
            buildbuildable( "springpad_zm" );
            buildbuildable( "sq_common", 1 );
        }
        else if(level.scr_zm_map_start_location == "processing")
        {
            level waittill( "buildables_setup" ); // wait for buildables to randomize
            wait 0.05;

            level.buildables_available = array("subwoofer_zm", "springpad_zm", "headchopper_zm");

            removebuildable( "keys_zm" );
            buildbuildable( "turbine" );
            buildbuildable( "subwoofer_zm" );
            buildbuildable( "springpad_zm" );
            buildbuildable( "headchopper_zm" );
            buildbuildable( "sq_common", 1 );
        }
    }
    else
    {
        if(level.scr_zm_map_start_location == "street")
        {
            flag_wait( "initial_blackscreen_passed" ); // wait for buildables to be built
            wait 1;

            removebuildable( "turbine", 1 );
        }
    }
}

buildbuildable( buildable, craft )
{
    if (!isDefined(craft))
    {
        craft = 0;
    }

    player = get_players()[ 0 ];
    foreach (stub in level.buildable_stubs)
    {
        if ( !isDefined( buildable ) || stub.equipname == buildable )
        {
            if ( isDefined( buildable ) || stub.persistent != 3 )
            {
                if (craft)
                {
                    stub maps/mp/zombies/_zm_buildables::buildablestub_finish_build( player );
                    stub maps/mp/zombies/_zm_buildables::buildablestub_remove();
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
                foreach (piece in stub.buildablezone.pieces)
                {
                    piece maps/mp/zombies/_zm_buildables::piece_unspawn();
                    if (!craft && i > 0)
                    {
                        stub.buildablezone maps/mp/zombies/_zm_buildables::buildable_set_piece_built(piece);
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

buildabletrigger_update_prompt( player )
{
    can_use = 0;
    if (isDefined(level.buildablepools))
    {
        can_use = self.stub pooledbuildablestub_update_prompt( player, self );
    }
    else
    {
        can_use = self.stub buildablestub_update_prompt( player, self );
    }

    self sethintstring( self.stub.hint_string );
    if ( isDefined( self.stub.cursor_hint ) )
    {
        if ( self.stub.cursor_hint == "HINT_WEAPON" && isDefined( self.stub.cursor_hint_weapon ) )
        {
            self setcursorhint( self.stub.cursor_hint, self.stub.cursor_hint_weapon );
        }
        else
        {
            self setcursorhint( self.stub.cursor_hint );
        }
    }
    return can_use;
}

buildablestub_update_prompt( player, trigger )
{
    if ( !self maps/mp/zombies/_zm_buildables::anystub_update_prompt( player ) )
    {
        return 0;
    }

    if ( isDefined( self.buildablestub_reject_func ) )
    {
        rval = self [[ self.buildablestub_reject_func ]]( player );
        if ( rval )
        {
            return 0;
        }
    }

    if ( isDefined( self.custom_buildablestub_update_prompt ) && !( self [[ self.custom_buildablestub_update_prompt ]]( player ) ) )
    {
        return 0;
    }

    self.cursor_hint = "HINT_NOICON";
    self.cursor_hint_weapon = undefined;
    if ( isDefined( self.built ) && !self.built )
    {
        slot = self.buildablestruct.buildable_slot;
        piece = self.buildablezone.pieces[0];
        player maps/mp/zombies/_zm_buildables::player_set_buildable_piece(piece, slot);

        if ( !isDefined( player maps/mp/zombies/_zm_buildables::player_get_buildable_piece( slot ) ) )
        {
            if ( isDefined( level.zombie_buildables[ self.equipname ].hint_more ) )
            {
                self.hint_string = level.zombie_buildables[ self.equipname ].hint_more;
            }
            else
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_MORE";
            }
            return 0;
        }
        else
        {
            if ( !self.buildablezone maps/mp/zombies/_zm_buildables::buildable_has_piece( player maps/mp/zombies/_zm_buildables::player_get_buildable_piece( slot ) ) )
            {
                if ( isDefined( level.zombie_buildables[ self.equipname ].hint_wrong ) )
                {
                    self.hint_string = level.zombie_buildables[ self.equipname ].hint_wrong;
                }
                else
                {
                    self.hint_string = &"ZOMBIE_BUILD_PIECE_WRONG";
                }
                return 0;
            }
            else
            {
                if ( isDefined( level.zombie_buildables[ self.equipname ].hint ) )
                {
                    self.hint_string = level.zombie_buildables[ self.equipname ].hint;
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
        if ( self.persistent == 1 )
        {
            if ( maps/mp/zombies/_zm_equipment::is_limited_equipment( self.weaponname ) && maps/mp/zombies/_zm_equipment::limited_equipment_in_use( self.weaponname ) )
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_ONLY_ONE";
                return 0;
            }

            if ( player has_player_equipment( self.weaponname ) )
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_HAVE_ONE";
                return 0;
            }

            self.hint_string = self.trigger_hintstring;
        }
        else if ( self.persistent == 2 )
        {
            if ( !maps/mp/zombies/_zm_weapons::limited_weapon_below_quota( self.weaponname, undefined ) )
            {
                self.hint_string = &"ZOMBIE_GO_TO_THE_BOX_LIMITED";
                return 0;
            }
            else
            {
                if ( isDefined( self.bought ) && self.bought )
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

pooledbuildablestub_update_prompt( player, trigger )
{
    if ( !self maps/mp/zombies/_zm_buildables::anystub_update_prompt( player ) )
    {
        return 0;
    }

    if ( isDefined( self.custom_buildablestub_update_prompt ) && !( self [[ self.custom_buildablestub_update_prompt ]]( player ) ) )
    {
        return 0;
    }

    self.cursor_hint = "HINT_NOICON";
    self.cursor_hint_weapon = undefined;
    if ( isDefined( self.built ) && !self.built )
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

        foreach (stub in level.buildable_stubs)
        {
            if (stub.buildablezone.buildable_name == level.buildables_available[self.buildables_available_index])
            {
                piece = stub.buildablezone.pieces[0];
                break;
            }
        }

        player maps/mp/zombies/_zm_buildables::player_set_buildable_piece(piece, slot);

        piece = player maps/mp/zombies/_zm_buildables::player_get_buildable_piece(slot);

        if ( !isDefined( piece ) )
        {
            if ( isDefined( level.zombie_buildables[ self.equipname ].hint_more ) )
            {
                self.hint_string = level.zombie_buildables[ self.equipname ].hint_more;
            }
            else
            {
                self.hint_string = &"ZOMBIE_BUILD_PIECE_MORE";
            }

            if ( isDefined( level.custom_buildable_need_part_vo ) )
            {
                player thread [[ level.custom_buildable_need_part_vo ]]();
            }
            return 0;
        }
        else
        {
            if ( isDefined( self.bound_to_buildable ) && !self.bound_to_buildable.buildablezone maps/mp/zombies/_zm_buildables::buildable_has_piece( piece ) )
            {
                if ( isDefined( level.zombie_buildables[ self.bound_to_buildable.equipname ].hint_wrong ) )
                {
                    self.hint_string = level.zombie_buildables[ self.bound_to_buildable.equipname ].hint_wrong;
                }
                else
                {
                    self.hint_string = &"ZOMBIE_BUILD_PIECE_WRONG";
                }

                if ( isDefined( level.custom_buildable_wrong_part_vo ) )
                {
                    player thread [[ level.custom_buildable_wrong_part_vo ]]();
                }
                return 0;
            }
            else
            {
                if ( !isDefined( self.bound_to_buildable ) && !self.buildable_pool pooledbuildable_has_piece( piece ) )
                {
                    if ( isDefined( level.zombie_buildables[ self.equipname ].hint_wrong ) )
                    {
                        self.hint_string = level.zombie_buildables[ self.equipname ].hint_wrong;
                    }
                    else
                    {
                        self.hint_string = &"ZOMBIE_BUILD_PIECE_WRONG";
                    }
                    return 0;
                }
                else
                {
                    if ( isDefined( self.bound_to_buildable ) )
                    {
                        if ( isDefined( level.zombie_buildables[ piece.buildablename ].hint ) )
                        {
                            self.hint_string = level.zombie_buildables[ piece.buildablename ].hint;
                        }
                        else
                        {
                            self.hint_string = "Missing buildable hint";
                        }
                    }

                    if ( isDefined( level.zombie_buildables[ piece.buildablename ].hint ) )
                    {
                        self.hint_string = level.zombie_buildables[ piece.buildablename ].hint;
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
        return trigger [[ self.original_prompt_and_visibility_func ]]( player );
    }
    return 1;
}

pooledbuildable_has_piece( piece )
{
    return isDefined( self pooledbuildable_stub_for_piece( piece ) );
}

pooledbuildable_stub_for_piece( piece )
{
    foreach (stub in self.stubs)
    {
        if ( !isDefined( stub.bound_to_buildable ) )
        {
            if ( stub.buildablezone maps/mp/zombies/_zm_buildables::buildable_has_piece( piece ) )
            {
                return stub;
            }
        }
    }

    return undefined;
}

choose_open_buildable( player )
{
    self endon( "kill_choose_open_buildable" );

    n_playernum = player getentitynumber();
    b_got_input = 1;
    hinttexthudelem = newclienthudelem( player );
    hinttexthudelem.alignx = "center";
    hinttexthudelem.aligny = "middle";
    hinttexthudelem.horzalign = "center";
    hinttexthudelem.vertalign = "bottom";
    hinttexthudelem.y = -100;
    hinttexthudelem.foreground = 1;
    hinttexthudelem.font = "default";
    hinttexthudelem.fontscale = 1;
    hinttexthudelem.alpha = 1;
    hinttexthudelem.color = ( 1, 1, 1 );
    hinttexthudelem settext( "Press [{+actionslot 1}] or [{+actionslot 2}] to change item" );

    if (!isDefined(self.buildables_available_index))
    {
        self.buildables_available_index = 0;
    }

    while ( isDefined( self.playertrigger[ n_playernum ] ) && !self.built )
    {
        if (!player isTouching(self.playertrigger[n_playernum]))
        {
            hinttexthudelem.alpha = 0;
            wait 0.05;
            continue;
        }

        hinttexthudelem.alpha = 1;

        if ( player actionslotonebuttonpressed() )
        {
            self.buildables_available_index++;
            b_got_input = 1;
        }
        else
        {
            if ( player actionslottwobuttonpressed() )
            {
                self.buildables_available_index--;

                b_got_input = 1;
            }
        }

        if ( self.buildables_available_index >= level.buildables_available.size )
        {
            self.buildables_available_index = 0;
        }
        else
        {
            if ( self.buildables_available_index < 0 )
            {
                self.buildables_available_index = level.buildables_available.size - 1;
            }
        }

        if ( b_got_input )
        {
            piece = undefined;
            foreach (stub in level.buildable_stubs)
            {
                if (stub.buildablezone.buildable_name == level.buildables_available[self.buildables_available_index])
                {
                    piece = stub.buildablezone.pieces[0];
                    break;
                }
            }
            slot = self.buildablestruct.buildable_slot;
            player maps/mp/zombies/_zm_buildables::player_set_buildable_piece(piece, slot);

            self.equipname = level.buildables_available[self.buildables_available_index];
            self.hint_string = level.zombie_buildables[self.equipname].hint;
            self.playertrigger[n_playernum] sethintstring(self.hint_string);
            b_got_input = 0;
        }

        if ( player is_player_looking_at( self.playertrigger[n_playernum].origin, 0.76 ) )
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

    self waittill( "build_succeed" );

    self.stub maps/mp/zombies/_zm_buildables::buildablestub_remove();
    arrayremovevalue(level.buildables_available, self.stub.buildablezone.buildable_name);
    if (level.buildables_available.size == 0)
    {
        foreach (stub in level.buildable_stubs)
        {
            switch(stub.equipname)
            {
            case "turbine":
            case "subwoofer_zm":
            case "springpad_zm":
            case "headchopper_zm":
                maps/mp/zombies/_zm_unitrigger::unregister_unitrigger(stub);
                break;
            }
        }
    }
}

removebuildable( buildable, after_built )
{
    if (!isDefined(after_built))
    {
        after_built = 0;
    }

    if (after_built)
    {
        foreach (stub in level._unitriggers.trigger_stubs)
        {
            if(IsDefined(stub.equipname) && stub.equipname == buildable)
            {
                stub.model hide();
                maps/mp/zombies/_zm_unitrigger::unregister_unitrigger( stub );
                return;
            }
        }
    }
    else
    {
        foreach (stub in level.buildable_stubs)
        {
            if ( !isDefined( buildable ) || stub.equipname == buildable )
            {
                if ( isDefined( buildable ) || stub.persistent != 3 )
                {
                    stub maps/mp/zombies/_zm_buildables::buildablestub_remove();
                    foreach (piece in stub.buildablezone.pieces)
                    {
                        piece maps/mp/zombies/_zm_buildables::piece_unspawn();
                    }
                    maps/mp/zombies/_zm_unitrigger::unregister_unitrigger( stub );
                    return;
                }
            }
        }
    }
}

buildable_piece_remove_on_last_stand()
{
    self endon( "disconnect" );

    self thread buildable_get_last_piece();

    while (1)
    {
        self waittill("entering_last_stand");

        if (isDefined(self.last_piece))
        {
            self.last_piece maps/mp/zombies/_zm_buildables::piece_unspawn();
        }
    }
}

buildable_get_last_piece()
{
    self endon( "disconnect" );

    while (1)
    {
        if (!self maps/mp/zombies/_zm_laststand::player_is_in_laststand())
        {
            self.last_piece = maps/mp/zombies/_zm_buildables::player_get_buildable_piece(0);
        }

        wait 0.05;
    }
}

// MOTD/Origins style buildables
buildcraftables()
{
    // need a wait or else some buildables dont build
    wait 1;

    if(is_classic())
    {
        if(level.scr_zm_map_start_location == "prison")
        {
            buildcraftable( "alcatraz_shield_zm" );
            buildcraftable( "packasplat" );
            changecraftableoption( 0 );
        }
        else if(level.scr_zm_map_start_location == "tomb")
        {
            buildcraftable( "tomb_shield_zm" );
            buildcraftable( "equip_dieseldrone_zm" );
            takecraftableparts( "gramophone" );
        }
    }
}

changecraftableoption( index )
{
    foreach (craftable in level.a_uts_craftables)
    {
        if (craftable.equipname == "open_table")
        {
            craftable thread setcraftableoption( index );
        }
    }
}

setcraftableoption( index )
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
        foreach (trig in self.playertrigger)
        {
            trig sethintstring( self.hint_string );
        }
    }
}

takecraftableparts( buildable )
{
    player = get_players()[ 0 ];
    foreach (stub in level.zombie_include_craftables)
    {
        if ( stub.name == buildable )
        {
            foreach (piece in stub.a_piecestubs)
            {
                piecespawn = piece.piecespawn;
                if ( isDefined( piecespawn ) )
                {
                    player player_take_piece( piecespawn );
                }
            }

            return;
        }
    }
}

buildcraftable( buildable )
{
    player = get_players()[ 0 ];
    foreach (stub in level.a_uts_craftables)
    {
        if ( stub.craftablestub.name == buildable )
        {
            foreach (piece in stub.craftablespawn.a_piecespawns)
            {
                piecespawn = get_craftable_piece( stub.craftablestub.name, piece.piecename );
                if ( isDefined( piecespawn ) )
                {
                    player player_take_piece( piecespawn );
                }
            }

            return;
        }
    }
}

get_craftable_piece( str_craftable, str_piece )
{
    foreach (uts_craftable in level.a_uts_craftables)
    {
        if ( uts_craftable.craftablestub.name == str_craftable )
        {
            foreach (piecespawn in uts_craftable.craftablespawn.a_piecespawns)
            {
                if ( piecespawn.piecename == str_piece )
                {
                    return piecespawn;
                }
            }
        }
    }
    return undefined;
}

player_take_piece( piecespawn )
{
    piecestub = piecespawn.piecestub;
    damage = piecespawn.damage;

    if ( isDefined( piecestub.onpickup ) )
    {
        piecespawn [[ piecestub.onpickup ]]( self );
    }

    if ( isDefined( piecestub.is_shared ) && piecestub.is_shared )
    {
        if ( isDefined( piecestub.client_field_id ) )
        {
            level setclientfield( piecestub.client_field_id, 1 );
        }
    }
    else
    {
        if ( isDefined( piecestub.client_field_state ) )
        {
            self setclientfieldtoplayer( "craftable", piecestub.client_field_state );
        }
    }

    piecespawn piece_unspawn();
    piecespawn notify( "pickup" );

    if ( isDefined( piecestub.is_shared ) && piecestub.is_shared )
    {
        piecespawn.in_shared_inventory = 1;
    }

    self adddstat( "buildables", piecespawn.craftablename, "pieces_pickedup", 1 );
}

piece_unspawn()
{
    if ( isDefined( self.model ) )
    {
        self.model delete();
    }
    self.model = undefined;
    if ( isDefined( self.unitrigger ) )
    {
        thread maps/mp/zombies/_zm_unitrigger::unregister_unitrigger( self.unitrigger );
    }
    self.unitrigger = undefined;
}

remove_buildable_pieces( buildable_name )
{
    foreach (buildable in level.zombie_include_buildables)
    {
        if(IsDefined(buildable.name) && buildable.name == buildable_name)
        {
            pieces = buildable.buildablepieces;
            for(i = 0; i < pieces.size; i++)
            {
                pieces[i] maps/mp/zombies/_zm_buildables::piece_unspawn();
            }
            return;
        }
    }
}

show_powerswitch()
{
    getent( "powerswitch_p6_zm_buildable_pswitch_hand", "targetname" ) show();
    getent( "powerswitch_p6_zm_buildable_pswitch_body", "targetname" ) show();
    getent( "powerswitch_p6_zm_buildable_pswitch_lever", "targetname" ) show();
}

// QOL stuff :D
spawn_on_join()
{
    level endon("end_game");
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
    if (isdefined(level.zombie_weapons[weapon]))
    {
        return true;
    }

    return false;
}

changerank(index, custom)
{
    if (!isdefined(custom))
        custom = false;

    if (isdefined(custom) && !custom)
    {
        if (!isdefined(index)) // random
        {
            rankindex = randomintrange(0, 5);
            self.killcam_rank = "zombies_rank_" + rankindex;
            self iprintln("killcam rank set to random rank ^1" + rankindex);
        }
        else // index specified
        {
            self.killcam_rank = "zombies_rank_" + index;
            self iprintln("killcam rank set to rank ^1" + index);
        }
    }
    else if (isdefined(custom) && custom)
    {
        self.killcam_rank = index;
        self iprintln("killcam rank set to rank ^1" + index);
    }
}