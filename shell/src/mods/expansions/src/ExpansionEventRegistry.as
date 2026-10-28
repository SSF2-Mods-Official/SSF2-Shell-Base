package
{
	import flash.display.BitmapData;

	/**
	 * Static registry of expansion events discovered in expansions/events/*.swf.
	 */
	public class ExpansionEventRegistry
	{
		/** Menu entry id for the GameBanana browse shortcut pinned to the bottom of the list. */
		public static const DOWNLOAD_ID:String = "event_expansions.download";
		public static const DOWNLOAD_URL:String = "https://gamebanana.com/mods/cats/49482";

		private static var s_packs:Object = {};
		private static var s_order:Array = [];
		private static var s_series:Object = {};
		private static var s_menuList:Array = [];

		public static function reset():void
		{
			s_packs = {};
			s_order = [];
			s_series = {};
			s_menuList = [];
		}

		public static function registerPack(id:String, info:Object, folder:*, classAPI:Class, previewBitmapData:BitmapData = null):void
		{
			var pack:Object;
			if (!id)
			{
				return;
			};
			pack = {
				"id": id,
				"info": info || {},
				"folder": folder,
				"classAPI": classAPI,
				"previewBitmapData": previewBitmapData,
				"seriesId": null
			};
			if (!s_packs[id])
			{
				s_order.push(id);
			};
			s_packs[id] = pack;
		}

		public static function setPreview(id:String, previewBitmapData:BitmapData):void
		{
			var pack:Object = s_packs[id];
			if (pack)
			{
				pack.previewBitmapData = previewBitmapData;
			};
		}

		public static function registerSeries(id:String, info:Object, folder:*):void
		{
			if (!id)
			{
				return;
			};
			s_series[id] = {
				"id": id,
				"info": info || {},
				"folder": folder,
				"events": (info && info.events is Array) ? (info.events as Array) : []
			};
			linkSeriesMembership();
		}

		public static function linkSeriesMembership():void
		{
			var sid:String;
			var series:Object;
			var i:int;
			var evId:String;
			var pack:Object;
			for (sid in s_series)
			{
				series = s_series[sid];
				i = 0;
				while (series.events && i < series.events.length)
				{
					evId = String(series.events[i]);
					pack = s_packs[evId];
					if (pack)
					{
						pack.seriesId = sid;
						pack.seriesIndex = i;
					};
					i++;
				};
			};
		}

		public static function getPack(id:String):Object
		{
			return s_packs[id];
		}

		public static function getSeries(id:String):Object
		{
			return s_series[id];
		}

		public static function getPackIds():Array
		{
			return s_order.concat();
		}

		/** Series first, then standalone events, both A-Z by display name, then the download shortcut. */
		public static function buildMenuList():Array
		{
			var seriesEntries:Array = [];
			var eventEntries:Array = [];
			var used:Object = {};
			var sid:String;
			var series:Object;
			var info:Object;
			var firstId:String;
			var first:Object;
			var i:int;
			var id:String;
			var pack:Object;
			var entry:Object;

			for (sid in s_series)
			{
				series = s_series[sid];
				info = series.info || {};
				firstId = (series.events && series.events.length > 0) ? String(series.events[0]) : null;
				first = firstId ? s_packs[firstId] : null;
				seriesEntries.push({
					"id": sid,
					"name": info.name || sid,
					"description": info.description || "",
					"creator": info.creator || "",
					"expansion": true,
					"seriesStart": true,
					"seriesId": sid,
					"chooseCharacter": false,
					"classAPI": first ? first.classAPI : null,
					"previewBitmapData": first ? first.previewBitmapData : null
				});
				i = 0;
				while (series.events && i < series.events.length)
				{
					used[String(series.events[i])] = true;
					i++;
				};
			};

			i = 0;
			while (i < s_order.length)
			{
				id = String(s_order[i]);
				i++;
				if (used[id])
				{
					continue;
				};
				pack = s_packs[id];
				if (!pack)
				{
					continue;
				};
				info = pack.info || {};
				if (isTruthy(info.hidden))
				{
					continue;
				};
				eventEntries.push({
					"id": id,
					"name": info.name || id,
					"description": info.description || "",
					"creator": info.creator || "",
					"expansion": true,
					"chooseCharacter": isTruthy(info.chooseCharacter),
					"stageBackground": info.stageBackground ? String(info.stageBackground) : "",
					"classAPI": pack.classAPI,
					"previewBitmapData": pack.previewBitmapData,
					"previewCharacter": info.previewCharacter,
					"previewCostume": info.previewCostume != null ? info.previewCostume : -1,
					"folder": pack.folder
				});
			};

			sortByName(seriesEntries);
			sortByName(eventEntries);

			s_menuList = seriesEntries.concat(eventEntries);
			s_menuList.push({
				"id": DOWNLOAD_ID,
				"name": "Download new events",
				"description": "Browse community event packs posted on GameBanana and install them here.",
				"creator": "GameBanana",
				"expansion": true,
				"downloadEntry": true,
				"downloadUrl": DOWNLOAD_URL,
				"chooseCharacter": false,
				"classAPI": null,
				"previewBitmapData": null
			});
			return s_menuList;
		}

		private static function sortByName(list:Array):void
		{
			list.sort(function (a:Object, b:Object):int
			{
				var an:String = String(a && a.name != null ? a.name : "").toLowerCase();
				var bn:String = String(b && b.name != null ? b.name : "").toLowerCase();
				if (an < bn)
				{
					return -1;
				};
				if (an > bn)
				{
					return 1;
				};
				return 0;
			});
		}

		public static function getMenuList():Array
		{
			if (!s_menuList || s_menuList.length == 0)
			{
				return buildMenuList();
			};
			return s_menuList;
		}

		public static function findEventEntry(id:String):Object
		{
			var pack:Object = s_packs[id];
			var info:Object;
			if (!pack)
			{
				return null;
			};
			info = pack.info || {};
			return {
				"id": id,
				"name": info.name || id,
				"description": info.description || "",
				"creator": info.creator || "",
				"expansion": true,
				"chooseCharacter": isTruthy(info.chooseCharacter),
				"stageBackground": info.stageBackground ? String(info.stageBackground) : "",
				"classAPI": pack.classAPI,
				"previewBitmapData": pack.previewBitmapData,
				"previewCharacter": info.previewCharacter,
				"previewCostume": info.previewCostume != null ? info.previewCostume : -1,
				"folder": pack.folder,
				"seriesId": pack.seriesId,
				"seriesIndex": pack.seriesIndex
			};
		}

		/** Vault eventinfo often stores chooseCharacter as the string "true"/"false". */
		private static function isTruthy(v:*):Boolean
		{
			if (v === true || v === 1)
			{
				return true;
			};
			if (v === false || v == null || v === 0)
			{
				return false;
			};
			return String(v).toLowerCase() === "true" || String(v) === "1";
		}
	}
}
