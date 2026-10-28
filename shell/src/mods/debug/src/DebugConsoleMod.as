package
{
   import com.mcleodgaming.ssf2.menus.DebugConsole;
   import com.mcleodgaming.ssf2.menus.ShellDebugConsole;
   import flash.display.Sprite;

   public class DebugConsoleMod extends Sprite
   {
      public function DebugConsoleMod()
      {
         super();
      }

      public function onBoot(host:*):void
      {
         if(!host)
         {
            return;
         }
         host["replaceClass"](DebugConsole, ShellDebugConsole);
      }
   }
}
