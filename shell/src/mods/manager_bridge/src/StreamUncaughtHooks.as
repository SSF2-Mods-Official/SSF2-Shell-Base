package
{
	import flash.display.Stage;
	import flash.events.UncaughtErrorEvent;
	import flash.desktop.NativeApplication;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Arms UNCAUGHT_ERROR on the app, stage, main root and resource LoaderInfos.
	 */
	internal class StreamUncaughtHooks
	{
		private var core:Ssf2StreamMod;
		private var m_uncaughtAppArmed:Boolean;
		/** LoaderInfo urls already hooked for UNCAUGHT_ERROR (character SWFs included). */
		private var m_uncaughtLiKeys:Object;
		private var m_uncaughtLastArmLog:String;
		private var m_uncaughtTargets:Array = [];

		public function StreamUncaughtHooks(owner:Ssf2StreamMod)
		{
			core = owner;
			m_uncaughtAppArmed = false;
			m_uncaughtLiKeys = {};
			m_uncaughtLastArmLog = "";
		}

		internal function onMatchStartUncaught(ctx:Object):void
		{
			armUncaughtErrorLogging();
		}

		/**
		 * Auto-dismiss AIR / runtime uncaught dialogs (Launch SSF2 + Launch Debug)
		 * and mirror them to game.log + last_error.txt for Output → SSF2 Game.
		 *
		 * Character timeline NPEs (e.g. mugenkfm frame1 during HitBoxManager) fire on
		 * that SWF's LoaderInfo — not the stage. Arm every loaded resource MC.loaderInfo.
		 */
		internal function armUncaughtErrorLogging():void
		{
			var appOk:Boolean;
			var rootOk:Boolean;
			var stageOk:Boolean;
			var resCount:int;
			var newly:int;
			var status:String;
			appOk = false;
			rootOk = false;
			stageOk = false;
			resCount = 0;
			newly = 0;
			if (!m_uncaughtLiKeys)
			{
				m_uncaughtLiKeys = {};
			};
			try
			{
				if (armNativeUncaught())
				{
					appOk = true;
					newly++;
				}
				else
				{
					appOk = m_uncaughtAppArmed;
				};
			}
			catch (appErr:*)
			{
			};
			try
			{
				if (armMainRootLoaderInfo())
				{
					rootOk = true;
					newly++;
				}
				else
				{
					rootOk = hasArmedKeyPrefix("root:");
				};
			}
			catch (rootErr:*)
			{
			};
			try
			{
				if (armStageLoaderInfo())
				{
					stageOk = true;
					newly++;
				}
				else
				{
					stageOk = hasArmedKeyPrefix("stage:");
				};
			}
			catch (stErr:*)
			{
			};
			try
			{
				resCount = armResourceLoaderInfos();
				newly += resCount;
			}
			catch (resErr:*)
			{
			};
			status = "uncaught armed app=" + (appOk ? "Y" : "N")
				+ " root=" + (rootOk ? "Y" : "N")
				+ " stage=" + (stageOk ? "Y" : "N")
				+ " resources=" + countArmedResources()
				+ (newly > 0 ? (" (+" + newly + ")") : "");
			// Always log when new hooks added; otherwise only if status changed.
			if (newly > 0 || status != m_uncaughtLastArmLog)
			{
				m_uncaughtLastArmLog = status;
				log(status);
			};
		}

		private function hasArmedKeyPrefix(prefix:String):Boolean
		{
			var k:String;
			if (!m_uncaughtLiKeys)
			{
				return (false);
			};
			for (k in m_uncaughtLiKeys)
			{
				if (k && k.indexOf(prefix) == 0)
				{
					return (true);
				};
			};
			return (false);
		}

		private function countArmedResources():int
		{
			var k:String;
			var n:int;
			n = 0;
			if (!m_uncaughtLiKeys)
			{
				return (0);
			};
			for (k in m_uncaughtLiKeys)
			{
				if (k && k.indexOf("res:") == 0)
				{
					n++;
				};
			};
			return (n);
		}

		/** @return true if newly armed */
		private function armNativeUncaught():Boolean
		{
			var app:*;
			if (m_uncaughtAppArmed)
			{
				return (false);
			};
			app = NativeApplication.nativeApplication;
			if (!app || !app.uncaughtErrorEvents)
			{
				return (false);
			};
			app.uncaughtErrorEvents.addEventListener(
				UncaughtErrorEvent.UNCAUGHT_ERROR, core.crashCtl.onUncaughtError, false, int.MAX_VALUE, false);
			app.uncaughtErrorEvents.addEventListener(
				UncaughtErrorEvent.UNCAUGHT_ERROR, core.crashCtl.onUncaughtError, true, int.MAX_VALUE, false);
			m_uncaughtTargets.push(app.uncaughtErrorEvents);
			m_uncaughtAppArmed = true;
			return (true);
		}

		internal function disarmUncaughtErrorLogging():void
		{
			var n:int;
			for each (var target:* in m_uncaughtTargets)
			{
				try
				{
					target.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, core.crashCtl.onUncaughtError, false);
					target.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, core.crashCtl.onUncaughtError, true);
					n++;
				}
				catch (err:*)
				{
				};
			};
			m_uncaughtTargets = [];
			m_uncaughtLiKeys = {};
			m_uncaughtAppArmed = false;
			log("uncaught logging disarmed targets=" + n);
		}

		/** @return true if newly armed */
		private function armMainRootLoaderInfo():Boolean
		{
			var MainCls:Class;
			var root:*;
			var li:*;
			MainCls = EngineRefs.Main as Class;
			if (!MainCls)
			{
				return (false);
			};
			root = MainCls["Root"];
			if (!root)
			{
				root = MainCls["root"];
			};
			if (!root)
			{
				return (false);
			};
			li = root.loaderInfo;
			return (armOneLoaderInfo(li, "root"));
		}

		/** @return true if newly armed */
		private function armStageLoaderInfo():Boolean
		{
			var MainCls:Class;
			var root:*;
			var st:Stage;
			var li:*;
			st = null;
			try
			{
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? (MainCls["Root"] || MainCls["root"]) : null;
				if (root && root.stage)
				{
					st = root.stage as Stage;
				};
			}
			catch (e1:*)
			{
			};
			if (!st)
			{
				st = core.stage as Stage;
			};
			if (!st)
			{
				return (false);
			};
			li = st.loaderInfo;
			return (armOneLoaderInfo(li, "stage"));
		}

		/**
		 * Arm LoaderInfo on every loaded ResourceManager resource MC (character/stage SWFs).
		 * @return number newly armed
		 */
		private function armResourceLoaderInfos():int
		{
			var RM:Class;
			var resources:*;
			var hash:*;
			var i:int;
			var n:int;
			var res:*;
			var id:String;
			var newly:int;
			newly = 0;
			try
			{
				RM = EngineRefs.ResourceManager as Class;
			}
			catch (rmErr:*)
			{
				return (0);
			};
			if (!RM)
			{
				return (0);
			};
			try
			{
				resources = RM["resources"];
				if (resources)
				{
					n = int(resources.length);
					for (i = 0; i < n; i++)
					{
						res = resources[i];
						if (armResourceMc(res))
						{
							newly++;
						};
					};
				};
			}
			catch (vecErr:*)
			{
			};
			try
			{
				hash = RM["resourcesHash"];
				if (hash)
				{
					for (id in hash)
					{
						res = hash[id];
						if (armResourceMc(res))
						{
							newly++;
						};
					};
				};
			}
			catch (hashErr:*)
			{
			};
			return (newly);
		}

		private function armResourceMc(res:*):Boolean
		{
			var li:*;
			var id:String;
			if (!res)
			{
				return (false);
			};
			try
			{
				if (!res.Loaded)
				{
					return (false);
				};
			}
			catch (loadedErr:*)
			{
			};
			try
			{
				if (!res.MC || !res.MC.loaderInfo)
				{
					return (false);
				};
				li = res.MC.loaderInfo;
				id = String(res.ID || "");
				return (armOneLoaderInfo(li, "res:" + id));
			}
			catch (mcErr:*)
			{
			};
			return (false);
		}

		/**
		 * Hook one LoaderInfo if not already armed.
		 * @param tag short label used in dedupe key with li.url
		 * @return true if newly armed
		 */
		private function armOneLoaderInfo(li:*, tag:String):Boolean
		{
			var key:String;
			var url:String;
			if (!li || !li.uncaughtErrorEvents)
			{
				return (false);
			};
			url = "";
			try
			{
				url = String(li.url || "");
			}
			catch (urlErr:*)
			{
			};
			key = String(tag || "li") + ":" + (url.length > 0 ? url : String(li));
			if (m_uncaughtLiKeys[key])
			{
				return (false);
			};
			try
			{
				li.uncaughtErrorEvents.addEventListener(
					UncaughtErrorEvent.UNCAUGHT_ERROR, core.crashCtl.onUncaughtError, false, int.MAX_VALUE, false);
				li.uncaughtErrorEvents.addEventListener(
					UncaughtErrorEvent.UNCAUGHT_ERROR, core.crashCtl.onUncaughtError, true, int.MAX_VALUE, false);
				m_uncaughtTargets.push(li.uncaughtErrorEvents);
				m_uncaughtLiKeys[key] = true;
				return (true);
			}
			catch (armErr:*)
			{
			};
			return (false);
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
