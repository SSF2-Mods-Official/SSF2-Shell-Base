package
{
   import com.mcleodgaming.ssf2.engine.FrameBudget;
   import com.mcleodgaming.ssf2.engine.TelemetryLookup;
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
         var gate:TelemetryLookup;
         var lookups:int;
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
         gate = new TelemetryLookup();
         if(gate.resolve(boom) != null || gate.lookups != 0)
         {
            write("held");
            return;
         }
         gate.release();
         if(gate.resolve(found) != "Air")
         {
            write("miss");
            return;
         }
         lookups = gate.lookups;
         if(gate.resolve(boom) != "Air" || gate.lookups != lookups)
         {
            write("recache");
            return;
         }
         gate.holdOff();
         if(gate.resolve(boom) != null || gate.lookups != lookups)
         {
            write("rehold");
            return;
         }
         gate.release();
         if(gate.resolve(found) != "Air" || gate.lookups != lookups + 1)
         {
            write("relock");
            return;
         }
         if(!FrameBudget.shouldCollect(10))
         {
            write("slack10");
            return;
         }
         if(FrameBudget.shouldCollect(16) || FrameBudget.shouldCollect(40))
         {
            write("slack16");
            return;
         }
         write("OK");
      }
      
      private function found() : *
      {
         return "Air";
      }
      
      private function boom() : *
      {
         throw new Error("lookup");
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
