package
{
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFieldAutoSize;

	import ssf2mm.shared.EngineRefs;

	/**
	 * F1 hub. Packs emit mod_menu.register / unregister.
	 * Payload: id, label, onSelect, section?, visible?, notes?, guide? (non-selectable),
	 * nowPlaying? (Function→String for upper-right song label), onNowPlaying?
	 */
	public class ModMenuMod extends Sprite
	{
		private static const KEY_F1:uint = 112;
		private static const KEY_ESC:uint = 27;
		private static const KEY_ENTER:uint = 13;
		private static const KEY_SPACE:uint = 32;
		private static const KEY_A:uint = 65;
		private static const KEY_Z:uint = 90;
		private static const ROW_H:int = ModMenuScroll.ROW_H;
		private static const SECTION_H:int = ModMenuScroll.SECTION_H;
		private static const MARGIN:int = 20;
		private static const SAVE_HOTKEY:String = "mod_menu.hotkey";
		private static const HOLD_DELAY:int = 16;
		private static const HOLD_FAST:int = 3;
		private static const HOLD_TURBO:int = 1;
		private static const PAD_BIND_NAMES:Array = [
			"START", "TAUNT", "SHIELD", "SHIELD2", "GRAB", "JUMP", "JUMP2",
			"DASH", "BUTTON1", "BUTTON2", "C_UP", "C_DOWN", "C_LEFT", "C_RIGHT"
		];

		private var m_host:*;
		private var m_items:Array = [];
		private var m_view:Array = [];
		private var m_overlay:Sprite;
		private var m_listLayer:Sprite;
		private var m_listMask:Sprite;
		private var m_scrollBar:Sprite;
		private var m_scrollThumb:Sprite;
		private var m_notesPanel:TextField;
		private var m_open:Boolean = false;
		private var m_index:int = 0;
		private var m_scroll:int = 0;
		private var m_rows:Array = [];
		private var m_title:TextField;
		private var m_hint:TextField;
		private var m_billboard:TextField;
		private var m_nowPlaying:TextField;
		private var m_billboardText:String = "";
		private var m_prevUp:Boolean;
		private var m_prevDown:Boolean;
		private var m_prevOk:Boolean;
		private var m_prevBack:Boolean;
		private var m_onNowPlaying:Function;
		private var m_releaseHoldoff:Boolean = false;
		private var m_suspendedMenus:Array = [];
		private var m_gw:int = 853;
		private var m_gh:int = 480;
		private var m_listTop:int = 52;
		private var m_listBottom:int = 430;
		private var m_listLeft:int = 36;
		private var m_listWidth:int = 420;
		private var m_holdAge:int = 0;
		private var m_holdDir:int = 0;
		private var m_binding:Boolean = false;
		private var m_bindWaitRelease:Boolean = false;
		private var m_hotkeyKind:String = "";
		private var m_hotkeyCode:uint = 0;
		private var m_hotkeyPad:String = "";
		private var m_prevHotkeyDown:Boolean = true;
		private var m_hotkeyPollArmed:Boolean = false;
		private var m_hotkeyRoot:*;
		private var m_reopen:Boolean = false;

		public function ModMenuMod()
		{
			super();
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			};
			host.addEventListener("mod_menu.register", onRegister);
			host.addEventListener("mod_menu.unregister", onUnregister);
			host.addEventListener("mod_menu.open", onOpenRequest);
			host.addKeyListener(onKey);
			host.addHook("AFTER_BOOT", onAfterBoot);
			loadHotkey();
			armHotkeyPoll();
			m_reopen = Boolean(m_host.saveExtGet("mod_menu.reopen"));
			if (m_reopen)
			{
				m_host.saveExtSet("mod_menu.reopen", false);
			};
			flushPending();
			if (m_reopen)
			{
				openMenu();
				if (m_open)
				{
					m_reopen = false;
				};
			};
			trace("[mod_menu] boot — F1 / hotkey opens shortcuts");
		}

		public function onBootEnd():void
		{
			closeMenu();
			disarmHotkeyPoll();
			if (m_host)
			{
				try
				{
					m_host["removeEventListener"]("mod_menu.register", onRegister);
					m_host["removeEventListener"]("mod_menu.unregister", onUnregister);
					m_host["removeEventListener"]("mod_menu.open", onOpenRequest);
					m_host["removeKeyListener"](onKey);
					m_host["removeHook"]("AFTER_BOOT", onAfterBoot);
				}
				catch (err:*)
				{
				};
			};
			m_host = null;
		}

		private function onAfterBoot(ctx:Object):void
		{
			flushPending();
			if (m_reopen)
			{
				m_reopen = false;
				openMenu();
			};
		}

		private function onOpenRequest(e:*):void
		{
			openMenu();
		}

		private function onRegister(e:*):void
		{
			var data:Object;
			data = (e && e.data) ? e.data : e;
			if (!data || !data.id)
			{
				return;
			};
			upsert(data);
			if (m_open)
			{
				rebuildList();
			};
		}

		private function onUnregister(e:*):void
		{
			var data:Object;
			var i:int;
			data = (e && e.data) ? e.data : e;
			if (!data || !data.id)
			{
				return;
			};
			i = 0;
			while (i < m_items.length)
			{
				if (m_items[i].id == String(data.id))
				{
					m_items.splice(i, 1);
					break;
				};
				i++;
			};
			if (m_open)
			{
				rebuildList();
			};
		}

		private function upsert(data:Object):void
		{
			var id:String;
			var i:int;
			var item:Object;
			id = String(data.id);
			i = 0;
			while (i < m_items.length)
			{
				if (m_items[i].id == id)
				{
					item = m_items[i];
					item.label = String(data.label || id);
					item.onSelect = data.onSelect as Function;
					item.section = String(data.section || "");
					item.visible = data.visible as Function;
					item.notes = String(data.notes || "");
					item.guide = Boolean(data.guide);
					item.nowPlaying = data.nowPlaying as Function;
					item.onNowPlaying = data.onNowPlaying as Function;
					sortItems();
					return;
				};
				i++;
			};
			m_items.push({
				"id": id,
				"label": String(data.label || id),
				"onSelect": data.onSelect as Function,
				"section": String(data.section || ""),
				"visible": data.visible as Function,
				"notes": String(data.notes || ""),
				"guide": Boolean(data.guide),
				"nowPlaying": data.nowPlaying as Function,
				"onNowPlaying": data.onNowPlaying as Function
			});
			sortItems();
		}

		private function sortItems():void
		{
			m_items.sortOn(["section", "label", "id"], Array.CASEINSENSITIVE);
		}

		private function visibleItems():Array
		{
			var out:Array;
			var i:int;
			var item:Object;
			var show:Boolean;
			out = [];
			i = 0;
			while (i < m_items.length)
			{
				item = m_items[i];
				show = true;
				if (item && item.visible is Function)
				{
					try
					{
						show = Boolean(item.visible());
					}
					catch (err:*)
					{
						show = false;
					};
				};
				if (show)
				{
					out.push(item);
				};
				i++;
			};
			appendModToggles(out);
			// Built-in Settings row — bind secondary open key.
			out.push({
				"id": "__bind_hotkey__",
				"label": "Bind Hotkey: " + hotkeyDisplay(),
				"section": "Settings",
				"notes": "Press A, then any keyboard key or controller button. That becomes a secondary Mod Menu open key (alongside F1). Esc cancels.",
				"onSelect": beginHotkeyBind,
				"guide": false
			});
			return (out);
		}

		private function appendModToggles(out:Array):void
		{
			var list:Array;
			var i:int;
			var info:Object;
			var id:String;
			var enabled:Boolean;
			if (!m_host || !out)
			{
				return;
			};
			try
			{
				list = m_host.getModList();
			}
			catch (err:*)
			{
				return;
			};
			if (!list)
			{
				return;
			};
			i = 0;
			while (i < list.length)
			{
				info = list[i];
				if (info && info.id)
				{
					id = String(info.id);
					enabled = false;
					try
					{
						enabled = Boolean(m_host.isModEnabled(id));
					}
					catch (enErr:*)
					{
					};
					if (Boolean(info.essential))
					{
						out.push({
							"id": "__mod__" + id,
							"label": String(info.name || id) + "  [ON]",
							"section": "Mods",
							"notes": "Essential pack. It stays on.",
							"guide": true
						});
					}
					else
					{
						out.push({
							"id": "__mod__" + id,
							"label": String(info.name || id) + (enabled ? "  [ON]" : "  [OFF]"),
							"section": "Mods",
							"notes": String(info.description || "Select to turn this pack on or off."),
							"guide": false,
							"onSelect": makeModToggle(id, enabled)
						});
					};
				};
				i++;
			};
		}

		private function makeModToggle(id:String, enabledNow:Boolean):Function
		{
			var modId:String = id;
			var wasOn:Boolean = enabledNow;
			return function ():void
			{
				if (!m_host)
				{
					return;
				};
				try
				{
					m_host.notify(modId + (wasOn ? " disabled" : " enabled"));
				}
				catch (noteErr:*)
				{
				};
				try
				{
					m_host.saveExtSet("mod_menu.reopen", true);
					m_host.setModEnabled(modId, !wasOn);
				}
				catch (err:*)
				{
				};
			};
		}

		private function flushPending():void
		{
			try
			{
				if (m_host)
				{
					m_host.emit("mod_menu.ready", {});
				};
			}
			catch (err:*)
			{
			};
		}

		private function onKey(e:KeyboardEvent):Boolean
		{
			var code:uint;
			code = uint(e.keyCode);
			if (m_binding)
			{
				if (code == KEY_ESC)
				{
					cancelHotkeyBind();
					return (true);
				};
				if (code == KEY_F1)
				{
					return (true);
				};
				finishHotkeyBindKey(code);
				return (true);
			};
			if (!m_open)
			{
				if (code == KEY_F1 || isHotkeyKey(code))
				{
					try
					{
						if (m_host && m_host.getSessionFlag("mod_menu.skip_f1"))
						{
							m_host.setSessionFlag("mod_menu.skip_f1", false);
							return (true);
						};
						if (m_host && m_host.getSessionFlag("mod_menu.overlay"))
						{
							return (true);
						};
					}
					catch (err:*)
					{
					};
					openMenu();
					return (true);
				};
				return (false);
			};
			if (code == KEY_F1 || code == KEY_ESC)
			{
				closeMenu();
				return (true);
			};
			// Swallow every key while open. Arrows and confirm keys are handled
			// in onFrame via Controllers; handling them here double-steps the list.
			return (true);
		}

		private function openMenu():void
		{
			var root:*;
			if (m_open || !m_host)
			{
				return;
			};
			root = resolveGameRoot();
			if (!root)
			{
				return;
			};
			refreshGameSize();
			m_open = true;
			m_binding = false;
			m_bindWaitRelease = false;
			m_releaseHoldoff = false;
			m_index = 0;
			m_scroll = 0;
			m_holdAge = 0;
			m_holdDir = 0;
			m_prevUp = m_prevDown = m_prevOk = m_prevBack = true;
			setGameInputBlocked(true);
			suspendUnderlyingMenus();
			try
			{
				m_host.setSessionFlag("mod_menu.overlay", true);
			}
			catch (err2:*)
			{
			};
			m_listTop = 56;
			m_listBottom = m_gh - 40;
			m_listLeft = MARGIN + 16;
			m_listWidth = int(m_gw * 0.52) - MARGIN;
			m_overlay = new Sprite();
			// Full game-resolution dim (attach to Main.Root so window_scale applies).
			m_overlay.graphics.beginFill(0x050508, 0.92);
			m_overlay.graphics.drawRect(0, 0, m_gw, m_gh);
			m_overlay.graphics.endFill();
			m_overlay.graphics.beginFill(0x14141C, 0.98);
			m_overlay.graphics.lineStyle(2, 0xE8A020, 0.95);
			m_overlay.graphics.drawRect(MARGIN, MARGIN, m_gw - MARGIN * 2, m_gh - MARGIN * 2);
			m_overlay.graphics.endFill();
			// Notes column background
			m_overlay.graphics.lineStyle(0, 0, 0);
			m_overlay.graphics.beginFill(0x1A1A24, 0.95);
			m_overlay.graphics.drawRect(m_listLeft + m_listWidth + 12, m_listTop,
				m_gw - MARGIN - (m_listLeft + m_listWidth + 12) - 16, m_listBottom - m_listTop);
			m_overlay.graphics.endFill();
			m_title = makeLabel("MOD MENU", MARGIN + 18, MARGIN + 10, 24, 0xE8A020, true);
			m_nowPlaying = makeLabel("♪ —", m_gw - MARGIN - 280, MARGIN + 14, 13, 0x88CCFF, false);
			m_nowPlaying.width = 260;
			m_nowPlaying.height = 22;
			m_nowPlaying.mouseEnabled = true;
			m_nowPlaying.selectable = false;
			m_nowPlaying.addEventListener(MouseEvent.CLICK, onNowPlayingClick);
			m_hint = makeLabel("F1/Esc close  A select  B back  Hold ↑↓ to scroll", MARGIN + 18, m_gh - MARGIN - 22, 12, 0x888888, false);
			m_hint.width = m_gw - MARGIN * 2 - 40;
			m_billboard = makeLabel("", m_listLeft + m_listWidth + 24, m_listTop + 8, 13, 0xDDDD88, false);
			m_billboard.width = m_gw - MARGIN - (m_listLeft + m_listWidth + 24) - 24;
			m_billboard.height = 36;
			m_billboard.wordWrap = true;
			m_notesPanel = makeLabel("", m_listLeft + m_listWidth + 24, m_listTop + 52, 13, 0xCCCCCC, false);
			m_notesPanel.width = m_billboard.width;
			m_notesPanel.height = m_listBottom - m_listTop - 60;
			m_notesPanel.wordWrap = true;
			m_notesPanel.multiline = true;
			m_listLayer = new Sprite();
			m_listMask = new Sprite();
			m_listMask.graphics.beginFill(0xFFFFFF, 1);
			m_listMask.graphics.drawRect(m_listLeft, m_listTop, m_listWidth, m_listBottom - m_listTop);
			m_listMask.graphics.endFill();
			m_listLayer.mask = m_listMask;
			m_scrollBar = new Sprite();
			m_scrollBar.x = m_listLeft + m_listWidth - 12;
			m_scrollBar.y = m_listTop;
			m_scrollBar.graphics.beginFill(0x333340, 1);
			m_scrollBar.graphics.drawRect(0, 0, 10, m_listBottom - m_listTop);
			m_scrollBar.graphics.endFill();
			m_scrollThumb = new Sprite();
			m_scrollThumb.graphics.beginFill(0xE8A020, 1);
			m_scrollThumb.graphics.drawRect(0, 0, 10, 48);
			m_scrollThumb.graphics.endFill();
			m_scrollBar.addChild(m_scrollThumb);
			m_overlay.addChild(m_title);
			m_overlay.addChild(m_nowPlaying);
			m_overlay.addChild(m_listMask);
			m_overlay.addChild(m_listLayer);
			m_overlay.addChild(m_scrollBar);
			m_overlay.addChild(m_hint);
			m_overlay.addChild(m_billboard);
			m_overlay.addChild(m_notesPanel);
			m_overlay.addEventListener(MouseEvent.MOUSE_WHEEL, onWheel);
			root.addChild(m_overlay);
			root.addEventListener(Event.ENTER_FRAME, onFrame);
			rebuildList();
			refreshNowPlaying();
			updateBillboard();
		}

		private function closeMenu():void
		{
			var root:*;
			if (!m_open)
			{
				return;
			};
			m_open = false;
			m_binding = false;
			m_bindWaitRelease = false;
			root = null;
			if (m_overlay)
			{
				root = m_overlay.parent;
				if (root)
				{
					root.removeEventListener(Event.ENTER_FRAME, onFrame);
				};
				try
				{
					m_overlay.removeEventListener(MouseEvent.MOUSE_WHEEL, onWheel);
				}
				catch (e0:*)
				{
				};
				if (m_overlay.parent)
				{
					m_overlay.parent.removeChild(m_overlay);
				};
			};
			m_overlay = null;
			m_listLayer = null;
			m_notesPanel = null;
			m_rows = [];
			resumeUnderlyingMenus();
			m_releaseHoldoff = true;
			try
			{
				if (m_host)
				{
					m_host.setSessionFlag("mod_menu.overlay", false);
					m_host.setSessionFlag("mod_menu.skip_f1", true);
				};
			}
			catch (err:*)
			{
			};
			root = resolveGameRoot();
			if (root)
			{
				root.addEventListener(Event.ENTER_FRAME, onHoldoffFrame);
			}
			else
			{
				setGameInputBlocked(false);
				m_releaseHoldoff = false;
			};
		}

		private function onHoldoffFrame(e:Event):void
		{
			var root:*;
			if (!m_releaseHoldoff)
			{
				return;
			};
			if (padDown("BUTTON1") || padDown("BUTTON2"))
			{
				return;
			};
			m_releaseHoldoff = false;
			setGameInputBlocked(false);
			root = e && e.currentTarget ? e.currentTarget : resolveGameRoot();
			if (root)
			{
				root.removeEventListener(Event.ENTER_FRAME, onHoldoffFrame);
			};
		}

		private function setGameInputBlocked(on:Boolean):void
		{
			var MH:*;
			try
			{
				MH = EngineRefs.ModHost;
				if (MH && MH["setInputBlocked"] is Function)
				{
					MH["setInputBlocked"](on);
				};
			}
			catch (e1:*)
			{
			};
			try
			{
				if (m_host && m_host["setInputBlocked"] is Function)
				{
					m_host["setInputBlocked"](on);
				};
			}
			catch (e2:*)
			{
			};
		}

		/** Pause underlying Menu ENTER_FRAME handlers (same idea as ControlsMenu covering CSS). */
		private function suspendUnderlyingMenus():void
		{
			var MC:*;
			var names:Array;
			var i:int;
			var menu:*;
			m_suspendedMenus = [];
			try
			{
				MC = EngineRefs.MenuController;
				if (!MC)
				{
					return;
				};
				names = [
					"soundMenu", "stageSelectMenu", "vsMenu", "vaultMenu", "mainMenu",
					"optionsMenu", "titleMenu", "groupMenu", "soloMenu", "dataMenu",
					"arenaCharacterSelectMenu", "controlsMenu", "gamepadMenu"
				];
				i = 0;
				while (i < names.length)
				{
					menu = MC[names[i]];
					i++;
					if (!menu)
					{
						continue;
					};
					try
					{
						if (menu["isOnscreen"] is Function && Boolean(menu["isOnscreen"]())
							&& menu["killEvents"] is Function)
						{
							menu["killEvents"]();
							m_suspendedMenus.push(menu);
						};
					}
					catch (oneErr:*)
					{
					};
				};
			}
			catch (err:*)
			{
			};
		}

		private function resumeUnderlyingMenus():void
		{
			var i:int;
			var menu:*;
			i = 0;
			while (i < m_suspendedMenus.length)
			{
				menu = m_suspendedMenus[i];
				i++;
				try
				{
					if (menu && menu["isOnscreen"] is Function && Boolean(menu["isOnscreen"]())
						&& menu["makeEvents"] is Function)
					{
						menu["makeEvents"]();
					};
				}
				catch (err:*)
				{
				};
			};
			m_suspendedMenus = [];
		}

		private function onFrame(e:Event):void
		{
			var up:Boolean;
			var down:Boolean;
			var ok:Boolean;
			var back:Boolean;
			var padName:String;
			if (!m_open)
			{
				return;
			};
			if (m_overlay && m_overlay.parent)
			{
				m_overlay.parent.setChildIndex(m_overlay, m_overlay.parent.numChildren - 1);
			};
			if (m_binding)
			{
				if (m_bindWaitRelease)
				{
					if (!firstPadDown())
					{
						m_bindWaitRelease = false;
					};
				}
				else
				{
					padName = firstPadDown();
					if (padName)
					{
						finishHotkeyBindPad(padName);
					};
				};
				tickBillboard();
				return;
			};
			tickBillboard();
			refreshNowPlaying();
			up = padDown("UP");
			down = padDown("DOWN");
			ok = padDown("BUTTON2");
			back = padDown("BUTTON1");
			tickHoldScroll(up, down);
			if (ok && !m_prevOk)
			{
				activate(m_index);
			};
			if (back && !m_prevBack)
			{
				closeMenu();
			};
			m_prevUp = up;
			m_prevDown = down;
			m_prevOk = ok;
			m_prevBack = back;
		}

		private function tickHoldScroll(up:Boolean, down:Boolean):void
		{
			var period:int;
			if (up && !down)
			{
				if (!m_prevUp)
				{
					moveSel(-1);
					m_holdDir = -1;
					m_holdAge = 0;
				}
				else if (m_holdDir == -1)
				{
					m_holdAge++;
					period = m_holdAge > 50 ? HOLD_TURBO : HOLD_FAST;
					if (m_holdAge >= HOLD_DELAY && ((m_holdAge - HOLD_DELAY) % period) == 0)
					{
						moveSel(-1);
					};
				};
			}
			else if (down && !up)
			{
				if (!m_prevDown)
				{
					moveSel(1);
					m_holdDir = 1;
					m_holdAge = 0;
				}
				else if (m_holdDir == 1)
				{
					m_holdAge++;
					period = m_holdAge > 50 ? HOLD_TURBO : HOLD_FAST;
					if (m_holdAge >= HOLD_DELAY && ((m_holdAge - HOLD_DELAY) % period) == 0)
					{
						moveSel(1);
					};
				};
			}
			else
			{
				m_holdDir = 0;
				m_holdAge = 0;
			};
		}

		private function padDown(which:String):Boolean
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			try
			{
				SD = EngineRefs.SaveData as Class;
				list = SD ? SD["Controllers"] : null;
				if (!list)
				{
					return (false);
				};
				i = 0;
				while (i < list.length)
				{
					c = list[i];
					i++;
					if (!c || !(c["IsDown"] is Function))
					{
						continue;
					};
					if (which == "UP" && Boolean(c["IsDown"](c["_UP"], true)))
					{
						return (true);
					};
					if (which == "DOWN" && Boolean(c["IsDown"](c["_DOWN"], true)))
					{
						return (true);
					};
					if (which == "BUTTON1" && Boolean(c["IsDown"](c["_BUTTON1"], true)))
					{
						return (true);
					};
					if (which == "BUTTON2" && Boolean(c["IsDown"](c["_BUTTON2"], true)))
					{
						return (true);
					};
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function onWheel(e:MouseEvent):void
		{
			if (e.delta > 0)
			{
				moveSel(-1);
			}
			else if (e.delta < 0)
			{
				moveSel(1);
			};
		}

		private function moveSel(delta:int):void
		{
			var n:int;
			n = m_view.length;
			if (n < 1)
			{
				return;
			};
			m_index = (m_index + delta + n) % n;
			ensureScroll();
			paintSelection();
			updateBillboard();
		}

		/** First item index whose section header+row still fits in the mask. */
		private function listHeight():int
		{
			return (m_listBottom - m_listTop);
		}

		private function itemTopY(itemIndex:int):int
		{
			return (ModMenuScroll.itemTopY(m_view, itemIndex));
		}

		private function sectionStartsAt(itemIndex:int):Boolean
		{
			return (ModMenuScroll.sectionStartsAt(m_view, itemIndex));
		}

		private function ensureScroll():void
		{
			var rowTop:int;
			var blockTop:int;
			var blockBottom:int;
			var h:int;
			h = listHeight();
			if (m_view.length < 1)
			{
				m_scroll = 0;
				rebuildList();
				return;
			};
			while (m_scroll > 0)
			{
				rowTop = itemTopY(m_index) - itemTopY(m_scroll);
				blockTop = sectionStartsAt(m_index) ? rowTop - SECTION_H : rowTop;
				if (blockTop >= 0)
				{
					break;
				};
				m_scroll--;
			};
			while (m_scroll < m_index)
			{
				rowTop = itemTopY(m_index) - itemTopY(m_scroll);
				blockTop = sectionStartsAt(m_index) ? rowTop - SECTION_H : rowTop;
				blockBottom = rowTop + ROW_H;
				if (blockBottom <= h && blockTop >= 0)
				{
					break;
				};
				m_scroll++;
			};
			if (m_scroll < 0)
			{
				m_scroll = 0;
			};
			if (m_scroll > m_index)
			{
				m_scroll = m_index;
			};
			rebuildList();
		}

		private function rebuildList():void
		{
			var i:int;
			var y:int;
			var tf:TextField;
			var lastSec:String;
			var item:Object;
			var label:String;
			var limitY:int;
			var sec:String;
			i = 0;
			while (i < m_rows.length)
			{
				if (m_rows[i] && m_rows[i].parent)
				{
					m_rows[i].parent.removeChild(m_rows[i]);
				};
				i++;
			};
			m_rows = [];
			if (!m_listLayer)
			{
				return;
			};
			m_view = visibleItems();
			if (m_view.length == 0)
			{
				tf = makeLabel("No mods registered.", m_listLeft, m_listTop + 8, 13, 0xCCCCCC, false);
				m_listLayer.addChild(tf);
				m_rows.push(tf);
				return;
			};
			if (m_index >= m_view.length)
			{
				m_index = m_view.length - 1;
			};
			if (m_index < 0)
			{
				m_index = 0;
			};
			if (m_scroll > m_index)
			{
				m_scroll = m_index;
			};
			y = m_listTop;
			limitY = m_listBottom;
			lastSec = "\x00";
			// Carry section state from items above the scroll window.
			i = 0;
			while (i < m_scroll && i < m_view.length)
			{
				lastSec = String(m_view[i].section || "");
				i++;
			};
			i = m_scroll;
			while (i < m_view.length)
			{
				item = m_view[i];
				sec = String(item.section || "");
				if (sec != lastSec)
				{
					lastSec = sec;
					if (sec.length > 0)
					{
						if (y + SECTION_H > limitY)
						{
							break;
						};
						tf = makeLabel("— " + sec + " —", m_listLeft, y, 12, 0x8888AA, true);
						m_listLayer.addChild(tf);
						m_rows.push(tf);
						y += SECTION_H;
					};
				};
				if (y + ROW_H > limitY)
				{
					break;
				};
				label = String(item.label);
				if (item.guide)
				{
					label = "• " + label;
				};
				tf = makeLabel(label, m_listLeft, y, 15, 0xFFFFFF, false);
				tf.mouseEnabled = true;
				tf.selectable = false;
				tf.width = m_listWidth - 28;
				bindRow(tf, i);
				m_listLayer.addChild(tf);
				m_rows.push(tf);
				y += ROW_H;
				i++;
			};
			updateScrollThumb();
			paintSelection();
			updateBillboard();
		}

		private function updateScrollThumb():void
		{
			var track:Number;
			var maxScroll:int;
			var ratio:Number;
			if (!m_scrollThumb)
			{
				return;
			};
			track = m_listBottom - m_listTop;
			maxScroll = maxScrollIndex(track);
			if (maxScroll < 1)
			{
				m_scrollThumb.visible = false;
				return;
			};
			m_scrollThumb.visible = true;
			ratio = m_scroll / maxScroll;
			m_scrollThumb.y = ratio * (track - 48);
		}

		private function maxScrollIndex(track:Number):int
		{
			return (ModMenuScroll.maxScrollIndex(m_view, track));
		}

		private function bindRow(tf:TextField, index:int):void
		{
			tf.addEventListener(MouseEvent.MOUSE_OVER, function (e:MouseEvent):void
			{
				m_index = index;
				paintSelection();
				updateBillboard();
			});
			tf.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				activate(index);
			});
		}

		private function paintSelection():void
		{
			var i:int;
			var tf:TextField;
			var rowIndex:int;
			i = 0;
			rowIndex = m_scroll;
			while (i < m_rows.length)
			{
				if (m_rows[i] is TextField)
				{
					tf = TextField(m_rows[i]);
					if (tf.text && tf.text.indexOf("— ") == 0)
					{
						tf.textColor = 0x8888AA;
					}
					else
					{
						tf.textColor = (rowIndex == m_index) ? 0xE8A020 : 0xFFFFFF;
						rowIndex++;
					};
				};
				i++;
			};
		}

		private function updateBillboard():void
		{
			var item:Object;
			var notes:String;
			if (!m_billboard || m_index < 0 || m_index >= m_view.length)
			{
				m_billboardText = "";
				if (m_billboard)
				{
					m_billboard.text = "";
				};
				if (m_notesPanel)
				{
					m_notesPanel.text = "";
				};
				return;
			};
			item = m_view[m_index];
			notes = item && item.notes ? String(item.notes) : "";
			m_billboardText = String(item.label || "");
			m_billboard.text = m_billboardText;
			if (m_notesPanel)
			{
				m_notesPanel.text = notes.length > 0 ? notes : " ";
			};
		}

		private function tickBillboard():void
		{
			// Notes panel is static; no marquee needed on the right column.
		}

		private function activate(index:int):void
		{
			var item:Object;
			var fn:Function;
			if (index < 0 || index >= m_view.length)
			{
				return;
			};
			item = m_view[index];
			if (item.guide)
			{
				return;
			};
			fn = item.onSelect as Function;
			// Bind Hotkey stays open and listens — do not close first.
			if (String(item.id) == "__bind_hotkey__")
			{
				if (fn != null)
				{
					try
					{
						fn();
					}
					catch (bindErr:*)
					{
					};
				};
				return;
			};
			closeMenu();
			if (fn != null)
			{
				try
				{
					fn();
				}
				catch (err:Error)
				{
					trace("[mod_menu] onSelect " + item.id + ": " + err.message);
				};
			};
		}

		private function beginHotkeyBind():void
		{
			m_binding = true;
			m_bindWaitRelease = true;
			m_prevHotkeyDown = true;
			m_billboardText = "Press any key or controller button… (Esc cancel)";
			if (m_billboard)
			{
				m_billboard.text = m_billboardText;
			};
			if (m_notesPanel)
			{
				m_notesPanel.text = "Listening for hotkey. F1 stays as primary. Esc cancels without changing.";
			};
			if (m_hint)
			{
				m_hint.text = "Waiting for input…";
			};
		}

		private function cancelHotkeyBind():void
		{
			m_binding = false;
			m_bindWaitRelease = false;
			rebuildList();
			updateBillboard();
			if (m_hint)
			{
				m_hint.text = "F1/Esc close  A select  B back  Hold ↑↓ to scroll";
			};
		}

		private function finishHotkeyBindKey(code:uint):void
		{
			// Ignore the same confirm key that opened bind mode until release cycle.
			if (m_bindWaitRelease && (code == KEY_ENTER || code == KEY_SPACE || code == KEY_A || code == KEY_Z))
			{
				return;
			};
			m_hotkeyKind = "key";
			m_hotkeyCode = code;
			m_hotkeyPad = "";
			m_binding = false;
			m_bindWaitRelease = false;
			saveHotkey();
			rebuildList();
			updateBillboard();
			if (m_hint)
			{
				m_hint.text = "Hotkey saved: " + hotkeyDisplay();
			};
		}

		private function finishHotkeyBindPad(name:String):void
		{
			m_hotkeyKind = "pad";
			m_hotkeyPad = name;
			m_hotkeyCode = 0;
			m_binding = false;
			m_bindWaitRelease = false;
			saveHotkey();
			rebuildList();
			updateBillboard();
			if (m_hint)
			{
				m_hint.text = "Hotkey saved: " + hotkeyDisplay();
			};
		}

		private function hotkeyDisplay():String
		{
			if (m_hotkeyKind == "key" && m_hotkeyCode > 0)
			{
				return ("Key " + m_hotkeyCode);
			};
			if (m_hotkeyKind == "pad" && m_hotkeyPad)
			{
				return ("Pad " + m_hotkeyPad);
			};
			return ("(none)");
		}

		private function isHotkeyKey(code:uint):Boolean
		{
			return (m_hotkeyKind == "key" && m_hotkeyCode > 0 && code == m_hotkeyCode);
		}

		private function loadHotkey():void
		{
			var raw:*;
			var s:String;
			var parts:Array;
			try
			{
				if (m_host && m_host.saveExtGet is Function)
				{
					raw = m_host.saveExtGet(SAVE_HOTKEY, null);
				};
			}
			catch (err:*)
			{
			};
			if (!raw)
			{
				return;
			};
			s = String(raw);
			parts = s.split(":");
			if (parts.length < 2)
			{
				return;
			};
			if (parts[0] == "key")
			{
				m_hotkeyKind = "key";
				m_hotkeyCode = uint(parts[1]);
				m_hotkeyPad = "";
			}
			else if (parts[0] == "pad")
			{
				m_hotkeyKind = "pad";
				m_hotkeyPad = String(parts[1]);
				m_hotkeyCode = 0;
			};
		}

		private function saveHotkey():void
		{
			var val:String;
			if (m_hotkeyKind == "key")
			{
				val = "key:" + m_hotkeyCode;
			}
			else if (m_hotkeyKind == "pad")
			{
				val = "pad:" + m_hotkeyPad;
			}
			else
			{
				val = "";
			};
			try
			{
				if (m_host && m_host.saveExtSet is Function)
				{
					m_host.saveExtSet(SAVE_HOTKEY, val);
				};
			}
			catch (err:*)
			{
			};
		}

		private function armHotkeyPoll():void
		{
			var root:*;
			if (m_hotkeyPollArmed)
			{
				return;
			};
			root = resolveGameRoot();
			if (!root)
			{
				return;
			};
			m_hotkeyPollArmed = true;
			m_hotkeyRoot = root;
			root.addEventListener(Event.ENTER_FRAME, onHotkeyPoll);
		}

		private function disarmHotkeyPoll():void
		{
			if (m_hotkeyRoot)
			{
				m_hotkeyRoot.removeEventListener(Event.ENTER_FRAME, onHotkeyPoll);
			};
			m_hotkeyRoot = null;
			m_hotkeyPollArmed = false;
		}

		private function onHotkeyPoll(e:Event):void
		{
			var down:Boolean;
			if (m_open || m_binding || m_releaseHoldoff)
			{
				m_prevHotkeyDown = true;
				return;
			};
			down = isHotkeyPadDown();
			if (down && !m_prevHotkeyDown)
			{
				openMenu();
			};
			m_prevHotkeyDown = down;
		}

		private function isHotkeyPadDown():Boolean
		{
			if (m_hotkeyKind != "pad" || !m_hotkeyPad)
			{
				return (false);
			};
			return (padNamedDown(m_hotkeyPad));
		}

		private function firstPadDown():String
		{
			var i:int;
			var name:String;
			i = 0;
			while (i < PAD_BIND_NAMES.length)
			{
				name = String(PAD_BIND_NAMES[i]);
				i++;
				if (padNamedDown(name))
				{
					return (name);
				};
			};
			return (null);
		}

		private function padNamedDown(name:String):Boolean
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			var key:String;
			try
			{
				SD = EngineRefs.SaveData as Class;
				list = SD ? SD["Controllers"] : null;
				if (!list)
				{
					return (false);
				};
				key = "_" + name;
				i = 0;
				while (i < list.length)
				{
					c = list[i];
					i++;
					if (!c || !(c["IsDown"] is Function))
					{
						continue;
					};
					if (Boolean(c["IsDown"](c[key] != null ? c[key] : name, true)))
					{
						return (true);
					};
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function refreshGameSize():void
		{
			var MainCls:Class;
			m_gw = 853;
			m_gh = 480;
			try
			{
				MainCls = EngineRefs.Main as Class;
				if (MainCls)
				{
					if (MainCls["Width"])
					{
						m_gw = int(MainCls["Width"]);
					};
					if (MainCls["Height"])
					{
						m_gh = int(MainCls["Height"]);
					};
				};
			}
			catch (err:*)
			{
			};
		}

		private function resolveGameRoot():*
		{
			var MainCls:Class;
			try
			{
				MainCls = EngineRefs.Main as Class;
				if (MainCls && MainCls["Root"])
				{
					return (MainCls["Root"]);
				};
			}
			catch (err:*)
			{
			};
			try
			{
				if (m_host && m_host.stage)
				{
					return (m_host.stage);
				};
			}
			catch (err2:*)
			{
			};
			return (null);
		}

		private function makeLabel(text:String, x:int, y:int, size:int, color:uint, bold:Boolean):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.x = x;
			tf.y = y;
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", size, color, bold);
			tf.text = text;
			return (tf);
		}

		private function refreshNowPlaying():void
		{
			var i:int;
			var item:Object;
			var song:String;
			var fn:Function;
			var bestSong:String;
			if (!m_nowPlaying)
			{
				return;
			};
			bestSong = "";
			m_onNowPlaying = null;
			i = 0;
			while (i < m_items.length)
			{
				item = m_items[i];
				fn = item.nowPlaying as Function;
				if (fn != null)
				{
					try
					{
						song = String(fn() || "");
					}
					catch (err:*)
					{
						song = "";
					};
					if (m_onNowPlaying == null || String(item.id) == "music_player")
					{
						m_onNowPlaying = item.onNowPlaying as Function;
						if (m_onNowPlaying == null)
						{
							m_onNowPlaying = item.onSelect as Function;
						};
					};
					if (song.length > 0 && (bestSong.length < 1 || String(item.id) == "music_player"))
					{
						bestSong = song;
					};
				};
				i++;
			};
			m_nowPlaying.text = bestSong.length > 0 ? ("♪ " + bestSong) : "♪ —";
			m_nowPlaying.textColor = bestSong.length > 0 ? 0x88CCFF : 0x667788;
		}

		private function onNowPlayingClick(e:MouseEvent):void
		{
			var fn:Function;
			fn = m_onNowPlaying;
			if (fn == null)
			{
				// Fall back to first Music Player entry.
				var i:int;
				var item:Object;
				i = 0;
				while (i < m_items.length)
				{
					item = m_items[i];
					i++;
					if (item && String(item.id) == "music_player" && item.onSelect is Function)
					{
						fn = item.onSelect as Function;
						break;
					};
				};
			};
			if (fn == null)
			{
				return;
			};
			closeMenu();
			try
			{
				fn();
			}
			catch (err:*)
			{
			};
		}
	}
}
