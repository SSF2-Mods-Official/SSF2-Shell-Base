package
{
	import ssf2mm.shared.EngineRefs;

	/**
	 * Nametag list operations: select, add, and persist the last-used profile per tag.
	 */
	public class ProfileTags
	{
		internal var mod:ControllerProfilesMod;

		public function ProfileTags(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		internal function userTagNames():Array
		{
			var names:Array;
			var out:Array;
			var i:int;
			names = mod.m_data["names"] as Array;
			out = [];
			if (!names)
			{
				return (out);
			};
			i = 0;
			while (i < names.length)
			{
				if (String(names[i]) != ControllerProfilesMod.DEFAULT_TAG)
				{
					out.push(String(names[i]));
				};
				i++;
			};
			return (out);
		}

		/** Stock CSS label for an empty/default slot — not a real profile name. */
		private static function slotLabel(pid:int):String
		{
			if (pid < 1)
			{
				pid = 1;
			};
			return ("P" + pid);
		}

		internal function selectName(pid:int, name:String):void
		{
			var game:*;
			var settings:*;
			var display:*;
			var displayName:String;
			// Persist current bindings before switching away.
			if (mod.m_controls)
			{
				mod.m_bar.saveActiveProfile();
			};
			name = ProfileNameEdit.clampName(ProfileNameEdit.trimStr(name));
			if (name.length < 1)
			{
				name = ControllerProfilesMod.DEFAULT_TAG;
			};
			if (name == ControllerProfilesMod.DEFAULT_TAG)
			{
				mod.m_data["last"][String(pid)] = ControllerProfilesMod.DEFAULT_TAG;
				// Stored name stays empty; CSS only shows the stock P# label.
				displayName = slotLabel(pid);
			}
			else
			{
				if (!mod.m_data["profiles"][name])
				{
					mod.m_data["profiles"][name] = mod.m_blobs.seedProfileFromLast(pid);
				};
				mod.m_data["last"][String(pid)] = name;
				displayName = name;
			};
			try
			{
				game = mod.m_cssMenu ? mod.m_cssMenu["GameObj"] : null;
				settings = game ? game["PlayerSettings"] : null;
				if (settings && settings[pid - 1])
				{
					// Default = no nametag (empty). P# is display-only.
					settings[pid - 1]["name"] = name == ControllerProfilesMod.DEFAULT_TAG ? "" : displayName;
				};
			}
			catch (err:*)
			{
				log("selectName failed: " + err);
			};
			display = ProfileCssHooks.findNameDisplay(mod.m_cssMenu, pid);
			try
			{
				if (display && display["nameTxt"])
				{
					display["nameTxt"].text = displayName;
				};
			}
			catch (nErr:*)
			{
				log("selectName failed: " + nErr);
			};
			mod.m_bar.applyProfile(pid, name, false);
			mod.saveData();
			if (mod.m_controls)
			{
				mod.m_bar.refreshProfileBar();
			};
		}

		internal function addName(name:String, forPid:int = 0):void
		{
			var names:Array;
			var i:int;
			var pid:int;
			name = ProfileNameEdit.clampName(ProfileNameEdit.trimStr(name));
			if (name.length < 1 || name == ControllerProfilesMod.DEFAULT_TAG)
			{
				return;
			};
			names = mod.m_data["names"] as Array;
			if (!names)
			{
				names = [];
				mod.m_data["names"] = names;
			};
			i = 0;
			while (i < names.length)
			{
				if (String(names[i]) == name)
				{
					return;
				};
				i++;
			};
			names.push(name);
			pid = forPid > 0 ? forPid : (mod.m_editPid > 0 ? mod.m_editPid : (mod.m_controls ? int(mod.m_controls["playNum"] || 1) : 1));
			// Flush last profile (keyboard + every active pad) so the clone is current.
			persistLastProfileLive(pid);
			mod.m_data["profiles"][name] = mod.m_blobs.seedProfileFromLast(pid);
			log("new profile \"" + name + "\" seeded from last profile for P" + pid);
		}

		/** Persist the current slot's live bindings into its last-used profile before cloning. */
		private function persistLastProfileLive(pid:int):void
		{
			var lastName:String;
			var profile:Object;
			var key:String;
			var blob:Object;
			var p:int;
			lastName = String(mod.m_data["last"][String(pid)] || ControllerProfilesMod.DEFAULT_TAG);
			if (lastName.length < 1)
			{
				lastName = ControllerProfilesMod.DEFAULT_TAG;
			};
			profile = mod.m_data["profiles"][lastName];
			if (!profile)
			{
				profile = lastName == ControllerProfilesMod.DEFAULT_TAG ? ProfileBlobs.seedDefaultProfile(pid) : {"keyboard":ProfileBlobs.stockKeyboardBlob(pid), "pads":{}};
				mod.m_data["profiles"][lastName] = profile;
			};
			if (!profile["pads"])
			{
				profile["pads"] = {};
			};
			// Capture keyboard + every currently active pad across P1–P4 into last profile.
			p = 1;
			while (p <= 4)
			{
				key = ProfileBlobs.deviceKey(p);
				blob = ProfileBlobs.snapshotLiveBlob(p);
				if (!blob)
				{
					p++;
					continue;
				};
				if (key == "keyboard")
				{
					if (p == pid)
					{
						profile["keyboard"] = blob;
					};
				}
				else
				{
					profile["pads"][key] = blob;
				};
				p++;
			};
			if (!profile["keyboard"])
			{
				profile["keyboard"] = ProfileBlobs.stockKeyboardBlob(pid);
			};
			mod.saveData();
		}

		internal function currentProfileName(pid:int):String
		{
			var name:String;
			name = String(mod.m_data["last"][String(pid)] || playerTag(pid) || ControllerProfilesMod.DEFAULT_TAG);
			if (name.length < 1)
			{
				name = ControllerProfilesMod.DEFAULT_TAG;
			};
			return (name);
		}

		internal static function playerTag(pid:int, humanOnly:Boolean = false):String
		{
			var MC:Class;
			var menu:*;
			var game:*;
			var settings:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				menu = MC ? MC["CurrentCharacterSelectMenu"] : null;
				game = menu ? menu["GameObj"] : null;
				settings = game ? game["PlayerSettings"] : null;
				if (settings && settings[pid - 1] && (!humanOnly || settings[pid - 1]["human"])
					&& settings[pid - 1]["name"])
				{
					return (String(settings[pid - 1]["name"]));
				};
			}
			catch (err:*)
			{
			};
			return ("");
		}
	}
}
