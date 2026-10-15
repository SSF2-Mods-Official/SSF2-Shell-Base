package
{
   import com.mcleodgaming.ssf2.menus.HitBoxTestMenu;
   import flash.display.Sprite;

   public class DebugHitboxMod extends Sprite
   {
      public function DebugHitboxMod()
      {
         super();
      }

      public function onBoot(host:*):void
      {
         if(!host)
         {
            return;
         }
         host.patch("debug_hitbox.menu",function():*
         {
            return new HitBoxTestMenu();
         });
      }
   }
}
