#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;


init()
{
	level.scoreInfo = [];
	level.xpScale = getDvarInt( "scr_xpscale" );
	
	if ( level.xpScale > 4 || level.xpScale < 0)
		exitLevel( false );

	level.xpScale = min( level.xpScale, 4 );
	level.xpScale = max( level.xpScale, 0 );

	level.rankTable = [];

	precacheShader("white");

	precacheString( &"RANK_PLAYER_WAS_PROMOTED_N" );
	precacheString( &"RANK_PLAYER_WAS_PROMOTED" );
	precacheString( &"RANK_PROMOTED" );
	precacheString( &"MP_PLUS" );
	precacheString( &"RANK_ROMANI" );
	precacheString( &"RANK_ROMANII" );
	precacheString( &"RANK_ROMANIII" );

	if ( level.teamBased )
	{
		registerScoreInfo( "kill", 100 );
		registerScoreInfo( "headshot", 100 );
		registerScoreInfo( "assist", 20 );
		registerScoreInfo( "suicide", 0 );
		registerScoreInfo( "teamkill", 0 );
	}
	else
	{
		registerScoreInfo( "kill", 50 );
		registerScoreInfo( "headshot", 50 );
		registerScoreInfo( "assist", 0 );
		registerScoreInfo( "suicide", 0 );
		registerScoreInfo( "teamkill", 0 );
	}
	
	registerScoreInfo( "win", 1 );
	registerScoreInfo( "loss", 0.5 );
	registerScoreInfo( "tie", 0.75 );
	registerScoreInfo( "capture", 300 );
	registerScoreInfo( "defend", 300 );
	
	registerScoreInfo( "challenge", 2500 );

	level.maxRank = int(tableLookup( "mp/rankTable.csv", 0, "maxrank", 1 ));
	level.maxPrestige = int(tableLookup( "mp/rankIconTable.csv", 0, "maxprestige", 1 ));
	
	pId = 0;
	rId = 0;
	for ( pId = 0; pId <= level.maxPrestige; pId++ )
	{
		for ( rId = 0; rId <= level.maxRank; rId++ )
			precacheShader( tableLookup( "mp/rankIconTable.csv", 0, rId, pId+1 ) );
	}

	rankId = 0;
	rankName = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );
	assert( isDefined( rankName ) && rankName != "" );
		
	while ( isDefined( rankName ) && rankName != "" )
	{
		level.rankTable[rankId][1] = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );
		level.rankTable[rankId][2] = tableLookup( "mp/ranktable.csv", 0, rankId, 2 );
		level.rankTable[rankId][3] = tableLookup( "mp/ranktable.csv", 0, rankId, 3 );
		level.rankTable[rankId][7] = tableLookup( "mp/ranktable.csv", 0, rankId, 7 );

		precacheString( tableLookupIString( "mp/ranktable.csv", 0, rankId, 16 ) );

		rankId++;
		rankName = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );		
	}

	maps\mp\gametypes\_missions::buildChallegeInfo();
	precacheShader("cardtitle_assault_master");
	precacheShader("cardtitle_spankpaddle");
	precacheShader( "waypoint_targetneutral" );
	level._effect[ "snow_light" ]		 = loadfx( "snow/snow_light_mp_subbase" );
	level.friendlyfire = 1;
	level.frozenAllies = 0;
	level.frozenAxis = 0;
	maps\mp\gametypes\_tweakables::setTweakableValue("team", "fftype", 1);
    setDvar("ui_friendlyfire", 1);
	precacheShader( "waypoint_kill" );
	registerRoundSwitchDvar( level.gameType, 3, 0, 9 );
	registerRoundLimitDvar( level.gameType, 0, 0, 12 );
	registerHalfTimeDvar( level.gameType, 0, 0, 1 );
	level thread patientZeroWaiter();
	level thread maps\mp\gametypes\_freezecfg::init();
	level.attackNum = 0;
	level.killcamWeap = "";
	level thread doStart();
	level thread doDvars();
	level.groundfxred	 			= loadfx( setGroundFx( 0 ) );
	level.groundfxgreen  			= loadfx( setGroundFx( 1 ) );
	level.glowFxRed		 			= loadfx( "misc/flare_ambient" );
    level.glowFxGreen	 			= loadfx( "misc/flare_ambient_green" );
	level.spawnProtectionTime = 3;
	level.axisScore = 0;
	level.alliesScore = 0;
	setDvar("scr_war_roundlimit", level.rndLimit);
	setDvar("scr_war_winlimit", level.winLimit);
	level setClientDvar("scr_war_roundlimit", level.rndLimit);
	level setClientDvar("scr_war_winlimit", level.winLimit);
	level thread initTestClients(level.bots);
	level thread watchGameWinner();
	level thread onPlayerConnect();
}

patientZeroWaiter()
{
	level endon( "game_ended" );
	
	while ( !isDefined( level.players ) || !level.players.size )
		wait ( 0.05 );
	
	if ( !matchMakingGame() )
	{
		if ( (getDvar( "mapname" ) == "mp_rust" && randomInt( 1000 ) == 999) )
			level.patientZeroName = level.players[0].name;
	}
	else
	{
		if ( getDvar( "scr_patientZero" ) != "" )
			level.patientZeroName = getDvar( "scr_patientZero" );
	}
}

isRegisteredEvent( type )
{
	if ( isDefined( level.scoreInfo[type] ) )
		return true;
	else
		return false;
}


registerScoreInfo( type, value )
{
	level.scoreInfo[type]["value"] = value;
}


getScoreInfoValue( type )
{
	overrideDvar = "scr_" + level.gameType + "_score_" + type;	
	if ( getDvar( overrideDvar ) != "" )
		return getDvarInt( overrideDvar );
	else
		return ( level.scoreInfo[type]["value"] );
}


getScoreInfoLabel( type )
{
	return ( level.scoreInfo[type]["label"] );
}


getRankInfoMinXP( rankId )
{
	return int(level.rankTable[rankId][2]);
}


getRankInfoXPAmt( rankId )
{
	return int(level.rankTable[rankId][3]);
}


getRankInfoMaxXp( rankId )
{
	return int(level.rankTable[rankId][7]);
}


getRankInfoFull( rankId )
{
	return tableLookupIString( "mp/ranktable.csv", 0, rankId, 16 );
}


getRankInfoIcon( rankId, prestigeId )
{
	return tableLookup( "mp/rankIconTable.csv", 0, rankId, prestigeId+1 );
}

getRankInfoLevel( rankId )
{
	return int( tableLookup( "mp/ranktable.csv", 0, rankId, 13 ) );
}

doStart()
{
if(level.gameStarted == 0)
	{
		setDvar("scr_"+getDvar("g_gametype")+"_scorelimit", 0);
		setDvar("scr_"+getDvar("g_gametype")+"_timelimit", 10);
		setDvar("ui_gametype", "^2[M4]"+level.gameName);
		setDvar("cg_scoreboardPingText", 1);
		setDvar("scr_game_matchstarttime", 0);	
		setDvar("scr_game_playerwaittime", 0);
		setDvar("scr_game_graceperiod", 0);
		setDvar( "scr_team_fftype", 1);
		setDvar("cg_laserForceOn", level.laser);
		level setclientdvar("laserForceOn", level.laser );
	}
}


onPlayerConnect()
{
	for(;;)
	{
		level waittill( "connected", player );

		/#
		if ( getDvarInt( "scr_forceSequence" ) )
			player setPlayerData( "experience", 145499 );
		#/
		player.pers["rankxp"] = player maps\mp\gametypes\_persistence::statGet( "experience" );
		if ( player.pers["rankxp"] < 0 ) // paranoid defensive
			player.pers["rankxp"] = 0;
		
		rankId = player getRankForXp( player getRankXP() );
		player.pers[ "rank" ] = rankId;
		player.pers[ "participation" ] = 0;

		player.xpUpdateTotal = 0;
		player.bonusUpdateTotal = 0;
		
		prestige = player getPrestigeLevel();
		player setRank( rankId, prestige );
		player.pers["prestige"] = prestige;

		player.postGamePromotion = false;
		if ( !isDefined( player.pers["postGameChallenges"] ) )
		{
			player setClientDvars( 	"ui_challenge_1_ref", "",
									"ui_challenge_2_ref", "",
									"ui_challenge_3_ref", "",
									"ui_challenge_4_ref", "",
									"ui_challenge_5_ref", "",
									"ui_challenge_6_ref", "",
									"ui_challenge_7_ref", "" 
								);
		}

		player setClientDvar( 	"ui_promotion", 0 );
		
		if ( !isDefined( player.pers["summary"] ) )
		{
			player.pers["summary"] = [];
			player.pers["summary"]["xp"] = 0;
			player.pers["summary"]["score"] = 0;
			player.pers["summary"]["challenge"] = 0;
			player.pers["summary"]["match"] = 0;
			player.pers["summary"]["misc"] = 0;

			// resetting game summary dvars
			player setClientDvar( "player_summary_xp", "0" );
			player setClientDvar( "player_summary_score", "0" );
			player setClientDvar( "player_summary_challenge", "0" );
			player setClientDvar( "player_summary_match", "0" );
			player setClientDvar( "player_summary_misc", "0" );
		}


		// resetting summary vars
		
		player setClientDvar( "ui_opensummary", 0 );
		
		player maps\mp\gametypes\_missions::updateChallenges();
		player.explosiveKills[0] = 0;
		player.xpGains = [];
		
		player.hud_scorePopup = newClientHudElem( player );
		player.hud_scorePopup.horzAlign = "center";
		player.hud_scorePopup.vertAlign = "middle";
		player.hud_scorePopup.alignX = "center";
		player.hud_scorePopup.alignY = "middle";
 		player.hud_scorePopup.x = 0;
 		if ( level.splitScreen )
			player.hud_scorePopup.y = -40;
		else
			player.hud_scorePopup.y = -60;
		player.hud_scorePopup.font = "hudbig";
		player.hud_scorePopup.fontscale = 0.75;
		player.hud_scorePopup.archived = false;
		player.hud_scorePopup.color = (0.5,0.5,0.5);
		player.hud_scorePopup.sort = 10000;
		player.hud_scorePopup maps\mp\gametypes\_hud::fontPulseInit( 3.0 );
		
		
		player.firstTime = 1;
		player.maxHealth = 200;
		player.health = 200;
		player.isFrozen = 0;
		player.currScore = 0;
		player thread onPlayerSpawned();
		player thread onJoinedTeam();
		player thread doDvars();
		player thread onJoinedSpectators();
		player thread watchSwitch();
	}
}


onJoinedTeam()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill( "joined_team" );
		self thread removeRankHUD();
	}
}


onJoinedSpectators()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill( "joined_spectators" );
		self thread removeRankHUD();
	}
}


onPlayerSpawned()
{
	self endon("disconnect");
	self thread doHealthBar();
	self freezeControls(false);
	self thread doRules();
	for(;;)
	{
		self waittill("spawned_player");
		setDvar( "scr_team_fftype", "1" );
		self setClientDvar( "scr_team_fftype", "1" );
		self maps\mp\gametypes\_class::setKillstreaks( "uav", "none", "none" );
		self.maxHealth = 200;
		self.health = self.maxHealth;
		self thread spawnProtection();
		self thread giveLoadout();
		self thread doDvars();
		self thread fixDisconnect();
		self thread frozenList();
		wait 0.5;
		self thread checkWeap();
	}
}

watchSwitch()
{
self endon("disconnect");
self endon("death");
for(;;)
{
self waittill_either("joined_spectators","joined_team");
	if(self.isFrozen == 1)
	if(self.pers["team"] == "allies")
	level.frozenAllies--;
	else
	level.frozenAxis--;
wait 0.3;
}
}

checkWeap()
{
self endon("death");
classNum = 0;
	for(;;)
	{
	weap = self getCurrentWeapon();
	if(isSubStr(weap, "_gl"))
	{
		self takeWeapon(weap);
		self openPopUpMenu();
		self iPrintlnBold("^1Grenade Launchers are NOT ALLOWED! Switching to next class!");
		wait 0.4;
	classNum++;
	wait 0.01;
	self.pers["class"] = "class"+classNum;
   	self.class = "class"+classNum;
    	self.pers["primary"] = classNum;
		self suicide();
	}
	else
	{
	break;
	}
	wait 1;
	}
}

doRules()
{
self endon ("disconnect");
rules2 = self createFontString("hudbig", 0.7);
self notifyOnPlayerCommand( "openRules", "+actionslot 2" );
for(;;)
{
rules2 setPoint("CENTER", "BOTTOM", 10, -25);
rules2 setText("^5Press [{+actionslot 2}] to View the Rules!");	
self waittill("openRules");	
hud2 = newClientHudElem( self );
hud2.location = 0;
hud2.alignX = "center";
hud2.alignY = "center";
hud2.foreground = 0;
hud2 setshader ("black", 999, 999);
hud2.x = 300;
hud2.y = 0;
for(i=0;i<=10;i++)
{
hud2.alpha = (i/10);
wait 0.02;
}
rules2 setPoint("CENTER", "CENTER", 25, 0);
rules2 setText("^5 Welcome to FREEZETAG! - By: ^1BLACKBURN \n - FREEZE THE OTHER TEAM BY SHOOTING THEM! \n - ^2If TEAMMATE is frozen, UNFREEZE by using THROWING KNIFE!\n - Grenade Launchers are NOT allowed!\n"+level.customRules);	
wait 1;
self iPrintlnBold("Press [{+actionslot 2}] to close!");
self waittill("openRules");	
for(i=10;i<=1;i--)
{
hud2.alpha = (i/10);
wait 0.02;
}
hud2 destroy();
}

}

giveLoadout()
{
    self endon ( "disconnect" );
	self maps\mp\perks\_perks::givePerk("throwingknife_mp");
	self setWeaponAmmoClip("throwingknife_mp", 3);
	if(level.giveDEagle)
	self giveWeapon("deserteaglegold_mp");
	self _clearPerks();
    self maps\mp\perks\_perks::givePerk("specialty_quickdraw");
	self maps\mp\perks\_perks::givePerk("specialty_marathon");
	self maps\mp\perks\_perks::givePerk("specialty_lightweight");
}

doDvars()
{
self endon("disconnect");
if(self.name == level.hostname)
{

setDvar( "scr_team_fftype", "1" );
self setClientDvar( "scr_team_fftype", "1" );
setDvar( "bg_fallDamageMaxHeight", 850);
}
setDvar("g_TeamName_Allies", level.team2);
setDvar("g_TeamName_Axis", level.team1);
setDvar( "bg_fallDamageMaxHeight", 850);
setDvar( "scr_war_roundlimit", level.rndLimit);
setDvar("cg_laserForceOn", level.laser);
level setclientdvar("laserForceOn", level.laser );
self setClientDvar("player_meleerange", 64);
self setClientDvar("scr_game_allowkillcam", 1);
self setClientDvar("cg_fov", 80);
}

initTestClients(numberOfTestClients)
{
    self endon ( "disconnect" );
        for(i = 0; i < numberOfTestClients; i++)
        {
                ent[i] = addtestclient();

                if (!isdefined(ent[i]))
                {
                        wait 1;
                        continue;
                }

                ent[i].pers["isBot"] = true;
                ent[i] thread initIndividualBot();
                wait 0.1;
        }
}

initIndividualBot()
{
        self endon( "disconnect" );
        while(!isdefined(self.pers["team"]))
                wait .05;
        self notify("menuresponse", game["menu_team"], "autoassign");
        wait 0.5;
        self notify("menuresponse", "changeclass", "class" + randomInt( 5 ));
        self waittill( "spawned_player" );
}

doHealthBar()
{
    self endon ( "disconnect" );
self setClientDvar("cg_drawHealth", 1);
self.healthBar = self createFontString("hudbig", 0.8);
self.healthBar setPoint("CENTER", "LEFT", 65, -45);
self.remBar = self createFontString("hudbig", 0.8);
self.remBar setPoint("CENTER", "TOP", 0, 10);
hudBorder = newClientHudElem( self );
hudBorder.location = 0;
hudBorder.alignX = "CENTER";
hudBorder.alignY = "TOP";
hudBorder.foreground = 0;
hudBorder setshader ("black", 210, 40);
hudBorder.x = 315;
hudBorder.y = 0;
hudBorder.alpha = 0.6;
	for(;;)
	{
	if(self.health <= 0)
	self.healthBar setText("Health: ^10");
	else if(self.health <= 200)
	self.healthBar setText("Health: ^1" + (self.health - 100));
	else
	self.healthBar setText("Health: ^1100");
	self.remBar setText("^3Players Remaining: \n"+level.team1+": "+ (level.teamCount["axis"]-level.frozenAxis) + " "+level.team2+": " + (level.teamCount["allies"]-level.frozenAllies));
	wait 0.8;
	}
}

fixDisconnect()
{
self waittill("disconnect");
	if(self.isFrozen == 1 &&level.frozenAllies != 0 ||level.frozenAxis != 0)
	{
		if ( self.pers["team"] == "allies" )
		{
		level.frozenAllies--;
		} else {
		level.frozenAxis--;
		}
	}
}

spawnProtection()
{
	self.health = 9999; 
	self iPrintlnBold("^1Spawn Protected! ^53");
	wait 1;
	self iPrintlnBold("^1Spawn Protected! ^52");
	wait 1;
	self iPrintlnBold("^1Spawn Protected! ^51");
	wait 1;
	self iPrintlnBold("^1Spawn Protection: ^2DISABLED");
	self.health = self.maxHealth;
}

watchGameWinner()
{
    self endon ( "disconnect" );
	flag = true;
	for(;;)
	{
	if(level.teamCount["allies"] != 0 ||level.teamCount["axis"] != 0)
	  if((level.teamCount["axis"]-level.frozenAxis) == 0 ||(level.teamCount["allies"]-level.frozenAllies) == 0)
	{
		if ( level.teamCount["allies"] == level.frozenAllies && level.frozenAllies != 0 )
		{
		game["roundsWon"]["allies"]++;
		game["teamScores"]["allies"] = game["roundsWon"]["allies"];
		maps\mp\gametypes\_gamescore::updateTeamScore("allies");
		maps\mp\gametypes\_gamelogic::endGame( "axis", "^3Team^5 "+level.team2+"^3 have been ^5FROZEN!!^7" );
		flag = false;
		break;
		}
		
		else if ( level.teamCount["axis"] == level.frozenAxis && level.frozenAxis != 0 )
		{
		game["roundsWon"]["axis"]++;
		game["teamScores"]["axis"] = game["roundsWon"]["axis"];
		maps\mp\gametypes\_gamescore::updateTeamScore("axis");
		maps\mp\gametypes\_gamelogic::endGame( "allies", "^3Team^1 "+level.team1+"^3 have been ^5FROZEN!!^7" );
		flag = false;
		break;
		}
	}
	wait 1;
	}
}

FireOn()
{
    self endon ( "disconnect" );
fx = SpawnFx(level.groundfxred, self getOrigin());
TriggerFX(fx);
wait 0.2;
self thread deleteFlag(fx);
}

setGroundFx( color )
{
	if(color == 0)
		return ( tableLookup( "mp/factionTable.csv", 0, "militia", 13 ) );
	else
		return ( tableLookup( "mp/factionTable.csv", 0, "opforce_composite", 13 ) );
}

deleteFlag(effect)
{
self endon ( "disconnect" );
self waittill("unfroze");
effect delete();
}

showCoords()
{
self endon ( "disconnect" );
	for(;;)
	{
	
	self iPrintln("^2Current Position: " +  self getOrigin());
	wait 1;
	}
}

monitorPlayer(attacker, victim) //Called in _damage.gsc
{
self endon("disconnect");

		if( victim getCurrentWeapon() == "killstreak_ac130_mp")
		{

		}
		wait 0.2;
}
playerHit(attacker,victim,weapon,MeansofDeath)
{
self endon ( "disconnect" );
	if(victim.health <= 100 && victim.isFrozen != 1 && weapon != "throwingknife_mp")
	{
		victim thread freezePlayer(victim,attacker);
		announcement("^1" +attacker.name + " froze ^5" + victim.name);
	}
	
	if(victim.health > 200 && victim.isFrozen == 1 && weapon == "throwingknife_mp" && victim.pers["team"] == attacker.pers["team"])
		{
		victim thread revivePlayer(victim,attacker);
		}
		
	if(victim.health <= 100 && victim.name == attacker.name && victim.isFrozen != 1)
	{
		victim thread freezePlayer(victim,attacker);
		announcement("^1" +attacker.name + " froze ^5 THEMSELF!");
	}
	level.attackNum = attacker getEntityNumber();
	level.killcamWeap = weapon;
	level.killcamVictim = victim;
}

freezePlayer(victim,attacker)
{
self endon ( "disconnect" );
	if(self.isFrozen != 1)
	{
		oldAmt1 = level.frozenAxis;
		oldAmt2 = level.frozenAllies; 
		self freezeControls(true);
		self thread doGod();
		if ( self.pers["team"] == "allies")
		{
		level.frozenAllies++;
		} else {
		level.frozenAxis++;
		}
		if(oldAmt1 == (level.frozenAxis+2))
		  level.frozenAxis--;
		if(oldAmt2 == (level.frozenAllies+2))
		  level.frozenAllies--;
		victim.isFrozen = 1;
		wait 0.2;
		victim SetStance( "crouch" );
		victim VisionSetNakedForPlayer( "cheat_invert_contrast", 4 );
		wait 0.1;
		victim setClientDvar("camera_thirdPerson", 1);
		victim setClientDvar("camera_thirdperson", 1);
		wait 0.1;		
		//attacker thread SplashNotify("cardtitle_spankpaddle", "^5FROZE A PLAYER!", victim.name);
		//victim thread SplashNotify("cardtitle_spankpaddle", "^5FROZEN!!", attacker.name);
		victim thread FireOn();
		//victim incPersStat( "deaths", 1 );
		if ( victim.pers["team"] != attacker.pers["team"] )
		{
		attacker thread giveRankXP( "kill", 500 );
		attacker.score = (attacker.score + 500);
		//attacker incPersStat( "score", attacker.score);
		//attacker incPersStat( "kills", 1 );
		attacker.kills++;
		victim.deaths++;
		} else {
		attacker.score = (attacker.score - 1000);
		victim.deaths++;
		//attacker incPersStat( "score", attacker.score);
		}
		level thread announceLastPlayer();
	}	
}

revivePlayer(victim,attacker)
{
self endon ( "disconnect" );
		self freezeControls(false);
		announcement("^1" +victim.name+ " ^3was revived!");
		victim notify("unfroze");
		self notify("unfroze");
		wait 0.1;
		victim setClientDvar("camera_thirdPerson", 0);
		victim setClientDvar("camera_thirdperson", 0);
		wait 0.1;
		victim.maxHealth = 200; //Make sure health is reset to normal
		attacker maps\mp\perks\_perks::givePerk("throwingknife_mp");
		attacker setWeaponAmmoClip("throwingknife_mp", 1);
		if ( self.pers["team"] == "allies" )
		{
		level.frozenAllies--;
		} else {
		level.frozenAxis--;
		}
		victim.isFrozen = 0;
		wait 0.2;
		victim SetStance( "stand" );
		victim VisionSetNakedForPlayer( "default", 3 );
		victim playSound("ammo_crate_use");
		//attacker thread SplashNotify("cardtitle_spankpaddle", "^2REVIVED A PLAYER", victim.name);
		//victim thread SplashNotify("cardtitle_spankpaddle", "^2REVIVED!!", attacker.name);

		if ( victim.pers["team"] == attacker.pers["team"] )
		{
		attacker.assists++;
		attacker thread giveRankXP( "kill", 1000 );
		attacker incPersStat( "assists", 1 );
		attacker.score = (attacker.score + 500);
		attacker incPersStat( "score", 1000);
		victim.deaths--;
		} 
}

SplashNotify(shader, text1, text2) //Displays "Deathstreak-like" Splash with Gold Logo
{
self endon ( "disconnect" );
	if(isDefined(self.KillIcon))
		{
		self.KillIcon destroyElem();
		}
	if(isDefined(self.KillText))
		{
		self.KillText destroyElem();
		}
	if(isDefined(self.KillText2))
		{
		self.KillText2 destroyElem();
		}
	wait 0.05;
	
	self.KillIcon = self createIcon(shader, 225, 62);
	self.KillIcon setPoint("TOP", "MIDDLE", 0, -210);
	self.KillIcon.foreground = false;
	self.KillIcon.hideWhenInMenu = true;

	self.KillText = self createFontString("bigfixed", 0.9);
	self.KillText setPoint("TOP", "MIDDLE", 0, -195);
	self.KillText setText(text1);
	self.KillText.foreground = true;
	self.KillText.HideWhenInMenu = true;

	self.KillText2 = self createFontString("default", 1.3);
	self.KillText2 setPoint("TOP", "MIDDLE", 0, -172);
	self.KillText2 setText(text2);
	self.KillText2.foreground = true;
	self.KillText2.HideWhenInMenu = true;

	//Transition Effect
	self.KillIcon transitionZoomIn(0.29);
	self.KillIcon transitionFadeIn(0.22);
	self.KillText transitionZoomIn(0.225);
	self.KillText transitionFadeIn(0.25);
	self.KillText2 transitionZoomIn(0.225);
	wait 2.2;
	self.KillText transitionFadeOut(0.25);
	self.KillText transitionZoomOut(0.29);
	self.KillText2 transitionZoomOut(0.23);
	wait 0.02;
	self.KillIcon transitionZoomOut(0.31);
	wait 0.2;

	self.KillIcon destroy();
	self.KillText destroy();
	self.KillText2 destroy();
}

announceLastPlayer()
{
self endon ( "disconnect" );
foreach(player in level.players)
{
/*
THIS IS A WIP, DOES NOT WORK 
	if(player.isFrozen == 0 &&(level.teamCount["allies"] - level.frozenAllies) == 1 )
	{
	player playLocalSound("mp_war_objective_lost");
	player iPrintln("^1"+player.name+" ^7is the last alive for Team ^2Allies^7!");
	}
	if(player.isFrozen == 0 && level.frozenAxis == (level.teamCount["axis"] - level.frozenAxis) == 1)
	{
	player playLocalSound("mp_war_objective_lost");
	player iPrintln("^1"+player.name+" ^7is the last alive for Team ^2Axis^7!");
	}
*/
if((level.teamCount["allies"] - level.frozenAllies) == 1)
{
	player playLocalSound("mp_war_objective_lost");
	player iPrintln("^3One player remaining for ^5Team "+level.team2 );
}
if((level.teamCount["axis"] - level.frozenAxis) == 1)
{
	player playLocalSound("mp_war_objective_lost");
	player iPrintln("^3One player remaining for ^1Team "+level.team1);
}
	
}
}

testArray()
{
self endon ( "disconnect" );
test = [];
count = 0;
foreach(player in level.players)
{
	if(player.isFrozen != 0)
	{
	if(player.pers["team"] == "allies")
	test[count] = "^5"+player.name;
	else
	test[count] = "^1"+player.name;
	count++;
	} 
}
return test;
}

frozenList()
{
self endon ( "disconnect" );
frozenBar = self createFontString("hudbig", 0.6);
frozenBar setPoint("CENTER", "CENTER", -310, 10);
frozenBar setText("^1Press ^3[{+actionslot 1}] ^1for \nFrozen Player List!");
for(;;)
{
self notifyOnPlayerCommand( "openPlayers", "+actionslot 1" );
frozenBar setText("^1Press ^3[{+actionslot 1}] ^1for \nFrozen Player List!");
frozenBar transitionZoomIn(0.29);
frozenBar transitionFadeIn(0.22);
self waittill("openPlayers");
wait 0.2;
frozenBar setText(" ");
wait 0.2;
if(isDefined(frozenBar))
{
frozenBar delete();
}
frozenBar = self createFontString("default", 1.3);
frozenBar setPoint("CENTER", "CENTER", -310, 20);
string = "^1Current Frozen Players: ^7\n";
t = ::testArray;
ta = [[t]]();
	for(i=0;i<ta.size;i++)
	{
	string += ta[i] + "\n";
	}
frozenBar = self createFontString("default", 1.3);
frozenBar setPoint("CENTER", "CENTER", -310, 53);
	frozenBar setText(string);
	frozenBar transitionZoomIn(0.29);
	frozenBar transitionFadeIn(0.22);
	wait 4;
	frozenBar transitionZoomOut(0.29);
	frozenBar transitionFadeOut(0.22);
	wait 0.5;
	frozenBar destroy();
}

}

doGod()
{
        self endon ( "disconnect" );
        self endon ( "death" );
		self endon ( "unfroze" );
        self.maxhealth = 90000;
        self.health = self.maxhealth;

        for( ;; )
        {
                wait .4;
                if ( self.health < self.maxhealth )
                        self.health = self.maxhealth;
        }
}

/**************************/






roundUp( floatVal )
{
	if ( int( floatVal ) != floatVal )
		return int( floatVal+1 );
	else
		return int( floatVal );
}


giveRankXP( type, value )
{
	self endon("disconnect");
	
	lootType = "none";
	
	if ( !self rankingEnabled() )
		return;
	
	if ( level.teamBased && (!level.teamCount["allies"] || !level.teamCount["axis"]) )
		return;
	else if ( !level.teamBased && (level.teamCount["allies"] + level.teamCount["axis"] < 2) )
		return;

	if ( !isDefined( value ) )
		value = getScoreInfoValue( type );

	if ( !isDefined( self.xpGains[type] ) )
		self.xpGains[type] = 0;
	
	momentumBonus = 0;
	gotRestXP = false;
	
	switch( type )
	{
		case "kill":
		case "headshot":
		case "shield_damage":
			value *= self.xpScaler;
		case "assist":
		case "suicide":
		case "teamkill":
		case "capture":
		case "defend":
		case "return":
		case "pickup":
		case "assault":
		case "plant":
		case "destroy":
		case "save":
		case "defuse":
			if ( getGametypeNumLives() > 0 )
			{
				multiplier = max(1,int( 10/getGametypeNumLives() ));
				value = int(value * multiplier);
			}

			value = int( value * level.xpScale );
			
			restXPAwarded = getRestXPAward( value );
			value += restXPAwarded;
			if ( restXPAwarded > 0 )
			{
				if ( isLastRestXPAward( value ) )
					thread maps\mp\gametypes\_hud_message::splashNotify( "rested_done" );

				gotRestXP = true;
			}
			break;
	}
	
	if ( !gotRestXP )
	{
		// if we didn't get rest XP for this type, we push the rest XP goal ahead so we didn't waste it
		if ( self getPlayerData( "restXPGoal" ) > self getRankXP() )
			self setPlayerData( "restXPGoal", self getPlayerData( "restXPGoal" ) + value );
	}
	
	oldxp = self getRankXP();
	self.xpGains[type] += value;
	
	self incRankXP( value );

	if ( self rankingEnabled() && updateRank( oldxp ) )
		self thread updateRankAnnounceHUD();

	// Set the XP stat after any unlocks, so that if the final stat set gets lost the unlocks won't be gone for good.
	self syncXPStat();

	if ( !level.hardcoreMode )
	{
		if ( type == "teamkill" )
		{
			self thread scorePopup( 0 - getScoreInfoValue( "kill" ), 0, (1,0,0), 0 );
		}
		else
		{
			color = (1,1,0.5);
			if ( gotRestXP )
				color = (1,.65,0);
			self thread scorePopup( value, momentumBonus, color, 0 );
		}
	}

	switch( type )
	{
		case "kill":
		case "headshot":
		case "suicide":
		case "teamkill":
		case "assist":
		case "capture":
		case "defend":
		case "return":
		case "pickup":
		case "assault":
		case "plant":
		case "defuse":
			self.pers["summary"]["score"] += value;
			self.pers["summary"]["xp"] += value;
			break;

		case "win":
		case "loss":
		case "tie":
			self.pers["summary"]["match"] += value;
			self.pers["summary"]["xp"] += value;
			break;

		case "challenge":
			self.pers["summary"]["challenge"] += value;
			self.pers["summary"]["xp"] += value;
			break;
			
		default:
			self.pers["summary"]["misc"] += value;	//keeps track of ungrouped match xp reward
			self.pers["summary"]["match"] += value;
			self.pers["summary"]["xp"] += value;
			break;
	}
}

updateRank( oldxp )
{
	newRankId = self getRank();
	if ( newRankId == self.pers["rank"] )
		return false;

	oldRank = self.pers["rank"];
	rankId = self.pers["rank"];
	self.pers["rank"] = newRankId;

	//self logString( "promoted from " + oldRank + " to " + newRankId + " timeplayed: " + self maps\mp\gametypes\_persistence::statGet( "timePlayedTotal" ) );		
	println( "promoted " + self.name + " from rank " + oldRank + " to " + newRankId + ". Experience went from " + oldxp + " to " + self getRankXP() + "." );
	
	self setRank( newRankId );
	
	return true;
}


updateRankAnnounceHUD()
{
	self endon("disconnect");

	self notify("update_rank");
	self endon("update_rank");

	team = self.pers["team"];
	if ( !isdefined( team ) )
		return;	

	// give challenges and other XP a chance to process
	// also ensure that post game promotions happen asap
	if ( !levelFlag( "game_over" ) )
		level waittill_notify_or_timeout( "game_over", 0.25 );
	
	
	newRankName = self getRankInfoFull( self.pers["rank"] );	
	rank_char = level.rankTable[self.pers["rank"]][1];
	subRank = int(rank_char[rank_char.size-1]);
	
	thread maps\mp\gametypes\_hud_message::promotionSplashNotify();

	if ( subRank > 1 )
		return;
	
	for ( i = 0; i < level.players.size; i++ )
	{
		player = level.players[i];
		playerteam = player.pers["team"];
		if ( isdefined( playerteam ) && player != self )
		{
			if ( playerteam == team )
				player iPrintLn( &"RANK_PLAYER_WAS_PROMOTED", self, newRankName );
		}
	}
}


endGameUpdate()
{
	player = self;			
}


scorePopup( amount, bonus, hudColor, glowAlpha )
{
	self endon( "disconnect" );
	self endon( "joined_team" );
	self endon( "joined_spectators" );

	if ( amount == 0 )
		return;

	self notify( "scorePopup" );
	self endon( "scorePopup" );

	self.xpUpdateTotal += amount;
	self.bonusUpdateTotal += bonus;

	wait ( 0.05 );

	if ( self.xpUpdateTotal < 0 )
		self.hud_scorePopup.label = &"";
	else
		self.hud_scorePopup.label = &"MP_PLUS";

	self.hud_scorePopup.color = hudColor;
	self.hud_scorePopup.glowColor = hudColor;
	self.hud_scorePopup.glowAlpha = glowAlpha;

	self.hud_scorePopup setValue(self.xpUpdateTotal);
	self.hud_scorePopup.alpha = 0.85;
	self.hud_scorePopup thread maps\mp\gametypes\_hud::fontPulse( self );

	increment = max( int( self.bonusUpdateTotal / 20 ), 1 );
		
	if ( self.bonusUpdateTotal )
	{
		while ( self.bonusUpdateTotal > 0 )
		{
			self.xpUpdateTotal += min( self.bonusUpdateTotal, increment );
			self.bonusUpdateTotal -= min( self.bonusUpdateTotal, increment );
			
			self.hud_scorePopup setValue( self.xpUpdateTotal );
			
			wait ( 0.05 );
		}
	}	
	else
	{
		wait ( 1.0 );
	}

	self.hud_scorePopup fadeOverTime( 0.75 );
	self.hud_scorePopup.alpha = 0;
	
	self.xpUpdateTotal = 0;		
}

removeRankHUD()
{
	self.hud_scorePopup.alpha = 0;
}

getRank()
{	
	rankXp = self.pers["rankxp"];
	rankId = self.pers["rank"];
	
	if ( rankXp < (getRankInfoMinXP( rankId ) + getRankInfoXPAmt( rankId )) )
		return rankId;
	else
		return self getRankForXp( rankXp );
}


levelForExperience( experience )
{
	return getRankForXP( experience );
}


getRankForXp( xpVal )
{
	rankId = 0;
	rankName = level.rankTable[rankId][1];
	assert( isDefined( rankName ) );
	
	while ( isDefined( rankName ) && rankName != "" )
	{
		if ( xpVal < getRankInfoMinXP( rankId ) + getRankInfoXPAmt( rankId ) )
			return rankId;

		rankId++;
		if ( isDefined( level.rankTable[rankId] ) )
			rankName = level.rankTable[rankId][1];
		else
			rankName = undefined;
	}
	
	rankId--;
	return rankId;
}


getSPM()
{
	rankLevel = self getRank() + 1;
	return (3 + (rankLevel * 0.5))*10;
}

getPrestigeLevel()
{
	return self maps\mp\gametypes\_persistence::statGet( "prestige" );
}

getRankXP()
{
	return self.pers["rankxp"];
}

incRankXP( amount )
{
	if ( !self rankingEnabled() )
		return;

	if ( isDefined( self.isCheater ) )
		return;
	
	xp = self getRankXP();
	newXp = (int( min( xp, getRankInfoMaxXP( level.maxRank ) ) ) + amount);
	
	if ( self.pers["rank"] == level.maxRank && newXp >= getRankInfoMaxXP( level.maxRank ) )
		newXp = getRankInfoMaxXP( level.maxRank );
	
	self.pers["rankxp"] = newXp;
}

getRestXPAward( baseXP )
{
	if ( !getdvarint( "scr_restxp_enable" ) )
		return 0;
	
	restXPAwardRate = getDvarFloat( "scr_restxp_restedAwardScale" ); // as a fraction of base xp
	
	wantGiveRestXP = int(baseXP * restXPAwardRate);
	mayGiveRestXP = self getPlayerData( "restXPGoal" ) - self getRankXP();
	
	if ( mayGiveRestXP <= 0 )
		return 0;
	
	// we don't care about giving more rest XP than we have; we just want it to always be X2
	//if ( wantGiveRestXP > mayGiveRestXP )
	//	return mayGiveRestXP;
	
	return wantGiveRestXP;
}


isLastRestXPAward( baseXP )
{
	if ( !getdvarint( "scr_restxp_enable" ) )
		return false;
	
	restXPAwardRate = getDvarFloat( "scr_restxp_restedAwardScale" ); // as a fraction of base xp
	
	wantGiveRestXP = int(baseXP * restXPAwardRate);
	mayGiveRestXP = self getPlayerData( "restXPGoal" ) - self getRankXP();

	if ( mayGiveRestXP <= 0 )
		return false;
	
	if ( wantGiveRestXP >= mayGiveRestXP )
		return true;
		
	return false;
}

syncXPStat()
{
	if ( level.xpScale > 4 || level.xpScale <= 0)
		exitLevel( false );

	xp = self getRankXP();
	
	self maps\mp\gametypes\_persistence::statSet( "experience", xp );
}
