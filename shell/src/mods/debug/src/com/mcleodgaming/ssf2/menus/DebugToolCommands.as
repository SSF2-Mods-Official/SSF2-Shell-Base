package com.mcleodgaming.ssf2.menus
{
    import com.mcleodgaming.ssf2.interfaces.IDebugConsole;
    import flash.text.TextField;
    import com.mcleodgaming.ssf2.util.ResourceManager;
    import com.mcleodgaming.ssf2.Main;
    import flash.events.KeyboardEvent;
    import flash.events.Event;
    import com.mcleodgaming.ssf2.util.Key;
    import com.adobe.utils.StringUtil;
    import com.mcleodgaming.ssf2.controllers.GameController;
    import com.mcleodgaming.ssf2.engine.ItemData;
    import com.mcleodgaming.ssf2.items.Item;
    import com.mcleodgaming.ssf2.items.ItemsListData;
    import com.mcleodgaming.ssf2.Version;
    import com.mcleodgaming.ssf2.net.MultiplayerManager;
    import com.mcleodgaming.ssf2.engine.HitBoxManager;
    import flash.system.System;
    import com.mcleodgaming.ssf2.engine.Character;
    import com.mcleodgaming.ssf2.util.Utils;
    import __AS3__.vec.Vector;
    import com.mcleodgaming.ssf2.util.Resource;
    import flash.utils.ByteArray;
    import flash.utils.Timer;
    import flash.geom.ColorTransform;
    import flash.display.Shape;
    import com.mcleodgaming.ssf2.enums.SpecialMode;
    import com.mcleodgaming.ssf2.engine.ReplayData;
    import flash.events.TimerEvent;
    import com.mcleodgaming.ssf2.enums.Mode;
    import com.mcleodgaming.ssf2.controllers.Game;
    import com.mcleodgaming.ssf2.controllers.MenuController;
    import com.mcleodgaming.ssf2.util.SaveData;
    import com.mcleodgaming.ssf2.controllers.UnlockController;
    import com.mcleodgaming.ssf2.controllers.Unlockable;
    import com.mcleodgaming.ssf2.util.Vcam;
    import com.mcleodgaming.ssf2.util.*;
    import com.mcleodgaming.ssf2.engine.*;
    import com.mcleodgaming.ssf2.items.*;
    import __AS3__.vec.*;

    /** Console tools: encrypt, decrypt, bgmcheck. */
    public class DebugToolCommands extends DebugCommandSet
    {
        public function DebugToolCommands(console:ShellDebugConsole)
        {
            super(console);
        }

        public function encrypt(... args):void
        {
            this.parseFlags(args);
            var error:String = "Error, encrypt expects a single solid string (no spaces) followed by an encryption key (no spaces) . (e.g. encrypt mytext mykey)";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else
            {
                if (((args.length == 1) || (args.length > 2)))
                {
                    this.writeLine("Error, encrypt expects an encryption key to follow the text to encrypt (no spaces)");
                }
                else
                {
                    this.writeLine(("Key: " + args[1]));
                    this.writeLine(("Input: " + args[0]));
                    this.writeLine("Encrypted text:");
                    this.writeLine(encryptText(args[0], args[1]));
                };
            };
        }

        public function decrypt(... args):void
        {
            this.parseFlags(args);
            var error:String = "Error, decrypt expects a single solid string (no spaces) followed by a decryption key (no spaces). (e.g. decrypt mytext mykey)";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else
            {
                if (((args.length == 1) || (args.length > 2)))
                {
                    this.writeLine("Error, decrypt expects a decryption key to follow the text to decrypt (no spaces)");
                }
                else
                {
                    this.writeLine(("Key: " + args[1]));
                    this.writeLine(("Input: " + args[0]));
                    this.writeLine("Decrypted text:");
                    this.writeLine(Utils.d(args[0], args[1]));
                };
            };
        }

        public function bgmcheck(... args):void
        {
            var i:* = undefined;
            var stages:Vector.<Resource>;
            var flags:Array = this.parseFlags(args);
            if (((!(flags.length == 1)) || (!((flags.indexOf("-public") >= 0) || (flags.indexOf("-all") >= 0)))))
            {
                this.writeLine("Error, bgmcheck expects single flag -public or -all");
                return;
            };
            var all:Boolean = (flags.indexOf("-all") >= 0);
            var manifest:Object = Utils.cloneObject(ResourceManager.manifestJSONData);
            var extendedMetaData:Object = Utils.cloneObject(ResourceManager.getResourceByID("mappings").getProp("metadata_dev"));
            stages = new Vector.<Resource>();
            var music:Vector.<Resource> = new Vector.<Resource>();
            for (i in manifest.stage)
            {
                if ((!(i in extendedMetaData.stage)))
                {
                    this.addBgmResource(i, Resource.STAGE, "stage", stages, true);
                };
            };
            for (i in manifest.music)
            {
                if ((!(i in extendedMetaData.music)))
                {
                    this.addBgmResource(i, Resource.MUSIC, "music", music, false);
                };
            };
            if (flags.indexOf("-all") >= 0)
            {
                this.writeLine("Checking all mappings for missing bgms...");
                for (i in extendedMetaData.stage)
                {
                    this.addBgmResource(i, Resource.STAGE, "stage", stages, true);
                };
                for (i in extendedMetaData.music)
                {
                    this.addBgmResource(i, Resource.MUSIC, "music", music, false);
                };
            }
            else
            {
                this.writeLine("Checking public mappings for missing bgms...");
            };
            this.loadBgmStages(stages);
        }

        /** One bgmcheck candidate: warn on a bad entry, otherwise add it to list (and queue it when asked). */
        private function addBgmResource(i:*, type:*, label:String, list:Vector.<Resource>, queue:Boolean):void
        {
            var res:Resource = ResourceManager.getResourceByID(i);
            if (res)
            {
                if (res.Type !== type)
                {
                    return;
                };
                if ((!(res.ID)))
                {
                    this.writeLine((("Warning: bgmcheck " + label + " resource '" + i) + "' does not have valid resource id"));
                }
                else
                {
                    if ((!(res.FileName)))
                    {
                        this.writeLine((("Warning: bgmcheck " + label + " resource '" + i) + "' does not have valid file name"));
                    }
                    else
                    {
                        list.push(res);
                        if (queue)
                        {
                            ResourceManager.queueResources([res.ID]);
                        };
                    };
                };
            }
            else
            {
                this.writeLine(("Warning: bgmcheck could not find " + label + " id: " + i));
            };
        }

        private function loadBgmStages(stages:Vector.<Resource>):void
        {
            var j:int;
            var k:int;
            j = 0;
            k = 0;
            ResourceManager.DISABLE_MUSIC_AUTO_LOAD = true;
            ResourceManager.load({
                "oncomplete":function ():void
                {
                    var currStage:*;
                    var musicIDs:*;
                    ResourceManager.DISABLE_MUSIC_AUTO_LOAD = false;
                    writeLine("All stages have been loaded, checking for bgm id inconsistencies w/ mappings...");
                    j = 0;
                    while (j < stages.length)
                    {
                        currStage = stages[j];
                        musicIDs = ((currStage.getProp("music")) ? currStage.getProp("music") : []);
                        if (musicIDs.length <= 0)
                        {
                            writeLine((("Warning: No music tracks listed in stage '" + currStage.ID) + "'"));
                        }
                        else
                        {
                            k = 0;
                            while (k < musicIDs.length)
                            {
                                if ((!(ResourceManager.getResourceByID(musicIDs[k].id))))
                                {
                                    writeLine((((("Warning: Track '" + musicIDs[k].id) + "' for stage '") + currStage.ID) + "' was not found in mappings"));
                                };
                                k++;
                            };
                        };
                        j++;
                    };
                    writeLine("bgmcheck completed");
                },
                "onerror":function ():void
                {
                    ResourceManager.DISABLE_MUSIC_AUTO_LOAD = false;
                    writeLine("Error loading the following stages:");
                    j = 0;
                    while (j < stages.length)
                    {
                        if (stages[j].HasError)
                        {
                            writeLine(stages[j].CurrentFileName);
                        };
                        j++;
                    };
                }
            });
        }

        private function encryptText(s:String, k:String = "") : String
        {
            var c:String = null;
            var kc:String = null;
            var o:int = 0;
            var o2:int = 0;
            var s2:int = 0;
            var i:int = 0;
            var r:String = "";
            if(!s || !k)
            {
                return "";
            }
            while(i < s.length)
            {
                c = s.substr(i,1);
                kc = k.substr(i % k.length,1);
                o = c.charCodeAt(0);
                o2 = kc.charCodeAt(0);
                s2 = o + o2;
                c = String.fromCharCode(s2);
                r += c;
                i++;
            }
            return com.hurlant.util.Base64.encode(r);
        }
    }
}
