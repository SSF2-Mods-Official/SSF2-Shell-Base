package com.mcleodgaming.ssf2.util
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.media.Sound;
   import flash.net.URLRequest;

   /**
    * Alternate files for a character the game already has (expansions/alts/alts.json).
    * Jump cycles every alt. Costume-tied picks also set PlayerSetting.costume.
    * mode "sounds": keep stock character SWF; play clips from sounds/ via tryGetAltSound.
    * Otherwise UrlOverride swaps the character SWF (GameBanana sound packs).
    */
   public class CharacterAlts
   {
      private static var m_data:Object = null;
      private static var m_picks:Object = {};
      private static var m_costumes:Object = {};
      /** linkage → relative path under applicationDirectory (sound-only alts). */
      private static var m_soundFiles:Object = {};
      /** path → Sound cache */
      private static var m_soundCache:Object = {};

      public function CharacterAlts()
      {
         super();
      }

      public static function load() : void
      {
         var file:File = null;
         var stream:FileStream = null;
         var chars:int = 0;
         var alts:int = 0;
         var id:String = null;
         m_data = {};
         try
         {
            file = File.applicationDirectory.resolvePath("expansions/alts/alts.json");
            if(file.exists)
            {
               stream = new FileStream();
               stream.open(file,FileMode.READ);
               var parsed:Object = JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
               stream.close();
               if(parsed && parsed.characters)
               {
                  m_data = parsed.characters;
               }
            }
         }
         catch(err:*)
         {
            GameLog.write("[alts] load failed " + err);
            m_data = {};
         }
         for(id in m_data)
         {
            if(m_data[id] is Array && m_data[id].length > 0)
            {
               chars++;
               alts += m_data[id].length;
            }
         }
         GameLog.write("[alts] load characters=" + chars + " alts=" + alts);
      }

      private static function listFor(character:String) : Array
      {
         if(m_data == null)
         {
            load();
         }
         if(!character || !(m_data[character] is Array))
         {
            return null;
         }
         return m_data[character] as Array;
      }

      private static function isAllScope(entry:Object) : Boolean
      {
         if(!entry)
         {
            return true;
         }
         var scope:String = entry.scope ? String(entry.scope) : "all";
         return scope.length == 0 || scope.toLowerCase() == "all";
      }

      /** Local voice alt: mode "sounds" or empty files map — stock SWF + sounds folder. */
      private static function isSoundOnly(entry:Object) : Boolean
      {
         var mode:String = null;
         var n:int = 0;
         var k:String = null;
         if(!entry)
         {
            return false;
         }
         mode = entry.mode ? String(entry.mode).toLowerCase() : "";
         if(mode == "sounds")
         {
            return true;
         }
         if(!entry.files)
         {
            return true;
         }
         for(k in entry.files)
         {
            n++;
         }
         return n == 0;
      }

      private static function hasFileMap(entry:Object) : Boolean
      {
         var k:String = null;
         if(!entry || !entry.files || isSoundOnly(entry))
         {
            return false;
         }
         for(k in entry.files)
         {
            return true;
         }
         return false;
      }

      /** Every alt for the character (jump list). */
      private static function cycleList(character:String) : Array
      {
         var list:Array = listFor(character);
         return list ? list : [];
      }

      public static function count(character:String) : int
      {
         return cycleList(character).length;
      }

      /** 0 is stock, 1..count is an alt in cycleList order. */
      public static function picked(player:int, character:String) : int
      {
         var pick:Object = m_picks[player];
         if(!pick || pick.character != character)
         {
            return 0;
         }
         return int(pick.alt);
      }

      /**
       * Advance jump pick. When the next entry is costume-tied, sets playerSettings.costume
       * (if provided) and records onCostumeChange so apply() uses that voice.
       */
      public static function cycle(player:int, character:String, playerSettings:Object = null) : int
      {
         var list:Array = cycleList(character);
         var total:int = list.length;
         var next:int = 0;
         var entry:Object = null;
         var cos:int = 0;
         if(total <= 0)
         {
            return 0;
         }
         next = (picked(player,character) + 1) % (total + 1);
         m_picks[player] = {
            "character":character,
            "alt":next,
            "at":new Date().time
         };
         GameLog.write("[alts] cycle p=" + player + " character=" + character + " alt=" + next + "/" + total);
         if(next > 0 && next <= list.length)
         {
            entry = list[next - 1];
            if(entry && !isAllScope(entry))
            {
               cos = int(entry.costume);
               if(playerSettings)
               {
                  playerSettings.costume = cos;
               }
               onCostumeChange(player,character,cos);
               GameLog.write("[alts] cycle costume=" + cos + " scope=costume p=" + player);
            }
         }
         apply();
         return next;
      }

      /** CSS portrait label: costume-tied name, or jump name with (i/total), or null for stock. */
      public static function label(player:int, character:String, stockName:String) : String
      {
         var costumeEntry:Object = costumeMatch(player,character);
         if(costumeEntry)
         {
            if(costumeEntry.name && String(costumeEntry.name).length > 0)
            {
               return String(costumeEntry.name);
            }
            return (stockName ? stockName : character) + " Alt";
         }
         var alt:int = picked(player,character);
         var list:Array = cycleList(character);
         if(alt <= 0 || alt > list.length)
         {
            return null;
         }
         var entry:Object = list[alt - 1];
         var total:int = list.length;
         if(entry && entry.name && String(entry.name).length > 0)
         {
            return String(entry.name) + " (" + alt + "/" + total + ")";
         }
         return (stockName ? stockName : character) + " Alt " + alt + "/" + total;
      }

      /** Match HUD name when no nametag: active alt name only (no i/total). Null → use stock DisplayName. */
      public static function hudName(player:int, character:String, stockName:String) : String
      {
         var costumeEntry:Object = costumeMatch(player,character);
         var alt:int = 0;
         var list:Array = null;
         var entry:Object = null;
         if(costumeEntry)
         {
            if(costumeEntry.name && String(costumeEntry.name).length > 0)
            {
               return String(costumeEntry.name);
            }
            return null;
         }
         alt = picked(player,character);
         list = cycleList(character);
         if(alt <= 0 || alt > list.length)
         {
            return null;
         }
         entry = list[alt - 1];
         if(entry && entry.name && String(entry.name).length > 0)
         {
            return String(entry.name);
         }
         return null;
      }

      public static function onSetPlayer(player:int, character:String) : void
      {
         var pick:Object = m_picks[player];
         if(pick && pick.character != character && int(pick.alt) > 0)
         {
            delete m_picks[player];
            GameLog.write("[alts] reset p=" + player);
         }
         var cos:Object = m_costumes[player];
         if(cos && cos.character != character)
         {
            delete m_costumes[player];
         }
         apply();
      }

      /** Called when CSS changes PlayerSetting.costume. */
      public static function onCostumeChange(player:int, character:String, costume:int) : void
      {
         var pick:Object = m_picks[player];
         var jumpList:Array = null;
         var entry:Object = null;
         m_costumes[player] = {
            "character":character,
            "costume":costume
         };
         GameLog.write("[alts] costume p=" + player + " character=" + character + " costume=" + costume);
         // Costume-tied jump pick only stays while that costume is selected.
         if(pick && pick.character == character && int(pick.alt) > 0)
         {
            jumpList = cycleList(character);
            if(int(pick.alt) <= jumpList.length)
            {
               entry = jumpList[int(pick.alt) - 1];
               if(entry && !isAllScope(entry) && int(entry.costume) != costume)
               {
                  delete m_picks[player];
                  GameLog.write("[alts] clear jump pick costume mismatch p=" + player);
               }
            }
         }
         apply();
      }

      private static function costumeMatch(player:int, character:String) : Object
      {
         var cos:Object = m_costumes[player];
         var list:Array = listFor(character);
         var i:int = 0;
         var entry:Object = null;
         var want:int = 0;
         if(!cos || cos.character != character || !list)
         {
            return null;
         }
         want = int(cos.costume);
         for(i = 0; i < list.length; i++)
         {
            entry = list[i];
            if(!entry || isAllScope(entry))
            {
               continue;
            }
            if(int(entry.costume) == want)
            {
               return entry;
            }
         }
         return null;
      }

      /** Active alt entry for a character (costume-tied wins over jump pick), or null for stock. */
      private static function activeEntry(character:String) : Object
      {
         var list:Array = listFor(character);
         var jumpList:Array = null;
         var latest:Object = null;
         var p:String = null;
         var pick:Object = null;
         var cos:Object = null;
         var entry:Object = null;
         var i:int = 0;
         if(!list)
         {
            return null;
         }
         for(p in m_costumes)
         {
            cos = m_costumes[p];
            if(!cos || cos.character != character)
            {
               continue;
            }
            for(i = 0; i < list.length; i++)
            {
               entry = list[i];
               if(!entry || isAllScope(entry))
               {
                  continue;
               }
               if(int(entry.costume) == int(cos.costume))
               {
                  return entry;
               }
            }
         }
         jumpList = cycleList(character);
         for(p in m_picks)
         {
            pick = m_picks[p];
            if(pick && pick.character == character && int(pick.alt) > 0 && (!latest || Number(pick.at) > Number(latest.at)))
            {
               latest = pick;
            }
         }
         if(latest && int(latest.alt) > 0 && int(latest.alt) <= jumpList.length)
         {
            entry = jumpList[int(latest.alt) - 1];
            // Costume-tied jump picks only apply while a player is on that costume.
            if(entry && !isAllScope(entry))
            {
               for(p in m_costumes)
               {
                  cos = m_costumes[p];
                  if(cos && cos.character == character && int(cos.costume) == int(entry.costume))
                  {
                     return entry;
                  }
               }
               return null;
            }
            return entry;
         }
         return null;
      }

      /**
       * Jump / costume pick: SWF alts set UrlOverride; sound-only alts register disk sounds and clear override.
       */
      public static function apply() : void
      {
         var character:String = null;
         var list:Array = null;
         var active:Object = null;
         var rid:String = null;
         var i:int = 0;
         var wantFiles:Object = null;
         if(m_data == null)
         {
            load();
         }
         m_soundFiles = {};
         for(character in m_data)
         {
            list = m_data[character] as Array;
            if(!list)
            {
               continue;
            }
            active = activeEntry(character);
            if(active && isSoundOnly(active))
            {
               registerSoundFolder(active);
               GameLog.write("[alts] apply mode=sounds character=" + character + " folder=" + (active.folder ? active.folder : ""));
               wantFiles = null;
            }
            else if(active && hasFileMap(active))
            {
               wantFiles = active.files;
               if(!isAllScope(active))
               {
                  GameLog.write("[alts] apply costume=" + int(active.costume) + " scope=costume character=" + character);
               }
            }
            else
            {
               wantFiles = null;
            }
            for(i = 0; i < list.length; i++)
            {
               if(!list[i] || !hasFileMap(list[i]))
               {
                  continue;
               }
               for(rid in list[i].files)
               {
                  setOverride(rid,wantFiles && wantFiles[rid] ? String(wantFiles[rid]) : null);
               }
            }
            if(active && isSoundOnly(active))
            {
               setOverride(character,null);
            }
         }
      }

      /** Called from ResourceManager.getLibrarySound before stock library lookup. */
      public static function tryGetAltSound(soundName:String) : Sound
      {
         var path:String = null;
         var key:String = null;
         if(!soundName || !m_soundFiles)
         {
            return null;
         }
         path = m_soundFiles[soundName] as String;
         if(!path)
         {
            for(key in m_soundFiles)
            {
               if(key && key.toLowerCase() == soundName.toLowerCase())
               {
                  path = m_soundFiles[key] as String;
                  break;
               }
            }
         }
         if(!path)
         {
            return null;
         }
         return ensureDiskSound(path);
      }

      /**
       * Only register *replaced* clips (replacements.json). Unreplaced voices stay in the stock SWF
       * so we do not preload dozens of disk Sounds (lag / missing SFX).
       */
      private static function registerSoundFolder(entry:Object) : void
      {
         var folderRel:String = null;
         var soundsDir:File = null;
         var mapFile:File = null;
         var replFile:File = null;
         var stream:FileStream = null;
         var linkages:Object = null;
         var replaced:Object = null;
         var linkage:String = null;
         var fileName:String = null;
         var stem:String = null;
         var n:int = 0;
         var k:String = null;
         if(!entry || !entry.folder)
         {
            return;
         }
         folderRel = String(entry.folder).replace(/\\/g,"/");
         soundsDir = File.applicationDirectory.resolvePath(folderRel.indexOf("alts/") == 0 ? "expansions/" + folderRel + "/sounds" : folderRel + "/sounds");
         if(!soundsDir.exists)
         {
            soundsDir = File.applicationDirectory.resolvePath("expansions/" + folderRel + "/sounds");
         }
         if(!soundsDir.exists)
         {
            GameLog.write("[alts] sounds missing folder=" + soundsDir.nativePath);
            return;
         }
         replFile = soundsDir.resolvePath("replacements.json");
         if(!replFile.exists)
         {
            GameLog.write("[alts] sounds none-replaced character folder=" + folderRel);
            return;
         }
         try
         {
            stream = new FileStream();
            stream.open(replFile,FileMode.READ);
            replaced = JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
            stream.close();
         }
         catch(err:*)
         {
            GameLog.write("[alts] replacements read failed " + err);
            return;
         }
         if(!replaced)
         {
            return;
         }
         mapFile = soundsDir.resolvePath("linkages.json");
         if(mapFile.exists)
         {
            try
            {
               stream = new FileStream();
               stream.open(mapFile,FileMode.READ);
               linkages = JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
               stream.close();
            }
            catch(err2:*)
            {
               linkages = {};
            }
         }
         else
         {
            linkages = {};
         }
         for(linkage in linkages)
         {
            fileName = String(linkages[linkage]);
            if(!fileName || !isReplacedName(replaced,fileName))
            {
               continue;
            }
            if(!soundsDir.resolvePath(fileName).exists)
            {
               continue;
            }
            m_soundFiles[linkage] = relPath(soundsDir,fileName);
            n++;
         }
         // Fallback: replaced filenames whose stem matches a linkage string.
         for(k in replaced)
         {
            fileName = String(k);
            if(!fileName || !/\.(wav|mp3)$/i.test(fileName))
            {
               continue;
            }
            if(!soundsDir.resolvePath(fileName).exists)
            {
               continue;
            }
            stem = fileName.replace(/\.(wav|mp3)$/i,"");
            stem = stem.replace(/^-?\d+_/,"");
            if(stem.length > 0 && !m_soundFiles[stem])
            {
               m_soundFiles[stem] = relPath(soundsDir,fileName);
               n++;
            }
         }
         GameLog.write("[alts] sounds replaced=" + n + " folder=" + folderRel);
      }

      private static function isReplacedName(replaced:Object, fileName:String) : Boolean
      {
         var k:String = null;
         var stem:String = null;
         var other:String = null;
         if(!replaced || !fileName)
         {
            return false;
         }
         if(replaced[fileName] != null)
         {
            return true;
         }
         stem = fileName.replace(/\.(wav|mp3|flv|ogg)$/i,"");
         for(k in replaced)
         {
            other = String(k).replace(/\.(wav|mp3|flv|ogg)$/i,"");
            if(other.toLowerCase() == stem.toLowerCase())
            {
               return true;
            }
         }
         return false;
      }

      private static function relPath(soundsDir:File, fileName:String) : String
      {
         var full:File = soundsDir.resolvePath(fileName);
         var app:String = File.applicationDirectory.nativePath.replace(/\\/g,"/").toLowerCase();
         var path:String = full.nativePath.replace(/\\/g,"/");
         if(path.toLowerCase().indexOf(app) == 0)
         {
            path = path.substring(File.applicationDirectory.nativePath.length);
            while(path.charAt(0) == "/" || path.charAt(0) == "\\")
            {
               path = path.substring(1);
            }
         }
         return path.replace(/\\/g,"/");
      }

      /** Lazy-load one disk Sound; if still buffering, return null so stock SWF plays this time. */
      private static function ensureDiskSound(rel:String) : Sound
      {
         var s:Sound = null;
         var f:File = null;
         if(!rel)
         {
            return null;
         }
         s = m_soundCache[rel] as Sound;
         if(s)
         {
            if(s.bytesTotal > 0 && s.bytesLoaded < s.bytesTotal)
            {
               return null;
            }
            return s;
         }
         try
         {
            f = File.applicationDirectory.resolvePath(rel);
            if(!f.exists)
            {
               GameLog.write("[alts] sound missing path=" + rel);
               return null;
            }
            s = new Sound();
            s.load(new URLRequest(f.url));
            m_soundCache[rel] = s;
            GameLog.write("[alts] sound load path=" + rel);
            if(s.bytesTotal > 0 && s.bytesLoaded < s.bytesTotal)
            {
               return null;
            }
            return s;
         }
         catch(err:*)
         {
            GameLog.write("[alts] sound load failed " + rel + " " + err);
            return null;
         }
      }

      private static function setOverride(resourceId:String, url:String) : void
      {
         var res:Resource = ResourceManager.getResourceByID(resourceId,false);
         var unloaded:int = 0;
         if(!res)
         {
            return;
         }
         if(res.Type != Resource.CHARACTER)
         {
            GameLog.write("[alts] skip resource=" + resourceId + " type=" + res.Type);
            return;
         }
         url = existingUrl(url);
         if(res.UrlOverride == url)
         {
            return;
         }
         if(res.Loaded)
         {
            ResourceManager.unloadResource(res);
            unloaded = 1;
         }
         res.UrlOverride = url;
         GameLog.write("[alts] apply resource=" + resourceId + " url=" + (url ? url : "stock") + " unloaded=" + unloaded);
      }

      private static function existingUrl(url:String) : String
      {
         var other:String = null;
         if(!url)
         {
            return null;
         }
         try
         {
            if(File.applicationDirectory.resolvePath(url).exists)
            {
               return url;
            }
            other = /\.ssf$/i.test(url) ? url.replace(/\.ssf$/i,".swf") : url.replace(/\.swf$/i,".ssf");
            if(other != url && File.applicationDirectory.resolvePath(other).exists)
            {
               return other;
            }
         }
         catch(err:*)
         {
         }
         GameLog.write("[alts] missing url=" + url);
         return url;
      }
   }
}
