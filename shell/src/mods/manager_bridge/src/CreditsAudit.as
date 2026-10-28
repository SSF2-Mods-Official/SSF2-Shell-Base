package
{
	import flash.filesystem.File;

	import ssf2mm.shared.JsonFile;

	/**
	 * Ensures Credits.txt exists next to the game exe and lists every expansion
	 * pack under expansions/ (from info.json / mod.json). Restores missing lines.
	 *
	 * Writes via nativePath bridge — AIR blocks FileMode.WRITE on
	 * File.applicationDirectory handles directly (fileWriteResource).
	 */
	public class CreditsAudit
	{
		private static const FILE_NAME:String = "Credits.txt";
		private static const SKIP_SECTIONS:Object = {"engine": true, "ssf2mm": true};
		private static const SKIP_FOLDERS:Object = {
			"decompiled": true, "resources": true, "_template": true, "template": true
		};

		private var m_log:Function;

		public function CreditsAudit(logFn:Function = null)
		{
			m_log = logFn;
		}

		public function ensure():void
		{
			var root:File;
			var entries:Array;
			var notes:String;
			var path:File;
			try
			{
				root = appRoot();
				if (!root || !root.exists)
				{
					return;
				};
				path = writableCreditsPath(root);
				if (!path)
				{
					log("credits: no writable path");
					return;
				};
				entries = scan(root);
				notes = readNotes(path);
				if (!notes || notes.length < 1)
				{
					notes = readNotes(root.resolvePath(FILE_NAME));
				};
				write(path, entries, notes);
				log("credits ok entries=" + entries.length + " path=" + path.nativePath);
			}
			catch (err:*)
			{
				log("credits audit fail: " + err);
			};
		}

		/** Absolute File for the install root (readable). */
		private function appRoot():File
		{
			var rel:File;
			try
			{
				rel = File.applicationDirectory;
				if (rel && rel.exists)
				{
					return (new File(rel.nativePath));
				};
			}
			catch (err:*)
			{
			};
			return (rel);
		}

		/**
		 * Credits.txt beside the exe. Use nativePath so writes are allowed when
		 * the install folder is user-writable (dev / sideload layout).
		 */
		private function writableCreditsPath(root:File):File
		{
			var abs:File;
			try
			{
				if (!root)
				{
					return (null);
				};
				abs = new File(root.resolvePath(FILE_NAME).nativePath);
				return (abs);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private function scan(root:File):Array
		{
			var out:Array;
			var expansions:File;
			var sections:Array;
			var i:int;
			var section:File;
			var sectionName:String;
			var packs:Array;
			var j:int;
			var pack:File;
			var entry:Object;
			out = [];
			expansions = root.resolvePath("expansions");
			if (!expansions.exists || !expansions.isDirectory)
			{
				return (out);
			};
			sections = expansions.getDirectoryListing();
			i = 0;
			while (i < sections.length)
			{
				section = sections[i] as File;
				i++;
				if (!section || !section.isDirectory)
				{
					continue;
				};
				sectionName = section.name;
				if (SKIP_SECTIONS[sectionName])
				{
					continue;
				};
				packs = section.getDirectoryListing();
				j = 0;
				while (j < packs.length)
				{
					pack = packs[j] as File;
					j++;
					if (!pack || !pack.isDirectory)
					{
						continue;
					};
					if (SKIP_FOLDERS[pack.name])
					{
						continue;
					};
					entry = readPack(root, pack, sectionName);
					if (entry)
					{
						out.push(entry);
					};
				};
			};
			out.sortOn(["section", "name"], [Array.CASEINSENSITIVE, Array.CASEINSENSITIVE]);
			return (out);
		}

		private function readPack(root:File, pack:File, section:String):Object
		{
			var info:Object;
			var mod:Object;
			var name:String;
			var creator:String;
			var type:String;
			var rel:String;
			info = readJson(pack.resolvePath("info.json"));
			mod = readJson(pack.resolvePath("mod.json"));
			if (!info && !mod)
			{
				return (null);
			};
			name = pick(info, "name") || pick(mod, "name") || pack.name;
			creator = pick(info, "creator") || pick(info, "author")
				|| pick(mod, "author") || pick(mod, "creator") || "Unknown";
			type = pick(info, "type") || section;
			rel = "expansions/" + section + "/" + pack.name;
			return ({
				"rel": rel,
				"name": name,
				"creator": creator,
				"type": type,
				"section": section
			});
		}

		private function pick(obj:Object, key:String):String
		{
			var v:*;
			if (!obj)
			{
				return ("");
			};
			v = obj[key];
			if (v == null)
			{
				return ("");
			};
			return (String(v).replace(/^\s+|\s+$/g, ""));
		}

		private function readJson(file:File):Object
		{
			return (JsonFile.read(file));
		}

		private function readNotes(path:File):String
		{
			var raw:String = JsonFile.readText(path);
			var idx:int;
			if (raw == null)
			{
				return ("");
			};
			idx = raw.toLowerCase().indexOf("## notes");
			if (idx < 0)
			{
				return ("");
			};
			return (raw.substring(idx + 8).replace(/^\s+/, ""));
		}

		private function standingCredits(notes:String):String
		{
			var block:String = "- IDK — David (stariwinkle)\n- Palette Maker (original) — VAL\n\n";
			if (notes == null)
			{
				notes = "";
			};
			if (notes.indexOf("David (stariwinkle)") >= 0 && notes.indexOf("Palette Maker (original)") >= 0)
			{
				return (notes);
			};
			return (block + notes);
		}

		private function write(path:File, entries:Array, notes:String):void
		{
			var sb:String;
			var i:int;
			var e:Object;
			var last:String;
			var title:String;
			sb = "# SSF2 Shell — Mod Credits\n"
				+ "# Auto-maintained by SSF2 Mod Manager. Verified again when the game launches (ssf2_stream).\n"
				+ "# Removing an entry for an installed mod will restore it on the next update/launch.\n"
				+ "# Format: Name — Creator  [type]  (relative path)\n\n";
			last = "";
			i = 0;
			while (i < entries.length)
			{
				e = entries[i];
				i++;
				if (String(e.section) != last)
				{
					if (last.length > 0)
					{
						sb += "\n";
					};
					title = sectionTitle(String(e.section));
					sb += "## " + title + "\n";
					last = String(e.section);
				};
				sb += "- " + e.name + " — " + e.creator + "  [" + e.type + "]  (" + e.rel + ")\n";
			};
			sb += "\n## Notes\n";
			notes = standingCredits(notes);
			if (notes && notes.length > 0)
			{
				sb += notes;
				if (notes.charAt(notes.length - 1) != "\n")
				{
					sb += "\n";
				};
			}
			else
			{
				sb += "# Add freeform credits below this line; they are preserved across updates.\n";
			};
			if (!JsonFile.writeText(path, sb))
			{
				throw new Error("write failed " + path.nativePath);
			};
		}

		private function sectionTitle(section:String):String
		{
			if (section == "essentials")
			{
				return ("Essentials");
			};
			if (section == "mods")
			{
				return ("Mods");
			};
			if (section == "character")
			{
				return ("Characters");
			};
			if (section.length < 1)
			{
				return ("Other");
			};
			return (section.charAt(0).toUpperCase() + section.substr(1));
		}

		private function log(msg:String):void
		{
			if (m_log != null)
			{
				try
				{
					m_log(msg);
				}
				catch (err:*)
				{
				};
			};
		}
	}
}
