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

    /** Batch/mappings text written by print -dat and print -datrenamer. */
    public class DebugDatScripts extends DebugCommandSet
    {
        public function DebugDatScripts(console:ShellDebugConsole)
        {
            super(console);
        }

        public function writeDatScript():void
        {
            var buffer:String;
            buffer = "";
            var bulkTrace:Function = function (str:String):void
            {
                buffer = (buffer + str);
                buffer = (buffer + "\n");
            };
            var names:Array = this.shuffledDatNames();
            this.traceMakeDat(bulkTrace, names);
            this.traceUnmakeDat(bulkTrace, names);
            this.traceDatMappings(bulkTrace, names);
            this.writeLine(buffer);
        }

        private function shuffledDatNames():Array
        {
            var first:int;
            var second:int;
            var tp:int;
            var b:int;
            var names:Array = new Array(ResourceManager.pool.length);
            b = 0;
            while (b < ResourceManager.pool.length)
            {
                names[b] = b;
                b = (b + 1);
            };
            b = 1000;
            while (b > 0)
            {
                b = (b - 1);
                first = Utils.randomInteger(0, (names.length - 1));
                second = Utils.randomInteger(0, (names.length - 1));
                tp = names[first];
                names[first] = names[second];
                names[second] = tp;
            };
            return names;
        }

        private function traceMakeDat(bulkTrace:Function, names:Array):void
        {
            var b:int;
            (bulkTrace(":: ------------- BEGIN make_dat_files.bat -------------"));
            b = 0;
            while (b < ResourceManager.pool.length)
            {
                if (ResourceManager.pool[b].ID === "targettest_sheik")
                {
                }
                else
                {
                    if (ResourceManager.pool[b].ID === "sheik")
                    {
                    }
                    else
                    {
                        if ((!(ResourceManager.pool[b].EncryptedFileName)))
                        {
                        }
                        else
                        {
                            if (ResourceManager.pool[b].Type == Resource.CHARACTER)
                            {
                                (bulkTrace((((("ren ..\\..\\build\\data\\character\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                            }
                            else
                            {
                                if (ResourceManager.pool[b].Type == Resource.STAGE)
                                {
                                    (bulkTrace((((("ren ..\\..\\build\\data\\stage\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                                }
                                else
                                {
                                    if (ResourceManager.pool[b].Type == Resource.MISC)
                                    {
                                        (bulkTrace((((("ren ..\\..\\build\\data\\misc\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                                    }
                                    else
                                    {
                                        if (ResourceManager.pool[b].Type == Resource.EXTRA)
                                        {
                                            (bulkTrace((((("ren ..\\..\\build\\data\\misc\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                                        }
                                        else
                                        {
                                            if (ResourceManager.pool[b].Type == Resource.MENU)
                                            {
                                                (bulkTrace((((("ren ..\\..\\build\\data\\menu\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                                            }
                                            else
                                            {
                                                if (ResourceManager.pool[b].Type == Resource.AUDIO)
                                                {
                                                    (bulkTrace((((("ren ..\\..\\build\\data\\sound\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                                                }
                                                else
                                                {
                                                    if (ResourceManager.pool[b].Type == Resource.MUSIC)
                                                    {
                                                        (bulkTrace((((("ren ..\\..\\build\\data\\sound\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                                                    }
                                                    else
                                                    {
                                                        if (ResourceManager.pool[b].Type == Resource.MODE)
                                                        {
                                                            (bulkTrace((((("ren ..\\..\\build\\data\\modes\\" + ResourceManager.pool[b].FileName) + " DAT") + names[b]) + ".ssf")));
                                                        };
                                                    };
                                                };
                                            };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
                b = (b + 1);
            };
            (bulkTrace("move ..\\..\\build\\data\\character\\DAT*.ssf ..\\..\\build\\data\\"));
            (bulkTrace("move ..\\..\\build\\data\\stage\\DAT*.ssf ..\\..\\build\\data\\"));
            (bulkTrace("move ..\\..\\build\\data\\misc\\DAT*.ssf ..\\..\\build\\data\\"));
            (bulkTrace("move ..\\..\\build\\data\\menu\\DAT*.ssf ..\\..\\build\\data\\"));
            (bulkTrace("move ..\\..\\build\\data\\sound\\DAT*.ssf ..\\..\\build\\data\\"));
            (bulkTrace("move ..\\..\\build\\data\\modes\\DAT*.ssf ..\\..\\build\\data\\"));
            (bulkTrace(":: ------------- END make_dat_files.bat -------------"));
            (bulkTrace("\n"));
        }

        private function traceUnmakeDat(bulkTrace:Function, names:Array):void
        {
            var b:int;
            (bulkTrace(":: ------------- BEGIN unmake_dat_files.bat -------------"));
            (bulkTrace("mkdir ..\\..\\build\\data\\character"));
            (bulkTrace("mkdir ..\\..\\build\\data\\stage"));
            (bulkTrace("mkdir ..\\..\\build\\data\\misc"));
            (bulkTrace("mkdir ..\\..\\build\\data\\menu"));
            (bulkTrace("mkdir ..\\..\\build\\data\\sound"));
            (bulkTrace("mkdir ..\\..\\build\\data\\modes"));
            b = 0;
            while (b < ResourceManager.pool.length)
            {
                if (ResourceManager.pool[b].ID === "targettest_sheik")
                {
                }
                else
                {
                    if (ResourceManager.pool[b].ID === "sheik")
                    {
                    }
                    else
                    {
                        if ((!(ResourceManager.pool[b].EncryptedFileName)))
                        {
                        }
                        else
                        {
                            if (ResourceManager.pool[b].Type == Resource.CHARACTER)
                            {
                                (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\character\\")));
                                (bulkTrace((((("ren ..\\..\\build\\data\\character\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                            }
                            else
                            {
                                if (ResourceManager.pool[b].Type == Resource.STAGE)
                                {
                                    (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\stage\\")));
                                    (bulkTrace((((("ren ..\\..\\build\\data\\stage\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                                }
                                else
                                {
                                    if (ResourceManager.pool[b].Type == Resource.MISC)
                                    {
                                        (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\misc\\")));
                                        (bulkTrace((((("ren ..\\..\\build\\data\\misc\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                                    }
                                    else
                                    {
                                        if (ResourceManager.pool[b].Type == Resource.EXTRA)
                                        {
                                            (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\misc\\")));
                                            (bulkTrace((((("ren ..\\..\\build\\data\\misc\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                                        }
                                        else
                                        {
                                            if (ResourceManager.pool[b].Type == Resource.MENU)
                                            {
                                                (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\menu\\")));
                                                (bulkTrace((((("ren ..\\..\\build\\data\\menu\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                                            }
                                            else
                                            {
                                                if (ResourceManager.pool[b].Type == Resource.AUDIO)
                                                {
                                                    (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\sound\\")));
                                                    (bulkTrace((((("ren ..\\..\\build\\data\\sound\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                                                }
                                                else
                                                {
                                                    if (ResourceManager.pool[b].Type == Resource.MUSIC)
                                                    {
                                                        (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\sound\\")));
                                                        (bulkTrace((((("ren ..\\..\\build\\data\\sound\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                                                    }
                                                    else
                                                    {
                                                        if (ResourceManager.pool[b].Type == Resource.MODE)
                                                        {
                                                            (bulkTrace(((("move ..\\..\\build\\data\\" + "DAT") + names[b]) + ".ssf ..\\..\\build\\data\\modes\\")));
                                                            (bulkTrace((((("ren ..\\..\\build\\data\\modes\\" + "DAT") + names[b]) + ".ssf ") + ResourceManager.pool[b].FileName)));
                                                        };
                                                    };
                                                };
                                            };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
                b = (b + 1);
            };
            (bulkTrace(":: ------------- END unmake_dat_files.bat -------------"));
            (bulkTrace("\n"));
        }

        private function traceDatMappings(bulkTrace:Function, names:Array):void
        {
            var b:int;
            (bulkTrace("// ------------- BEGIN mappings -------------"));
            (bulkTrace("// Note: This is only the data that is loaded on-demand (characters, stages, music, etc.). Don't overwrite entire mappings with this!"));
            var tempManifest:Object = Utils.cloneObject(ResourceManager.manifestJSONData);
            b = 0;
            while (b < ResourceManager.pool.length)
            {
                if ((!(ResourceManager.pool[b].EncryptedFileName)))
                {
                }
                else
                {
                    if (ResourceManager.pool[b].Type == Resource.CHARACTER)
                    {
                        tempManifest.character[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                    }
                    else
                    {
                        if (ResourceManager.pool[b].Type == Resource.STAGE)
                        {
                            tempManifest.stage[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                        }
                        else
                        {
                            if (ResourceManager.pool[b].Type == Resource.MISC)
                            {
                                tempManifest.misc[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                            }
                            else
                            {
                                if (ResourceManager.pool[b].Type == Resource.EXTRA)
                                {
                                    tempManifest.extra[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                                }
                                else
                                {
                                    if (ResourceManager.pool[b].Type == Resource.MENU)
                                    {
                                        tempManifest.menu[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                                    }
                                    else
                                    {
                                        if (ResourceManager.pool[b].Type == Resource.AUDIO)
                                        {
                                            tempManifest.audio[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                                        }
                                        else
                                        {
                                            if (ResourceManager.pool[b].Type == Resource.MUSIC)
                                            {
                                                tempManifest.music[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                                            }
                                            else
                                            {
                                                if (ResourceManager.pool[b].Type == Resource.MODE)
                                                {
                                                    tempManifest.modes[ResourceManager.pool[b].ID].file_pub = (("DAT" + names[b]) + ".ssf");
                                                };
                                            };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
                b = (b + 1);
            };
            var engineManifest:Object = {
                "modes":tempManifest.modes,
                "menu":tempManifest.menu,
                "misc":tempManifest.misc,
                "audio":tempManifest.audio
            };
            delete tempManifest.modes;
            delete tempManifest.menu;
            delete tempManifest.misc;
            delete tempManifest.audio;
            tempManifest.character.sheik.file_pub = tempManifest.character.zelda.file_pub;
            (bulkTrace(JSON.stringify(tempManifest, null, "  ")));
            (bulkTrace("// ------------- END mappings -------------"));
            (bulkTrace("\n"));
            (bulkTrace("// ------------- BEGIN manifest -------------"));
            (bulkTrace("// Note: This is in-engine only!"));
            (bulkTrace(JSON.stringify(engineManifest, null, "  ")));
            (bulkTrace("// ------------- END manifest -------------"));
        }

        public function writeDatRenamer():void
        {
            var buffer:String = "";
            var bulkTrace:Function = function (str:String):void
            {
                buffer += str + "\n";
            };

            var getObfuscatedName:Function = function(res:Object):String
            {
                var fileName:String = null;
                var entry:Object;

                switch (res.Type)
                {
                    case Resource.CHARACTER:
                        entry = ResourceManager.manifestJSONData.character[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                    case Resource.STAGE:
                        entry = ResourceManager.manifestJSONData.stage[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                    case Resource.MISC:
                        entry = ResourceManager.manifestJSONData.misc[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                    case Resource.EXTRA:
                        entry = ResourceManager.manifestJSONData.extra[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                    case Resource.MENU:
                        entry = ResourceManager.manifestJSONData.menu[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                    case Resource.AUDIO:
                        entry = ResourceManager.manifestJSONData.audio[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                    case Resource.MUSIC:
                        entry = ResourceManager.manifestJSONData.music[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                    case Resource.MODE:
                        entry = ResourceManager.manifestJSONData.modes[res.ID];
                        if (entry) fileName = entry.file_pub;
                        break;
                }

                return fileName;
            };

            bulkTrace(":: ------------- BEGIN make_dat_files.bat -------------");
            for each (var res:Object in ResourceManager.pool)
            {
                if (!res.EncryptedFileName || res.ID === "sheik" || res.ID === "targettest_sheik") continue;

                var obfuscated:String = getObfuscatedName(res);
                if (!obfuscated) continue;

                var subdir:String = "";
                switch (res.Type)
                {
                    case Resource.CHARACTER: subdir = "character"; break;
                    case Resource.STAGE:     subdir = "stage";     break;
                    case Resource.MISC:
                    case Resource.EXTRA:     subdir = "misc";      break;
                    case Resource.MENU:      subdir = "menu";      break;
                    case Resource.AUDIO:
                    case Resource.MUSIC:     subdir = "sound";     break;
                    case Resource.MODE:      subdir = "modes";     break;
                }

                bulkTrace("ren ..\\..\\build\\data\\" + subdir + "\\" + res.FileName + " " + obfuscated);
            }

            // Move all DAT*.ssf files to root data folder
            var allDirs:Array = ["character", "stage", "misc", "menu", "sound", "modes"];
            for each (var dir:String in allDirs)
            {
                bulkTrace("move ..\\..\\build\\data\\" + dir + "\\DAT*.ssf ..\\..\\build\\data\\");
            }
            bulkTrace(":: ------------- END make_dat_files.bat -------------\n");


            // Begin unmake
            bulkTrace(":: ------------- BEGIN unmake_dat_files.bat -------------");
            for each (dir in allDirs)
            {
                bulkTrace("mkdir ..\\..\\build\\data\\" + dir);
            }

            for each (res in ResourceManager.pool)
            {
                if (!res.EncryptedFileName || res.ID === "sheik" || res.ID === "targettest_sheik") continue;

                obfuscated = getObfuscatedName(res);
                if (!obfuscated) continue;

                subdir = "";
                switch (res.Type)
                {
                    case Resource.CHARACTER: subdir = "character"; break;
                    case Resource.STAGE:     subdir = "stage";     break;
                    case Resource.MISC:
                    case Resource.EXTRA:     subdir = "misc";      break;
                    case Resource.MENU:      subdir = "menu";      break;
                    case Resource.AUDIO:
                    case Resource.MUSIC:     subdir = "sound";     break;
                    case Resource.MODE:      subdir = "modes";     break;
                }

                bulkTrace("move ..\\..\\build\\data\\" + obfuscated + " ..\\..\\build\\data\\" + subdir + "\\");
                bulkTrace("ren ..\\..\\build\\data\\" + subdir + "\\" + obfuscated + " " + res.FileName);
            }

            bulkTrace(":: ------------- END unmake_dat_files.bat -------------");

            this.writeLine(buffer);
        }
    }
}
