package ssf2mm.replay
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.audio.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.enums.*;
   import com.mcleodgaming.ssf2.modapi.ModAPI;
   import com.mcleodgaming.ssf2.modhost.ModHost;
   import com.mcleodgaming.ssf2.net.*;
   import com.mcleodgaming.ssf2.util.ResourceManager;
   import com.mcleodgaming.ssf2.util.Utils;
   import ssf2mm.shared.JsonFile;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.geom.*;
   import flash.net.*;
   import flash.text.*;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   
   /** Text for the replay list and info panel: mode, rules, lineup, duration, stage name. */
   public class ReplayLabels
   {
      public static function modeLabel(param1:int) : String
      {
         switch(param1)
         {
            case Mode.VS:
               return "Versus";
            case Mode.ONLINE:
               return "Online";
            case Mode.ARENA:
            case Mode.ONLINE_ARENA:
               return "Arena";
            case Mode.TARGET_TEST:
               return "Target Test";
            case Mode.HOME_RUN_CONTEST:
               return "Home-Run Contest";
            case Mode.MULTIMAN:
               return "Multi-Man";
            case Mode.CRYSTAL_SMASH:
               return "Crystal Smash";
            case Mode.RACE_TO_THE_FINISH:
               return "Race to Finish";
            default:
               return "Versus";
         }
      }
      
      public static function rulesLabel(param1:Object) : String
      {
         if(param1 == null)
         {
            return "";
         }
         var _loc2_:Array = [];
         if(Boolean(param1.usingLives) && param1.lives !== undefined)
         {
            _loc2_.push(param1.lives + " Stock");
         }
         if(Boolean(param1.usingTime) && Boolean(param1.time !== undefined) && param1.time > 0)
         {
            _loc2_.push(param1.time + " Min");
         }
         if(param1.usingStamina)
         {
            _loc2_.push("Stamina");
         }
         return _loc2_.join("  |  ");
      }
      
      public static function lineupLabel(param1:Array) : String
      {
         var _loc4_:Object = null;
         var _loc5_:String = null;
         var _loc6_:String = null;
         if(param1 == null || param1.length == 0)
         {
            return "";
         }
         var _loc2_:Array = [];
         var _loc3_:int = 0;
         while(_loc3_ < param1.length)
         {
            _loc4_ = param1[_loc3_];
            if(_loc4_.exist === false)
            {
               _loc3_++;
            }
            else
            {
               _loc5_ = _loc4_.character ? _loc4_.character : "?";
               _loc6_ = _loc5_.charAt(0).toUpperCase() + _loc5_.substr(1);
               if(_loc4_.human === false)
               {
                  _loc6_ += " (CPU)";
               }
               _loc2_.push(_loc6_);
               _loc3_++;
            }
         }
         return _loc2_.join(" vs ");
      }
      
      public static function durationLabel(param1:int) : String
      {
         var _loc2_:int = int(param1 / 60);
         var _loc3_:int = int(_loc2_ / 60);
         _loc2_ %= 60;
         return _loc3_ + ":" + (_loc2_ < 10 ? "0" : "") + _loc2_;
      }
      
      public static function stagePretty(param1:String) : String
      {
         var _loc3_:Object = null;
         if(param1 == null || param1 == "")
         {
            return "?";
         }
         try
         {
            _loc3_ = ResourceManager.getResourceByID("mappings").getProp("metadata").stage;
            if(Boolean(_loc3_) && Boolean(_loc3_[param1]) && Boolean(_loc3_[param1].name))
            {
               return _loc3_[param1].name;
            }
         }
         catch(e_m:*)
         {
         }
         var _loc2_:String = param1.replace(/([A-Z])/g," $1").replace(/(\d+)/g," $1").replace(/_/g," ").replace(/\s+/g," ");
         _loc2_ = _loc2_.charAt(0).toUpperCase() + _loc2_.substr(1);
         return _loc2_.replace(/^\s/,"");
      }
      
      public static function makeFolderButton(param1:String, param2:int = 110) : MovieClip
      {
         var _loc3_:int = 18;
         var _loc4_:MovieClip = new MovieClip();
         _loc4_.graphics.lineStyle(1,4500036,1);
         _loc4_.graphics.beginFill(1118481,0.88);
         _loc4_.graphics.drawRoundRect(0,0,param2,_loc3_,4,4);
         _loc4_.graphics.endFill();
         var _loc5_:TextField = new TextField();
         var _loc6_:TextFormat = new TextFormat("_sans",9,13434828,true);
         _loc6_.align = "center";
         _loc5_.defaultTextFormat = _loc6_;
         _loc5_.text = param1;
         _loc5_.setTextFormat(_loc6_);
         _loc5_.width = param2;
         _loc5_.height = _loc3_;
         _loc5_.x = 0;
         _loc5_.y = 1;
         _loc5_.selectable = false;
         _loc5_.mouseEnabled = false;
         _loc4_.addChild(_loc5_);
         return _loc4_;
      }
   }
}
