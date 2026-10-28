package com.mcleodgaming.ssf2.engine
{
   public class TelemetryLookup
   {
      
      public var known:Boolean = false;
      
      public var hold:Boolean = true;
      
      public var lookups:int = 0;
      
      public var value:* = null;
      
      public function TelemetryLookup()
      {
         super();
      }
      
      public function holdOff() : void
      {
         this.value = null;
         this.known = false;
         this.hold = true;
      }
      
      public function release() : void
      {
         this.hold = false;
         this.known = false;
      }
      
      public function resolve(param1:Function) : *
      {
         var lookup:Function = param1;
         if(this.hold)
         {
            return null;
         }
         if(this.known)
         {
            return this.value;
         }
         this.known = true;
         ++this.lookups;
         try
         {
            this.value = lookup();
         }
         catch(err:*)
         {
            this.value = null;
         }
         return this.value;
      }
   }
}
