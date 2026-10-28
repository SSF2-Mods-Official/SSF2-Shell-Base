package com.jotard.ane
{
   import flash.events.EventDispatcher;
   import flash.external.*;
   
   public class DiscordGameSDK extends EventDispatcher
   {
      
      private static var _context:ExtensionContext;
      
      private static const EXTENSION_ID:String = "com.jotard.ane.DiscordANE";
      
      private static const NATIVE_HEADER_NAME:String = "[DiscordANENative]";
      
      private static const AS3_HEADER_NAME:String = "[DiscordGameSDK]";
      
      public function DiscordGameSDK()
      {
         super();
         _context = ExtensionContext.createExtensionContext("com.jotard.ane.DiscordANE",null);
         if(Boolean(_context))
         {
            _context.addEventListener("status",this.onStatus);
         }
      }
      
      private function onStatus(param1:Object) : void
      {
         if(param1.level is String || param1.level is Number || param1.level is Boolean)
         {
            this.dispatchEvent(new DiscordEvent(param1.code,param1.level));
         }
         else
         {
            this.dispatchEvent(new DiscordEvent(param1.code,JSON.parse(param1.level)));
         }
      }
      
      public function initialize(param1:String, param2:Object = null, param3:int = 5000) : void
      {
         var onSuccessConnect:Function = null;
         var activity:Object = null;
         onSuccessConnect = null;
         activity = null;
         onSuccessConnect = null;
         var applicationID:String = param1;
         activity = param2;
         var reconnectInterval:int = param3;
         onSuccessConnect = null;
         onSuccessConnect = null;
         onSuccessConnect = null;
         var defaultFlag:String = null;
         var notRequireDiscordFlag:String = null;
         onSuccessConnect = null;
         if(!_context)
         {
            return;
         }
         defaultFlag = "0";
         notRequireDiscordFlag = "1";
         _context.call("initialize",applicationID,notRequireDiscordFlag,activity);
         onSuccessConnect = function(param1:Object):void
         {
            var _loc2_:int = 0;
            _context.removeEventListener("status",onSuccessConnect);
            if(Boolean(param1) && param1.code == "CORE_INIT")
            {
               _loc2_ = int(param1.level);
               if(_loc2_ == 0)
               {
                  _context.call("updateActivity",activity);
               }
            }
         };
         _context.addEventListener("status",onSuccessConnect);
      }
      
      public function runCallbacks() : void
      {
         if(!_context)
         {
            return;
         }
         _context.call("runCallbacks");
      }
      
      public function updateActivity(param1:Object) : void
      {
         if(!_context)
         {
            return;
         }
         try
         {
            _context.call("updateActivity",param1);
         }
         catch(err:Error)
         {
         }
      }
      
      public function sendRequestReply(param1:String, param2:int) : void
      {
         if(!_context)
         {
            return;
         }
         _context.call("sendRequestReply",param1,param2);
      }
      
      public function sendInvite(param1:String, param2:int, param3:String) : void
      {
         if(!_context)
         {
            return;
         }
         _context.call("sendInvite",param1,param2,param3);
      }
      
      public function acceptInvite(param1:String) : void
      {
         if(!_context)
         {
            return;
         }
         _context.call("acceptInvite",param1);
      }
   }
}
