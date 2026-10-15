package
{
	import flash.system.System;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Game-wide memory + ResourceManager load counts (attract / leaks).
	 * Logs flashMb, privateMb, and how many RM entries are Loaded.
	 */
	public class ResourceMem
	{
		private static var s_lastFlash:Number = 0;

		public static function snap(tag:String, extra:String = ""):void
		{
			var total:Number;
			var priv:Number;
			var delta:Number;
			var loaded:int;
			var known:int;
			var poolLoaded:int;
			var msg:String;
			try
			{
				total = Number(System.totalMemory);
				priv = 0;
				try
				{
					priv = Number(System["privateMemory"]);
				}
				catch (pErr:*)
				{
				};
				delta = s_lastFlash > 0 ? (total - s_lastFlash) : 0;
				s_lastFlash = total;
				loaded = countLoaded();
				known = countKnown();
				poolLoaded = countPoolLoaded();
				msg = "[ResourceManager][mem] " + tag
					+ " flashMb=" + int(total / 1048576)
					+ " dFlash=" + (delta >= 0 ? "+" : "") + int(delta / 1048576);
				if (priv > 0)
				{
					msg += " privateMb=" + int(priv / 1048576);
				};
				msg += " loaded=" + loaded + "/" + known + " poolL=" + poolLoaded;
				if (extra)
				{
					msg += " " + extra;
				};
				print(msg);
			}
			catch (err:*)
			{
			};
		}

		private static function countLoaded():int
		{
			var RM:*;
			var hash:Object;
			var id:String;
			var res:*;
			var n:int;
			try
			{
				RM = EngineRefs.ResourceManager;
				hash = RM ? RM["resourcesHash"] : null;
				if (!hash)
				{
					return (0);
				};
				n = 0;
				for (id in hash)
				{
					res = hash[id];
					if (res && Boolean(res["Loaded"]))
					{
						n++;
					};
				};
				return (n);
			}
			catch (err:*)
			{
			};
			return (0);
		}

		/** Non-null resourcesHash slots (null = unloaded stub key). */
		private static function countKnown():int
		{
			var RM:*;
			var hash:Object;
			var id:String;
			var n:int;
			try
			{
				RM = EngineRefs.ResourceManager;
				hash = RM ? RM["resourcesHash"] : null;
				if (!hash)
				{
					return (0);
				};
				n = 0;
				for (id in hash)
				{
					if (hash[id])
					{
						n++;
					};
				};
				return (n);
			}
			catch (err:*)
			{
			};
			return (0);
		}

		/** Loaded entries still sitting in poolHash (survives resourcesHash null). */
		private static function countPoolLoaded():int
		{
			var RM:*;
			var hash:Object;
			var id:String;
			var res:*;
			var n:int;
			try
			{
				RM = EngineRefs.ResourceManager;
				hash = RM ? RM["poolHash"] : null;
				if (!hash)
				{
					return (0);
				};
				n = 0;
				for (id in hash)
				{
					res = hash[id];
					if (res && Boolean(res["Loaded"]))
					{
						n++;
					};
				};
				return (n);
			}
			catch (err:*)
			{
			};
			return (0);
		}

		private static function print(msg:String):void
		{
			var Api:*;
			var Host:*;
			try
			{
				Api = EngineRefs.ssf2("api.SSF2API");
				if (Api && Api["print"] is Function)
				{
					Api["print"](msg);
					return;
				};
			}
			catch (apiErr:*)
			{
			};
			try
			{
				Host = EngineRefs.ModHost;
				if (Host && Host["appendGameLog"] is Function)
				{
					Host["appendGameLog"](msg);
					return;
				};
			}
			catch (hostErr:*)
			{
			};
			trace(msg);
		}
	}
}
