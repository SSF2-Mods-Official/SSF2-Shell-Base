package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.media.SoundMixer;
	import flash.system.System;
	import flash.ui.Keyboard;
	import flash.utils.Timer;
	import flash.utils.clearTimeout;
	import flash.utils.getQualifiedClassName;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.VideoOverlay;

	/**
	 * Arcade-style attract on the title screen (external / home launches):
	 * idle → live CPU demo → How to Play FLV → live CPU demo → random intro → repeat.
	 * F2 on title starts a live demo immediately.
	 */
	public class AttractMode
	{
		private static const IDLE_FRAMES:int = 30 * 22;
		private static const STEPS:Array = ["demo", "howto", "demo", "intro"];

		private var m_log:Function;
		private var m_host:*;
		private var m_enabled:Boolean;
		internal var m_onTitle:Boolean;
		private var m_idle:int;
		private var m_step:int;
		internal var m_busy:Boolean;
		internal var m_kind:String;
		internal var m_demoFrames:int;
		internal var m_demoPhase:int;
		internal var m_focusOrder:Array;
		internal var m_hudHidden:Boolean;
		internal var m_logoLayer:Sprite;
		internal var m_howto:VideoOverlay;
		private var m_armedRoot:Boolean;
		internal var m_pickIntro:Function;
		private var m_abortIntro:Function;
		private var m_mediaSuspended:Boolean;
		/** Ignore skip for a short beat after FLV starts (avoids start-frame false cancels). */
		internal var m_skipArmed:Boolean;
		/** After My Jukebox on title: no attract until leave + re-enter title. */
		private var m_holdUntilTitleReentry:Boolean;
		private var m_deepLinkHold:Boolean;
		private var m_sawJukeboxOverlay:Boolean;
		/** TitleMenu instance from MENU_SHOW — never use MenuController.titleMenu getter (Discord RP). */
		private var m_titleMenuRef:*;
		/** True while sitting on title between playlist segments — ignore menu churn resetting m_step. */
		private var m_playlistHold:Boolean;
		/** Prevent stacked finishSegment timeouts from double-firing runNextStep. */
		private var m_nextStepTimer:uint;
		/** Resource ids loaded for the current live demo (trim after match). */
		internal var m_demoLoadedIds:Array;
		/** Pause on title between playlist segments (ms). */
		private static const SEGMENT_GAP_MS:int = 14000;
		internal var demoCtl:AttractDemo;
		internal var videoCtl:AttractVideo;


		public function AttractMode(logFn:Function, pickIntroFn:Function = null, abortIntroFn:Function = null)
		{
			super();
			demoCtl = new AttractDemo(this);
			videoCtl = new AttractVideo(this);
			m_log = logFn;
			m_pickIntro = pickIntroFn;
			m_abortIntro = abortIntroFn;
			m_host = null;
			m_enabled = true;
			m_onTitle = false;
			m_idle = 0;
			m_step = 0;
			m_busy = false;
			m_kind = "";
			m_demoFrames = 0;
			m_demoPhase = -1;
			m_focusOrder = [];
			m_hudHidden = false;
			m_logoLayer = null;
			m_howto = null;
			m_armedRoot = false;
			m_mediaSuspended = false;
			m_skipArmed = false;
			m_holdUntilTitleReentry = false;
			m_titleMenuRef = null;
			m_playlistHold = false;
			m_nextStepTimer = 0;
			m_demoLoadedIds = [];
		}

		public function setEnabled(v:Boolean):void
		{
			m_enabled = v;
			if (!v)
			{
				stopAll(false);
			};
		}

		public function isBusy():Boolean
		{
			return m_busy;
		}

		/** Boot-intro skip. Clears a busy attract intro and shows the title. */
		public function requestSkipToTitle():void
		{
			if (m_busy && (m_kind == "intro" || m_kind == "howto" || m_kind == "demo"))
			{
				cancelAttractToTitle();
				return;
			};
			showTitle();
		}

		/**
		 * Hard-stop attract after an uncaught error. Clears attract state only —
		 * match teardown is owned by Ssf2StreamMod.softTeardownSession (same as
		 * Configure → Apply). Does not return to Title.
		 */
		public function abortForRecovery():void
		{
			m_skipArmed = false;
			try
			{
				if (m_kind == "intro")
				{
					abortIntroPlayback();
				};
			}
			catch (introErr:*)
			{
			};
			try
			{
				videoCtl.stopVideo();
				videoCtl.stopIntroWatch();
				stopAttractMusic();
				videoCtl.hideLogo();
				demoCtl.hideFade();
				setAttractMedia(false);
			}
			catch (uiErr:*)
			{
			};
			m_busy = false;
			m_kind = "";
			m_demoFrames = 0;
			m_demoPhase = -1;
			m_hudHidden = false;
			m_idle = 0;
			m_onTitle = false;
			resetPlaylistStep("crash-recovery");
			m_holdUntilTitleReentry = false;
			m_playlistHold = false;
			clearNextStepTimer();
			log("attract aborted for crash recovery");
		}

		public function attach(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			};
			try
			{
				host.addHook("MENU_SHOW", onMenuShow);
				host.addHook("MENU_HIDE", onMenuHide);
				host.addHook("MATCH_RESULTS", onMatchResults);
				host.addHook("MODE_END", onModeEnd);
				host.addHook("KEY_EVENT", onKeyEvent);
			}
			catch (err:*)
			{
				log("hook fail: " + err);
			};
			armRootInput();
		}

		public function detach():void
		{
			stopAll(false);
			disarmRootInput();
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("MENU_SHOW", onMenuShow);
					m_host["removeHook"]("MENU_HIDE", onMenuHide);
					m_host["removeHook"]("MATCH_RESULTS", onMatchResults);
					m_host["removeHook"]("MODE_END", onModeEnd);
					m_host["removeHook"]("KEY_EVENT", onKeyEvent);
				}
				catch (err:*)
				{
				};
			};
			m_host = null;
		}

		public function holdForDeepLink():void
		{
			m_deepLinkHold = true;
			m_sawJukeboxOverlay = false;
			m_idle = 0;
			m_holdUntilTitleReentry = true;
		}

		public function onFrame():void
		{
			var titleUp:Boolean;
			if (!m_enabled)
			{
				return;
			};
			if (m_deepLinkHold)
			{
				if (isJukeboxOpen())
				{
					m_sawJukeboxOverlay = true;
				}
				else if (m_sawJukeboxOverlay)
				{
					m_deepLinkHold = false;
					m_sawJukeboxOverlay = false;
					m_holdUntilTitleReentry = false;
					m_idle = 0;
				};
				return;
			};
			if (isJukeboxOpen())
			{
				if (m_busy || m_playlistHold || m_nextStepTimer != 0)
				{
					suspendAttract("jukebox", true);
				}
				else if (!m_holdUntilTitleReentry)
				{
					m_holdUntilTitleReentry = true;
					m_idle = 0;
					log("title + jukebox — attract held until re-enter");
				};
				return;
			};
			if (m_busy && m_kind == "demo")
			{
				demoCtl.tickDemoCamera();
				pollControllerSkip();
				return;
			};
			if (m_busy)
			{
				pollControllerSkip();
				return;
			};
			titleUp = isTitleOnscreen();
			if (!titleUp)
			{
				if (m_onTitle || m_playlistHold || m_nextStepTimer != 0)
				{
					suspendAttract("left-title", false);
				};
				return;
			};
			if (m_holdUntilTitleReentry)
			{
				m_idle = 0;
				if (!m_onTitle)
				{
					m_onTitle = true;
					armRootInput();
				};
				return;
			};
			if (!m_onTitle)
			{
				m_onTitle = true;
				m_idle = 0;
				armRootInput();
				log("title detected — idle countdown armed");
			};
			m_idle++;
			if (m_playlistHold)
			{
				// finishSegment owns the next step timer — don't double-fire from idle.
				return;
			};
			if (m_idle >= IDLE_FRAMES)
			{
				m_idle = 0;
				runNextStep();
			};
		}

		/** Match Menu.manageMenuMappings: BUTTON1/2/START skip when no menu mapper is live. */
		private function pollControllerSkip():void
		{
			if (!m_busy)
			{
				return;
			};
			if (m_kind != "howto" && m_kind != "intro" && m_kind != "demo")
			{
				return;
			};
			if (anyControllerSkipDown())
			{
				trySkipAttract();
			};
		}

		/** BUTTON1, BUTTON2 or START held on any SaveData.Controllers entry. Also polled by the boot intro. */
		public static function anyControllerSkipDown():Boolean
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			try
			{
				SD = EngineRefs.SaveData as Class;
				list = SD ? SD["Controllers"] : null;
				if (!list)
				{
					return (false);
				};
				i = 0;
				while (i < list.length)
				{
					c = list[i];
					i++;
					if (!c || !(c["IsDown"] is Function))
					{
						continue;
					};
					if (Boolean(c["IsDown"](c["_BUTTON1"]))
						|| Boolean(c["IsDown"](c["_BUTTON2"]))
						|| Boolean(c["IsDown"](c["_START"])))
					{
						return (true);
					};
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function isTitleOnscreen():Boolean
		{
			var menu:*;
			menu = m_titleMenuRef;
			if (menu)
			{
				try
				{
					if (menu["isOnscreen"] is Function)
					{
						return Boolean(menu["isOnscreen"]());
					};
				}
				catch (err:*)
				{
				};
			};
			// Do NOT touch MenuController.titleMenu — that getter fires Discord RP.
			return (false);
		}

		private function isJukeboxOpen():Boolean
		{
			try
			{
				if (m_host && m_host.getSessionFlag is Function)
				{
					return Boolean(m_host.getSessionFlag("music_player.overlay"));
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var name:String;
			var reentry:Boolean;
			if (!m_enabled || !ctx)
			{
				return;
			};
			menu = ctx["menu"];
			name = safeName(menu);
			if (name.indexOf("TitleMenu") >= 0)
			{
				m_titleMenuRef = menu;
				reentry = !m_onTitle;
				m_onTitle = true;
				m_idle = 0;
				armRootInput();
				if (reentry)
				{
					m_holdUntilTitleReentry = false;
					log("title show — attract hold cleared, idle armed");
				}
				else
				{
					log("title show — idle countdown reset");
				};
				if (m_busy && (m_kind == "intro" || m_kind == "howto") && !m_playlistHold)
				{
					// Returned from intro/video to title — advance playlist.
					finishSegment();
				};
				return;
			};
			if (name.indexOf("Disclaimer") >= 0 || name.indexOf("Intro") >= 0)
			{
				return;
			};
			// Mute / volume overlays sit on title — do not treat as leaving.
			if (name.indexOf("MuteMenu") >= 0)
			{
				return;
			};
			// Left title for a real menu (Start / navigate away) — always stop
			// scheduled playlist steps, even during the inter-segment gap.
			suspendAttract("menu:" + name, false);
			if (name.indexOf("MainMenu") >= 0 || name.indexOf("GroupMenu") >= 0)
			{
				resetPlaylistStep("menu:" + name);
			};
		}

		private function onMenuHide(ctx:Object):void
		{
			var menu:*;
			var name:String;
			if (!ctx)
			{
				return;
			};
			menu = ctx["menu"];
			name = safeName(menu);
			// Title hide during attract teardown must NOT reset the playlist.
			if (name.indexOf("TitleMenu") >= 0 && !m_busy && !m_playlistHold)
			{
				m_onTitle = false;
				m_idle = 0;
				clearNextStepTimer();
			};
		}

		/**
		 * Stop attract immediately: cancel gap timer, tear down demo/intro/howto,
		 * and optionally hold until leave+re-enter title (jukebox).
		 */
		private function suspendAttract(reason:String, holdReentry:Boolean):void
		{
			var wasBusy:Boolean;
			var wasHold:Boolean;
			wasBusy = m_busy;
			wasHold = m_playlistHold || m_nextStepTimer != 0;
			if (!wasBusy && !wasHold && !m_onTitle && !holdReentry)
			{
				m_onTitle = false;
				m_idle = 0;
				return;
			};
			clearNextStepTimer();
			m_playlistHold = false;
			m_idle = 0;
			m_skipArmed = false;
			if (holdReentry)
			{
				m_holdUntilTitleReentry = true;
			};
			if (wasBusy)
			{
				if (m_kind == "demo")
				{
					demoCtl.endLiveDemo(false, !holdReentry ? false : true);
				};
				hardStopAttractMedia();
				demoCtl.unloadDemoResources();
				setAttractMedia(false);
				m_busy = false;
				m_kind = "";
				m_demoFrames = 0;
				m_demoPhase = -1;
				m_hudHidden = false;
				if (holdReentry || isTitleOnscreen())
				{
					showTitle();
				};
			};
			m_onTitle = isTitleOnscreen();
			if (wasBusy || wasHold)
			{
				log("attract suspended (" + reason + ")"
					+ (holdReentry ? " hold-until-reenter" : ""));
				ResourceMem.snap("attract:suspend", reason);
			};
		}

		private function resetPlaylistStep(reason:String):void
		{
			if (m_step != 0)
			{
				log("playlist reset step " + m_step + "→0 (" + reason + ")");
			};
			m_step = 0;
		}

		private function onKeyEvent(ctx:Object):void
		{
			var e:*;
			var code:uint;
			if (!m_enabled || !ctx)
			{
				return;
			};
			e = ctx["event"] || ctx["e"] || ctx["keyboardEvent"];
			try
			{
				code = e ? uint(e["keyCode"]) : 0;
			}
			catch (err:*)
			{
				code = 0;
			};
			if (code == Keyboard.F2 && m_onTitle && !m_busy)
			{
				ctx.cancel = true;
				m_idle = 0;
				resetPlaylistStep("F2");
				startLiveDemo();
				return;
			};
			if (m_busy && trySkipAttract(ctx))
			{
				return;
			};
			if (m_onTitle)
			{
				m_idle = 0;
			};
		}

		private function onMatchResults(ctx:Object):void
		{
			if (!m_busy || m_kind != "demo")
			{
				return;
			};
			log("demo MATCH_RESULTS — divert to title");
			setTimeout(function ():void
			{
				demoCtl.abortMatchToTitle();
				finishSegment();
			}, 1);
		}

		private function onModeEnd(ctx:Object):void
		{
			if (!m_busy || m_kind != "demo")
			{
				return;
			};
			setTimeout(function ():void
			{
				if (m_busy && m_kind == "demo")
				{
					demoCtl.abortMatchToTitle();
					finishSegment();
				};
			}, 50);
		}

		private function runNextStep():void
		{
			var kind:String;
			var guard:int;
			if (m_busy)
			{
				return;
			};
			if (!canRunAttractStep())
			{
				clearNextStepTimer();
				m_playlistHold = false;
				m_idle = 0;
				log("step blocked (title=" + isTitleOnscreen()
					+ " jukebox=" + isJukeboxOpen()
					+ " hold=" + m_holdUntilTitleReentry + ")");
				return;
			};
			clearNextStepTimer();
			m_playlistHold = false;
			// Never let intro FLV / howto video / leftover demo stack with the next step.
			hardStopAttractMedia();
			guard = 0;
			while (guard < STEPS.length)
			{
				kind = String(STEPS[m_step % STEPS.length]);
				m_step = (m_step + 1) % STEPS.length;
				guard++;
				if (kind == "howto" && !howToPlayExists())
				{
					log("step → howto (skip — flv missing)");
					continue;
				};
				log("step → " + kind + " (nextIdx=" + (m_step % STEPS.length) + ")");
				ResourceMem.snap("attract:step", "kind=" + kind);
				if (kind == "demo")
				{
					startLiveDemo();
				}
				else if (kind == "howto")
				{
					videoCtl.startHowToPlay();
				}
				else
				{
					videoCtl.startRandomIntro();
				};
				return;
			};
			log("attract playlist empty — idle");
		}

		/** Attract playlist only runs on title with jukebox closed. */
		private function canRunAttractStep():Boolean
		{
			if (!m_enabled || m_holdUntilTitleReentry || m_deepLinkHold)
			{
				return (false);
			};
			if (isJukeboxOpen())
			{
				return (false);
			};
			// Trust m_onTitle after finish/cancel — TitleMenu can lag one frame
			// behind isOnscreen() and the old check skipped the gap → stuck black.
			return Boolean(m_onTitle || isTitleOnscreen());
		}

		private function howToPlayExists():Boolean
		{
			var file:File;
			try
			{
				file = File.applicationDirectory.resolvePath("data/video/how_to_play.flv");
				return Boolean(file && file.exists);
			}
			catch (err:*)
			{
			};
			return (false);
		}

		/** Kill intro timeline, howto video, and BGM so segments never overlap. */
		internal function hardStopAttractMedia():void
		{
			// Only tear down intro when an intro was active — calling abort after
			// every demo used to disposeAllMenus and black-screen TitleMenu.
			if (m_kind == "intro")
			{
				abortIntroPlayback();
			};
			videoCtl.stopVideo();
			videoCtl.stopIntroWatch();
			stopAttractMusic();
			videoCtl.hideLogo();
			demoCtl.hideFade();
		}

		private function clearNextStepTimer():void
		{
			if (m_nextStepTimer != 0)
			{
				try
				{
					clearTimeout(m_nextStepTimer);
				}
				catch (err:*)
				{
				};
				m_nextStepTimer = 0;
			};
		}

		internal function finishSegment():void
		{
			// Arm hold BEFORE clearing busy so MENU_SHOW/HIDE cannot reset m_step.
			m_playlistHold = true;
			hardStopAttractMedia();
			demoCtl.unloadDemoResources();
			setAttractMedia(false);
			m_busy = false;
			m_kind = "";
			m_demoFrames = 0;
			m_demoPhase = -1;
			m_hudHidden = false;
			m_onTitle = true;
			m_idle = 0;
			if (!isTitleOnscreen())
			{
				showTitle();
			};
			ResourceMem.snap("attract:finish", "nextIdx=" + (m_step % STEPS.length));
			scheduleNextStep(SEGMENT_GAP_MS);
		}

		private function cancelAttractToTitle():void
		{
			// Keep m_step — runNextStep already advanced it when this segment
			// started, so the next gap continues the playlist (howto/demo/intro).
			log("attract cancel → title (next step " + (m_step % STEPS.length) + ")");
			m_skipArmed = false;
			// Same hold + gap as finish — cancel used to clear hold and the idle
			// path (or a nested finishSegment) jumped to the next step immediately.
			m_playlistHold = true;
			clearNextStepTimer();
			if (m_kind == "demo")
			{
				demoCtl.endLiveDemo(false);
			};
			hardStopAttractMedia();
			demoCtl.unloadDemoResources();
			setAttractMedia(false);
			m_busy = false;
			m_kind = "";
			m_demoFrames = 0;
			m_demoPhase = -1;
			m_hudHidden = false;
			m_idle = 0;
			showTitle();
			m_onTitle = true;
			ResourceMem.snap("attract:cancel");
			scheduleNextStep(SEGMENT_GAP_MS);
		}

		/** Title pause, then continue playlist — only if still on title / no jukebox. */
		private function scheduleNextStep(delayMs:int):void
		{
			clearNextStepTimer();
			if (!canRunAttractStep())
			{
				m_playlistHold = false;
				m_idle = 0;
				log("gap skipped — not on title or jukebox open");
				return;
			};
			m_playlistHold = true;
			m_nextStepTimer = setTimeout(function ():void
			{
				m_nextStepTimer = 0;
				if (m_enabled && !m_busy && canRunAttractStep())
				{
					m_onTitle = true;
					runNextStep();
				}
				else
				{
					m_playlistHold = false;
					m_idle = 0;
					log("gap expired — step aborted (left title or jukebox)");
				};
			}, delayMs);
		}

		/**
		 * Intro FLVs / beta timeline (ssf2intro_beta) leave audio playing after
		 * visual skip. SoundQueue only tracks its own channels — timeline sounds
		 * need SoundMixer.stopAll().
		 */
		private function stopAttractMusic():void
		{
			var SQ:*;
			try
			{
				SQ = EngineRefs.SoundQueue;
				if (SQ && SQ.instance)
				{
					if (SQ.instance.stopMusic is Function)
					{
						SQ.instance.stopMusic();
					};
					if (SQ.instance.stopAllSounds is Function)
					{
						SQ.instance.stopAllSounds();
					};
				};
			}
			catch (err:*)
			{
				log("stopAttractMusic SQ: " + err);
			};
			try
			{
				SoundMixer.stopAll();
			}
			catch (mixErr:*)
			{
				log("stopAttractMusic mixer: " + mixErr);
			};
		}

		/** Returns true if the attract segment was skipped. */
		internal function trySkipAttract(ctx:Object = null):Boolean
		{
			if (!m_busy)
			{
				return (false);
			};
			if (m_kind == "howto" || m_kind == "intro")
			{
				if (!m_skipArmed)
				{
					return (true);
				};
				if (ctx)
				{
					ctx.cancel = true;
				};
				cancelAttractToTitle();
				return (true);
			};
			if (m_kind == "demo")
			{
				if (ctx)
				{
					ctx.cancel = true;
				};
				cancelAttractToTitle();
				return (true);
			};
			return (false);
		}

		internal function armSkipSoon():void
		{
			m_skipArmed = false;
			setTimeout(function ():void
			{
				if (m_busy && (m_kind == "howto" || m_kind == "intro"))
				{
					m_skipArmed = true;
				};
			}, 450);
		}

		private function abortIntroPlayback():void
		{
			try
			{
				if (m_abortIntro != null)
				{
					m_abortIntro();
				};
			}
			catch (err:*)
			{
				log("abort intro: " + err);
			};
			// Do NOT disposeAllMenus — that wipes TitleMenu after demo finish
			// and leaves a black screen. Intro tear-down is owned by
			// stopActiveIntroPlayback (intro menus only).
		}

		private function startLiveDemo():void
		{
			var GameCls:Class;
			var ModeCls:Class;
			var GC:Class;
			var RM:Class;
			var MainCls:Class;
			var UtilsCls:Class;
			var StageSetting:Class;
			var Stats:Class;
			var MC:Class;
			var game:*;
			var stageId:String;
			var playerSettings:*;
			var chars:Array;
			var loadingMask:MovieClip;

			if (m_busy)
			{
				return;
			};
			try
			{
				// Game is under controllers — engine.Game throws #1065.
				GameCls = requireClass("com.mcleodgaming.ssf2.controllers.Game");
				ModeCls = requireClass("com.mcleodgaming.ssf2.enums.Mode");
				GC = requireClass("com.mcleodgaming.ssf2.controllers.GameController");
				RM = requireClass("com.mcleodgaming.ssf2.util.ResourceManager");
				MainCls = requireClass("com.mcleodgaming.ssf2.Main");
				UtilsCls = requireClass("com.mcleodgaming.ssf2.util.Utils");
				StageSetting = requireClass("com.mcleodgaming.ssf2.engine.StageSetting");
				Stats = requireClass("com.mcleodgaming.ssf2.engine.Stats");
				MC = requireClass("com.mcleodgaming.ssf2.controllers.MenuController");
			}
			catch (err:*)
			{
				log("demo class fail: " + describeErr(err));
				finishSegment();
				return;
			};
			if (!GameCls || !ModeCls || !GC || !RM || Boolean(GC["isStarted"]))
			{
				log("demo blocked (in match? isStarted=" + (GC ? GC["isStarted"] : "?") + ")");
				return;
			};
			hardStopAttractMedia();
			abortIntroPlayback();
			stopAttractMusic();
			setAttractMedia(true);
			m_busy = true;
			resetDemoSegment();
			ResourceMem.snap("attract:demo:start");
			try
			{
				stageId = demoCtl.pickDemoStage(StageSetting, RM);
				chars = demoCtl.pickDemoChars(Stats, 4, RM);
				game = new GameCls(4, ModeCls["VS"]);
				demoCtl.setupDemoLevel(game, stageId, UtilsCls);
				playerSettings = game["PlayerSettings"];
				demoCtl.assignDemoPlayers(playerSettings, chars);
				MainCls["prepRandomCharacters"](playerSettings["length"]);
				GC["isStarted"] = true;
				demoCtl.queueDemoResources(RM, playerSettings, stageId);
				loadingMask = demoCtl.showDemoLoadingMask(RM, MainCls);
				RM["load"]({"oncomplete": demoLoadComplete(loadingMask, MC, GC, RM, game, stageId, chars)});
			}
			catch (setupErr:*)
			{
				try
				{
					GC["isStarted"] = false;
				}
				catch (e2:*)
				{
				};
				m_busy = false;
				m_kind = "";
				setAttractMedia(false);
				log("demo setup fail: " + describeErr(setupErr));
				finishSegment();
			};
		}

		/** Fresh demo segment state: frame and phase counters, HUD flag, loaded ids, shuffled focus order. */
		private function resetDemoSegment():void
		{
			m_kind = "demo";
			m_demoFrames = 0;
			m_demoPhase = -1;
			m_hudHidden = false;
			m_onTitle = false;
			m_playlistHold = false;
			m_demoLoadedIds = [];
			m_focusOrder = [1, 2, 3, 4];
			demoCtl.shuffleInts(m_focusOrder);
		}

		/** RM.load oncomplete for the demo: start the match with logo, hidden HUD and wide camera; title on failure. */
		private function demoLoadComplete(loadingMask:MovieClip, MC:Class, GC:Class, RM:Class, game:*,
			stageId:String, chars:Array):Function
		{
			return function (e:* = null):void
			{
				try
				{
					if (loadingMask && loadingMask.parent)
					{
						loadingMask.parent.removeChild(loadingMask);
					};
					if (MC)
					{
						MC["disposeAllMenus"]();
					};
					GC["startMatch"](game);
					videoCtl.showLogo();
					demoCtl.hideMatchHud();
					demoCtl.camMaxZoomOut();
					demoCtl.rememberStageMusicIds(RM, stageId);
					log("live demo 4P stage=" + stageId + " chars=" + chars.join(",")
						+ " focus=" + m_focusOrder.join(","));
				}
				catch (doneErr:*)
				{
					GC["isStarted"] = false;
					m_busy = false;
					m_kind = "";
					videoCtl.hideLogo();
					setAttractMedia(false);
					log("demo start fail: " + describeErr(doneErr));
					showTitle();
				};
			};
		}

		private function requireClass(path:String):Class
		{
			var c:Class = EngineRefs.cls(path) as Class;
			if (!c)
			{
				throw new Error("Missing class " + path);
			};
			return c;
		}

		internal function describeErr(err:*):String
		{
			var msg:String;
			var id:int;
			var extra:String;
			var m:Array;
			if (err == null)
			{
				return "";
			};
			msg = String(err);
			id = 0;
			try
			{
				if (err is Error)
				{
					id = int((err as Error).errorID);
					msg = (err as Error).message || msg;
				};
			}
			catch (e1:*)
			{
			};
			if (id <= 0)
			{
				m = msg.match(/Error\s*#(\d+)/i);
				if (m && m.length > 1)
				{
					id = int(m[1]);
				};
			};
			extra = "";
			if (id == 1065)
			{
				extra = " — #1065 Variable not defined (wrong getDefinitionByName path or class not loaded)";
			}
			else if (id == 1009)
			{
				extra = " — #1009 Null object reference";
			}
			else if (id == 1069)
			{
				extra = " — #1069 Property not found on sealed object";
			}
			else if (id > 0)
			{
				extra = " — Flash/AS3 error #" + id;
			};
			return msg + extra;
		}

		internal function setAttractMedia(active:Boolean):void
		{
			var MH:Class;
			if (active == m_mediaSuspended)
			{
				return;
			};
			m_mediaSuspended = active;
			try
			{
				MH = EngineRefs.ModHost as Class;
				if (MH && MH["runHook"] is Function)
				{
					MH["runHook"]("ATTRACT_MEDIA", {"active": active});
				};
			}
			catch (err:*)
			{
				log("ATTRACT_MEDIA: " + describeErr(err));
			};
			if (m_host)
			{
				try
				{
					m_host.setSessionFlag("attractActive", active ? true : null);
					// Clear jukebox BGM hold so demo uses stage music, not settings override.
					if (active)
					{
						m_host.setSessionFlag("music_player.bgm_hold", null);
						m_host.setSessionFlag("match_music.claim_id", null);
						m_host.setSessionFlag("match_music.claim_at", null);
					};
				}
				catch (e2:*)
				{
				};
			};
			ResourceMem.snap(active ? "attract:media:on" : "attract:media:off");
		}

		internal function showTitle():void
		{
			var MC:Class;
			try
			{
				MC = EngineRefs.MenuController as Class;
				if (MC && MC["titleMenu"] && MC["titleMenu"]["show"])
				{
					MC["titleMenu"]["show"]();
				};
			}
			catch (err:*)
			{
				log("showTitle: " + err);
			};
		}

		private function stopAll(advanceIdle:Boolean):void
		{
			if (m_busy && m_kind == "demo")
			{
				try
				{
					demoCtl.endLiveDemo(false);
				}
				catch (err:*)
				{
				};
			};
			videoCtl.stopVideo();
			videoCtl.stopIntroWatch();
			videoCtl.hideLogo();
			m_busy = false;
			m_kind = "";
			m_demoFrames = 0;
			m_idle = 0;
			m_onTitle = false;
		}

		private function armRootInput():void
		{
			var MainCls:Class;
			var root:*;
			if (m_armedRoot)
			{
				return;
			};
			try
			{
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? MainCls["Root"] : null;
				if (!root)
				{
					return;
				};
				root.addEventListener(Event.ENTER_FRAME, onRootFrame, false, 0, true);
				root.stage.addEventListener(KeyboardEvent.KEY_DOWN, onRootKey, false, 0, true);
				root.stage.addEventListener(MouseEvent.MOUSE_DOWN, onRootMouse, false, 0, true);
				m_armedRoot = true;
			}
			catch (err:*)
			{
			};
		}

		private function disarmRootInput():void
		{
			var MainCls:Class;
			var root:*;
			if (!m_armedRoot)
			{
				return;
			};
			try
			{
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? MainCls["Root"] : null;
				if (root)
				{
					root.removeEventListener(Event.ENTER_FRAME, onRootFrame);
					if (root.stage)
					{
						root.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onRootKey);
						root.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onRootMouse);
					};
				};
			}
			catch (err:*)
			{
			};
			m_armedRoot = false;
		}

		private function onRootFrame(e:Event):void
		{
			onFrame();
		}

		private function onRootKey(e:KeyboardEvent):void
		{
			if (!m_enabled)
			{
				return;
			};
			if (e && e.keyCode == Keyboard.F2 && m_onTitle && !m_busy)
			{
				m_idle = 0;
				resetPlaylistStep("F2");
				startLiveDemo();
				return;
			};
			if (m_busy && trySkipAttract())
			{
				return;
			};
			if (m_onTitle)
			{
				m_idle = 0;
			};
		}

		private function onRootMouse(e:MouseEvent):void
		{
			if (!m_enabled)
			{
				return;
			};
			if (m_busy && trySkipAttract())
			{
				return;
			};
			if (m_onTitle)
			{
				m_idle = 0;
			};
		}

		private function safeName(menu:*):String
		{
			try
			{
				return getQualifiedClassName(menu);
			}
			catch (err:*)
			{
			};
			return "?";
		}

		internal function log(msg:String):void
		{
			if (m_log != null)
			{
				try
				{
					m_log("[attract] " + msg);
				}
				catch (err:*)
				{
				};
			};
		}
	}
}
