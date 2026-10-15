package
{
	import flash.display.MovieClip;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;

	import ssf2mm.shared.EngineRefs;

	use namespace flash_proxy;

	/**
	 * PSB MenuAPIWrapper — stage initAPI / timeline SSF2API calls.
	 * getStage() MUST return the stage script instance (e.g. finaldestination) so
	 * startPhase3 / killPhase3 / frames resolve — not the sealed MenuBgStageStub.
	 */
	public dynamic class MenuBgApiProxy extends Proxy
	{
		private var m_engineAPI:*;
		private var m_stageScript:*;
		private var m_stageStub:*;

		public function MenuBgApiProxy(engineAPI:*)
		{
			super();
			m_engineAPI = engineAPI;
			m_stageScript = null;
			m_stageStub = null;
		}

		public function setStageScript(instance:*):void
		{
			m_stageScript = instance;
		}

		public function setStageStub(stub:*):void
		{
			m_stageStub = stub;
		}

		override flash_proxy function callProperty(name:*, ... rest):*
		{
			var key:String;
			key = String(name);
			if (key == "isReady")
			{
				return true;
			};
			if (key == "getQualitySettings")
			{
				return qualitySettings();
			};
			if (key == "getStage")
			{
				return stageForScripts();
			};
			if (key == "getCurrentMusicInfo")
			{
				return currentMusicInfo();
			};
			if (key == "getTimestamp")
			{
				return timestampNow();
			};
			if (key == "getPlatform")
			{
				return platformByName(rest.length > 0 ? rest[0] : null);
			};
			if (key == "getPlatforms")
			{
				return [];
			};
			if (key == "safeRandom" || key == "random")
			{
				return Math.random();
			};
			if (key == "safeRandomInteger")
			{
				return randomInteger(rest.length > 0 ? int(rest[0]) : 0, rest.length > 1 ? int(rest[1]) : 0);
			};
			if (key == "randomInteger")
			{
				return randomInteger(rest.length > 0 ? int(rest[0]) : 0, rest.length > 1 ? int(rest[1]) : 0);
			};
			if (key == "getCharacters")
			{
				return liveCharacters();
			};
			if (key == "getDeathBounds")
			{
				return deathBoundsStub();
			};
			if (key == "playSound")
			{
				return playSoundSafe(rest.length > 0 ? rest[0] : null, rest.length > 1 ? Boolean(rest[1]) : false);
			};
			if (key == "print")
			{
				if (rest.length > 0)
				{
					trace("[menu_bg_api] " + rest[0]);
				};
				return null;
			};
			if (key == "spawnEnemy")
			{
				return null;
			};
			return forwardCall(name, rest);
		}

		override flash_proxy function getProperty(name:*):*
		{
			var key:String;
			key = String(name);
			if (key == "isReady")
			{
				return function():Boolean
				{
					return true;
				};
			};
			if (key == "getQualitySettings")
			{
				return (qualitySettings as Function);
			};
			if (key == "getStage")
			{
				return (stageForScripts as Function);
			};
			if (key == "getCurrentMusicInfo")
			{
				return (currentMusicInfo as Function);
			};
			if (key == "getTimestamp")
			{
				return (timestampNow as Function);
			};
			if (key == "getPlatform")
			{
				return (platformByName as Function);
			};
			if (key == "getPlatforms")
			{
				return function(... rest):Array
				{
					return [];
				};
			};
			if (key == "safeRandom" || key == "random")
			{
				return (Math.random as Function);
			};
			if (key == "getCharacters")
			{
				return (liveCharacters as Function);
			};
			if (key == "getDeathBounds")
			{
				return (deathBoundsStub as Function);
			};
			if (key == "playSound")
			{
				return (playSoundSafe as Function);
			};
			if (key == "print")
			{
				return function(msg:*):void
				{
					trace("[menu_bg_api] " + msg);
				};
			};
			if (key == "spawnEnemy")
			{
				return function(... rest):*
				{
					return null;
				};
			};
			if (m_engineAPI)
			{
				return m_engineAPI[name];
			};
			return undefined;
		}

		override flash_proxy function setProperty(name:*, value:*):void
		{
			if (m_engineAPI)
			{
				m_engineAPI[name] = value;
			};
		}

		override flash_proxy function hasProperty(name:*):Boolean
		{
			var key:String;
			key = String(name);
			if (key == "isReady" || key == "getQualitySettings" || key == "getStage" || key == "getCurrentMusicInfo"
				|| key == "getTimestamp" || key == "getPlatform" || key == "getPlatforms"
				|| key == "safeRandom" || key == "random" || key == "safeRandomInteger" || key == "randomInteger"
				|| key == "getCharacters" || key == "getDeathBounds" || key == "playSound" || key == "print"
				|| key == "spawnEnemy")
			{
				return true;
			};
			return m_engineAPI != null && (name in m_engineAPI);
		}

		/**
		 * Real match roster when a stage script runs as camera BG.
		 * Empty list meant KO listeners (e.g. Jungle Island checkDead) never attached.
		 */
		private function liveCharacters():Array
		{
			var list:*;
			try
			{
				if (m_engineAPI && m_engineAPI.getCharacters is Function)
				{
					list = m_engineAPI.getCharacters();
					if (list is Array)
					{
						return list as Array;
					};
				};
			}
			catch (err:*)
			{
			};
			return [];
		}

		private function forwardCall(name:*, args:Array):*
		{
			var fn:Function;
			if (!m_engineAPI)
			{
				return null;
			};
			fn = m_engineAPI[name] as Function;
			if (fn == null)
			{
				return null;
			};
			try
			{
				return fn.apply(null, args);
			}
			catch (callErr:*)
			{
			};
			return null;
		}

		/** FD timeline: getStage().startPhase3 / frames / killPhase3 */
		private function stageForScripts():*
		{
			return m_stageScript;
		}

		/** Smashville (and others): real clock for time-of-day layers. */
		private function timestampNow():Date
		{
			var d:*;
			try
			{
				if (m_engineAPI && m_engineAPI.getTimestamp is Function)
				{
					d = m_engineAPI.getTimestamp();
					if (d is Date)
					{
						return d as Date;
					};
				};
			}
			catch (apiErr:*)
			{
			};
			return new Date();
		}

		/**
		 * Smashville syncStage calls getPlatform("smashvillePlatform").getMC().gotoAndStop(...).
		 * Without a soft stub that throws and never reaches camera BG time-of-day frames.
		 */
		private function platformByName(subject:*):Object
		{
			var clip:MovieClip;
			var name:String;
			var live:*;
			clip = null;
			name = subject != null ? String(subject) : "";
			try
			{
				if (m_engineAPI && m_engineAPI.getPlatform is Function)
				{
					live = m_engineAPI.getPlatform(subject);
					if (live)
					{
						return live;
					};
				};
			}
			catch (apiErr:*)
			{
			};
			clip = findNamedClip(name);
			return new MenuBgPlatformStub(clip);
		}

		private function findNamedClip(name:String):MovieClip
		{
			var mid:MovieClip;
			var bg:MovieClip;
			var fg:MovieClip;
			if (!name || !m_stageStub)
			{
				return null;
			};
			try
			{
				mid = m_stageStub.getMidground() as MovieClip;
				if (mid && mid[name] is MovieClip)
				{
					return mid[name] as MovieClip;
				};
			}
			catch (midErr:*)
			{
			};
			try
			{
				bg = m_stageStub.getBackground() as MovieClip;
				if (bg && bg[name] is MovieClip)
				{
					return bg[name] as MovieClip;
				};
			}
			catch (bgErr:*)
			{
			};
			try
			{
				fg = m_stageStub.getForeground() as MovieClip;
				if (fg && fg[name] is MovieClip)
				{
					return fg[name] as MovieClip;
				};
			}
			catch (fgErr:*)
			{
			};
			return null;
		}

		private function deathBoundsStub():MovieClip
		{
			var mc:MovieClip;
			mc = new MovieClip();
			mc.x = -100;
			mc.y = -100;
			mc.graphics.beginFill(0, 0);
			mc.graphics.drawRect(0, 0, 1200, 800);
			mc.graphics.endFill();
			return mc;
		}

		private function randomInteger(min:int, max:int):int
		{
			if (max < min)
			{
				return min;
			};
			return min + int(Math.random() * (max - min + 1));
		}

		private function playSoundSafe(linkage:*, vfx:Boolean = false):int
		{
			try
			{
				if (m_engineAPI && m_engineAPI.playSound is Function)
				{
					return int(m_engineAPI.playSound(linkage, vfx));
				};
			}
			catch (apiErr:*)
			{
			};
			return 0;
		}

		private function currentMusicInfo():Object
		{
			var SQ:*;
			var info:Object;
			try
			{
				if (m_engineAPI && m_engineAPI.getCurrentMusicInfo is Function)
				{
					info = m_engineAPI.getCurrentMusicInfo();
					if (info)
					{
						return info;
					};
				};
			}
			catch (apiErr:*)
			{
			};
			try
			{
				SQ = EngineRefs.SoundQueue;
				if (SQ && SQ.instance)
				{
					return {
						"linkage": SQ.instance.CurrentSongID,
						"loop": SQ.instance.LoopLocation,
						"position": (SQ.instance.CurrentSong ? SQ.instance.CurrentSong.position : -1)
					};
				};
			}
			catch (sqErr:*)
			{
			};
			return {
				"linkage": null,
				"loop": 0,
				"position": -1
			};
		}

		private function qualitySettings():Object
		{
			var SaveData:*;
			var qs:Object;
			try
			{
				if (m_engineAPI && m_engineAPI.getQualitySettings is Function)
				{
					qs = m_engineAPI.getQualitySettings();
					if (qs)
					{
						return qs;
					};
				};
			}
			catch (apiErr:*)
			{
			};
			try
			{
				SaveData = EngineRefs.SaveData;
				if (SaveData && SaveData.Quality)
				{
					return SaveData.Quality;
				};
			}
			catch (sdErr:*)
			{
			};
			return {
				"stage_effects": "enabled",
				"menu_bg": true,
				"weather": true
			};
		}
	}
}
