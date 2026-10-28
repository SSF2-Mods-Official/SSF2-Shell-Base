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

    /** The hack console command, one method per subcommand. */
    public class DebugHackCommands extends DebugCommandSet
    {
        public function DebugHackCommands(console:ShellDebugConsole)
        {
            super(console);
        }

        public function hack(... args):void
        {
            var flags:Array = this.parseFlags(args);
            var error:String = "Error, hack expects args [fstimer | special | replay | unlocks | collisions | hud | bubble | camera | fsmeter]";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else if (/^fstimer$/i.test(args[0]))
            {
                this.hackFsTimer(args);
            }
            else if (/^special$/i.test(args[0]))
            {
                this.hackSpecial(args);
            }
            else if (/^replay$/i.test(args[0]))
            {
                this.hackReplay(args);
            }
            else if (/^unlocks$/i.test(args[0]))
            {
                this.hackUnlocks(args);
            }
            else if (/^hud$/i.test(args[0]))
            {
                this.hackHud(args);
            }
            else if (/^bubble$/i.test(args[0]))
            {
                this.hackBubble(args);
            }
            else if (/^camera$/i.test(args[0]))
            {
                this.hackCamera(args);
            }
            else if (/^fsmeter$/i.test(args[0]))
            {
                this.hackFsMeter(args);
            };
        }

        private function hackFsTimer(args:Array):void
        {
            var i:int;
            var success:Boolean;
            var character:Character;
            if (args.length <= 1)
            {
                this.writeLine("Error parsing hack fstimer value (Expects [##])");
            }
            else
            {
                if ((!(GameController.stageData)))
                {
                    this.writeLine("Error, match must be initialized to change hack fstimer value");
                }
                else
                {
                    if (((args.length <= 1) || (isNaN(parseInt(args[1])))))
                    {
                        this.writeLine("Error, invalid hack fstimer value provided (Expects [##])");
                    }
                    else
                    {
                        success = false;
                        args[1] = Math.max(0, parseInt(args[1]));
                        i = 0;
                        while (i < GameController.stageData.Players.length)
                        {
                            character = GameController.stageData.Players[i];
                            if (((character) && (character.TransformedSpecial)))
                            {
                                character.transformTimerExtend(args[1]);
                                success = true;
                            };
                            i = (i + 1);
                        };
                        this.writeLine(((success) ? (("Characters have been granted an additional " + args[1]) + " frame(s) of final form time") : "Error, no character is currently in final form"));
                    };
                };
            };
        }

        private function hackSpecial(args:Array):void
        {
            if (args.length <= 1)
            {
                this.writeLine("Error, hack special value (Expects [mini, mega, slow, lightning, vampire, vengeance, freeze, egg, dramatic, turbo, light, heavy, invisible, metal, ssf1])");
            }
            else
            {
                if (((args.length <= 2) || ((!(args[2] == "off")) && (!(args[2] == "on")))))
                {
                    this.writeLine((("Error reading command for hack special " + args[1]) + " (Expects [ on | off ]"));
                }
                else
                {
                    if ((!(GameController.currentGame)))
                    {
                        this.writeLine("Error, could not run hack special, no game setup has be initiated.");
                    }
                    else
                    {
                        switch (args[1])
                        {
                            case "mini":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.MINI, /^on$/i.test(args[2]));
                                break;
                            case "mega":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.MEGA, /^on$/i.test(args[2]));
                                break;
                            case "slow":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.SLOW, /^on$/i.test(args[2]));
                                break;
                            case "lightning":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.LIGHTNING, /^on$/i.test(args[2]));
                                break;
                            case "vampire":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.VAMPIRE, /^on$/i.test(args[2]));
                                break;
                            case "vengeance":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.VENGEANCE, /^on$/i.test(args[2]));
                                break;
                            case "freeze":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.FREEZE, /^on$/i.test(args[2]));
                                break;
                            case "egg":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.EGG, /^on$/i.test(args[2]));
                                break;
                            case "dramatic":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.DRAMATIC, /^on$/i.test(args[2]));
                                break;
                            case "turbo":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.TURBO, /^on$/i.test(args[2]));
                                break;
                            case "invisible":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.INVISIBLE, /^on$/i.test(args[2]));
                                break;
                            case "light":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.LIGHT, /^on$/i.test(args[2]));
                                break;
                            case "heavy":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.HEAVY, /^on$/i.test(args[2]));
                                break;
                            case "ssf1":
                                GameController.currentGame.LevelData.specialModes = SpecialMode.setModeEnabled(GameController.currentGame.LevelData.specialModes, SpecialMode.SSF1, /^on$/i.test(args[2]));
                                break;
                            default:
                                this.writeLine("Error parsing hack special flag (Expects [mini, mega, slow, lightning, vampire, vengeance, freeze, egg, dramatic, turbo, light, heavy, invisible, metal, ssf1]");
                                return;
                        };
                        this.writeLine((((("Hacked special flag " + args[1]) + ' to "') + args[2]) + '"'));
                    };
                };
            };
        }

        private function hackReplay(args:Array):void
        {
            var date:Date;
            var year:String;
            var month:String;
            var day:String;
            var replayData:ByteArray;
            var replayTimer:Timer;
            var replayFunc:Function;
            if (args.length <= 1)
            {
                this.writeLine("Error, hack replay value (Expects [save | load])");
            }
            else
            {
                if (/^save$/i.test(args[1]))
                {
                    if ((!(GameController.stageData)))
                    {
                        this.writeLine("Error, cannot save replay unless a match has been started.");
                    }
                    else
                    {
                        date = new Date();
                        year = ("" + date.getFullYear());
                        month = ((date.getMonth() < 9) ? ("0" + (date.getMonth() + 1)) : ("" + (date.getMonth() + 1)));
                        day = ((date.getDate() < 10) ? ("0" + date.getDate()) : ("" + date.getDate()));
                        replayData = new ByteArray();
                        replayData.writeUTF(GameController.stageData.ReplayDataObj.exportReplay());
                        replayData.compress();
                        Utils.saveFile(replayData, (((((((((GameController.stageData.ReplayDataObj.Name + ".") + year) + "-") + month) + "-") + day) + ".v") + Version.getVersion()) + ".ssfrec"));
                    };
                }
                else
                {
                    if (/^load$/i.test(args[1]))
                    {
                        if (((GameController.stageData) && (!(GameController.stageData.GameEnded))))
                        {
                            this.writeLine("Error, cannot load replay mid-match.");
                        }
                        else
                        {
                            this.writeLine("Choose a replay file load");
                            Utils.openFile("SSF2 Replay File (*.ssfrec)", "*.ssfrec");
                            replayTimer = new Timer(20);
                            replayFunc = function (e:TimerEvent):void
                            {
                                var loadedReplayFile:ByteArray;
                                var loadedReplayData:ReplayData;
                                var mode:uint;
                                if (Utils.finishedLoading)
                                {
                                    replayTimer.removeEventListener(TimerEvent.TIMER, replayFunc);
                                    replayTimer.stop();
                                    if (Utils.openSuccess)
                                    {
                                        loadedReplayFile = Utils.fileRef.data;
                                        loadedReplayFile.uncompress();
                                        loadedReplayData = new ReplayData(Main.MAXPLAYERS);
                                        loadedReplayData.importReplay(loadedReplayFile.readUTF());
                                        if (((!(loadedReplayData.VersionNumber == Version.getVersion())) && (ReplayData.COMPATIBLE_VERSIONS.indexOf(loadedReplayData.VersionNumber) < 0)))
                                        {
                                            writeLine((((("Error, incompatible version number. Received version\t" + loadedReplayData.VersionNumber) + " (Expecting ") + Version.getVersion()) + ")"));
                                        }
                                        else
                                        {
                                            writeLine(loadedReplayData.exportReplay());
                                            mode = loadedReplayData.GameMode;
                                            if (mode === Mode.ONLINE)
                                            {
                                                mode = Mode.VS;
                                            }
                                            else
                                            {
                                                if (mode === Mode.ONLINE_ARENA)
                                                {
                                                    mode = Mode.ARENA;
                                                };
                                            };
                                            GameController.currentGame = new Game(Main.MAXPLAYERS, mode);
                                            GameController.currentGame.ReplayDataObj = loadedReplayData;
                                            MenuController.removeAllMenus();
                                            MenuController.CurrentCharacterSelectMenu.initReplay();
                                        };
                                    }
                                    else
                                    {
                                        writeLine("Error, there was a problem loading the replay file");
                                    };
                                };
                            };
                            replayTimer.addEventListener(TimerEvent.TIMER, replayFunc);
                            replayTimer.start();
                        };
                    }
                    else
                    {
                        this.writeLine("Error, hack replay value (Expects [save | load])");
                    };
                };
            };
        }

        private function hackUnlocks(args:Array):void
        {
            var j:* = undefined;
            var events:Array;
            var i:int;
            if (args.length <= 1)
            {
                this.writeLine("Error, hack unlocks value (Expects [on | off | partial])");
            }
            else
            {
                if (/^on$/i.test(args[1]))
                {
                    for (j in SaveData.Unlocks)
                    {
                        if ((SaveData.Unlocks[j] is Boolean))
                        {
                            SaveData.Unlocks[j] = true;
                        };
                    };
                    SaveData.saveGame();
                    this.writeLine("All unlockables have been unlocked.");
                }
                else
                {
                    if (/^off$/i.test(args[1]))
                    {
                        for (j in SaveData.Unlocks)
                        {
                            if ((SaveData.Unlocks[j] is Boolean))
                            {
                                SaveData.Unlocks[j] = false;
                            };
                        };
                        SaveData.saveGame();
                        this.writeLine("All unlockables have been locked.");
                    }
                    else
                    {
                        if (/^partial$/i.test(args[1]))
                        {
                            for (j in SaveData.Unlocks)
                            {
                                if ((SaveData.Unlocks[j] is Boolean))
                                {
                                    SaveData.Unlocks[j] = false;
                                };
                            };
                            UnlockController.getUnlockableByID(Unlockable.THE_WORLD_THAT_NEVER_WAS).TriggerUnlock = true;
                            UnlockController.getUnlockableByID(Unlockable.SKY_PILLAR).TriggerUnlock = true;
                            UnlockController.getUnlockableByID(Unlockable.KRAZOA_PALACE).TriggerUnlock = true;
                            UnlockController.getUnlockableByID(Unlockable.URBAN_CHAMPION).TriggerUnlock = true;
                            SaveData.Records.vs.stages.konohavillage = 14;
                            SaveData.Records.classic.wins.naruto = {"score":123456};
                            SaveData.Records.vs.ffaMatchTotal = 14;
                            UnlockController.getUnlockableByID(Unlockable.WORLD_TOURNAMENT).TriggerUnlock = true;
                            SaveData.Unlocks.waterKOs = 19;
                            SaveData.Records.classic.wins.jigglypuff = {"score":123456};
                            SaveData.Unlocks.linkHyrule64Condition = true;
                            SaveData.Unlocks.zeldaHyrule64Condition = true;
                            SaveData.Unlocks.linkHyrule64Condition = true;
                            SaveData.Unlocks.zeldaHyrule64Condition = true;
                            SaveData.Unlocks.ghostNessSDs = 2;
                            UnlockController.getUnlockableByID(Unlockable.METAL_CAVERN).TriggerUnlock = true;
                            SaveData.Records.vs.matchTotal = 99;
                            SaveData.Records.vs.matches.sandbag = 0;
                            SaveData.Unlocks.eventAllStar01 = true;
                            SaveData.Unlocks.events11_20 = true;
                            SaveData.Unlocks.eventAllStar06 = true;
                            SaveData.Unlocks.events21_30 = true;
                            SaveData.Unlocks.eventAllStar07 = true;
                            SaveData.Unlocks.events31_33 = true;
                            SaveData.Unlocks.eventAllStar08 = true;
                            SaveData.Unlocks.events34_40 = true;
                            SaveData.Unlocks.eventAllStar09 = true;
                            SaveData.Unlocks.events41_46 = true;
                            SaveData.Unlocks.eventAllStarBeta = true;
                            SaveData.Unlocks.events47_51 = false;
                            SaveData.Unlocks.eventsARank = false;
                            SaveData.Unlocks.eventsSRank = false;
                            events = ResourceManager.getResourceByID("event_mode").getProp("eventList");
                            i = 0;
                            while (i < events.length)
                            {
                                SaveData.Records.events.wins[events[i].id] = {
                                    "rank":"S",
                                    "score":0,
                                    "scoreType":"time",
                                    "fps":30
                                };
                                i = (i + 1);
                            };
                            UnlockController.getUnlockableByID(Unlockable.ALTERNATE_TRACKS).TriggerUnlock = true;
                            SaveData.saveGame();
                            this.writeLine("All unlockable conditions have been partially satisfied.");
                        }
                        else
                        {
                            this.writeLine("Error, hack unlocks value (Expects [on | off | partial])");
                        };
                    };
                };
            };
        }

        private function hackHud(args:Array):void
        {
            if (args.length <= 1)
            {
                this.writeLine("Error, hack hud value (Expects [on | off])");
            }
            else
            {
                if (/^on$/i.test(args[1]))
                {
                    if (GameController.stageData)
                    {
                        GameController.stageData.HudRef.Container.alpha = 1;
                        GameController.stageData.FPSTimer.MC.visible = true;
                        GameController.constantDebugger.Container.visible = true;
                        this.writeLine("HUD enabled.");
                    }
                    else
                    {
                        this.writeLine("A game must be active to toggle hud.");
                    };
                }
                else
                {
                    if (/^off$/i.test(args[1]))
                    {
                        if (GameController.stageData)
                        {
                            GameController.stageData.HudRef.Container.alpha = 0;
                            GameController.stageData.FPSTimer.MC.visible = false;
                            GameController.constantDebugger.Container.visible = false;
                            this.writeLine("HUD disabled");
                        }
                        else
                        {
                            this.writeLine("A game must be active to toggle hud.");
                        };
                    }
                    else
                    {
                        this.writeLine("Error, hack hud value (Expects [on | off])");
                    };
                };
            };
        }

        private function hackBubble(args:Array):void
        {
            var i:int;
            if (args.length <= 1)
            {
                this.writeLine("Error, hack bubble value (Expects [on | off])");
            }
            else
            {
                if (/^on$/i.test(args[1]))
                {
                    DebugConsole.DISABLE_OFFSCREEN_BUBBLE = false;
                    if (GameController.stageData)
                    {
                        i = 0;
                        while (i < GameController.stageData.Characters.length)
                        {
                            GameController.stageData.Characters[i].OffScreenIndicatorEnabled = true;
                            i = (i + 1);
                        };
                        this.writeLine("Offscreen bubbles enabled.");
                    };
                }
                else
                {
                    if (/^off$/i.test(args[1]))
                    {
                        DebugConsole.DISABLE_OFFSCREEN_BUBBLE = true;
                        if (GameController.stageData)
                        {
                            i = 0;
                            while (i < GameController.stageData.Characters.length)
                            {
                                GameController.stageData.Characters[i].OffScreenIndicatorEnabled = false;
                                i = (i + 1);
                            };
                            this.writeLine("Offscreen bubbles disabled.");
                        };
                    }
                    else
                    {
                        this.writeLine("Error, hack bubble value (Expects [on | off])");
                    };
                };
            };
        }

        private function hackCamera(args:Array):void
        {
            if (args.length <= 1)
            {
                this.writeLine("Error, hack camera value (Expects [normal | stage | zoom | free | lock])");
            }
            else
            {
                if (/^normal$/i.test(args[1]))
                {
                    if (GameController.stageData)
                    {
                        GameController.stageData.CamRef.forceSetMode(Vcam.NORMAL_MODE);
                        this.writeLine("Camera set to normal mode.");
                    }
                    else
                    {
                        this.writeLine("A game must be active to toggle camera.");
                    };
                }
                else
                {
                    if (/^stage$/i.test(args[1]))
                    {
                        if (GameController.stageData)
                        {
                            GameController.stageData.CamRef.forceSetMode(Vcam.STAGE_MODE);
                            this.writeLine("Camera set to stage mode.");
                        }
                        else
                        {
                            this.writeLine("A game must be active to toggle camera.");
                        };
                    }
                    else
                    {
                        if (/^zoom$/i.test(args[1]))
                        {
                            if (GameController.stageData)
                            {
                                GameController.stageData.CamRef.forceSetMode(Vcam.ZOOM_MODE);
                                this.writeLine("Camera set to normal mode.");
                            }
                            else
                            {
                                this.writeLine("A game must be active to toggle camera.");
                            };
                        }
                        else
                        {
                            if (/^free$/i.test(args[1]))
                            {
                                if (GameController.stageData)
                                {
                                    GameController.stageData.CamRef.forceSetMode(Vcam.FREE_MODE);
                                    this.writeLine("Camera set to free mode.");
                                }
                                else
                                {
                                    this.writeLine("A game must be active to toggle camera.");
                                };
                            }
                            else
                            {
                                if (/^lock$/i.test(args[1]))
                                {
                                    if (GameController.stageData)
                                    {
                                        GameController.stageData.CamRef.forceSetMode(Vcam.LOCK_MODE);
                                        this.writeLine("Camera set to lock mode.");
                                    }
                                    else
                                    {
                                        this.writeLine("A game must be active to toggle camera.");
                                    };
                                }
                                else
                                {
                                    this.writeLine("Error, hack camera value (Expects [normal | stage | zoom | free | lock])");
                                };
                            };
                        };
                    };
                };
            };
        }

        private function hackFsMeter(args:Array):void
        {
            var chargeValue:Number;
            var i:int;
            var success:Boolean;
            var character:Character;
            if ((!(GameController.stageData)))
            {
                this.writeLine("Error, match must be initialized to change hack fsmeter value");
            }
            else
            {
                if (args.length >= 2)
                {
                    if ((!(/^\d++(\.\d++)?$/i.test(args[1]))))
                    {
                        this.writeLine("Error, hack fsmeter value (Expects a Number between 0.0 and 1.0)");
                    }
                    else
                    {
                        chargeValue = parseFloat(args[1]);
                        if (((chargeValue < 0) || (chargeValue > 1)))
                        {
                            this.writeLine("Error, hack fsmeter value (Expects a Number between 0.0 and 1.0)");
                        }
                        else
                        {
                            i = 0;
                            while (i < GameController.stageData.Players.length)
                            {
                                character = GameController.stageData.Players[i];
                                if ((!(character)))
                                {
                                }
                                else
                                {
                                    character.FinalSmashMeterCharge = chargeValue;
                                };
                                i = (i + 1);
                            };
                            this.writeLine((("Final smash meter charge has been set to " + chargeValue) + " on all player slots"));
                        };
                    };
                }
                else
                {
                    i = 0;
                    while (i < GameController.stageData.Players.length)
                    {
                        character = GameController.stageData.Players[i];
                        if ((!(character)))
                        {
                        }
                        else
                        {
                            character.updateCharacterStats({"finalSmashMeter":(!(character.CharacterStats.FinalSmashMeter))});
                            success = character.CharacterStats.FinalSmashMeter;
                        };
                        i = (i + 1);
                    };
                    this.writeLine(((success) ? "Final smash meter behavior has been enabled on all player slots" : "Final smash meter behavior has been disabled on all player slots"));
                };
            };
        }
    }
}
