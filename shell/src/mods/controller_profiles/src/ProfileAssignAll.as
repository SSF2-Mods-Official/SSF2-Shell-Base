package
{
	import ssf2mm.shared.EngineRefs;
	import flash.display.Sprite;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.ui.Keyboard;

	/**
	 * "Assign All" guided rebinding HUD on the Controls menu.
	 */
	public class ProfileAssignAll
	{
		private static const ASSIGN_STEPS:Array = [
			{"clip":"k1", "label":"Up"},
			{"clip":"k2", "label":"Jump"},
			{"clip":"k3", "label":"Pause"},
			{"clip":"k4", "label":"Grab"},
			{"clip":"k5", "label":"Shield"},
			{"clip":"k6", "label":"Left"},
			{"clip":"k7", "label":"Right"},
			{"clip":"k8", "label":"Taunt"},
			{"clip":"k9", "label":"Standard Attack"},
			{"clip":"k10", "label":"Down"},
			{"clip":"k11", "label":"Special Attack"},
			{"clip":"k12", "label":"Jump 2"},
			{"clip":"k13", "label":"C-Stick Up"},
			{"clip":"k14", "label":"C-Stick Down"},
			{"clip":"k15", "label":"C-Stick Left"},
			{"clip":"k16", "label":"C-Stick Right"},
			{"clip":"k17", "label":"Dash Button"},
			{"clip":"k18", "label":"Shield Button"}
		];

		internal var mod:ControllerProfilesMod;
		private var m_assignHud:Sprite;
		private var m_assignPrompt:TextField;
		private var m_assignSkip:TextField;
		private var m_assignCancel:TextField;
		private var m_assignWaiting:Boolean = false;
		private var m_assignSawOpen:Boolean = false;
		private var m_assignWaitFrames:int = 0;
		private var m_assignPendingStart:Boolean = false;
		private var m_assignCooldown:int = 0;
		private var m_assignIndex:int = 0;
		private var m_assignPid:int = 0;

		public function ProfileAssignAll(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		internal function onAssignAllClick(e:MouseEvent):void
		{
			e.stopImmediatePropagation();
			e.stopPropagation();
			if (mod.m_assignActive)
			{
				return;
			};
			startAssignAll();
		}

		private function startAssignAll():void
		{
			var play:int;
			if (!mod.m_controls)
			{
				return;
			};
			play = int(mod.m_controls["playNum"] || 1);
			mod.m_list.closeListFor(play);
			mod.m_manage.closeManageFor(play);
			m_assignPid = play;
			m_assignIndex = 0;
			mod.m_assignActive = true;
			m_assignWaiting = false;
			m_assignSawOpen = false;
			m_assignWaitFrames = 0;
			m_assignPendingStart = true;
			m_assignCooldown = 0;
			mod.m_bar.setControlsHandEnabled(false);
			showAssignHud();
			updateAssignHud();
			log("assign all start pid=" + play);
		}

		private function showAssignHud():void
		{
			var skipHit:Sprite;
			var cancelHit:Sprite;
			if (!m_assignHud)
			{
				m_assignHud = new Sprite();
				m_assignHud.name = "__ssf2mm_profiles_assign";
				m_assignPrompt = ProfileUi.menuText("Assign: —", 18, 0xFFFFFF);
				m_assignPrompt.selectable = false;
				m_assignPrompt.mouseEnabled = false;
				m_assignPrompt.x = 16;
				m_assignPrompt.y = 12;
				m_assignHud.addChild(m_assignPrompt);
				m_assignSkip = ProfileUi.menuText("Skip", 18, 0x33CC66);
				m_assignSkip.selectable = false;
				m_assignSkip.mouseEnabled = false;
				m_assignSkip.y = 12;
				skipHit = new Sprite();
				skipHit.buttonMode = true;
				skipHit.mouseChildren = false;
				skipHit.addChild(m_assignSkip);
				skipHit.addEventListener(MouseEvent.CLICK, onAssignSkipClick);
				skipHit.name = "__assignSkipHit";
				m_assignHud.addChild(skipHit);
				m_assignCancel = ProfileUi.menuText("Cancel", 18, 0xFF6666);
				m_assignCancel.selectable = false;
				m_assignCancel.mouseEnabled = false;
				m_assignCancel.y = 12;
				cancelHit = new Sprite();
				cancelHit.buttonMode = true;
				cancelHit.mouseChildren = false;
				cancelHit.addChild(m_assignCancel);
				cancelHit.addEventListener(MouseEvent.CLICK, onAssignCancelClick);
				cancelHit.name = "__assignCancelHit";
				m_assignHud.addChild(cancelHit);
			};
			layoutAssignHud();
			ProfileUi.rootAdd(m_assignHud);
			try
			{
				m_assignHud.parent.setChildIndex(m_assignHud, m_assignHud.parent.numChildren - 1);
			}
			catch (zErr:*)
			{
				log("showAssignHud failed: " + zErr);
			};
		}

		private function layoutAssignHud():void
		{
			var skipHit:Sprite;
			var cancelHit:Sprite;
			var xPos:Number;
			if (!m_assignPrompt || !m_assignSkip)
			{
				return;
			};
			m_assignSkip.x = 0;
			xPos = m_assignPrompt.x + m_assignPrompt.textWidth + 18;
			skipHit = m_assignHud.getChildByName("__assignSkipHit") as Sprite;
			if (skipHit)
			{
				skipHit.x = xPos;
				skipHit.y = m_assignPrompt.y;
				skipHit.graphics.clear();
				skipHit.graphics.beginFill(0x000000, 0);
				skipHit.graphics.drawRect(-4, -2, m_assignSkip.textWidth + 12, 24);
				skipHit.graphics.endFill();
				xPos = skipHit.x + m_assignSkip.textWidth + 20;
			};
			if (m_assignCancel)
			{
				m_assignCancel.x = 0;
				cancelHit = m_assignHud.getChildByName("__assignCancelHit") as Sprite;
				if (cancelHit)
				{
					cancelHit.x = xPos;
					cancelHit.y = m_assignPrompt.y;
					cancelHit.graphics.clear();
					cancelHit.graphics.beginFill(0x000000, 0);
					cancelHit.graphics.drawRect(-4, -2, m_assignCancel.textWidth + 12, 24);
					cancelHit.graphics.endFill();
				};
			};
		}

		private function updateAssignHud():void
		{
			var step:Object;
			if (!m_assignPrompt)
			{
				return;
			};
			if (m_assignIndex < 0 || m_assignIndex >= ASSIGN_STEPS.length)
			{
				m_assignPrompt.text = "Assign: —";
			}
			else
			{
				step = ASSIGN_STEPS[m_assignIndex];
				m_assignPrompt.text = "Assign: " + String(step["label"]);
			};
			layoutAssignHud();
		}

		private function hideAssignHud():void
		{
			if (m_assignHud && m_assignHud.parent)
			{
				try
				{
					m_assignHud.parent.removeChild(m_assignHud);
				}
				catch (rmErr:*)
				{
					log("hideAssignHud failed: " + rmErr);
				};
			};
		}

		private function onAssignSkipClick(e:MouseEvent):void
		{
			var stage:*;
			e.stopImmediatePropagation();
			e.stopPropagation();
			if (!mod.m_assignActive)
			{
				return;
			};
			log("assign skip idx=" + m_assignIndex);
			if (keySetterVisible())
			{
				stage = ProfileUi.gameStage();
				if (stage)
				{
					stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, false, 0, Keyboard.ESCAPE));
				};
			}
			else
			{
				m_assignWaiting = false;
				m_assignSawOpen = false;
				advanceAssignStep();
			};
		}

		private function onAssignCancelClick(e:MouseEvent):void
		{
			var stage:*;
			e.stopImmediatePropagation();
			e.stopPropagation();
			if (!mod.m_assignActive)
			{
				return;
			};
			log("assign cancel idx=" + m_assignIndex);
			if (keySetterVisible())
			{
				stage = ProfileUi.gameStage();
				if (stage)
				{
					stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, false, 0, Keyboard.ESCAPE));
				};
			};
			endAssignAll(false);
		}

		private function beginAssignStep():void
		{
			var sub:*;
			var step:Object;
			var btn:*;
			if (!mod.m_assignActive || !mod.m_controls)
			{
				endAssignAll(false);
				return;
			};
			if (m_assignIndex >= ASSIGN_STEPS.length)
			{
				endAssignAll(true);
				return;
			};
			sub = mod.m_controls["SubMenu"];
			step = ASSIGN_STEPS[m_assignIndex];
			updateAssignHud();
			btn = sub ? sub[String(step["clip"])] : null;
			if (!btn)
			{
				log("assign missing clip " + step["clip"]);
				m_assignIndex++;
				beginAssignStep();
				return;
			};
			m_assignWaiting = false;
			m_assignSawOpen = false;
			m_assignWaitFrames = 0;
			try
			{
				btn.dispatchEvent(new MouseEvent(MouseEvent.CLICK, true, false));
			}
			catch (clickErr:*)
			{
				log("assign click failed: " + clickErr);
				m_assignIndex++;
				beginAssignStep();
				return;
			};
			m_assignWaiting = true;
			log("assign step " + m_assignIndex + " " + step["label"]);
		}

		internal function pollAssignAll():void
		{
			if (!mod.m_assignActive)
			{
				return;
			};
			if (!mod.m_controls || !(mod.m_controls["isOnscreen"] && mod.m_controls["isOnscreen"]()))
			{
				endAssignAll(false);
				return;
			};
			if (m_assignCooldown > 0)
			{
				m_assignCooldown--;
				// Don't open the next prompt until the previous key/button is fully released.
				if (m_assignCooldown > 0 || assignInputHeld())
				{
					if (m_assignCooldown < 1 && assignInputHeld())
					{
						m_assignCooldown = 1;
					};
					return;
				};
				beginAssignStep();
				return;
			};
			if (m_assignPendingStart)
			{
				m_assignPendingStart = false;
				beginAssignStep();
				return;
			};
			if (!m_assignWaiting)
			{
				return;
			};
			if (keySetterVisible())
			{
				m_assignSawOpen = true;
				m_assignWaitFrames = 0;
				if (m_assignHud && m_assignHud.parent)
				{
					try
					{
						m_assignHud.parent.setChildIndex(m_assignHud, m_assignHud.parent.numChildren - 1);
					}
					catch (zErr:*)
					{
						// per-frame z-order keep; silent
					};
				};
				return;
			};
			if (m_assignSawOpen)
			{
				m_assignWaiting = false;
				m_assignSawOpen = false;
				advanceAssignStep();
				return;
			};
			m_assignWaitFrames++;
			if (m_assignWaitFrames > 20)
			{
				log("assign step timeout idx=" + m_assignIndex);
				m_assignWaiting = false;
				advanceAssignStep();
			};
		}

		private function advanceAssignStep():void
		{
			m_assignIndex++;
			if (m_assignIndex >= ASSIGN_STEPS.length)
			{
				endAssignAll(true);
				return;
			};
			// Gap so the key/button that finished this step can't bind the next one.
			m_assignCooldown = 18;
			updateAssignHud();
		}

		/** True while any likely assign input is still held (keyboard or pad). */
		private function assignInputHeld():Boolean
		{
			var SD:Class;
			var controller:*;
			var pad:*;
			var state:*;
			var id:String;
			var val:Number;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				controller = SD["Controllers"][m_assignPid - 1];
				if (!controller)
				{
					return (false);
				};
				pad = controller["GamepadInstance"];
				if (pad && pad["ControlState"])
				{
					for (id in pad["ControlState"])
					{
						state = pad["ControlState"][id];
						if (!state)
						{
							continue;
						};
						val = Number(state["value"]);
						if (Math.abs(val) >= Number(state["deadZone"] || 0.35))
						{
							return (true);
						};
					};
				}
				else if (controller["IsDown"] && (
					controller["IsDown"](controller["_UP"])
					|| controller["IsDown"](controller["_DOWN"])
					|| controller["IsDown"](controller["_LEFT"])
					|| controller["IsDown"](controller["_RIGHT"])
					|| controller["IsDown"](controller["_JUMP"])
					|| controller["IsDown"](controller["_JUMP2"])
					|| controller["IsDown"](controller["_BUTTON1"])
					|| controller["IsDown"](controller["_BUTTON2"])
					|| controller["IsDown"](controller["_GRAB"])
					|| controller["IsDown"](controller["_SHIELD"])
					|| controller["IsDown"](controller["_SHIELD2"])
					|| controller["IsDown"](controller["_TAUNT"])
					|| controller["IsDown"](controller["_START"])
					|| controller["IsDown"](controller["_DASH"])
					|| controller["IsDown"](controller["_C_UP"])
					|| controller["IsDown"](controller["_C_DOWN"])
					|| controller["IsDown"](controller["_C_LEFT"])
					|| controller["IsDown"](controller["_C_RIGHT"])
				))
				{
					return (true);
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function keySetterVisible():Boolean
		{
			var sub:*;
			var ks:*;
			if (!mod.m_controls)
			{
				return (false);
			};
			sub = mod.m_controls["SubMenu"];
			ks = sub ? sub["keySetter"] : null;
			return (Boolean(ks && ks.visible));
		}

		internal function endAssignAll(save:Boolean):void
		{
			var play:int;
			if (!mod.m_assignActive && !m_assignHud)
			{
				return;
			};
			mod.m_assignActive = false;
			m_assignWaiting = false;
			m_assignSawOpen = false;
			m_assignWaitFrames = 0;
			m_assignPendingStart = false;
			m_assignCooldown = 0;
			hideAssignHud();
			// Persist any bindings remapped before skip/cancel/finish.
			if (m_assignPid > 0)
			{
				mod.m_bar.cacheLiveDevice(m_assignPid, ProfileBlobs.deviceKey(m_assignPid));
				mod.m_bar.flushDeviceCache(m_assignPid, mod.m_deviceKey.length > 0 ? mod.m_deviceKey : ProfileBlobs.deviceKey(m_assignPid));
			};
			if (save)
			{
				try
				{
					if (mod.m_controls && mod.m_controls["updateControls"])
					{
						mod.m_controls["updateControls"]();
					};
				}
				catch (uErr:*)
				{
					log("endAssignAll failed: " + uErr);
				};
				log("assign all done pid=" + m_assignPid);
			}
			else
			{
				log("assign all end");
			};
			m_assignPid = 0;
			m_assignIndex = 0;
			if (mod.m_controls && !mod.m_bar.controlsUiOpen())
			{
				play = int(mod.m_controls["playNum"] || 1);
				if (mod.specialDown(play))
				{
					mod.m_controlsHandHoldoff = true;
				}
				else
				{
					mod.m_controlsHandHoldoff = false;
					mod.m_bar.setControlsHandEnabled(true);
				};
			};
		}
	}
}
