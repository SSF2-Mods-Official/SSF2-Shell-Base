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

    /** Console commands that change console and match settings: capture, debug, config. */
    public class DebugSettingsCommands extends DebugCommandSet
    {
        public function DebugSettingsCommands(console:ShellDebugConsole)
        {
            super(console);
        }

        public function capture(... args):void
        {
            var flags:Array = this.parseFlags(args);
            var error:String = "Error, capture expects args [controls | keyboard | online | attack | ping]";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else
            {
                if (/^controls$/i.test(args[0]))
                {
                    if (this.c.m_controlsCapture)
                    {
                        this.c.m_controlsCapture = false;
                        this.writeLine("controls capture stopped");
                    }
                    else
                    {
                        if (((GameController.stageData) && (GameController.stageData.getPlayerByID(1))))
                        {
                            GameController.stageData.getPlayerByID(1).clearAttackControlsArr();
                        };
                        this.c.m_controlsCapture = true;
                        this.writeLine("controls capture started for player 1");
                    };
                }
                else
                {
                    if (/^online$/i.test(args[0]))
                    {
                        if (this.c.m_onlineCapture)
                        {
                            this.c.m_onlineCapture = false;
                            this.writeLine("online capture stopped");
                        }
                        else
                        {
                            this.c.m_onlineCapture = true;
                            this.writeLine("online capture started");
                        };
                    }
                    else
                    {
                        if (/^ping$/i.test(args[0]))
                        {
                            if (this.c.m_pingCapture)
                            {
                                this.c.m_pingCapture = false;
                                this.writeLine("ping capture stopped");
                            }
                            else
                            {
                                this.c.m_pingCapture = true;
                                this.writeLine("ping capture started");
                            };
                        }
                        else
                        {
                            if (/^keyboard$/i.test(args[0]))
                            {
                                this.c.m_disableKeyCapture = Key.CaptureStarted;
                                if (this.c.m_disableKeyCapture)
                                {
                                    this.writeLine("key capture blocked.");
                                    Key.endCapture();
                                }
                                else
                                {
                                    this.writeLine("key capture unblocked.");
                                    Key.beginCapture(Main.Root.stage);
                                };
                            }
                            else
                            {
                                if (/^attack$/i.test(args[0]))
                                {
                                    this.c.m_attackStateCapture = (!(this.c.m_attackStateCapture));
                                    if (this.c.m_attackStateCapture)
                                    {
                                        this.writeLine("attack capture started");
                                    }
                                    else
                                    {
                                        this.writeLine("attack capture ended");
                                    };
                                }
                                else
                                {
                                    if (/^knockback$/i.test(args[0]))
                                    {
                                        this.c.m_knockbackCapture = (!(this.c.m_knockbackCapture));
                                        if (this.c.m_knockbackCapture)
                                        {
                                            this.writeLine("knockback capture started");
                                        }
                                        else
                                        {
                                            this.writeLine("knockback capture ended");
                                        };
                                    }
                                    else
                                    {
                                        this.writeLine(error);
                                    };
                                };
                            };
                        };
                    };
                };
            };
        }

        public function debug(... args):void
        {
            var flags:Array = this.parseFlags(args);
            var error:String = "Error, debug expects args [off]";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else
            {
                if (/^off$/i.test(args[0]))
                {
                    this.writeLine("Debug mode has been disabled.");
                    Main.turnOffDebug();
                }
                else
                {
                    this.writeLine(error);
                };
            };
        }

        public function config(... args):void
        {
            var flags:Array = this.parseFlags(args);
            var error:String = "Error, config expects args [alerts | fps | airDodge | global | flushcache]";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else if (/^airDodge$/i.test(args[0]))
            {
                this.configAirDodge(args);
            }
            else if (/^fps$/i.test(args[0]))
            {
                this.configFps(args);
            }
            else if (/^alerts$/i.test(args[0]))
            {
                this.configAlerts(args);
            }
            else if (/^global$/i.test(args[0]))
            {
                this.configGlobal(args);
            }
            else if (/^flushcache$/i.test(args[0]))
            {
                this.configFlushCache(args);
            }
            else
            {
                this.writeLine(error);
            };
        }

        private function configAirDodge(args:Array):void
        {
            if (args.length <= 1)
            {
                this.writeLine("Error parsing config airDodge value (Expects [brawl | melee | ultimate | solo | double | vsolo | vdouble ])");
            }
            else
            {
                if ((!(GameController.stageData)))
                {
                    this.writeLine("Error, match must be initialized to change config airDodge value");
                }
                else
                {
                    if (/^brawl$/i.test(args[1]))
                    {
                        GameController.stageData.AirDodge = "brawl";
                        this.writeLine("Brawl air dodging has been enabled");
                    }
                    else
                    {
                        if (/^melee$/i.test(args[1]))
                        {
                            GameController.stageData.AirDodge = "melee";
                            this.writeLine("Melee air dodging has been enabled");
                        }
                        else
                        {
                            if (/^ultimate$/i.test(args[1]))
                            {
                                GameController.stageData.AirDodge = "ultimate";
                                this.writeLine("Ultimate air dodging has been enabled");
                            }
                            else
                            {
                                if (/^solo$/i.test(args[1]))
                                {
                                    GameController.stageData.AirDodge = "solo";
                                    this.writeLine("Ultimate air dodging + Solo Wavedash has been enabled");
                                }
                                else
                                {
                                    if (/^double$/i.test(args[1]))
                                    {
                                        GameController.stageData.AirDodge = "double";
                                        this.writeLine("Ultimate air dodging + Double Wavedash has been enabled");
                                    }
                                    else
                                    {
                                        if (/^vsolo$/i.test(args[1]))
                                        {
                                            GameController.stageData.AirDodge = "vsolo";
                                            this.writeLine("Ultimate air dodging + Variable Solo Wavedash has been enabled");
                                        }
                                        else
                                        {
                                            if (/^vdouble$/i.test(args[1]))
                                            {
                                                GameController.stageData.AirDodge = "vdouble";
                                                this.writeLine("Ultimate air dodging + Variable Double Wavedash has been enabled");
                                            }
                                            else
                                            {
                                                this.writeLine("Error, invalid config airDodge value provided (Expects [brawl | melee | ultimate | solo | double | vsolo | vdouble])");
                                            };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        }

        private function configFps(args:Array):void
        {
            if (args.length <= 1)
            {
                this.writeLine("Error parsing config fps value (Expects [1-120])");
            }
            else
            {
                if (((args.length <= 1) || (isNaN(parseInt(args[1])))))
                {
                    this.writeLine("Error, invalid config fps value provided (Expects [1-120])");
                }
                else
                {
                    args[1] = Math.max(0, parseInt(args[1]));
                    if (((args[1] < 1) || (args[1] > 120)))
                    {
                        this.writeLine("Error, invalid config fps value provided (Expects [1-120])");
                    }
                    else
                    {
                        this.writeLine(("Game FPS has been set to " + args[1]));
                        Main.Root.stage.frameRate = args[1];
                    };
                };
            };
        }

        private function configAlerts(args:Array):void
        {
            if (args.length <= 1)
            {
                this.writeLine("Error parsing config alerts value (Expects [true | false])");
            }
            else
            {
                if (/^true$/i.test(args[1]))
                {
                    this.c.m_alerts = true;
                    this.writeLine("Alerts have been enabled");
                }
                else
                {
                    if (/^false$/i.test(args[1]))
                    {
                        this.c.m_alerts = false;
                        this.writeLine("Alerts have been disabled");
                    }
                    else
                    {
                        this.writeLine("Error, invalid config alerts value provided (Expects [true | false])");
                    };
                };
            };
        }

        private function configGlobal(args:Array):void
        {
            if (args.length <= 1)
            {
                this.writeLine("Error parsing config global var name (Expects {varname}))");
            }
            else
            {
                if (args.length <= 2)
                {
                    this.writeLine(((("Retrieved config global var: " + args[1]) + " = ") + DebugConsole.globalHash[args[1]]));
                }
                else
                {
                    if (((/^true$/i.test(args[2])) || (/^false$/i.test(args[2]))))
                    {
                        DebugConsole.globalHash[args[1]] = /^true$/i.test(args[2]);
                    }
                    else
                    {
                        if ((!(isNaN(parseFloat(args[2])))))
                        {
                            DebugConsole.globalHash[args[1]] = ((parseFloat(args[2]) === parseInt(args[2])) ? parseFloat(args[2]) : parseInt(args[2]));
                        }
                        else
                        {
                            DebugConsole.globalHash[args[1]] = ((args[2].match(/^"(.*?)"$/)) ? args[2].replace(/^"(.*?)"$/, "$1") : args[2]);
                        };
                    };
                    this.writeLine(((("Assigned config global var: " + args[1]) + " = ") + DebugConsole.globalHash[args[1]]));
                };
            };
        }

        private function configFlushCache(args:Array):void
        {
            ResourceManager.flushUnusedResources();
            HitBoxManager.clearCache();
            this.writeLine("All resources that are not required and not currently in the loading queue have been unloaded, and hitbox cache has been cleared. Garbage collection has been requested.");
            System.gc();
        }
    }
}
