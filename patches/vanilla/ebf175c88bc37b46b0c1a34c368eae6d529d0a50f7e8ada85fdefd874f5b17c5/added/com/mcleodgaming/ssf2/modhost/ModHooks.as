package com.mcleodgaming.ssf2.modhost
{
   public class ModHooks
   {
      
      public static const BOOT_START:String = "BOOT_START";
      
      public static const AFTER_BOOT:String = "AFTER_BOOT";
      
      public static const BEFORE_INITIAL_MENU:String = "BEFORE_INITIAL_MENU";
      
      public static const CONFIG_LOADED:String = "CONFIG_LOADED";
      
      public static const MATCH_START:String = "MATCH_START";
      
      public static const MATCH_END:String = "MATCH_END";
      
      public static const MATCH_PAUSE:String = "MATCH_PAUSE";
      
      public static const MATCH_RESUME:String = "MATCH_RESUME";
      
      public static const MATCH_SUDDEN_DEATH:String = "MATCH_SUDDEN_DEATH";
      
      public static const MATCH_RESULTS:String = "MATCH_RESULTS";
      
      public static const QUEUE_MATCH_RESOURCES:String = "QUEUE_MATCH_RESOURCES";
      
      public static const BEFORE_APPLY_DAMAGE:String = "BEFORE_APPLY_DAMAGE";
      
      public static const AFTER_APPLY_DAMAGE:String = "AFTER_APPLY_DAMAGE";
      
      public static const BEFORE_APPLY_KNOCKBACK:String = "BEFORE_APPLY_KNOCKBACK";
      
      public static const AFTER_APPLY_KNOCKBACK:String = "AFTER_APPLY_KNOCKBACK";
      
      public static const BEFORE_HITSTUN:String = "BEFORE_HITSTUN";
      
      public static const BEFORE_KO:String = "BEFORE_KO";
      
      public static const AFTER_KO:String = "AFTER_KO";
      
      public static const BEFORE_LEDGE_GRAB:String = "BEFORE_LEDGE_GRAB";
      
      public static const AFTER_LEDGE_GRAB:String = "AFTER_LEDGE_GRAB";
      
      public static const BEFORE_POWER_SHIELD:String = "BEFORE_POWER_SHIELD";
      
      public static const BEFORE_SHIELD:String = "BEFORE_SHIELD";
      
      public static const AFTER_SHIELD_BREAK:String = "AFTER_SHIELD_BREAK";
      
      public static const BEFORE_GRAB:String = "BEFORE_GRAB";
      
      public static const BEFORE_THROW:String = "BEFORE_THROW";
      
      public static const BEFORE_RESPAWN:String = "BEFORE_RESPAWN";
      
      public static const AFTER_RESPAWN:String = "AFTER_RESPAWN";
      
      public static const STOCK_CHANGE:String = "STOCK_CHANGE";
      
      public static const STOCK_LOST:String = "STOCK_LOST";
      
      public static const BEFORE_TAUNT:String = "BEFORE_TAUNT";
      
      public static const BEFORE_CHARACTER_SPAWN:String = "BEFORE_CHARACTER_SPAWN";
      
      public static const AFTER_CHARACTER_SPAWN:String = "AFTER_CHARACTER_SPAWN";
      
      public static const BEFORE_CHARACTER_SWITCH:String = "BEFORE_CHARACTER_SWITCH";
      
      public static const AFTER_CHARACTER_SWITCH:String = "AFTER_CHARACTER_SWITCH";
      
      public static const BEFORE_TRANSFORM:String = "BEFORE_TRANSFORM";
      
      public static const AFTER_TRANSFORM:String = "AFTER_TRANSFORM";
      
      public static const AFTER_ATTACH_EFFECT:String = "AFTER_ATTACH_EFFECT";
      
      public static const AFTER_ATTACH_EFFECT_OVERLAY:String = "AFTER_ATTACH_EFFECT_OVERLAY";
      
      public static const BEFORE_STANCE_PAINT:String = "BEFORE_STANCE_PAINT";
      
      public static const AFTER_STANCE_PAINT:String = "AFTER_STANCE_PAINT";
      
      public static const BEFORE_HEALTHBOX_PAINT:String = "BEFORE_HEALTHBOX_PAINT";
      
      public static const BEFORE_PROJECTILE_SPAWN:String = "BEFORE_PROJECTILE_SPAWN";
      
      public static const AFTER_PROJECTILE_SPAWN:String = "AFTER_PROJECTILE_SPAWN";
      
      public static const BEFORE_PROJECTILE_HIT:String = "BEFORE_PROJECTILE_HIT";
      
      public static const BEFORE_ITEM_SPAWN:String = "BEFORE_ITEM_SPAWN";
      
      public static const STATS_SYNC:String = "STATS_SYNC";
      
      public static const COSTUME_LIST_MERGE:String = "COSTUME_LIST_MERGE";
      
      public static const AI_DECIDE:String = "AI_DECIDE";
      
      public static const HITBOX_CREATE:String = "HITBOX_CREATE";
      
      public static const MENU_SHOW:String = "MENU_SHOW";
      
      public static const MENU_HIDE:String = "MENU_HIDE";
      
      public static const MENU_BACK:String = "MENU_BACK";
      
      public static const MENU_GESTURE:String = "MENU_GESTURE";
      
      public static const RUMBLE:String = "RUMBLE";
      
      public static const MENU_CREATE:String = "MENU_CREATE";
      
      public static const CSS_SELECT_CHARACTER:String = "CSS_SELECT_CHARACTER";
      
      public static const CSS_APPLY_COSTUME:String = "CSS_APPLY_COSTUME";
      
      public static const CSS_CHANGE_COSTUME_INDEX:String = "CSS_CHANGE_COSTUME_INDEX";
      
      public static const CSS_TEAM_CHANGED:String = "CSS_TEAM_CHANGED";
      
      public static const CSS_SLOT_ACTION:String = "CSS_SLOT_ACTION";
      
      public static const CSS_READY_CONFIRM:String = "CSS_READY_CONFIRM";
      
      public static const CSS_NAME_PENCIL:String = "CSS_NAME_PENCIL";
      
      public static const BEFORE_CHIP_UPDATE:String = "BEFORE_CHIP_UPDATE";
      
      public static const STAGE_SELECT:String = "STAGE_SELECT";
      
      public static const STAGE_SELECT_GESTURE:String = "STAGE_SELECT_GESTURE";
      
      public static const VAULT_SHOW:String = "VAULT_SHOW";
      
      public static const VAULT_HIDE:String = "VAULT_HIDE";
      
      public static const VAULT_REPLAY:String = "VAULT_REPLAY";
      
      public static const RESULTS_SHOW:String = "RESULTS_SHOW";
      
      public static const HUD_UPDATE:String = "HUD_UPDATE";
      
      public static const GROUP_MENU_NAV:String = "GROUP_MENU_NAV";
      
      public static const ONLINE_MENU_SHOW:String = "ONLINE_MENU_SHOW";
      
      public static const BEFORE_SEND_ROOM_DATA:String = "BEFORE_SEND_ROOM_DATA";
      
      public static const ROOM_DATA_RECEIVED:String = "ROOM_DATA_RECEIVED";
      
      public static const CONTROLS_MENU_SHOW:String = "CONTROLS_MENU_SHOW";
      
      public static const TITLE_ENTER:String = "TITLE_ENTER";
      
      public static const RESOURCE_QUEUED:String = "RESOURCE_QUEUED";
      
      public static const RESOURCE_LOADED:String = "RESOURCE_LOADED";
      
      public static const RESOURCE_FAILED:String = "RESOURCE_FAILED";
      
      public static const RESOURCE_POOL_READY:String = "RESOURCE_POOL_READY";
      
      public static const SAVE_LOAD:String = "SAVE_LOAD";
      
      public static const SAVE_WRITE:String = "SAVE_WRITE";
      
      public static const SAVE_CORRUPT:String = "SAVE_CORRUPT";
      
      public static const CAMERA_UPDATE:String = "CAMERA_UPDATE";
      
      public static const BOOT_AFTER_RESOURCES:String = "BOOT_AFTER_RESOURCES";
      
      public static const GAME_CREATE:String = "GAME_CREATE";
      
      public static const GAME_DESTROY:String = "GAME_DESTROY";
      
      public static const SETTINGS_APPLY:String = "SETTINGS_APPLY";
      
      public static const PLAYER_SETTINGS_UPDATE:String = "PLAYER_SETTINGS_UPDATE";
      
      public static const UNLOCK_GRANT:String = "UNLOCK_GRANT";
      
      public static const MENU_NAVIGATE:String = "MENU_NAVIGATE";
      
      public static const MATCH_RESULTS_BUILD:String = "MATCH_RESULTS_BUILD";
      
      public static const CHIP_SELECT:String = "CHIP_SELECT";
      
      public static const MUSIC_START:String = "MUSIC_START";
      
      public static const MUSIC_STOP:String = "MUSIC_STOP";
      
      public static const MUSIC_FADE:String = "MUSIC_FADE";
      
      public static const BEFORE_INPUT_APPLY:String = "BEFORE_INPUT_APPLY";
      
      public static const KEY_EVENT:String = "KEY_EVENT";
      
      public static const GAMEPAD_EVENT:String = "GAMEPAD_EVENT";
      
      public static const INPUT_REMAP:String = "INPUT_REMAP";
      
      public static const BEFORE_ITEM_PICKUP:String = "BEFORE_ITEM_PICKUP";
      
      public static const AFTER_ITEM_PICKUP:String = "AFTER_ITEM_PICKUP";
      
      public static const BEFORE_ITEM_USE:String = "BEFORE_ITEM_USE";
      
      public static const BEFORE_ITEM_HIT:String = "BEFORE_ITEM_HIT";
      
      public static const ITEM_DESTROY:String = "ITEM_DESTROY";
      
      public static const ASSIST_SPAWN:String = "ASSIST_SPAWN";
      
      public static const ASSIST_FADE:String = "ASSIST_FADE";
      
      public static const ASSIST_DESTROY:String = "ASSIST_DESTROY";
      
      public static const ENEMY_SPAWN:String = "ENEMY_SPAWN";
      
      public static const ENEMY_HIT:String = "ENEMY_HIT";
      
      public static const ENEMY_DESTROY:String = "ENEMY_DESTROY";
      
      public static const ENEMY_AI_STEP:String = "ENEMY_AI_STEP";
      
      public static const MODE_SELECT:String = "MODE_SELECT";
      
      public static const MODE_START:String = "MODE_START";
      
      public static const MODE_END:String = "MODE_END";
      
      public static const MODE_SCORE:String = "MODE_SCORE";
      
      public static const RULESET_CHANGE:String = "RULESET_CHANGE";
      
      public static const NET_LOBBY_JOIN:String = "NET_LOBBY_JOIN";
      
      public static const NET_LOBBY_LEAVE:String = "NET_LOBBY_LEAVE";
      
      public static const NET_COSTUME_RESOLVE:String = "NET_COSTUME_RESOLVE";
      
      public static const NET_NOTIFY:String = "NET_NOTIFY";
      
      public static const PLATFORM_STEP:String = "PLATFORM_STEP";
      
      public static const STAGE_BOUNDARY_HIT:String = "STAGE_BOUNDARY_HIT";
      
      public static const MOVING_PLATFORM_UPDATE:String = "MOVING_PLATFORM_UPDATE";
      
      public static const CUSTOM_EVENT:String = "CUSTOM_EVENT";
      
      public static const ATTRACT_MEDIA:String = "ATTRACT_MEDIA";
      
      public function ModHooks()
      {
         super();
      }
   }
}
