package
{
   import com.mcleodgaming.ssf2.audio.PitchShiftSound;
   import ssf2mm.shared.EngineRefs;

   public class PitchShiftBridge
   {
      private static var player:PitchShiftSound;

      public static function play(soundName:String, initialPitch:Number = 1, scaleVolume:Number = 1) : Boolean
      {
         var resources:Class = null;
         var saveData:Class = null;
         var tempSound:* = null;
         resources = EngineRefs.ssf2("util.ResourceManager") as Class;
         saveData = EngineRefs.ssf2("util.SaveData") as Class;
         tempSound = resources["getLibrarySound"](soundName);
         if(tempSound == null)
         {
            return false;
         }
         if(player)
         {
            player.stop();
         }
         player = new PitchShiftSound();
         player.loadSound(tempSound);
         player.play(initialPitch,Number(saveData["SEVolumeLevel"]) * scaleVolume);
         return true;
      }

      public static function updatePitch(newPitch:Number) : void
      {
         if(player && player.IsPlaying)
         {
            player.PitchShift = newPitch;
         }
      }

      public static function updateVolume(volume:Number) : void
      {
         if(player && player.IsPlaying)
         {
            player.Volume = volume;
         }
      }

      public static function stop() : void
      {
         if(player)
         {
            player.stop();
            player = null;
         }
      }

      public static function isPlaying() : Boolean
      {
         return player != null && player.IsPlaying;
      }
   }
}
