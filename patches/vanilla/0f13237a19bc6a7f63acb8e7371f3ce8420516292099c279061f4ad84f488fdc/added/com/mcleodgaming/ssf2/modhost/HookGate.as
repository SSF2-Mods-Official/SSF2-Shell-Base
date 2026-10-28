package com.mcleodgaming.ssf2.modhost
{
   public class HookGate
   {
      
      public function HookGate()
      {
         super();
      }
      
      public static function listening(param1:Array) : Boolean
      {
         return param1 != null && param1.length > 0;
      }
   }
}
