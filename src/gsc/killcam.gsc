/*

    killcam related stuff

*/

init_killcam()
{
    level.in_final_killcam = false;

    level.finalkillcamsettings = [];
    initfinalkillcamteam("none");
    foreach(team in level.teams)
    {
        initfinalkillcamteam(team);
    }
    level.finalkillcam_winner = undefined;

    level thread do_final_killcam();
}

callbackactorkilled_stub(einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime)
{
    // call original
    thread [[level.callbackactorkilled_og]](einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime);

    if (self == attacker)
        return;
    if (!isplayer(attacker))
        return;

    attacker = updateattacker(attacker, sweapon);
    if (!isplayer(attacker))
        return;

    einflictor = updateinflictor(einflictor);

    killcamentity = self getkillcamentity(attacker, einflictor, sweapon);
    killcamentityindex = -1;
    killcamentitystarttime = 0;
    if (isdefined(killcamentity))
    {
        killcamentityindex = killcamentity getentitynumber();
        if (isdefined(killcamentity.starttime))
            killcamentitystarttime = killcamentity.starttime;
        else
            killcamentitystarttime = killcamentity.birthtime;

        if (!isdefined(killcamentitystarttime))
            killcamentitystarttime = 0;
    }

    lpattacknum = attacker getentitynumber();
    deathtimeoffset = 0;
    self.deathtime = getTime();
    willrespawnimmediately = 0;

    perks = [];

    level.last_attacker = attacker;
    level thread record_killcam_settings(lpattacknum, self getentitynumber(), sweapon, self.deathtime, deathtimeoffset, psoffsettime, killcamentityindex, killcamentitystarttime, perks, attacker);
}

record_killcam_settings(spectatorclient, targetentityindex, sweapon, deathtime, deathtimeoffset, offsettime, entityindex, entitystarttime, perks, attacker)
{
    if (level.teambased && isdefined(attacker.team) && isdefined(level.teams[attacker.team]))
    {
        team = attacker.team;
        level.finalkillcamsettings[team].spectatorclient = spectatorclient;
        level.finalkillcamsettings[team].weapon = sweapon;
        level.finalkillcamsettings[team].deathtime = deathtime;
        level.finalkillcamsettings[team].deathtimeoffset = deathtimeoffset;
        level.finalkillcamsettings[team].offsettime = offsettime;
        level.finalkillcamsettings[team].entityindex = entityindex;
        level.finalkillcamsettings[team].targetentityindex = targetentityindex;
        level.finalkillcamsettings[team].entitystarttime = entitystarttime;
        level.finalkillcamsettings[team].perks = perks;
        level.finalkillcamsettings[team].attacker = attacker;
    }
    level.finalkillcamsettings["none"].spectatorclient = spectatorclient;
    level.finalkillcamsettings["none"].weapon = sweapon;
    level.finalkillcamsettings["none"].deathtime = deathtime;
    level.finalkillcamsettings["none"].deathtimeoffset = deathtimeoffset;
    level.finalkillcamsettings["none"].offsettime = offsettime;
    level.finalkillcamsettings["none"].entityindex = entityindex;
    level.finalkillcamsettings["none"].targetentityindex = targetentityindex;
    level.finalkillcamsettings["none"].entitystarttime = entitystarttime;
    level.finalkillcamsettings["none"].perks = perks;
    level.finalkillcamsettings["none"].attacker = attacker;
}

final_killcam_waiter()
{
    if (!isdefined(level.finalkillcam_winner))
    {
        return;
    }

    level waittill("final_killcam_done");
}

postroundfinalkillcam()
{
    level notify("play_final_killcam");
    maps\mp\gametypes_zm\_globallogic::resetoutcomeforallplayers();
    final_killcam_waiter();
}

do_final_killcam()
{
    level waittill("play_final_killcam");

    level.in_final_killcam = 1;

    winner = "none";
    if (isdefined(level.finalkillcam_winner))
    {
        winner = level.finalkillcam_winner;
    }

    settings = level.finalkillcamsettings[winner];
    if (!isdefined(settings.targetentityindex))
    {
        level notify("final_killcam_done");
        level.in_final_killcam = 0;
        return;
    }

    if (isdefined(settings.attacker))
    {
        maps\mp\_challenges::getfinalkill(level.finalkillcamsettings[winner].attacker);
    }

    visionsetnaked(getdvar("mapname"), 0);

    foreach (player in level.players)
    {
        player closemenu();
        player closeingamemenu();
        player thread final_killcam(winner);
    }

    wait 0.1;

    // wait for all killcams to finish watching killcam
    while (are_any_players_watching())
    {
        wait 0.05;
    }

    level notify("final_killcam_done");
    level.in_final_killcam = 0;
}

are_any_players_watching()
{
    foreach(player in level.players)
    {
        if (is_true(player.killcam))
        {
            return true;
        }
    }
    return false;
}

initfinalkillcamteam(team)
{
    level.finalkillcamsettings[team] = spawnstruct();
    level.finalkillcamsettings[team].spectatorclient = undefined;
    level.finalkillcamsettings[team].weapon = undefined;
    level.finalkillcamsettings[team].deathtime = undefined;
    level.finalkillcamsettings[team].deathtimeoffset = undefined;
    level.finalkillcamsettings[team].offsettime = undefined;
    level.finalkillcamsettings[team].entityindex = undefined;
    level.finalkillcamsettings[team].targetentityindex = undefined;
    level.finalkillcamsettings[team].entitystarttime = undefined;
    level.finalkillcamsettings[team].perks = undefined;
    level.finalkillcamsettings[team].killstreaks = undefined;
    level.finalkillcamsettings[team].attacker = undefined;
}

set_killcam_entity(killcamentityindex, delayms)
{
    self endon("disconnect");
    self endon("end_killcam");
    self endon("spawned");
    if (delayms > 0)
    {
        wait (delayms / 1000);
    }
    self.killcamentity = killcamentityindex;
}

waitkillcamtime()
{
    self endon("disconnect");
    self endon("end_killcam");
    wait (self.killcamlength - 0.05);
    self notify("end_killcam");
}

waitfinalkillcamslowdown(deathtime, starttime)
{
    self endon("disconnect");
    self endon("end_killcam");
    secondsuntildeath = (deathtime - starttime) / 1000;
    deathtime = getTime() + (secondsuntildeath * 1000);
    waitbeforedeath = 1.65;
    maps\mp\_utility::setclientsysstate("levelNotify", "fkcb");
    wait max(0, secondsuntildeath - waitbeforedeath);
    setslowmotion(1, 0.25, waitbeforedeath);
    wait (waitbeforedeath + 0.5);
    setslowmotion(0.25, 1, 1);
    wait 2;
    maps\mp\_utility::setclientsysstate("levelNotify", "fkce");
}

waitteamchangeendkillcam()
{
    self endon("disconnect");
    self endon("end_killcam");
    self waittill("changed_class");
    endkillcam(0);
}

waitskipkillcamsafespawnbutton()
{
    self endon("disconnect");
    self endon("end_killcam");
    while (self fragbuttonpressed())
    {
        wait 0.05;
    }
    while (!self fragbuttonpressed())
    {
        wait 0.05;
    }
    self.wantsafespawn = 1;
    self notify("end_killcam");
}

endkillcam(final)
{
    if (isdefined(self.kc_skiptext))
    {
        self.kc_skiptext.alpha = 0;
    }
    self.killcam = undefined;
    self thread maps\mp\gametypes_zm\_spectating::setspectatepermissions();
}

checkforabruptkillcamend()
{
    self endon("disconnect");
    self endon("end_killcam");
    while (1)
    {
        if (self.archivetime <= 0)
        {
            break;
        }
        wait 0.05;
    }
    self notify("end_killcam");
}

spawnedkillcamcleanup()
{
    self endon("end_killcam");
    self endon("disconnect");
    self waittill("spawned");
    self endkillcam(0);
}

spectatorkillcamcleanup(attacker)
{
    self endon("end_killcam");
    self endon("disconnect");
    attacker endon("disconnect");
    attacker waittill("begin_killcam", attackerkcstarttime);
    waittime = max(0, attackerkcstarttime - self.deathtime - 50);
    wait waittime;
    self endkillcam(0);
}

endedkillcamcleanup()
{
    self endon("end_killcam");
    self endon("disconnect");
    level waittill("game_ended");
    self endkillcam(0);
}

ended_final_killcam_cleanup()
{
    self endon("end_killcam");
    self endon("disconnect");
    level waittill("game_ended");
    self endkillcam(1);
}

cancelkillcamusebutton()
{
    return self usebuttonpressed();
}

cancelkillcamsafespawnbutton()
{
    return self fragbuttonpressed();
}

cancelkillcamcallback()
{
    self.cancelkillcam = 1;
}

cancelkillcamsafespawncallback()
{
    self.cancelkillcam = 1;
    self.wantsafespawn = 1;
}

cancelkillcamonuse()
{
    self thread cancelkillcamonuse_specificbutton(::cancelkillcamusebutton, ::cancelkillcamcallback);
}

cancelkillcamonuse_specificbutton(pressingbuttonfunc, finishedfunc)
{
    self endon("death_delay_finished");
    self endon("disconnect");
    level endon("game_ended");
    for(;;)
    {
        if (!self [[pressingbuttonfunc]]())
        {
            wait 0.05;
            continue;
        }
        buttontime = 0;
        while (self [[pressingbuttonfunc]]())
        {
            buttontime += 0.05;
            wait 0.05;
        }
        if (buttontime >= 0.5)
        {
            continue;
        }
        buttontime = 0;
        while (!(self [[pressingbuttonfunc]]()) && buttontime < 0.5)
        {
            buttontime += 0.05;
            wait 0.05;
        }
        if (buttontime >= 0.5)
        {
            continue;
        }
        else
        {
            self [[finishedfunc]]();
            return;
        }
        wait 0.05;
    }
}

final_killcam(winner)
{
    self endon("disconnect");
    level endon("game_ended");

    attacker = level.finalkillcamsettings[winner].attacker;

    setmatchflag("final_killcam", 1);

    killcamsettings = level.finalkillcamsettings[winner];
    postdeathdelay = (getTime() - killcamsettings.deathtime) / 1000;
    predelay = postdeathdelay + killcamsettings.deathtimeoffset;
    camtime = attacker calc_time(killcamsettings.weapon, killcamsettings.entitystarttime, predelay, 0, undefined);
    postdelay = 2.5;
    killcamoffset = camtime + predelay;
    killcamlength = (camtime + postdelay) - 0.05;
    killcamstarttime = getTime() - (killcamoffset * 1000);
    self notify("begin_killcam", getTime());
    self.sessionstate = "spectator";
    self.spectatorclient = killcamsettings.spectatorclient;
    self.killcamentity = -1;

    if (killcamsettings.entityindex >= 0)
        self thread set_killcam_entity(killcamsettings.entityindex, killcamsettings.entitystarttime - killcamstarttime - 100);

    self.killcamtargetentity = killcamsettings.targetentityindex;
    self.archivetime = killcamoffset;
    self.killcamlength = killcamlength;
    self.psoffsettime = killcamsettings.offsettime;

    self overlay(true, attacker, true); // killcam overlay

    foreach(team in level.teams)
    {
        self allowspectateteam(team, 1);
    }
    self allowspectateteam("freelook", 1);
    self allowspectateteam("none", 1);

    self thread ended_final_killcam_cleanup();

    // wait till the next server frame to allow code a chance to update archivetime if it needs trimming
    wait 0.05;

    if (self.archivetime <= predelay) // if we're not looking back in time far enough to even see the death, cancel
    {
        self.sessionstate = "dead";
        self.spectatorclient = -1;
        self.killcamentity = -1;
        if (is_false(level.skip_game_end))
            self.archivetime = 0;
        self.psoffsettime = 0;
        self overlay(false);
        self notify("end_killcam");
        return;
    }

    self thread checkforabruptkillcamend();

    self.killcam = 1;

    self thread waitkillcamtime();
    self thread waitfinalkillcamslowdown(level.finalkillcamsettings[winner].deathtime, killcamstarttime);

    self waittill("end_killcam");
    self endkillcam(1);

    setmatchflag("final_killcam", 0);
    setmatchflag("round_end_killcam", 0);
}

calc_time(sweapon, entitystarttime, predelay, respawn, maxtime)
{
    camtime = self.killcam_length;
    if (isdefined(maxtime))
    {
        if (camtime > maxtime)
        {
            camtime = maxtime;
        }
        if (camtime < 0.05)
        {
            camtime = 0.05;
        }
    }
    return camtime;
}

// thanks to birchy for this :)
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
            if (attacker.name[i] == "[" && prefix == -1)
            {
                prefix = i;
            }
            else if (attacker.name[i] == "]" && postfix == -1)
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
        self.hud[3] = self shader("CENTER", "CENTER", 5, 188, attacker.killcam_rank, 16, 16, (1, 1, 1), 1, 3); //player rank
        self.hud[4] = self drawtext2(name, "LEFT", "CENTER", -44, 171, 1.20, "default", (1,1,1), 1, 3); //player name
        self.hud[5] = self drawtext2(killcam_type(final), "CENTER", "CENTER", 0, -180, 3.25, "default", (1,1,1), 0.9, 3); //top text
        for(i = 0; i < self.hud.size; i++)
        {
            self.hud[i].foreground = true;
            self.hud[i].hidewhendead = false;
            self.hud[i].hidewheninkillcam = false;
            self.hud[i].archived = false;
        }
    }
    else
    {
        foreach(hud in self.hud)
        {
            hud destroy();
        }
    }
}

killcam_type(final)
{
    if (level.round_based)
        return "ROUND ENDING KILLCAM";

    return "FINAL KILLCAM";
}

changerank(index, custom)
{
    if (!isdefined(custom))
        custom = false;

    if (is_false(custom))
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
    else if (is_true(custom))
    {
        self.killcam_rank = index;
        self iprintln("killcam rank set to rank ^1" + index);
    }
}

changekctime(time, is_default)
{
    if (is_true(is_default))
    {
        self.killcam_length = 5;
        self iprintln("killcam length set to ^15 ^7seconds (^2default^7)");
        return;
    }

    newtime = self.killcam_length + time; // new killcam time
    if (newtime < 5) // disable killcam time going below 5 seconds
    {
        self iprintln("cannot set killcam length below 5 seconds.");
        return;
    }

    self iprintln("killcam length set to ^1" + newtime + " ^7seconds");
    foreach(player in level.players)
    {
        if (self != player)
            player iprintln(self.name + " changed their killcam length to ^1" + newtime + " ^7seconds");
    }
    self.killcam_length = newtime;
}
