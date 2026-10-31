package
{
	import flash.display.MovieClip;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageDisplayState;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.events.UncaughtErrorEvent;
	import flash.desktop.NativeApplication;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import flash.utils.getTimer;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.media.SoundMixer;
	import flash.media.Video;
	import flash.net.NetStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getQualifiedClassName;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;
	import ssf2mm.shared.VideoOverlay;

	/**
	 * Bridge for the SSF2 Stream Cursor extension.
	 *
	 * Deep-link flow (Versus/Training CSS must not race the first menu):
	 *   1. Wait until the engine has shown the home/main menu (MENU_SHOW).
	 *   2. Open CSS without disposeAllMenus(true) wiping player areas.
	 *   3. Call updateDisplay() until GameObj + CharSelectionBoxes are ready.
	 *   4. Optional instant match uses that CSS GameObj.
	 */
	public class Ssf2StreamMod extends Sprite
	{
		internal var m_host:*;
		internal var m_screen:String;
		internal var m_match:Object;
		internal var m_tries:int;
		internal var m_logFile:String;
		internal var m_logFileAbs:String;
		internal var m_didMatch:Boolean;
		internal var m_matchQueued:Boolean;

		internal var m_phase:String;
		internal var m_homeReady:Boolean;
		internal var m_homeStable:int;
		internal var m_cssMenu:*;
		internal var m_fixupTries:int;
		internal var m_matchArmTries:int;
		internal var m_didCssReset:Boolean;
		internal var m_didCssShow:Boolean;
		internal var m_pendingApply:Object;
		/** True while the onBoot launch.json deep-link is running — ignore Apply. */
		internal var m_bootDeepLink:Boolean;
		internal var m_eventId:String;
		internal var m_eventOverride:String;
		internal var m_eventStarted:Boolean;
		internal var m_eventClickPending:Boolean;
		internal var m_eventClickTries:int;
		internal var m_forcedMusicId:String;
		internal var m_musicEverywhere:Boolean;
		/** skip | default | intro1 | intro2 | intro3 | random | custom:<id> — from boot/launch.json */
		internal var m_bootIntro:String;
		/** Absolute path to custom FLV when bootIntro is custom:* */
		internal var m_bootIntroPath:String;
		/** When true, enter fullscreen after boot (from launch.json / boot.json). */
		internal var m_wantFullscreen:Boolean;
		/** When bootIntro is random: [{bootIntro, bootIntroPath?}, ...] */
		internal var m_randomPool:Array;
		/** Arcade attract on title (home / external). */
		internal var m_attract:AttractMode;
		internal var m_attractEnabled:Boolean;
		internal var m_introOverlay:VideoOverlay;
		internal var m_customIntroActive:Boolean;
		private var m_discordGuarded:Boolean;
		/** After vault intros (v8/v9), bounce Vault → Title on boot. */
		internal var m_redirectVaultToTitle:Boolean;
		/** Disclaimer → Intro3 should return to vault (vault + default intro). */
		internal var m_intro3ToVault:Boolean;
		/** vault launch: intro | costumes */
		internal var m_vaultAction:String;
		/** palette maker character when vaultAction=costumes */
		internal var m_vaultPaletteChar:String;
		/** One character to warm when vaultAction=cachewarm. Empty warms the roster. */
		internal var m_vaultCacheChar:String;
		private var m_bridgeDir:File;
		private var m_bridgeDirKey:String;
		/** Last logStepError line per step, so timer/frame writers log a stuck failure once. */
		private var m_lastStepError:Object;
		internal var prefsCtl:StreamLaunchPrefs;
		internal var introCtl:StreamBootIntro;
		internal var attractCtl:StreamAttractLink;
		internal var deepLinkCtl:StreamDeepLink;
		internal var cssCtl:StreamCssMenus;
		internal var eventsCtl:StreamEvents;
		internal var musicCtl:StreamMusic;
		internal var rosterCtl:StreamRoster;
		internal var matchCtl:StreamMatchStart;
		internal var cmdCtl:StreamCmdChannel;
		internal var catalogCtl:StreamCatalog;
		internal var cursorCtl:StreamCursor;
		internal var uncaughtCtl:StreamUncaughtHooks;
		internal var crashCtl:StreamCrash;


		public function Ssf2StreamMod()
		{
			super();
			prefsCtl = new StreamLaunchPrefs(this);
			introCtl = new StreamBootIntro(this);
			attractCtl = new StreamAttractLink(this);
			deepLinkCtl = new StreamDeepLink(this);
			cssCtl = new StreamCssMenus(this);
			eventsCtl = new StreamEvents(this);
			musicCtl = new StreamMusic(this);
			rosterCtl = new StreamRoster(this);
			matchCtl = new StreamMatchStart(this);
			cmdCtl = new StreamCmdChannel(this);
			catalogCtl = new StreamCatalog(this);
			cursorCtl = new StreamCursor(this);
			uncaughtCtl = new StreamUncaughtHooks(this);
			crashCtl = new StreamCrash(this);
			m_screen = "";
			m_match = null;
			m_tries = 0;
			m_logFile = "expansions/state/game.log";
			m_logFileAbs = "";
			m_didMatch = false;
			m_matchQueued = false;
			m_phase = "idle";
			m_homeReady = false;
			m_homeStable = 0;
			m_cssMenu = null;
			m_fixupTries = 0;
			m_matchArmTries = 0;
			m_didCssReset = false;
			m_didCssShow = false;
			m_pendingApply = null;
			m_bootDeepLink = false;
			m_eventId = "";
			m_eventOverride = "";
			m_eventStarted = false;
			m_eventClickPending = false;
			m_eventClickTries = 0;
			m_forcedMusicId = "";
			m_musicEverywhere = false;
			m_bootIntro = "default";
			m_bootIntroPath = "";
			m_wantFullscreen = false;
			m_randomPool = null;
			m_attract = null;
			m_attractEnabled = true;
			m_introOverlay = null;
			m_customIntroActive = false;
			m_redirectVaultToTitle = false;
			m_intro3ToVault = false;
			m_vaultAction = "intro";
			m_vaultPaletteChar = "mario";
			m_vaultCacheChar = "";
			m_lastStepError = {};
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			runStep("onBoot", "guardDiscordActivity", guardDiscordActivity);
			// Sticky prefs first (exe launch); launch.json may override for Stream deep-links.
			runStep("onBoot", "readBootPrefs", prefsCtl.readBootPrefs);
			runStep("onBoot", "readLaunch", prefsCtl.readLaunch);
			runStep("onBoot", "readMenuMusicFile", musicCtl.readMenuMusicFile);
			runStep("onBoot", "armMenuMusicPatch", musicCtl.armMenuMusicPatch);
			runStep("onBoot", "armSandbagSpawnPatch", matchCtl.armSandbagSpawnPatch);
			setTimeout(musicCtl.armMenuMusicPatch, 2000);
			runStep("onBoot", "pickRandomBootIntroIfNeeded", introCtl.pickRandomBootIntroIfNeeded);
			runStep("onBoot", "armUncaughtErrorLogging", uncaughtCtl.armUncaughtErrorLogging);
			runStep("onBoot", "armCursorReporting", cursorCtl.armCursorReporting);
			runStep("onBoot", "auditCredits", prefsCtl.auditCredits);
			runStep("onBoot", "applyFullscreenIfNeeded", prefsCtl.applyFullscreenIfNeeded);
			setTimeout(prefsCtl.applyFullscreenIfNeeded, 400);
			setTimeout(prefsCtl.applyFullscreenIfNeeded, 1500);
			runStep("onBoot", "setGameLogPath", setHostGameLogPath);
			log("onBoot screen=" + (m_screen || "(none)") + " match=" + (m_match ? "yes" : "no")
				+ " intro=" + m_bootIntro + " path=" + (m_bootIntroPath || "(none)"));
			runStep("onBoot", "clearStaleCmdOnBoot", cmdCtl.clearStaleCmdOnBoot);
			runStep("onBoot", "dumpCatalog", catalogCtl.dumpCatalog);
			runStep("onBoot", "startCmdWatcher", cmdCtl.startCmdWatcher);
			runStep("onBoot", "armAttractIfNeeded", attractCtl.armAttractIfNeeded);
			addBootHooks(host);
			if ((!m_screen || m_screen == "home") && !cssCtl.wantImmediateMatch())
			{
				return;
			};
			m_bootDeepLink = true;
			runStep("onBoot", "beginDeepLink", deepLinkCtl.beginDeepLink);
		}

		/** Point ModHost's game.log at launch.json's logFileAbs. */
		private function setHostGameLogPath():void
		{
			if (m_logFileAbs && m_logFileAbs.length > 0)
			{
				var MH:Class = EngineRefs.ModHost as Class;
				if (MH && MH["setGameLogPath"])
				{
					MH["setGameLogPath"](m_logFileAbs);
				};
			};
		}

		/**
		 * Always hook AFTER_BOOT so catalog dumps when mappings are ready.
		 * MODE_START forces custom match music after Multiman/CustomMode rebuild LevelData.
		 * onBootEnd removes every hook added here.
		 */
		private function addBootHooks(host:*):void
		{
			if (host)
			{
				try
				{
					host.addHook("AFTER_BOOT", onAfterBoot);
					host.addHook("MODE_START", musicCtl.onModeStart);
					host.addHook("MATCH_END", musicCtl.onMatchEndMusic);
					host.addHook("MATCH_START", uncaughtCtl.onMatchStartUncaught);
					host.addHook("MATCH_START", cursorCtl.onMatchStartCursor);
					host.addHook("MATCH_END", cursorCtl.onMatchEndCursor);
					host.addHook("BEFORE_INITIAL_MENU", introCtl.onBeforeInitialMenu);
					host.addHook("MENU_SHOW", onMenuShow);
					host.addHook("MENU_MUSIC", musicCtl.onMenuMusicHook);
				}
				catch (bootHookErr:*)
				{
					logStepError("onBoot addHook", bootHookErr);
				};
			};
		}

		public function onBootEnd():void
		{
			runStep("onBootEnd", "stopTick", deepLinkCtl.stopTick);
			runStep("onBootEnd", "stopCmdWatcher", cmdCtl.stopCmdWatcher);
			runStep("onBootEnd", "disarmCursorReporting", cursorCtl.disarmCursorReporting);
			runStep("onBootEnd", "disarmUncaughtErrorLogging", uncaughtCtl.disarmUncaughtErrorLogging);
			m_customIntroActive = false;
			runStep("onBootEnd", "finishCustomBootIntro", introCtl.finishCustomBootIntro);
			if (m_attract)
			{
				try
				{
					m_attract.detach();
				}
				catch (attrErr:*)
				{
					logStepError("onBootEnd attract.detach", attrErr);
				};
				m_attract = null;
			};
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("AFTER_BOOT", onAfterBoot);
					m_host["removeHook"]("MENU_SHOW", onMenuShow);
					m_host["removeHook"]("MENU_MUSIC", musicCtl.onMenuMusicHook);
					m_host["removeHook"]("MODE_START", musicCtl.onModeStart);
					m_host["removeHook"]("MATCH_END", musicCtl.onMatchEndMusic);
					m_host["removeHook"]("MATCH_START", uncaughtCtl.onMatchStartUncaught);
					m_host["removeHook"]("MATCH_START", cursorCtl.onMatchStartCursor);
					m_host["removeHook"]("MATCH_END", cursorCtl.onMatchEndCursor);
					m_host["removeHook"]("BEFORE_INITIAL_MENU", introCtl.onBeforeInitialMenu);
					m_host["unpatch"]("playMusic");
					m_host["unpatch"]("api.spawnCharacter");
				}
				catch (err:*)
				{
					logStepError("onBootEnd removeHook", err);
				};
			};
			m_host = null;
			m_cssMenu = null;
		}

		/** Runs one named step. A throw is logged as "<phase> <step> failed: <err>" and the caller goes on. */
		internal function runStep(phase:String, step:String, fn:Function):Boolean
		{
			try
			{
				fn();
				return (true);
			}
			catch (err:*)
			{
				logStepError(phase + " " + step, err);
			};
			return (false);
		}

		/** One log line for a failed critical step. dropRepeats skips an identical line (timer/frame writers). */
		internal function logStepError(step:String, err:*, dropRepeats:Boolean = false):void
		{
			var line:String;
			line = step + " failed: " + err;
			if (dropRepeats && m_lastStepError[step] == line)
			{
				return;
			};
			m_lastStepError[step] = line;
			log(line);
		}

		private function onAfterBoot(ctx:Object):void
		{
			// Boot finished; still wait for a real MENU_SHOW before deep-linking.
			uncaughtCtl.armUncaughtErrorLogging();
			cursorCtl.armCursorReporting();
			log("AFTER_BOOT — waiting for home menu");
			catalogCtl.dumpCatalog();
		}

		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var qn:String;
			uncaughtCtl.armUncaughtErrorLogging();
			cursorCtl.armCursorReporting();
			menu = ctx ? ctx.menu : null;
			if (!menu)
			{
				return;
			};
			if (m_customIntroActive)
			{
				introCtl.suppressMenusDuringCustomIntro(menu);
				return;
			};
			if (introCtl.isIntroPresentationMenu(menu))
			{
				return;
			};
			introCtl.maybeRedirectVaultToTitle(menu);
			// Once we're on title/main after boot, drop the one-shot vault→title divert
			// so the first real Vault open from Main isn't bounced away.
			qn = safeName(menu);
			if (qn.indexOf("TitleMenu") >= 0 || qn.indexOf("MainMenu") >= 0)
			{
				m_redirectVaultToTitle = false;
			};
			// Title stops BGM — drop stale jukebox hold so MainMenu can start playlist again.
			if (qn.indexOf("TitleMenu") >= 0)
			{
				try
				{
					if (m_host && m_host.setSessionFlag is Function)
					{
						m_host.setSessionFlag("music_player.bgm_hold", null);
					};
				}
				catch (holdClr:*)
				{
				};
			}
			else if (qn.indexOf("MainMenu") >= 0)
			{
				musicCtl.ensureMenuMusicPlaying();
			};
			if (m_intro3ToVault && qn.indexOf("Intro3Menu") >= 0)
			{
				try
				{
					if (menu["setVault"])
					{
						menu["setVault"](true);
					};
				}
				catch (i3Err:*)
				{
				};
			};
			if (m_phase == "wait_home")
			{
				if (introCtl.isBootGateMenu(menu) && introCtl.wantDeepLinkBoot())
				{
					// Disclaimer/intro must not count as "home ready" or deep-link CSS gets stomped.
					log("MENU_SHOW ignore boot gate: " + safeName(menu));
					return;
				};
				if (cssCtl.isTargetCssMenu(menu))
				{
					// CSS appeared early — let ENTER_FRAME finish init (avoid show→MENU_SHOW reentry).
					m_homeReady = true;
					m_homeStable = 99;
					m_cssMenu = menu;
					m_phase = "fixup";
					m_fixupTries = 0;
					log("MENU_SHOW already on target CSS — fixup");
					return;
				};
				m_homeReady = true;
				log("MENU_SHOW home/other ready: " + safeName(menu));
			}
			else if (m_phase == "fixup" || m_phase == "open_css" || m_phase == "match")
			{
				// Never call reset/show from MENU_SHOW — show() fires this hook and would recurse.
				if (cssCtl.isTargetCssMenu(menu))
				{
					m_cssMenu = menu;
				};
			};
		}

		internal function getRM():Class
		{
			try
			{
				return (EngineRefs.ResourceManager as Class);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function safeName(menu:*):String
		{
			try
			{
				return (getQualifiedClassName(menu));
			}
			catch (err:*)
			{
			};
			return ("?");
		}

		/** Writable expansions/state via absolute path (AIR blocks writes under applicationDirectory). */
		private function bridgeDir():File
		{
			var dir:File;
			var rel:File;
			try
			{
				if (m_logFileAbs && m_logFileAbs.length > 0 && !pathIsUnderData(m_logFileAbs))
				{
					dir = new File(m_logFileAbs).parent;
					if (dir)
					{
						return (dir);
					};
				};
			}
			catch (absErr:*)
			{
			};
			try
			{
				rel = File.applicationDirectory.resolvePath("expansions/state");
				dir = new File(rel.nativePath);
				if (dir)
				{
					return (dir);
				};
			}
			catch (nativeErr:*)
			{
			};
			return (null);
		}

		private function pathIsUnderData(path:String):Boolean
		{
			var flat:String;
			if (!path)
			{
				return (false);
			};
			flat = path.split("\\").join("/").toLowerCase();
			return (flat.indexOf("/data/") >= 0);
		}

		internal function bridgeFile(name:String):File
		{
			var dir:File;
			if (m_bridgeDir && m_bridgeDirKey == m_logFileAbs)
			{
				return (m_bridgeDir.resolvePath(name));
			};
			dir = bridgeDir();
			if (!dir)
			{
				return (null);
			};
			try
			{
				if (!dir.exists)
				{
					dir.createDirectory();
				};
				m_bridgeDir = dir;
				m_bridgeDirKey = m_logFileAbs;
				return (dir.resolvePath(name));
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function resolveSsf2mmFile(name:String):File
		{
			var dir:File;
			dir = bridgeDir();
			if (!dir)
			{
				return (null);
			};
			return (dir.resolvePath(name));
		}

		/** Discord updateActivity throws #3500 when the debugger's extension has no such method. titleMenu calls it before returning. */
		private function guardDiscordActivity():void
		{
			var SDK:Class;
			var proto:Object;
			var orig:Function;
			if (m_discordGuarded)
			{
				return;
			};
			try
			{
				SDK = EngineRefs.cls("com.jotard.ane.DiscordGameSDK") as Class;
				proto = SDK ? SDK["prototype"] : null;
				orig = proto ? proto["updateActivity"] as Function : null;
				if (!(orig is Function))
				{
					return;
				};
				m_discordGuarded = true;
				proto["updateActivity"] = function (activity:Object):void
				{
					try
					{
						orig.call(this, activity);
					}
					catch (callErr:*)
					{
						trace("[ssf2_stream] discord updateActivity " + callErr);
					};
				};
				log("discord updateActivity guarded");
			}
			catch (err:*)
			{
				m_discordGuarded = false;
				log("discord guard: " + err);
			};
		}

		internal function log(msg:String):void
		{
			var line:String;
			var MH:Class;
			line = "[ssf2_stream] " + msg;
			trace(line);
			try
			{
				MH = EngineRefs.ModHost as Class;
				if (MH && MH["appendGameLog"])
				{
					MH["appendGameLog"](line);
					return;
				};
			}
			catch (hostErr:*)
			{
			};
			try
			{
				var GL:Class = EngineRefs.GameLog as Class;
				if (GL && GL["write"])
				{
					GL["write"](line);
					return;
				};
			}
			catch (glErr:*)
			{
			};
			// ModHost/GameLog not loaded yet — write game.log directly.
			try
			{
				var file:File;
				var stream:FileStream;
				if (m_logFileAbs && m_logFileAbs.length > 0)
				{
					file = new File(m_logFileAbs);
				}
				else
				{
					file = File.applicationDirectory.resolvePath(m_logFile || "expansions/state/game.log");
				};
				file.parent.createDirectory();
				stream = new FileStream();
				stream.open(file, FileMode.APPEND);
				stream.writeUTFBytes(line + "\n");
				stream.close();
			}
			catch (err:*)
			{
			};
		}
	}
}
