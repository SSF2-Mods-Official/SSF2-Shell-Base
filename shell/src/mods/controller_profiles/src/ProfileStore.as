package
{
	import flash.filesystem.File;
	import ssf2mm.shared.JsonFile;

	/**
	 * Nametags and bindings live in expansions/user/controller_profiles.json (the Mod Manager's
	 * Configure Launch tags read the same file). The first load without it copies the newest of the
	 * old locations.
	 */
	public class ProfileStore
	{
		public static const STATE_REL:String = "expansions/user/controller_profiles.json";
		public static const LEGACY_RELS:Array = [
			"data/ssf2mm/state/controller_profiles.json",
			"expansions/mods/controller_profiles/profiles.json",
			"data/ssf2mm/controller_profiles/profiles.json"
		];
		public static const STORE_REL:String = "controller_profiles/profiles.json";

		public static function stateFile(appDir:File):File
		{
			return (new File(appDir.resolvePath(STATE_REL).nativePath));
		}

		/** Existing old files, app folder first, then app storage. */
		public static function legacyFiles(appDir:File, storeDir:File):Array
		{
			var out:Array = [];
			var rel:String;
			var f:File;
			for each (rel in LEGACY_RELS)
			{
				f = new File(appDir.resolvePath(rel).nativePath);
				if (f.exists)
				{
					out.push(f);
				};
			};
			if (storeDir)
			{
				f = storeDir.resolvePath(STORE_REL);
				if (f.exists)
				{
					out.push(f);
				};
			};
			return (out);
		}

		/** Returns {data, from}; from is the file read, or null when nothing was there. */
		public static function load(appDir:File, storeDir:File):Object
		{
			var state:File = stateFile(appDir);
			var from:File = state.exists ? state : null;
			var data:Object;
			var legacy:Array;
			if (!from)
			{
				legacy = legacyFiles(appDir, storeDir);
				from = legacy.length > 0 ? legacy[0] as File : null;
			};
			data = from ? JsonFile.read(from) : null;
			return ({"data": normalize(data), "from": from});
		}

		public static function save(appDir:File, data:Object):Boolean
		{
			return (JsonFile.write(stateFile(appDir), data));
		}

		public static function normalize(data:Object):Object
		{
			if (!data)
			{
				data = {};
			};
			if (!(data["names"] is Array))
			{
				data["names"] = [];
			};
			if (!data["last"])
			{
				data["last"] = {};
			};
			if (!data["profiles"])
			{
				data["profiles"] = {};
			};
			return (data);
		}
	}
}
