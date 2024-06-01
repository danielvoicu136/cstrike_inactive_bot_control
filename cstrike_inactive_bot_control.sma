#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <engine>
#include <fun>

// Configs 

#define PLUGIN_REMINDER 45.0					// How many seconds to next chat info message   
#define PLUGIN_TAG "!g[REPLACE - Press E]"  	// Tag for chat message 
#define MAX_CONTROL 20   						// How many times players can control others  
#define MAX_CAMP_AFK 50							// How fast it will be marked as inactive  	

// Plugin Utils 

#define PLUGIN_NAME		"Inactive Player and Bot Control Replacer"
#define PLUGIN_VERSION	"1.3"
#define PLUGIN_AUTHOR	"Daniel" 

#define MAX_PLAYERS				32

#define fm_user_has_shield(%1)			(get_pdata_int(%1, OFFSET_SHIELD) & HAS_SHIELD)
#define fm_get_user_team(%1)			get_pdata_int(%1, OFFSET_TEAM)
#define fm_set_user_team(%1,%2)			set_pdata_int(%1, OFFSET_TEAM, %2)  

#define OFFSET_SHIELD				510
#define HAS_SHIELD				(1<<24)

#define m_rgAmmo_player_Slot0			376
#define OFFSET_TEAM				114
#define OFFSET_ARMOR_TYPE    			112
#define m_iClip					51
#define m_iPrimaryAmmoType			49
#define XTRA_OFS_PLAYER  			5
#define XTRA_OFS_WEAPON				4
#define OBS_IN_EYE 				4

#define TERRORISTS				1
#define CTS					2

#define MAX_GLOCK18_BPAMMO			40
#define MAX_USP_BPAMMO				24

new const Float:g_fSizes[][3] =
{ 
	{0.0, 0.0, 1.0}, {0.0, 0.0, -1.0}, {0.0, 1.0, 0.0}, {0.0, -1.0, 0.0}, {1.0, 0.0, 0.0}, {-1.0, 0.0, 0.0}, {-1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, -1.0, 1.0}, {1.0, 1.0, -1.0}, {-1.0, -1.0, 1.0}, {1.0, -1.0, -1.0}, {-1.0, 1.0, -1.0}, {-1.0, -1.0, -1.0},
	{0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0},
	{0.0, 0.0, 3.0}, {0.0, 0.0, -3.0}, {0.0, 3.0, 0.0}, {0.0, -3.0, 0.0}, {3.0, 0.0, 0.0}, {-3.0, 0.0, 0.0}, {-3.0, 3.0, 3.0}, {3.0, 3.0, 3.0}, {3.0, -3.0, 3.0}, {3.0, 3.0, -3.0}, {-3.0, -3.0, 3.0}, {3.0, -3.0, -3.0}, {-3.0, 3.0, -3.0}, {-3.0, -3.0, -3.0},
	{0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0},
	{0.0, 0.0, 5.0}, {0.0, 0.0, -5.0}, {0.0, 5.0, 0.0}, {0.0, -5.0, 0.0}, {5.0, 0.0, 0.0}, {-5.0, 0.0, 0.0}, {-5.0, 5.0, 5.0}, {5.0, 5.0, 5.0}, {5.0, -5.0, 5.0}, {5.0, 5.0, -5.0}, {-5.0, -5.0, 5.0}, {5.0, -5.0, -5.0}, {-5.0, 5.0, -5.0}, {-5.0, -5.0, -5.0}
}

const INVALID_WEAPONS =				(1 << CSW_KNIFE)|(1 << CSW_C4)|(1 << CSW_HEGRENADE)|(1 << CSW_FLASHBANG)|(1 << CSW_SMOKEGRENADE)

new bool:g_bRoundEnded

new g_iPlayerControl[MAX_PLAYERS + 1]
new g_iPlayerTeam[MAX_PLAYERS + 1]
new bool:g_bPlayerInactive[MAX_PLAYERS + 1]

#define TASKID_CHECKCAMPING		858

new bool:ChangeLevel = false, StandardDeviation[33], Meter[33], CheckCampingTime[33]
new CoordsBody[33][4][3], CoordsEyes[33][4][3]


public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR) 

	register_cvar("inactive_bot_control", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY)
		
	register_forward(FM_CmdStart, "CmdStart", ._post=true)
	
	register_logevent("joinTeam", 3, "1=joined team")
	register_logevent("roundEnd", 2, "1=Round_End")
	
	register_logevent("LOGEVENT_RoundStart", 2, "1=Round_Start");
	register_logevent("LOGEVENT_RoundEnd", 2, "1=Round_End");
	
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_event("TextMsg", "event_round_restart", "a", "2&#Game_C", "2&#Game_w")
	
	set_task(PLUGIN_REMINDER, "send_reminder", 0, "", 0, "b");
	
}

public client_putinserver(id)
{

	g_iPlayerControl[id] = 0
	g_iPlayerTeam[id] = 0
	
}

public joinTeam() 
{
	new szLogUser[80], szName[MAX_PLAYERS]
	read_logargv(0, szLogUser, charsmax(szLogUser))
	parse_loguser(szLogUser, szName, charsmax(szName))

	new szTeam[2], iPlayer = get_user_index(szName)
	read_logargv(2, szTeam, charsmax(szTeam))
	switch(szTeam[0])
	{
		case 'T' :	g_iPlayerTeam[iPlayer] = TERRORISTS
		case 'C' :	g_iPlayerTeam[iPlayer] = CTS
		case 'S' :	g_iPlayerTeam[iPlayer] = 0
	}
} 

public event_round_restart()
{
	static iPlayers[MAX_PLAYERS]
	new iNum
	get_players(iPlayers, iNum)
	for(new i, iPlayer;i < iNum;i++)
	{
		g_iPlayerControl[iPlayer] = 0
		g_bPlayerInactive[iPlayer] = false
	}
}
	
public event_round_start()
{
	g_bRoundEnded = false
	
	static iPlayers[MAX_PLAYERS]
	new iNum
	get_players(iPlayers, iNum)
	for(new i, iPlayer;i < iNum;i++)
	{
		iPlayer = iPlayers[i]
		if(g_iPlayerControl[iPlayer] > 0)
		{
			g_iPlayerControl[iPlayer] = 0
			g_bPlayerInactive[iPlayer] = false
		}
	}
}

public roundEnd()
{
	g_bRoundEnded = true
}

public CmdStart(iPlayer, userCmdHandle, randomSeed) 
{
	if(is_user_alive(iPlayer) || !(TERRORISTS <= get_user_team(iPlayer) <= CTS))
		return FMRES_IGNORED

	if(g_bRoundEnded)
		return FMRES_IGNORED
			
	static iButton;
	iButton = get_uc(userCmdHandle, UC_Buttons)
	if((iButton & IN_USE) && (pev(iPlayer, pev_iuser1) == OBS_IN_EYE))
	{
		if(g_iPlayerControl[iPlayer] >= MAX_CONTROL)
			return FMRES_IGNORED
		
		ControlReplacer(iPlayer)
		set_uc(userCmdHandle, UC_Buttons, (iButton & ~IN_USE) & ~IN_USE)
		return FMRES_IGNORED
	}
	return FMRES_IGNORED
}

ControlReplacer(iPlayer)
{
	static iTarget;
	iTarget = entity_get_int(iPlayer, EV_INT_iuser2)
	
	if(is_user_bot(iTarget) || g_bPlayerInactive[iTarget])
	{
			
		if(g_iPlayerTeam[iPlayer] != get_user_team(iTarget))
			return PLUGIN_HANDLED
		
		static Float:fPlane[3], Float:fOrigin[3], Float:fVelocity[3]
		entity_get_vector(iTarget, EV_VEC_angles, fPlane)
		entity_get_vector(iTarget, EV_VEC_origin, fOrigin)
		entity_get_vector(iTarget, EV_VEC_velocity, fVelocity)
		
		ExecuteHamB(Ham_CS_RoundRespawn, iPlayer)
		attach_view(iPlayer, iTarget)
		
		entity_set_vector(iPlayer, EV_VEC_origin, fOrigin)
		entity_set_vector(iPlayer, EV_VEC_angles, fPlane)
		entity_set_vector(iPlayer, EV_VEC_velocity, fVelocity)
		entity_set_vector(iTarget, EV_VEC_origin, Float:{9999.0, 9999.0, 9999.0})
		
			checkPlayerInvalidOrigin(iPlayer)
		
			strip_user_weapons(iPlayer)
			give_item(iPlayer, "weapon_knife")
		
			static szWeaponName[20]
			for(new iWeapon = CSW_P228, iAmmoType, iAmmo, iMagazine;iWeapon <= CSW_P90; iWeapon++)
			{
				if(INVALID_WEAPONS & (1 << iWeapon))
					continue
			
				if(user_has_weapon(iTarget, iWeapon))
				{
					get_weaponname(iWeapon, szWeaponName, charsmax(szWeaponName))
					
					new iWeaponEntity = find_ent_by_owner(-1, szWeaponName, iTarget)
					if(iWeaponEntity > 0)
					{
						iAmmoType = m_rgAmmo_player_Slot0 + get_pdata_int(iWeaponEntity, m_iPrimaryAmmoType, XTRA_OFS_WEAPON)
						iAmmo = get_pdata_int(iWeaponEntity, m_iClip, XTRA_OFS_WEAPON)
						iMagazine = get_pdata_int(iTarget, iAmmoType, XTRA_OFS_PLAYER)
						
						give_item(iPlayer, szWeaponName)
						set_pdata_int(iPlayer, iAmmoType, iMagazine, XTRA_OFS_PLAYER)
						set_pdata_int(iWeaponEntity, m_iClip, iAmmo, XTRA_OFS_WEAPON)
					}
				}
			}
			
			if(fm_user_has_shield(iTarget))
			{
				give_item(iPlayer, "weapon_shield")
			}
			
			if(cs_get_user_defuse(iTarget))
			{
				cs_set_user_defuse(iPlayer, 1)
			}
			
			if(user_has_weapon(iTarget, CSW_C4))
			{
				fm_transfer_user_gun(iTarget, iPlayer, CSW_C4)
			}
			
			static iArmorType;iArmorType = get_pdata_int(iTarget, OFFSET_ARMOR_TYPE)
			cs_set_user_armor(iPlayer, get_user_armor(iTarget), CsArmorType:iArmorType)
			set_user_health(iPlayer, get_user_health(iTarget))
			cs_set_user_money(iPlayer, cs_get_user_money(iTarget))
		
		
		
		attach_view(iPlayer, iPlayer)
		user_silentkill(iTarget)
		
		g_iPlayerControl[iPlayer]++
		
		static szName[MAX_PLAYERS], szTargetName[MAX_PLAYERS]
		get_user_name(iPlayer, szName, charsmax(szName))
		get_user_name(iTarget, szTargetName, charsmax(szTargetName))
		ColorChat(0, "%s!n Spectator player!g %s !nreplaced!g %s",PLUGIN_TAG, szName, szTargetName)
		
	}

	return PLUGIN_CONTINUE
}

public send_reminder() {
    ColorChat(0, "%s !nSpectators can press!g E !nto replace !ginactive players!n instant.",PLUGIN_TAG)
}



checkPlayerInvalidOrigin(playerid)
{
	new Float:fOrigin[3], Float:fMins[3], Float:fVec[3]
	pev(playerid, pev_origin, fOrigin)
	
	new hull = (pev(playerid, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
	if(is_hull_vacant(fOrigin, hull)) 
	{
		engfunc(EngFunc_SetOrigin, playerid, fOrigin)
		return
	}
	else
	{
		pev(playerid, pev_mins, fMins)
		fVec[2] = fOrigin[2]
		
		for(new i; i < sizeof g_fSizes; i++)
		{
			fVec[0] = fOrigin[0] - fMins[0] * g_fSizes[i][0]
			fVec[1] = fOrigin[1] - fMins[1] * g_fSizes[i][1]
			fVec[2] = fOrigin[2] - fMins[2] * g_fSizes[i][2]
			if(is_hull_vacant(fVec, hull))
			{
				engfunc(EngFunc_SetOrigin, playerid, fVec)
				set_pev(playerid, pev_velocity, Float:{0.0, 0.0, 0.0})
				break
			}
		}
	}
}

is_hull_vacant(const Float:origin[3], hull)
{
	new tr = 0
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, tr)
	if(!get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid) && get_tr2(tr, TR_InOpen))
		return true
	
	return false
}





public server_changelevel() {
	ChangeLevel = true
}

public LOGEVENT_RoundStart() {
	
		for(new id = 0; id <= 32; id++) {
			Meter[id] = 0;
			CheckCampingTime[id] = 0;
		}
		set_task(0.5, "TASK_CheckCamping", TASKID_CHECKCAMPING, _, _, "b");
}

public LOGEVENT_RoundEnd() {
	remove_task(TASKID_CHECKCAMPING);
}

public TASK_CheckCamping() {
	new Players[32], Num;
	get_players(Players, Num, "ch");
	
	if(Num == 1 || get_cvar_float("mp_timelimit") && !get_timeleft() || ChangeLevel)
		return;
	
	new PrevMeter, bool:PunishCamper;
	
	get_players(Players, Num, "ah");
	for(new index = 0; index < Num; ++index) {
		new id = Players[index];
		
		if(fm_get_user_maxspeed(id) > 2.0) {
			coords_insert(id, 0);
			CheckCampingTime[id] ++
			
			if(CheckCampingTime[id] > 2) {
				StandardDeviation[id] = coords_standard_deviation(id);
				CheckCampingTime[id] = 0
			}
			PrevMeter = Meter[id];
			
			Meter[id] += ((100 - StandardDeviation[id]) / MAX_CAMP_AFK);
			
			Meter[id] = clamp(Meter[id], 0, 100);
			
			if(Meter[id] < PrevMeter && Meter[id] < 80)
				Meter[id] -= (PrevMeter - Meter[id]) / 3;
			
			(Meter[id] >= 100) ? (PunishCamper = true) : (PunishCamper = false)					
			
			if(PunishCamper) {
				g_bPlayerInactive[id] = true;
			}
			else { 
				g_bPlayerInactive[id] = false;
			}
			
			if(Meter[id]) {
				new r, g, b;
				
				if(Meter[id] > 90)
					r = 255;
				else if(Meter[id] > 80) {
					r = 255; 
					g = 100;
				}
				else if(Meter[id] > 60) {
					r = 255;
					g = 255;
				}
				else if(Meter[id] > 50) 
					g = 255; 
				else 
					g = 255;
				
				new Message[64];
				
				if(Meter[id] >= 99) 
				{
						formatex(Message,sizeof(Message)-1,"Spectators can replace you", Meter[id]);
				} else 
				{ 
						formatex(Message,sizeof(Message)-1,"Inactivity: %i%%", Meter[id]);
				}
				
				
				HudMessage(id, Message, r, g, b, -1.0, 0.75, _, _, 0.5);
				
				
					new Players[32], Num, Spectator;
					get_players(Players, Num, "bch");
					for(new index = 0; index < Num; ++index) {
						Spectator = Players[index];
						
						if(pev(Spectator, pev_iuser2) == id) {
						
							new Message[64];
							if(is_user_bot(id)) 
							{
								formatex(Message,sizeof(Message)-1,"Press E to replace this lag player");
							}
							else if( g_bPlayerInactive[id] ) 
							{ 
								formatex(Message,sizeof(Message)-1,"Press E to replace this inactive player");
							}
							else 
							{
								formatex(Message,sizeof(Message)-1,"Inactivity: %i%%", Meter[id]);
							}
						
							HudMessage(Spectator, Message, r, g, b, -1.0, 0.75, _, _, 0.5);
						}				
					}
				
			}
		}
	}
}

stock coords_standard_deviation(id) {
	new Sum, Avg, Variance, VarianceTot;
	new CoordID, VectorID;
	
	for(CoordID = 0; CoordID < 3; ++CoordID) {
		Sum = 0;
		Variance = 0;
		
		for(VectorID = 0; VectorID < 4; ++VectorID)
			Sum += CoordsBody[id][VectorID][CoordID];
		
		Avg = Sum / 4;
		
		for(VectorID = 0; VectorID < 4; ++VectorID)
			Variance += power(CoordsBody[id][VectorID][CoordID] - Avg, 2);
		
		Variance = Variance /(4- 1);
		
		VarianceTot += Variance;
	}
	
	return sqroot(VarianceTot);
}

stock coords_insert(id, CoordType) {
	for(new VectorID = 4 - 1; VectorID > 0;--VectorID) {	
		for(new CoordID = 0; CoordID < 3; ++CoordID) {
			if(CoordType == 0)
				CoordsBody[id][VectorID][CoordID] = CoordsBody[id][VectorID - 1][CoordID];
			else
				CoordsEyes[id][VectorID][CoordID] = CoordsEyes[id][VectorID - 1][CoordID];
		}
	}
	
	if(is_user_connected(id)) {
		if(CoordType == 0)
			get_user_origin(id, CoordsBody[id][0], 0);
		else
			get_user_origin(id, CoordsEyes[id][0], 3);
	}
}

#define clamp_byte(%1)       ( clamp( %1, 0, 255 ) )
#define pack_color(%1,%2,%3) ( %3 + ( %2 << 8 ) + ( %1 << 16 ) )

stock HudMessage(const id, const message[], red = 0, green = 160, blue = 0, Float:x = -1.0, Float:y = 0.65, effects = 2, Float:fxtime = 0.01, Float:holdtime = 3.0, Float:fadeintime = 0.01, Float:fadeouttime = 0.01) {
	new count = 1, players[32];
	
	if(id) players[0] = id;
	else get_players(players, count, "ch"); {
		for(new i = 0; i < count; i++) {
			if(is_user_connected(players[i])) {	
				new color = pack_color(clamp_byte(red), clamp_byte(green), clamp_byte(blue))
				
				message_begin(MSG_ONE_UNRELIABLE, SVC_DIRECTOR, _, players[i]);
				write_byte(strlen(message) + 31);
				write_byte(DRC_CMD_MESSAGE);
				write_byte(effects);
				write_long(color);
				write_long(_:x);
				write_long(_:y);
				write_long(_:fadeintime);
				write_long(_:fadeouttime);
				write_long(_:holdtime);
				write_long(_:fxtime);
				write_string(message);
				message_end();
			}
		}
	}
}

ColorChat(const id, const input[], any:...) 
{
	new iNum = 1, iPlayers[MAX_PLAYERS]
	
	static szMsg[192]
	vformat(szMsg, charsmax(szMsg), input, 3)
	
	replace_all(szMsg, charsmax(szMsg), "!g", "^4" )
	replace_all(szMsg, charsmax(szMsg), "!n", "^1" )
	replace_all(szMsg, charsmax(szMsg), "!t", "^3" )
   
	if(id) 	iPlayers[0] = id
	else 	get_players(iPlayers, iNum, "ch" )
		
	for(new i, iPlayer; i < iNum;i++)
	{
		iPlayer = iPlayers[i]
		
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, iPlayer)  
		write_byte(iPlayer)
		write_string(szMsg)
		message_end()
	}
}
