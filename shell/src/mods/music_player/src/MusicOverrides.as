package
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/**
	 * Writable user overrides for stock list.json (never mutate list.json at runtime).
	 * applicationStorageDirectory/music_player/overrides.json
	 */
	public class MusicOverrides
	{
		private static var s_data:Object;
		private static var s_loaded:Boolean;

		public static function load():void
		{
			var file:File;
			var stream:FileStream;
			var raw:String;
			if (s_loaded)
			{
				return;
			};
			s_loaded = true;
			s_data = {"version": 1, "tracks": {}, "customSeries": {}, "seriesLabels": {}, "theme": {}};
			try
			{
				file = storageFile();
				if (!file || !file.exists)
				{
					return;
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				raw = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				s_data = JSON.parse(raw);
				if (!s_data.tracks)
				{
					s_data.tracks = {};
				};
				if (!s_data.customSeries)
				{
					s_data.customSeries = {};
				};
				if (!s_data.seriesLabels)
				{
					s_data.seriesLabels = {};
				};
				if (!s_data.theme)
				{
					s_data.theme = {};
				};
			}
			catch (err:*)
			{
				try
				{
					if (stream)
					{
						stream.close();
					};
				}
				catch (closeErr:*)
				{
				};
			};
		}

		public static function save():void
		{
			var file:File;
			var stream:FileStream;
			load();
			try
			{
				file = storageFile();
				if (!file)
				{
					return;
				};
				if (file.parent && !file.parent.exists)
				{
					file.parent.createDirectory();
				};
				stream = new FileStream();
				stream.open(file, FileMode.WRITE);
				stream.writeUTFBytes(JSON.stringify(s_data));
				stream.close();
			}
			catch (err:*)
			{
				try
				{
					if (stream)
					{
						stream.close();
					};
				}
				catch (closeErr:*)
				{
				};
			};
		}

		public static function trackOverride(trackId:String):Object
		{
			load();
			if (!trackId || !s_data.tracks)
			{
				return (null);
			};
			return s_data.tracks[trackId] as Object;
		}

		public static function setTrackFields(trackId:String, fields:Object):void
		{
			var cur:Object;
			var k:String;
			if (!trackId || !fields)
			{
				return;
			};
			load();
			cur = s_data.tracks[trackId] as Object;
			if (!cur)
			{
				cur = {};
				s_data.tracks[trackId] = cur;
			};
			for (k in fields)
			{
				if (fields[k] == null || fields[k] === "")
				{
					delete cur[k];
				}
				else
				{
					cur[k] = fields[k];
				};
			};
			save();
		}

		public static function customSeries():Object
		{
			load();
			return s_data.customSeries || {};
		}

		public static function putCustomSeries(id:String, label:String, symbolKey:String, stageArt:String):void
		{
			if (!id)
			{
				return;
			};
			load();
			s_data.customSeries[id] = {
				"label": label || id,
				"symbolKey": symbolKey || "",
				"stageArt": stageArt || ""
			};
			save();
		}

		public static function getCustomSeries(id:String):Object
		{
			load();
			if (!id || !s_data.customSeries)
			{
				return (null);
			};
			return s_data.customSeries[id] as Object;
		}

		public static function removeCustomSeries(id:String):void
		{
			if (!id)
			{
				return;
			};
			load();
			delete s_data.customSeries[id];
			if (s_data.seriesLabels)
			{
				delete s_data.seriesLabels[id];
			};
			save();
		}

		public static function setCustomSeriesFields(id:String, fields:Object):void
		{
			var cur:Object;
			var k:String;
			if (!id || !fields)
			{
				return;
			};
			load();
			cur = s_data.customSeries[id] as Object;
			if (!cur)
			{
				cur = {"label": id, "symbolKey": "", "stageArt": ""};
				s_data.customSeries[id] = cur;
			};
			for (k in fields)
			{
				if (fields[k] == null || fields[k] === "")
				{
					delete cur[k];
				}
				else
				{
					cur[k] = fields[k];
				};
			};
			save();
		}

		public static function setSeriesLabel(seriesKey:String, label:String):void
		{
			var custom:Object;
			if (!seriesKey)
			{
				return;
			};
			load();
			if (!label)
			{
				delete s_data.seriesLabels[seriesKey];
			}
			else
			{
				s_data.seriesLabels[seriesKey] = label;
			};
			custom = s_data.customSeries[seriesKey] as Object;
			if (custom && label)
			{
				custom.label = label;
			};
			save();
		}

		public static function seriesLabel(seriesKey:String):String
		{
			var custom:Object;
			load();
			if (seriesKey && s_data.seriesLabels && s_data.seriesLabels[seriesKey])
			{
				return String(s_data.seriesLabels[seriesKey]);
			};
			custom = seriesKey ? s_data.customSeries[seriesKey] as Object : null;
			if (custom && custom.label)
			{
				return String(custom.label);
			};
			return (null);
		}

		public static function themeColor(key:String, fallback:uint):uint
		{
			var v:*;
			load();
			if (!s_data.theme)
			{
				return (fallback);
			};
			v = s_data.theme[key];
			if (v == null)
			{
				return (fallback);
			};
			return uint(v);
		}

		public static function setThemeColor(key:String, color:uint):void
		{
			if (!key)
			{
				return;
			};
			load();
			if (!s_data.theme)
			{
				s_data.theme = {};
			};
			s_data.theme[key] = color;
			save();
		}

		public static function themeFlag(key:String, fallback:Boolean):Boolean
		{
			var v:*;
			load();
			if (!s_data.theme)
			{
				return (fallback);
			};
			v = s_data.theme[key];
			if (v == null)
			{
				return (fallback);
			};
			return Boolean(v);
		}

		public static function setThemeFlag(key:String, on:Boolean):void
		{
			if (!key)
			{
				return;
			};
			load();
			if (!s_data.theme)
			{
				s_data.theme = {};
			};
			s_data.theme[key] = on ? true : false;
			save();
		}

		private static function storageFile():File
		{
			try
			{
				return File.applicationStorageDirectory.resolvePath("music_player/overrides.json");
			}
			catch (err:*)
			{
			};
			return (null);
		}
	}
}
