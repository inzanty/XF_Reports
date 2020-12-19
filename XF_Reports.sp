#include <sourcemod>
#include <SteamWorks>

public Plugin myinfo =
{
	author = "Alexbu444 && inzanty",
	name = "XF2 Reports (LiteServers LLP)",
	description = "Plugin for report players to forum",
	version = "1.0.0.2",
	url = "https://spb.wtf"
};

#define MPL MAXPLAYERS+1
#define PMP PLATFORM_MAX_PATH

char		g_szReason[MPL][256],
			g_szNodeId[256],
			g_szApiKey[256],
			g_szApiUrl[256];
			
bool		g_bReasonChat[MPL];

int			g_iVictim[MPL];

public void OnPluginStart()
{
	char szPath[256], szForumUrl[256];
	
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/XenForo_Reports.cfg");
	
	KeyValues kv = new KeyValues("XF_Reports");
	if(!kv.ImportFromFile(szPath) || !kv.GotoFirstSubKey())
		SetFailState("[XF Reports] file is not found (%s)", szPath);
	
	kv.Rewind();
	
	if(kv.JumpToKey("Settings"))
	{
		kv.GetString("forum", szForumUrl, sizeof(szForumUrl));
		kv.GetString("forum_id", g_szNodeId, sizeof(g_szNodeId));
		kv.GetString("apikey", g_szApiKey, sizeof(g_szApiKey));
	}
	
	FormatEx(g_szApiUrl, sizeof(g_szApiUrl), "https://%s/api/threads", szForumUrl);

	RegConsoleCmd("sm_report",	ReportCmd);
	
	RegConsoleCmd("say_team",	OnSayHook);
	RegConsoleCmd("say",		OnSayHook);
}

public Action ReportCmd(int iClient, int iArgs)
{
	if (iClient == 0)
		return Plugin_Handled;


	Handle hMenu = CreateMenu(SelectPlayerHandler);

	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{

			char szUID[13];
			char szUsername[MAX_TARGET_LENGTH];

			GetClientName(i, szUsername, sizeof(szUsername));
			IntToString(GetClientUserId(i), szUID, sizeof(szUID));

			AddMenuItem(hMenu, szUID, szUsername);
		}
	}

	if (GetMenuItemCount(hMenu) > 0)
	{
		SetMenuExitBackButton(hMenu, false);
		SetMenuExitButton(hMenu, true);
		SetMenuTitle(hMenu, "[XenForo] Report Player", iClient);

		DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
		return Plugin_Handled;
	}

	CloseHandle(hMenu);
	PrintToChat(iClient, "[XenForo] %t", "No Available Players");
	return Plugin_Handled;
}

public Action OnSayHook(int iClient, int iArgs)
{
	if (!iClient || !g_bReasonChat[iClient])
		return Plugin_Continue;

	if (!(g_iVictim[iClient] = GetClientOfUserId(g_iVictim[iClient])))
	{
		PrintToChat(iClient, "[XenForo] %t", "Player no longer available");

		g_bReasonChat[iClient] = false;
		g_iVictim[iClient] = -1;
		return Plugin_Handled;
	}

	if (iArgs == 1)
		GetCmdArg(1, g_szReason[iClient], sizeof(g_szReason[]));
	else
		GetCmdArgString(g_szReason[iClient], sizeof(g_szReason[]));

	if (!strcmp(g_szReason[iClient], "!cancel"))
	{
		PrintToChat(iClient, "[XenForo] Operation cancelled.");
		
		g_bReasonChat[iClient] = false;
		g_iVictim[iClient] = -1;
		return Plugin_Handled;
	}
	
	UTIL_SendReport(iClient);

	return Plugin_Handled;
}

public int SelectPlayerHandler(Handle hMenu, MenuAction eAction, int iParam1, int iParam2)
{
	switch (eAction)
	{
		case MenuAction_End:  CloseHandle(hMenu);
		case MenuAction_Select:
		{
			char szUID[13];
			GetMenuItem(hMenu, iParam2, szUID, sizeof(szUID));

			int iUID = GetClientOfUserId(StringToInt(szUID));
			if (!iUID)
			{
				PrintToChat(iParam1, "[XenForo] %t", "Player no longer available");
				return;
			}

			g_iVictim[iParam1] = GetClientUserId(iUID);
			UTIL_HookChatMessage(iParam1);
		}
	}
}

void UTIL_HookChatMessage(int iClient)
{
	g_bReasonChat[iClient] = true;
	PrintToChat(iClient, "[XenForo] Using the chat, enter the reason for the ban. Or use !cancel for cancel operation.");
}

void UTIL_SendReport(int iClient)
{
	char szSteam[2][30], szName[2][256];
	
	// Player.
	GetClientName(iClient, szName[0], sizeof(szName[]));
	GetClientAuthId(iClient, AuthId_Steam2, szSteam[0], sizeof(szSteam[]));
	
	// Target.
	GetClientName(g_iVictim[iClient], szName[1], sizeof(szName[]));
	GetClientAuthId(g_iVictim[iClient], AuthId_Steam2, szSteam[1], sizeof(szSteam[]));
	
	// More details.
	char szHostname[256];
	GetConVarString(FindConVar("hostname"), szHostname, sizeof(szHostname));
	
	char szTime[256];
	FormatTime(szTime, sizeof(szTime), "%d.%m.%Y %H:%M", GetTime());

	// Title of the thread.
	char szTitle[512];
	FormatEx(szTitle, sizeof(szTitle), "Жалоба на игрока: %s", szName[1]);
	
	// Body of the first post.
	char szMessage[512];
	FormatEx(szMessage, sizeof(szMessage), "Отправил репорт: %s [ %s ]\nИгрок: %s [ %s ]\nПричина: %s\nДата: %s", szName[0], szSteam[0], szName[1], szSteam[1], g_szReason[iClient], szTime);
	
	// Creates a thread.
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, g_szApiUrl);
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "XF-Api-Key", g_szApiKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "node_id", g_szNodeId); 
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "title", szTitle); 
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "message", szMessage); 
	SteamWorks_SetHTTPCallbacks(hRequest, OnRequestComplete);
	SteamWorks_SendHTTPRequest(hRequest);
}

public void OnRequestComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
}