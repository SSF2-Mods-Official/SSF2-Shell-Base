package
{
   import com.mcleodgaming.ssf2.modhost.HookGate;
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   
   public class FrameGateFixture extends Sprite
   {
      public function FrameGateFixture()
      {
         addEventListener(Event.ADDED_TO_STAGE,onStage);
      }
      
      private function onStage(e:Event) : void
      {
         removeEventListener(Event.ADDED_TO_STAGE,onStage);
         if(HookGate.listening(null))
         {
            write("hook null");
            return;
         }
         if(HookGate.listening([]))
         {
            write("hook empty");
            return;
         }
         if(!HookGate.listening([onStage]))
         {
            write("hook list");
            return;
         }
         write("OK");
      }
      
      private function write(line:String) : void
      {
         var stream:FileStream = new FileStream();
         var file:File = File.applicationStorageDirectory.resolvePath("frame-gate-fixture.txt");
         stream.open(file,FileMode.WRITE);
         stream.writeUTFBytes(line);
         stream.close();
         NativeApplication.nativeApplication.exit(line == "OK" ? 0 : 1);
      }
   }
}
