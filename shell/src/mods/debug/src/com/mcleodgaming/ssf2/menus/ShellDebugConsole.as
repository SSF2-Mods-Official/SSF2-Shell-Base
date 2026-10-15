// Decompiled by AS3 Sorcerer 6.78
// www.buraks.com/as3sorcerer

//com.mcleodgaming.ssf2.menus.DebugConsole

package com.mcleodgaming.ssf2.menus
{
    import com.mcleodgaming.ssf2.interfaces.IDebugConsole;
    import flash.text.TextField;
    import com.mcleodgaming.ssf2.util.ResourceManager;
    import com.mcleodgaming.ssf2.util.GameLog;
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

    public class ShellDebugConsole extends DebugConsole 
    {


        private static const MASK_COLOR:uint = 0x03FF68;
        private var MAX_HISTORY:int = 25;
        private var m_enabled:Boolean;
        private var m_input:TextField;
        private var m_output:TextField;
        private var m_history:Array;
        private var m_historyIndex:int;
        private var m_commands:Array;
        private var m_function:Function;
        private var m_enterReleased:Boolean;
        private var m_upReleased:Boolean;
        private var m_downReleased:Boolean;
        internal var m_controlsCapture:Boolean;
        internal var m_onlineCapture:Boolean;
        internal var m_pingCapture:Boolean;
        internal var m_attackStateCapture:Boolean;
        internal var m_disableKeyCapture:Boolean;
        internal var m_knockbackCapture:Boolean;
        internal var m_alerts:Boolean;

        public function ShellDebugConsole()
        {
            super();
            trace("[debug] console ctor");
            try
            {
                this.build();
            }
            catch (err:*)
            {
                m_subMenu = null;
                this.m_input = null;
                this.m_output = null;
                trace("[debug] console init failed: " + err);
                try
                {
                    GameLog.write("[debug] console init failed: " + err);
                }
                catch (logErr:*)
                {
                };
            };
        }

        /** MenuController.init creates this during boot; a throw here stops boot at 80%. */
        private function build():void
        {
            m_subMenu = ResourceManager.getLibraryMC("debug_console");
            if (!m_subMenu)
            {
                GameLog.write("[debug] console clip missing; console disabled");
                return;
            };
            GameLog.write("[debug] console ready debug=" + Main.DEBUG);
            this.m_input = m_subMenu.input;
            this.m_output = m_subMenu.output;
            this.m_output.text = "";
            this.m_historyIndex = 0;
            this.m_history = new Array("");
            this.registerCommands();
            m_container.addChild(m_subMenu);
            m_subMenu.x = (Main.Width / 2);
            m_subMenu.y = Main.Height;
            var outerMask:Shape = new Shape();
            outerMask.graphics.beginFill(MASK_COLOR);
            outerMask.graphics.drawRect(0,0,m_subMenu.width,m_subMenu.height);
            outerMask.graphics.endFill();
            outerMask.y = Main.Height - 140;
            m_container.addChild(outerMask);
            m_subMenu.mask = outerMask;
            this.m_enabled = false;
            this.m_enterReleased = true;
            this.m_upReleased = true;
            this.m_downReleased = true;
            this.m_alerts = false;
            this.m_controlsCapture = false;
            this.m_onlineCapture = false;
            this.m_pingCapture = false;
            this.m_disableKeyCapture = true;
            this.m_attackStateCapture = false;
            this.m_knockbackCapture = false;
            if (Main.DEBUG)
            {
                Main.Root.stage.addEventListener(KeyboardEvent.KEY_DOWN, this.toggleDebugConsole);
            };
        }

        private function registerCommands():void
        {
            var settings:DebugSettingsCommands = new DebugSettingsCommands(this);
            var match:DebugMatchCommands = new DebugMatchCommands(this);
            var hacks:DebugHackCommands = new DebugHackCommands(this);
            var tools:DebugToolCommands = new DebugToolCommands(this);
            this.m_commands = new Array();
            this.m_commands["clear"] = this.clear;
            this.m_commands["exit"] = this.exit;
            this.m_commands["close"] = this.exit;
            this.m_commands["alpha"] = this.alpha;
            this.m_commands["unfocus"] = this.unfocus;
            this.m_commands["capture"] = settings.capture;
            this.m_commands["print"] = match.print;
            this.m_commands["generate"] = match.generate;
            this.m_commands["debug"] = settings.debug;
            this.m_commands["config"] = settings.config;
            this.m_commands["hack"] = hacks.hack;
            this.m_commands["encrypt"] = tools.encrypt;
            this.m_commands["decrypt"] = tools.decrypt;
            this.m_commands["bgmcheck"] = tools.bgmcheck;
        }

        override public function get ControlsCapture():Boolean
        {
            return (this.m_controlsCapture);
        }

        override public function get DisableKeyCapture():Boolean
        {
            return (this.m_disableKeyCapture);
        }

        override public function get OnlineCapture():Boolean
        {
            return (this.m_onlineCapture);
        }

        override public function get PingCapture():Boolean
        {
            return (this.m_pingCapture);
        }

        override public function get AttackStateCapture():Boolean
        {
            return (this.m_attackStateCapture);
        }

        override public function get KnockbackCapture():Boolean
        {
            return (this.m_knockbackCapture);
        }

        override public function get Alerts():Boolean
        {
            return (this.m_alerts);
        }

        override public function set Alerts(value:Boolean):void
        {
            this.m_alerts = value;
        }

        override public function makeEvents():void
        {
            super.makeEvents();
            Main.Root.addEventListener(Event.ADDED, moveToFront);
            Main.Root.stage.addEventListener(KeyboardEvent.KEY_DOWN, this.submitCommand);
            Main.Root.stage.addEventListener(KeyboardEvent.KEY_UP, this.resetKeys);
        }

        override public function show():void
        {
            if (!m_subMenu)
            {
                return;
            };
            Main.setFocus(this.m_input);
            super.show();
            if (m_container.parent)
            {
                m_container.parent.setChildIndex(m_container, (m_container.parent.numChildren - 1));
            };
            if (this.m_disableKeyCapture)
            {
                Key.endCapture();
            };
            this.m_historyIndex = 0;
            this.clearInput();
        }

        override public function killEvents():void
        {
            super.killEvents();
            Main.Root.removeEventListener(Event.ADDED, moveToFront);
            Main.Root.stage.removeEventListener(KeyboardEvent.KEY_DOWN, this.submitCommand);
            Main.Root.stage.removeEventListener(KeyboardEvent.KEY_UP, this.resetKeys);
        }

        override public function removeSelf():void
        {
            super.removeSelf();
            this.m_enterReleased = true;
            this.m_upReleased = true;
            this.m_downReleased = true;
            m_subMenu.alpha = 1;
            Main.fixFocus();
            if (this.m_disableKeyCapture)
            {
                Key.beginCapture(Main.Root.stage);
            };
        }

        override public function forceShow():void
        {
            if ((!(this.m_enabled)))
            {
                this.show();
                this.m_enabled = true;
            };
        }

        private function toggleDebugConsole(e:KeyboardEvent):void
        {
            if ((!(Main.DEBUGAUTHED)))
            {
                return;
            };
            if (e.keyCode == 192)
            {
                if (this.m_enabled)
                {
                    this.removeSelf();
                    this.m_enabled = (!(this.m_enabled));
                }
                else
                {
                    if (Main.DEBUG)
                    {
                        this.show();
                        this.m_enabled = (!(this.m_enabled));
                    };
                };
            };
        }

        private function resetKeys(e:KeyboardEvent):void
        {
            if (((e.keyCode == 13) && (!(this.m_enterReleased))))
            {
                this.m_enterReleased = true;
            };
            if (((e.keyCode == 38) && (!(this.m_upReleased))))
            {
                this.m_upReleased = true;
            };
            if (((e.keyCode == 40) && (!(this.m_downReleased))))
            {
                this.m_downReleased = true;
            };
        }

        private function submitCommand(e:KeyboardEvent):void
        {
            var input:String;
            var argArray:Array;
            var funcName:String;
            if (((e.keyCode == 13) && (this.m_enterReleased)))
            {
                this.m_enterReleased = false;
                input = this.cleanString(this.m_input.text);
                if (input == "")
                {
                    this.writeLine("-No command entered");
                }
                else
                {
                    this.m_history[0] = input;
                    this.m_history.unshift("");
                    if (this.m_history.length > this.MAX_HISTORY)
                    {
                        this.m_history.pop();
                    };
                    argArray = input.split(" ");
                    funcName = argArray[0].toLowerCase();
                    argArray.splice(0, 1);
                    if (this.m_commands[funcName] != null)
                    {
                        this.runCommand(funcName, argArray);
                    }
                    else
                    {
                        this.writeLine((("Command '" + funcName) + "' not found"));
                    };
                };
                this.clearInput();
                this.m_historyIndex = 0;
            }
            else
            {
                if (((e.keyCode == 38) && (this.m_upReleased)))
                {
                    if (((this.m_history.length > 0) && (this.m_historyIndex < (this.m_history.length - 1))))
                    {
                        this.m_historyIndex++;
                        this.m_input.text = this.m_history[this.m_historyIndex];
                        this.cursorToEnd();
                    };
                }
                else
                {
                    if (((e.keyCode == 40) && (this.m_downReleased)))
                    {
                        if (((this.m_history.length > 0) && (this.m_historyIndex > 0)))
                        {
                            this.m_historyIndex--;
                            this.m_input.text = this.m_history[this.m_historyIndex];
                            this.cursorToEnd();
                        };
                    };
                };
            };
        }

        private function runCommand(funcName:String, argArray:Array):void
        {
            try
            {
                this.m_commands[funcName].apply(null, argArray);
            }
            catch (err:*)
            {
                trace("[debug] command " + funcName + " failed: " + err);
                try
                {
                    GameLog.write("[debug] command " + funcName + " failed: " + err);
                }
                catch (logErr:*)
                {
                };
            };
        }

        internal function writeLine(str:String):void
        {
            if (!this.m_output)
            {
                return;
            };
            this.m_output.appendText((str + "\n"));
            this.m_output.scrollV = this.m_output.numLines;
        }

        private function cleanString(str:String):String
        {
            while (str.indexOf("  ") >= 0)
            {
                str = str.replace("  ", " ");
            };
            while (str.indexOf("\n") >= 0)
            {
                str = str.replace("\n", "");
            };
            while (str.indexOf("\r") >= 0)
            {
                str = str.replace("\r", "");
            };
            str = StringUtil.trim(str);
            return (str);
        }

        private function cursorToEnd():void
        {
            this.m_input.setSelection(this.m_input.text.length, this.m_input.text.length);
        }

        private function clearInput():void
        {
            this.m_input.text = "";
        }

        private function exit(... args):void
        {
            this.removeSelf();
            this.m_enabled = false;
        }

        private function clear(... args):void
        {
            this.m_output.text = "";
        }

        /** Removes leading "-flag" args from args (in place) and returns them. */
        internal function parseFlags(args:Array):Array
        {
            var flags:Array = [];
            while (args.length > 0 && String(args[0]).charAt(0) == "-")
            {
                flags.push(args.shift());
            }
            return flags;
        }

        private function alpha(... args):void
        {
            var alpha:Number;
            var flags:Array = this.parseFlags(args);
            var error:String = "Error, alpha expects args [0-1.0]";
            if (args.length == 0)
            {
                this.writeLine(error);
            }
            else
            {
                if (isNaN(parseFloat(args[0])))
                {
                    this.writeLine(error);
                }
                else
                {
                    alpha = parseFloat(args[0]);
                    alpha = Math.min(alpha, 1);
                    alpha = Math.max(alpha, 0);
                    this.writeLine(("alpha set to " + alpha));
                    m_subMenu.alpha = alpha;
                };
            };
        }

        private function unfocus(... args):void
        {
            Main.fixFocus();
        }

        override public function alert(str:String):void
        {
            if (((Main.DEBUG) && (this.m_alerts)))
            {
                if ((!((GameController.currentGame) && (((GameController.currentGame.GameMode == Mode.ONLINE) || (GameController.currentGame.GameMode == Mode.ONLINE_ARENA)) || (GameController.currentGame.GameMode == Mode.ONLINE_WAITING_ROOM)))))
                {
                    this.forceShow();
                };
                this.writeLine(str);
            };
        }

        override public function writeEndAttackControls(str:String):void
        {
            if (this.m_controlsCapture)
            {
                this.writeLine(str);
            };
        }

        override public function writeTextData(str:String):void
        {
            this.writeLine(str);
        }

    }
}//package com.mcleodgaming.ssf2.menus

