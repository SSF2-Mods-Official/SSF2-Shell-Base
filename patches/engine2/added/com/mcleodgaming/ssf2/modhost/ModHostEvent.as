package com.mcleodgaming.ssf2.modhost
{
   import flash.events.Event;
   
   public class ModHostEvent extends Event
   {
      
      public var data:Object;
      
      public function ModHostEvent(param1:String, param2:Object = null, param3:Boolean = false, param4:Boolean = false)
      {
         super(param1,param3,param4);
         this.data = param2;
      }
      
      override public function clone() : Event
      {
         return new ModHostEvent(type,this.data,bubbles,cancelable);
      }
   }
}
