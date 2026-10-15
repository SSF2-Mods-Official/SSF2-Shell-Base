package
{
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.utils.ByteArray;
   
   public class Heavy extends Sprite
   {
      public static var held:BitmapData;
      public static var blob:ByteArray;
      
      public function Heavy()
      {
         if(!held)
         {
            held = new BitmapData(2048,2048,false,0xFF336699);
         }
         if(!blob)
         {
            blob = new ByteArray();
            blob.length = 8 << 20;
         }
      }
   }
}
