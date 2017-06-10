#if defined _chargersonly_core_included
    #endinput
#endif
#define _chargersonly_core_included


#define CHARGERSONLY_LIB_CORE       chargersonly_core

#define CHARGERSONLY_AUTHOR         "Mehis"
#define CHARGERSONLY_URL            "http://steamcommunity.com/profiles/76561198021256769/"
#define CHARGERSONLY_NAME           "Chargers Only"


#define SO_SHORTNAME                "CHARGERS-ONLY"
#define SO_CON_PRE                  "["...SHORTNAME..."] "
#define SO_CHAT_PRE                 "\x01[\x04"...SHORTNAME..."\x01]\x03 "



native bool CO_IsInMatch();
native bool CO_IsSwitchDone();
native float CO_GetTimeLeft();


public SharedPlugin __pl_chargersonly_core =
{
    name = CHARGERSONLY_LIB_CORE,
    file = CHARGERSONLY_LIB_CORE...".smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
    public void __pl_chargersonly_core_SetNTVOptional()
    {
        MarkNativeAsOptional( "CO_GetTimeLeft" );
        MarkNativeAsOptional( "CO_IsInMatch" );
        MarkNativeAsOptional( "CO_IsSwitchDone" );
    }
#endif