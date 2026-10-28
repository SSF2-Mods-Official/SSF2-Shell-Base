package
{
	/**
	 * Editor keys in the extension save, through ModHost.saveExtGet / saveExtSet.
	 * Each saveExtSet rewrites the whole save file (SaveData.saveGame), so callers batch writes
	 * and clearKeys only touches keys that hold a value. Never throws.
	 */
	public class EditorSave
	{
		/** Error text from the last setJson that failed both ways. */
		public static var lastError:String = "";

		/** The stored value of key, then oldKey when key is unset. Null on a miss or a host error. */
		public static function get(host:*, key:String, oldKey:String = null):*
		{
			var raw:*;
			if (!host)
			{
				return (null);
			};
			try
			{
				raw = host.saveExtGet(key, null);
				if (raw == null && oldKey)
				{
					raw = host.saveExtGet(oldKey, null);
				};
			}
			catch (err:*)
			{
				raw = null;
			};
			return (raw);
		}

		/** get, with a String value parsed as JSON. Null when the string does not parse. */
		public static function getJson(host:*, key:String, oldKey:String = null):*
		{
			var raw:*;
			raw = get(host, key, oldKey);
			if (raw is String)
			{
				try
				{
					raw = JSON.parse(String(raw));
				}
				catch (parseErr:*)
				{
					raw = null;
				};
			};
			return (raw);
		}

		public static function has(host:*, key:String, oldKey:String = null):Boolean
		{
			var raw:*;
			raw = get(host, key, oldKey);
			return (raw != null && raw != "");
		}

		public static function loadRows(host:*, key:String, oldKey:String = null):Array
		{
			return (GridRows.parseRows(get(host, key, oldKey)));
		}

		/** Stores JSON.stringify(value); falls back to the raw value. 1 = JSON, 2 = raw, 0 = failed (see lastError). */
		public static function setJson(host:*, key:String, value:*):int
		{
			if (!host)
			{
				lastError = "no host";
				return (0);
			};
			try
			{
				host.saveExtSet(key, JSON.stringify(value));
				return (1);
			}
			catch (err:*)
			{
				try
				{
					host.saveExtSet(key, value);
					return (2);
				}
				catch (err2:*)
				{
					lastError = String(err2);
				};
			};
			return (0);
		}

		/** Sets key to null only when it holds a value. Returns how many keys were cleared. */
		public static function clearKeys(host:*, keys:Array):int
		{
			var cleared:int;
			var key:String;
			if (!host || !keys)
			{
				return (0);
			};
			for each (key in keys)
			{
				try
				{
					if (key && host.saveExtGet(key, null) != null)
					{
						host.saveExtSet(key, null);
						cleared++;
					};
				}
				catch (err:*)
				{
				};
			};
			return (cleared);
		}

		/** Saved id list as a set: {id: true}. */
		public static function loadIdSet(host:*, key:String):Object
		{
			var list:Array;
			var out:Object;
			var i:int;
			out = {};
			list = GridRows.asList(getJson(host, key));
			i = 0;
			while (list && i < list.length)
			{
				if (list[i])
				{
					out[String(list[i])] = true;
				};
				i++;
			};
			return (out);
		}

		public static function writeIdSet(host:*, key:String, seen:Object):void
		{
			var list:Array;
			var id:String;
			if (!host || !seen)
			{
				return;
			};
			list = [];
			for (id in seen)
			{
				if (id && seen[id])
				{
					list.push(id);
				};
			};
			setJson(host, key, list);
		}
	}
}
