package com.mcleodgaming.ssf2.modhost
{
   import flash.filesystem.*;
   
   public class ModInfo
   {
      
      public var id:String;
      
      public var name:String;
      
      public var description:String;
      
      public var version:String;
      
      public var lifetime:String;
      
      public var entryClass:String;
      
      public var enabledByDefault:Boolean;
      
      public var folderPath:String;
      
      public var folderName:String;
      
      public var swfPath:String;
      
      public var relativeBase:String;
      
      public var essential:Boolean;
      
      public var runtimeClass:Class;
      
      public var resources:Array;
      
      public function ModInfo()
      {
         super();
         this.id = "";
         this.name = "";
         this.description = "";
         this.version = "1.0.0";
         this.lifetime = "boot";
         this.entryClass = null;
         this.enabledByDefault = true;
         this.folderPath = null;
         this.folderName = null;
         this.swfPath = null;
         this.relativeBase = "expansions/mods";
         this.essential = false;
         this.runtimeClass = null;
         this.resources = [];
      }
      
      public static function fromFolder(param1:File, param2:String = "expansions/mods", param3:Boolean = false) : ModInfo
      {
         var folder:File = param1;
         var relativeBase:String = param2;
         var essential:Boolean = param3;
         var jsonFile:File = null;
         var stream:FileStream = null;
         var raw:String = null;
         var data:Object = null;
         var info:ModInfo = null;
         var swf:File = null;
         var i:int = 0;
         var rawRes:Array = null;
         var item:Object = null;
         var copy:Object = null;
         if(!folder || !folder.isDirectory)
         {
            return null;
         }
         jsonFile = folder.resolvePath("mod.json");
         if(!jsonFile.exists)
         {
            return null;
         }
         try
         {
            stream = new FileStream();
            stream.open(jsonFile,FileMode.READ);
            raw = stream.readUTFBytes(stream.bytesAvailable);
            stream.close();
            data = JSON.parse(raw);
         }
         catch(err:Error)
         {
            return null;
         }
         info = new ModInfo();
         info.folderPath = folder.nativePath;
         info.folderName = folder.name;
         info.relativeBase = Boolean(relativeBase) && relativeBase.length > 0 ? relativeBase : "expansions/mods";
         info.essential = essential;
         info.id = String(data.id || folder.name);
         info.name = String(data.name || info.id);
         info.description = String(data.description || "");
         info.version = String(data.version || "1.0.0");
         info.lifetime = String(data.lifetime || "boot");
         info.entryClass = Boolean(data.entryClass) ? String(data.entryClass) : null;
         info.enabledByDefault = essential ? true : data.enabledByDefault !== false;
         swf = folder.resolvePath("mod.swf");
         if(swf.exists)
         {
            info.swfPath = swf.nativePath;
         }
         info.resources = [];
         if(data.resources is Array)
         {
            rawRes = data.resources as Array;
            i = 0;
            while(i < rawRes.length)
            {
               item = rawRes[i];
               if(!(!item || !item.id || !item.file))
               {
                  copy = {
                     "id":String(item.id),
                     "file":String(item.file),
                     "type":(Boolean(item.type) ? String(item.type) : "menu"),
                     "guid":(Boolean(item.guid) ? String(item.guid) : ""),
                     "softFail":item.softFail !== false
                  };
                  info.resources.push(copy);
               }
               i++;
            }
         }
         return info;
      }
   }
}
