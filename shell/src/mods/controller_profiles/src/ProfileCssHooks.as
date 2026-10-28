package
{
	import ssf2mm.shared.EngineRefs;
	import flash.events.MouseEvent;

	/**
	 * Character Select hooks: edit-button / pencil hit tests and nameDisplay lookup.
	 */
	public class ProfileCssHooks
	{
		internal var mod:ControllerProfilesMod;
		private var m_pencilDown:Boolean = false;

		public function ProfileCssHooks(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		/** Safe probe — sealed Menu subclasses throw #1069 on missing bracket props. */
		internal static function menuHasCharBoxes(menu:*):Boolean
		{
			try
			{
				return (menu != null && menu["CharSelectionBoxes"] != null);
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal static function charBoxCount(menu:*):int
		{
			try
			{
				var boxes:* = menu["CharSelectionBoxes"];
				return (boxes ? int(boxes["length"]) : 0);
			}
			catch (err:*)
			{
			};
			return (0);
		}

		internal function hookEditButtons(menu:*):void
		{
			var pid:int;
			var btn:*;
			pid = 1;
			while (pid <= 4)
			{
				btn = findNameButton(menu, pid);
				if (btn)
				{
					try
					{
						btn.removeEventListener(MouseEvent.CLICK, onEditMouse, true);
						btn.removeEventListener(MouseEvent.CLICK, onEditMouse, false);
						btn.removeEventListener(MouseEvent.MOUSE_DOWN, onEditMouse, true);
						btn.removeEventListener(MouseEvent.MOUSE_DOWN, onEditMouse, false);
					}
					catch (rmErr:*)
					{
					};
					mod.m_editPidByBtn[btn] = pid;
					mod.m_editHooked[btn] = true;
					btn.addEventListener(MouseEvent.CLICK, onEditMouse, true, 99);
					btn.addEventListener(MouseEvent.MOUSE_DOWN, onEditMouse, true, 99);
					log("hooked edit pid=" + pid);
				}
				else
				{
					log("no edit btn pid=" + pid);
				};
				pid++;
			};
		}

		private function onEditMouse(e:MouseEvent):void
		{
			var btn:*;
			var pid:int;
			e.stopImmediatePropagation();
			e.preventDefault();
			// Controller/keyboard confirm arrives through CSS_NAME_PENCIL; CLICK only follows a MOUSE_DOWN.
			if (e.type != MouseEvent.MOUSE_DOWN)
			{
				return;
			};
			btn = e.currentTarget;
			pid = mod.m_editPidByBtn[btn] != null ? int(mod.m_editPidByBtn[btn]) : 0;
			if (pid < 1)
			{
				pid = hitEditPid(e.stageX, e.stageY);
			};
			if (pid < 1)
			{
				pid = 1;
			};
			log("edit btn pid=" + pid + " type=" + e.type);
			mod.m_nameEdit.hideStockKeypad(pid);
			mod.m_list.openList(pid, btn);
		}

		/** Stage capture: catch pencil clicks even when btn listeners don't fire. */
		internal function onStagePencil(e:MouseEvent):void
		{
			var pid:int;
			var btn:*;
			if (e.type == MouseEvent.CLICK)
			{
				if (m_pencilDown)
				{
					m_pencilDown = false;
					e.stopImmediatePropagation();
					e.preventDefault();
				};
				return;
			};
			m_pencilDown = false;
			if (mod.m_addPopup && mod.m_addPopup.parent)
			{
				return;
			};
			if (mod.m_liveNameTxt)
			{
				return;
			};
			ensureCssMenu();
			if (!cssMenuOnscreen())
			{
				return;
			};
			pid = hitEditPid(e.stageX, e.stageY);
			if (pid < 1)
			{
				return;
			};
			if (hitCssChrome(e.stageX, e.stageY))
			{
				return;
			};
			// Don't steal clicks meant for an open dropdown/manage panel.
			if (hitAnyProfilesUi(e.stageX, e.stageY))
			{
				return;
			};
			e.stopImmediatePropagation();
			e.preventDefault();
			m_pencilDown = true;
			mod.m_nameEdit.hideStockKeypad(pid);
			btn = findNameButton(mod.m_cssMenu, pid);
			log("stage pencil pid=" + pid + " btn=" + Boolean(btn) + " type=" + e.type);
			mod.m_list.openList(pid, btn);
		}

		private function hitCssChrome(stageX:Number, stageY:Number):Boolean
		{
			var sub:*;
			var child:*;
			var i:int;
			ensureCssMenu();
			if (!mod.m_cssMenu)
			{
				return (false);
			};
			try
			{
				sub = mod.m_cssMenu["SubMenu"];
			}
			catch (err:*)
			{
				sub = null;
			};
			if (!sub)
			{
				return (false);
			};
			i = sub.numChildren - 1;
			while (i >= 0)
			{
				child = sub.getChildAt(i);
				if (child && child.name == "cssChrome" && child.visible)
				{
					try
					{
						if (child.hitTestPoint(stageX, stageY, true))
						{
							return (true);
						};
					}
					catch (hitErr:*)
					{
					};
				};
				i--;
			};
			return (false);
		}

		private function hitAnyProfilesUi(stageX:Number, stageY:Number):Boolean
		{
			var pid:int;
			var s:Object;
			pid = 1;
			while (pid <= 4)
			{
				s = mod.m_sessions[String(pid)];
				if (mod.sessionManageOpen(s) && ProfileUi.hitSprite(s["manage"], stageX, stageY))
				{
					return (true);
				};
				if (mod.sessionListOpen(s) && ProfileUi.hitSprite(s["list"], stageX, stageY))
				{
					return (true);
				};
				pid++;
			};
			return (false);
		}

		private function hitEditPid(stageX:Number, stageY:Number):int
		{
			var pid:int;
			var btn:*;
			var display:*;
			ensureCssMenu();
			if (!mod.m_cssMenu)
			{
				return (0);
			};
			pid = 1;
			while (pid <= 4)
			{
				btn = findNameButton(mod.m_cssMenu, pid);
				if (btn)
				{
					try
					{
						if (btn.hitTestPoint(stageX, stageY, true))
						{
							return (pid);
						};
					}
					catch (hitErr:*)
					{
					};
				};
				display = findNameDisplay(mod.m_cssMenu, pid);
				if (display)
				{
					try
					{
						// Pencil sits on nameDisplay; hit the whole strip's right side if btn miss.
						if (display["btn_keypad"] && display["btn_keypad"].hitTestPoint(stageX, stageY, true))
						{
							return (pid);
						};
					}
					catch (dErr:*)
					{
					};
				};
				pid++;
			};
			return (0);
		}

		private function cssMenuOnscreen():Boolean
		{
			if (!mod.m_cssMenu)
			{
				return (false);
			};
			try
			{
				return (Boolean(mod.m_cssMenu["isOnscreen"] && mod.m_cssMenu["isOnscreen"]()));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function ensureCssMenu():void
		{
			var MC:Class;
			var menu:*;
			if (mod.m_cssMenu)
			{
				try
				{
					if (mod.m_cssMenu["isOnscreen"] && mod.m_cssMenu["isOnscreen"]())
					{
						return;
					};
				}
				catch (onErr:*)
				{
				};
			};
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				menu = MC ? MC["CurrentCharacterSelectMenu"] : null;
				if (menu && menu["isOnscreen"] && menu["isOnscreen"]())
				{
					mod.m_cssMenu = menu;
					mod.setFrameArmed(true);
					hookEditButtons(menu);
				};
			}
			catch (err:*)
			{
			};
		}

		internal function pollCssMenu():void
		{
			var MC:Class;
			var menu:*;
			var btn1:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				menu = MC ? MC["CurrentCharacterSelectMenu"] : null;
				if (menu && menu["isOnscreen"] && menu["isOnscreen"]())
				{
					btn1 = findNameButton(menu, 1);
					if (mod.m_cssMenu != menu || !btn1 || !mod.m_editHooked[btn1])
					{
						mod.m_cssMenu = menu;
						hookEditButtons(menu);
					};
				};
			}
			catch (err:*)
			{
			};
		}

		internal function applyLastNames(menu:*):void
		{
			var pid:int;
			var name:String;
			pid = 1;
			while (pid <= 4)
			{
				name = String(mod.m_data["last"][String(pid)] || "");
				if (name.length > 0)
				{
					mod.m_cssMenu = menu;
					mod.m_tags.selectName(pid, name);
				};
				pid++;
			};
		}

		internal static function findNameButton(menu:*, pid:int):*
		{
			var display:*;
			display = findNameDisplay(menu, pid);
			return (display ? display["btn_keypad"] : null);
		}

		internal static function findNameDisplay(menu:*, pid:int):*
		{
			var boxes:*;
			var box:*;
			var sub:*;
			var display:*;
			if (!menu || pid < 1)
			{
				return (null);
			};
			try
			{
				boxes = menu["CharSelectionBoxes"];
				if (boxes && int(boxes["length"]) >= pid)
				{
					box = boxes[pid - 1];
					if (box && box["nameDisplay"])
					{
						return (box["nameDisplay"]);
					};
				};
			}
			catch (boxErr:*)
			{
			};
			try
			{
				sub = menu["SubMenu"] || menu;
				display = sub["display" + pid];
				if (display && display["nameDisplay"])
				{
					return (display["nameDisplay"]);
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}
	}
}
