#include <sourcemod>
#include <sdktools>
#include <cstrike>


#include <chargersonly/core>


#define DEBUG
#define CHECK_MODE_CVARS


ConVar g_ConVar_OurTimeLimit;
ConVar g_ConVar_SuppressTimeLimit;
ConVar g_ConVar_TimeLimit;


float g_flTurnTimeLeft;
float g_flRoundStartTime;
float g_flRoundEndTime;


bool g_bEnabled;

bool g_bSwitchDone;
bool g_bSwitching;
bool g_bCounting;
bool g_bInRoundEnd;

int g_iSwitchCTWins;

//Handle g_hTurnTimer;


public Plugin myinfo =
{
    author = CHARGERSONLY_AUTHOR,
    url = CHARGERSONLY_URL,
    name = CHARGERSONLY_NAME..." - Core",
    description = "",
    version = "1.0"
};

public APLRes AskPluginLoad2( Handle hPlugin, bool late, char[] szError, int error_len )
{
    if ( GetEngineVersion() != Engine_CSGO )
    {
        char szFolder[32];
        GetGameFolderName( szFolder, sizeof( szFolder ) );
        
        FormatEx( szError, error_len, CHARGERSONLY_NAME..." does not support %s!", szFolder );
        
        return APLRes_Failure;
    }
    
    
    // LIBRARIES
    RegPluginLibrary( CHARGERSONLY_LIB_CORE );
    
    
    // NATIVES
    CreateNative( "CO_IsInMatch", Native_IsInMatch );
    CreateNative( "CO_IsSwitchDone", Native_IsSwitchDone );
    CreateNative( "CO_GetTimeLeft", Native_GetTimeLeft );
    
    return APLRes_Success;
}

public void OnPluginStart()
{
#if defined CHECK_MODE_CVARS
    ConVar conv = FindConVar( "game_type" );
    
    if ( conv == null || conv.IntValue != 0 )
    {
        SetFailState( SO_CON_PRE..."Invalid game_type value!" );
    }
    
    delete conv;
#endif

    if ( (g_ConVar_TimeLimit = FindConVar( "mp_timelimit" )) == null )
    {
        SetFailState( SO_CON_PRE..."Couldn't find cvar mp_timelimit!" );
    }
    
    g_ConVar_OurTimeLimit = CreateConVar( "co_timelimit", "8", "Time limit for turns.", _, true, 0.0, true, 60.0 );
    g_ConVar_SuppressTimeLimit = CreateConVar( "co_suppresstimelimit", "1", "Do we suppress messages made by mp_timelimit changes?", _, true, 0.0, true, 1.0 );
    
    
#if defined DEBUG
    RegAdminCmd( "sm_debug_endturn", Cmd_Debug_EndTurn, ADMFLAG_ROOT );
#endif
    
    
    //HookEvent( "teamplay_round_start", E_TeamplayRoundStart, EventHookMode_PostNoCopy );
    //HookEvent( "switch_team", E_SwitchTeam, EventHookMode_PostNoCopy );
    
    HookEvent( "bomb_planted", E_BombPlanted, EventHookMode_PostNoCopy );
    HookEvent( "round_freeze_end", E_FreezeEnd, EventHookMode_PostNoCopy );
    
    HookEvent( "round_poststart", E_RoundPostStart, EventHookMode_PostNoCopy );
    HookEvent( "round_end", E_RoundEnd, EventHookMode_PostNoCopy );
}

public void OnMapStart()
{
    g_bEnabled = false;
    
    g_bSwitchDone = false;
    g_bSwitching = false;
    
    g_bCounting = false;
    g_flRoundStartTime = 0.0;
    g_flRoundEndTime = 0.0;
    
    g_ConVar_TimeLimit.IntValue = 1337;
}

public void OnConfigsExecuted()
{
    if ( g_ConVar_SuppressTimeLimit.BoolValue )
    {
        g_ConVar_TimeLimit.Flags &= ~FCVAR_NOTIFY;
    }
    else
    {
        g_ConVar_TimeLimit.Flags |= FCVAR_NOTIFY;
    }
}

public Action Cmd_Debug_EndTurn( int client, int args )
{
    if ( g_bEnabled )
    {
        if ( g_bSwitchDone )
        {
            EndMatch();
        }
        else
        {
            SwitchTeams();
        }
    }
    
    return Plugin_Handled;
}

public Action CS_OnTerminateRound( float &delay, CSRoundEndReason &reason )
{
#if defined DEBUG
    char szReason[32];
    GetRoundEndReason( reason, szReason, sizeof( szReason ) );
    
    PrintToServer( SO_CON_PRE..."Round end reason: %s", szReason );
#endif
    
    // Our match/turn has ended!
    if ( reason == CSRoundEnd_TargetSaved )
    {
        if ( g_bSwitchDone )
        {
            EndMatch();
        }
        else
        {
            SwitchTeams();
        }
        
        // Don't let them get points from it.
        reason = CSRoundEnd_Draw;
        
        return Plugin_Changed;
    }
    else if ( reason == CSRoundEnd_GameStart )
    {
        StartMatch( false );
    }
    
    return Plugin_Continue;
}

stock void GetRoundEndReason( CSRoundEndReason reason, char[] sz, int len )
{
    switch ( reason )
    {
        case CSRoundEnd_TargetBombed : strcopy( sz, len, "Target bombed" );
        case CSRoundEnd_BombDefused : strcopy( sz, len, "Bomb defused" );
        case CSRoundEnd_CTWin : strcopy( sz, len, "CT win" );
        case CSRoundEnd_TerroristWin : strcopy( sz, len, "T win" );
        case CSRoundEnd_Draw : strcopy( sz, len, "Draw" );
        case CSRoundEnd_HostagesRescued : strcopy( sz, len, "Hostages rescued" );
        case CSRoundEnd_TargetSaved : strcopy( sz, len, "Targed saved" );
        case CSRoundEnd_HostagesNotRescued : strcopy( sz, len, "Hostages not rescued" );
        case CSRoundEnd_GameStart : strcopy( sz, len, "Game start" );
        
        default : FormatEx( sz, len, "N/A (%i)", reason );
    }
}

public Action E_BombPlanted( Event event, const char[] name, bool dontBroadcast )
{
    if ( !g_bEnabled ) return;
    
#if defined DEBUG
    PrintToServer( SO_CON_PRE..."Bomb has been planted!!!" );
#endif
    
    if ( g_bCounting )
    {
        g_flRoundEndTime = GetEngineTime();
    }
    
    g_bCounting = false;
    g_bInRoundEnd = true;
}

public Action E_FreezeEnd( Event event, const char[] name, bool dontBroadcast )
{
    if ( !g_bEnabled ) return;
    
#if defined DEBUG
    PrintToServer( SO_CON_PRE..."Freeze time is ending!" );
#endif
    
    g_bCounting = true;
    g_flRoundStartTime = GetEngineTime();
}

public Action E_RoundPostStart( Event event, const char[] name, bool dontBroadcast )
{
    if ( g_bEnabled )
    {
        g_bInRoundEnd = false;
        
        // Do our switch.
        if ( g_bSwitching )
        {
            g_bSwitching = false;
            g_bSwitchDone = true;
            
            InitNewTurn();
        }
        else
        {
            g_flTurnTimeLeft -= g_flRoundEndTime - g_flRoundStartTime;
            SetRoundTime( g_flTurnTimeLeft );
        }
        
        PrintTime();
    }
}

public Action E_RoundEnd( Event event, const char[] name, bool dontBroadcast )
{
    if ( !g_bEnabled ) return;
    
    
    if ( g_bCounting )
    {
        g_flRoundEndTime = GetEngineTime();
    }
    
    g_bInRoundEnd = true;
    g_bCounting = false;
    
    if ( g_bSwitchDone )
    {
        // Keep the CT score right.
        if ( CS_GetTeamScore( CS_TEAM_CT ) != g_iSwitchCTWins )
        {
            SetTeamScoreSend( CS_TEAM_CT, g_iSwitchCTWins );
        }
        
        CheckScoreStatus();
    }
}

stock void CheckScoreStatus()
{
    // We haven't even switched yet! We can't check for score!
    if ( !g_bSwitchDone ) return;
    
    
    // Check if our shit is done.
    int twins = CS_GetTeamScore( CS_TEAM_T );
    int ctwins = CS_GetTeamScore( CS_TEAM_CT );
    
    if ( twins > ctwins )
    {
#if defined DEBUG
        PrintToServer( SO_CON_PRE..."Terrorists have won more rounds! Ending match!!" );
#endif
        
        CS_TerminateRound( 3.0, CSRoundEnd_TargetSaved );
    }
}

stock void StartMatch( bool bResetScores = false )
{
#if defined DEBUG
    PrintToServer( SO_CON_PRE..."Match is starting!" );
#endif
    
    if ( bResetScores )
    {
        // Reset team scores.
        SetTeamScoreSend( CS_TEAM_CT, 0 );
        SetTeamScoreSend( CS_TEAM_T, 0 );
    }
    
    g_bEnabled = true;
    
    g_bSwitchDone = false;
    g_bSwitching = false;
    
    g_flRoundStartTime = 0.0;
    g_flRoundEndTime = 0.0;
    
    InitNewTurn();
}

stock void EndMatch()
{
#if defined DEBUG
    PrintToServer( SO_CON_PRE..."Match is stopping!" );
#endif
    
    // HACKHACK!!!
    g_ConVar_TimeLimit.IntValue = 1;
    
    // If that doesn't work, do this at least.
    g_bEnabled = false;
    
    
    int ctwins = CS_GetTeamScore( CS_TEAM_CT );
    int twins = CS_GetTeamScore( CS_TEAM_T );
    
    if ( ctwins == twins )
    {
        PrintMessageToAll( SO_CHAT_PRE..."Match ended! Draw!" );
    }
    else if ( ctwins > twins )
    {
        PrintMessageToAll( SO_CHAT_PRE..."Match ended! Counter-Terrorists won!" );
    }
    else
    {
        PrintMessageToAll( SO_CHAT_PRE..."Match ended! Terrorists won!" );
    }
}

stock void InitNewTurn()
{
    g_flTurnTimeLeft = g_ConVar_OurTimeLimit.FloatValue * 60.0;
    
    SetRoundTime( g_flTurnTimeLeft );
}

stock void SwitchTeams( bool bSwitchScores = true )
{
    if ( g_bSwitching ) return;
    
#if defined DEBUG
    PrintToServer( SO_CON_PRE..."Switching teams!!!" );
#endif

    g_bSwitching = true;
    
    

    
    if ( bSwitchScores )
    {
        int ctwins = CS_GetTeamScore( CS_TEAM_CT );
        int twins = CS_GetTeamScore( CS_TEAM_T );
        
        g_iSwitchCTWins = twins;
        
        //CreateTimer( 3.0, T_SetScores, _, TIMER_FLAG_NO_MAPCHANGE );
        SwitchTeamScores( ctwins, twins );
    }
    
    
    // HACKHACK!!!
    // This is so dumb... mp_switchteams doesn't work.
    //ServerCommand( "mp_swapteams" );
    
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame( i ) && GetClientTeam( i ) > CS_TEAM_SPECTATOR )
        {
            if ( GetClientTeam( i ) == CS_TEAM_CT )
            {
                CS_SwitchTeam( i, CS_TEAM_T );
            }
            else
            {
                CS_SwitchTeam( i, CS_TEAM_CT );
            }
        }
    }
    
    PrintMessageToAll( SO_CHAT_PRE..."Switching teams!" );
}

stock void SetRoundTime( float secs )
{
    GameRules_SetProp( "m_iRoundTime", RoundFloat( secs ) );
}

stock void SwitchTeamScores( int ctscore, int tscore )
{
    SetTeamScoreSend( CS_TEAM_CT, tscore );
    SetTeamScoreSend( CS_TEAM_T, ctscore );
}

stock void SetTeamScoreSend( int index, int value )
{
    SetTeamScore( index, value );
    CS_SetTeamScore( index, value );
}

stock void PrintMessageToAll( const char[] szMsg, int times = 3 )
{
    for ( int i = 0; i < times; i++ )
    {
        PrintToChatAll( szMsg );
    }
}

// TIMERS

// Switch happens here.
// Remember: IGNORE LAST CT WINS!!!
public Action T_SetScores( Handle timer )
{
    int ctwins = g_iSwitchCTWins;
    int twins = 0;
    
#if defined DEBUG
    PrintToServer( SO_CON_PRE..."Setting scores to CT: %i - T: %i!!!", ctwins, twins );
#endif
    
    SetTeamScoreSend( CS_TEAM_CT, ctwins );
    SetTeamScoreSend( CS_TEAM_T, twins );
}

// NATIVES
public int Native_IsInMatch( Handle hPlugin, int nParams )
{
    return g_bEnabled;
}

public int Native_IsSwitchDone( Handle hPlugin, int nParams )
{
    return g_bSwitchDone;
}

public int Native_GetTimeLeft( Handle hPlugin, int nParams )
{
    float time = g_flTurnTimeLeft;
    
    if ( g_bCounting )
    {
        time -= GetEngineTime() - g_flRoundStartTime;
    }
    else if ( g_bInRoundEnd )
    {
        time -= g_flRoundEndTime - g_flRoundStartTime;
    }
    
    return time;
}