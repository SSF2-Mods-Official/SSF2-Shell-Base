package com.mcleodgaming.ssf2.engine
{
   import flash.system.*;
   
   public class FrameBudget
   {
      
      public static const SLACK:int = 16;
      
      public function FrameBudget()
      {
         super();
      }
      
      public static function shouldCollect(param1:int) : Boolean
      {
         return param1 < SLACK;
      }
      
      public static function afterTick(param1:int) : void
      {
         if(shouldCollect(param1))
         {
            System.pauseForGCIfCollectionImminent(0.75);
         }
      }
   }
}
