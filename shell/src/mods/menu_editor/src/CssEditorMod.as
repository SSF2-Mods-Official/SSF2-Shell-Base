package
{
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.utils.getQualifiedClassName;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Visual Character Select grid editor. Persist rows via saveExt; apply in-memory mappings.
	 */
	public class CssEditorMod extends Sprite
	{
		internal static const PAGE_PREV:String = "css_prev_page";
		internal static const PAGE_NEXT:String = "css_next_page";
		internal static const MAX_PAGES:int = 99;
		internal static const MODE_SORT:int = 0;
		internal static const MODE_ADD:int = 1;
		internal static const MODE_REMOVE:int = 2;
		internal static const BTN_H:int = 26;
		internal static const EDIT_W:int = 72;
		internal static const MAX_ROWS:int = 21;

		internal var m_roster:CssRosterStore;
		internal var m_paging:CssPaging;
		internal var m_layout:CssGridLayout;
		internal var m_chrome:CssEditChrome;
		internal var m_hands:CssHands;
		internal var m_input:CssEditInput;
		internal var m_addUi:CssAddPopup;
		internal var m_host:*;
		internal var m_editing:Boolean;
		internal var m_mode:int;
		internal var m_defaults:Array;
		internal var m_defaultPos:Object;
		private var m_menusReady:Boolean;
		private var m_compactOn:Boolean;
		internal var m_editBtn:Sprite;
		internal var m_sortBtn:Sprite;
		internal var m_addBtn:Sprite;
		internal var m_removeBtn:Sprite;
		internal var m_restoreBtn:Sprite;
		internal var m_confirmBtn:Sprite;
		internal var m_removeAllBtn:Sprite;
		internal var m_addPopup:Sprite;
		internal var m_removeIds:Object;
		internal var m_dragId:String;
		internal var m_dragging:Boolean;
		internal var m_cell:Number;
		internal var m_originX:Number;
		internal var m_originY:Number;
		internal var m_maxCols:int;
		private var m_inputHooked:Boolean;
		internal var m_icons:DisplayObjectContainer;
		internal var m_menu:*;
		internal var m_gamepadDrag:Boolean;
		private var m_compactTries:int;
		internal var m_addTray:Sprite;
		internal var m_loggedGrid:Boolean;
		private var m_inLayout:Boolean;
		private var m_offFrames:int;
		private var m_menuCtl:Class;
		internal var m_pages:Array;
		internal var m_page:int;
		internal var m_pageClips:Object;
		private var m_openWait:OpenWaiter;
		private var m_layoutErr:String = "";

		public function CssEditorMod()
		{
			super();
			m_roster = new CssRosterStore(this);
			m_paging = new CssPaging(this);
			m_layout = new CssGridLayout(this);
			m_chrome = new CssEditChrome(this);
			m_hands = new CssHands(this);
			m_input = new CssEditInput(this);
			m_addUi = new CssAddPopup(this);
			m_editing = false;
			m_mode = MODE_SORT;
			m_menusReady = false;
			m_compactOn = false;
			m_removeIds = {};
			m_dragId = "";
			m_dragging = false;
			m_cell = 42;
			m_maxCols = 1;
			m_inputHooked = false;
			m_gamepadDrag = false;
			m_pageClips = {};
			m_pages = null;
			m_page = 0;
			m_compactTries = 0;
			m_offFrames = 0;
			m_openWait = new OpenWaiter("cssedit", m_chrome.isCssOnscreen, enterFromWait, cssLog);
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			cssLog("boot");
			if (!host)
			{
				return;
			};
			host.addHook("AFTER_BOOT", onAfterBoot);
			host.addHook("BEFORE_INITIAL_MENU", onBeforeMenu);
			host.addHook("MENU_SHOW", onCssMenuShow);
			host.addEventListener("mod_menu.ready", onMenuReady);
			host.addEventListener("css_editor.open", onCssEditOpen);
			registerMenu();
		}

		internal function cssLog(msg:String):void
		{
			var line:String;
			line = "[css_editor] " + msg;
			trace(line);
			try
			{
				if (m_host && m_host["appendGameLog"])
				{
					m_host["appendGameLog"](line);
					return;
				};
			}
			catch (hostErr:*)
			{
			};
			EngineRefs.gameLog(line);
		}

		private function onCssMenuShow(ctx:Object):void
		{
			var menu:*;
			var q:String;
			try
			{
				menu = ctx ? ctx["menu"] : null;
				if (!menu)
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
				if (q.indexOf("CharacterSelect") < 0 && q.indexOf("VSMenu") < 0 && q.indexOf("TrainingMenu") < 0)
				{
					return;
				};
				m_menu = menu;
				m_menusReady = true;
				m_compactTries = 0;
				m_loggedGrid = false;
				cssLog("show " + q);
				if (!m_editing)
				{
					m_roster.applySaved();
				};
				armCompact();
				m_chrome.ensureEditChrome();
			}
			catch (stepErr:*)
			{
				cssLog("fail step=onCssMenuShow err=" + stepErr);
			};
		}

		private function onCssEditOpen(e:*):void
		{
			try
			{
				m_openWait.start(cssEditStage());
			}
			catch (stepErr:*)
			{
				cssLog("fail step=onCssEditOpen err=" + stepErr);
			};
		}

		private function enterFromWait():void
		{
			if (!m_editing)
			{
				enterLiveEdit();
			};
		}

		private function cssEditStage():Stage
		{
			try
			{
				if (m_host && m_host.stage)
				{
					return (m_host.stage as Stage);
				};
			}
			catch (err:*)
			{
			};
			return (stage);
		}

		public function onBootEnd():void
		{
			m_openWait.stop();
			exitLiveEdit(false);
			stopCompact();
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("AFTER_BOOT", onAfterBoot);
					m_host["removeHook"]("BEFORE_INITIAL_MENU", onBeforeMenu);
					m_host["removeHook"]("MENU_SHOW", onCssMenuShow);
					m_host["removeEventListener"]("mod_menu.ready", onMenuReady);
					m_host["removeEventListener"]("css_editor.open", onCssEditOpen);
					m_host.emit("mod_menu.unregister", {"id": "css_editor"});
				}
				catch (err:*)
				{
				};
			};
			m_host = null;
		}

		private function onAfterBoot(ctx:Object):void
		{
			m_roster.captureDefaults();
			m_roster.applySaved();
			m_menusReady = true;
			registerMenu();
			armCompact();
		}

		private function onBeforeMenu(ctx:Object):void
		{
			m_menusReady = true;
			m_roster.applySaved();
			armCompact();
		}

		private function onMenuReady(e:*):void
		{
			registerMenu();
		}

		private function registerMenu():void
		{
			if (!m_host)
			{
				return;
			};
			try
			{
				m_host.emit("mod_menu.register", {
					"id": "css_editor",
					"label": "Edit Character Select",
					"section": "Roster",
					"onSelect": openEditor
				});
			}
			catch (err:*)
			{
			};
		}

		private function openEditor():void
		{
			try
			{
				if (!m_chrome.isCssOnscreen())
				{
					try
					{
						if (m_host)
						{
							m_host.notify("Open Character Select, then edit the roster.");
						};
					}
					catch (err:*)
					{
					};
					return;
				};
				if (m_editing)
				{
					exitLiveEdit(true);
				}
				else
				{
					enterLiveEdit();
				};
			}
			catch (stepErr:*)
			{
				cssLog("fail step=openEditor err=" + stepErr);
			};
		}

		private function armCompact():void
		{
			if (!m_host || m_compactOn)
			{
				return;
			};
			startCompact();
			if (m_compactOn)
			{
				m_compactTries = 0;
				return;
			};
			m_compactTries++;
			if (m_compactTries < 50)
			{
				setTimeout(armCompact, 200);
			};
		}

		private function startCompact():void
		{
			var st:Stage;
			if (m_compactOn || !m_host)
			{
				return;
			};
			st = m_host.stage as Stage;
			if (!st && stage)
			{
				st = stage;
			};
			if (!st)
			{
				return;
			};
			m_compactOn = true;
			m_offFrames = 0;
			st.addEventListener(Event.EXIT_FRAME, compactFrame);
		}

		private function stopCompact():void
		{
			var st:Stage;
			if (!m_compactOn)
			{
				return;
			};
			m_compactOn = false;
			m_hands.seatAllHands();
			m_hands.unhookHands();
			m_hands.restoreParkedHand();
			try
			{
				st = m_host ? (m_host.stage as Stage) : null;
				if (st)
				{
					st.removeEventListener(Event.EXIT_FRAME, compactFrame);
				};
				if (stage && stage != st)
				{
					stage.removeEventListener(Event.EXIT_FRAME, compactFrame);
				};
			}
			catch (err:*)
			{
			};
		}

		private function menuOnScreen(menu:*):Boolean
		{
			try
			{
				return (menu && menu.isOnscreen());
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function compactFrame(e:Event):void
		{
			var menu:*;
			var mappings:Object;
			var rows:Array;
			if (m_inLayout || !m_menusReady)
			{
				return;
			};
			mappings = EditorEngine.mappings();
			if (!mappings || !mappings.character_select_screen)
			{
				return;
			};
			rows = mappings.character_select_screen.rows as Array;
			if (!rows)
			{
				return;
			};
			try
			{
				if (!m_menuCtl)
				{
					m_menuCtl = EngineRefs.MenuController as Class;
				};
				menu = m_menuCtl["CurrentCharacterSelectMenu"];
			}
			catch (err:*)
			{
				return;
			};
			if (!menu)
			{
				menu = m_chrome.liveCssMenu();
			};
			if (menu && !menuOnScreen(menu) && menuOnScreen(m_menu))
			{
				menu = m_menu;
			};
			if (!menu || !menuOnScreen(menu))
			{
				if (m_editing)
				{
					exitLiveEdit(false);
				};
				m_chrome.restoreEditVisibility();
				m_chrome.hideEditChrome();
				m_offFrames++;
				if (m_offFrames >= 30)
				{
					cssLog("compact detach menu=" + (menu ? "offscreen" : "none"));
					stopCompact();
				};
				return;
			};
			m_offFrames = 0;
			m_inLayout = true;
			try
			{
				try
				{
					m_layout.layoutLiveCss(menu, mappings, rows);
				}
				catch (layoutErr:*)
				{
					if (String(layoutErr) != m_layoutErr)
					{
						m_layoutErr = String(layoutErr);
						cssLog("fail step=layoutLiveCss err=" + layoutErr);
					};
				};
				m_menu = menu;
				m_chrome.refreshEditSlot(menu);
				m_chrome.ensureEditChrome();
				m_chrome.applyEditVisibility(menu);
				m_chrome.raiseEditChrome();
				m_hands.raisePrimaryHand(menu);
				m_hands.liftHandsOverChrome(menu);
				m_input.pollGamepadEdit();
			}
			finally
			{
				m_inLayout = false;
			};
		}

		internal function enterLiveEdit():void
		{
			var st:Stage;
			var currentOn:int;
			var menuOn:int;
			try
			{
				currentOn = m_chrome.isCssOnscreen() ? 1 : 0;
				menuOn = menuOnScreen(m_menu) ? 1 : 0;
				cssLog("edit enter host=" + (m_host ? 1 : 0) + " currentOn=" + currentOn + " menuOn=" + menuOn);
				if (m_editing || !m_host || (currentOn == 0 && menuOn == 0))
				{
					return;
				};
				m_editing = true;
				m_mode = MODE_SORT;
				m_removeIds = {};
				m_dragId = "";
				m_dragging = false;
				try
				{
					m_host.setSessionFlag("css_editor.editing", true);
				}
				catch (flagErr:*)
				{
				};
				st = m_host.stage as Stage;
				if (st && !m_inputHooked)
				{
					m_inputHooked = true;
					st.addEventListener(MouseEvent.MOUSE_DOWN, m_input.onEditMouseDown, true, 80);
					st.addEventListener(MouseEvent.MOUSE_MOVE, m_input.onEditMouseMove, true, 80);
					st.addEventListener(MouseEvent.MOUSE_UP, m_input.onEditMouseUp, true, 80);
				};
				m_chrome.layoutBar();
			}
			catch (stepErr:*)
			{
				cssLog("fail step=enterLiveEdit err=" + stepErr);
			};
		}

		internal function exitLiveEdit(viaF1:Boolean):void
		{
			var st:Stage;
			if (!m_editing)
			{
				return;
			};
			m_dragging = false;
			m_dragId = "";
			m_editing = false;
			m_removeIds = {};
			m_gamepadDrag = false;
			m_addUi.closeAddPopup();
			m_chrome.restoreEditVisibility();
			try
			{
				m_host.setSessionFlag("css_editor.editing", false);
				if (viaF1)
				{
					m_host.setSessionFlag("mod_menu.skip_f1", true);
				};
			}
			catch (flagErr:*)
			{
			};
			st = m_host ? (m_host.stage as Stage) : null;
			if (st && m_inputHooked)
			{
				m_inputHooked = false;
				st.removeEventListener(MouseEvent.MOUSE_DOWN, m_input.onEditMouseDown, true);
				st.removeEventListener(MouseEvent.MOUSE_MOVE, m_input.onEditMouseMove, true);
				st.removeEventListener(MouseEvent.MOUSE_UP, m_input.onEditMouseUp, true);
			};
			m_chrome.layoutBar();
		}
	}
}
