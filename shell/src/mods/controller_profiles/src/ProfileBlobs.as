package
{
	import ssf2mm.shared.EngineRefs;

	/**
	 * Keyboard / controller binding blobs: stock defaults, live snapshots, gamepad slot I/O.
	 */
	public class ProfileBlobs
	{
		internal var mod:ControllerProfilesMod;

		public function ProfileBlobs(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		/**
		 * New nametag inherits the last profile's keyboard and all pad setups,
		 * plus any other pads currently active on P1–P4.
		 */
		internal function seedProfileFromLast(pid:int):Object
		{
			var lastName:String;
			var src:Object;
			var out:Object;
			var key:String;
			var p:int;
			var dev:String;
			var live:Object;
			lastName = String(mod.m_data["last"][String(pid)] || "");
			if (lastName.length < 1 || lastName == ControllerProfilesMod.DEFAULT_TAG)
			{
				src = mod.m_data["profiles"][ControllerProfilesMod.DEFAULT_TAG];
			}
			else
			{
				src = mod.m_data["profiles"][lastName];
			};
			out = {"keyboard":null, "pads":{}};
			if (src)
			{
				out["keyboard"] = src["keyboard"] ? deepCopyObject(src["keyboard"]) : stockKeyboardBlob(pid);
				if (src["pads"])
				{
					for (key in src["pads"])
					{
						out["pads"][key] = deepCopyObject(src["pads"][key]);
					};
				};
			}
			else
			{
				out["keyboard"] = stockKeyboardBlob(pid);
			};
			// Ensure every active controller right now is represented (copy last→live if needed).
			p = 1;
			while (p <= 4)
			{
				dev = deviceKey(p);
				if (dev != "keyboard" && !out["pads"][dev])
				{
					if (src && src["pads"] && src["pads"][dev])
					{
						out["pads"][dev] = deepCopyObject(src["pads"][dev]);
					}
					else
					{
						live = snapshotLiveBlob(p);
						if (live)
						{
							out["pads"][dev] = live;
						};
					};
				};
				p++;
			};
			return (out);
		}

		/** @deprecated Prefer seedProfileFromLast — kept for any leftover call sites. */
		internal function seedProfile(pid:int):Object
		{
			return (seedProfileFromLast(pid));
		}

		internal static function snapshotLiveBlob(pid:int):Object
		{
			var SD:Class;
			var controller:*;
			var blob:Object;
			var controls:Object;
			var padInputs:Object;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				controller = SD["Controllers"][pid - 1];
				if (!controller || !controller["getControls"])
				{
					return (null);
				};
				controls = copyOut(controller["getControls"]());
				blob = {"controls":controls, "pad":{}, "padInputs":{}};
				if (controller["GamepadInstance"] && controller["GamepadInstance"]["ControlsMap"])
				{
					blob["pad"] = copyOut(controller["GamepadInstance"]["ControlsMap"]);
					padInputs = readLivePadInputs(pid);
					if (padInputs)
					{
						blob["padInputs"] = padInputs;
					};
				};
				if (isBlankControls(controls) && deviceKey(pid) == "keyboard")
				{
					return (defaultKeyboardBlob(pid));
				};
				return (blob);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private static function isBlankControls(controls:Object):Boolean
		{
			var key:String;
			var mapped:int;
			if (!controls)
			{
				return (true);
			};
			mapped = 0;
			for (key in controls)
			{
				if (key == "TAP_JUMP" || key == "AUTO_DASH" || key == "DT_DASH")
				{
					continue;
				};
				if (int(controls[key]) != 0)
				{
					mapped++;
				};
			};
			return (mapped < 1);
		}

		/** First-time Default keyboard: game ControlSettings if present, else stock. */
		internal static function seedDefaultProfile(pid:int):Object
		{
			return ({"keyboard":defaultGameKeyboardBlob(pid), "pads":{}});
		}

		internal static function defaultGameKeyboardBlob(pid:int):Object
		{
			var SD:Class;
			var stored:*;
			var controls:Object;
			var key:String;
			controls = stockKeyboardControls(pid);
			try
			{
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				stored = SD["ControlSettings"] ? SD["ControlSettings"]["player" + pid] : null;
				if (stored)
				{
					// Keep mapped keys from the game save; toggles stay stock so a pad
					// session that wrote ControlSettings can't poison keyboard Default.
					for (key in stored)
					{
						if (key == "TAP_JUMP" || key == "AUTO_DASH" || key == "DT_DASH")
						{
							continue;
						};
						controls[key] = stored[key];
					};
				};
			}
			catch (err:*)
			{
			};
			return ({"controls":controls, "pad":{}});
		}

		internal static function stockPadBlob(pid:int = 1):Object
		{
			var controls:Object;
			var key:String;
			var padInputs:Object;
			controls = stockKeyboardControls(1);
			for (key in controls)
			{
				if (key != "TAP_JUMP" && key != "AUTO_DASH" && key != "DT_DASH")
				{
					controls[key] = 0;
				};
			};
			controls["TAP_JUMP"] = 1;
			controls["AUTO_DASH"] = 0;
			controls["DT_DASH"] = 1;
			padInputs = readLivePadInputs(pid);
			if (!padInputs)
			{
				padInputs = {};
			};
			return ({"controls":controls, "pad":{}, "padInputs":padInputs});
		}

		/**
		 * Stock SSF2 keyboard defaults (same as SaveData first-run):
		 * P1 WASD + O/P/U/I, P2 arrows + numpad.
		 */
		internal static function stockKeyboardBlob(pid:int):Object
		{
			return ({"controls":stockKeyboardControls(pid), "pad":{}});
		}

		private static function defaultKeyboardBlob(pid:int):Object
		{
			return (stockKeyboardBlob(pid));
		}

		internal static function stockKeyboardControls(pid:int):Object
		{
			if (pid < 1)
			{
				pid = 1;
			};
			if (pid == 2)
			{
				return ({
					"UP":38, "DOWN":40, "LEFT":37, "RIGHT":39,
					"BUTTON1":98, "BUTTON2":99, "GRAB":101, "START":96,
					"TAUNT":100, "SHIELD":97, "JUMP":0, "JUMP2":0,
					"C_UP":0, "C_DOWN":0, "C_LEFT":0, "C_RIGHT":0,
					"DASH":0, "AUTO_DASH":0, "DT_DASH":1, "TAP_JUMP":1
				});
			};
			if (pid >= 3)
			{
				return ({
					"UP":0, "DOWN":0, "LEFT":0, "RIGHT":0,
					"BUTTON1":0, "BUTTON2":0, "GRAB":0, "START":0,
					"TAUNT":0, "SHIELD":0, "JUMP":0, "JUMP2":0,
					"C_UP":0, "C_DOWN":0, "C_LEFT":0, "C_RIGHT":0,
					"DASH":0, "AUTO_DASH":0, "DT_DASH":1, "TAP_JUMP":1
				});
			};
			return ({
				"UP":87, "DOWN":83, "LEFT":65, "RIGHT":68,
				"BUTTON1":79, "BUTTON2":80, "GRAB":85, "START":8,
				"TAUNT":49, "SHIELD":73, "JUMP":0, "JUMP2":0,
				"C_UP":0, "C_DOWN":0, "C_LEFT":0, "C_RIGHT":0,
				"DASH":0, "AUTO_DASH":0, "DT_DASH":1, "TAP_JUMP":1
			});
		}

		internal static function deviceKey(pid:int):String
		{
			var SD:Class;
			var controller:*;
			var pad:*;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				controller = SD["Controllers"][pid - 1];
				pad = controller ? controller["GamepadInstance"] : null;
				if (pad && pad["Name"])
				{
					return (String(pad["Name"]));
				};
			}
			catch (err:*)
			{
			};
			return ("keyboard");
		}

		/**
		 * Resolve SaveData.Gamepads slot for this player (named CSS tag vs port),
		 * matching ControlsButton / reimportNamedPlayerControls.
		 */
		private static function resolvePadSlot(pid:int):Object
		{
			var SD:Class;
			var controller:*;
			var pad:*;
			var playerTag:String;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				controller = SD["Controllers"][pid - 1];
				pad = controller ? controller["GamepadInstance"] : null;
				if (!pad || !pad["Name"])
				{
					return (null);
				};
				playerTag = ProfileTags.playerTag(pid, true);
				if (playerTag.length > 0)
				{
					return ({
						"padName":String(pad["Name"]),
						"bucket":"names",
						"slot":playerTag
					});
				};
				return ({
					"padName":String(pad["Name"]),
					"bucket":"ports",
					"slot":"port" + int(pad["Port"])
				});
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal static function readLivePadInputs(pid:int):Object
		{
			var SD:Class;
			var slot:Object;
			var gpRoot:Object;
			var bucket:Object;
			var live:*;
			try
			{
				slot = resolvePadSlot(pid);
				if (!slot)
				{
					return (null);
				};
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				gpRoot = SD["Gamepads"][slot["padName"]];
				if (!gpRoot)
				{
					return ({});
				};
				bucket = gpRoot[slot["bucket"]];
				if (!bucket)
				{
					return ({});
				};
				live = bucket[slot["slot"]];
				if (!live)
				{
					return ({});
				};
				return (deepCopyObject(live));
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal static function writeLivePadInputs(pid:int, inputs:Object):void
		{
			var SD:Class;
			var slot:Object;
			var gpRoot:Object;
			var bucket:Object;
			var controller:*;
			var pad:*;
			var copy:Object;
			if (!inputs)
			{
				return;
			};
			try
			{
				slot = resolvePadSlot(pid);
				if (!slot)
				{
					return;
				};
				SD = EngineRefs.ssf2("util.SaveData") as Class;
				if (!SD["Gamepads"][slot["padName"]])
				{
					SD["Gamepads"][slot["padName"]] = {"names":{}, "ports":{}};
				};
				gpRoot = SD["Gamepads"][slot["padName"]];
				if (!gpRoot[slot["bucket"]])
				{
					gpRoot[slot["bucket"]] = {};
				};
				bucket = gpRoot[slot["bucket"]];
				copy = deepCopyObject(inputs);
				// Keep toggles on the pad save object in sync.
				controller = SD["Controllers"][pid - 1];
				if (controller)
				{
					copy["TAP_JUMP"] = controller["_TAP_JUMP"];
					copy["AUTO_DASH"] = controller["_AUTO_DASH"];
					copy["DT_DASH"] = controller["_DT_DASH"];
				};
				bucket[slot["slot"]] = copy;
				pad = controller ? controller["GamepadInstance"] : null;
				if (pad && pad["importControls"])
				{
					pad["importControls"](copy);
				};
			}
			catch (err:*)
			{
				log("writeLivePadInputs failed: " + err);
			};
		}

		internal static function isEmptyObject(obj:Object):Boolean
		{
			var key:String;
			if (!obj)
			{
				return (true);
			};
			for (key in obj)
			{
				return (false);
			};
			return (true);
		}

		private static function deepCopyObject(src:*):*
		{
			var out:Object;
			var arr:Array;
			var key:String;
			var i:int;
			if (src == null)
			{
				return (null);
			};
			if (src is Number || src is String || src is Boolean)
			{
				return (src);
			};
			if (src is Array)
			{
				arr = [];
				i = 0;
				while (i < (src as Array).length)
				{
					arr.push(deepCopyObject(src[i]));
					i++;
				};
				return (arr);
			};
			out = {};
			for (key in src)
			{
				out[key] = deepCopyObject(src[key]);
			};
			return (out);
		}

		internal static function copyFields(from:Object, to:Object):void
		{
			var key:String;
			if (!from || !to)
			{
				return;
			};
			for (key in from)
			{
				to[key] = from[key];
			};
		}

		internal static function copyOut(src:Object):Object
		{
			var out:Object;
			var key:String;
			out = {};
			if (!src)
			{
				return (out);
			};
			for (key in src)
			{
				out[key] = src[key];
			};
			return (out);
		}
	}
}
