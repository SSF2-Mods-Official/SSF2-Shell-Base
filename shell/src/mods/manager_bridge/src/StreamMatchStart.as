package
{
	import flash.display.MovieClip;
	import flash.utils.getQualifiedClassName;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Match start from CSS (or fallback Game), live match patches and the
	 * sandbag spawn override.
	 */
	internal class StreamMatchStart
	{
		private var core:Ssf2StreamMod;

		public function StreamMatchStart(owner:Ssf2StreamMod)
		{
			core = owner;
		}

		internal function tryStartSoloMatchFromCss():Boolean
		{
			var menu:*;
			var game:*;
			var key:String;
			var modeId:String;
			var idx:int;
			var SQ:Class;
			var charFromStage:String;
			menu = core.m_cssMenu;
			if (!menu || !core.cssCtl.isCssReady(menu))
			{
				if (menu && !core.cssCtl.menuHasGame(menu))
				{
					core.cssCtl.callUpdateDisplay(menu);
				};
				return (false);
			};
			try
			{
				core.rosterCtl.applyRosterFromMatch(menu);
				game = menu["GameObj"];
				if (!game)
				{
					return (false);
				};
				core.rosterCtl.applyRulesFromMatch(game);
				key = String(core.m_screen || core.cssCtl.cssScreenKey() || "").toLowerCase();
				modeId = String(core.m_match["customModeID"] || core.m_match["stage"] || "");
				if (key == "arena")
				{
					modeId = core.cssCtl.resolveArenaModeId(modeId);
				}
				else if (key == "multiman")
				{
					modeId = core.cssCtl.resolveMultimanModeId(modeId);
				}
				else if (key == "btt")
				{
					charFromStage = characterIdFromTargetTestStage(modeId);
					if (charFromStage.length > 0)
					{
						// Keep user's P1. Use Level 1 (not Character) so fighters without
						// their own BTT aren't __blocked; CustomMode swaps in the stage SWF.
						try
						{
							var MH:Class = EngineRefs.ModHost as Class;
							if (MH)
							{
								MH["pendingStageOverride"] = modeId;
							};
						}
						catch (ovErr:*)
						{
						};
						log("BTT stage override=" + modeId + " via Level 1 (P1 unchanged)");
						modeId = "Level 1";
					};
				};
				idx = findModeStageIndex(key, modeId);
				if (idx >= 0)
				{
					trySetMenuStageId(menu, idx);
				};
				if (modeId.length > 0 && game["LevelData"])
				{
					game["LevelData"]["customModeID"] = modeId;
				};
				core.cssCtl.applyModeStatics(key);
				try
				{
					SQ = EngineRefs.SoundQueue as Class;
					if (SQ && SQ["instance"])
					{
						SQ["instance"]["playSoundEffect"]("menu_selectstage");
						SQ["instance"]["playSoundEffect"]("menu_crowd");
					};
				}
				catch (sfxErr:*)
				{
				};
				// Keep custom music override (multiman/default mode tracks otherwise win).
				core.musicCtl.ensureMatchMusicQueued(game);
				queueSandbagOverride(core.getRM());
				if (menu["initMatch"])
				{
					menu["initMatch"]();
					// initMatch can abort silently (blocked icon) — drop unused override.
					clearPendingStageOverrideIfStale();
					core.m_didMatch = true;
					core.m_matchQueued = true;
					core.musicCtl.ensureMatchMusicQueued(game);
					log("solo initMatch screen=" + key + " modeId=" + modeId + " music=" + String(core.m_match && core.m_match["music"] || ""));
					core.deepLinkCtl.finish();
					return (true);
				};
			}
			catch (err:*)
			{
				clearPendingStageOverrideIfStale(true);
				log("solo initMatch failed: " + err);
				core.m_matchQueued = false;
				return (false);
			};
			return (false);
		}

		/** Drop pendingStageOverride if CustomMode.startMatch never consumed it. */
		private function clearPendingStageOverrideIfStale(force:Boolean=false):void
		{
			var MH:Class;
			var left:String;
			try
			{
				MH = EngineRefs.ModHost as Class;
				if (!MH)
				{
					return;
				};
				left = String(MH["pendingStageOverride"] || "");
				if (force || left.length > 0)
				{
					MH["pendingStageOverride"] = "";
					if (left.length > 0)
					{
						log("cleared stale pendingStageOverride=" + left);
					};
				};
			}
			catch (err:*)
			{
			};
		}

		/** targettest_mario → mario; Level 1 / Character → "". */
		internal function characterIdFromTargetTestStage(modeId:String):String
		{
			var id:String;
			var prefix:String;
			id = String(modeId || "");
			prefix = "targettest_";
			if (id.toLowerCase().indexOf(prefix) != 0)
			{
				return ("");
			};
			return (id.substr(prefix.length));
		}

		internal function findModeStageIndex(key:String, modeId:String):int
		{
			var list:Array;
			var i:int;
			var item:*;
			if (!modeId)
			{
				return (-1);
			};
			if (key == "btt")
			{
				list = core.catalogCtl.readModeStageList(core.getRM(), "targets_mode", "targetStageList");
			}
			else if (key == "hrc")
			{
				list = core.catalogCtl.readModeStageList(core.getRM(), "homeruncontest_mode", "hrcStageList");
			}
			else if (key == "crystal")
			{
				list = core.catalogCtl.readModeStageList(core.getRM(), "crystals_mode", "crystalStageList");
			}
			else
			{
				return (-1);
			};
			i = 0;
			while (i < list.length)
			{
				item = list[i];
				if (item && String(item["id"]) == modeId)
				{
					return (i);
				};
				i++;
			};
			return (-1);
		}

		internal function trySetMenuStageId(menu:*, idx:int):void
		{
			try
			{
				menu["m_stage_id"] = idx;
			}
			catch (e1:*)
			{
			};
			try
			{
				if (menu["updateTargetTestDisplay"])
				{
					menu["updateTargetTestDisplay"]();
				};
			}
			catch (e0:*)
			{
			};
			try
			{
				if (menu["updateCrystalSmashDisplay"])
				{
					menu["updateCrystalSmashDisplay"]();
				};
			}
			catch (e2:*)
			{
			};
			try
			{
				if (menu["updateText"])
				{
					menu["updateText"]();
				};
			}
			catch (e3:*)
			{
			};
			try
			{
				if (menu["updateDisplay"])
				{
					menu["updateDisplay"]();
				};
			}
			catch (e4:*)
			{
			};
		}

		internal function tryStartMatchFromCss():Boolean
		{
			var menu:*;
			var game:*;
			var GC:Class;
			var RM:Class;
			var MainCls:Class;
			var UtilsCls:Class;
			var MC:Class;
			var stageId:String;
			var players:Array;
			var playerSettings:*;
			var toLoad:Array;
			var onComplete:Function;
			var loadingMask:MovieClip;

			menu = core.m_cssMenu;
			if (!menu || !core.cssCtl.isCssReady(menu))
			{
				if (menu && !core.cssCtl.menuHasGame(menu))
				{
					core.cssCtl.callUpdateDisplay(menu);
				};
				return (false);
			};
			game = menu["GameObj"];
			stageId = String(core.m_match["stage"] || "");
			players = core.m_match["players"] as Array;
			if (!stageId || !players)
			{
				return (false);
			};
			try
			{
				GC = EngineRefs.GameController as Class;
				RM = EngineRefs.ResourceManager as Class;
				MainCls = EngineRefs.Main as Class;
				UtilsCls = EngineRefs.Utils as Class;
				MC = core.cssCtl.menuController();
			}
			catch (err:*)
			{
				return (false);
			};
			if (cssStartBlocked(GC, RM))
			{
				return (false);
			};
			if (StageAssetLaunch.hold(stageId))
			{
				return (false);
			};

			try
			{
				core.rosterCtl.applyRosterFromMatch(menu);
				playerSettings = game["PlayerSettings"];
				// Do NOT call updateDisplay here — training mode re-randomizes P2.
				game["LevelData"]["stage"] = stageId;
				seedMatchRandom(game, UtilsCls);
				if (MainCls)
				{
					MainCls["prepRandomCharacters"](playerSettings ? playerSettings["length"] : 0);
				};
				GC["isStarted"] = true;
				toLoad = buildMatchLoadList(RM, game, stageId);
				queueMatchResources(RM, playerSettings, toLoad);
				loadingMask = showMatchLoadingMask(RM, MainCls);
				onComplete = matchLoadComplete(loadingMask, MC, GC, game,
					"startMatch from CSS GameObj stage=" + stageId, "startMatch CSS failed: ");
				RM["load"]({"oncomplete": onComplete});
				log("loading match from CSS GameObj stage=" + stageId);
				core.m_matchQueued = true;
				return (true);
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
				log("CSS match setup failed: " + setupErr);
				return (false);
			};
			return (false);
		}

		/** True (and logged every 30 tries) while GC/RM are missing or a match is still marked started. */
		private function cssStartBlocked(GC:Class, RM:Class):Boolean
		{
			if (!GC || !RM)
			{
				if (core.m_matchArmTries == 1 || core.m_matchArmTries % 30 == 0)
				{
					log("tryStartMatch: missing GC=" + Boolean(GC) + " RM=" + Boolean(RM));
				};
				return (true);
			};
			if (Boolean(GC["isStarted"]))
			{
				if (core.m_matchArmTries == 1 || core.m_matchArmTries % 30 == 0)
				{
					log("tryStartMatch: blocked — GameController.isStarted still true");
				};
				try
				{
					GC["isStarted"] = false;
				}
				catch (resetErr:*)
				{
				};
				return (true);
			};
			return (false);
		}

		/** New LevelData.randSeed, then reseed and shuffle the engine RNG. */
		private function seedMatchRandom(game:*, UtilsCls:Class):void
		{
			game["LevelData"]["randSeed"] = UtilsCls["randomInteger"](1, 1000);
			UtilsCls["setRandSeed"](game["LevelData"]["randSeed"]);
			UtilsCls["shuffleRandom"]();
		}

		/** Stage, stage music, and the requested (musicOverride) or forced match music. */
		private function buildMatchLoadList(RM:Class, game:*, stageId:String):Array
		{
			var toLoad:Array;
			toLoad = [stageId];
			core.musicCtl.queueStageMusic(RM, stageId, toLoad);
			if (core.m_match && String(core.m_match["music"] || "").length > 0)
			{
				game["LevelData"]["musicOverride"] = String(core.m_match["music"]);
				toLoad.push(String(core.m_match["music"]));
			}
			else if (core.m_musicEverywhere && core.m_forcedMusicId)
			{
				toLoad.push(core.m_forcedMusicId);
			};
			return (toLoad);
		}

		/** Queues every player slot's character, the sandbag override, then the load list. */
		private function queueMatchResources(RM:Class, playerSettings:*, toLoad:Array):void
		{
			var slot:int;
			slot = 0;
			while (slot < playerSettings["length"])
			{
				RM["queuePlayerCharacterResource"](playerSettings[slot], slot);
				slot++;
			};
			queueSandbagOverride(RM);
			RM["queueResources"](toLoad);
		}

		/** Centers the engine loadingMask on Root while the match loads. Null when it is not available. */
		private function showMatchLoadingMask(RM:Class, MainCls:Class):MovieClip
		{
			var loadingMask:MovieClip;
			var root:*;
			loadingMask = null;
			try
			{
				loadingMask = RM["getLibraryMC"]("loadingMask") as MovieClip;
				if (loadingMask && MainCls)
				{
					loadingMask.x = Number(MainCls["Width"]) / 2;
					loadingMask.y = Number(MainCls["Height"]) / 2;
					root = MainCls["Root"];
					if (root)
					{
						root.addChild(loadingMask);
					};
				};
			}
			catch (maskErr:*)
			{
			};
			return (loadingMask);
		}

		/** RM.load oncomplete: drop the mask and menus, start the match, finish the deep link. */
		private function matchLoadComplete(loadingMask:MovieClip, MC:Class, GC:Class, game:*,
			startedLine:String, failedPrefix:String):Function
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
					core.uncaughtCtl.armUncaughtErrorLogging();
					GC["startMatch"](game);
					core.m_didMatch = true;
					log(startedLine);
					core.deepLinkCtl.finish();
				}
				catch (doneErr:*)
				{
					GC["isStarted"] = false;
					core.m_matchQueued = false;
					log(failedPrefix + doneErr);
				};
			};
		}

		internal function tryStartMatchFallback():Boolean
		{
			var GameCls:Class;
			var ModeCls:Class;
			var GC:Class;
			var RM:Class;
			var MainCls:Class;
			var UtilsCls:Class;
			var MC:Class;
			var game:*;
			var stageId:String;
			var players:Array;
			var count:int;
			var mode:*;
			var toLoad:Array;
			var onComplete:Function;
			var loadingMask:MovieClip;
			var playerSettings:*;

			if (core.m_didMatch || core.m_matchQueued)
			{
				return (true);
			};
			try
			{
				GameCls = EngineRefs.ssf2("controllers.Game") as Class;
				ModeCls = EngineRefs.ssf2("enums.Mode") as Class;
				GC = EngineRefs.GameController as Class;
				RM = EngineRefs.ResourceManager as Class;
				MainCls = EngineRefs.Main as Class;
				UtilsCls = EngineRefs.Utils as Class;
				MC = core.cssCtl.menuController();
			}
			catch (err:*)
			{
				return (false);
			};
			if (!GameCls || !ModeCls || !GC || !RM || Boolean(GC["isStarted"]))
			{
				return (false);
			};
			stageId = String(core.m_match["stage"] || "");
			players = core.m_match["players"] as Array;
			count = core.cssCtl.countPlayers(players);
			if (!stageId || count < 1)
			{
				return (false);
			};
			if (StageAssetLaunch.hold(stageId))
			{
				return (false);
			};
			mode = fallbackMode(ModeCls, count);
			try
			{
				game = new GameCls(count, mode);
				game["LevelData"]["stage"] = stageId;
				seedMatchRandom(game, UtilsCls);
				playerSettings = game["PlayerSettings"];
				fillFallbackPlayers(players, playerSettings);
				MainCls["prepRandomCharacters"](playerSettings ? playerSettings["length"] : 0);
				GC["isStarted"] = true;
				toLoad = buildMatchLoadList(RM, game, stageId);
				queueMatchResources(RM, playerSettings, toLoad);
				loadingMask = showMatchLoadingMask(RM, MainCls);
				onComplete = matchLoadComplete(loadingMask, MC, GC, game,
					"startMatch fallback stage=" + stageId, "startMatch fallback failed: ");
				RM["load"]({"oncomplete": onComplete});
				core.m_matchQueued = true;
				log("loading fallback match stage=" + stageId);
				return (true);
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
				log("fallback match setup failed: " + setupErr);
				return (false);
			};
			return (false);
		}

		/** TRAINING on the training CSS or with one player; otherwise the first VS mode the enum has. */
		private function fallbackMode(ModeCls:Class, count:int):*
		{
			var mode:*;
			mode = ModeCls["TRAINING"];
			if (core.cssCtl.cssScreenKey() != "training_css" && count > 1)
			{
				if (ModeCls["VS"] != null)
				{
					mode = ModeCls["VS"];
				}
				else if (ModeCls["VERSUS"] != null)
				{
					mode = ModeCls["VERSUS"];
				}
				else if (ModeCls["STANDARD"] != null)
				{
					mode = ModeCls["STANDARD"];
				};
			};
			return (mode);
		}

		/** Copies the requested players into PlayerSettings in order; P1 is human, the rest CPU. */
		private function fillFallbackPlayers(players:Array, playerSettings:*):void
		{
			var i:int;
			var slot:int;
			var charId:String;
			slot = 0;
			i = 0;
			while (i < players.length && slot < playerSettings["length"])
			{
				charId = core.cssCtl.playerCharId(players[i]);
				if (charId.length > 0)
				{
					playerSettings[slot]["exist"] = true;
					playerSettings[slot]["character"] = charId;
					playerSettings[slot]["human"] = slot == 0;
					core.cssCtl.preparePlayerCostume(charId, playerSettings, slot);
					slot++;
				};
				i++;
			};
		}

		/** Soft live update while already on CSS/menu — no teardown. */
		internal function patchMatchLive(data:Object):void
		{
			var menu:*;
			var game:*;
			var stageId:String;
			if (!data)
			{
				return;
			};
			if (data["screen"])
			{
				core.m_screen = String(data["screen"]).toLowerCase();
			};
			if (data["match"] !== undefined)
			{
				core.m_match = data["match"] as Object;
			};
			menu = core.m_cssMenu;
			if (!menu || !core.cssCtl.menuHasGame(menu))
			{
				try
				{
					menu = core.cmdCtl.resolveCurrentCssMenu();
					if (menu)
					{
						core.m_cssMenu = menu;
					};
				}
				catch (findErr:*)
				{
				};
			};
			if (!menu || !core.cssCtl.menuHasGame(menu))
			{
				log("patchMatch: no active CSS/menu");
				return;
			};
			try
			{
				// Soft live update: rules/mode only — never re-apply full roster (CSS_SELECT spam / focus loss).
				game = menu["GameObj"];
				if (game)
				{
					core.rosterCtl.applyRulesFromMatch(game);
					stageId = String(core.m_match && core.m_match["stage"] || "");
					if (stageId.length > 0 && game["LevelData"] && (core.cssCtl.cssScreenKey() == "versus_css" || core.cssCtl.cssScreenKey() == "training_css" || core.cssCtl.cssScreenKey() == "rttf"))
					{
						if (NON_STAGE_MODE_IDS_CHECK(stageId) == false)
						{
							game["LevelData"]["stage"] = stageId;
						};
					};
					if (core.m_match && core.m_match["customModeID"] && game["LevelData"])
					{
						game["LevelData"]["customModeID"] = String(core.m_match["customModeID"]);
					};
					if (core.m_match && String(core.m_match["music"] || "").length > 0 && game["LevelData"])
					{
						game["LevelData"]["musicOverride"] = String(core.m_match["music"]);
					};
					core.cssCtl.applyModeStatics(core.cssCtl.cssScreenKey());
					core.rosterCtl.scheduleArmCssMatchReady(menu);
				};
				log("patchMatch applied screen=" + core.m_screen);
			}
			catch (err:*)
			{
				log("patchMatch failed: " + err);
			};
		}

		private function NON_STAGE_MODE_IDS_CHECK(id:String):Boolean
		{
			return (id == "soccer" || id == "basketball" || id == "man10" || id == "man100" || id == "min3" || id == "endless" || id == "cruel");
		}

		private function sandbagOverrideId():String
		{
			if (!core.m_match || core.m_match["sandbagCharacter"] == undefined || core.m_match["sandbagCharacter"] == null)
			{
				return ("");
			};
			return (String(core.m_match["sandbagCharacter"] || ""));
		}

		internal function queueSandbagOverride(RM:Class):void
		{
			var id:String;
			id = sandbagOverrideId();
			armSandbagSpawnPatch();
			if (!RM || id.length < 1)
			{
				return;
			};
			try
			{
				RM["queuePlayerCharacterResource"]({
					"character": id,
					"costume": -1,
					"expansion": -1,
					"exist": true
				}, 0);
			}
			catch (err:*)
			{
				log("sandbag preload: " + err);
			};
		}

		internal function armSandbagSpawnPatch():void
		{
			if (!core.m_host || sandbagOverrideId().length < 1)
			{
				return;
			};
			try
			{
				core.m_host.patch("api.spawnCharacter", onSpawnCharacter);
			}
			catch (err:*)
			{
				log("sandbag spawn patch: " + err);
			};
		}

		private function characterClassForId(id:String):Class
		{
			var RM:Class;
			var res:*;
			var chars:*;
			var row:*;
			RM = core.getRM();
			if (!RM || !id || id.length < 1)
			{
				return (null);
			};
			try
			{
				res = RM["getResourceByID"](id);
				if (!res || !res["getProp"])
				{
					return (null);
				};
				chars = res["getProp"]("characters");
				if (!chars || int(chars["length"]) < 1)
				{
					return (null);
				};
				row = chars[0];
				if (!row || !row["cData"] || !row["cData"]["classAPI"])
				{
					return (null);
				};
				return (row["cData"]["classAPI"] as Class);
			}
			catch (err:*)
			{
				return (null);
			};
			return (null);
		}

		private function isSandbagClass(character:Class):Boolean
		{
			var q:String;
			var stock:Class;
			if (!character)
			{
				return (false);
			};
			q = getQualifiedClassName(character).toLowerCase();
			if (q.indexOf("sandbag") >= 0)
			{
				return (true);
			};
			stock = characterClassForId("sandbag");
			return (stock != null && character == stock);
		}

		/** Mode SWFs call SSF2API.spawnCharacter(Sandbag). Spawn the override class instead. */
		private function onSpawnCharacter(character:Class):*
		{
			var id:String;
			var next:Class;
			var repl:Class;
			var GC:Class;
			var sd:*;
			var spawned:*;
			id = sandbagOverrideId();
			next = character;
			if (id.length > 0 && isSandbagClass(character))
			{
				repl = characterClassForId(id);
				if (repl)
				{
					next = repl;
					log("sandbag spawn " + id);
				}
				else
				{
					log("sandbag spawn class missing for " + id);
				};
			};
			GC = EngineRefs.GameController as Class;
			sd = GC ? GC["stageData"] : null;
			if (!sd || !sd["spawnCharacterAPI"])
			{
				log("sandbag spawn: stageData missing");
				return (null);
			};
			spawned = sd["spawnCharacterAPI"](next);
			if (!spawned || !spawned["APIInstance"])
			{
				return (null);
			};
			return (spawned["APIInstance"]["instance"]);
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
