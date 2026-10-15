package com.mcleodgaming.ssf2.util
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.api.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.modhost.*;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.media.*;
   import flash.system.*;
   import flash.utils.ByteArray;
   import ssf2mm.shared.EngineRefs;

   public class ExpansionAudioResources
   {
      public static function getExpansionAnnouncerId(statsName:String) : String
      {
         if(Boolean(statsName) && Boolean(ResourceManager.m_expansionAnnouncerSound[statsName]))
         {
            return "narrator_" + statsName;
         }
         return null;
      }

      public static function tryGetExpansionAnnouncerSound(soundName:String) : Sound
      {
         var statsName:String = null;
         if(!soundName || soundName.indexOf("narrator_") != 0)
         {
            return null;
         }
         statsName = soundName.substring("narrator_".length);
         if(Boolean(statsName) && Boolean(ResourceManager.m_expansionAnnouncerSound[statsName]))
         {
            return ResourceManager.m_expansionAnnouncerSound[statsName] as Sound;
         }
         return null;
      }

      public static function tryLoadExpansionAnnouncerFromFolder(statsName:String, folder:File) : void
      {
         var announcerFile:File = null;
         if(!statsName || !folder || !folder.exists)
         {
            return;
         }
         announcerFile = folder.resolvePath("announcer.mp3");
         if(announcerFile.exists)
         {
            loadExpansionAnnouncer(statsName,announcerFile);
         }
      }

      public static function loadExpansionAnnouncer(statsName:String, file:File) : void
      {
         var stream:FileStream = null;
         var bytes:ByteArray = null;
         var sound:Sound = null;
         if(!statsName || !file || !file.exists)
         {
            return;
         }
         if(Boolean(ResourceManager.m_expansionAnnouncerSound[statsName]))
         {
            return;
         }
         try
         {
            stream = new FileStream();
            stream.open(file,FileMode.READ);
            bytes = new ByteArray();
            stream.readBytes(bytes);
            stream.close();
            bytes.position = 0;
            sound = new Sound();
            sound.loadCompressedDataFromByteArray(bytes,bytes.length);
            ResourceManager.m_expansionAnnouncerSound[statsName] = sound;
            GameLog.write("[ResourceManager] Loaded expansion announcer.mp3 for " + statsName);
         }
         catch(err:Error)
         {
            GameLog.write("[ResourceManager] announcer.mp3 load failed for " + statsName + ": " + err.message);
         }
      }
   }
}
