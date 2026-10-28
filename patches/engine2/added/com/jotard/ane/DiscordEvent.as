package com.jotard.ane
{
   import flash.events.Event;
   
   public final class DiscordEvent extends Event
   {
      
      public static const CORE_INIT:String = "CORE_INIT";
      
      public static const DISCORD_LOG_HOOK:String = "DISCORD_LOG_HOOK";
      
      public static const ON_ACTIVITY_JOIN_REQUEST:String = "ON_ACTIVITY_JOIN_REQUEST";
      
      public static const ON_ACTIVITY_INVITE:String = "ON_ACTIVITY_INVITE";
      
      public static const ON_ACTIVITY_JOIN:String = "ON_ACTIVITY_JOIN";
      
      public static const ON_ACTIVITY_SPECTATE:String = "ON_ACTIVITY_SPECTATE";
      
      public static const RUN_CALLBACKS:String = "RUN_CALLBACKS";
      
      public static const UPDATE_ACTIVITY:String = "UPDATE_ACTIVITY";
      
      public static const SEND_REQUEST_REPLY:String = "SEND_REQUEST_REPLY";
      
      public static const SEND_INVITE:String = "SEND_INVITE";
      
      public static const ACCEPT_INVITE:String = "ACCEPT_INVITE";
      
      private var _data:Object;
      
      public function DiscordEvent(param1:String, param2:Object = null, param3:Boolean = false, param4:Boolean = false)
      {
         super(param1,param3,param4);
         this._data = Boolean(param2) ? param2 : {};
      }
      
      public function get data() : Object
      {
         return this._data;
      }
   }
}
