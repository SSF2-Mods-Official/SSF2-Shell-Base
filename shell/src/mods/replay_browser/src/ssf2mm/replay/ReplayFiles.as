package ssf2mm.replay
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.audio.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.enums.*;
   import com.mcleodgaming.ssf2.modapi.ModAPI;
   import com.mcleodgaming.ssf2.modhost.ModHost;
   import com.mcleodgaming.ssf2.net.*;
   import com.mcleodgaming.ssf2.util.GameLog;
   import com.mcleodgaming.ssf2.util.ResourceManager;
   import com.mcleodgaming.ssf2.util.Utils;
   import ssf2mm.shared.JsonFile;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.geom.*;
   import flash.net.*;
   import flash.text.*;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   
   /** Replay folders (default plus extras in app storage), file order, reading and checking a replay, import sanitize. */
   public class ReplayFiles
   {
      public static const FOLDER_CFG:String = "replay_folder.cfg";
      
      public static function defaultReplayFolder() : File
      {
         return File.userDirectory.resolvePath("SSF2Replays/" + Version.getVersion());
      }
      
      public static function getReplayFolder() : File
      {
         return defaultReplayFolder();
      }
      
      /** Default folder first, then each extra path. A plain cfg path from an older build is one extra. */
      public static function getReplayFolders() : Array
      {
         var out:Array = [];
         var seen:Object = {};
         var paths:Array = extraFolderPaths();
         var i:int = 0;
         addFolder(out,seen,defaultReplayFolder());
         while(i < paths.length)
         {
            try
            {
               addFolder(out,seen,new File(String(paths[i])));
            }
            catch(pathErr:*)
            {
            }
            i++;
         }
         return out;
      }
      
      public static function hasExtraFolders() : Boolean
      {
         return extraFolderPaths().length > 0;
      }
      
      /** "ok", "default", "duplicate", or "fail". */
      public static function addExtraFolder(path:String) : String
      {
         var folder:File = null;
         var extras:Array = null;
         var i:int = 0;
         var folderKey:String = null;
         var extraKey:String = null;
         try
         {
            folder = new File(path);
            folderKey = folder.nativePath.toLowerCase();
            if(folderKey == defaultReplayFolder().nativePath.toLowerCase())
            {
               return "default";
            }
         }
         catch(pathErr:*)
         {
            return "fail";
         }
         extras = extraFolderPaths();
         while(i < extras.length)
         {
            try
            {
               extraKey = new File(String(extras[i])).nativePath.toLowerCase();
               if(extraKey == folderKey)
               {
                  return "duplicate";
               }
            }
            catch(extraErr:*)
            {
            }
            i++;
         }
         extras.push(folder.nativePath);
         if(!JsonFile.writeText(File.applicationStorageDirectory.resolvePath(FOLDER_CFG),JSON.stringify({"extra":extras})))
         {
            logLine("[replay_browser] save " + FOLDER_CFG + " failed");
            return "fail";
         }
         return "ok";
      }
      
      /** Drops one extra path. The default replay folder is not stored here. */
      public static function removeExtraFolder(path:String) : void
      {
         var extras:Array = extraFolderPaths();
         var kept:Array = [];
         var i:int = 0;
         var one:String = null;
         var dropKey:String = null;
         try
         {
            dropKey = new File(path).nativePath.toLowerCase();
         }
         catch(pathErr:*)
         {
            return;
         }
         while(i < extras.length)
         {
            one = String(extras[i]);
            try
            {
               if(new File(one).nativePath.toLowerCase() != dropKey)
               {
                  kept.push(one);
               }
            }
            catch(oneErr:*)
            {
               kept.push(one);
            }
            i++;
         }
         if(kept.length == 0)
         {
            clearCustomFolderPath();
            return;
         }
         if(!JsonFile.writeText(File.applicationStorageDirectory.resolvePath(FOLDER_CFG),JSON.stringify({"extra":kept})))
         {
            logLine("[replay_browser] save " + FOLDER_CFG + " failed");
         }
      }
      
      public static function extraFolderPaths() : Array
      {
         var text:String = JsonFile.readText(File.applicationStorageDirectory.resolvePath(FOLDER_CFG));
         var obj:Object = null;
         var extra:Array = null;
         var out:Array = [];
         var one:* = undefined;
         text = text ? text.replace(/^\s+|\s+$/g,"") : "";
         if(text.length == 0)
         {
            return out;
         }
         if(text.charAt(0) == "{")
         {
            try
            {
               obj = JSON.parse(text);
               extra = obj && obj.extra is Array ? obj.extra as Array : null;
               if(extra)
               {
                  for each(one in extra)
                  {
                     if(one != null && String(one).length > 0)
                     {
                        out.push(String(one));
                     }
                  }
               }
            }
            catch(parseErr:*)
            {
               logLine("[replay_browser] replay_folder.cfg parse failed: " + parseErr);
            }
            return out;
         }
         out.push(text);
         return out;
      }
      
      public static function loadCustomFolderPath() : String
      {
         var paths:Array = extraFolderPaths();
         return paths.length > 0 ? String(paths[0]) : null;
      }
      
      public static function saveCustomFolderPath(param1:String) : void
      {
         addExtraFolder(param1);
      }
      
      public static function clearCustomFolderPath() : void
      {
         var _loc1_:File = null;
         try
         {
            _loc1_ = File.applicationStorageDirectory.resolvePath(FOLDER_CFG);
            if(_loc1_.exists)
            {
               _loc1_.deleteFile();
            }
         }
         catch(e:*)
         {
            logLine("[replay_browser] clearCustomFolderPath failed: " + e);
         }
      }
      
      private static function addFolder(out:Array, seen:Object, folder:File) : void
      {
         var key:String = null;
         if(folder == null)
         {
            return;
         }
         try
         {
            key = folder.nativePath.toLowerCase();
         }
         catch(pathErr:*)
         {
            return;
         }
         if(seen[key])
         {
            return;
         }
         seen[key] = true;
         out.push(folder);
      }
      
      private static function logLine(line:String) : void
      {
         trace(line);
         try
         {
            GameLog.write(line);
         }
         catch(logErr:*)
         {
         }
      }
      
      /**
       * GameSettings, PlayerSetting, and ItemSettings are sealed. An unknown key
       * throws Error #1069 on importSettings. Copy known fields only.
       */
      public static function sanitizeMatchSettingsForImport(rd:ReplayData) : void
      {
         var ms:Object = null;
         var clean:Object = null;
         var key:String = null;
         var bg:* = undefined;
         var known:Object = null;
         var stageId:String = null;
         if(rd == null)
         {
            return;
         }
         sanitizePlayersForImport(rd);
         sanitizeItemsForImport(rd);
         ms = rd.MatchSettings as Object;
         if(ms == null)
         {
            return;
         }
         bg = ms["backgroundStage"];
         known = {
            "stage":true,
            "musicOverride":true,
            "sizeRatio":true,
            "lives":true,
            "usingStamina":true,
            "time":true,
            "countdown":true,
            "usingTime":true,
            "usingLives":true,
            "finalSmashMeter":true,
            "scoreDisplay":true,
            "hudDisplay":true,
            "pauseEnabled":true,
            "showPlayerID":true,
            "startDamage":true,
            "startStamina":true,
            "damageRatio":true,
            "teams":true,
            "teamDamage":true,
            "hazards":true,
            "specialModes":true,
            "randSeed":true,
            "inputBuffer":true,
            "scoreLimit":true,
            "difficulty":true,
            "showEntrances":true,
            "showCountdown":true,
            "showCountdownType":true,
            "showEndCountdown":true,
            "customModeID":true,
            "unlocks":true
         };
         clean = {};
         for(key in ms)
         {
            if(known[key])
            {
               clean[key] = ms[key];
            }
         }
         stageId = clean.stage != null ? String(clean.stage) : "";
         if(stageId.length == 0 || stageId == "null" || !stageResourceKnown(stageId))
         {
            logLine("[replay_browser] drop missing stage " + (stageId.length > 0 && stageId != "null" ? stageId : "(none)"));
            if(stageId.length > 0 && stageId != "null")
            {
               try
               {
                  MultiplayerManager.makeNotifier();
                  MultiplayerManager.notify("Stage " + stageId + " is not installed. Using Battlefield.");
               }
               catch(noteErr:*)
               {
               }
            }
            clean.stage = "battlefield";
         }
         if(clean.musicOverride != null)
         {
            var musicId:String = String(clean.musicOverride);
            if(musicId.length == 0 || musicId == "null" || !stageResourceKnown(musicId))
            {
               logLine("[replay_browser] drop musicOverride " + musicId);
               delete clean.musicOverride;
            }
         }
         rd.MatchSettings = clean;
         try
         {
            if(bg != null && String(bg).length > 0 && String(bg) != "null")
            {
               var bgId:String = String(bg);
               var ok:Boolean = bgId == "menu_space" || stageResourceKnown(bgId);
               ModHost.setSessionFlag("backgroundStage",ok ? bgId : null);
               if(ok)
               {
                  logLine("[replay_browser] restore backgroundStage " + bgId);
               }
               else
               {
                  logLine("[replay_browser] drop missing backgroundStage " + bgId);
               }
            }
            else
            {
               ModHost.setSessionFlag("backgroundStage",null);
            }
         }
         catch(flagErr:*)
         {
            logLine("[replay_browser] sanitizeMatchSettingsForImport failed: " + flagErr);
         }
      }
      
      /** PlayerSetting fields. Anything else throws #1069 in importSettings. */
      public static function sanitizePlayersForImport(rd:ReplayData) : void
      {
         var list:* = null;
         var known:Object = null;
         var out:Array = null;
         var i:int = 0;
         var src:Object = null;
         var clean:Object = null;
         var key:String = null;
         var n:int = 0;
         if(rd == null || rd.PlayerData == null)
         {
            return;
         }
         list = rd.PlayerData;
         known = {
            "character":true,
            "name":true,
            "level":true,
            "damageRatio":true,
            "attackRatio":true,
            "human":true,
            "exist":true,
            "team":true,
            "costume":true,
            "colorVaultId":true,
            "alternate":true,
            "team_prev":true,
            "lives":true,
            "x_start":true,
            "y_start":true,
            "x_respawn":true,
            "y_respawn":true,
            "facingRight":true,
            "unlimitedFinal":true,
            "finalSmashMeter":true,
            "startDamage":true,
            "expansion":true,
            "isRandom":true,
            "socket_id":true,
            "beatDevOnline":true,
            "ranked":true
         };
         out = [];
         n = int(list.length);
         while(i < n)
         {
            src = list[i] as Object;
            if(src == null)
            {
               out.push({
                  "exist":false,
                  "character":null
               });
               logLine("[replay_browser] drop empty player");
            }
            else
            {
               clean = {};
               for(key in src)
               {
                  if(known[key])
                  {
                     clean[key] = src[key];
                  }
                  else
                  {
                     logLine("[replay_browser] drop player key " + key);
                  }
               }
               if(clean.character == null || String(clean.character).length == 0 || String(clean.character) == "null")
               {
                  clean.exist = false;
                  clean.character = null;
                  logLine("[replay_browser] drop empty player");
               }
               else if(String(clean.character) != "random" && !stageResourceKnown(String(clean.character)))
               {
                  logLine("[replay_browser] drop unknown character " + clean.character);
                  clean.exist = false;
                  clean.character = null;
               }
               out.push(clean);
            }
            i++;
         }
         rd.PlayerData = out;
      }
      
      /** ItemSettings fields are frequency and items. */
      public static function sanitizeItemsForImport(rd:ReplayData) : void
      {
         var items:Object = null;
         var clean:Object = null;
         var key:String = null;
         if(rd == null || rd.ItemSettingsObj == null)
         {
            return;
         }
         items = rd.ItemSettingsObj as Object;
         if(items == null)
         {
            return;
         }
         clean = {};
         if(items.hasOwnProperty("frequency"))
         {
            clean.frequency = items.frequency;
         }
         if(items.hasOwnProperty("items"))
         {
            clean.items = items.items;
         }
         for(key in items)
         {
            if(key != "frequency" && key != "items")
            {
               logLine("[replay_browser] drop item key " + key);
            }
         }
         rd.ItemSettingsObj = clean;
      }
      
      /** True when at least one slot still has a character after sanitize. */
      public static function hasLivingPlayer(rd:ReplayData) : Boolean
      {
         var list:* = null;
         var i:int = 0;
         var src:Object = null;
         var n:int = 0;
         if(rd == null || rd.PlayerData == null)
         {
            logLine("[replay_browser] replay has no characters");
            return false;
         }
         list = rd.PlayerData;
         while(i < int(list.length))
         {
            src = list[i] as Object;
            if(src != null && Boolean(src.exist) && src.character != null && String(src.character).length > 0 && String(src.character) != "null")
            {
               n++;
            }
            i++;
         }
         if(n < 1)
         {
            logLine("[replay_browser] replay has no characters");
         }
         return n > 0;
      }
      
      /** Stage exists in this build (Added is enough — SWF need not be loaded yet). */
      public static function stageResourceKnown(stageId:String) : Boolean
      {
         var res:* = null;
         var mappings:* = null;
         var meta:Object = null;
         if(!stageId)
         {
            return false;
         }
         try
         {
            res = ResourceManager.getResourceByID(stageId);
            if(res && (res.FileName || res.ID))
            {
               return true;
            }
         }
         catch(resErr:*)
         {
         }
         try
         {
            mappings = ResourceManager.getResourceByID("mappings");
            meta = mappings && mappings.getProp is Function ? mappings.getProp("metadata") as Object : null;
            if(meta && meta.stage && meta.stage[stageId])
            {
               return true;
            }
         }
         catch(mapErr:*)
         {
         }
         return false;
      }
      
      /** Newest modificationDate first (sortOn does not order Date fields reliably). */
      public static function compareReplayDateNewestFirst(a:File, b:File) : int
      {
         var ta:Number = 0;
         var tb:Number = 0;
         try
         {
            if(a && a.modificationDate)
            {
               ta = a.modificationDate.getTime();
            }
         }
         catch(eA:*)
         {
         }
         try
         {
            if(b && b.modificationDate)
            {
               tb = b.modificationDate.getTime();
            }
         }
         catch(eB:*)
         {
         }
         if(ta > tb)
         {
            return -1;
         }
         if(ta < tb)
         {
            return 1;
         }
         return 0;
      }
      
      /** Cache key: a replay rewritten in place (same path) is parsed again. */
      public static function metaKey(f:File) : String
      {
         try
         {
            return f.nativePath + "|" + f.modificationDate.getTime() + "|" + f.size;
         }
         catch(e:*)
         {
         }
         return f.nativePath;
      }
      
      /** Reads and checks a replay; notifies and returns null when it cannot be played. */
      public static function readPlayableReplay(f:File) : ReplayData
      {
         var raw:ByteArray = new ByteArray();
         var stream:FileStream = null;
         var rd:ReplayData = null;
         var step:String = "read";
         MultiplayerManager.makeNotifier();
         try
         {
            stream = new FileStream();
            stream.open(f,FileMode.READ);
            stream.readBytes(raw);
            stream.close();
            step = "uncompress";
            raw.uncompress();
            step = "import";
            rd = new ReplayData(Main.MAXPLAYERS);
            rd.importReplay(raw.readUTF());
         }
         catch(e:*)
         {
            trace("[replay_browser] replay " + step + " failed (" + f.name + "): " + e);
            MultiplayerManager.notify(step == "read" ? "Replay file could not be loaded." : (step == "uncompress" ? "Replay file could not be decompressed." : "Replay file could not be read."));
            return null;
         }
         if(rd.VersionNumber != Version.getVersion() && ReplayData.COMPATIBLE_VERSIONS.indexOf(rd.VersionNumber) < 0)
         {
            MultiplayerManager.notify("Error, incompatible version number. Received version\t" + rd.VersionNumber + " (Expecting " + Version.getVersion() + ")");
            return null;
         }
         if(!ModeFeatures.hasFeature(ModeFeatures.ALLOW_REPLAY_RECORD,rd.GameMode) || rd.GameMode === Mode.CLASSIC)
         {
            MultiplayerManager.notify("Replay file was not playable.");
            return null;
         }
         return rd;
      }
   }
}
