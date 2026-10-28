package
{
   import com.mcleodgaming.ssf2.util.SwfRelease;
   import flash.desktop.NativeApplication;
   import flash.display.Loader;
   import flash.display.LoaderInfo;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.system.ApplicationDomain;
   import flash.system.System;
   import flash.utils.ByteArray;
   
   public class SwfReleaseFixture extends Sprite
   {
      private static const ROUNDS:int = 4;
      private static const SLACK:int = 6 << 20;
      private static const ALLOC:int = 24 << 20;
      
      private var fileBytes:ByteArray;
      private var loaders:Array;
      private var baseline:int;
      private var loadedAt:int;
      private var basePriv:int;
      private var loadedPriv:int;
      private var parentHas:int;
      private var heldW:int;
      private var forgot:int;
      private var step:int;
      private var frames:int;
      private var phase:String;
      
      public function SwfReleaseFixture()
      {
         addEventListener(Event.ADDED_TO_STAGE,onStage);
      }
      
      private function onStage(e:Event):void
      {
         var heavy:File;
         var stream:FileStream;
         removeEventListener(Event.ADDED_TO_STAGE,onStage);
         loaders = [];
         heavy = File.applicationDirectory.resolvePath("heavy.swf");
         stream = new FileStream();
         stream.open(heavy,FileMode.READ);
         fileBytes = new ByteArray();
         stream.readBytes(fileBytes);
         stream.close();
         collect();
         baseline = System.totalMemory;
         basePriv = System.privateMemory;
         step = 0;
         parentHas = 0;
         loadNext();
      }
      
      private function loadNext():void
      {
         var copy:ByteArray;
         var loader:Loader;
         if(step >= ROUNDS)
         {
            return;
         }
         copy = new ByteArray();
         copy.writeBytes(fileBytes);
         loader = new Loader();
         loader.contentLoaderInfo.addEventListener(Event.COMPLETE,onOne);
         loader.contentLoaderInfo.addEventListener(Event.INIT,onOne);
         loaders.push(loader);
         loader.loadBytes(copy,SwfRelease.context());
      }
      
      private function onOne(e:Event):void
      {
         var info:LoaderInfo;
         var heavyClass:Class;
         var held:*;
         if(e.type != Event.COMPLETE)
         {
            return;
         }
         info = e.target as LoaderInfo;
         info.removeEventListener(Event.COMPLETE,onOne);
         info.removeEventListener(Event.INIT,onOne);
         if(ApplicationDomain.currentDomain.hasDefinition("Heavy"))
         {
            parentHas = 1;
         }
         try
         {
            heavyClass = info.applicationDomain.getDefinition("Heavy") as Class;
            held = heavyClass["held"];
            if(held)
            {
               heldW = int(held.width);
            }
         }
         catch(defErr:*)
         {
         }
         step++;
         if(step < ROUNDS)
         {
            loadNext();
            return;
         }
         phase = "peak";
         frames = 0;
         addEventListener(Event.ENTER_FRAME,onFrame);
      }
      
      private function releaseAll():void
      {
         var i:int;
         var loader:Loader;
         var cache:Object;
         var info:LoaderInfo;
         var heavyClass:Class;
         loadedAt = System.totalMemory;
         loadedPriv = System.privateMemory;
         cache = {};
         i = 0;
         while(i < loaders.length)
         {
            loader = loaders[i] as Loader;
            info = loader.contentLoaderInfo;
            heavyClass = info.applicationDomain.getDefinition("Heavy") as Class;
            cache["Heavy"] = {"ref":heavyClass,"src":"nope"};
            forgot = forgot + SwfRelease.forget(cache,loader);
            i++;
         }
         if(cache["Heavy"])
         {
            forgot = -1;
         }
         i = 0;
         while(i < loaders.length)
         {
            loader = loaders[i] as Loader;
            SwfRelease.release(loader);
            loaders[i] = null;
            i++;
         }
         loaders = null;
         phase = "settle";
         frames = 0;
      }
      
      private function onFrame(e:Event):void
      {
         frames++;
         collect();
         if(phase == "peak")
         {
            if(frames >= 3)
            {
               releaseAll();
            }
            return;
         }
         if(frames < 8)
         {
            return;
         }
         removeEventListener(Event.ENTER_FRAME,onFrame);
         finish();
      }
      
      private function finish():void
      {
         var after:int;
         var afterPriv:int;
         var grewFlash:int;
         var grewPriv:int;
         var allocated:int;
         var failure:String;
         after = System.totalMemory;
         afterPriv = System.privateMemory;
         grewFlash = after - baseline;
         grewPriv = afterPriv - basePriv;
         allocated = loadedAt - baseline;
         if(parentHas != 0)
         {
            failure = "Heavy landed in the current domain";
         }
         else if(heldW != 2048)
         {
            failure = "bitmap missing heldW=" + heldW;
         }
         else if(allocated < ALLOC)
         {
            failure = "did not allocate flash=" + (allocated >> 20) + " priv=" + ((loadedPriv - basePriv) >> 20) + " heldW=" + heldW;
         }
         else if(forgot < ROUNDS)
         {
            failure = "forgot=" + forgot;
         }
         else if(grewFlash > SLACK)
         {
            failure = "flashGrew=" + (grewFlash >> 20) + " load=" + (allocated >> 20) + " base=" + (baseline >> 20) + " after=" + (after >> 20) + " privGrew=" + (grewPriv >> 20);
         }
         trace(failure ? ("FIXTURE FAIL " + failure) : "FIXTURE OK");
         writeResult(failure);
         NativeApplication.nativeApplication.exit(failure ? 1 : 0);
      }
      
      private function collect():void
      {
         try
         {
            System.gc();
         }
         catch(gcErr:*)
         {
         }
      }
      
      private function writeResult(failure:String):void
      {
         var file:File;
         var stream:FileStream;
         file = File.applicationStorageDirectory.resolvePath("swf-release-fixture.txt");
         stream = new FileStream();
         stream.open(file,FileMode.WRITE);
         stream.writeUTFBytes(failure ? ("FAIL " + failure) : "OK");
         stream.close();
      }
   }
}
