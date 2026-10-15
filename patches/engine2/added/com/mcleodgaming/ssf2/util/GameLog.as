package com.mcleodgaming.ssf2.util
{
   import flash.filesystem.*;
   
   public class GameLog
   {
      
      private static var m_absPath:String = "";
      
      private static var m_defaultRel:String = "data/ssf2mm/game.log";
      
      public function GameLog()
      {
         super();
      }
      
      public static function setPath(param1:String) : void
      {
         m_absPath = param1 ? param1 : "";
      }
      
      public static function write(param1:String, ... rest) : void
      {
         var _loc3_:String = param1 == null ? "" : String(param1);
         var _loc4_:int = 0;
         while(_loc4_ < rest.length)
         {
            _loc3_ += " " + rest[_loc4_];
            _loc4_++;
         }
         append(_loc3_);
      }
      
      public static function append(param1:String) : void
      {
         var _loc2_:File = null;
         var _loc3_:FileStream = null;
         var _loc4_:String = param1 == null ? "" : String(param1);
         try
         {
            if(Boolean(m_absPath) && m_absPath.length > 0)
            {
               _loc2_ = new File(m_absPath);
            }
            else
            {
               _loc2_ = File.applicationDirectory.resolvePath(m_defaultRel);
            }
            if(Boolean(_loc2_.parent) && !_loc2_.parent.exists)
            {
               _loc2_.parent.createDirectory();
            }
            _loc3_ = new FileStream();
            _loc3_.open(_loc2_,FileMode.APPEND);
            _loc3_.writeUTFBytes(_loc4_ + "\n");
            _loc3_.close();
         }
         catch(err:*)
         {
         }
      }
   }
}
