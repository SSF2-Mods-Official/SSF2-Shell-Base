package ssf2mm.shared
{
	import flash.filesystem.File;

	import ssf2mm.shared.EngineRefs;

	/** Packs under expansions/stage_assets. Each folder is pngs for one source stage. */
	public class StageAssetCatalog
	{
		public static const REL:String = "expansions/stage_assets";
		private static var s_map:Object;

		public static function dir():File
		{
			var at:File = File.applicationDirectory.resolvePath(REL);
			return (new File(at.nativePath));
		}

		public static function reload():Object
		{
			var root:File;
			var list:Array;
			var i:int;
			var folder:File;
			var info:Object;
			var assets:Object;
			var id:String;
			var preview:File;
			s_map = {};
			root = dir();
			if (!root.exists)
			{
				return (s_map);
			};
			list = root.getDirectoryListing();
			i = 0;
			while (list && i < list.length)
			{
				folder = list[i] as File;
				i++;
				if (!folder || !folder.isDirectory)
				{
					continue;
				};
				info = JsonFile.read(folder.resolvePath("info.json"));
				if (!info || String(info.type) != "StageAssetSwap" || info.enabled == false)
				{
					continue;
				};
				id = String(info.id || folder.name);
				assets = JsonFile.read(folder.resolvePath("assets.json"));
				preview = new File(folder.resolvePath("stagepreview.png").nativePath);
				s_map[id] = {
					"sourceStage": String(info.sourceStage || ""),
					"name": String(info.name || id),
					"preview": preview.exists ? preview.nativePath : "",
					"folder": folder.nativePath,
					"images": imageRows(folder, assets)
				};
			};
			return (s_map);
		}

		public static function map():Object
		{
			if (s_map == null)
			{
				reload();
			};
			return (s_map);
		}

		public static function resolve(slotId:String):Object
		{
			var row:Object = map()[slotId];
			if (!row || !row.sourceStage)
			{
				return (null);
			};
			return (row);
		}

		public static function invalidate():void
		{
			s_map = null;
		}

		/** Results reads metadata.stage[slot].name. The slot id is not in that table until this runs. */
		public static function rememberName(slotId:String, name:String):void
		{
			var RM:*;
			var mappings:Object;
			var label:String;
			if (!slotId)
			{
				return;
			};
			label = name ? name : slotId;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				mappings = RM && RM.getResourceByID is Function ? RM.getResourceByID("mappings").getProp("metadata") as Object : null;
			}
			catch (err:*)
			{
				mappings = null;
			};
			if (!mappings)
			{
				return;
			};
			if (!mappings.stage)
			{
				mappings.stage = {};
			};
			if (!mappings.stage[slotId])
			{
				mappings.stage[slotId] = {"name": label};
			}
			else if (!mappings.stage[slotId].name)
			{
				mappings.stage[slotId].name = label;
			};
			EngineRefs.gameLog("[stage_asset] name id=" + slotId + " name=" + label);
		}

		private static function imageRows(folder:File, assets:Object):Array
		{
			var src:Array;
			var rows:Array;
			var i:int;
			var item:Object;
			var name:String;
			var file:File;
			src = assets && assets.images is Array ? assets.images as Array : [];
			rows = [];
			i = 0;
			while (i < src.length)
			{
				item = src[i];
				i++;
				if (!item)
				{
					continue;
				};
				name = String(item.file || "");
				file = name.indexOf(":\\") >= 0 || name.indexOf(":/") >= 0 ? new File(name) : folder.resolvePath("assets/" + name);
				rows.push({
					"characterId": item.characterId,
					"file": file.nativePath,
					"width": item.width,
					"height": item.height
				});
			};
			return (rows);
		}
	}
}
