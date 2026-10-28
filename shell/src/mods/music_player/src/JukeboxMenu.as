package
{
	import flash.display.MovieClip;
	import flash.utils.getQualifiedClassName;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Menu shell for My Jukebox. Stock menus stay in the display list but are
	 * hidden and ignore input while this screen is up, so they do not re-show
	 * and overwrite Discord presence.
	 */
	public class JukeboxMenu
	{
		private var m_container:MovieClip;
		private var m_hidden:Array;
		private var m_open:Boolean;
		private var m_closing:Boolean;

		public function JukeboxMenu()
		{
			m_container = new MovieClip();
			m_container.name = "jukeboxMenu";
			m_hidden = [];
			m_open = false;
			m_closing = false;
		}

		public function isOpen():Boolean
		{
			return (m_open);
		}

		public function isOnscreen():Boolean
		{
			return (m_container != null && m_container.stage != null);
		}

		public function open(ui:*, stageId:String, matchPick:Boolean, onPick:Function, onClose:Function):void
		{
			var root:*;
			if (!ui)
			{
				return;
			};
			if (m_open)
			{
				return;
			};
			m_closing = false;
			hideStockMenus();
			root = gameRoot();
			if (!root)
			{
				return;
			};
			if (!m_container.parent)
			{
				root.addChild(m_container);
			};
			root.setChildIndex(m_container, root.numChildren - 1);
			m_open = true;
			ui.open(stageId, matchPick, onPick, onClose, m_container);
			try
			{
				var MH:* = EngineRefs.ssf2("modhost.ModHost");
				if (MH && MH["runHook"] is Function)
				{
					MH["runHook"]("MENU_SHOW", {"menu": this, "cancel": false});
					MH["runHook"]("MENU_NAVIGATE", {"menu": this, "action": "show"});
				};
			}
			catch (hookErr:*)
			{
			};
		}

		/** Called after the UI has torn itself down. */
		public function onUiClosed():void
		{
			var root:*;
			var i:int;
			var menu:*;
			if (m_closing)
			{
				return;
			};
			m_closing = true;
			m_open = false;
			if (m_container && m_container.parent)
			{
				m_container.parent.removeChild(m_container);
			};
			try
			{
				var MH:* = EngineRefs.ssf2("modhost.ModHost");
				if (MH && MH["runHook"] is Function)
				{
					MH["runHook"]("MENU_HIDE", {"menu": this, "cancel": false});
				};
			}
			catch (hookErr:*)
			{
			};
			i = 0;
			menu = null;
			while (i < m_hidden.length)
			{
				menu = m_hidden[i];
				i++;
				restoreStockMenu(menu);
			};
			m_hidden = [];
			m_closing = false;
			root = gameRoot();
			if (root)
			{
				try
				{
					var MainCls:* = EngineRefs.ssf2("Main");
					if (MainCls && MainCls["fixFocus"] is Function)
					{
						MainCls["fixFocus"]();
					};
				}
				catch (focusErr:*)
				{
				};
			};
		}

		/** Hide one stock menu that tried to show while the jukebox is open. */
		public function hideStockMenu(menu:*):void
		{
			var q:String;
			var i:int;
			if (!m_open || !menu || menu == this)
			{
				return;
			};
			q = "";
			try
			{
				q = getQualifiedClassName(menu);
			}
			catch (nameErr:*)
			{
			};
			if (q.indexOf("JukeboxMenu") >= 0)
			{
				return;
			};
			i = 0;
			while (i < m_hidden.length)
			{
				if (m_hidden[i] == menu)
				{
					applyHide(menu);
					return;
				};
				i++;
			};
			m_hidden.push(menu);
			applyHide(menu);
		}

		private function hideStockMenus():void
		{
			var menus:Array;
			var i:int;
			var menu:*;
			var q:String;
			m_hidden = [];
			menus = MusicLiveMenus.onscreen();
			i = 0;
			while (i < menus.length)
			{
				menu = menus[i];
				i++;
				if (!menu || menu == this)
				{
					continue;
				};
				q = "";
				try
				{
					q = getQualifiedClassName(menu);
				}
				catch (nameErr:*)
				{
				};
				if (q.indexOf("JukeboxMenu") >= 0)
				{
					continue;
				};
				try
				{
					if (menu["isOnscreen"] is Function && !Boolean(menu["isOnscreen"]()))
					{
						continue;
					};
				}
				catch (screenErr:*)
				{
				};
				m_hidden.push(menu);
				applyHide(menu);
			};
		}

		private function applyHide(menu:*):void
		{
			if (!menu)
			{
				return;
			};
			try
			{
				if (menu["killEvents"] is Function)
				{
					menu["killEvents"]();
				};
			}
			catch (killErr:*)
			{
			};
			try
			{
				if (menu["Container"])
				{
					menu["Container"].visible = false;
				};
			}
			catch (visErr:*)
			{
			};
		}

		private function restoreStockMenu(menu:*):void
		{
			if (!menu)
			{
				return;
			};
			try
			{
				if (menu["Container"])
				{
					menu["Container"].visible = true;
				};
			}
			catch (visErr:*)
			{
			};
			try
			{
				if (menu["makeEvents"] is Function)
				{
					menu["makeEvents"]();
				};
			}
			catch (evErr:*)
			{
			};
		}

		private function gameRoot():*
		{
			var MainCls:*;
			try
			{
				MainCls = EngineRefs.ssf2("Main");
				if (MainCls && MainCls["Root"])
				{
					return (MainCls["Root"]);
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}
	}
}
