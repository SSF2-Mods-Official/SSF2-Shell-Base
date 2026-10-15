package
{
	import ssf2mm.shared.EngineRefs;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.text.TextField;
	import flash.ui.Keyboard;
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;

	/**
	 * Nametag picker on the CSS edit button, and a Profiles dropdown on Controls.
	 * A name and its keyboard / controller bindings (including tap jump, auto-dash,
	 * and d-tap dash) are stored together.
	 */
	public class ControllerProfilesMod extends Sprite
	{
		internal static const MAX_VISIBLE:int = 4;
		internal static const DEFAULT_TAG:String = "Default";

		private static var s_saveDataCls:Class;

		private var m_host:*;
		private var m_frameArmed:Boolean = false;
		private var m_levelBlocked:Boolean = false;
		internal var m_data:Object;
		/** Per-player dropdown/manage sessions (P1–P4 can all be open). */
		internal var m_sessions:Object;
		/** Sprite → player id for row/manage hit handlers. */
		internal var m_pidByUi:Dictionary;
		internal var m_nameEditArmed:Boolean = false;
		/** Player currently typing a new nametag (live field or popup). */
		internal var m_editPid:int = 0;
		internal var m_cssMenu:*;
		internal var m_controls:*;
		internal var m_profileBar:Sprite;
		internal var m_assignActive:Boolean = false;
		internal var m_addPopup:Sprite;
		internal var m_addField:TextField;
		internal var m_liveNameTxt:TextField;
		private var m_namePrevCancel:Boolean;
		private var m_chipHoldoffPid:int = 0;
		/** Keep Controls selectHand killed until Special is released after closing Profiles UI. */
		internal var m_controlsHandHoldoff:Boolean = false;
		internal var m_pendingTogglePid:int = 0;
		internal var m_toggleSyncFrames:int = 0;
		internal var m_deviceKey:String;
		/** Last live snapshot per device key while that device was active (avoids pad↔keyboard poison). */
		internal var m_deviceLiveCache:Object;
		internal var m_playNum:int;
		/** Sealed btn_keypad clips can't take dynamic props — map button → pid. */
		internal var m_editPidByBtn:Dictionary;
		internal var m_editHooked:Dictionary;

		internal var m_css:ProfileCssHooks;
		internal var m_tags:ProfileTags;
		internal var m_list:ProfileList;
		internal var m_manage:ProfileManage;
		internal var m_nameEdit:ProfileNameEdit;
		internal var m_bar:ProfileControlsBar;
		internal var m_assign:ProfileAssignAll;
		internal var m_blobs:ProfileBlobs;
		internal var m_ui:ProfileUi;

		public function ControllerProfilesMod()
		{
			super();
			m_data = {"names":[], "last":{}, "profiles":{}};
			m_sessions = {};
			m_pidByUi = new Dictionary(true);
			m_editPid = 0;
			m_deviceKey = "";
			m_deviceLiveCache = {};
			m_playNum = 1;
			m_editPidByBtn = new Dictionary(true);
			m_editHooked = new Dictionary(true);
			m_css = new ProfileCssHooks(this);
			m_tags = new ProfileTags(this);
			m_list = new ProfileList(this);
			m_manage = new ProfileManage(this);
			m_nameEdit = new ProfileNameEdit(this);
			m_bar = new ProfileControlsBar(this);
			m_assign = new ProfileAssignAll(this);
			m_blobs = new ProfileBlobs(this);
			m_ui = new ProfileUi(this);
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			loadData();
			if (!host)
			{
				return;
			};
			host.addHook("MENU_SHOW", onMenuShow);
			host.addHook("MENU_HIDE", onMenuHide);
			host.addHook("BEFORE_CHIP_UPDATE", onChip);
			host.addHook("CONTROLS_MENU_SHOW", onControlsShow);
			host.addHook("CSS_NAME_PENCIL", onNamePencil);
			host.addHook("KEY_EVENT", onKeyEvent);
			armStage();
		}

		public function onBootEnd():void
		{
			var stage:*;
			saveData();
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("MENU_SHOW", onMenuShow);
					m_host["removeHook"]("MENU_HIDE", onMenuHide);
					m_host["removeHook"]("BEFORE_CHIP_UPDATE", onChip);
					m_host["removeHook"]("CONTROLS_MENU_SHOW", onControlsShow);
					m_host["removeHook"]("CSS_NAME_PENCIL", onNamePencil);
					m_host["removeHook"]("KEY_EVENT", onKeyEvent);
				}
				catch (err:*)
				{
					log("onBootEnd failed: " + err);
				};
			};
			setFrameArmed(false);
			stage = ProfileUi.gameStage();
			if (stage)
			{
				stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKey);
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, m_css.onStagePencil, true);
				stage.removeEventListener(MouseEvent.CLICK, m_css.onStagePencil, true);
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, onOutsideClose, false);
				stage.removeEventListener(MouseEvent.MOUSE_WHEEL, m_list.onListWheel, true);
			};
			closeAllUi();
			m_nameEdit.closeAddPopup();
			m_nameEdit.endLiveNameEdit(false);
			m_assign.endAssignAll(false);
			m_host = null;
		}

		private function makeSession(pid:int):Object
		{
			return ({
				"pid":pid,
				"list":null,
				"listIndex":0,
				"rows":[],
				"listContent":null,
				"listMask":null,
				"listScroll":0,
				"listViewH":0,
				"listContentH":0,
				"manage":null,
				"manageRows":[],
				"manageIndex":0,
				"manageContent":null,
				"manageMask":null,
				"manageScroll":0,
				"manageViewH":0,
				"manageContentH":0,
				"outsideArmed":false,
				"prevUp":false,
				"prevDown":false,
				"prevOk":false,
				"prevCancel":false
			});
		}

		internal function sessionOf(pid:int):Object
		{
			var key:String;
			var s:Object;
			if (pid < 1)
			{
				return (null);
			};
			key = String(pid);
			s = m_sessions[key];
			if (!s)
			{
				s = makeSession(pid);
				m_sessions[key] = s;
			};
			return (s);
		}

		internal function sessionListOpen(s:Object):Boolean
		{
			return (s && s["list"] && s["list"].parent);
		}

		internal function sessionManageOpen(s:Object):Boolean
		{
			return (s && s["manage"] && s["manage"].parent);
		}

		private function sessionUiOpen(s:Object):Boolean
		{
			return (sessionListOpen(s) || sessionManageOpen(s));
		}

		internal function uiOpenFor(pid:int):Boolean
		{
			return (sessionUiOpen(m_sessions[String(pid)]));
		}

		private function anySessionUiOpen():Boolean
		{
			var key:String;
			for (key in m_sessions)
			{
				if (sessionUiOpen(m_sessions[key]))
				{
					return (true);
				};
			};
			return (false);
		}

		private function nameEditActive():Boolean
		{
			return (Boolean(m_liveNameTxt) || (m_addPopup && m_addPopup.parent));
		}

		private function closeAllUi():void
		{
			var key:String;
			for (key in m_sessions)
			{
				m_list.closeListFor(int(key));
				m_manage.closeManageFor(int(key));
			};
		}

		internal function pidFromUi(target:*):int
		{
			if (!target)
			{
				return (0);
			};
			if (m_pidByUi[target] != null)
			{
				return (int(m_pidByUi[target]));
			};
			try
			{
				if (target.parent && m_pidByUi[target.parent] != null)
				{
					return (int(m_pidByUi[target.parent]));
				};
				if (target.parent && target.parent.parent && m_pidByUi[target.parent.parent] != null)
				{
					return (int(m_pidByUi[target.parent.parent]));
				};
			}
			catch (err:*)
			{
			};
			return (0);
		}

		private function armStage():void
		{
			var stage:*;
			stage = ProfileUi.gameStage();
			if (!stage)
			{
				return;
			};
			setFrameArmed(false);
			stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKey);
			stage.removeEventListener(MouseEvent.MOUSE_DOWN, m_css.onStagePencil, true);
			stage.removeEventListener(MouseEvent.CLICK, m_css.onStagePencil, true);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKey);
			// Capture on stage — btn_keypad listeners alone often miss sealed/timeline hits.
			stage.addEventListener(MouseEvent.MOUSE_DOWN, m_css.onStagePencil, true, 100);
			stage.addEventListener(MouseEvent.CLICK, m_css.onStagePencil, true, 100);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onOutsideClose, false, 0);
			stage.addEventListener(MouseEvent.MOUSE_WHEEL, m_list.onListWheel, true, 0);
			log("stage armed");
		}

		internal function setFrameArmed(on:Boolean):void
		{
			var stage:*;
			if (on == m_frameArmed)
			{
				return;
			};
			stage = ProfileUi.gameStage();
			if (!stage)
			{
				return;
			};
			if (on)
			{
				stage.addEventListener(Event.ENTER_FRAME, onFrame);
			}
			else
			{
				stage.removeEventListener(Event.ENTER_FRAME, onFrame);
			};
			m_frameArmed = on;
		}

		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var q:String;
			var hasBoxes:Boolean;
			menu = ctx ? ctx["menu"] : null;
			if (!menu)
			{
				return;
			};
			q = getQualifiedClassName(menu);
			log("MENU_SHOW " + q);
			if (q.indexOf("ControlsMenu") >= 0)
			{
				setFrameArmed(true);
				m_bar.armControls(menu);
				return;
			};
			hasBoxes = ProfileCssHooks.menuHasCharBoxes(menu);
			if (q.indexOf("CharacterSelect") >= 0 || q.indexOf("VSMenu") >= 0
				|| q.indexOf("TrainingMenu") >= 0 || hasBoxes)
			{
				setFrameArmed(true);
				m_cssMenu = menu;
				m_css.hookEditButtons(menu);
				m_css.applyLastNames(menu);
				log("css hooked boxes=" + (hasBoxes ? ProfileCssHooks.charBoxCount(menu) : 0)
					+ " btn1=" + Boolean(ProfileCssHooks.findNameButton(menu, 1))
					+ " display1=" + Boolean(ProfileCssHooks.findNameDisplay(menu, 1)));
			};
		}

		private function onControlsShow(ctx:Object):void
		{
			var menu:*;
			menu = ctx ? ctx["menu"] : null;
			if (!menu)
			{
				try
				{
					var MC:Class = EngineRefs.ssf2("controllers.MenuController") as Class;
					menu = MC ? MC["controlsMenu"] : null;
				}
				catch (err:*)
				{
					menu = null;
				};
			};
			if (menu)
			{
				setFrameArmed(true);
				m_bar.armControls(menu);
			};
		}

		private function onMenuHide(ctx:Object):void
		{
			var menu:*;
			menu = ctx ? ctx["menu"] : null;
			if (menu && menu == m_cssMenu)
			{
				closeAllUi();
				m_cssMenu = null;
			};
			if (menu && menu == m_controls)
			{
				m_bar.saveActiveProfile();
				m_assign.endAssignAll(false);
				m_controls = null;
			};
			if (!m_cssMenu && !m_controls && !m_assignActive && !m_levelBlocked
				&& !anySessionUiOpen() && !nameEditActive())
			{
				setFrameArmed(false);
			};
		}

		/** Chip.as CSS_NAME_PENCIL — controller/keyboard pencil confirm. */
		private function onNamePencil(ctx:Object):void
		{
			var pid:int;
			var btn:*;
			var menu:*;
			if (!ctx)
			{
				return;
			};
			pid = int(ctx["playerId"] || 0);
			menu = ctx["menu"];
			btn = ctx["button"];
			if (menu)
			{
				m_cssMenu = menu;
			};
			if (pid < 1)
			{
				return;
			};
			if (!btn)
			{
				btn = ProfileCssHooks.findNameButton(m_cssMenu, pid);
			};
			ctx["cancel"] = true;
			setFrameArmed(true);
			log("CSS_NAME_PENCIL pid=" + pid);
			m_nameEdit.hideStockKeypad(pid);
			m_list.openList(pid, btn);
		}

		private function onChip(ctx:Object):void
		{
			var chip:*;
			var hand:*;
			var hitBox:*;
			var pid:int;
			var menu:*;
			var btn:*;
			var over:Boolean;
			var attack:Boolean;
			if (!ctx)
			{
				return;
			};
			pid = int(ctx["playerId"] || 0);
			if (!pid && ctx["chip"])
			{
				try
				{
					pid = int(ctx["chip"]["PlayerID"]);
				}
				catch (idErr:*)
				{
					pid = 0;
				};
			};
			// Freeze only players who have a dropdown/manage open, or who are typing a name.
			if (uiOpenFor(pid) || (nameEditActive() && pid == m_editPid))
			{
				blockLevel(true);
				ctx["cancel"] = true;
				return;
			};
			if (pid < 1 && (anySessionUiOpen() || nameEditActive()))
			{
				ctx["cancel"] = true;
				return;
			};
			if (m_chipHoldoffPid > 0)
			{
				if (attackDown(m_chipHoldoffPid) || specialDown(m_chipHoldoffPid))
				{
					if (pid == m_chipHoldoffPid || pid < 1)
					{
						ctx["cancel"] = true;
						return;
					};
				}
				else
				{
					m_chipHoldoffPid = 0;
				};
			};
			chip = ctx["chip"];
			if (!chip)
			{
				return;
			};
			menu = ctx["menu"];
			if (menu)
			{
				m_cssMenu = menu;
			};
			hand = chip["HandMC"];
			hitBox = hand ? hand["hitBox"] : null;
			if (!pid)
			{
				pid = int(chip["PlayerID"] || 0);
			};
			btn = ProfileCssHooks.findNameButton(m_cssMenu, pid);
			if (!btn || !hitBox)
			{
				return;
			};
			over = false;
			try
			{
				over = hitBox.hitTestObject(btn);
			}
			catch (hitErr:*)
			{
				over = false;
			};
			if (!over)
			{
				return;
			};
			// Match Chip.checkGrab: BUTTON2 edge opens the name UI.
			attack = navDown(pid, "BUTTON2");
			if (attack)
			{
				var s:Object;
				s = sessionOf(pid);
				blockLevel(true);
				ctx["cancel"] = true;
				if (!s["prevOk"])
				{
					s["prevOk"] = true;
					log("chip pencil pid=" + pid);
					m_nameEdit.hideStockKeypad(pid);
					m_list.openList(pid, btn);
				};
			};
		}

		private function blockLevel(on:Boolean):void
		{
			m_levelBlocked = on;
			if (m_host && m_host["setSessionFlag"] != null)
			{
				m_host["setSessionFlag"]("css.blockLevel", on);
			};
		}

		private function releaseLevelBlock():void
		{
			var pid:int;
			if (!m_levelBlocked || anySessionUiOpen() || nameEditActive())
			{
				return;
			};
			pid = 1;
			while (pid <= 4)
			{
				if (attackDown(pid))
				{
					return;
				};
				pid++;
			};
			blockLevel(false);
		}

		private function onFrame(e:Event):void
		{
			var pid:int;
			var s:Object;
			var up:Boolean;
			var down:Boolean;
			var ok:Boolean;
			var cancel:Boolean;
			releaseLevelBlock();
			pid = 1;
			while (pid <= 4)
			{
				s = m_sessions[String(pid)];
				if (sessionManageOpen(s))
				{
					up = navDown(pid, "UP");
					down = navDown(pid, "DOWN");
					ok = attackDown(pid);
					cancel = specialDown(pid);
					if (up && !s["prevUp"])
					{
						m_manage.moveManage(pid, -1);
					};
					if (down && !s["prevDown"])
					{
						m_manage.moveManage(pid, 1);
					};
					if (ok && !s["prevOk"])
					{
						m_manage.chooseManage(pid);
					};
					if (cancel && !s["prevCancel"])
					{
						armChipHoldoff(pid);
						m_manage.closeManageFor(pid);
					};
					s["prevUp"] = up;
					s["prevDown"] = down;
					s["prevOk"] = ok;
					s["prevCancel"] = cancel;
					if (!s["outsideArmed"])
					{
						s["outsideArmed"] = true;
					};
				}
				else if (sessionListOpen(s))
				{
					up = navDown(pid, "UP");
					down = navDown(pid, "DOWN");
					ok = attackDown(pid);
					cancel = specialDown(pid);
					if (up && !s["prevUp"])
					{
						m_list.moveList(pid, -1);
					};
					if (down && !s["prevDown"])
					{
						m_list.moveList(pid, 1);
					};
					if (ok && !s["prevOk"])
					{
						m_list.chooseList(pid);
					};
					if (cancel && !s["prevCancel"])
					{
						armChipHoldoff(pid);
						m_list.closeListFor(pid);
					};
					s["prevUp"] = up;
					s["prevDown"] = down;
					s["prevOk"] = ok;
					s["prevCancel"] = cancel;
					if (!s["outsideArmed"])
					{
						s["outsideArmed"] = true;
					};
				}
				else if (s)
				{
					s["prevOk"] = false;
					s["prevCancel"] = false;
					s["outsideArmed"] = false;
				};
				pid++;
			};
			if (m_assignActive)
			{
				m_assign.pollAssignAll();
			};
			if (nameEditActive())
			{
				var nameCancel:Boolean;
				m_nameEdit.hideStockKeypad(m_editPid);
				if (!m_nameEditArmed)
				{
					m_nameEditArmed = true;
				};
				// Special / back cancels new nametag → Default (P#).
				nameCancel = specialDown(m_editPid);
				if (nameCancel && !m_namePrevCancel)
				{
					m_nameEdit.cancelNameEditToDefault();
				};
				m_namePrevCancel = nameCancel;
			}
			else
			{
				m_nameEditArmed = false;
				m_namePrevCancel = false;
			};
			if (m_pendingTogglePid > 0 || m_toggleSyncFrames > 0)
			{
				var syncPid:int;
				syncPid = m_pendingTogglePid > 0 ? m_pendingTogglePid : m_playNum;
				m_bar.syncToggleCheckboxes(syncPid);
				m_pendingTogglePid = 0;
				if (m_toggleSyncFrames > 0)
				{
					m_toggleSyncFrames--;
				};
			};
			pollControlsMenu();
			pollControlsHandHoldoff();
			m_css.pollCssMenu();
			if (m_controls && m_controls["playNum"])
			{
				m_bar.syncControls();
			};
		}

		private function pollControlsHandHoldoff():void
		{
			var play:int;
			if (!m_controlsHandHoldoff || !m_controls)
			{
				return;
			};
			play = int(m_controls["playNum"] || 1);
			if (specialDown(play))
			{
				return;
			};
			m_controlsHandHoldoff = false;
			if (!m_bar.controlsUiOpen())
			{
				m_bar.setControlsHandEnabled(true);
			};
		}

		private function pollControlsMenu():void
		{
			var MC:Class;
			var menu:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				menu = MC ? MC["controlsMenu"] : null;
				if (menu && menu["isOnscreen"] && menu["isOnscreen"]())
				{
					if (m_controls != menu || !m_profileBar || !m_profileBar.parent)
					{
						m_bar.armControls(menu);
					};
				}
				else if (m_controls && menu && m_controls == menu)
				{
					m_bar.saveActiveProfile();
					m_controls = null;
				};
			}
			catch (err:*)
			{
			};
		}

		private function onKey(e:KeyboardEvent):void
		{
			// Navigation is handled in onFrame via controller IsDown (keyboard + pad).
			// Handling keys here too double-fires and skips every other row.
			if (e.keyCode != Keyboard.ESCAPE)
			{
				return;
			};
			if (anySessionUiOpen())
			{
				closeAllUi();
			};
		}

		internal function armChipHoldoff(pid:int):void
		{
			if (pid > 0)
			{
				m_chipHoldoffPid = pid;
			};
		}

		private function onOutsideClose(e:MouseEvent):void
		{
			var pid:int;
			var s:Object;
			// Click outside while typing a new nametag → cancel to Default.
			if (m_liveNameTxt)
			{
				if (!m_nameEditArmed)
				{
					return;
				};
				if (ProfileUi.hitTextField(m_liveNameTxt, e.stageX, e.stageY))
				{
					return;
				};
				m_nameEdit.cancelNameEditToDefault();
				return;
			};
			if (m_addPopup && m_addPopup.parent)
			{
				if (!m_nameEditArmed)
				{
					return;
				};
				if (ProfileUi.hitSprite(m_addPopup, e.stageX, e.stageY))
				{
					return;
				};
				m_nameEdit.cancelNameEditToDefault();
				return;
			};
			pid = 1;
			while (pid <= 4)
			{
				s = m_sessions[String(pid)];
				if (!s || !s["outsideArmed"])
				{
					pid++;
					continue;
				};
				if (sessionManageOpen(s))
				{
					if (!ProfileUi.hitSprite(s["manage"], e.stageX, e.stageY))
					{
						armChipHoldoff(pid);
						m_manage.closeManageFor(pid);
					};
				}
				else if (sessionListOpen(s))
				{
					if (!ProfileUi.hitSprite(s["list"], e.stageX, e.stageY))
					{
						armChipHoldoff(pid);
						m_list.closeListFor(pid);
					};
				};
				pid++;
			};
		}

		/** Block CSS/menu key handling while typing a nametag (TextField still receives focus input). */
		private function onKeyEvent(ctx:Object):void
		{
			if (!ctx)
			{
				return;
			};
			if (m_liveNameTxt || (m_addPopup && m_addPopup.parent && m_addField))
			{
				ctx["cancel"] = true;
			};
		}

		private function attackDown(pid:int):Boolean
		{
			// Attack / confirm (A / BUTTON2)
			return (navDown(pid, "BUTTON2"));
		}

		internal function specialDown(pid:int):Boolean
		{
			// Special / back (B / BUTTON1)
			return (navDown(pid, "BUTTON1"));
		}

		internal static function saveDataClass():Class
		{
			if (!s_saveDataCls)
			{
				s_saveDataCls = EngineRefs.ssf2("util.SaveData") as Class;
			};
			return (s_saveDataCls);
		}

		private function navDown(pid:int, which:String):Boolean
		{
			var SD:Class;
			var controller:*;
			try
			{
				SD = saveDataClass();
				controller = SD["Controllers"][pid - 1];
				if (!controller)
				{
					return (false);
				};
				if (which == "UP")
				{
					return (Boolean(controller["IsDown"](controller["_UP"])));
				};
				if (which == "DOWN")
				{
					return (Boolean(controller["IsDown"](controller["_DOWN"])));
				};
				if (which == "BUTTON1")
				{
					return (Boolean(controller["IsDown"](controller["_BUTTON1"])));
				};
				return (Boolean(controller["IsDown"](controller["_BUTTON2"])));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal static function log(msg:String):void
		{
			var GL:Class;
			var API:Class;
			var line:String;
			line = "[controller_profiles] " + msg;
			try
			{
				API = EngineRefs.ssf2("api.SSF2API") as Class;
				if (API && API["print"] is Function)
				{
					API["print"](line);
				};
			}
			catch (apiErr:*)
			{
			};
			try
			{
				GL = EngineRefs.ssf2("util.GameLog") as Class;
				if (GL && GL["write"])
				{
					GL["write"](line);
					return;
				};
			}
			catch (err:*)
			{
			};
			trace(line);
		}

		private function loadData():void
		{
			var got:Object = ProfileStore.load(File.applicationDirectory, File.applicationStorageDirectory);
			m_data = got.data;
			if (got.from)
			{
				log("profiles loaded from " + File(got.from).nativePath + " names=" + (m_data["names"] as Array).length);
			};
			if (got.from && File(got.from).nativePath != ProfileStore.stateFile(File.applicationDirectory).nativePath)
			{
				log("profiles migrated to " + ProfileStore.STATE_REL + " saved=" + ProfileStore.save(File.applicationDirectory, m_data));
			};
		}

		internal function saveData():void
		{
			if (!ProfileStore.save(File.applicationDirectory, m_data))
			{
				log("profiles save failed " + ProfileStore.STATE_REL);
			};
		}
	}
}
