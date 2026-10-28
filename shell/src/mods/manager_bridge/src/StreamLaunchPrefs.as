package
{
	import flash.display.Stage;
	import flash.display.StageDisplayState;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/**
	 * launch.json / boot.json: sticky boot prefs, the Stream launch handshake,
	 * fullscreen and vault prefs. Read once in onBoot before the title screen.
	 */
	internal class StreamLaunchPrefs
	{
		private var core:Ssf2StreamMod;

		public function StreamLaunchPrefs(owner:Ssf2StreamMod)
		{
			core = owner;
		}

		internal function applyVaultPrefsFromData(data:Object):void
		{
			if (!data)
			{
				return;
			};
			if (data["vaultAction"])
			{
				core.m_vaultAction = String(data["vaultAction"]).toLowerCase();
			};
			if (data["vaultPaletteChar"])
			{
				core.m_vaultPaletteChar = String(data["vaultPaletteChar"]);
			};
			if (data.hasOwnProperty("vaultCacheChar"))
			{
				core.m_vaultCacheChar = String(data["vaultCacheChar"] || "");
			};
		}

		internal function readBootPrefs():void
		{
			var file:File;
			var stream:FileStream;
			var text:String;
			var data:Object;
			try
			{
				file = File.applicationDirectory.resolvePath("expansions/state/boot.json");
				if (!file.exists)
				{
					file = core.bridgeFile("boot.json");
				};
				data = JsonFile.read(file);
				if (!data)
				{
					return;
				};
				if (data.bootIntro)
				{
					core.m_bootIntro = String(data.bootIntro).toLowerCase();
				};
				core.m_bootIntroPath = "";
				if (data.bootIntroPath)
				{
					core.m_bootIntroPath = String(data.bootIntroPath);
				};
				if (data.randomPool is Array && (data.randomPool as Array).length > 0)
				{
					core.m_randomPool = data.randomPool as Array;
				}
				else
				{
					// Older / fixed-boot writes only randomPoolKeys + customs.
					core.m_randomPool = core.attractCtl.buildRandomPoolFromBootData(data);
				};
				applyVaultPrefsFromData(data);
				if (data.hasOwnProperty("fullscreen"))
				{
					core.m_wantFullscreen = Boolean(data.fullscreen);
				};
				if (data.hasOwnProperty("attractMode"))
				{
					core.m_attractEnabled = Boolean(data.attractMode);
				}
				else if (data.hasOwnProperty("attract"))
				{
					core.m_attractEnabled = Boolean(data.attract);
				};
				log("boot.json intro=" + core.m_bootIntro + " path=" + (core.m_bootIntroPath || "(none)")
					+ " pool=" + (core.m_randomPool ? core.m_randomPool.length : 0)
					+ " fullscreen=" + core.m_wantFullscreen
					+ " attract=" + core.m_attractEnabled);
			}
			catch (err:*)
			{
				log("boot.json error: " + err);
			};
		}

		internal function readLaunch():void
		{
			var file:File;
			var clearTarget:File;
			var data:Object;
			try
			{
				// Extension writes under the build tree; read works on applicationDirectory.
				file = File.applicationDirectory.resolvePath("expansions/state/launch.json");
				if (!file.exists)
				{
					file = core.bridgeFile("launch.json");
				};
				data = JsonFile.read(file);
				if (!data)
				{
					return;
				};
				applyLaunchJson(data);
				// Clear via absolute bridge path (delete under applicationDirectory often fails).
				clearTarget = core.bridgeFile("launch.json");
				if (clearTarget)
				{
					core.cmdCtl.clearCmdFile(clearTarget);
				}
				else
				{
					core.cmdCtl.clearCmdFile(file);
				};
			}
			catch (err:*)
			{
				log("launch.json error: " + err);
			};
		}

		/** launch.json keys: logFile(Abs), screen, eventId, music, match, vault, bootIntro, randomPool, fullscreen. */
		private function applyLaunchJson(data:Object):void
		{
			if (data.logFile)
			{
				core.m_logFile = String(data.logFile);
			};
			if (data.logFileAbs)
			{
				core.m_logFileAbs = String(data.logFileAbs);
			};
			if (data.screen)
			{
				core.m_screen = String(data.screen).toLowerCase();
			};
			if (core.m_screen == "jukebox" && core.m_host && core.m_host.setSessionFlag is Function)
			{
				core.m_host.setSessionFlag("music_player.open_jukebox", true);
			};
			if (data.eventId)
			{
				core.m_eventId = String(data.eventId);
				core.m_eventOverride = data.eventCharacter ? String(data.eventCharacter) : "";
				core.m_eventStarted = false;
				core.m_eventClickPending = false;
				core.m_eventClickTries = 0;
			};
			if (Boolean(data.musicEverywhere) && data.musicId)
			{
				core.m_musicEverywhere = true;
				core.m_forcedMusicId = String(data.musicId);
			}
			else if (data.hasOwnProperty("musicEverywhere") || data.hasOwnProperty("musicId"))
			{
				core.musicCtl.clearForcedMatchMusic();
			};
			if (data.match)
			{
				core.m_match = data.match as Object;
			};
			applyVaultPrefsFromData(data);
			if (data.bootIntro)
			{
				core.m_bootIntro = String(data.bootIntro).toLowerCase();
			};
			if (data.bootIntroPath)
			{
				core.m_bootIntroPath = String(data.bootIntroPath);
			}
			else if (data.bootIntro)
			{
				// Explicit launch override without a path (builtin / skip / random).
				core.m_bootIntroPath = "";
			};
			if (data.randomPool is Array && (data.randomPool as Array).length > 0)
			{
				core.m_randomPool = data.randomPool as Array;
			}
			else if (data.randomPoolKeys is Array || data.customs is Array)
			{
				core.m_randomPool = core.attractCtl.buildRandomPoolFromBootData(data);
			};
			if (data.hasOwnProperty("fullscreen"))
			{
				core.m_wantFullscreen = Boolean(data.fullscreen);
			};
		}

		/** Enter fullscreen when launch/boot asked for it (Configure → Open in fullscreen). */
		internal function applyFullscreenIfNeeded():void
		{
			var MainCls:Class;
			var root:*;
			var st:Stage;
			if (!core.m_wantFullscreen)
			{
				return;
			};
			try
			{
				MainCls = EngineRefs.Main as Class;
				if (!MainCls)
				{
					return;
				};
				if (MainCls["isFullscreen"])
				{
					return;
				};
				root = MainCls["Root"] || MainCls["root"];
				st = root && root.stage ? (root.stage as Stage) : (core.stage as Stage);
				if (!st)
				{
					return;
				};
				st.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
				log("fullscreen on");
			}
			catch (fsErr:*)
			{
				log("fullscreen: " + fsErr);
			};
		}

		/** Ensure Credits.txt lists every expansion pack (restore missing entries). */
		internal function auditCredits():void
		{
			var audit:CreditsAudit;
			try
			{
				audit = new CreditsAudit(log);
				audit.ensure();
			}
			catch (err:*)
			{
				log("credits: " + err);
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
