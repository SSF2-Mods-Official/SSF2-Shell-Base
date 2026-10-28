package
{
	import ssf2mm.shared.EngineRefs;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;

	/**
	 * Controls menu Profiles bar: device sync, apply/save profile blobs, toggle checkboxes.
	 */
	public class ProfileControlsBar
	{
		/** Idle Controls snapshot interval (frames); device and player switches snapshot at once. */
		private static const CACHE_EVERY:int = 10;

		internal var mod:ControllerProfilesMod;
		private var m_cacheTick:int = 0;
		private var m_profileLabel:TextField;
		private var m_profileText:TextField;
		private var m_assignAllTxt:TextField;
		private var m_assignAllHit:Sprite;

		public function ProfileControlsBar(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		internal function armControls(menu:*):void
		{
			var sub:*;
			var drop:*;
			var cleft:*;
			var fmt:TextFormat;
			var halfW:Number;
			var barX:Number;
			var ref:*;
			var idx:int;
			mod.m_controls = menu;
			sub = menu["SubMenu"];
			if (!sub)
			{
				return;
			};
			drop = sub["gamepadDropdown"];
			if (!drop)
			{
				return;
			};
			if (!m_profileLabel)
			{
				fmt = ProfileUi.textFormatFrom(sub["autoDashTxt"] || sub["rumbleTxt"]);
				m_profileLabel = ProfileUi.menuText("Profiles", 16, 0xFFFFFF);
				if (fmt)
				{
					m_profileLabel.defaultTextFormat = fmt;
					m_profileLabel.setTextFormat(fmt);
				};
				ProfileUi.copyFilters(sub["autoDashTxt"] || sub["rumbleTxt"], m_profileLabel);
				mod.m_profileBar = new Sprite();
				mod.m_profileBar.buttonMode = true;
				mod.m_profileBar.addEventListener(MouseEvent.CLICK, onProfileBar);
				m_profileText = new TextField();
				m_profileText.selectable = false;
				m_profileText.mouseEnabled = false;
				m_profileText.defaultTextFormat = new TextFormat("Arial", 13, 0x111111, true);
				m_profileText.text = ControllerProfilesMod.DEFAULT_TAG;
				m_profileText.x = 8;
				m_profileText.y = 2;
				m_profileText.height = 20;
				mod.m_profileBar.addChild(m_profileText);
				m_assignAllTxt = ProfileUi.menuText("Assign All", 14, 0x33CC66);
				m_assignAllTxt.selectable = false;
				m_assignAllTxt.mouseEnabled = false;
				if (fmt)
				{
					m_assignAllTxt.defaultTextFormat = new TextFormat(
						fmt.font, 14, 0x33CC66, fmt.bold, fmt.italic, fmt.underline);
					m_assignAllTxt.setTextFormat(m_assignAllTxt.defaultTextFormat);
				};
				ProfileUi.copyFilters(sub["autoDashTxt"] || sub["rumbleTxt"], m_assignAllTxt);
			};
			if (!m_assignAllHit)
			{
				m_assignAllHit = new Sprite();
				m_assignAllHit.buttonMode = true;
				m_assignAllHit.mouseChildren = false;
				m_assignAllHit.addChild(m_assignAllTxt);
				m_assignAllHit.addEventListener(MouseEvent.CLICK, mod.m_assign.onAssignAllClick);
			};
			// Keep Profiles at checkbox/graphics depth — not above the whole Controls menu.
			ref = sub["autoDashTxt"] || sub["tapJumpTxt"] || sub["rumbleTxt"] || drop;
			idx = -1;
			try
			{
				if (ref && ref.parent == sub)
				{
					idx = int(sub.getChildIndex(ref));
				};
			}
			catch (idxErr:*)
			{
				idx = -1;
			};
			if (m_profileLabel.parent != sub)
			{
				if (idx >= 0)
				{
					sub.addChildAt(m_profileLabel, Math.min(idx + 1, sub.numChildren));
					sub.addChildAt(mod.m_profileBar, Math.min(idx + 2, sub.numChildren));
					sub.addChildAt(m_assignAllHit, Math.min(idx + 3, sub.numChildren));
				}
				else
				{
					sub.addChild(m_profileLabel);
					sub.addChild(mod.m_profileBar);
					sub.addChild(m_assignAllHit);
				};
			}
			else if (m_assignAllHit.parent != sub)
			{
				if (idx >= 0)
				{
					sub.addChildAt(m_assignAllHit, Math.min(idx + 3, sub.numChildren));
				}
				else
				{
					sub.addChild(m_assignAllHit);
				};
			};
			halfW = Number(drop.width) > 20 ? Number(drop.width) * 0.5 : 90;
			if (halfW < 90)
			{
				halfW = 90;
			};
			// Align under C-LEFT, slightly to the right of prior placement.
			barX = Number(drop.x);
			cleft = sub["k15"] || sub["key_cleft"];
			if (cleft)
			{
				try
				{
					barX = Number(cleft.x);
				}
				catch (cErr:*)
				{
					log("armControls failed: " + cErr);
				};
			};
			barX = barX + 10;
			mod.m_profileBar.x = barX;
			m_profileLabel.x = mod.m_profileBar.x;
			m_assignAllHit.x = mod.m_profileBar.x;
			m_profileLabel.y = Number(drop.y) + 2;
			mod.m_profileBar.y = Number(drop.y) + 28;
			m_assignAllHit.y = mod.m_profileBar.y + 26;
			m_assignAllHit.graphics.clear();
			m_assignAllHit.graphics.beginFill(0x000000, 0);
			m_assignAllHit.graphics.drawRect(0, 0, m_assignAllTxt.textWidth + 8, 22);
			m_assignAllHit.graphics.endFill();
			drawBar(halfW);
			mod.m_playNum = int(menu["playNum"] || 1);
			mod.m_deviceKey = ProfileBlobs.deviceKey(mod.m_playNum);
			syncProfileToTag();
			refreshProfileBar();
			cacheLiveDevice(mod.m_playNum, mod.m_deviceKey);
			mod.m_toggleSyncFrames = 4;
			hookControlsHandTargets();
		}

		/** Let the Controls menu hand cursor attack-click Profiles / Assign All. */
		private function hookControlsHandTargets():void
		{
			var hand:*;
			if (!mod.m_controls)
			{
				return;
			};
			try
			{
				hand = mod.m_controls["selectHand"];
				if (!hand || !hand["addClickEventClipCheckBounds"])
				{
					return;
				};
				if (mod.m_profileBar)
				{
					hand["addClickEventClipCheckBounds"](mod.m_profileBar);
				};
				if (m_assignAllHit)
				{
					hand["addClickEventClipCheckBounds"](m_assignAllHit);
				};
			}
			catch (err:*)
			{
				log("hookControlsHandTargets failed: " + err);
			};
		}

		internal function setControlsHandEnabled(on:Boolean):void
		{
			var hand:*;
			if (!mod.m_controls)
			{
				return;
			};
			try
			{
				hand = mod.m_controls["selectHand"];
				if (!hand)
				{
					return;
				};
				// SelectHand has no "enabled" flag — kill/makeEvents gates BUTTON1 back.
				if (on)
				{
					if (hand["makeEvents"] is Function)
					{
						hand["makeEvents"]();
					};
					hookControlsHandTargets();
				}
				else if (hand["killEvents"] is Function)
				{
					hand["killEvents"]();
				};
			}
			catch (err:*)
			{
				log("setControlsHandEnabled failed: " + err);
			};
		}

		internal function controlsUiOpen():Boolean
		{
			var play:int;
			if (!mod.m_controls)
			{
				return (false);
			};
			play = int(mod.m_controls["playNum"] || 1);
			return (mod.uiOpenFor(play) || mod.m_assignActive);
		}

		private function drawBar(w:Number):void
		{
			mod.m_profileBar.graphics.clear();
			mod.m_profileBar.graphics.beginFill(0xD0D0D0, 1);
			mod.m_profileBar.graphics.drawRect(0, 0, w, 22);
			mod.m_profileBar.graphics.endFill();
			m_profileText.width = w - 16;
		}

		private function onProfileBar(e:MouseEvent):void
		{
			var play:int;
			if (!mod.m_profileBar)
			{
				return;
			};
			if (mod.m_assignActive)
			{
				return;
			};
			play = int(mod.m_controls["playNum"] || 1);
			log("controls Profiles click play=" + play);
			mod.m_list.openList(play, mod.m_profileBar);
		}

		internal function syncControls():void
		{
			var play:int;
			var key:String;
			var oldKey:String;
			if (!mod.m_controls)
			{
				return;
			};
			play = int(mod.m_controls["playNum"] || 1);
			key = ProfileBlobs.deviceKey(play);
			if (play != mod.m_playNum)
			{
				flushDeviceCache(mod.m_playNum, mod.m_deviceKey);
				mod.m_playNum = play;
				mod.m_deviceKey = key;
				mod.m_deviceLiveCache = {};
				syncProfileToTag();
				refreshProfileBar();
				mod.m_pendingTogglePid = play;
				mod.m_toggleSyncFrames = 8;
				return;
			};
			if (key != mod.m_deviceKey)
			{
				oldKey = mod.m_deviceKey;
				// Persist the outgoing device from the last good snapshot taken while
				// it was active — live toggles may already match the NEW device.
				flushDeviceCache(play, oldKey);
				mod.m_deviceKey = key;
				applyProfile(play, mod.m_tags.currentProfileName(play), true);
				refreshProfileBar();
				mod.m_pendingTogglePid = play;
				mod.m_toggleSyncFrames = 8;
				cacheLiveDevice(play, key);
				return;
			};
			if (++m_cacheTick >= CACHE_EVERY)
			{
				m_cacheTick = 0;
				cacheLiveDevice(play, key);
			};
		}

		/** Snapshot live controls into cache for the active device key. */
		internal function cacheLiveDevice(pid:int, key:String):void
		{
			var blob:Object;
			if (!key || key.length < 1)
			{
				return;
			};
			blob = ProfileBlobs.snapshotLiveBlob(pid);
			if (blob)
			{
				mod.m_deviceLiveCache[key] = blob;
			};
		}

		/** Write cached (or live) blob for a device into the active profile. */
		internal function flushDeviceCache(pid:int, key:String):void
		{
			var name:String;
			var profile:Object;
			var blob:Object;
			if (!key || key.length < 1 || pid < 1)
			{
				return;
			};
			name = mod.m_tags.currentProfileName(pid);
			if (name.length < 1)
			{
				return;
			};
			blob = mod.m_deviceLiveCache[key] as Object;
			if (!blob)
			{
				// Fallback: only safe if deviceKey still matches key.
				if (ProfileBlobs.deviceKey(pid) == key)
				{
					blob = ProfileBlobs.snapshotLiveBlob(pid);
				};
			};
			if (!blob)
			{
				return;
			};
			profile = mod.m_data["profiles"][name];
			if (!profile)
			{
				profile = name == ControllerProfilesMod.DEFAULT_TAG ? ProfileBlobs.seedDefaultProfile(pid) : mod.m_blobs.seedProfile(pid);
				mod.m_data["profiles"][name] = profile;
			};
			if (key == "keyboard")
			{
				profile["keyboard"] = blob;
				if (name == ControllerProfilesMod.DEFAULT_TAG)
				{
					try
					{
						var SD:Class = EngineRefs.ssf2("util.SaveData") as Class;
						SD["ControlSettings"]["player" + pid] = ProfileBlobs.copyOut(blob["controls"]);
					}
					catch (csErr:*)
					{
						log("flushDeviceCache failed: " + csErr);
					};
				};
			}
			else
			{
				if (!profile["pads"])
				{
					profile["pads"] = {};
				};
				profile["pads"][key] = blob;
			};
			mod.saveData();
		}

		private function syncProfileToTag():void
		{
			var name:String;
			var play:int;
			play = int(mod.m_controls["playNum"] || 1);
			name = ProfileTags.playerTag(play);
			if (name.length < 1)
			{
				name = String(mod.m_data["last"][String(play)] || "");
			};
			if (name.length > 0)
			{
				mod.m_data["last"][String(play)] = name;
				applyProfile(play, name, false);
			};
		}

		internal function refreshProfileBar():void
		{
			var name:String;
			if (!m_profileText || !mod.m_controls)
			{
				return;
			};
			name = String(mod.m_data["last"][String(int(mod.m_controls["playNum"] || 1))] || ControllerProfilesMod.DEFAULT_TAG);
			if (name.length < 1)
			{
				name = ControllerProfilesMod.DEFAULT_TAG;
			};
			m_profileText.text = name;
		}

		internal function applyProfile(pid:int, name:String, blankIfMissing:Boolean):void
		{
			var profile:Object;
			var key:String;
			var blob:Object;
			if (!name)
			{
				return;
			};
			// Default is stored per-device like named tags so pad toggles don't contaminate keyboard.
			profile = mod.m_data["profiles"][name];
			if (!profile)
			{
				profile = name == ControllerProfilesMod.DEFAULT_TAG ? ProfileBlobs.seedDefaultProfile(pid) : mod.m_blobs.seedProfile(pid);
				mod.m_data["profiles"][name] = profile;
			};
			key = ProfileBlobs.deviceKey(pid);
			blob = key == "keyboard" ? profile["keyboard"] : (profile["pads"] ? profile["pads"][key] : null);
			if (!blob)
			{
				blob = key == "keyboard"
					? (name == ControllerProfilesMod.DEFAULT_TAG ? ProfileBlobs.defaultGameKeyboardBlob(pid) : ProfileBlobs.stockKeyboardBlob(pid))
					: ProfileBlobs.stockPadBlob(pid);
				if (key == "keyboard")
				{
					profile["keyboard"] = blob;
				}
				else
				{
					if (!profile["pads"])
					{
						profile["pads"] = {};
					};
					profile["pads"][key] = blob;
				};
			}
			else if (key != "keyboard" && (!blob["padInputs"] || ProfileBlobs.isEmptyObject(blob["padInputs"])))
			{
				// Older saves only had ControlsMap — seed real pad inputs from live once.
				blob["padInputs"] = ProfileBlobs.readLivePadInputs(pid) || {};
			};
			pushBlobToController(pid, blob);
			mod.m_pendingTogglePid = pid;
		}

		/** Game's normally saved ControlSettings (and pad map when a pad is active). */
		private function applyGameDefault(pid:int):void
		{
			var SD:Class;
			var controller:*;
			var stored:*;
			var controls:Object;
			var pad:*;
			var padStored:*;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				controller = SD["Controllers"][pid - 1];
				if (!controller)
				{
					return;
				};
				stored = SD["ControlSettings"] ? SD["ControlSettings"]["player" + pid] : null;
				if (stored)
				{
					controls = ProfileBlobs.copyOut(stored);
				}
				else
				{
					controls = ProfileBlobs.stockKeyboardControls(pid);
				};
				controller["setControls"](controls);
				// Always force toggles to 0/1 so uncheck applies (missing keys clear).
				controller["_TAP_JUMP"] = toggleBit(controls, "TAP_JUMP");
				controller["_AUTO_DASH"] = toggleBit(controls, "AUTO_DASH");
				controller["_DT_DASH"] = toggleBit(controls, "DT_DASH");
				pad = controller["GamepadInstance"];
				if (pad && pad["Name"] && SD["Gamepads"] && SD["Gamepads"][pad["Name"]])
				{
					padStored = SD["Gamepads"][pad["Name"]]["controls"];
					if (padStored)
					{
						ProfileBlobs.copyFields(padStored, pad["ControlsMap"]);
					};
					pad["ControlsMap"]["TAP_JUMP"] = controller["_TAP_JUMP"];
					pad["ControlsMap"]["AUTO_DASH"] = controller["_AUTO_DASH"];
					pad["ControlsMap"]["DT_DASH"] = controller["_DT_DASH"];
				};
				syncToggleCheckboxes(pid);
			}
			catch (err:*)
			{
				log("applyGameDefault failed: " + err);
			};
		}

		private function pushBlobToController(pid:int, blob:Object):void
		{
			var SD:Class;
			var controller:*;
			var controls:Object;
			var pad:*;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				controller = SD["Controllers"][pid - 1];
				if (!controller || !blob)
				{
					return;
				};
				controls = blob["controls"];
				if (controller["setControls"] && controls)
				{
					controller["setControls"](controls);
				};
				// Always write 0/1 — missing/false must clear checked boxes.
				controller["_TAP_JUMP"] = toggleBit(controls, "TAP_JUMP");
				controller["_AUTO_DASH"] = toggleBit(controls, "AUTO_DASH");
				controller["_DT_DASH"] = toggleBit(controls, "DT_DASH");
				pad = controller["GamepadInstance"];
				if (pad)
				{
					if (blob["pad"])
					{
						ProfileBlobs.copyFields(blob["pad"], pad["ControlsMap"]);
					};
					pad["ControlsMap"]["TAP_JUMP"] = controller["_TAP_JUMP"];
					pad["ControlsMap"]["AUTO_DASH"] = controller["_AUTO_DASH"];
					pad["ControlsMap"]["DT_DASH"] = controller["_DT_DASH"];
					// Real hardware→action map is per-profile in padInputs.
					if (blob["padInputs"])
					{
						ProfileBlobs.writeLivePadInputs(pid, blob["padInputs"]);
					};
				};
				syncToggleCheckboxes(pid);
				if (mod.m_controls && mod.m_controls["updateControls"] && int(mod.m_controls["playNum"] || 0) == pid)
				{
					mod.m_controls["updateControls"]();
				};
			}
			catch (err:*)
			{
				log("pushBlobToController failed: " + err);
			};
		}

		private static function toggleBit(controls:Object, key:String):int
		{
			if (!controls || controls[key] == null)
			{
				return (0);
			};
			return (int(controls[key]) != 0 ? 1 : 0);
		}

		/** Force fl.controls.CheckBox to match controller (stuck across pad↔keyboard swaps). */
		internal function syncToggleCheckboxes(pid:int):void
		{
			var SD:Class;
			var controller:*;
			var tj:*;
			var ad:*;
			var dt:*;
			var sub:*;
			var wantTJ:Boolean;
			var wantAD:Boolean;
			var wantDT:Boolean;
			if (!mod.m_controls)
			{
				return;
			};
			try
			{
				if (int(mod.m_controls["playNum"] || 0) != pid)
				{
					if (mod.m_controls["updateControls"])
					{
						mod.m_controls["updateControls"]();
					};
					return;
				};
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				controller = SD["Controllers"][pid - 1];
				if (!controller)
				{
					return;
				};
				wantTJ = int(controller["_TAP_JUMP"]) == 1;
				wantAD = int(controller["_AUTO_DASH"]) == 1;
				wantDT = int(controller["_DT_DASH"]) == 1;
				tj = mod.m_controls["TapJumpCheckBox"];
				ad = mod.m_controls["AutoDashCheckBox"];
				dt = mod.m_controls["DTDashCheckBox"];
				sub = mod.m_controls["SubMenu"];
				if (!tj && sub)
				{
					tj = sub["tapJump"];
				};
				if (!ad && sub)
				{
					ad = sub["autoDash"];
				};
				if (!dt && sub)
				{
					dt = sub["dtapDash"];
				};
				forceCheckBox(tj, wantTJ);
				forceCheckBox(ad, wantAD);
				forceCheckBox(dt, !wantAD && wantDT);
				if (mod.m_controls["updateControls"])
				{
					mod.m_controls["updateControls"]();
				};
				// updateControls / CHANGE can fight us — re-assert controller + UI.
				controller["_TAP_JUMP"] = wantTJ ? 1 : 0;
				controller["_AUTO_DASH"] = wantAD ? 1 : 0;
				controller["_DT_DASH"] = (!wantAD && wantDT) ? 1 : 0;
				forceCheckBox(tj, wantTJ);
				forceCheckBox(ad, wantAD);
				forceCheckBox(dt, !wantAD && wantDT);
			}
			catch (err:*)
			{
			};
		}

		private static function forceCheckBox(box:*, want:Boolean):void
		{
			if (!box)
			{
				return;
			};
			try
			{
				box["selected"] = !want;
				box["selected"] = want;
			}
			catch (err:*)
			{
			};
		}

		internal function saveActiveProfile():void
		{
			var name:String;
			var key:String;
			var play:int;
			if (!mod.m_controls)
			{
				return;
			};
			play = int(mod.m_controls["playNum"] || mod.m_playNum || 1);
			name = mod.m_tags.currentProfileName(play);
			if (name.length < 1)
			{
				return;
			};
			key = mod.m_deviceKey.length > 0 ? mod.m_deviceKey : ProfileBlobs.deviceKey(play);
			if (ProfileBlobs.deviceKey(play) == key)
			{
				cacheLiveDevice(play, key);
			};
			// Prefer last stable snapshot for this device so a mid-swap save can't poison it.
			if (mod.m_deviceLiveCache[key])
			{
				flushDeviceCache(play, key);
				return;
			};
			cacheLiveDevice(play, key);
			flushDeviceCache(play, key);
		}
	}
}
