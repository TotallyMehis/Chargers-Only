#include <sourcemod>
#include <sdktools>
#include <cstrike>


#include <chargersonly/core>


g_ConVar_FreezeTime;


public Plugin myinfo =
{
    author = CHARGERSONLY_AUTHOR,
    url = CHARGERSONLY_URL,
    name = CHARGERSONLY_NAME..." - Timer",
    description = "Displays the time on the screen.",
    version = "1.0"
};

public void OnPluginStart()
{
    if ( (g_ConVar_FreezeTime = FindConVar( "mp_freezetime" )) == null )
    {
        SetFailState( CO_PRE_CON..."Couldn't find cvar mp_freezetime!" );
    }
    
    HookEvent( "round_poststart", E_RoundPostStart, EventHookMode_PostNoCopy );
}

public Action E_RoundPostStart( Event event, const char[] name, bool dontBroadcast )
{
    
}