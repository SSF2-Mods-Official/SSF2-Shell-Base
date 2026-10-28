package com.sbxmod.paletteMaker
{
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.utils.getTimer;
	import __AS3__.vec.Vector;

	/**
	 * Host-side stand-in for com.mcleodgaming.ssf2.menus.Menu.
	 * Palette Maker / Costume Selector compose against this instead of extending
	 * the engine Menu class (keeps asconfig src-only like other external mods).
	 */
	public class PaletteMenuBase
	{
		protected var m_container:MovieClip;
		protected var m_subMenu:MovieClip;
		protected var m_clickBlocker:MovieClip;
		protected var m_secondaryClickBlocker:MovieClip;
		protected var m_bgBlocker:MovieClip;
		protected var m_fillBackground:Boolean;
		protected var m_buttons:Vector.<MovieClip>;
		protected var m_showCount:int = 0;
		protected var m_aLetGo:Boolean;
		protected var m_bLetGo:Boolean;
		protected var m_startLetGo:Boolean;
		protected var m_backgroundContainer:MovieClip;
		protected var m_backgroundID:String;
		protected var m_hasEvents:Boolean;
		protected var m_disablePauseMapping:Boolean;
		/** Pause after the first step before a held direction repeats, then the gap between repeats. */
		private static const PAD_HOLD_DELAY:int = 200;
		private static const PAD_HOLD_REPEAT:int = 110;
		private var m_dirReady:Array;
		private var m_dirHoldAt:Array;
		private var m_dirNextAt:Array;

		public function PaletteMenuBase()
		{
			var Main:* = Ssf2.Main;
			m_container = new MovieClip();
			m_backgroundContainer = new MovieClip();
			m_subMenu = null;
			m_backgroundID = null;
			m_fillBackground = true;
			m_hasEvents = false;
			m_clickBlocker = new MovieClip();
			m_clickBlocker.graphics.beginFill(0, 0.5);
			m_clickBlocker.graphics.drawRect(-2, -2, Main.Width + 4, Main.Height + 4);
			m_clickBlocker.graphics.endFill();
			m_clickBlocker.buttonMode = true;
			m_clickBlocker.useHandCursor = false;
			m_secondaryClickBlocker = new MovieClip();
			m_secondaryClickBlocker.graphics.beginFill(0, 0.5);
			m_secondaryClickBlocker.graphics.drawRect(-2, -2, Main.Width + 4, Main.Height + 4);
			m_secondaryClickBlocker.graphics.endFill();
			m_secondaryClickBlocker.buttonMode = true;
			m_secondaryClickBlocker.useHandCursor = false;
			m_bgBlocker = new MovieClip();
			m_bgBlocker.graphics.beginFill(0, 0.3);
			m_bgBlocker.graphics.drawRect(-2, -2, Main.Width + 4, Main.Height + 4);
			m_bgBlocker.graphics.endFill();
			m_buttons = new Vector.<MovieClip>();
			m_aLetGo = false;
			m_bLetGo = false;
			m_startLetGo = false;
			m_disablePauseMapping = false;
			resetDirectionHold();
		}

		public function get Container():MovieClip
		{
			return m_container;
		}

		public function get SubMenu():MovieClip
		{
			return m_subMenu;
		}

		public function initMenuMappings():void
		{
		}

		public function makeEvents():void
		{
			if (m_showCount == 0)
			{
				findContainerButtons();
			};
			m_aLetGo = false;
			m_bLetGo = false;
			m_startLetGo = false;
			m_hasEvents = true;
			resetDirectionHold();
		}

		public function killEvents():void
		{
			m_hasEvents = false;
		}

		public function resetButtonFocus(mc:MovieClip):void
		{
			Ssf2.Utils.tryToGotoAndStop(mc, "_up");
		}

		public function setButtonFocus(mc:MovieClip):void
		{
			Ssf2.Utils.tryToGotoAndStop(mc, "_over");
		}

		/** Menu-mapper stub. PaletteMakerMenu fills this in for the gamepad. */
		public function manageMenuMappings(e:Event):void
		{
		}

		protected function pollPad(onUp:Function, onDown:Function, onLeft:Function, onRight:Function, onA:Function, onB:Function):void
		{
			var SaveData:* = Ssf2.SaveData;
			var i:int = 1;
			var found:Boolean = false;
			var pad:*;
			var heldUp:Boolean = false;
			var heldDown:Boolean = false;
			var heldLeft:Boolean = false;
			var heldRight:Boolean = false;
			if (!m_hasEvents || !SaveData || !SaveData.Controllers)
			{
				return;
			};
			if (!m_dirReady)
			{
				resetDirectionHold();
			};
			while (i <= SaveData.Controllers.length && m_hasEvents)
			{
				pad = SaveData.Controllers[i - 1];
				if (pad.IsDown(pad._BUTTON1))
				{
					if (m_bLetGo)
					{
						m_bLetGo = false;
						if (onB != null)
						{
							onB();
						};
					};
					found = true;
				};
				if (pad.IsDown(pad._BUTTON2))
				{
					if (m_aLetGo)
					{
						m_aLetGo = false;
						if (onA != null)
						{
							onA();
						};
					};
					found = true;
				}
				else if (pad.IsDown(pad._START) && !m_disablePauseMapping)
				{
					if (m_startLetGo)
					{
						m_startLetGo = false;
						if (onA != null)
						{
							onA();
						};
					};
					found = true;
				};
				if (pad.IsDown(pad._UP))
				{
					heldUp = true;
				};
				if (pad.IsDown(pad._DOWN))
				{
					heldDown = true;
				};
				if (pad.IsDown(pad._LEFT))
				{
					heldLeft = true;
				};
				if (pad.IsDown(pad._RIGHT))
				{
					heldRight = true;
				};
				i++;
			};
			if (heldUp || heldDown || heldLeft || heldRight)
			{
				found = true;
			};
			if (m_hasEvents)
			{
				pollHeldDirection(0, heldUp, onUp);
				pollHeldDirection(1, heldDown, onDown);
				pollHeldDirection(2, heldLeft, onLeft);
				pollHeldDirection(3, heldRight, onRight);
			};
			if (!found)
			{
				m_aLetGo = true;
				m_bLetGo = true;
				m_startLetGo = true;
			};
		}

		private function resetDirectionHold():void
		{
			m_dirReady = [false, false, false, false];
			m_dirHoldAt = [0, 0, 0, 0];
			m_dirNextAt = [0, 0, 0, 0];
		}

		/** First press steps once. A hold waits, then keeps stepping until that direction is released. */
		private function pollHeldDirection(index:int, down:Boolean, onMove:Function):void
		{
			var now:int;
			if (!down)
			{
				m_dirReady[index] = true;
				m_dirHoldAt[index] = 0;
				return;
			};
			if (!m_dirReady[index])
			{
				return;
			};
			now = getTimer();
			if (int(m_dirHoldAt[index]) == 0)
			{
				m_dirHoldAt[index] = now;
				m_dirNextAt[index] = now + PAD_HOLD_DELAY;
				if (onMove != null)
				{
					onMove();
				};
				return;
			};
			if (now >= int(m_dirNextAt[index]))
			{
				m_dirNextAt[index] = now + PAD_HOLD_REPEAT;
				if (onMove != null)
				{
					onMove();
				};
			};
		}

		public function findContainerButtons():void
		{
			var i:int = 0;
			while (i < m_container.numChildren)
			{
				if (m_container.getChildAt(i) is MovieClip && Boolean(MovieClip(m_container.getChildAt(i)).buttonMode))
				{
					m_buttons.push(MovieClip(m_container.getChildAt(i) as MovieClip));
				};
				i++;
			};
		}

		public function findSubMenuButtons():void
		{
			var i:int = 0;
			if (m_subMenu == null)
			{
				return;
			};
			i = 0;
			while (i < m_subMenu.numChildren)
			{
				if (m_subMenu.getChildAt(i) is MovieClip && Boolean(MovieClip(m_subMenu.getChildAt(i)).buttonMode))
				{
					m_buttons.push(MovieClip(m_subMenu.getChildAt(i) as MovieClip));
				};
				i++;
			};
		}

		public function findSpecificMenuButtons(mc:MovieClip):void
		{
			var i:int = 0;
			if (mc == null)
			{
				return;
			};
			i = 0;
			while (i < mc.numChildren)
			{
				if (mc.getChildAt(i) is MovieClip && Boolean(MovieClip(mc.getChildAt(i)).buttonMode))
				{
					m_buttons.push(MovieClip(mc.getChildAt(i) as MovieClip));
				};
				i++;
			};
		}

		public function resetAllButtons():void
		{
			var i:int = 0;
			while (i < m_buttons.length)
			{
				resetButtonFocus(m_buttons[i]);
				i++;
			};
		}

		public function isOnscreen():Boolean
		{
			return m_container.stage != null;
		}

		protected function updateMenuBackground():void
		{
			var Main:* = Ssf2.Main;
			var Utils:* = Ssf2.Utils;
			var SaveData:* = Ssf2.SaveData;
			var ModHost:* = Ssf2.ModHost;
			var ModPatches:* = Ssf2.ModPatches;
			var ResourceManager:* = Ssf2.ResourceManager;
			var self:* = this;
			if (Boolean(m_subMenu))
			{
				m_subMenu.addChildAt(m_backgroundContainer, 0);
				if (!SaveData.Quality.menu_bg)
				{
					Utils.recursiveMovieClipPlay(m_backgroundContainer, false, false);
					m_backgroundContainer.visible = false;
				}
				else
				{
					Utils.recursiveMovieClipPlay(m_backgroundContainer, true, true);
					m_backgroundContainer.visible = true;
				};
				if (m_fillBackground)
				{
					m_subMenu.graphics.beginFill(0);
					m_subMenu.graphics.drawRect(-2 - Main.Width / 2, -2 - Main.Height / 2, Main.Width + 4, Main.Height + 4);
					m_subMenu.graphics.endFill();
				};
			};
			if (Boolean(m_backgroundID))
			{
				ModHost.applyPatch(ModPatches.APPLY_MENU_BACKGROUND, [self, m_backgroundID, m_backgroundContainer], function(menu:*, id:*, container:*):void
				{
					container.addChild(ResourceManager.getLibraryMC("menu_bg_" + id));
				});
				m_backgroundID = null;
			};
		}

		public function show():void
		{
			var Main:* = Ssf2.Main;
			var ModHost:* = Ssf2.ModHost;
			var ModHooks:* = Ssf2.ModHooks;
			updateMenuBackground();
			Main.Root.addChild(m_container);
			makeEvents();
			++m_showCount;
			Main.fixFocus();
			ModHost.runHook(ModHooks.MENU_SHOW, {
				"menu": this,
				"cancel": false
			});
			ModHost.runHook(ModHooks.MENU_NAVIGATE, {
				"menu": this,
				"action": "show"
			});
		}

		public function removeSelf():void
		{
			var Main:* = Ssf2.Main;
			var ModHost:* = Ssf2.ModHost;
			var ModHooks:* = Ssf2.ModHooks;
			if (Boolean(m_container.parent))
			{
				resetAllButtons();
				killEvents();
				m_container.parent.removeChild(m_container);
			};
			Main.fixFocus();
			ModHost.runHook(ModHooks.MENU_HIDE, {
				"menu": this,
				"cancel": false
			});
		}

		public function addClickBlocker():void
		{
			m_container.addChild(m_clickBlocker);
		}

		public function removeClickBlocker():void
		{
			if (Boolean(m_clickBlocker.parent))
			{
				m_clickBlocker.parent.removeChild(m_clickBlocker);
			};
		}

		public function addBGBlocker():void
		{
			m_container.addChild(m_bgBlocker);
		}

		public function removeBGBlocker():void
		{
			if (Boolean(m_bgBlocker.parent))
			{
				m_bgBlocker.parent.removeChild(m_bgBlocker);
			};
		}

		public function addSecondaryClickBlocker():void
		{
			m_container.addChild(m_secondaryClickBlocker);
		}

		public function removeSecondaryClickBlocker():void
		{
			if (Boolean(m_secondaryClickBlocker.parent))
			{
				m_secondaryClickBlocker.parent.removeChild(m_secondaryClickBlocker);
			};
		}
	}
}
