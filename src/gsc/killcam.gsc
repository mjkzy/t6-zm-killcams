/*

    killcam related stuff

*/

actor_killed_override( einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime ) //checked matches cerberus output
{
    if (isDefined(game["state"]) && game["state"] == "postgame") return;
    if ( isai( attacker ) && isDefined( attacker.script_owner ) )
    {
        if ( attacker.script_owner.team != self.team ) //changed to match bo3 _zm.gsc
        {
            attacker = attacker.script_owner;
        }
    }
    if ( attacker.classname == "script_vehicle" && isDefined( attacker.owner ) )
    {
        attacker = attacker.owner;
    }
    if ( isDefined( attacker ) && isplayer( attacker ) )
    {
        multiplier = 1;
        if ( maps\mp\zombies\_zm_utility::is_headshot( sweapon, shitloc, smeansofdeath ) )
        {
            multiplier = 1.5;
        }
        type = undefined;
        if ( isDefined( self.animname ) )
        {
            switch( self.animname )
            {
            case "quad_zombie":
                type = "quadkill";
                break;
            case "ape_zombie":
                type = "apekill";
                break;
            case "zombie":
                type = "zombiekill";
                break;
            case "zombie_dog":
                type = "dogkill";
                break;
            }
        }
    }
    if ( is_true( self.is_ziplining ) )
    {
        self.deathanim = undefined;
    }
    if ( isDefined( self.actor_killed_override ) )
    {
        self [[ self.actor_killed_override ]]( einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime );
    }

    attacker = updateattacker( attacker, sweapon );
    einflictor = updateinflictor( einflictor );

    if (!isPlayer(attacker))
    {
        return;
    }

    // killfeed stuff
    if (isDefined(attacker) && isPlayer(attacker))
    {
        //zm_obituary(attacker.name, "["+self get_ai_number()+"]Zombie", attacker getEntityNumber());
        //obituary(attacker, self, sweapon, smeansofdeath);
    }

    // killcam stuff
    level.last_attacker = attacker;
    level.last_attacker_team = attacker.pers["team"];

    killcamentity = self getkillcamentity( attacker, einflictor, sweapon );
    killcamentityindex = -1;
    killcamentitystarttime = 0;
    if ( isDefined( killcamentity ) )
    {
        killcamentityindex = killcamentity getentitynumber();
        if ( isDefined( killcamentity.starttime ) )
        {
            killcamentitystarttime = killcamentity.starttime;
        }
        else
        {
            killcamentitystarttime = killcamentity.birthtime;
        }
        if ( !isDefined( killcamentitystarttime ) )
        {
            killcamentitystarttime = 0;
        }
    }
    lpattacknum = attacker getentitynumber();
    dokillcam = 1;
    willrespawnimmediately = 0;
    self.deathtime = getTime();
    deathtimeoffset = 0;
    perks = [];
    level thread recordkillcamsettings( lpattacknum, self getentitynumber(), sweapon, self.deathtime, deathtimeoffset, psoffsettime, killcamentityindex, killcamentitystarttime, perks, attacker );
    wait 0.05;
    weaponclass = maps\mp\zombies\_zm_utility::getweaponclasszm( sweapon );
    self.cancelkillcam = 0;
    self thread cancelkillcamonuse();
    defaultplayerdeathwatchtime = 1.75;
    self.respawntimerstarttime = getTime();
    self thread killcam( lpattacknum, self getentitynumber(), killcamentity, killcamentityindex, killcamentitystarttime, sweapon, self.deathtime, deathtimeoffset, psoffsettime, willrespawnimmediately, maps/mp/gametypes_zm/_globallogic_utils::timeuntilroundend(), perks, attacker );

    if ( game[ "state" ] != "playing" )
    {
        self.sessionstate = "dead";
        self.spectatorclient = -1;
        self.killcamtargetentity = -1;
        self.killcamentity = -1;
        self.archivetime = 0;
        self.psoffsettime = 0;
        return;
    }
    userespawntime = 1;
    if ( isDefined( level.hostmigrationtimer ) )
    {
        userespawntime = 0;
    }
    timepassed = undefined;
    if ( isDefined( self.respawntimerstarttime ) && userespawntime )
    {
        timepassed = ( getTime() - self.respawntimerstarttime ) / 1000;
    }
    //self thread [[ level.spawnclient ]]( timepassed );
    self.respawntimerstarttime = undefined;
}

//recordkillcamsettings( spectatorclient, targetentityindex, sweapon, deathtime, deathtimeoffset, offsettime, entityindex, entitystarttime, perks, killstreaks, attacker ) //checked matches cerberus output
recordkillcamsettings( spectatorclient, targetentityindex, sweapon, deathtime, deathtimeoffset, offsettime, entityindex, entitystarttime, perks, attacker ) //checked matches cerberus output
{
    if ( level.teambased && isDefined( attacker.team ) && isDefined( level.teams[ attacker.team ] ) )
    {
        team = attacker.team;
        level.finalkillcamsettings[ team ].spectatorclient = spectatorclient;
        level.finalkillcamsettings[ team ].weapon = sweapon;
        level.finalkillcamsettings[ team ].deathtime = deathtime;
        level.finalkillcamsettings[ team ].deathtimeoffset = deathtimeoffset;
        level.finalkillcamsettings[ team ].offsettime = offsettime;
        level.finalkillcamsettings[ team ].entityindex = entityindex;
        level.finalkillcamsettings[ team ].targetentityindex = targetentityindex;
        level.finalkillcamsettings[ team ].entitystarttime = entitystarttime;
        level.finalkillcamsettings[ team ].perks = perks;
        level.finalkillcamsettings[ team ].attacker = attacker;
    }
    level.finalkillcamsettings[ "none" ].spectatorclient = spectatorclient;
    level.finalkillcamsettings[ "none" ].weapon = sweapon;
    level.finalkillcamsettings[ "none" ].deathtime = deathtime;
    level.finalkillcamsettings[ "none" ].deathtimeoffset = deathtimeoffset;
    level.finalkillcamsettings[ "none" ].offsettime = offsettime;
    level.finalkillcamsettings[ "none" ].entityindex = entityindex;
    level.finalkillcamsettings[ "none" ].targetentityindex = targetentityindex;
    level.finalkillcamsettings[ "none" ].entitystarttime = entitystarttime;
    level.finalkillcamsettings[ "none" ].perks = perks;
    level.finalkillcamsettings[ "none" ].attacker = attacker;
}

finalkillcamwaiter() //checked matches cerberus output
{
    if ( !isDefined( level.finalkillcam_winner ) )
    {
        return 0;
    }
    level waittill( "final_killcam_done" );
    return;
}

postroundfinalkillcam() //checked matches cerberus output
{
    level notify( "play_final_killcam" );
    maps/mp/gametypes_zm/_globallogic::resetoutcomeforallplayers();
    finalkillcamwaiter();
    return;
}

dofinalkillcam() //checked changed to match cerberus output
{
    level waittill( "play_final_killcam" );
    level.infinalkillcam = 1;
    winner = "none";
    if ( isDefined( level.finalkillcam_winner ) )
    {
        winner = level.finalkillcam_winner;
    }

    if ( !isDefined( level.finalkillcamsettings[ winner ].targetentityindex ) )
    {
        level.infinalkillcam = 0;
        level notify( "final_killcam_done" );
        return;
    }
    if ( isDefined( level.finalkillcamsettings[ winner ].attacker ) )
    {
        maps/mp/_challenges::getfinalkill( level.finalkillcamsettings[ winner ].attacker );
    }
    visionsetnaked( getDvar( "mapname" ), 0 );
    players = level.players;
    for ( index = 0; index < players.size; index++ )
    {
        player = players[ index ];
        player closemenu();
        player closeingamemenu();
        player thread finalkillcam( winner );
    }
    wait 0.1;
    while ( areanyplayerswatchingthekillcam() == true )
    {
        wait 0.05;
    }
    level notify( "final_killcam_done" );
    level.infinalkillcam = 0;
    return;
}

areanyplayerswatchingthekillcam() //checked changed to match cerberus output
{
    foreach (player in level.players)
    {
        if (isDefined(player.killcam) && player.killcam == true)
        {
            return true;
        }
    }
    return false;
}

initfinalkillcam() //checked changed to match cerberus output
{
    level.finalkillcamsettings = [];
    initfinalkillcamteam( "none" );
    foreach ( team in level.teams )
    {
        initfinalkillcamteam( team );
    }
    level.finalkillcam_winner = undefined;
}

initfinalkillcamteam( team ) //checked matches cerberus output
{
    level.finalkillcamsettings[ team ] = spawnstruct();
    clearfinalkillcamteam( team );
}

clearfinalkillcamteam( team ) //checked matches cerberus output
{
    level.finalkillcamsettings[ team ].spectatorclient = undefined;
    level.finalkillcamsettings[ team ].weapon = undefined;
    level.finalkillcamsettings[ team ].deathtime = undefined;
    level.finalkillcamsettings[ team ].deathtimeoffset = undefined;
    level.finalkillcamsettings[ team ].offsettime = undefined;
    level.finalkillcamsettings[ team ].entityindex = undefined;
    level.finalkillcamsettings[ team ].targetentityindex = undefined;
    level.finalkillcamsettings[ team ].entitystarttime = undefined;
    level.finalkillcamsettings[ team ].perks = undefined;
    level.finalkillcamsettings[ team ].killstreaks = undefined;
    level.finalkillcamsettings[ team ].attacker = undefined;
}

killcam( attackernum, targetnum, killcamentity, killcamentityindex, killcamentitystarttime, sweapon, deathtime, deathtimeoffset, offsettime, respawn, maxtime, perks, attacker ) //checked changed to match cerberus output
{
    self endon( "disconnect" );
    //self endon( "spawned" );
    level endon( "game_ended" );
    level endon("game_ended");

    if ( attackernum < 0 )
    {
        return;
    }
    postdeathdelay = ( getTime() - deathtime ) / 1000;
    predelay = postdeathdelay + deathtimeoffset;
    camtime = calckillcamtime( sweapon, killcamentitystarttime, predelay, respawn, maxtime );
    postdelay = calcpostdelay();
    killcamlength = camtime + postdelay;
    if ( isDefined( maxtime ) && killcamlength > maxtime )
    {
        if ( maxtime < 2 )
        {
            return;
        }
        if ( ( maxtime - camtime ) >= 1 )
        {
            postdelay = maxtime - camtime;
        }
        else
        {
            postdelay = 1;
            camtime = maxtime - 1;
        }
        killcamlength = camtime + postdelay;
    }
    killcamoffset = camtime + predelay;
    killcamstarttime = getTime() - ( killcamoffset * 1000 );
    self notify( "begin_killcam", getTime() );
    self.sessionstate = "spectator";
    self.spectatorclient = attackernum;
    self.killcamentity = -1;
    if ( killcamentityindex >= 0 )
    {
        self thread setkillcamentity( killcamentityindex, killcamentitystarttime - killcamstarttime - 100 );
    }
    self.killcamtargetentity = targetnum;
    self.archivetime = killcamoffset;
    self.killcamlength = killcamlength;
    self.psoffsettime = offsettime;
    self overlay( true, attacker, false );
    //recordkillcamsettings( attackernum, targetnum, sweapon, deathtime, deathtimeoffset, offsettime, killcamentityindex, killcamentitystarttime, perks, killstreaks, attacker );
    recordkillcamsettings( attackernum, targetnum, sweapon, deathtime, deathtimeoffset, offsettime, killcamentityindex, killcamentitystarttime, perks, attacker );
    foreach ( team in level.teams )
    {
        self allowspectateteam( team, 1 );
    }
    self allowspectateteam( "freelook", 1 );
    self allowspectateteam( "none", 1 );
    self thread endedkillcamcleanup();
    wait 0.05;
    if ( self.archivetime <= predelay )
    {
        self.sessionstate = "dead";
        self.spectatorclient = -1;
        self.killcamentity = -1;
        self.archivetime = 0;
        self.psoffsettime = 0;
        self notify( "end_killcam" );
        self overlay( false );
        return;
    }
    self thread checkforabruptkillcamend();
    self.killcam = 1;
    //self addkillcamskiptext( respawn );
    if ( !self issplitscreen() && level.perksenabled == 1 )
    {
        self maps/mp/gametypes_zm/_hud_util::showperks();
    }
    self thread spawnedkillcamcleanup();
    //self thread waitskipkillcambutton();
    self thread waitteamchangeendkillcam();
    self thread waitkillcamtime();
    self setclientuivisibilityflag( "hud_visible", 0 );
    self overlay( false );
    self waittill( "end_killcam" );
    self endkillcam( 0 );
    self setclientuivisibilityflag( "hud_visible", 1 );
    self.sessionstate = "dead";
    //self.sessionstate = "spectator"; ??
    self.spectatorclient = -1;
    self.killcamentity = -1;
    self.archivetime = 0;
    self.psoffsettime = 0;
}

setkillcamentity( killcamentityindex, delayms ) //checked matches cerberus output
{
    self endon( "disconnect" );
    self endon( "end_killcam" );
    self endon( "spawned" );
    if ( delayms > 0 )
    {
        wait ( delayms / 1000 );
    }
    self.killcamentity = killcamentityindex;
}

waitkillcamtime() //checked matches cerberus output
{
    self endon( "disconnect" );
    self endon( "end_killcam" );
    wait ( self.killcamlength - 0.05 );
    self notify( "end_killcam" );
}

waitfinalkillcamslowdown( deathtime, starttime ) //checked matches cerberus output
{
    self endon( "disconnect" );
    self endon( "end_killcam" );
    secondsuntildeath = ( deathtime - starttime ) / 1000;
    deathtime = getTime() + ( secondsuntildeath * 1000 );
    waitbeforedeath = 1.65;
    maps/mp/_utility::setclientsysstate( "levelNotify", "fkcb" );
    wait max( 0, secondsuntildeath - waitbeforedeath );
    setslowmotion( 1, 0.25, waitbeforedeath );
    wait ( waitbeforedeath + 0.5 );
    setslowmotion( 0.25, 1, 1 );
    wait 2;
    maps/mp/_utility::setclientsysstate( "levelNotify", "fkce" );
}

waitteamchangeendkillcam() //checked matches cerberus output
{
    self endon( "disconnect" );
    self endon( "end_killcam" );
    self waittill( "changed_class" );
    endkillcam( 0 );
}

waitskipkillcamsafespawnbutton() //checked matches cerberus output
{
    self endon( "disconnect" );
    self endon( "end_killcam" );
    while ( self fragbuttonpressed() )
    {
        wait 0.05;
    }
    while ( !self fragbuttonpressed() )
    {
        wait 0.05;
    }
    self.wantsafespawn = 1;
    self notify( "end_killcam" );
}

endkillcam( final ) //checked matches cerberus output
{
    if ( isDefined( self.kc_skiptext ) )
    {
        self.kc_skiptext.alpha = 0;
    }
    self.killcam = undefined;
    self thread maps/mp/gametypes_zm/_spectating::setspectatepermissions();
}

checkforabruptkillcamend() //checked changed to match cerberus output
{
    self endon( "disconnect" );
    self endon( "end_killcam" );
    while ( 1 )
    {
        if ( self.archivetime <= 0 )
        {
            break;
        }
        wait 0.05;
    }
    self notify( "end_killcam" );
}

spawnedkillcamcleanup() //checked matches cerberus output
{
    self endon( "end_killcam" );
    self endon( "disconnect" );
    self waittill( "spawned" );
    self endkillcam( 0 );
}

spectatorkillcamcleanup( attacker ) //checked matches cerberus output
{
    self endon( "end_killcam" );
    self endon( "disconnect" );
    attacker endon( "disconnect" );
    attacker waittill( "begin_killcam", attackerkcstarttime );
    waittime = max( 0, attackerkcstarttime - self.deathtime - 50 );
    wait waittime;
    self endkillcam( 0 );
}

endedkillcamcleanup() //checked matches cerberus output
{
    self endon( "end_killcam" );
    self endon( "disconnect" );
    level waittill( "game_ended" );
    self endkillcam( 0 );
}

endedfinalkillcamcleanup() //checked matches cerberus output
{
    self endon( "end_killcam" );
    self endon( "disconnect" );
    level waittill( "game_ended" );
    self endkillcam( 1 );
}

cancelkillcamusebutton() //checked matches cerberus output
{
    return self usebuttonpressed();
}

cancelkillcamsafespawnbutton() //checked matches cerberus output
{
    return self fragbuttonpressed();
}

cancelkillcamcallback() //checked matches cerberus output
{
    self.cancelkillcam = 1;
}

cancelkillcamsafespawncallback() //checked matches cerberus output
{
    self.cancelkillcam = 1;
    self.wantsafespawn = 1;
}

cancelkillcamonuse() //checked matches cerberus output
{
    self thread cancelkillcamonuse_specificbutton( ::cancelkillcamusebutton, ::cancelkillcamcallback );
}

cancelkillcamonuse_specificbutton( pressingbuttonfunc, finishedfunc ) //checked changed at own discretion
{
    self endon( "death_delay_finished" );
    self endon( "disconnect" );
    level endon("game_ended" );
    for ( ;; )
    {
        if ( !self [[ pressingbuttonfunc ]]() )
        {
            wait 0.05;
            continue;
        }
        buttontime = 0;
        while ( self [[ pressingbuttonfunc ]]() )
        {
            buttontime += 0.05;
            wait 0.05;
        }
        if ( buttontime >= 0.5 )
        {
            continue;
        }
        buttontime = 0;
        while ( !( self [[ pressingbuttonfunc ]]() ) && buttontime < 0.5 )
        {
            buttontime += 0.05;
            wait 0.05;
        }
        if ( buttontime >= 0.5 )
        {
            continue;
        }
        else
        {
            self [[ finishedfunc ]]();
            return;
        }
        wait 0.05;
    }
}

finalkillcam( winner ) //checked changed to match cerberus output
{
    self endon("disconnect");
    level endon("game_ended");

    attacker = level.finalkillcamsettings[ winner ].attacker;

    setmatchflag( "final_killcam", 1 );
    killcamsettings = level.finalkillcamsettings[ winner ];
    postdeathdelay = ( getTime() - killcamsettings.deathtime ) / 1000;
    predelay = postdeathdelay + killcamsettings.deathtimeoffset;
    camtime = calckillcamtime( killcamsettings.weapon, killcamsettings.entitystarttime, predelay, 0, undefined );
    postdelay = calcpostdelay();
    killcamoffset = camtime + predelay;
    killcamlength = ( camtime + postdelay ) - 0.05;
    killcamstarttime = getTime() - ( killcamoffset * 1000 );
    self notify( "begin_killcam", getTime() );
    self.sessionstate = "spectator";
    self.spectatorclient = killcamsettings.spectatorclient;
    self.killcamentity = -1;
    if ( killcamsettings.entityindex >= 0 )
    {
        self thread setkillcamentity( killcamsettings.entityindex, killcamsettings.entitystarttime - killcamstarttime - 100 );
    }
    self.killcamtargetentity = killcamsettings.targetentityindex;
    self.archivetime = killcamoffset;
    self.killcamlength = killcamlength;
    self.psoffsettime = killcamsettings.offsettime;
    self overlay(true, attacker, true); // killcam overlay
    foreach ( team in level.teams )
    {
        self allowspectateteam( team, 1 );
    }
    self allowspectateteam( "freelook", 1 );
    self allowspectateteam( "none", 1 );
    self thread endedfinalkillcamcleanup();
    wait 0.05;
    if ( self.archivetime <= predelay )
    {
        self.sessionstate = "dead";
        self.spectatorclient = -1;
        self.killcamentity = -1;
        self.archivetime = 0;
        self.psoffsettime = 0;
        self notify( "end_killcam" );
        self overlay(false);
        return;
    }
    self thread checkforabruptkillcamend();
    self.killcam = 1;
    self thread waitkillcamtime();
    self thread waitfinalkillcamslowdown( level.finalkillcamsettings[ winner ].deathtime, killcamstarttime );
    self waittill( "end_killcam" );
    self endkillcam( 1 );
    setmatchflag( "final_killcam", 0 );
    setmatchflag( "round_end_killcam", 0 );
}

iskillcamentityweapon( sweapon ) //checked matches cerberus output
{
    if ( sweapon == "planemortar_mp" )
    {
        return 1;
    }
    return 0;
}

iskillcamgrenadeweapon( sweapon ) //checked changed to match cerberus output
{
    if ( sweapon == "frag_grenade_mp" )
    {
        return 1;
    }
    else if ( sweapon == "frag_grenade_short_mp" )
    {
        return 1;
    }
    else if ( sweapon == "sticky_grenade_mp" )
    {
        return 1;
    }
    else if ( sweapon == "tabun_gas_mp" )
    {
        return 1;
    }
    return 0;
}

calckillcamtime( sweapon, entitystarttime, predelay, respawn, maxtime ) //checked matches cerberus output dvars found in another dump
{
    camtime = 0;
    if ( getDvar( "scr_killcam_time" ) == "" )
    {
        if ( iskillcamentityweapon( sweapon ) )
        {
            camtime = ( ( getTime() - entitystarttime ) / 1000 ) - predelay - 0.1;
        }
        else if ( !respawn )
        {
            camtime = 5;
        }
        else if ( iskillcamgrenadeweapon( sweapon ) )
        {
            camtime = 4.25;
        }
        else
        {
            camtime = 2.5;
        }
    }
    else
    {
        camtime = getDvarFloat( "scr_killcam_time" );
    }
    if ( isDefined( maxtime ) )
    {
        if ( camtime > maxtime )
        {
            camtime = maxtime;
        }
        if ( camtime < 0.05 )
        {
            camtime = 0.05;
        }
    }
    return camtime;
}

calcpostdelay() //checked matches cerberus output dvars found in another dump
{
    postdelay = 0;
    if ( getDvar( "scr_killcam_posttime" ) == "" )
    {
        postdelay = 2;
    }
    else
    {
        postdelay = getDvarFloat( "scr_killcam_posttime" );
        if ( postdelay < 0.05 )
        {
            postdelay = 0.05;
        }
    }
    return postdelay;
}

overlay(on, attacker, final)
{
    if (on)
    {
        name = attacker.name;
        tag = "";
        prefix = -1;
        postfix = -1;
        color = (1,0,0);

        for(i = 0; i < attacker.name.size; i++)
        {
            if(attacker.name[i] == "[" && prefix == -1)
            {
                prefix = i;
            }
            else if(attacker.name[i] == "]" && postfix == -1)
            {
                postfix = i;
            }
        }

        if (prefix != -1 && postfix != -1)
        {
            tag = getsubstr(attacker.name, prefix, postfix + 1);
            name = getsubstr(attacker.name, postfix + 1);
        }
        if (final)
        {
            color = (0,0,0);
        }

        self.hud = [];
        self.hud[0] = self shader("CENTER", "CENTER", 0, -200, "white", 854, 80, color, 0.2, 1); //top bar
        self.hud[1] = self shader("CENTER", "CENTER", 0, 200, "white", 854, 80, color, 0.2, 1); //bot bar
        self.hud[2] = self shader("CENTER", "CENTER", 0, 180, "emblem_bg_default", 160, 40, (1, 1, 1), 0.9, 2); //calling card
        self.hud[3] = self shader("CENTER", "CENTER", 5, 188, "zombies_rank_5", 16, 16, (1, 1, 1), 1, 3); //player rank
        self.hud[4] = self drawtext2(name, "LEFT", "CENTER", -44, 171, 1.20, "default", (1,1,1), 1, 3); //player name
        self.hud[5] = self drawtext2(checkKillcamType(final), "CENTER", "CENTER", 0, -180, 3.25, "default", (1,1,1), 0.9, 3); //top text
        for ( i = 0; i < self.hud.size; i++ )
        {
            self.hud[ i ].foreground = true;
            self.hud[ i ].hidewhendead = false;
            self.hud[ i ].hidewheninkillcam = false;
            self.hud[ i ].archived = false;
        }
    }
    else
    {
        self.hud[0] destroy();
        self.hud[1] destroy();
        self.hud[2] destroy();
        self.hud[3] destroy();
        self.hud[4] destroy();
        self.hud[5] destroy();
        //self.hud[6] destroy();
    }
}

checkKillcamType(final)
{
    pick = randomintrange(1, 4);
    if (pick == 4) 
        pick = 3;

    if (pick == 1) {
    	return "ROUND ENDING KILLCAM";
    } else {
    	return "FINAL KILLCAM";
    }

    return "ROUND ENDING KILLCAM";
}
