package
{
	import flash.display.MovieClip;
	import flash.filesystem.File;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/** Engine data both select-screen editors read: live mappings, library clips, JSON next to the game. Never throws. */
	public class EditorEngine
	{
		/** ResourceManager "mappings" prop: "metadata" is live, "metadata_original" is the boot copy. */
		public static function mappings(prop:String = "metadata"):Object
		{
			var RM:*;
			var res:*;
			RM = EngineRefs.ResourceManager;
			try
			{
				res = RM ? RM["getResourceByID"]("mappings") : null;
				if (res)
				{
					return (res.getProp(prop));
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		public static function libraryMC(name:String):MovieClip
		{
			var RM:*;
			RM = EngineRefs.ResourceManager;
			try
			{
				return (RM ? (RM["getLibraryMC"](name) as MovieClip) : null);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		/** JSON file under the game folder (File.applicationDirectory), or null. */
		public static function appJson(rel:String):Object
		{
			try
			{
				return (JsonFile.read(File.applicationDirectory.resolvePath(rel)));
			}
			catch (err:*)
			{
			};
			return (null);
		}
	}
}
