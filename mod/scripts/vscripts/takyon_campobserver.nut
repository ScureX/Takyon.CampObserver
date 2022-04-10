global function CampObserverInit

struct PlayerData{
	string uid // identify player
	int timeBelowMin = 0 // how long player is belowmin threshhold 
	bool immune = false // maybe needed to make a player immune, maybe trusted players or some other shit idk, just nice to have i think 
}

// internal shit, dont fuck with this
array<PlayerData> pdArr = []
array<entity> highlightedPlayers = [] // players to highlight
array<string> highlightCycles = ["spot_threat", "enemy_sonar", "spot_threat", "enemy_boss_bounty"]
array<string> messagedUids = [] // uids who have received the anti camp message
bool highlightCycleComplete = false
int highlightCycle = 0

void function CampObserverInit(){
	AddCallback_OnPlayerRespawned(OnPlayerSpawned)
	AddCallback_OnClientDisconnected(OnPlayerDisconnected)
	AddCallback_GameStateEnter(eGameState.Playing, Playing)
}

void function Playing(){
	thread CampObserverMain()
}

void function CampObserverMain(){
	while(true){
        WaitFrame()
        if(!IsLobby()){
			// loop thru every player
			foreach(entity player in GetPlayerArray()){

				// check if above speed requirement to clear the time below min speed and remove from highlight list
				if(GetPlayerSpeed(player) > GetConVarFloat("co_minspeed")){
					foreach(PlayerData pd in pdArr){
						if(pd.uid == player.GetUID()){
							pd.timeBelowMin = 0
							try{
								highlightedPlayers.remove(highlightedPlayers.find(player))
								messagedUids.remove(messagedUids.find(player.GetUID()))
								if(IsValid(player))
									Highlight_ClearEnemyHighlight(player)
								Chat_ServerPrivateMessage(player, "\x1b[34mCampObserver \x1b[32mis no longer highlighting your position.", false)
							}catch(e){}
						}
					}
					continue
				}

				// find players data to increase time below min speed
				foreach(PlayerData pd in pdArr){
					if(pd.uid == player.GetUID()){
						pd.timeBelowMin++ 
						if(pd.timeBelowMin > GetConVarInt("co_timetillreveal") && !pd.immune){
							if(!highlightedPlayers.contains(player))
								highlightedPlayers.append(player)

							// notify
							if(!messagedUids.contains(player.GetUID())){
								Chat_ServerPrivateMessage(player, "\x1b[34mCampObserver \x1b[31mis highlighting your position. \x1b[32mMove faster!", false)
								messagedUids.append(player.GetUID())
							}
						}
					}
				}

				// highlight players
				thread HighlightCampers()
				wait 0.5 // speed check once every idk seconds
				// scared of removing a player from the highlight list while its in use so this is my way to cope with threads doing thread things
				while(!highlightCycleComplete){ 
					WaitFrame()
				}
			}
		}
	}
	
}

void function HighlightCampers(){
	highlightCycleComplete = false

	foreach(entity player in highlightedPlayers){
		try{
			if(IsValid(player))
				Highlight_SetEnemyHighlight(player, highlightCycles[highlightCycle])
		}catch(e){}		
	}

	// will wrap around (i hope)
	highlightCycle = highlightCycle + 1
	highlightCycle = WrapCycleNum(highlightCycle, highlightCycles.len())
	highlightCycleComplete = true
}

///

int function HowOftenInArray(entity player, array<entity> arr){
	int count = 0
	for(int i = 0; i < arr.len(); i++){
		if(arr[i] == player)
			count++
	}
	return count
}

int function WrapCycleNum(int value, int modulo){
    int remainder = (value % modulo);
    return (remainder < 0) ? (modulo + remainder) : remainder;
}

float function GetPlayerSpeed(entity player){
	vector playerVelV = player.GetVelocity()
    float playerVel = sqrt(playerVelV.x * playerVelV.x + playerVelV.y * playerVelV.y)
    return playerVel * (0.274176/3)
}

void function OnPlayerSpawned(entity player){
	bool found = false
	for(int i = 0; i < pdArr.len(); i++){
		if(pdArr[i].uid == player.GetUID()){
			found = true
		}
	}

	if(!found){
		PlayerData tmp
		tmp.uid = player.GetUID()
		pdArr.append(tmp)
	}
}

void function OnPlayerDisconnected(entity player){
	for(int i = 0; i < pdArr.len(); i++){
		if(pdArr[i].uid == player.GetUID()){
			pdArr.remove(i)
		}
	}
}