#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))
#define TEXT "{default}"
#define SPECIAL "{lightgreen}"

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_DESCRIPTION "Just another redie plugin with some cool features. Press +RELOAD during redie to get redie for a second"

bool g_bBlockCommand = true;
bool g_bRedie[MAXPLAYERS + 1] = { false, ... };
bool g_bBlock[MAXPLAYERS + 1] = { false, ... };

Handle g_hNoclip[MAXPLAYERS + 1] = { null, ... };
Handle g_hReset[MAXPLAYERS + 1] = { null, ... };

public Plugin myinfo = 
{
    name = "Redie",
    author = "Bara",
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Redie_GetClientStatus", Native_GetClientStatus);
	
	RegPluginLibrary("redie");
	
	return APLRes_Success;
}

public int Native_GetClientStatus(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	return g_bRedie[client];
}

public void OnPluginStart()
{
	CreateConVar("redie_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);

	RegConsoleCmd("sm_redie", Command_Redie);
	RegConsoleCmd("sm_reback", Command_Reback);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	
	AddNormalSoundHook(view_as<NormalSHook>(OnNormalSoundHook));
	
	LoopClients(i)
	{
		SDKHook(i, SDKHook_WeaponCanUse, OnWeaponCanUse);
		SDKHook(i, SDKHook_WeaponEquip, OnWeaponCanUse);
		SDKHook(i, SDKHook_TraceAttack, OnTraceAttack);
	}

	CSetPrefix("{darkblue}[Redie]{default}");
}

public void OnClientPutInServer(int client)
{
	if (IsClientInGame(client))
	{
		SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
		SDKHook(client, SDKHook_WeaponEquip, OnWeaponCanUse);
		SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	}
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if(g_bRedie[client])
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(g_bRedie[victim])
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Command_Redie(int client, int args)
{
	if(IsClientValid(client))
	{
		if(!IsPlayerAlive(client))
		{
			if(GetClientTeam(client) > CS_TEAM_SPECTATOR)
			{
				if(!g_bBlockCommand)
				{
					g_bRedie[client] = true;
					
					SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
					SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
					
					CS_RespawnPlayer(client);
					
					for(int i = CS_SLOT_PRIMARY; i <= CS_SLOT_C4; i++)
					{
						int index = -1;
						
						while((index = GetPlayerWeaponSlot(client, i)) != -1)
						{
							SafeRemoveWeapon(client, index);
						}
					}

					SetEntProp(client, Prop_Send, "m_lifeState", 1);
		
					g_bRedie[client] = true;
		
					SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
					SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
					
					LoopClients(i)
					{
						SetListenOverride(client, i, Listen_Yes);
						
						if(IsPlayerAlive(i))
						{
							SetListenOverride(i, client, Listen_No);
						}
						else
						{
							SetListenOverride(i, client, Listen_Yes);
						}
					}
		
					CPrintToChat(client, "Du bist nun ein Geist.");
				}
				else
				{
					CPrintToChat(client, "Du musst bis zur nächsten Runde warten.");
				}
			}
			else
			{
				CPrintToChat(client, "Du musst in einem Team sein, um %s!redie %snutzen zu können.", SPECIAL, TEXT);
			}
		}
		else
		{
			CPrintToChat(client, "Du musst tot sein, um %s!redie %snutzen zu können.", SPECIAL, TEXT);
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Reback(int client, int args)
{
	if(IsClientValid(client))
	{
		if(g_bRedie[client])
		{
			int iTeam = GetClientTeam(client);
			
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
			ChangeClientTeam(client, iTeam);
			
			LoopClients(i)
			{
				SetListenOverride(client, i, Listen_Default);
				SetListenOverride(i, client, Listen_Default);
			}
			
			ResetRedie(client);
		}
		else
		{
			CPrintToChat(client, "Du musst im %s!redie %ssein, um %s!reback %snutzen zu können.", SPECIAL, TEXT, SPECIAL, TEXT);
		}
	}
	
	return Plugin_Handled;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bBlockCommand = false;
	
	LoopClients(client)
	{
		ResetRedie(client);
		
		SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
		SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
	}
	
	int ent = MaxClients + 1;
	
	SDKUnhook(ent, SDKHook_EndTouch, BlockTouch);
	SDKUnhook(ent, SDKHook_StartTouch, BlockTouch);
	SDKUnhook(ent, SDKHook_Touch, BlockTouch);
	
	while((ent = FindEntityByClassname(ent, "trigger_multiple")) != -1)
	{
		SDKHook(ent, SDKHook_EndTouch, BlockTouch);
		SDKHook(ent, SDKHook_StartTouch, BlockTouch);
		SDKHook(ent, SDKHook_Touch, BlockTouch);
	}
	
	while((ent = FindEntityByClassname(ent, "func_door")) != -1)
	{
		SDKHook(ent, SDKHook_EndTouch, BlockTouch);
		SDKHook(ent, SDKHook_StartTouch, BlockTouch);
		SDKHook(ent, SDKHook_Touch, BlockTouch);
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bBlockCommand = true;

	LoopClients(i)
	{
		ResetRedie(i);
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsClientValid(client))
	{
		if(CheckCommandAccess(client, "sm_redie", ADMFLAG_CUSTOM4))
		{
			CPrintToChat(client, "Gib %s!redie %sein, um als Geist weiterzuspielen.", SPECIAL, TEXT);
		}
	}
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
	return Plugin_Changed;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsClientValid(client) && g_bRedie[client])
	{
		ResetRedie(client);
		CreateTimer(0.5, Timer_FixSolids, GetClientUserId(client));
	}
}

public Action Timer_FixSolids(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsClientValid(client))
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 1);
		SetEntProp(client, Prop_Data, "m_nSolidType", 0);
		SetEntProp(client, Prop_Send, "m_usSolidFlags", 4);
	}
}

public Action Timer_Noclip(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(IsClientValid(client) && g_bRedie[client])
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
		
		g_hReset[client] = CreateTimer(5.0, Timer_Reset, GetClientUserId(client));
	}
	
	g_hNoclip[client] = null;
}

public Action Timer_Reset(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if(IsClientValid(client) && g_bRedie[client])
	{
		g_bBlock[client] = false;
	}
	
	g_hReset[client] = null;
}

public Action BlockTouch(int entity, int other)
{
	if(IsClientValid(other) && g_bRedie[other])
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnNormalSoundHook(int[] clients, int &numClients, char[] sample, int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
	if(IsClientValid(entity) && g_bRedie[entity])
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(g_bRedie[client])
	{
		buttons &= ~IN_USE;
		
		if(buttons & IN_RELOAD)
		{
			if(!g_bBlock[client])
			{
				g_bBlock[client] = true;
				
				SetEntityMoveType(client, MOVETYPE_NOCLIP);
				g_hNoclip[client] = CreateTimer(1.0, Timer_Noclip, GetClientUserId(client));
				
				CPrintToChat(client, "Du hast für %s1 Sekunde %sNoclip.", SPECIAL, TEXT);
			}
		}
	}
}

void ResetRedie(int client)
{
	g_bRedie[client] = false;
	g_bBlock[client] = false;
	
	LoopClients(i)
	{
		SetListenOverride(client, i, Listen_Default);
		SetListenOverride(i, client, Listen_Default);
	}

	SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKUnhook(client, SDKHook_TraceAttack, OnTraceAttack);
	
	delete g_hNoclip[client];
	delete g_hReset[client];
}

public void OnClientDisconnect(int client)
{
	ResetRedie(client);
}

stock bool IsClientValid(int client, bool bots = false)
{
    if (client > 0 && client <= MaxClients)
    {
        if(IsClientInGame(client) && (bots || !IsFakeClient(client)) && !IsClientSourceTV(client))
        {
            return true;
        }
    }
    
    return false;
}

stock bool SafeRemoveWeapon(int iClient, int iWeapon)
{
    if (!IsValidEntity(iWeapon) || !IsValidEdict(iWeapon))
	{
        return false;
	}
    
    if (!HasEntProp(iWeapon, Prop_Send, "m_hOwnerEntity"))
	{
        return false;
	}
    
    int iOwnerEntity = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
    
    if (iOwnerEntity != iClient)
	{
        SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);
	}
    
    CS_DropWeapon(iClient, iWeapon, false);
    
    if (HasEntProp(iWeapon, Prop_Send, "m_hWeaponWorldModel"))
    {
        int iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
        
        if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
		{
            if (!AcceptEntityInput(iWorldModel, "Kill"))
			{
                return false;
			}
		}
    }
    
    if (!AcceptEntityInput(iWeapon, "Kill"))
	{
        return false;
	}
    
    return true;
}
