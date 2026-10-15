package
{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.UncaughtErrorEvent;
	import flash.desktop.NativeApplication;
	import flash.utils.getTimer;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/**
	 * Uncaught error response: storm detection, crash replay, recovery or quit,
	 * alert.json and last_error.txt.
	 */
	internal class StreamCrash
	{
		private var core:Ssf2StreamMod;
		/** Dedup identical UNCAUGHT logs within a short window (still always dismiss). */
		private var m_uncaughtDedupMsg:String;
		private var m_uncaughtDedupMs:int;
		/** Live-match uncaught errors tolerated before soft teardown to title. */
		private static const UNCAUGHT_MATCH_TOLERATE:int = 5;
		/** Crash storm: one recover attempt, then quit if errors keep firing. */
		private var m_uncaughtStormStartMs:int;
		private var m_uncaughtStormCount:int;
		private var m_uncaughtRecoverAttempted:Boolean;
		private var m_uncaughtExiting:Boolean;
		private var m_uncaughtSameMs:int;
		private var m_crashNotifyHead:String;
		private var m_crashNotifyId:String;
		private var m_crashNotifyMeaning:String;
		private var m_crashNotifyLogPath:String;

		public function StreamCrash(owner:Ssf2StreamMod)
		{
			core = owner;
			m_uncaughtDedupMsg = "";
			m_uncaughtDedupMs = 0;
			m_uncaughtStormStartMs = 0;
			m_uncaughtStormCount = 0;
			m_uncaughtRecoverAttempted = false;
			m_uncaughtExiting = false;
			m_uncaughtSameMs = 0;
			m_crashNotifyHead = "";
			m_crashNotifyId = "";
			m_crashNotifyMeaning = "";
			m_crashNotifyLogPath = "";
		}

		internal function onUncaughtError(e:UncaughtErrorEvent):void
		{
			var err:*;
			var msg:String;
			var stack:String;
			var errorId:String;
			var head:String;
			var body:String;
			var now:int;
			var skipLog:Boolean;
			try
			{
				// Always dismiss — this is "auto Dismiss All". Do not stopImmediatePropagation
				// so other mods can still observe the event.
				try
				{
					e.preventDefault();
				}
				catch (pdErr:*)
				{
				};
				err = e ? e.error : null;
				msg = "";
				stack = "";
				errorId = "";
				if (err is Error)
				{
					msg = String((err as Error).message || err);
					try
					{
						errorId = String((err as Error).errorID);
					}
					catch (idErr:*)
					{
					};
					try
					{
						stack = String((err as Error).getStackTrace() || "");
					}
					catch (stErr:*)
					{
					};
					try
					{
						log("UNCAUGHT detail name=" + (err as Error).name
							+ " id=" + errorId
							+ " qn=" + getQualifiedClassName(err)
							+ " msg=" + msg);
					}
					catch (detErr:*)
					{
					};
				}
				else if (err is ErrorEvent)
				{
					msg = String((err as ErrorEvent).text || err);
					try
					{
						log("UNCAUGHT detail ErrorEvent text=" + msg + " qn=" + getQualifiedClassName(err));
					}
					catch (eeErr:*)
					{
					};
				}
				else
				{
					msg = String(err);
					try
					{
						log("UNCAUGHT detail typeof=" + typeof err + " qn=" + getQualifiedClassName(err) + " val=" + msg);
					}
					catch (otErr:*)
					{
					};
				};
				if (msg.length < 1)
				{
					msg = "(unknown error)";
				};
				if ((!errorId || errorId == "0") && msg.length > 0)
				{
					errorId = extractErrorIdFromMessage(msg);
				};
				head = msg.split("\n")[0];
				now = getTimer();
				// Capture+bubble arms fire the same handler twice per error.
				if (now == m_uncaughtSameMs || m_uncaughtExiting)
				{
					return;
				};
				m_uncaughtSameMs = now;
				skipLog = (head == m_uncaughtDedupMsg) && ((now - m_uncaughtDedupMs) < 2000);
				if (!skipLog)
				{
					m_uncaughtDedupMsg = head;
					m_uncaughtDedupMs = now;
					body = "UNCAUGHT " + head;
					if (errorId && errorId.length > 0 && errorId != "0")
					{
						body += " (errorID=" + errorId + ")";
						body += " — " + describeFlashError(errorId);
					};
					log(body);
					if (stack && stack.length > 0)
					{
						log("UNCAUGHT stack:\n" + stack);
					}
					else
					{
						log("UNCAUGHT stack: (unavailable without debugger)");
					};
					writeLastError(body, stack);
				};
				handleUncaughtStorm(head, errorId, stack);
			}
			catch (handlerErr:*)
			{
				try
				{
					e.preventDefault();
				}
				catch (pe:*)
				{
				};
				try
				{
					log("UNCAUGHT (handler failed) " + handlerErr);
				}
				catch (logErr:*)
				{
				};
			};
		}

		/**
		 * Crash policy:
		 *  1) First four uncaught while a live match is running → log only (stay in match)
		 *  2) Menu/replay/load errors, or #1069 sealed-property, or no UI left → recover now
		 *     (tolerate here = black screen after ReplaySelectMenu tears down)
		 *  3) Fifth uncaught in the same storm → soft teardown + Title + notify
		 *  4) If errors keep coming after recover → quit the game
		 */
		private function handleUncaughtStorm(head:String, errorId:String, stack:String):void
		{
			var now:int;
			var inLiveMatch:Boolean;
			var fatalNow:Boolean;
			now = getTimer();
			if (m_uncaughtStormStartMs < 1 || (now - m_uncaughtStormStartMs) > 8000)
			{
				m_uncaughtStormStartMs = now;
				m_uncaughtStormCount = 0;
				m_uncaughtRecoverAttempted = false;
			};
			m_uncaughtStormCount++;
			inLiveMatch = isLiveMatchContext();
			fatalNow = !inLiveMatch
				|| errorId == "1069"
				|| errorId == "1009" && !inLiveMatch
				|| looksLikeBlackScreenRisk();
			// One-off script errors in a live match should not eject to title.
			if (m_uncaughtStormCount < UNCAUGHT_MATCH_TOLERATE && !fatalNow)
			{
				m_crashNotifyHead = head || "";
				m_crashNotifyId = errorId || "";
				log("uncaught tolerate — stay in match (" + UNCAUGHT_MATCH_TOLERATE + "th error → title)");
				scheduleBlackScreenWatch();
				return;
			};
			if (fatalNow && m_uncaughtStormCount < 2)
			{
				log("uncaught fatal-now (match=" + inLiveMatch + " id=" + errorId + ") — recover");
			};
			// Capture replay while StageData is still alive (before killTicks/dispose).
			try
			{
				if (inLiveMatch)
				{
					saveCrashReplay();
				};
			}
			catch (repErr:*)
			{
				log("crash replay save: " + repErr);
			};
			try
			{
				killMatchTicksImmediate();
			}
			catch (killErr:*)
			{
			};
			if (!m_uncaughtRecoverAttempted)
			{
				m_uncaughtRecoverAttempted = true;
				m_crashNotifyHead = head || "";
				m_crashNotifyId = errorId || "";
				m_crashNotifyMeaning = describeFlashError(errorId);
				m_crashNotifyLogPath = resolveGameLogPath();
				try
				{
					writeCrashAlert(m_crashNotifyHead, m_crashNotifyId, stack, m_crashNotifyMeaning, m_crashNotifyLogPath);
				}
				catch (alertErr:*)
				{
				};
				setTimeout(runSimpleCrashRecovery, 50);
				return;
			};
			// Still throwing after recover attempt → bail out of the process.
			if (m_uncaughtStormCount >= 8)
			{
				quitAfterUncaughtStorm();
			};
		}

		/** True when StageData is live and a match has actually started. */
		private function isLiveMatchContext():Boolean
		{
			var GC:Class;
			var sd:*;
			try
			{
				GC = EngineRefs.GameController as Class;
				if (!GC)
				{
					return (false);
				};
				if (!GC["isStarted"])
				{
					return (false);
				};
				sd = GC["stageData"];
				if (!sd)
				{
					return (false);
				};
				return (true);
			}
			catch (err:*)
			{
			};
			return (false);
		}

		/**
		 * After ReplaySelectMenu.removeAllMenus + import crash, nothing is on screen.
		 * Treat empty menu stack + not in match as black-screen risk.
		 */
		private function looksLikeBlackScreenRisk():Boolean
		{
			var MC:Class;
			var root:*;
			var MainCls:Class;
			try
			{
				if (isLiveMatchContext())
				{
					return (false);
				};
				MC = EngineRefs.MenuController as Class;
				if (MC && MC["menu"] == null && MC["CurrentCharacterSelectMenu"] == null)
				{
					return (true);
				};
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? MainCls["Root"] : null;
				if (root && root.numChildren < 1)
				{
					return (true);
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function scheduleBlackScreenWatch():void
		{
			setTimeout(function ():void
			{
				if (m_uncaughtRecoverAttempted || m_uncaughtExiting)
				{
					return;
				};
				if (looksLikeBlackScreenRisk())
				{
					log("uncaught black-screen watch — recover");
					m_uncaughtStormCount = UNCAUGHT_MATCH_TOLERATE;
					handleUncaughtStorm(m_crashNotifyHead || "black-screen", m_crashNotifyId || "0", "");
				};
			}, 400);
		}

		/**
		 * Write a shareable .ssfrec under SSF2Replays/<version>/ before teardown.
		 * Stamps musicOverride + backgroundStage into MatchSettings for repro.
		 */
		private function saveCrashReplay():void
		{
			var GC:Class;
			var Utils:Class;
			var Version:Class;
			var sd:*;
			var rd:*;
			var replaysFolder:File;
			var versionFolder:File;
			var replayFile:File;
			var fileWriter:FileStream;
			var replayData:ByteArray;
			var baseName:String;
			var duplicateNum:int;
			var ModeFeatures:Class;
			var game:*;
			try
			{
				GC = EngineRefs.GameController as Class;
				sd = GC ? GC["stageData"] : null;
			}
			catch (gcErr:*)
			{
				sd = null;
			};
			if (!sd)
			{
				return;
			};
			try
			{
				if (sd["ReplayMode"])
				{
					return;
				};
			}
			catch (rmErr:*)
			{
			};
			try
			{
				ModeFeatures = EngineRefs.ssf2("enums.ModeFeatures") as Class;
				game = sd["GAME"] || sd["GameRef"];
				if (ModeFeatures && game
					&& !(ModeFeatures["hasFeature"](ModeFeatures["ALLOW_REPLAY_RECORD"], game["GameMode"])))
				{
					return;
				};
			}
			catch (mfErr:*)
			{
			};
			rd = null;
			try
			{
				rd = sd["ReplayDataObj"];
			}
			catch (rdErr:*)
			{
			};
			if (!rd || !(rd["exportReplay"] is Function))
			{
				return;
			};
			stampReplayMatchExtras(sd, rd);
			try
			{
				Utils = EngineRefs.Utils as Class;
				Version = EngineRefs.ssf2("Version") as Class;
			}
			catch (clsErr:*)
			{
				return;
			};
			try
			{
				baseName = "CRASH";
				if (Utils && Utils["generateReplaySaveFileName"] is Function)
				{
					baseName = "CRASH-" + String(Utils["generateReplaySaveFileName"](sd) || "replay");
				};
				rd["Name"] = baseName;
				replayData = new ByteArray();
				replayData.writeUTF(String(rd["exportReplay"]()));
				replayData.compress();
				replaysFolder = File.userDirectory.resolvePath("SSF2Replays");
				if (!replaysFolder.exists)
				{
					replaysFolder.createDirectory();
				};
				versionFolder = replaysFolder.resolvePath(
					Version && Version["getVersion"] is Function
						? String(Version["getVersion"]())
						: "unknown");
				if (!versionFolder.exists)
				{
					versionFolder.createDirectory();
				};
				duplicateNum = 1;
				replayFile = versionFolder.resolvePath(baseName + ".ssfrec");
				while (replayFile.exists)
				{
					duplicateNum++;
					replayFile = versionFolder.resolvePath(baseName + " (" + duplicateNum + ").ssfrec");
				};
				fileWriter = new FileStream();
				fileWriter.open(replayFile, FileMode.WRITE);
				fileWriter.writeBytes(replayData);
				fileWriter.close();
				log("crash replay saved " + replayFile.nativePath);
				m_crashNotifyMeaning = (m_crashNotifyMeaning || "")
					+ (m_crashNotifyMeaning ? " " : "")
					+ "Replay: " + replayFile.name;
			}
			catch (writeErr:*)
			{
				log("crash replay write: " + writeErr);
			};
		}

		/** Persist jukebox music + camera BG into MatchSettings JSON for replay share. */
		private function stampReplayMatchExtras(sd:*, rd:*):void
		{
			var ms:Object;
			var game:*;
			var bg:*;
			var musicId:String;
			if (!rd)
			{
				return;
			};
			ms = rd["MatchSettings"] as Object;
			if (!ms)
			{
				ms = {};
				rd["MatchSettings"] = ms;
			};
			try
			{
				game = sd ? (sd["GAME"] || sd["GameRef"]) : null;
				if (game && game["LevelData"] && game["LevelData"]["musicOverride"])
				{
					musicId = String(game["LevelData"]["musicOverride"]);
					if (musicId && musicId != "null")
					{
						ms["musicOverride"] = musicId;
					};
				};
			}
			catch (musErr:*)
			{
			};
			try
			{
				if (core.m_host && core.m_host.getSessionFlag is Function)
				{
					bg = core.m_host.getSessionFlag("backgroundStage", null);
					if (bg && String(bg).length > 0)
					{
						ms["backgroundStage"] = String(bg);
					};
				};
			}
			catch (bgErr:*)
			{
			};
		}

		private function runSimpleCrashRecovery():void
		{
			try
			{
				log("crash recover — soft teardown → title");
				try
				{
					if (core.m_attract)
					{
						core.m_attract.abortForRecovery();
						core.m_attract.setEnabled(false);
					};
				}
				catch (attErr:*)
				{
				};
				try
				{
					core.introCtl.stopActiveIntroPlayback();
				}
				catch (introErr:*)
				{
				};
				try
				{
					core.cmdCtl.softTeardownSession();
				}
				catch (tearErr:*)
				{
					log("crash recover teardown: " + tearErr);
				};
				core.m_screen = "home";
				core.m_match = null;
				core.m_phase = "done";
				core.deepLinkCtl.stopTick();
				if (!core.cssCtl.tryOpenMenuSoft("title"))
				{
					try
					{
						core.introCtl.showTitleAfterBootSkip();
					}
					catch (titleErr:*)
					{
					};
				};
				notifyCrashOnScreen();
			}
			catch (recErr:*)
			{
				log("crash recover failed: " + recErr);
			};
		}

		private function quitAfterUncaughtStorm():void
		{
			var app:*;
			if (m_uncaughtExiting)
			{
				return;
			};
			m_uncaughtExiting = true;
			try
			{
				log("uncaught storm — quitting game (recovery failed)");
			}
			catch (logErr:*)
			{
			};
			try
			{
				writeCrashAlert(
					m_crashNotifyHead || "Uncaught error storm",
					m_crashNotifyId,
					"",
					(m_crashNotifyMeaning || "Repeated uncaught errors") + ". Game is quitting.",
					m_crashNotifyLogPath);
			}
			catch (alertErr:*)
			{
			};
			try
			{
				notifyCrashOnScreen();
			}
			catch (nErr:*)
			{
			};
			try
			{
				app = NativeApplication.nativeApplication;
				if (app && app.exit is Function)
				{
					app.exit();
					return;
				};
			}
			catch (exitErr:*)
			{
				log("exit failed: " + exitErr);
			};
		}

		/** In-game toast via MultiplayerManager.notify (engine). */
		private function notifyCrashOnScreen():void
		{
			var parts:Array;
			var msg:String;
			var MM:*;
			var MH:Class;
			parts = [];
			if (m_crashNotifyId && m_crashNotifyId.length > 0 && m_crashNotifyId != "0")
			{
				parts.push("Error #" + m_crashNotifyId);
			}
			else if (m_crashNotifyHead && m_crashNotifyHead.length > 0)
			{
				parts.push(m_crashNotifyHead.split("\n")[0]);
			}
			else
			{
				parts.push("Uncaught error");
			};
			if (m_crashNotifyMeaning && m_crashNotifyMeaning.length > 0)
			{
				parts.push(m_crashNotifyMeaning);
			};
			if (m_crashNotifyLogPath && m_crashNotifyLogPath.length > 0)
			{
				parts.push("Check log for more details: " + m_crashNotifyLogPath);
			}
			else
			{
				parts.push("Check log for more details: data/ssf2mm/game.log");
			};
			msg = parts.join(" — ");
			try
			{
				MM = EngineRefs.MultiplayerManager;
				if (MM && MM["notify"] is Function)
				{
					MM["notify"](msg);
					log("crash notify ok");
					return;
				};
			}
			catch (netErr:*)
			{
			};
			try
			{
				MH = EngineRefs.ModHost as Class;
				if (MH && MH["notify"] is Function)
				{
					MH["notify"](msg);
					log("crash notify ok (ModHost)");
					return;
				};
			}
			catch (mhErr:*)
			{
			};
			log("crash notify failed — " + msg);
		}

		private function resolveGameLogPath():String
		{
			var logFile:File;
			try
			{
				logFile = core.resolveSsf2mmFile("game.log");
				if (logFile)
				{
					return logFile.nativePath;
				};
			}
			catch (err:*)
			{
			};
			return "data/ssf2mm/game.log";
		}

		/**
		 * Detach StageData RENDER/ENTER_FRAME before any dispose that can throw.
		 * Must run synchronously on first uncaught — delayed teardown leaves HudMenu
		 * spamming #1009 every frame via StageData.renderComplete → PERFORMALL.
		 */
		private function killMatchTicksImmediate():void
		{
			var GC:Class;
			var MainCls:Class;
			var sd:*;
			var hud:*;
			var st:*;
			var hadLive:Boolean;
			hadLive = false;
			try
			{
				GC = EngineRefs.GameController as Class;
			}
			catch (gcErr:*)
			{
				GC = null;
			};
			sd = null;
			hud = null;
			if (GC)
			{
				try
				{
					sd = GC["stageData"];
				}
				catch (sdErr:*)
				{
					sd = null;
				};
				try
				{
					hud = GC["hud"];
				}
				catch (hudGetErr:*)
				{
					hud = null;
				};
			};
			if (sd)
			{
				hadLive = true;
				try
				{
					sd["Paused"] = true;
					sd["GameEnded"] = true;
				}
				catch (flagErr:*)
				{
				};
				try
				{
					if (sd["killTicks"] is Function)
					{
						sd["killTicks"]();
					}
					else if (sd["dispose"] is Function)
					{
						try
						{
							sd["dispose"]();
						}
						catch (dispErr:*)
						{
						};
					};
				}
				catch (killErr:*)
				{
					log("killTicks: " + killErr);
				};
			};
			// HudMenu keeps an ENTER_FRAME on stage (manageMenuMappings) that NPEs
			// after stageData is torn down — always killEvents/removeSelf.
			if (hud)
			{
				hadLive = true;
				try
				{
					if (hud["killEvents"] is Function)
					{
						hud["killEvents"]();
					};
				}
				catch (keErr:*)
				{
				};
				try
				{
					if (hud["removeSelf"] is Function)
					{
						hud["removeSelf"]();
					};
				}
				catch (rsErr:*)
				{
				};
			};
			if (GC)
			{
				try
				{
					GC["hud"] = null;
					GC["matchStarted"] = false;
					GC["isStarted"] = false;
				}
				catch (flag2Err:*)
				{
				};
			};
			try
			{
				MainCls = EngineRefs.Main as Class;
				st = MainCls && MainCls["Root"] ? MainCls["Root"].stage : null;
				if (st && hud && hud["manageMenuMappings"] is Function)
				{
					st.removeEventListener(Event.ENTER_FRAME, hud["manageMenuMappings"]);
				};
			}
			catch (stErr:*)
			{
			};
			if (hadLive)
			{
				log("match ticks killed");
			};
		}

		/** Notify Mod Manager (polls data/ssf2mm/state/alert.json) to open the log. */
		private function writeCrashAlert(head:String, errorId:String, stack:String, meaning:String = "", logPath:String = ""):void
		{
			var file:File;
			var stream:FileStream;
			var stamp:String;
			var payload:Object;
			var text:String;
			try
			{
				if (!logPath || logPath.length < 1)
				{
					logPath = resolveGameLogPath();
				};
				stamp = new Date().getTime().toString();
				payload = {
					"type": "uncaught",
					"stamp": stamp,
					"errorId": errorId || "",
					"message": head || "",
					"meaning": meaning || "",
					"stack": stack || "",
					"logPath": logPath,
					"action": "open_log"
				};
				text = JSON.stringify(payload);
				file = core.bridgeFile("alert.json");
				JsonFile.writeText(file, text);
			}
			catch (err:*)
			{
				core.logStepError("writeCrashAlert", err);
			};
		}

		/** Pull Error #NNNN from a bare release-player message when errorID is missing. */
		private function extractErrorIdFromMessage(msg:String):String
		{
			var m:Array;
			try
			{
				m = msg.match(/Error\s*#(\d+)/i);
				if (m && m.length > 1)
				{
					return (String(m[1]));
				};
			}
			catch (err:*)
			{
			};
			return ("");
		}

		/**
		 * Human-readable Flash/AIR runtime error definitions (Adobe runtimeErrors).
		 * Release builds often only print "Error #1065" with no variable name.
		 */
		private function describeFlashError(errorId:String):String
		{
			var map:Object;
			var id:int;
			var title:String;
			var hint:String;
			if (!errorId || errorId.length < 1)
			{
				return ("(unknown error id)");
			};
			id = int(errorId);
			map = flashRuntimeErrorIndex();
			if (map[id] != null)
			{
				title = String(map[id]["t"] || "");
				hint = String(map[id]["h"] || "");
				if (hint.length > 0)
				{
					return (title + ". " + hint);
				};
				return (title);
			};
			if (id >= 1000 && id < 2000)
			{
				return ("AS3 runtime error #" + id + " (see Adobe runtimeErrors)");
			};
			if (id >= 2000 && id < 4000)
			{
				return ("Flash Player / AIR error #" + id + " (see Adobe runtimeErrors)");
			};
			return ("unlisted runtime error #" + id);
		}

		/** Compact index of the errors we hit most often in SSF2 + common AS3 failures. */
		private function flashRuntimeErrorIndex():Object
		{
			return ({
				1000: {t:"Out of memory", h:"Player ran out of RAM"},
				1006: {t:"Value is not a function", h:"Called something that is not callable (wrong object or missing method)"},
				1007: {t:"Instantiation on a non-constructor", h:"new used on a non-class"},
				1009: {t:"Null object reference", h:"Accessed a property/method on null"},
				1010: {t:"Undefined has no properties", h:"Accessed a property on undefined (often a misspelled timeline name)"},
				1014: {t:"Class could not be found", h:"getDefinitionByName / missing linkage or unloaded SWF"},
				1034: {t:"Type coercion failed", h:"Value could not be converted to the expected type"},
				1046: {t:"Method referenced before definition", h:"ABC verify issue"},
				1056: {t:"Cannot create property", h:"Wrote a dynamic property on a sealed/non-dynamic object"},
				1061: {t:"Precision loss on conversion", h:"Number assigned to int/uint out of range"},
				1063: {t:"Argument count mismatch", h:"Wrong number of arguments to a function"},
				1065: {t:"Variable is not defined", h:"Undefined identifier or missing MovieClip instance name (common on timeline children)"},
				1069: {t:"Property not found", h:"Property missing on sealed class and no default"},
				1070: {t:"Method not found", h:"Method missing on that type"},
				1074: {t:"Illegal write to read-only property", h:""},
				1078: {t:"Illegal opcode/multiname", h:"Corrupt or mismatched ABC"},
				1115: {t:"Not a constructor", h:"Tried to new a non-constructor"},
				1502: {t:"Script timeout", h:"Code ran longer than ~15 seconds"},
				1507: {t:"Argument may not be null", h:""},
				1508: {t:"Invalid argument value", h:""},
				2004: {t:"Invalid parameter", h:""},
				2006: {t:"Range error", h:"Index out of bounds"},
				2007: {t:"Parameter must be non-null", h:""},
				2015: {t:"Invalid BitmapData", h:""},
				2024: {t:"Cannot add child of itself", h:""},
				2025: {t:"DisplayObject is not a child of the caller", h:"removeChild/addChild on the wrong parent"},
				2028: {t:"Local SWF cannot access Internet URL", h:"Sandbox"},
				2030: {t:"End of file", h:""},
				2032: {t:"Stream error", h:""},
				2035: {t:"URL not found", h:""},
				2036: {t:"Load never completed", h:""},
				2037: {t:"Functions called in incorrect sequence", h:""},
				2038: {t:"File I/O error", h:""},
				2044: {t:"Unhandled error event", h:"An ErrorEvent was not handled"},
				2048: {t:"Security sandbox violation (load)", h:""},
				2071: {t:"Stage property/method not available", h:""},
				2094: {t:"Event dispatch recursion overflow", h:""},
				2099: {t:"Loader not sufficiently loaded", h:""},
				2131: {t:"Definition cannot be found", h:"ApplicationDomain missing a class"},
				2136: {t:"SWF contains invalid data", h:""},
				3600: {t:"No active security context", h:"AIR/security"},
				3708: {t:"NetStream.Play.Failed / DRM", h:""},
				3709: {t:"NetStream buffer issue", h:""},
				3710: {t:"NetStream not ready", h:""},
				3807: {t:"Worker domain error", h:""}
			});
		}

		/** Overwrite data/ssf2mm/state/last_error.txt for Copy Last Uncaught Error. */
		private function writeLastError(head:String, stack:String):void
		{
			var file:File;
			var stream:FileStream;
			var text:String;
			var stamp:String;
			try
			{
				stamp = new Date().toString();
				text = stamp + "\n" + head + "\n";
				if (stack && stack.length > 0)
				{
					text += stack + "\n";
				}
				else
				{
					text += "(stack unavailable without debugger)\n";
				};
				file = core.bridgeFile("last_error.txt");
				JsonFile.writeText(file, text);
			}
			catch (err:*)
			{
				core.logStepError("writeLastError", err);
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
