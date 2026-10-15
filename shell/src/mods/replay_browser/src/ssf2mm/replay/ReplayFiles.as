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
   
   /** Replay folder (custom path in app storage), file order, reading and checking a replay, MatchSettings sanitize. */
   public class ReplayFiles
   {
      public static const FOLDER_CFG:String = "replay_folder.cfg";
      
      public static function getReplayFolder() : File
      {
         var _loc1_:String = loadCustomFolderPath();
         if(_loc1_ != null)
         {
            return new File(_loc1_);
         }
         return File.userDirectory.resolvePath("SSF2Replays/" + Version.getVersion());
      }
      
      public static function loadCustomFolderPath() : String
      {
         var text:String = JsonFile.readText(File.applicationStorageDirectory.resolvePath(FOLDER_CFG));
         text = text ? text.replace(/^\s+|\s+$/g,"") : "";
         return text.length > 0 ? text : null;
      }
      
      public static function saveCustomFolderPath(param1:String) : void
      {
         if(!JsonFile.writeText(File.applicationStorageDirectory.resolvePath(FOLDER_CFG),param1))
         {
            trace("[replay_browser] save " + FOLDER_CFG + " failed");
         }
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
            trace("[replay_browser] clearCustomFolderPath failed: " + e);
         }
      }
      
      /**
       * GameSettings is sealed — unknown MatchSettings keys (e.g. backgroundStage)
       * throw Error #1069 on importSettings. Pull mod extras out first, then whitelist.
       */
      public static function sanitizeMatchSettingsForImport(rd:ReplayData) : void
      {
         var ms:Object = null;
         var clean:Object = null;
         var key:String = null;
         var bg:* = undefined;
         var known:Object = null;
         if(rd == null)
         {
            return;
         }
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
         rd.MatchSettings = clean;
         try
         {
            if(bg != null && String(bg).length > 0 && String(bg) != "null")
            {
               var bgId:String = String(bg);
               var ok:Boolean = stageResourceKnown(bgId);
               ModHost.setSessionFlag("backgroundStage",ok ? bgId : null);
               if(ok)
               {
                  trace("[replay_browser] restore backgroundStage " + bgId);
               }
               else
               {
                  trace("[replay_browser] drop missing backgroundStage " + bgId);
               }
            }
            else
            {
               ModHost.setSessionFlag("backgroundStage",null);
            }
         }
         catch(flagErr:*)
         {
            trace("[replay_browser] sanitizeMatchSettingsForImport failed: " + flagErr);
         }
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
