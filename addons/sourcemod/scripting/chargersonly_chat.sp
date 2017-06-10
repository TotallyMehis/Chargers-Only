#include <sourcemod>
#include <sdktools>
#include <cstrike>


//#define REQUIRE_PLUGIN
#include <chargersonly/core>


float g_flLastTimeMsg;

ConVar g_ConVar_Interval_Time;
ConVar g_ConVar_Interval_Ad;
ConVar g_ConVar_WinsReq;


public Plugin myinfo =
{
    author = CHARGERSONLY_AUTHOR,
    url = CHARGERSONLY_URL,
    name = CHARGERSONLY_NAME..." - Chat Info",
    description = "Displays info in chat.",
    version = "1.0"
};

public void OnPluginStart()
{
    g_ConVar_Interval_Time = CreateConVar( "sm_chargersonly_interval_time", "70", "Interval for time printing in chat in seconds. (0 = disable)", _, true, 0.0, true, 1337.0 );
    g_ConVar_Interval_Ad = CreateConVar( "sm_chargersonly_interval_ad", "270", "Interval for plugin info printing in chat in seconds. (0 = disable)", _, true, 0.0, true, 1337.0 );
    g_ConVar_WinsReq = CreateConVar( "sm_chargersonly_display_winsreq", "1", "", _, true, 0.0, true, 1.0 );
    
    
    CreateTimer( g_ConVar_Interval_Time.FloatValue, T_DisplayTime );
    CreateTimer( g_ConVar_Interval_Ad.FloatValue, T_DisplayAd );
    
    
    HookEvent( "round_poststart", E_RoundPostStart, EventHookMode_PostNoCopy );
    HookEvent( "round_end", E_RoundEnd, EventHookMode_PostNoCopy );
}

public void OnMapStart()
{
    g_flLastTimeMsg = 0.0;
}

public Action E_RoundPostStart( Event event, const char[] name, bool dontBroadcast )
{
    if ( CO_IsInMatch() )
    {
        if ( (GetEngineTime() - g_flLastTimeMsg) < (time * 0.2) )
        {
            PrintTime();
        }
    }
}

public Action E_RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
    if ( g_ConVar_WinsReq.BoolValue && CO_IsInMatch() && CO_IsSwitchDone() )
    {
        int req = CS_GetTeamScore( CS_TEAM_CT ) - CS_GetTeamScore( CS_TEAM_T ) + 1;
        
        PrintToChatAll( SO_CHAT_PRE..."Terrorists need to win %i more round%s", req, ( req > 1 ) ? "s." : "!" );
    }
}

public Action T_DisplayTime( Handle hTimer )
{
    float time = g_ConVar_Interval_Time.FloatValue;
    if ( time > 0.0 )
    {
        if ( CO_IsInMatch() )
        {
            // Check for repeating displays.
            if ( (GetEngineTime() - g_flLastTimeMsg) < (time * 0.75) )
            {
                PrintTime();
            }
            else
            {
                // Display in half of the time next then.
                time *= 0.5;
            }
        }
        
        CreateTimer( time, T_DisplayTime );
    }
    
    return Plugin_Stop;
}

public Action T_DisplayAd( Handle hTimer )
{
    float time = g_ConVar_Interval_Ad.FloatValue;
    if ( time > 0.0 )
    {
        PrintToChatAll( "This server is running "...CHARGERSONLY_NAME );
        
        CreateTimer( time, T_DisplayAd );
    }
    
    return Plugin_Stop;
}

stock void PrintTime()
{
    float secs = CO_GetTimeLeft();
    int mins = 0;
    
    while ( secs >= 60.0 )
    {
        ++mins;
        secs -= 60.0;
    }
    
    
    if ( mins >= 10 )
    {
        PrintToChatAll( SO_CHAT_PRE..."Terrorists have %i minutes to attack!", mins );
    }
    else if ( mins <= 0 )
    {
        PrintToChatAll( SO_CHAT_PRE..."Terrorists have %.0f seconds to attack!", secs );
    }
    else
    {
        PrintToChatAll( SO_CHAT_PRE..."Terrorists have %i minutes and %.0f seconds to attack!", mins, secs );
    }
    
    g_flLastTimeMsg = GetEngineTime();
}