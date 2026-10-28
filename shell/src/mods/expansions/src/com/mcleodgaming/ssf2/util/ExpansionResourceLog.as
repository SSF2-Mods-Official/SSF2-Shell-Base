package com.mcleodgaming.ssf2.util
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.api.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.modhost.*;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.media.*;
   import flash.system.*;
   import flash.utils.ByteArray;
   import ssf2mm.shared.EngineRefs;

   public class ExpansionResourceLog
   {
      internal static function rmLog(msg:String) : void
      {
         var GL:* = undefined;
         try
         {
            GL = EngineRefs.ssf2("util.GameLog");
            if(GL && GL.write is Function)
            {
               GL.write(msg);
            }
         }
         catch(logErr:*)
         {
         }
         trace(msg);
      }

      internal static function step(name:String, err:*) : void
      {
         rmLog("[ResourceManager] " + name + " failed: " + (err is Error ? Error(err).message : String(err)));
      }
   }
}
