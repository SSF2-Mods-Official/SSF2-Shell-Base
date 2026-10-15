package com.mcleodgaming.ssf2.modes
{
   import ssf2mm.shared.EngineRefs;
   
   /**
    * Mode script for expansion events. Same role as event_mode's EventMode, but keeps
    * the custom-match instance untyped so child-ApplicationDomain classAPI values do not
    * coerce to event_mode's package-less SSF2CustomMatch (#1034).
    */
   public class ExpansionEventOrchestrator
   {
      
      public static var currentInstance:ExpansionEventOrchestrator;

      private static function resources() : *
      {
         return EngineRefs.ssf2("util.ResourceManager");
      }

      private static function api() : *
      {
         return EngineRefs.ssf2("api.SSF2API");
      }
      
      public var $ext:Object;
      
      private var _api:*;
      
      private var m_currentMatch:*;
      
      private var eventMatchPropData:Object = null;
      
      private var eventMatchClass:Class = null;
      
      public function ExpansionEventOrchestrator(api:*)
      {
         super();
         this._api = api;
         this.$ext = {"getAPI":function():*
         {
            return _api;
         }};
      }
      
      /** Prefer this orchestrator when the menu/registry entry is an expansion pack. */
      public static function modeClassForEvent(event:Object) : Class
      {
         var modeCls:* = null;
         if(Boolean(event) && Boolean(event.expansion))
         {
            return ExpansionEventOrchestrator;
         }
         try
         {
            modeCls = resources().getResourceByID("event_mode").getProp("mode");
            if(modeCls is Class)
            {
               return modeCls as Class;
            }
         }
         catch(err:*)
         {
         }
         return null;
      }
      
      public function initialize() : void
      {
         var eventMatchID:String = null;
         var list:Array = null;
         var i:int = 0;
         var entry:Object = null;
         currentInstance = this;
         this.m_currentMatch = null;
         this.eventMatchPropData = null;
         this.eventMatchClass = null;
         try
         {
            eventMatchID = String(this._api.getModeSettings().eventMatchID);
         }
         catch(idErr:*)
         {
            trace("[ExpansionEventOrchestrator] missing eventMatchID: " + idErr);
            return;
         }
         try
         {
            list = resources().getResourceByID("event_mode").getProp("eventList") as Array;
         }
         catch(listErr:*)
         {
            list = null;
         }
         i = 0;
         while(list && i < list.length)
         {
            entry = list[i];
            if(Boolean(entry) && entry.id === eventMatchID)
            {
               this.eventMatchPropData = entry;
               if(entry.classAPI is Class)
               {
                  this.eventMatchClass = entry.classAPI as Class;
               }
               break;
            }
            i++;
         }
         if(!this.eventMatchClass)
         {
            trace("[ExpansionEventOrchestrator] no Class classAPI for id=" + eventMatchID);
            try
            {
               this._api.endMode({});
            }
            catch(endErr:*)
            {
            }
            return;
         }
         try
         {
            this.m_currentMatch = api().createCustomMatch(this.eventMatchClass,this,this._api.getInitialGameSettings());
            this._api.startMatch(this.m_currentMatch);
         }
         catch(startErr:*)
         {
            trace("[ExpansionEventOrchestrator] start failed id=" + eventMatchID + " err=" + startErr);
            try
            {
               this._api.endMode({});
            }
            catch(endErr2:*)
            {
            }
         }
      }
      
      public function handleMatchComplete() : void
      {
         var matchData:Object = null;
         if(!this.m_currentMatch)
         {
            this._api.endMode({});
            return;
         }
         try
         {
            matchData = this.m_currentMatch.matchData;
         }
         catch(mdErr:*)
         {
            matchData = null;
         }
         if(Boolean(matchData) && Boolean(matchData.success))
         {
            this._api.saveModeData({
               "type":"eventMatch",
               "eventMatchID":this._api.getModeSettings().eventMatchID,
               "matchData":matchData
            });
         }
         try
         {
            if(Boolean(matchData))
            {
               api().print("" + matchData.score + ": rank " + matchData.rank + ".");
            }
         }
         catch(printErr:*)
         {
         }
         this._api.endMode({});
      }
      
      public function getSummary() : String
      {
         if(Boolean(this.eventMatchPropData) && Boolean(this.eventMatchPropData.name))
         {
            return String(this.eventMatchPropData.name);
         }
         return "Expansion Event";
      }
   }
}
