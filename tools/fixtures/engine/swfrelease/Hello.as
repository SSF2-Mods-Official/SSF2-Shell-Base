package
{
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   public class Hello extends Sprite
   {
      public function Hello()
      {
         trace("hello");
         NativeApplication.nativeApplication.exit(0);
      }
   }
}
