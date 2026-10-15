package
{
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.utils.Timer;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/**
	 * cmd.json channel from the Mod Manager: watch, apply, soft teardown, ack.
	 */
	internal class StreamCmdChannel
	{
		private var core:Ssf2StreamMod;
		private var m_cmdTimer:Timer;
		private var m_lastCmdFingerprint:String;
		private var m_pausedByStream:Boolean;
		private var m_cmdFile:File;
		private var m_cmdFileKey:String;

		public function StreamCmdChannel(owner:Ssf2StreamMod)
		{
			core = owner;
			m_cmdTimer = null;
			m_lastCmdFingerprint = "";
			m_pausedByStream = false;
		}

		/** Drop leftover cmd.json from a prior session so it cannot hijack launch.json. */
		internal function clearStaleCmdOnBoot():void
		{
			var file:File;
			try
			{
				file = core.bridgeFile("cmd.json");
				if (file && file.exists)
				{
					log("clearing stale cmd.json on boot");
					clearCmdFile(file);
				};
			}
			catch (err:*)
			{
				core.logStepError("clearStaleCmdOnBoot", err);
			};
			m_lastCmdFingerprint = "";
			core.m_pendingApply = null;
		}

		internal function startCmdWatcher():void
		{
			if (m_cmdTimer)
			{
				return;
			};
			m_cmdTimer = new Timer(500);
			m_cmdTimer.addEventListener(TimerEvent.TIMER, onCmdTimer);
			m_cmdTimer.start();
			log("cmd watcher started (500ms)");
		}

		internal function stopCmdWatcher():void
		{
			if (!m_cmdTimer)
			{
				return;
			};
			try
			{
				m_cmdTimer.stop();
				m_cmdTimer.removeEventListener(TimerEvent.TIMER, onCmdTimer);
			}
			catch (err:*)
			{
				core.logStepError("stopCmdWatcher", err);
			};
			m_cmdTimer = null;
		}

		private function onCmdTimer(e:TimerEvent):void
		{
			var file:File;
			core.musicCtl.writeNowPlaying();
			try
			{
				if (!m_cmdFile || m_cmdFileKey != core.m_logFileAbs)
				{
					m_cmdFile = core.bridgeFile("cmd.json");
					m_cmdFileKey = core.m_logFileAbs;
				};
				file = m_cmdFile;
				if (file && file.exists)
				{
					handleCmdFile(file);
					return;
				};
			}
			catch (err:*)
			{
				core.logStepError("cmd poll", err, true);
			};
		}

		private function handleCmdFile(file:File):void
		{
			var data:Object;
			var op:String;
			data = takeCmd(file);
			if (!data)
			{
				return;
			};
			op = String(data["op"] || "").toLowerCase();
			if (op == "ack" || op == "nop")
			{
				return;
			};
			log("cmd op=" + op);
			try
			{
				dispatchCmd(op, data);
			}
			catch (opErr:*)
			{
				core.logStepError("cmd op=" + op, opErr);
			};
		}

		/**
		 * Reads cmd.json once and clears it. Null for unreadable, empty, repeated or bad JSON.
		 * The fingerprint is set before dispatch so a stuck file cannot re-fire.
		 */
		private function takeCmd(file:File):Object
		{
			var text:String;
			var data:Object;
			var fingerprint:String;
			text = JsonFile.readText(file);
			if (text == null)
			{
				log("cmd.json read error: " + (file ? file.nativePath : "null"));
				return (null);
			};
			fingerprint = String(text || "").replace(/^\s+|\s+$/g, "");
			if (fingerprint.length < 1)
			{
				clearCmdFile(file);
				return (null);
			};
			if (fingerprint == m_lastCmdFingerprint)
			{
				clearCmdFile(file);
				return (null);
			};
			try
			{
				data = JSON.parse(text) as Object;
			}
			catch (parseErr:*)
			{
				log("cmd.json parse error: " + parseErr);
				m_lastCmdFingerprint = fingerprint;
				clearCmdFile(file);
				return (null);
			};
			m_lastCmdFingerprint = fingerprint;
			clearCmdFile(file);
			return (data);
		}

		private function dispatchCmd(op:String, data:Object):void
		{
			if (op == "refreshcatalog")
			{
				core.catalogCtl.dumpCatalog();
			}
			else if (op == "previewmusic")
			{
				// Always honor the live flag from Configure — unchecking everywhere must clear.
				if (data.hasOwnProperty("musicEverywhere"))
				{
					core.m_musicEverywhere = Boolean(data["musicEverywhere"]);
				};
				if (core.m_musicEverywhere)
				{
					core.m_forcedMusicId = String(data["musicId"] || data["id"] || "");
				}
				else
				{
					core.musicCtl.clearForcedMatchMusic();
				};
				core.musicCtl.previewMusic(String(data["musicId"] || data["id"] || ""));
			}
			else if (op == "menumusic")
			{
				core.musicCtl.applyMenuMusicCmd(data);
			}
			else if (op == "defaultmenu")
			{
				core.musicCtl.disableMenuMusic();
				core.musicCtl.playMusicDirect("menumusic", 0);
			}
			else if (op == "defaultmusic")
			{
				core.musicCtl.playStageDefault();
			}
			else if (op == "stopmusic")
			{
				core.musicCtl.stopPreviewMusic();
			}
			else if (op == "pausematch")
			{
				setMatchPaused(true);
			}
			else if (op == "resumematch")
			{
				setMatchPaused(false);
			}
			else if (op == "generate")
			{
				generateDebug(data);
			}
			else if (op == "dumpdebuglists")
			{
				core.catalogCtl.dumpCatalog();
			}
			else if (op == "applylaunch" || op == "openscreen")
			{
				applyLaunchCmd(data);
			}
			else if (op == "patchmatch")
			{
				core.matchCtl.patchMatchLive(data);
			}
			else
			{
				log("unknown cmd op=" + op);
			};
		}

		internal function resolveCurrentCssMenu():*
		{
			var MC:Class;
			var cur:*;
			try
			{
				MC = core.cssCtl.menuController();
				cur = MC ? MC["currentMenu"] : null;
				if (cur && core.cssCtl.menuHasGame(cur))
				{
					return (cur);
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function clearCmdFile(file:File):void
		{
			var stream:FileStream;
			var ack:String;
			if (!file)
			{
				return;
			};
			try
			{
				if (file.exists)
				{
					file.deleteFile();
				};
				return;
			}
			catch (delErr:*)
			{
				log("cmd delete: " + delErr);
			};
			ack = "{\"op\":\"ack\"}";
			if (JsonFile.writeText(file, ack))
			{
				m_lastCmdFingerprint = ack;
			}
			else
			{
				log("cmd clear write: failed " + file.nativePath);
			};
		}

		internal function applyLaunchCmd(data:Object):void
		{
			if (core.m_bootDeepLink || (core.deepLinkCtl.isDeepLinkBusy() && !core.m_homeReady))
			{
				log("apply ignored: boot deep-link in progress phase=" + core.m_phase);
				return;
			};
			// Mid-session Apply/Goto must interrupt soft settle / CSS open so menu
			// switches are not stuck behind a prior patch or incomplete deep-link.
			if (core.deepLinkCtl.isDeepLinkBusy() && core.m_homeReady)
			{
				log("apply interrupt phase=" + core.m_phase);
				core.m_pendingApply = null;
				core.deepLinkCtl.stopTick();
				core.m_phase = "done";
			};
			try
			{
				core.introCtl.stopActiveIntroPlayback();
				softTeardownSession();
			}
			catch (tearErr:*)
			{
				log("teardown: " + tearErr);
			};
			applyLaunchFields(data);
			log("applyLaunch screen=" + core.m_screen + " match=" + (core.m_match ? "yes" : "no")
				+ " vault=" + core.m_vaultAction);
			if (routeLaunchWithoutCss())
			{
				core.m_phase = "done";
				core.deepLinkCtl.stopTick();
				return;
			};
			if (core.m_homeReady)
			{
				// Brief settle so endMatch MENU_HIDE can clear css_sprite_preview hosts.
				scheduleSoftBegin();
			}
			else
			{
				core.deepLinkCtl.beginDeepLink();
			};
		}

		/** Copies an applyLaunch/openScreen command onto the session (same keys as launch.json). */
		private function applyLaunchFields(data:Object):void
		{
			if (data.screen)
			{
				core.m_screen = String(data.screen).toLowerCase();
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
			else
			{
				core.musicCtl.clearForcedMatchMusic();
			};
			if (data.match !== undefined)
			{
				core.m_match = data.match as Object;
			};
			if (data.logFileAbs)
			{
				core.m_logFileAbs = String(data.logFileAbs);
			};
			core.prefsCtl.applyVaultPrefsFromData(data);
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
				core.m_bootIntroPath = "";
			};
			if (data.hasOwnProperty("fullscreen"))
			{
				core.m_wantFullscreen = Boolean(data.fullscreen);
				core.prefsCtl.applyFullscreenIfNeeded();
			};
		}

		/** Vault intro, vault costumes and home need no CSS. True when one of them handled the apply. */
		private function routeLaunchWithoutCss():Boolean
		{
			if (core.m_screen == "vault" && core.m_vaultAction == "intro")
			{
				if (core.introCtl.startBootIntroPlayback(String(core.m_bootIntro || "default"), false))
				{
					log("applyLaunch vault intro started");
				}
				else if (String(core.m_bootIntro || "default").toLowerCase() == "default")
				{
					core.introCtl.playBootIntro3();
				}
				else
				{
					core.introCtl.showPostIntroDestination();
				};
				return (true);
			};
			if (core.m_screen == "vault" && core.m_vaultAction == "costumes")
			{
				if (core.introCtl.openPaletteMaker(core.m_vaultPaletteChar))
				{
					log("applyLaunch vault palette " + core.m_vaultPaletteChar);
				};
				return (true);
			};
			if ((!core.m_screen || core.m_screen == "home") && !core.cssCtl.wantImmediateMatch())
			{
				core.introCtl.showPostIntroDestination();
				log("applyLaunch home → title");
				return (true);
			};
			return (false);
		}

		private function scheduleSoftBegin():void
		{
			var t:Timer;
			log("soft apply — settling after teardown");
			core.m_phase = "soft_settle";
			t = new Timer(180, 1);
			t.addEventListener(TimerEvent.TIMER, onSoftSettle);
			t.start();
		}

		private function onSoftSettle(e:TimerEvent):void
		{
			try
			{
				if (e && e.target)
				{
					(e.target as Timer).removeEventListener(TimerEvent.TIMER, onSoftSettle);
				};
			}
			catch (err:*)
			{
			};
			if (core.m_phase != "soft_settle")
			{
				return;
			};
			softBeginDeepLink();
		}

		/** Mid-session apply when home already settled — skip wait_home. */
		private function softBeginDeepLink():void
		{
			core.m_tries = 0;
			core.m_cssMenu = null;
			core.m_fixupTries = 0;
			core.m_matchArmTries = 0;
			core.m_didCssReset = false;
			core.m_didCssShow = false;
			core.m_didMatch = false;
			core.m_matchQueued = false;
			if (core.cssCtl.isCssScreen(core.m_screen) || core.cssCtl.wantImmediateMatch())
			{
				core.m_phase = "open_css";
				log("soft apply — opening CSS/mode select");
			}
			else
			{
				core.m_phase = "open_other";
				log("soft apply — opening " + core.m_screen);
			};
			core.deepLinkCtl.armTick();
		}

		/** End live match if any; never disposeAllMenus (wipes Title/Main and crashes hooks). */
		internal function softTeardownSession():void
		{
			var GC:Class;
			var MC:Class;
			var MainCls:Class;
			var UnlockCls:Class;
			var sd:*;
			var game:*;
			var cur:*;
			try
			{
				GC = EngineRefs.GameController as Class;
			}
			catch (gcErr:*)
			{
				GC = null;
			};
			if (GC)
			{
				try
				{
					GC["isStarted"] = false;
				}
				catch (startedErr:*)
				{
				};
				try
				{
					sd = GC["stageData"];
					if (sd)
					{
						try
						{
							game = sd["GAME"];
							if (game)
							{
								game["CustomMatchObj"] = null;
							};
							sd["Paused"] = true;
							sd["GameEnded"] = true;
						}
						catch (quietErr:*)
						{
						};
					};
				}
				catch (sdErr:*)
				{
				};
				try
				{
					if (GC["endMatch"])
					{
						GC["endMatch"]();
					};
				}
				catch (endErr:*)
				{
					log("endMatch: " + endErr);
				};
				try
				{
					if (GC["destroyStageData"])
					{
						GC["destroyStageData"]();
					};
				}
				catch (destroyErr:*)
				{
					log("destroyStageData: " + destroyErr);
				};
			};
			try
			{
				UnlockCls = EngineRefs.ssf2("controllers.UnlockController") as Class;
				if (UnlockCls)
				{
					UnlockCls["nextMenuFunc"] = null;
				};
			}
			catch (unlockErr:*)
			{
			};
			m_pausedByStream = false;
			try
			{
				MainCls = EngineRefs.Main as Class;
				if (MainCls && MainCls["Root"])
				{
					MainCls["Root"]["visible"] = true;
				};
			}
			catch (visErr:*)
			{
			};
			try
			{
				if (core.m_cssMenu && core.m_cssMenu["removeSelf"])
				{
					core.m_cssMenu["removeSelf"]();
				};
			}
			catch (hideErr:*)
			{
			};
			try
			{
				MC = core.cssCtl.menuController();
				if (MC)
				{
					cur = MC["CurrentCharacterSelectMenu"];
					if (cur && cur != core.m_cssMenu && cur["removeSelf"])
					{
						cur["removeSelf"]();
					};
				};
			}
			catch (cssErr:*)
			{
			};
			core.m_didMatch = false;
			core.m_matchQueued = false;
			core.m_didCssReset = false;
			core.m_didCssShow = false;
			core.m_cssMenu = null;
		}

		private function setMatchPaused(pause:Boolean):void
		{
			var GC:Class;
			var sd:*;
			try
			{
				GC = EngineRefs.GameController as Class;
				sd = GC ? GC["stageData"] : null;
				// Menu-preview StageData has HUD=null; Paused setter NPEs on it.
				if (!sd || Boolean(sd["GameEnded"]) || Boolean(sd["IsMenuPreview"]) || !sd["HUD"])
				{
					log(pause ? "pauseMatch: no live match" : "resumeMatch: no live match");
					return;
				};
				if (pause)
				{
					sd["PausedID"] = 1;
					sd["Paused"] = true;
					m_pausedByStream = true;
					log("pauseMatch ok");
				}
				else
				{
					sd["Paused"] = false;
					m_pausedByStream = false;
					log("resumeMatch ok");
				};
			}
			catch (err:*)
			{
				log((pause ? "pauseMatch" : "resumeMatch") + " failed: " + err);
			};
		}

		private function generateDebug(data:Object):void
		{
			var GC:Class;
			var sd:*;
			var kind:String;
			var id:int;
			var rare:Boolean;
			var itemDataCls:Class;
			var itemsListCls:Class;
			var itemData:*;
			var item:*;
			var p1:*;
			var itemsRef:*;
			kind = String(data["kind"] || "").toLowerCase();
			id = int(data["id"] || 0);
			rare = Boolean(data["rare"]);
			if (id < 0)
			{
				id = 0;
			};
			try
			{
				GC = EngineRefs.GameController as Class;
				sd = GC ? GC["stageData"] : null;
				if (!sd || Boolean(sd["GameEnded"]))
				{
					log("generate: no live match");
					return;
				};
				itemsRef = sd["ItemsRef"];
				p1 = sd["getPlayerByID"](1);
				if (!itemsRef)
				{
					log("generate: no ItemsRef");
					return;
				};
				if (kind == "item")
				{
					itemDataCls = EngineRefs.ssf2("items.ItemData") as Class;
					itemsListCls = EngineRefs.ssf2("items.ItemsListData") as Class;
					itemData = new itemDataCls();
					itemData["importData"](itemsListCls["DATA"][Math.min(itemsListCls["DATA"]["length"] - 1, id)]);
					item = itemsRef["generateItemObj"](itemData);
				}
				else if (kind == "pokemon")
				{
					item = itemsRef["generateItemObj"](itemsRef["getItemByLinkage"](rare ? "masterball" : "pokeball"));
					if (item)
					{
						itemsRef["PokemonClass"] = rare
							? sd["PokemonsRare"][Math.min(sd["PokemonsRare"]["length"] - 1, id)]
							: sd["Pokemons"][Math.min(sd["Pokemons"]["length"] - 1, id)];
					};
				}
				else if (kind == "assist")
				{
					item = itemsRef["generateItemObj"](itemsRef["getItemByLinkage"]("assistTrophy"));
					if (item)
					{
						itemsRef["AssistClass"] = rare
							? sd["AssistsRare"][Math.min(sd["AssistsRare"]["length"] - 1, id)]
							: sd["Assists"][Math.min(sd["Assists"]["length"] - 1, id)];
					};
				}
				else
				{
					log("generate: unknown kind=" + kind);
					return;
				};
				if (item && p1)
				{
					item["X"] = p1["X"] + (p1["FacingForward"] ? 8 : -8);
					item["Y"] = p1["Y"] - p1["Height"];
					log("generate " + kind + " id=" + id + (rare ? " rare" : ""));
				}
				else if (!item)
				{
					log("generate failed kind=" + kind + " id=" + id);
				};
			}
			catch (err:*)
			{
				log("generate error: " + err);
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
