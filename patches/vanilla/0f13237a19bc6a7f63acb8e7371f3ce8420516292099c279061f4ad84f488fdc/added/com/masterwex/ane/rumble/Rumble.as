package com.masterwex.ane.rumble
{
   import flash.external.*;
   
   public class Rumble
   {
      
      private static var _ctx:ExtensionContext;
      
      public function Rumble()
      {
         super();
      }
      
      public static function initialize() : Boolean
      {
         if(!_ctx)
         {
            _ctx = ExtensionContext.createExtensionContext("com.masterwex.ane.rumble",null);
            if(!_ctx)
            {
               return false;
            }
         }
         var _loc1_:Object = _ctx.call("initialize");
         return Boolean(_loc1_);
      }
      
      public static function setRumble(param1:int, param2:Number, param3:Number, param4:int) : Boolean
      {
         if(!_ctx)
         {
            if(!initialize())
            {
               return false;
            }
         }
         var _loc5_:Object = _ctx.call("setRumble",param1,param2,param3,param4);
         return Boolean(_loc5_);
      }
      
      public static function identifyActiveControllers() : Array
      {
         if(!_ctx)
         {
            if(!initialize())
            {
               return null;
            }
         }
         var _loc1_:* = _ctx.call("identifyActiveControllers");
         return _loc1_ is Array ? _loc1_ as Array : null;
      }
      
      public static function getControllerState(param1:int) : Object
      {
         if(!_ctx)
         {
            if(!initialize())
            {
               return null;
            }
         }
         return _ctx.call("getControllerState",param1);
      }
      
      public static function stopAll() : Boolean
      {
         if(!_ctx)
         {
            if(!initialize())
            {
               return false;
            }
         }
         var _loc1_:Object = _ctx.call("stopAll");
         return Boolean(_loc1_);
      }
      
      public static function shutdown() : Boolean
      {
         if(!_ctx)
         {
            return true;
         }
         var _loc1_:Object = _ctx.call("shutdown");
         try
         {
            _ctx.dispose();
         }
         catch(e:Error)
         {
         }
         _ctx = null;
         return Boolean(_loc1_);
      }
   }
}
