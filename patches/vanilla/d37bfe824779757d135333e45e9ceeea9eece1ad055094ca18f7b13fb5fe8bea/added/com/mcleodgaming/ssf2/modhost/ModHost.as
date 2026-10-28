package com.mcleodgaming.ssf2.modhost
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.modapi.*;
   import com.mcleodgaming.ssf2.net.*;
   import com.mcleodgaming.ssf2.util.*;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.system.*;
   import flash.utils.ByteArray;
   import flash.utils.getDefinitionByName;
   import flash.utils.getQualifiedClassName;

   public class ModHost
   {
      
      public static const VERSION_MAJOR:int = 1;
      
      public static const VERSION_MINOR:int = 1;
      
      public static const VERSION_REVISION:int = 0;
      
      public static const HOST_ABI:String = "1.1";
      
      private static var m_booted:Boolean = false;
      
      private static var m_mods:Object = {};
      
      private static var m_modOrder:Array = [];
      
      private static var m_bootInstances:Object = {};
      
      private static var m_matchInstances:Object = {};
      
      private static var m_classReplacements:Object = {};
      
      private static var m_patches:Object = {};
      
      private static var m_hookListeners:Object = {};
      
      private static var m_eventBridge:EventDispatcher = new EventDispatcher();
      
      private static var m_keyListeners:Array = [];
      
      private static var m_pendingSwfLoads:int = 0;
      
      private static var m_bootModsReady:Boolean = false;
      
      private static var m_gameLogAbs:String = "";
      
      public static var pendingStageOverride:String = "";
      
      private static var m_activateJobsStarted:Boolean = false;
      
      private static var m_bootReadyCallbacks:Array = null;
      
      private static var m_loaders:Object = {};
      
      private static var m_domains:Array = [];
      
      private static var m_rulesets:Object = {};
      
      private static var m_sessionFlags:Object = {};
      
      private static var m_inputBlocked:Boolean = false;
      
      private static var m_saveExt:Object = {};
      
      private static var m_playerExt:Object = {};
      
      private static const UI_INST_DEBUG:Boolean = false;
      
      public function ModHost()
      {
         super();
      }
      
      public static function getAPIVersion() : String
      {
         return VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_REVISION;
      }
      
      public static function getHostABI() : String
      {
         return HOST_ABI;
      }
      
      public static function isBooted() : Boolean
      {
         return m_booted;
      }
      
      public static function areBootModsReady() : Boolean
      {
         return m_bootModsReady;
      }
      
      public static function whenBootModsReady(param1:Function) : void
      {
         if(m_bootModsReady)
         {
            if(param1 != null)
            {
               param1();
            }
            return;
         }
         if(m_bootReadyCallbacks == null)
         {
            m_bootReadyCallbacks = [];
         }
         if(param1 != null)
         {
            m_bootReadyCallbacks.push(param1);
         }
      }
      
      private static function maybeFireBootModsReady() : void
      {
         var detail:String = null;
         detail = null;
         detail = null;
         var cbs:Array = null;
         var i:int = 0;
         if(m_bootModsReady)
         {
            return;
         }
         if(!m_activateJobsStarted)
         {
            return;
         }
         if(m_pendingSwfLoads > 0)
         {
            return;
         }
         m_bootModsReady = true;
         cbs = m_bootReadyCallbacks;
         m_bootReadyCallbacks = null;
         GameLog.write("[ModHost] boot mods ready");
         if(!cbs)
         {
            return;
         }
         i = 0;
         while(i < cbs.length)
         {
            try
            {
               if(cbs[i] != null)
               {
                  cbs[i]();
               }
            }
            catch(cbErr:*)
            {
               detail = "";
               try
               {
                  detail = cbErr.message;
               }
               catch(msgErr:*)
               {
               }
               try
               {
                  if(cbErr.getStackTrace != null)
                  {
                     detail += " " + cbErr.getStackTrace();
                  }
               }
               catch(stackErr:*)
               {
               }
               GameLog.write("[ModHost] boot ready callback: " + cbErr + " " + detail);
            }
            i++;
         }
      }
      
      public static function getDefinition(param1:String) : *
      {
         if(!param1 || param1.indexOf("com.mcleodgaming.ssf2.") != 0)
         {
            return null;
         }
         var _loc2_:int = 0;
         var _loc3_:ApplicationDomain = null;
         var _loc4_:* = undefined;
         try
         {
            _loc4_ = getDefinitionByName(param1);
            if(Boolean(_loc4_))
            {
               return _loc4_;
            }
         }
         catch(err:*)
         {
         }
         _loc2_ = 0;
         while(_loc2_ < m_domains.length)
         {
            _loc3_ = m_domains[_loc2_] as ApplicationDomain;
            if(Boolean(_loc3_) && _loc3_.hasDefinition(param1))
            {
               return _loc3_.getDefinition(param1);
            }
            _loc2_++;
         }
         return null;
      }

      public static function readText(modId:String, relative:String) : String
      {
         var file:File = fileInMod(modId, relative);
         var stream:FileStream;
         var text:String;
         if(!file || !file.exists)
         {
            return null;
         }
         stream = new FileStream();
         try
         {
            stream.open(file, FileMode.READ);
            text = stream.readUTFBytes(stream.bytesAvailable);
            stream.close();
            return text;
         }
         catch(err:*)
         {
            return null;
         }
      }

      public static function writeText(modId:String, relative:String, text:String) : Boolean
      {
         var file:File = fileInMod(modId, relative);
         var stream:FileStream;
         if(!file)
         {
            return false;
         }
         stream = new FileStream();
         try
         {
            if(file.parent && !file.parent.exists)
            {
               file.parent.createDirectory();
            }
            stream.open(file, FileMode.WRITE);
            stream.writeUTFBytes(text == null ? "" : text);
            stream.close();
            return true;
         }
         catch(err:*)
         {
            return false;
         }
      }

      private static function swfRefused(bytes:ByteArray) : Boolean
      {
         var text:String;
         var names:Array = ["URLLoader","URLRequest","URLStream","navigateToURL","Socket","ExternalInterface","FileReference","getDefinitionByName","ApplicationDomain","loadBytes","FileStream","FileMode","flash.filesystem","fromCharCode"];
         var i:int = 0;
         var kind:String;
         if(!bytes || bytes.length < 3)
         {
            return true;
         }
         bytes.position = 0;
         kind = bytes.readUTFBytes(3);
         if(kind != "FWS" && kind != "CWS")
         {
            return true;
         }
         if(kind == "CWS")
         {
            var body:ByteArray = new ByteArray();
            bytes.position = 8;
            bytes.readBytes(body);
            try
            {
               body.uncompress();
            }
            catch(zipErr:*)
            {
               return true;
            }
            text = body.readUTFBytes(body.length);
         }
         else
         {
            bytes.position = 0;
            text = bytes.readUTFBytes(bytes.length);
         }
         bytes.position = 0;
         while(i < names.length)
         {
            if(text.indexOf(String(names[i])) >= 0)
            {
               return true;
            }
            i++;
         }
         return false;
      }

      private static function fileInMod(modId:String, relative:String) : File
      {
         var info:ModInfo = getModInfo(modId);
         var root:File;
         var file:File;
         var rel:String;
         if(!info || !info.folderPath || !relative)
         {
            return null;
         }
         rel = relative.split("\\").join("/");
         if(rel.indexOf("..") >= 0 || rel.indexOf(":") >= 0 || rel.charAt(0) == "/")
         {
            return null;
         }
         root = new File(info.folderPath);
         file = root.resolvePath(rel);
         if(file.nativePath.indexOf(root.nativePath) != 0)
         {
            return null;
         }
         return file;
      }
      
      public static function boot() : void
      {
         if(m_booted)
         {
            return;
         }
         GameLog.write("[ModHost] boot() ABI " + getAPIVersion());
         ensureModsOption();
         hydrateSaveExtFromDisk();
         discoverMods();
         activateEnabledMods();
         m_booted = true;
         GameLog.write("[ModHost] boot complete — mods=" + m_modOrder.length);
      }
      
      public static function matchInit(param1:StageData) : void
      {
         var _loc2_:int = 0;
         var _loc3_:String = null;
         var _loc4_:ModInfo = null;
         var _loc5_:* = undefined;
         _loc2_ = 0;
         while(_loc2_ < m_modOrder.length)
         {
            _loc3_ = String(m_modOrder[_loc2_]);
            _loc4_ = m_mods[_loc3_] as ModInfo;
            if(!(!_loc4_ || !isModEnabled(_loc3_)))
            {
               if(!(_loc4_.lifetime != "match" && _loc4_.lifetime != "both"))
               {
                  _loc5_ = createInstanceFromInfo(_loc4_);
                  if(Boolean(_loc5_))
                  {
                     m_matchInstances[_loc3_] = _loc5_;
                     tryCall(_loc5_,"onMatchInit",[param1]);
                     tryCall(_loc5_,"onMatchStart",[param1]);
                  }
               }
            }
            _loc2_++;
         }
      }
      
      public static function matchDeinit() : void
      {
         var _loc1_:String = null;
         var _loc2_:* = undefined;
         for(_loc1_ in m_matchInstances)
         {
            _loc2_ = m_matchInstances[_loc1_];
            tryCall(_loc2_,"onMatchEnd",null);
            tryCall(_loc2_,"onMatchDeinit",null);
         }
         m_matchInstances = {};
      }
      
      public static function getModList() : Array
      {
         var _loc1_:int = 0;
         var _loc2_:String = null;
         var _loc3_:Array = [];
         _loc1_ = 0;
         while(_loc1_ < m_modOrder.length)
         {
            _loc2_ = String(m_modOrder[_loc1_]);
            _loc3_.push(m_mods[_loc2_]);
            _loc1_++;
         }
         return _loc3_;
      }
      
      public static function getModInfo(param1:String) : ModInfo
      {
         return m_mods[param1] as ModInfo;
      }
      
      public static function isModEnabled(param1:String) : Boolean
      {
         var _loc2_:Object = null;
         var _loc3_:ModInfo = null;
         _loc3_ = m_mods[param1] as ModInfo;
         if(!_loc3_)
         {
            return false;
         }
         if(_loc3_.essential)
         {
            return true;
         }
         if(Boolean(_loc3_) && folderInfoHasEnabled(_loc3_.folderPath))
         {
            return folderInfoEnabled(_loc3_.folderPath);
         }
         ensureModsOption();
         _loc2_ = SaveData.ModEnabled;
         if(Boolean(_loc2_) && _loc2_[param1] !== undefined)
         {
            return Boolean(_loc2_[param1]);
         }
         _loc3_ = m_mods[param1] as ModInfo;
         if(Boolean(_loc3_))
         {
            return _loc3_.enabledByDefault;
         }
         return true;
      }
      
      public static function folderInfoEnabled(param1:String) : Boolean
      {
         var stream:FileStream = null;
         stream = null;
         stream = null;
         var folderPath:String = param1;
         var file:File = null;
         stream = null;
         var data:Object = null;
         if(!folderPath)
         {
            return true;
         }
         try
         {
            file = new File(folderPath).resolvePath("info.json");
            if(!file.exists)
            {
               return true;
            }
            stream = new FileStream();
            stream.open(file,FileMode.READ);
            data = JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
            stream.close();
            if(Boolean(data) && data.enabled === false)
            {
               return false;
            }
         }
         catch(err:*)
         {
            try
            {
               if(Boolean(stream))
               {
                  stream.close();
               }
            }
            catch(closeErr:*)
            {
            }
         }
         return true;
      }
      
      public static function folderInfoHasEnabled(param1:String) : Boolean
      {
         var folderPath:String = param1;
         var file:File = null;
         var stream:FileStream = null;
         var data:Object = null;
         if(!folderPath)
         {
            return false;
         }
         try
         {
            file = new File(folderPath).resolvePath("info.json");
            if(!file.exists)
            {
               return false;
            }
            stream = new FileStream();
            stream.open(file,FileMode.READ);
            data = JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
            stream.close();
            return Boolean(data) && data.enabled !== undefined;
         }
         catch(err:*)
         {
            return false;
         }
      }
      
      public static function setModEnabled(param1:String, param2:Boolean) : void
      {
         var _loc3_:Object = null;
         var _loc4_:Boolean = false;
         ensureModsOption();
         _loc4_ = isModEnabled(param1);
         _loc3_ = SaveData.ModEnabled;
         _loc3_[param1] = param2;
         SaveData.ModEnabled = _loc3_;
         SaveData.saveGame();
         if(_loc4_ == param2)
         {
            return;
         }
         GameLog.write("[ModHost] setModEnabled " + param1 + "=" + param2 + " — applying live");
         if(m_booted)
         {
            applyLiveEnableState();
         }
         emit("modEnabledChanged",{
            "id":param1,
            "enabled":param2
         });
      }
      
      public static function reloadBootMods() : void
      {
         applyLiveEnableState();
      }
      
      private static function applyLiveEnableState() : void
      {
         var id:String = null;
         var inst:* = undefined;
         var stageData:StageData = null;
         StageData.holdTelemetry();
         for(id in m_matchInstances)
         {
            inst = m_matchInstances[id];
            tryCall(inst,"onMatchEnd",null);
            tryCall(inst,"onMatchDeinit",null);
         }
         m_matchInstances = {};
         for(id in m_bootInstances)
         {
            inst = m_bootInstances[id];
            tryCall(inst,"onBootEnd",null);
         }
         m_bootInstances = {};
         m_keyListeners = [];
         m_patches = {};
         m_hookListeners = {};
         m_classReplacements = {};
         m_rulesets = {};
         m_sessionFlags = {};
         m_inputBlocked = false;
         m_playerExt = {};
         unloadAllModSwfs();
         activateEnabledMods();
         stageData = null;
         try
         {
            if(ModAPI.isReady())
            {
               stageData = ModAPI.getEngineAPI();
            }
         }
         catch(err:*)
         {
            stageData = null;
         }
         if(Boolean(stageData))
         {
            matchInit(stageData);
         }
         if(m_pendingSwfLoads == 0)
         {
            StageData.releaseTelemetry();
         }
         GameLog.write("[ModHost] live enable state applied");
      }
      
      public static function replaceClass(param1:Object, param2:Class) : void
      {
         var _loc3_:String = null;
         if(!param1 || !param2)
         {
            return;
         }
         _loc3_ = classKey(param1);
         if(!_loc3_)
         {
            return;
         }
         m_classReplacements[_loc3_] = param2;
         GameLog.write("[ModHost] replaceClass " + _loc3_ + " → " + getQualifiedClassName(param2));
      }
      
      public static function clearClassReplacement(param1:Object) : void
      {
         var _loc2_:String = classKey(param1);
         if(Boolean(_loc2_))
         {
            delete m_classReplacements[_loc2_];
         }
      }
      
      public static function resolveClass(param1:Class) : Class
      {
         var _loc2_:String = null;
         var _loc3_:Class = null;
         if(!param1)
         {
            return null;
         }
         _loc2_ = classKey(param1);
         _loc3_ = m_classReplacements[_loc2_] as Class;
         return _loc3_ || param1;
      }
      
      public static function create(param1:Class, param2:Array = null) : *
      {
         var _loc3_:Class = resolveClass(param1);
         var _loc4_:Array = param2 || [];
         if(!_loc3_)
         {
            return null;
         }
         switch(_loc4_.length)
         {
            case 0:
               return new _loc3_();
            case 1:
               return new _loc3_(_loc4_[0]);
            case 2:
               return new _loc3_(_loc4_[0],_loc4_[1]);
            case 3:
               return new _loc3_(_loc4_[0],_loc4_[1],_loc4_[2]);
            case 4:
               return new _loc3_(_loc4_[0],_loc4_[1],_loc4_[2],_loc4_[3]);
            case 5:
               return new _loc3_(_loc4_[0],_loc4_[1],_loc4_[2],_loc4_[3],_loc4_[4]);
            default:
               GameLog.write("[ModHost] create: max 5 args; use resolveClass + new");
               return new _loc3_(_loc4_[0],_loc4_[1],_loc4_[2],_loc4_[3],_loc4_[4]);
         }
      }
      
      public static function registerRuleset(param1:String, param2:Object) : void
      {
         var _loc3_:Object = null;
         var _loc4_:String = null;
         if(!param1 || !param2)
         {
            return;
         }
         _loc3_ = {};
         for(_loc4_ in param2)
         {
            _loc3_[_loc4_] = param2[_loc4_];
         }
         _loc3_.id = param1;
         m_rulesets[param1] = _loc3_;
      }
      
      public static function unregisterRuleset(param1:String) : void
      {
         if(Boolean(param1))
         {
            delete m_rulesets[param1];
         }
      }
      
      public static function getRuleset(param1:String) : Object
      {
         return Boolean(param1) ? m_rulesets[param1] as Object : null;
      }
      
      public static function listRulesets() : Array
      {
         var _loc1_:String = null;
         var _loc2_:Array = [];
         for(_loc1_ in m_rulesets)
         {
            _loc2_.push(m_rulesets[_loc1_]);
         }
         return _loc2_;
      }
      
      public static function setSessionFlag(param1:String, param2:*) : void
      {
         var _loc3_:* = undefined;
         if(!param1)
         {
            return;
         }
         _loc3_ = m_sessionFlags[param1];
         m_sessionFlags[param1] = param2;
         runHook(ModHooks.RULESET_CHANGE,{
            "id":param1,
            "value":param2,
            "previous":_loc3_,
            "cancel":false
         });
      }
      
      public static function getSessionFlag(param1:String, param2:* = undefined) : *
      {
         if(!param1 || !m_sessionFlags.hasOwnProperty(param1))
         {
            return param2;
         }
         return m_sessionFlags[param1];
      }
      
      public static function setInputBlocked(param1:Boolean) : void
      {
         m_inputBlocked = param1;
      }
      
      public static function isInputBlocked() : Boolean
      {
         return m_inputBlocked;
      }
      
      public static function ensureResourcesLoaded(param1:Array, param2:Function, param3:Function = null) : void
      {
         var res:Resource = null;
         var remaining:int = 0;
         var failed:Boolean = false;
         var onComplete:Function = null;
         var onError:Function = null;
         res = null;
         remaining = 0;
         failed = false;
         onComplete = null;
         onError = null;
         res = null;
         remaining = 0;
         failed = false;
         var ids:Array = param1;
         onComplete = param2;
         onError = param3;
         res = null;
         remaining = 0;
         failed = false;
         var need:Array = null;
         var i:int = 0;
         var id:String = null;
         var doneOne:Function = null;
         need = [];
         if(!ids)
         {
            if(onComplete != null)
            {
               onComplete();
            }
            return;
         }
         i = 0;
         while(i < ids.length)
         {
            id = String(ids[i]);
            if(Boolean(id))
            {
               if(!Boolean(ResourceManager.getResourceByID(id,true)))
               {
                  res = ResourceManager.getResourceByID(id,false) as Resource;
                  if(!res)
                  {
                     GameLog.write("[ModHost] ensureResourcesLoaded: unknown id " + id);
                  }
                  else
                  {
                     need.push(res);
                  }
               }
            }
            i++;
         }
         if(need.length == 0)
         {
            GameLog.write("[boot] ensureResourcesLoaded already loaded");
            if(onComplete != null)
            {
               onComplete();
            }
            return;
         }
         remaining = int(need.length);
         failed = false;
         GameLog.write("[boot] ensureResourcesLoaded start n=" + need.length + " ids=" + ids.join(","));
         doneOne = function(param1:Resource, param2:Boolean):void
         {
            if(param2 && Boolean(param1))
            {
               ResourceManager.registerLoadedResource(param1);
            }
            else
            {
               failed = true;
            }
            --remaining;
            GameLog.write("[boot] ensureResourcesLoaded one id=" + (Boolean(param1) ? param1.ID : "?") + " ok=" + param2 + " left=" + remaining);
            if(remaining <= 0)
            {
               GameLog.write("[boot] ensureResourcesLoaded done failed=" + failed);
               if(failed && onError != null)
               {
                  onError();
               }
               else if(onComplete != null)
               {
                  onComplete();
               }
            }
         };
         i = 0;
         while(i < need.length)
         {
            res = need[i] as Resource;
            try
            {
               res.load(function(param1:Resource):void
               {
                  doneOne(param1,true);
               },function(param1:Resource):void
               {
                  GameLog.write("[ModHost] ensureResourcesLoaded failed: " + (Boolean(param1) ? param1.ID : "?"));
                  doneOne(param1,false);
               });
            }
            catch(err:*)
            {
               GameLog.write("[ModHost] ensureResourcesLoaded exception: " + err);
               doneOne(res,false);
            }
            i++;
         }
      }
      
      public static function saveExtGet(param1:String, param2:* = null) : *
      {
         var key:String = param1;
         var defaultValue:* = param2;
         return applyPatch(ModPatches.SAVE_EXT_GET,[key,defaultValue],function(param1:String, param2:*):*
         {
            hydrateSaveExtFromDisk();
            if(!param1 || !m_saveExt.hasOwnProperty(param1))
            {
               return param2;
            }
            return m_saveExt[param1];
         });
      }
      
      public static function saveExtSet(param1:String, param2:*) : void
      {
         var key:String = param1;
         var value:* = param2;
         applyPatch(ModPatches.SAVE_EXT_SET,[key,value],function(param1:String, param2:*):void
         {
            var k:String = param1;
            var v:* = param2;
            var opts:Object = null;
            if(!k)
            {
               return;
            }
            m_saveExt[k] = v;
            try
            {
               opts = SaveData.getSavedVSOptions();
               if(Boolean(opts))
               {
                  if(!opts.modExt)
                  {
                     opts.modExt = {};
                  }
                  opts.modExt[k] = v;
                  SaveData.saveGame();
               }
            }
            catch(err:*)
            {
               GameLog.write("[ModHost] saveExtSet persist failed: " + err);
            }
         });
      }
      
      private static function hydrateSaveExtFromDisk() : void
      {
         var _loc1_:Object = null;
         var _loc2_:Object = null;
         var _loc3_:String = null;
         try
         {
            _loc1_ = SaveData.getSavedVSOptions();
            if(!_loc1_ || !_loc1_.modExt)
            {
               return;
            }
            _loc2_ = _loc1_.modExt as Object;
            for(_loc3_ in _loc2_)
            {
               m_saveExt[_loc3_] = _loc2_[_loc3_];
            }
         }
         catch(err:*)
         {
         }
      }
      
      public static function playerSettingsGetExt(param1:*, param2:String, param3:* = null) : *
      {
         var playerKey:* = param1;
         var key:String = param2;
         var defaultValue:* = param3;
         return applyPatch(ModPatches.PLAYER_SETTINGS_GET_EXT,[playerKey,key,defaultValue],function(param1:*, param2:String, param3:*):*
         {
            var _loc4_:* = undefined;
            var _loc5_:* = String(param1);
            _loc4_ = m_playerExt[_loc5_] as Object;
            if(!_loc4_ || !param2 || !_loc4_.hasOwnProperty(param2))
            {
               return param3;
            }
            return _loc4_[param2];
         });
      }
      
      public static function playerSettingsSetExt(param1:*, param2:String, param3:*) : void
      {
         var playerKey:* = param1;
         var key:String = param2;
         var value:* = param3;
         applyPatch(ModPatches.PLAYER_SETTINGS_SET_EXT,[playerKey,key,value],function(param1:*, param2:String, param3:*):void
         {
            var _loc4_:String = String(param1);
            var _loc5_:Object = m_playerExt[_loc4_] as Object;
            if(!_loc5_)
            {
               _loc5_ = {};
               m_playerExt[_loc4_] = _loc5_;
            }
            if(Boolean(param2))
            {
               _loc5_[param2] = param3;
            }
         });
      }
      
      public static function emitMenuGesture(param1:*, param2:Array, param3:Object = null) : Boolean
      {
         var _loc4_:String = null;
         var _loc5_:Object = {
            "cancel":false,
            "menu":param1,
            "chords":param2 || [],
            "consume":false
         };
         if(Boolean(param3))
         {
            for(_loc4_ in param3)
            {
               _loc5_[_loc4_] = param3[_loc4_];
            }
         }
         return runHook(ModHooks.MENU_GESTURE,_loc5_) || Boolean(_loc5_.consume);
      }
      
      public static function emitStageSelectGesture(param1:*, param2:*, param3:Array, param4:Object = null) : Boolean
      {
         var _loc5_:String = null;
         var _loc6_:Object = null;
         var _loc7_:* = null;
         if(Boolean(param4))
         {
            _loc7_ = param4.stageId;
         }
         if(_loc7_ == null)
         {
            _loc7_ = safeReadProp(param2,["StageID","stageID","m_stageID","id"]);
         }
         _loc6_ = {
            "cancel":false,
            "menu":param1,
            "hoverTarget":param2,
            "stageId":_loc7_,
            "chords":param3 || [],
            "consume":false
         };
         if(Boolean(param4))
         {
            for(_loc5_ in param4)
            {
               if(_loc5_ != "stageId" || _loc6_.stageId == null)
               {
                  _loc6_[_loc5_] = param4[_loc5_];
               }
            }
         }
         return runHook(ModHooks.STAGE_SELECT_GESTURE,_loc6_) || Boolean(_loc6_.consume);
      }
      
      public static function safeReadProp(param1:*, param2:Array) : *
      {
         var _loc3_:int = 0;
         var _loc4_:String = null;
         var _loc5_:* = undefined;
         if(!param1 || !param2)
         {
            return null;
         }
         _loc3_ = 0;
         while(_loc3_ < param2.length)
         {
            _loc4_ = String(param2[_loc3_]);
            try
            {
               _loc5_ = param1[_loc4_];
               if(_loc5_ != null)
               {
                  return _loc5_;
               }
            }
            catch(err:*)
            {
            }
            _loc3_++;
         }
         return null;
      }
      
      private static function classKey(param1:Object) : String
      {
         if(!param1)
         {
            return null;
         }
         if(param1 is String)
         {
            return String(param1);
         }
         try
         {
            return getQualifiedClassName(param1);
         }
         catch(err:*)
         {
         }
         return null;
      }
      
      public static function discoverAndLoadExpansions(param1:Function = null) : void
      {
         var onDone:Function = null;
         onDone = null;
         onDone = param1;
         try
         {
            ResourceManager.discoverDroppedExpansions();
            ResourceManager.loadPendingExpansions(function():void
            {
               try
               {
                  ResourceManager.appendExpansionCostumes();
               }
               catch(appendErr:*)
               {
               }
               if(onDone != null)
               {
                  onDone();
               }
            });
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] discoverAndLoadExpansions: " + err.message);
            if(onDone != null)
            {
               onDone();
            }
         }
      }
      
      public static function loadRealExpansionUiTemplates(param1:Function = null) : void
      {
         var onDone:Function = null;
         onDone = null;
         onDone = param1;
         try
         {
            ResourceManager.loadRealExpansionUiTemplates(onDone);
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] loadRealExpansionUiTemplates: " + err.message);
            if(onDone != null)
            {
               onDone();
            }
         }
      }
      
      public static function addExtraResource(param1:String, param2:String) : Boolean
      {
         var id:String = param1;
         var urlOverride:String = param2;
         var res:Resource = null;
         if(!id || !urlOverride)
         {
            return false;
         }
         try
         {
            if(Boolean(ResourceManager.getResourceByID(id,false)))
            {
               return false;
            }
            res = new Resource(id,"assets.swf","assets.swf","",Resource.EXTRA);
            res.SoftFail = true;
            res.UrlOverride = urlOverride;
            ResourceManager.addResource(res);
            return true;
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] addExtraResource: " + err.message);
         }
         return false;
      }
      
      public static function instantiateFromResource(param1:String, param2:String) : MovieClip
      {
         var debugUi:Boolean = false;
         var resourceId:String = null;
         var className:String = null;
         debugUi = false;
         resourceId = null;
         className = null;
         debugUi = false;
         resourceId = param1;
         className = param2;
         debugUi = false;
         var res:Resource = null;
         var loader:Loader = null;
         var domain:ApplicationDomain = null;
         var cls:Class = null;
         var obj:* = undefined;
         if(!resourceId || !className || resourceId == "undefined")
         {
            return null;
         }
         debugUi = Boolean(UI_INST_DEBUG) && (resourceId.indexOf("ui_tpl_") == 0 || className == "stock" || className == "icon" || className.indexOf("_stock") > 0 || className.indexOf("_icon") > 0);
         try
         {
            res = ResourceManager.getResourceByID(resourceId,true) as Resource;
            if(!res)
            {
               if(debugUi)
               {
                  GameLog.write("[ModHost] instantiateFromResource NO_RES " + resourceId + "." + className + " loaded=false");
               }
               return null;
            }
            loader = res.getLoader();
            if(!loader || !loader.contentLoaderInfo)
            {
               if(debugUi)
               {
                  GameLog.write("[ModHost] instantiateFromResource NO_LOADER " + resourceId + "." + className);
               }
               return null;
            }
            domain = loader.contentLoaderInfo.applicationDomain;
            cls = resolveUiTemplateClass(domain,res,className);
            if(!cls)
            {
               if(debugUi)
               {
                  GameLog.write("[ModHost] instantiateFromResource NO_DEF " + resourceId + "." + className);
               }
               return null;
            }
            obj = new cls();
            return wrapUiTemplateInstance(obj,resourceId,className,debugUi);
         }
         catch(err:Error)
         {
            if(debugUi)
            {
               GameLog.write("[ModHost] instantiateFromResource INST_ERR " + resourceId + "." + className + ": " + err.message);
            }
         }
         return null;
      }
      
      private static function wrapUiTemplateInstance(param1:*, param2:String, param3:String, param4:Boolean) : MovieClip
      {
         var _loc5_:MovieClip = null;
         var _loc6_:BitmapData = null;
         var _loc7_:Boolean = false;
         if(param1 == null || param1 == undefined)
         {
            if(param4)
            {
               GameLog.write("[ModHost] instantiateFromResource INST_NULL " + param2 + "." + param3);
            }
            return null;
         }
         if(param1 is MovieClip)
         {
            return param1 as MovieClip;
         }
         if(param1 is DisplayObject)
         {
            _loc5_ = new MovieClip();
            _loc5_.addChild(param1 as DisplayObject);
            return _loc5_;
         }
         if(param1 is BitmapData)
         {
            _loc6_ = param1 as BitmapData;
            _loc7_ = param3 == "stock" || param3.indexOf("_stock") >= 0 || param3.indexOf("Stock") >= 0;
            if(_loc7_)
            {
               return ResourceManager.wrapStockBitmapData(_loc6_);
            }
            _loc5_ = new MovieClip();
            _loc5_.addChild(new Bitmap(_loc6_,"auto",true));
            return _loc5_;
         }
         if(param4)
         {
            GameLog.write("[ModHost] instantiateFromResource BAD_TYPE " + param2 + "." + param3 + " qn=" + getQualifiedClassName(param1));
         }
         return null;
      }
      
      private static function resolveUiTemplateClass(param1:ApplicationDomain, param2:Resource, param3:String) : Class
      {
         if(Boolean(param1) && param1.hasDefinition(param3))
         {
            return param1.getDefinition(param3) as Class;
         }
         return null;
      }
      
      public static function traceResourceDefinitions(param1:String, param2:String = "") : void
      {
         var resourceId:String = param1;
         var context:String = param2;
         var res:Resource = null;
         var domain:ApplicationDomain = null;
         var probes:Array = null;
         var i:int = 0;
         var name:String = null;
         var hits:Array = null;
         if(!resourceId || resourceId == "undefined")
         {
            return;
         }
         try
         {
            res = ResourceManager.getResourceByID(resourceId,true) as Resource;
            if(!res || !res.MC || !res.MC.loaderInfo)
            {
               GameLog.write("[ModHost] ui defs " + resourceId + " not loaded" + (Boolean(context) ? " ctx=" + context : ""));
               return;
            }
            domain = res.MC.loaderInfo.applicationDomain;
            probes = ["stock","Stock","select","charselect","icon","classic","classic_trophy","cssp","event","allstar","congrats","allstar_congrats","buu_stock","hero_stock","buu_select","hero_select","buu_icon","hero_icon"];
            hits = [];
            i = 0;
            while(i < probes.length)
            {
               name = String(probes[i]);
               if(Boolean(domain) && domain.hasDefinition(name))
               {
                  hits.push(name);
               }
               i++;
            }
            GameLog.write("[ModHost] ui defs " + resourceId + (Boolean(context) ? " (" + context + ")" : "") + ": [" + hits.join(", ") + "]");
         }
         catch(err:*)
         {
            GameLog.write("[ModHost] traceResourceDefinitions: " + err);
         }
      }
      
      public static function registerMappedCharacter(param1:String, param2:Object) : Boolean
      {
         var id:String = param1;
         var entry:Object = param2;
         var res:Resource = null;
         var file:String = null;
         var filePub:String = null;
         var guid:String = null;
         var cssCache:Object = null;
         if(!id || !entry)
         {
            return false;
         }
         try
         {
            if(Boolean(ResourceManager.getResourceByID(id)))
            {
               return false;
            }
            file = String(entry["file"] || "");
            if(!file)
            {
               return false;
            }
            filePub = String(entry["file_pub"] || file);
            guid = entry["guid"] != null ? String(entry["guid"]) : "";
            cssCache = ResourceManager.readExpansionCssCache(file);
            Stats.writeStats({"cData":{
               "statsName":id,
               "displayName":(Boolean(cssCache) && Boolean(cssCache.displayName) ? cssCache.displayName : (entry["name"] != null ? entry["name"] : id)),
               "seriesIcon":(Boolean(cssCache) && Boolean(cssCache.seriesIcon) ? cssCache.seriesIcon : entry["seriesIcon"] || null)
            }});
            res = new Resource(id,file,filePub,guid,Resource.CHARACTER);
            res.SoftFail = true;
            ResourceManager.addResource(res);
            if(Boolean(ResourceManager.manifestJSONData))
            {
               if(!ResourceManager.manifestJSONData.character)
               {
                  ResourceManager.manifestJSONData.character = {};
               }
               ResourceManager.manifestJSONData.character[id] = entry;
            }
            GameLog.write("[ModHost] registerMappedCharacter: " + id + " -> " + file);
            return true;
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] registerMappedCharacter: " + err.message);
         }
         return false;
      }
      
      public static function fitCharacterSelectLayout(param1:Object) : void
      {
         var mappings:Object = param1;
         var screen:Object = null;
         var rows:Array = null;
         var r:int = 0;
         var maxCols:int = 0;
         var rowLen:int = 0;
         var cell:Number = Number(NaN);
         var bounds:Object = null;
         var pitchW:Number = Number(NaN);
         var pitchH:Number = Number(NaN);
         if(!mappings || !mappings.character_select_screen)
         {
            return;
         }
         try
         {
            screen = mappings.character_select_screen;
            rows = screen.rows as Array;
            if(!rows || rows.length <= 0)
            {
               return;
            }
            maxCols = 1;
            r = 0;
            while(r < rows.length)
            {
               rowLen = rows[r] is Array ? int((rows[r] as Array).length) : 0;
               if(rowLen > maxCols)
               {
                  maxCols = rowLen;
               }
               r++;
            }
            bounds = screen.chip_bounds;
            pitchW = Boolean(bounds) && Boolean(bounds.width) ? Number(bounds.width) : 610;
            pitchH = 200;
            cell = Math.min(Math.floor(pitchW / maxCols),Math.floor(pitchH / rows.length));
            if(cell > 42)
            {
               cell = 42;
            }
            if(cell < 8)
            {
               cell = 8;
            }
            if(!screen.icon_size)
            {
               screen.icon_size = {};
            }
            screen.icon_size.width = cell;
            screen.icon_size.height = cell;
            if(!screen.position)
            {
               screen.position = {};
            }
            if(Boolean(bounds))
            {
               screen.position.x = Number(bounds.x) + (pitchW - maxCols * cell) / 2;
            }
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] fitCharacterSelectLayout: " + err.message);
         }
      }
      
      public static function applyClassicJsonPacks() : void
      {
         try
         {
            ResourceManager.applyClassicJsonPacks();
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] applyClassicJsonPacks: " + err.message);
         }
      }
      
      public static function registerExpansionCostumes(param1:String, param2:Array) : void
      {
         var statsName:String = param1;
         var costumes:Array = param2;
         try
         {
            ResourceManager.registerExpansionCostumeData(statsName,costumes);
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] registerExpansionCostumes: " + err.message);
         }
      }
      
      public static function appendExpansionCostumes() : void
      {
         try
         {
            ResourceManager.appendExpansionCostumes();
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] appendExpansionCostumes: " + err.message);
         }
      }
      
      public static function get stage() : *
      {
         return Boolean(Main.Root) ? Main.Root.stage : null;
      }
      
      public static function get root() : *
      {
         return Main.Root;
      }
      
      public static function notify(param1:String) : void
      {
         var text:String = null;
         text = null;
         text = param1;
         try
         {
            MultiplayerManager.notify(text);
         }
         catch(err:*)
         {
            GameLog.write("[ModHost] notify: " + text);
         }
      }
      
      public static function addKeyListener(param1:Function) : void
      {
         if(param1 == null)
         {
            return;
         }
         m_keyListeners.push(param1);
      }
      
      public static function removeKeyListener(param1:Function) : void
      {
         var _loc2_:int = int(m_keyListeners.indexOf(param1));
         if(_loc2_ >= 0)
         {
            m_keyListeners.splice(_loc2_,1);
         }
      }
      
      public static function emit(param1:String, param2:Object = null) : void
      {
         m_eventBridge.dispatchEvent(new ModHostEvent(param1,param2));
         runHook(ModHooks.CUSTOM_EVENT,{
            "topic":param1,
            "data":param2,
            "cancel":false
         });
      }
      
      public static function addEventListener(param1:String, param2:Function, param3:Boolean = false, param4:int = 0, param5:Boolean = false) : void
      {
         m_eventBridge.addEventListener(param1,param2,param3,param4,param5);
      }
      
      public static function removeEventListener(param1:String, param2:Function, param3:Boolean = false) : void
      {
         m_eventBridge.removeEventListener(param1,param2,param3);
      }
      
      public static function dispatchKey(param1:*) : Boolean
      {
         var e:* = param1;
         var i:int = 0;
         var fn:Function = null;
         var handled:Boolean = false;
         var hookCtx:Object = {
            "cancel":false,
            "event":e
         };
         if(m_inputBlocked)
         {
            handled = true;
         }
         if(runHook(ModHooks.KEY_EVENT,hookCtx))
         {
            return true;
         }
         i = 0;
         while(i < m_keyListeners.length)
         {
            fn = m_keyListeners[i] as Function;
            try
            {
               if(Boolean(fn(e)))
               {
                  handled = true;
               }
            }
            catch(err:Error)
            {
               GameLog.write("[ModHost] key listener error: " + err.message);
            }
            i++;
         }
         return handled;
      }
      
      public static function addHook(param1:String, param2:Function) : void
      {
         if(!m_hookListeners[param1])
         {
            m_hookListeners[param1] = [];
         }
         (m_hookListeners[param1] as Array).push(param2);
      }
      
      public static function removeHook(param1:String, param2:Function) : void
      {
         var _loc3_:int = 0;
         var _loc4_:Array = m_hookListeners[param1] as Array;
         if(!_loc4_)
         {
            return;
         }
         _loc3_ = _loc4_.indexOf(param2);
         if(_loc3_ >= 0)
         {
            _loc4_.splice(_loc3_,1);
         }
      }
      
      public static function hasHook(param1:String) : Boolean
      {
         return HookGate.listening(m_hookListeners[param1] as Array);
      }
      
      public static function runHook(param1:String, param2:Object) : Boolean
      {
         var i:int = 0;
         var hookId:String = null;
         i = 0;
         hookId = null;
         i = 0;
         hookId = param1;
         var ctx:Object = param2;
         i = 0;
         var fn:Function = null;
         var list:Array = m_hookListeners[hookId] as Array;
         if(!ctx)
         {
            ctx = {};
         }
         if(!list)
         {
            return Boolean(ctx.cancel);
         }
         i = 0;
         while(i < list.length)
         {
            fn = list[i] as Function;
            try
            {
               fn(ctx);
            }
            catch(err:*)
            {
               GameLog.write("[ModHost] hook " + hookId + " #" + i + " error: " + err + (err is Error ? formatFlashError(err as Error) : ""));
            }
            if(Boolean(ctx.cancel))
            {
               return true;
            }
            i++;
         }
         return Boolean(ctx.cancel);
      }
      
      private static function formatFlashError(param1:Error) : String
      {
         var _loc2_:int = 0;
         var _loc3_:String = null;
         var _loc4_:String = null;
         var _loc5_:Object = null;
         if(!param1)
         {
            return "";
         }
         _loc2_ = int(param1.errorID);
         if(_loc2_ <= 0)
         {
            _loc2_ = int(extractErrorId(param1.message));
         }
         if(_loc2_ <= 0)
         {
            return Boolean(param1.name) && param1.name != "Error" ? " [" + param1.name + "]" : "";
         }
         _loc5_ = {
            1009:{
               "t":"Null object reference",
               "h":"Accessed a property/method on null"
            },
            1010:{
               "t":"Undefined has no properties",
               "h":"Accessed a property on undefined"
            },
            1056:{
               "t":"Cannot create property",
               "h":"Wrote a dynamic property on a sealed object"
            },
            1065:{
               "t":"Variable is not defined",
               "h":"getDefinitionByName path wrong, class not linked, or missing timeline instance name"
            },
            1069:{
               "t":"Property not found",
               "h":"Property missing on sealed class and no default"
            },
            1070:{
               "t":"Method not found",
               "h":"Method missing on that type"
            },
            2007:{
               "t":"Parameter must be non-null",
               "h":""
            },
            2025:{
               "t":"Not a child of the caller",
               "h":"removeChild/addChild on the wrong parent"
            }
         };
         if(_loc5_[_loc2_])
         {
            _loc3_ = String(_loc5_[_loc2_].t || "");
            _loc4_ = String(_loc5_[_loc2_].h || "");
            if(_loc4_.length > 0)
            {
               return " — #" + _loc2_ + " " + _loc3_ + ". " + _loc4_;
            }
            return " — #" + _loc2_ + " " + _loc3_;
         }
         return " — Flash/AS3 error #" + _loc2_;
      }
      
      private static function extractErrorId(param1:String) : int
      {
         var _loc2_:Array = null;
         if(!param1)
         {
            return 0;
         }
         _loc2_ = param1.match(/Error\s*#(\d+)/i);
         if(Boolean(_loc2_) && _loc2_.length > 1)
         {
            return int(_loc2_[1]);
         }
         _loc2_ = param1.match(/#(\d{3,4})\b/);
         if(Boolean(_loc2_) && _loc2_.length > 1)
         {
            return int(_loc2_[1]);
         }
         return 0;
      }
      
      public static function patch(param1:String, param2:Function) : void
      {
         m_patches[param1] = param2;
      }
      
      public static function unpatch(param1:String) : void
      {
         delete m_patches[param1];
      }
      
      public static function hasPatch(param1:String) : Boolean
      {
         return m_patches[param1] != null;
      }
      
      public static function applyPatch(param1:String, param2:Array, param3:Function) : *
      {
         var op:String = null;
         var stack:String = null;
         var id:String = null;
         var args:Array = null;
         op = null;
         stack = null;
         id = null;
         args = null;
         op = null;
         stack = null;
         id = param1;
         args = param2;
         var defaultFn:Function = param3;
         var fn:Function = m_patches[id] as Function;
         if(fn != null)
         {
            try
            {
               return fn.apply(null,args);
            }
            catch(err:Error)
            {
               op = args != null && args.length > 0 ? String(args[0]) : "";
               stack = "";
               try
               {
                  stack = err.getStackTrace();
               }
               catch(stackErr:*)
               {
               }
               GameLog.write("[ModHost] patch " + id + (op ? " " + op : "") + " error: " + err.message + formatFlashError(err) + (stack ? " " + stack : ""));
            }
         }
         if(defaultFn != null)
         {
            return defaultFn.apply(null,args);
         }
         return null;
      }
      
      public static function door(param1:String, param2:Array = null, param3:* = undefined) : *
      {
         var defaultVal:* = undefined;
         defaultVal = undefined;
         var id:String = param1;
         var args:Array = param2;
         defaultVal = param3;
         if(m_patches[id] == null)
         {
            return defaultVal;
         }
         var a:Array = args || [];
         return applyPatch(id,a,function(... rest):*
         {
            return defaultVal;
         });
      }
      
      public static function isReady() : Boolean
      {
         return ModAPI.isReady();
      }
      
      public static function setGameLogPath(param1:String) : void
      {
         m_gameLogAbs = param1 ? param1 : "";
         GameLog.setPath(m_gameLogAbs);
      }
      
      public static function appendGameLog(param1:String) : void
      {
         GameLog.write(param1 == null ? "" : String(param1));
      }
      
      public static function print(param1:String) : void
      {
         ModAPI.print(param1);
      }
      
      public static function getEngineAPI() : StageData
      {
         return ModAPI.getEngineAPI();
      }
      
      public static function getSSF2API() : Class
      {
         return ModAPI.getSSF2API();
      }
      
      public static function getModAPI() : Class
      {
         return ModAPI;
      }
      
      public static function playMusicWithFadeOut(param1:String, param2:Number, param3:Number = 2000) : void
      {
         applyPatch(ModPatches.PLAY_MUSIC_WITH_FADE_OUT,[param1,param2,param3],ModAPI.playMusicWithFadeOut);
      }
      
      public static function startImmediateFadeOut(param1:Number = 2000) : void
      {
         applyPatch(ModPatches.START_IMMEDIATE_FADE_OUT,[param1],ModAPI.startImmediateFadeOut);
      }
      
      public static function isMusicFadingOut() : Boolean
      {
         return Boolean(applyPatch(ModPatches.IS_MUSIC_FADING_OUT,[],ModAPI.isMusicFadingOut));
      }
      
      public static function playPitchShiftedEffect(param1:String, param2:Number = 1, param3:Number = 1) : Boolean
      {
         return Boolean(applyPatch(ModPatches.PLAY_PITCH_SHIFTED_EFFECT,[param1,param2,param3],ModAPI.playPitchShiftedEffect));
      }
      
      public static function updatePitchShift(param1:Number) : void
      {
         applyPatch(ModPatches.UPDATE_PITCH_SHIFT,[param1],ModAPI.updatePitchShift);
      }
      
      public static function updatePitchShiftVolume(param1:Number) : void
      {
         applyPatch(ModPatches.UPDATE_PITCH_SHIFT_VOLUME,[param1],ModAPI.updatePitchShiftVolume);
      }
      
      public static function stopPitchShiftedEffect() : void
      {
         applyPatch(ModPatches.STOP_PITCH_SHIFTED_EFFECT,[],ModAPI.stopPitchShiftedEffect);
      }
      
      public static function isPitchShiftedEffectPlaying() : Boolean
      {
         return Boolean(applyPatch(ModPatches.IS_PITCH_SHIFTED_EFFECT_PLAYING,[],ModAPI.isPitchShiftedEffectPlaying));
      }
      
      public static function rumbleController(param1:*, param2:Number, param3:Number, param4:int) : void
      {
         applyPatch(ModPatches.RUMBLE_CONTROLLER,[param1,param2,param3,param4],ModAPI.rumbleController);
      }
      
      public static function stopRumble(param1:*) : void
      {
         applyPatch(ModPatches.STOP_RUMBLE,[param1],ModAPI.stopRumble);
      }
      
      public static function supportsRumble(param1:*) : Boolean
      {
         return Boolean(applyPatch(ModPatches.SUPPORTS_RUMBLE,[param1],ModAPI.supportsRumble));
      }
      
      public static function isRumbleEnabled() : Boolean
      {
         return Boolean(applyPatch(ModPatches.IS_RUMBLE_ENABLED,[],ModAPI.isRumbleEnabled));
      }
      
      public static function stopTime(param1:*, param2:int = -1, param3:int = 0, param4:int = 2147483646, param5:Object = null) : void
      {
         applyPatch(ModPatches.STOP_TIME,[param1,param2,param3,param4,param5],ModAPI.stopTime);
      }
      
      public static function resumeTime(param1:*) : void
      {
         applyPatch(ModPatches.RESUME_TIME,[param1],ModAPI.resumeTime);
      }
      
      public static function applyTimeFreeze(param1:*, param2:int = -1) : void
      {
         applyPatch(ModPatches.APPLY_TIME_FREEZE,[param1,param2],ModAPI.applyTimeFreeze);
      }
      
      public static function removeTimeFreeze(param1:*) : void
      {
         applyPatch(ModPatches.REMOVE_TIME_FREEZE,[param1],ModAPI.removeTimeFreeze);
      }
      
      public static function triggerMenuRumble(param1:int) : void
      {
         applyPatch(ModPatches.TRIGGER_MENU_RUMBLE,[param1],ModAPI.triggerMenuRumble);
      }
      
      public static function stopMenuRumble() : void
      {
         applyPatch(ModPatches.STOP_MENU_RUMBLE,[],ModAPI.stopMenuRumble);
      }
      
      private static function ensureModsOption() : void
      {
         if(Boolean(SaveData.RawLocalObject) && Boolean(SaveData.RawLocalObject.game) && Boolean(SaveData.RawLocalObject.game.options))
         {
            if(SaveData.RawLocalObject.game.options.modEnabled == null)
            {
               SaveData.RawLocalObject.game.options.modEnabled = {};
            }
         }
      }
      
      private static function discoverMods() : void
      {
         m_mods = {};
         m_modOrder = [];
         discoverModsIn("data/ssf2mm",true);
         discoverModsIn("expansions/mods",false);
         m_modOrder.sort(Array.CASEINSENSITIVE);
      }
      
      private static function discoverModsIn(param1:String, param2:Boolean) : void
      {
         var relativeBase:String = null;
         relativeBase = null;
         relativeBase = param1;
         var essential:Boolean = param2;
         var dir:File = null;
         var list:Array = null;
         var i:int = 0;
         var child:File = null;
         var info:ModInfo = null;
         try
         {
            dir = File.applicationDirectory.resolvePath(relativeBase);
            if(!dir.exists || !dir.isDirectory)
            {
               if(!essential)
               {
                  GameLog.write("[ModHost] " + relativeBase + " missing");
               }
               return;
            }
            list = dir.getDirectoryListing();
            i = 0;
            while(i < list.length)
            {
               child = list[i] as File;
               if(!(!child || !child.isDirectory))
               {
                  if(child.name.charAt(0) != "_" && child.name.charAt(0) != ".")
                  {
                     if(child.resolvePath("mod.json").exists)
                     {
                        info = ModInfo.fromFolder(child,relativeBase,essential);
                        if(Boolean(info))
                        {
                           if(Boolean(m_mods[info.id]))
                           {
                              GameLog.write("[ModHost] duplicate mod id " + info.id + " in " + relativeBase + " — keeping first");
                           }
                           else
                           {
                              m_mods[info.id] = info;
                              m_modOrder.push(info.id);
                              GameLog.write("[ModHost] found " + (essential ? "essential" : "mod") + " " + info.id + " swf=" + (info.swfPath != null));
                           }
                        }
                     }
                  }
               }
               i++;
            }
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] discoverModsIn " + relativeBase + ": " + err.message);
         }
      }
      
      private static function activateEnabledMods() : void
      {
         var jobs:Array = null;
         jobs = null;
         jobs = null;
         jobs = null;
         jobs = null;
         jobs = null;
         jobs = null;
         var i:int = 0;
         var id:String = null;
         var info:ModInfo = null;
         var bootAfter:Boolean = false;
         jobs = null;
         var needLoad:Array = null;
         jobs = [];
         needLoad = [];
         i = 0;
         while(i < m_modOrder.length)
         {
            id = String(m_modOrder[i]);
            info = m_mods[id] as ModInfo;
            if(!info || !isModEnabled(id))
            {
               GameLog.write("[ModHost] skip disabled " + id);
            }
            else if(!info.swfPath)
            {
               GameLog.write("[ModHost] WARNING: mod " + id + " has no mod.swf — skipped");
            }
            else
            {
               bootAfter = info.lifetime == "boot" || info.lifetime == "both";
               appendResourceIds(registerModResources(info),needLoad);
               jobs.push({
                  "info":info,
                  "bootAfter":bootAfter
               });
            }
            i++;
         }
         if(needLoad.length > 0)
         {
            GameLog.write("[ModHost] loading pack resources: " + needLoad.join(", "));
            ResourceManager.queueResources(needLoad);
            ResourceManager.load({
               "oncomplete":function():void
               {
                  activateModJobs(jobs);
               },
               "onerror":function():void
               {
                  GameLog.write("[ModHost] pack resource load error — continuing SWF activate");
                  activateModJobs(jobs);
               }
            });
         }
         else
         {
            activateModJobs(jobs);
         }
      }
      
      private static function activateModJobs(param1:Array) : void
      {
         var _loc2_:int = 0;
         var _loc3_:Object = null;
         var _loc4_:ModInfo = null;
         var _loc5_:Boolean = false;
         m_activateJobsStarted = true;
         if(!param1)
         {
            maybeFireBootModsReady();
            return;
         }
         _loc2_ = 0;
         while(_loc2_ < param1.length)
         {
            _loc3_ = param1[_loc2_];
            _loc4_ = _loc3_.info as ModInfo;
            _loc5_ = Boolean(_loc3_.bootAfter);
            if(Boolean(_loc4_))
            {
               if(Boolean(_loc4_.runtimeClass))
               {
                  if(_loc5_)
                  {
                     bootInstance(_loc4_);
                  }
               }
               else
               {
                  loadModSwf(_loc4_,_loc5_);
               }
            }
            _loc2_++;
         }
         maybeFireBootModsReady();
      }
      
      public static function registerModResources(param1:ModInfo) : Array
      {
         var _loc2_:int = 0;
         var _loc3_:Object = null;
         var _loc4_:Array = null;
         var _loc5_:String = null;
         _loc4_ = [];
         if(!param1 || !param1.resources)
         {
            return _loc4_;
         }
         _loc2_ = 0;
         while(_loc2_ < param1.resources.length)
         {
            _loc3_ = param1.resources[_loc2_];
            _loc5_ = registerPackResource(param1,_loc3_);
            if(Boolean(_loc5_))
            {
               _loc4_.push(_loc5_);
            }
            _loc2_++;
         }
         return _loc4_;
      }
      
      public static function registerPackResource(param1:ModInfo, param2:Object) : String
      {
         var _loc3_:Resource = null;
         var _loc4_:Resource = null;
         var _loc5_:String = null;
         var _loc6_:File = null;
         var _loc7_:File = null;
         var _loc8_:int = 0;
         var _loc9_:String = null;
         var _loc10_:String = null;
         if(!param1 || !param2 || !param2.id || !param2.file)
         {
            return null;
         }
         _loc3_ = ResourceManager.getResourceByID(String(param2.id),false);
         if(Boolean(_loc3_))
         {
            if(_loc3_.Loaded)
            {
               return null;
            }
            return String(param2.id);
         }
         _loc5_ = String(param2.file);
         _loc6_ = new File(param1.folderPath);
         _loc7_ = _loc6_.resolvePath(_loc5_);
         if(!_loc7_.exists && _loc5_.length >= 4 && _loc5_.substr(_loc5_.length - 4).toLowerCase() == ".ssf")
         {
            _loc5_ = _loc5_.substr(0,_loc5_.length - 4) + ".swf";
            _loc7_ = _loc6_.resolvePath(_loc5_);
         }
         if(!_loc7_.exists)
         {
            GameLog.write("[ModHost] pack resource missing " + param1.id + ": " + _loc7_.nativePath);
            if(param2.softFail === false)
            {
               return null;
            }
         }
         _loc8_ = int(resourceTypeFromName(Boolean(param2.type) ? String(param2.type) : "menu"));
         _loc9_ = Boolean(param2.guid) ? String(param2.guid) : "";
         _loc4_ = new Resource(String(param2.id),_loc5_,_loc5_,_loc9_,_loc8_);
         _loc4_.SoftFail = param2.softFail !== false;
         _loc10_ = (Boolean(param1.relativeBase) ? param1.relativeBase : "expansions/mods") + "/" + param1.folderName + "/" + _loc5_;
         _loc4_.UrlOverride = _loc10_;
         ResourceManager.addResource(_loc4_);
         GameLog.write("[ModHost] registered pack resource " + _loc4_.ID + " → " + _loc10_);
         return String(param2.id);
      }
      
      public static function addAndLoadPackResource(param1:String, param2:Object, param3:Function = null) : void
      {
         var onDone:Function = null;
         onDone = null;
         var modId:String = param1;
         var spec:Object = param2;
         onDone = param3;
         var info:ModInfo = null;
         var rid:String = null;
         info = m_mods[modId] as ModInfo;
         if(!info)
         {
            GameLog.write("[ModHost] addAndLoadPackResource: unknown mod " + modId);
            if(onDone != null)
            {
               onDone(false);
            }
            return;
         }
         rid = registerPackResource(info,spec);
         if(!rid)
         {
            if(onDone != null)
            {
               onDone(true);
            }
            return;
         }
         ResourceManager.queueResources([rid]);
         ResourceManager.load({
            "oncomplete":function():void
            {
               if(onDone != null)
               {
                  onDone(true);
               }
            },
            "onerror":function():void
            {
               if(onDone != null)
               {
                  onDone(false);
               }
            }
         });
      }
      
      private static function appendResourceIds(param1:Array, param2:Array) : void
      {
         var _loc3_:int = 0;
         var _loc4_:String = null;
         if(!param1 || !param2)
         {
            return;
         }
         _loc3_ = 0;
         while(_loc3_ < param1.length)
         {
            _loc4_ = String(param1[_loc3_]);
            if(Boolean(_loc4_) && param2.indexOf(_loc4_) < 0)
            {
               param2.push(_loc4_);
            }
            _loc3_++;
         }
      }
      
      private static function resourceTypeFromName(param1:String) : int
      {
         switch(String(param1).toLowerCase())
         {
            case "misc":
               return Resource.MISC;
            case "extra":
               return Resource.EXTRA;
            case "audio":
               return Resource.AUDIO;
            case "mode":
               return Resource.MODE;
            case "character":
               return Resource.CHARACTER;
            case "stage":
               return Resource.STAGE;
            case "menu":
         }
         return Resource.MENU;
      }
      
      private static function bootInstance(param1:ModInfo) : void
      {
         var info:ModInfo = null;
         info = null;
         info = param1;
         var inst:* = undefined;
         if(!info || !info.runtimeClass)
         {
            return;
         }
         try
         {
            inst = new info.runtimeClass();
            m_bootInstances[info.id] = inst;
            tryCall(inst,"onBoot",[ModHost]);
            tryCall(inst,"onBootStart",[ModHost]);
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] bootInstance " + info.id + ": " + err.message);
         }
      }
      
      private static function createInstanceFromInfo(param1:ModInfo) : *
      {
         var info:ModInfo = null;
         info = null;
         info = param1;
         var cls:Class = null;
         if(!info)
         {
            return null;
         }
         if(Boolean(info.runtimeClass))
         {
            try
            {
               return new info.runtimeClass();
            }
            catch(err:Error)
            {
               GameLog.write("[ModHost] runtimeClass new " + info.id + ": " + err.message);
            }
         }
         if(Boolean(info.entryClass))
         {
            cls = getDefinition(info.entryClass) as Class;
            if(Boolean(cls))
            {
               try
               {
                  return new cls();
               }
               catch(err2:Error)
               {
                  GameLog.write("[ModHost] entryClass new " + info.id + ": " + err2.message);
               }
            }
         }
         return null;
      }
      
      private static function unloadAllModSwfs() : void
      {
         var loader:Loader = null;
         loader = null;
         loader = null;
         loader = null;
         loader = null;
         loader = null;
         loader = null;
         var id:String = null;
         loader = null;
         for(id in m_loaders)
         {
            loader = m_loaders[id] as Loader;
            if(Boolean(loader))
            {
               try
               {
                  loader.unloadAndStop(true);
               }
               catch(err:*)
               {
                  try
                  {
                     loader.unload();
                  }
                  catch(err2:*)
                  {
                  }
               }
            }
         }
         m_loaders = {};
         m_domains = [];
         for(id in m_mods)
         {
            if(Boolean(m_mods[id]))
            {
               (m_mods[id] as ModInfo).runtimeClass = null;
            }
         }
      }
      
      private static function finishOneModSwf() : void
      {
         if(m_pendingSwfLoads > 0)
         {
            --m_pendingSwfLoads;
         }
         if(m_pendingSwfLoads == 0)
         {
            StageData.releaseTelemetry();
         }
      }
      
      private static function loadModSwf(param1:ModInfo, param2:Boolean) : void
      {
         var info:ModInfo = null;
         var bootAfter:Boolean = false;
         info = null;
         bootAfter = false;
         info = param1;
         bootAfter = param2;
         var loader:Loader = null;
         var ctx:LoaderContext = null;
         var file:File = null;
         var stream:FileStream = null;
         var bytes:ByteArray = null;
         var parentDomain:ApplicationDomain = null;
         loader = new Loader();
         parentDomain = ApplicationDomain.currentDomain;
         ctx = new LoaderContext(false,new ApplicationDomain(parentDomain));
         try
         {
            ctx.allowCodeImport = true;
         }
         catch(allowErr:*)
         {
         }
         GameLog.write("[ModHost] loading " + info.id + " MenuDefined=" + parentDomain.hasDefinition("com.mcleodgaming.ssf2.menus.Menu") + " via loadBytes");
         ++m_pendingSwfLoads;
         m_loaders[info.id] = loader;
         loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(param1:Event):void
         {
            var e:Event = param1;
            var entry:* = undefined;
            var li:LoaderInfo = e.target as LoaderInfo;
            finishOneModSwf();
            try
            {
               if(Boolean(li.applicationDomain) && m_domains.indexOf(li.applicationDomain) < 0)
               {
                  m_domains.push(li.applicationDomain);
               }
               if(Boolean(info.entryClass) && li.applicationDomain.hasDefinition(info.entryClass))
               {
                  entry = li.applicationDomain.getDefinition(info.entryClass);
                  info.runtimeClass = entry as Class;
                  if(bootAfter)
                  {
                     bootInstance(info);
                  }
               }
               else if(Boolean(li.content) && "onBoot" in li.content)
               {
                  if(bootAfter)
                  {
                     m_bootInstances[info.id] = li.content;
                     tryCall(li.content,"onBoot",[ModHost]);
                  }
               }
               else
               {
                  GameLog.write("[ModHost] SWF loaded but no entryClass " + info.entryClass + " in " + info.id);
               }
               GameLog.write("[ModHost] SWF ready " + info.id);
            }
            catch(err:Error)
            {
               GameLog.write("[ModHost] SWF init " + info.id + ": " + err.message);
            }
            maybeFireBootModsReady();
         });
         loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(param1:IOErrorEvent):void
         {
            finishOneModSwf();
            GameLog.write("[ModHost] SWF load failed " + info.id + ": " + param1.text);
            maybeFireBootModsReady();
         });
         loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR,function(param1:SecurityErrorEvent):void
         {
            finishOneModSwf();
            GameLog.write("[ModHost] SWF security " + info.id + ": " + param1.text);
            maybeFireBootModsReady();
         });
         try
         {
            file = new File(info.swfPath);
            if(!file.exists)
            {
               finishOneModSwf();
               GameLog.write("[ModHost] missing mod.swf " + info.swfPath);
               maybeFireBootModsReady();
               return;
            }
            stream = new FileStream();
            stream.open(file,FileMode.READ);
            bytes = new ByteArray();
            stream.readBytes(bytes);
            stream.close();
            if(swfRefused(bytes))
            {
               finishOneModSwf();
               GameLog.write("[ModHost] refused " + info.id + " unsafe swf");
               maybeFireBootModsReady();
               return;
            }
            loader.loadBytes(bytes,ctx);
         }
         catch(err:Error)
         {
            finishOneModSwf();
            GameLog.write("[ModHost] loadModSwf " + info.id + ": " + err.message + "\n" + err.getStackTrace());
            maybeFireBootModsReady();
         }
      }
      
      private static function tryCall(param1:*, param2:String, param3:Array) : void
      {
         var method:String = null;
         method = null;
         var inst:* = param1;
         method = param2;
         var args:Array = param3;
         var fn:Function = null;
         var listed:Boolean = false;
         if(!inst)
         {
            return;
         }
         try
         {
            listed = method in inst;
         }
         catch(inErr:*)
         {
            listed = false;
         }
         try
         {
            fn = inst[method] as Function;
         }
         catch(lookupErr:*)
         {
            fn = null;
         }
         if(fn == null)
         {
            if(method == "onBoot")
            {
               GameLog.write("[ModHost] onBoot missing");
            }
            return;
         }
         if(!listed && method == "onBoot")
         {
            GameLog.write("[ModHost] onBoot via direct call");
         }
         try
         {
            if(Boolean(args))
            {
               fn.apply(inst,args);
            }
            else
            {
               fn.apply(inst);
            }
         }
         catch(err:Error)
         {
            GameLog.write("[ModHost] " + method + " error: " + err.message);
         }
      }
   }
}
