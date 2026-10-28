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

    /** Console commands that act on the running match: generate, print. */
    public class DebugMatchCommands extends DebugCommandSet
    {
        private var m_dat:DebugDatScripts;

        public function DebugMatchCommands(console:ShellDebugConsole)
        {
            super(console);
            this.m_dat = new DebugDatScripts(console);
        }

        public function generate(... args):void
        {
            var itemData:ItemData;
            var index:int;
            var item:Item;
            var flags:Array = this.parseFlags(args);
            var error:String = "Error, generate expects args [assist | item | pokemon]";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else
            {
                if (((!(GameController.stageData)) || (GameController.stageData.GameEnded)))
                {
                    this.writeLine("Error, no game detected for generate command");
                }
                else
                {
                    if (/^assist$/i.test(args[0]))
                    {
                        if (((args.length <= 1) || (isNaN(parseInt(args[1])))))
                        {
                            this.writeLine("Error parsing assist ID ##");
                        }
                        else
                        {
                            args[1] = Math.max(0, parseInt(args[1]));
                            item = GameController.stageData.ItemsRef.generateItemObj(GameController.stageData.ItemsRef.getItemByLinkage("assistTrophy"));
                            if (item)
                            {
                                if (flags.indexOf("-rare") >= 0)
                                {
                                    GameController.stageData.ItemsRef.AssistClass = GameController.stageData.AssistsRare[Math.min((GameController.stageData.AssistsRare.length - 1), args[1])];
                                }
                                else
                                {
                                    GameController.stageData.ItemsRef.AssistClass = GameController.stageData.Assists[Math.min((GameController.stageData.Assists.length - 1), args[1])];
                                };
                                if (GameController.stageData.getPlayerByID(1))
                                {
                                    item.X = (GameController.stageData.getPlayerByID(1).X + ((GameController.stageData.getPlayerByID(1).FacingForward) ? 8 : -8));
                                    item.Y = (GameController.stageData.getPlayerByID(1).Y - GameController.stageData.getPlayerByID(1).Height);
                                };
                                this.writeLine((((((("Generated assist ID#" + args[1]) + " @ (x:") + item.X) + ", y:") + item.Y) + ")"));
                            }
                            else
                            {
                                this.writeLine(("Error, failed to assist ID#" + args[1]));
                            };
                        };
                    }
                    else
                    {
                        if (/^item$/i.test(args[0]))
                        {
                            if (((args.length <= 1) || (isNaN(parseInt(args[1])))))
                            {
                                this.writeLine("Error parsing item ID ##");
                            }
                            else
                            {
                                args[1] = Math.max(0, parseInt(args[1]));
                                itemData = new ItemData();
                                itemData.importData(ItemsListData.DATA[Math.min((ItemsListData.DATA.length - 1), args[1])]);
                                item = GameController.stageData.ItemsRef.generateItemObj(itemData);
                                if (item)
                                {
                                    if (GameController.stageData.getPlayerByID(1))
                                    {
                                        item.X = (GameController.stageData.getPlayerByID(1).X + ((GameController.stageData.getPlayerByID(1).FacingForward) ? 8 : -8));
                                        item.Y = (GameController.stageData.getPlayerByID(1).Y - GameController.stageData.getPlayerByID(1).Height);
                                    };
                                    this.writeLine((((((("Generated item ID#" + args[1]) + " @ (x:") + item.X) + ", y:") + item.Y) + ")"));
                                }
                                else
                                {
                                    this.writeLine(("Error, failed to item ID#" + args[1]));
                                };
                            };
                        }
                        else
                        {
                            if (/^pokemon$/i.test(args[0]))
                            {
                                if (((args.length <= 1) || (isNaN(parseInt(args[1])))))
                                {
                                    this.writeLine("Error parsing pokemon ID ##");
                                }
                                else
                                {
                                    args[1] = Math.max(0, parseInt(args[1]));
                                    item = GameController.stageData.ItemsRef.generateItemObj(GameController.stageData.ItemsRef.getItemByLinkage(((flags.indexOf("-rare") >= 0) ? "masterball" : "pokeball")));
                                    if (item)
                                    {
                                        if (flags.indexOf("-rare") >= 0)
                                        {
                                            GameController.stageData.ItemsRef.PokemonClass = GameController.stageData.PokemonsRare[Math.min((GameController.stageData.PokemonsRare.length - 1), args[1])];
                                        }
                                        else
                                        {
                                            GameController.stageData.ItemsRef.PokemonClass = GameController.stageData.Pokemons[Math.min((GameController.stageData.Pokemons.length - 1), args[1])];
                                        };
                                        if (GameController.stageData.getPlayerByID(1))
                                        {
                                            item.X = (GameController.stageData.getPlayerByID(1).X + ((GameController.stageData.getPlayerByID(1).FacingForward) ? 8 : -8));
                                            item.Y = (GameController.stageData.getPlayerByID(1).Y - GameController.stageData.getPlayerByID(1).Height);
                                        };
                                        this.writeLine((((((("Generated pokemon ID#" + args[1]) + " @ (x:") + item.X) + ", y:") + item.Y) + ")"));
                                    }
                                    else
                                    {
                                        this.writeLine(("Error, failed to pokemon ID#" + args[1]));
                                    };
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
        }

        public function print(... args):void
        {
            var itemIndex:int;
            var itemName:String;
            var eventCounts:Array;
            var eventTotals:int;
            var i:int;
            var flags:Array = this.parseFlags(args);
            var error:String = "Error, print expects flags [-assist | -item | -online | -pokemon | -version | -ping | -dat | -events]";
            if (flags.length == 0)
            {
                this.writeLine(error);
            }
            else
            {
                if (flags[0] == "-assist")
                {
                    this.writeLine("[See assist Main.as]");
                };
                if (flags[0] == "-item")
                {
                    this.writeLine("[Items]");
                    itemIndex = 0;
                    while (itemIndex < ItemsListData.DATA.length)
                    {
                        itemName = ItemsListData.DATA[itemIndex].displayName;
                        this.writeLine(((itemIndex + " - ") + itemName));
                        itemIndex++;
                    };
                };
                if (flags.indexOf("-online") >= 0)
                {
                    if ((!(GameController.stageData)))
                    {
                        this.writeLine("Error, no match detected");
                    }
                    else
                    {
                        if ((!(GameController.stageData.LogText)))
                        {
                            this.writeLine("Log data is empty. Must enable capture via 'capture online' command and start a match.");
                        }
                        else
                        {
                            this.writeLine("[BEGIN LOG]");
                            this.writeLine(GameController.stageData.LogText);
                            this.writeLine("[END LOG]");
                        };
                    };
                };
                if (flags.indexOf("-pokemon") >= 0)
                {
                    this.writeLine("[See pokemon Main.as");
                };
                if (flags.indexOf("-version") >= 0)
                {
                    this.writeLine(((((((("SSF2 Version: " + Version.Major) + ".") + Version.Minor) + ".") + Version.Build) + ".") + Version.Revision));
                    this.writeLine(("ActionScript Version: " + Main.Root.loaderInfo.actionScriptVersion));
                    this.writeLine(("SWF Version: " + Main.Root.loaderInfo.swfVersion));
                };
                if (flags.indexOf("-ping") >= 0)
                {
                    this.writeLine((("Current Average Ping: " + MultiplayerManager.Ping) + " ms"));
                };
                if (flags.indexOf("-dat") >= 0)
                {
                    this.m_dat.writeDatScript();
                };
                if (flags.indexOf("-datrenamer") >= 0)
                {
                    this.m_dat.writeDatRenamer();
                };
                if (flags[0] == "-events")
                {
                    if (GameController.stageData)
                    {
                        eventCounts = [];
                        eventTotals = 0;
                        i = 0;
                        while (i < GameController.stageData.Players.length)
                        {
                            if (GameController.stageData.Players[i] != null)
                            {
                                eventCounts.push(((("P" + GameController.stageData.Players[i].ID) + ": ") + GameController.stageData.Players[i].EventManagerObj.Count));
                                eventTotals = (eventTotals + GameController.stageData.Players[i].EventManagerObj.Count);
                            };
                            i++;
                        };
                        this.writeLine((((("Player events: " + eventTotals) + " (") + eventCounts.join(", ")) + ")"));
                        eventTotals = 0;
                        i = 0;
                        while (i < GameController.stageData.Projectiles.length)
                        {
                            eventTotals = (eventTotals + GameController.stageData.Projectiles[i].EventManagerObj.Count);
                            i++;
                        };
                        this.writeLine(("Projectile events: " + eventTotals));
                        eventTotals = 0;
                        i = 0;
                        while (i < GameController.stageData.Enemies.length)
                        {
                            eventTotals = (eventTotals + GameController.stageData.Enemies[i].EventManagerObj.Count);
                            i++;
                        };
                        this.writeLine(("Enemy events: " + eventTotals));
                        eventTotals = 0;
                        i = 0;
                        while (i < GameController.stageData.ItemsRef.ItemsInUse.length)
                        {
                            if (GameController.stageData.ItemsRef.ItemsInUse[i])
                            {
                                eventTotals = (eventTotals + GameController.stageData.ItemsRef.ItemsInUse[i].EventManagerObj.Count);
                            };
                            i++;
                        };
                        this.writeLine(("Item events: " + eventTotals));
                        this.writeLine(("Match events: " + GameController.stageData.EventManagerObj.Count));
                    }
                    else
                    {
                        this.writeLine("Cannot print events, no game is active");
                    };
                };
            };
        }
    }
}
