package
{
	import ssf2mm.shared.EngineRefs;

	/**
	 * Menu and CSS helpers: resolve menus, open CSS, init GameObj, mode statics.
	 */
	internal class StreamCssMenus
	{
		private var core:Ssf2StreamMod;
		private var m_cssInitBusy:Boolean;

		private static const HOME_ALIASES:Array = [
			"mainMenu", "MainMenu", "homeMenu", "HomeMenu", "modeMenu", "ModeMenu",
			"menu", "Menu", "titleMenu", "TitleMenu"
		];

		private static const MENU_ALIASES:Object = {
			"title": ["titleMenu", "TitleMenu"],
			"home": ["titleMenu", "TitleMenu", "mainMenu", "MainMenu"],
			"group": ["groupMenu", "groupModeMenu", "GroupMenu", "multiplayerMenu"],
			"online": ["onlineMenu", "OnlineMenu", "wifiMenu", "netplayMenu"],
			"data": ["dataMenu", "DataMenu", "recordsMenu", "statsMenu"],
			"options": ["optionsMenu", "OptionsMenu", "settingsMenu", "gameOptionsMenu"],
			"controls": ["controlsMenu"],
			"vault": ["vaultMenu"],
			"solo": ["soloMenu", "SoloMenu", "singlePlayerMenu", "singlemenu"],
			"versus_css": ["vsMenu", "CurrentCharacterSelectMenu"],
			"training_css": ["trainingMenu"],
			"classic": ["classicMenu"],
			"allstar": ["allstarMenu"],
			"btt": ["targetTestMenu"],
			"hrc": ["homeRunContestMenu"],
			"multiman": ["multimanCharacterSelectMenu"],
			"crystal": ["crystalSmashCharacterMenu"],
			"rttf": ["raceToTheFinishCharacterMenu"],
			"arena": ["arenaCharacterSelectMenu"],
			"events": ["eventMenu"],
			"css": ["vsMenu", "CurrentCharacterSelectMenu", "trainingMenu"],
			"sss": ["vsStageMenu", "CurrentStageSelectMenu", "stageSelectMenu", "trainingStageMenu"]
		};

		public function StreamCssMenus(owner:Ssf2StreamMod)
		{
			core = owner;
			m_cssInitBusy = false;
		}

		internal function wantImmediateMatch():Boolean
		{
			var key:String;
			var players:Array;
			var stageId:String;
			var modeId:String;
			if (core.m_didMatch || core.m_matchQueued || !core.m_match)
			{
				return (false);
			};
			if (!core.m_match["immediate"])
			{
				return (false);
			};
			key = String(core.m_screen || cssScreenKey() || "").toLowerCase();
			players = core.m_match["players"] as Array;
			if (!players || countPlayers(players) < 1)
			{
				return (false);
			};
			if (key == "versus_css" || key == "training_css" || key == "css")
			{
				stageId = String(core.m_match["stage"] || "");
				return (stageId.length > 0);
			};
			if (key == "classic" || key == "allstar" || key == "rttf")
			{
				return (true);
			};
			if (key == "btt" || key == "hrc" || key == "crystal" || key == "multiman" || key == "arena")
			{
				modeId = String(core.m_match["customModeID"] || core.m_match["stage"] || "");
				return (modeId.length > 0);
			};
			return (false);
		}

		internal function isSoloModeScreen(key:String):Boolean
		{
			return (key == "classic" || key == "allstar" || key == "btt" || key == "hrc"
				|| key == "multiman" || key == "crystal" || key == "rttf" || key == "arena");
		}

		internal function countPlayers(players:Array):int
		{
			var n:int = 0;
			var i:int = 0;
			var slot:*;
			var charId:String;
			while (i < players.length)
			{
				slot = players[i];
				charId = playerCharId(slot);
				if (charId.length > 0)
				{
					n++;
				};
				i++;
			};
			return (n);
		}

		internal function playerCharId(slot:*):String
		{
			if (slot == null)
			{
				return ("");
			};
			if (typeof slot == "string" || slot is String)
			{
				return (String(slot));
			};
			try
			{
				if (slot["character"] != null)
				{
					return (String(slot["character"]));
				};
			}
			catch (err:*)
			{
			};
			return ("");
		}

		internal function isCssScreen(screen:String):Boolean
		{
			var key:String;
			key = LaunchScreen.menuKey(screen);
			return (key == "versus_css" || key == "training_css" || key == "css"
				|| key == "classic" || key == "allstar" || key == "btt" || key == "hrc"
				|| key == "multiman" || key == "crystal" || key == "rttf" || key == "arena");
		}

		internal function cssScreenKey():String
		{
			if (isCssScreen(core.m_screen))
			{
				return (LaunchScreen.menuKey(core.m_screen));
			};
			// Instant match without explicit CSS — pick training for 1P else versus.
			if (core.m_match && core.m_match["players"] && countPlayers(core.m_match["players"] as Array) <= 1)
			{
				return ("training_css");
			};
			return ("versus_css");
		}

		internal function menuController():Class
		{
			try
			{
				return (EngineRefs.MenuController as Class);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private function resolveMenu(names:Array):*
		{
			var MC:Class;
			var i:int;
			var menu:*;
			MC = menuController();
			if (!MC || !names)
			{
				return (null);
			};
			i = 0;
			while (i < names.length)
			{
				try
				{
					menu = MC[names[i]];
					if (menu)
					{
						return (menu);
					};
				}
				catch (err:*)
				{
				};
				i++;
			};
			return (null);
		}

		internal function isTargetCssMenu(menu:*):Boolean
		{
			var names:Array;
			var i:int;
			var other:*;
			var qn:String;
			var key:String;
			if (!menu)
			{
				return (false);
			};
			qn = core.safeName(menu);
			key = cssScreenKey();
			// Class-name check is reliable even before CurrentCharacterSelectMenu is wired.
			if (key == "training_css")
			{
				if (qn.indexOf("TrainingMenu") >= 0)
				{
					return (true);
				};
			}
			else if (key == "versus_css" || key == "css")
			{
				if (qn.indexOf("VSMenu") >= 0)
				{
					return (true);
				};
				if (key == "css" && qn.indexOf("TrainingMenu") >= 0)
				{
					return (true);
				};
			}
			else if (key == "classic" && qn.indexOf("ClassicModeMenu") >= 0)
			{
				return (true);
			}
			else if (key == "allstar" && qn.indexOf("AllStarModeMenu") >= 0)
			{
				return (true);
			}
			else if (key == "btt" && qn.indexOf("TargetTestMenu") >= 0)
			{
				return (true);
			}
			else if (key == "hrc" && qn.indexOf("HomeRunContestMenu") >= 0)
			{
				return (true);
			}
			else if (key == "multiman" && qn.indexOf("MultiManCharacterSelectMenu") >= 0)
			{
				return (true);
			}
			else if (key == "crystal" && qn.indexOf("CrystalSmashCharacterMenu") >= 0)
			{
				return (true);
			}
			else if (key == "rttf" && qn.indexOf("RaceToTheFinishCharacterMenu") >= 0)
			{
				return (true);
			}
			else if (key == "arena" && qn.indexOf("ArenaCharacterSelectMenu") >= 0)
			{
				return (true);
			};
			names = MENU_ALIASES[key] as Array;
			if (!names)
			{
				names = MENU_ALIASES["versus_css"] as Array;
			};
			i = 0;
			while (i < names.length)
			{
				other = resolveMenu([names[i]]);
				if (other && other == menu)
				{
					return (true);
				};
				i++;
			};
			return (false);
		}

		internal function pollAnyNonCssMenuVisible():Boolean
		{
			var MC:Class;
			var i:int;
			var menu:*;
			MC = menuController();
			if (!MC)
			{
				return (false);
			};
			i = 0;
			while (i < HOME_ALIASES.length)
			{
				try
				{
					menu = MC[HOME_ALIASES[i]];
					if (menu && menuIsOnscreen(menu) && !isTargetCssMenu(menu))
					{
						return (true);
					};
				}
				catch (err:*)
				{
				};
				i++;
			};
			// Any MENU_SHOW already flipped m_homeReady; also accept "something is up".
			return (false);
		}

		private function menuIsOnscreen(menu:*):Boolean
		{
			try
			{
				if (menu["isOnscreen"] && menu["isOnscreen"]())
				{
					return (true);
				};
			}
			catch (err:*)
			{
			};
			try
			{
				if (menu["visible"] || (menu["parent"] != null))
				{
					return (true);
				};
			}
			catch (err2:*)
			{
			};
			return (false);
		}

		/**
		 * Open CSS the engine way (GroupMenu.brawl / SoloMenu.training):
		 * CurrentCharacterSelectMenu = menu; menu.reset(); menu.show();
		 * reset() creates GameObj — show()/updateDisplay() alone NPE (#1009).
		 */
		internal function showCssMenu(screen:String):*
		{
			var MC:Class;
			var menu:*;
			var key:String;
			var preferred:Array;
			var modeId:String;
			var idx:int;
			MC = menuController();
			if (!MC)
			{
				return (null);
			};
			key = String(screen || "").toLowerCase();
			applyModeStatics(key);
			if (key == "training_css")
			{
				preferred = ["trainingMenu"];
			}
			else if (key == "classic")
			{
				preferred = ["classicMenu"];
			}
			else if (key == "allstar")
			{
				preferred = ["allstarMenu"];
			}
			else if (key == "btt")
			{
				preferred = ["targetTestMenu"];
			}
			else if (key == "hrc")
			{
				preferred = ["homeRunContestMenu"];
			}
			else if (key == "multiman")
			{
				preferred = ["multimanCharacterSelectMenu"];
			}
			else if (key == "crystal")
			{
				preferred = ["crystalSmashCharacterMenu"];
			}
			else if (key == "rttf")
			{
				preferred = ["raceToTheFinishCharacterMenu"];
			}
			else if (key == "arena")
			{
				preferred = ["arenaCharacterSelectMenu"];
			}
			else
			{
				preferred = ["vsMenu"];
			};
			menu = resolveMenu(preferred);
			if (!menu)
			{
				menu = resolveMenu(MENU_ALIASES[key] as Array);
			};
			if (!menu)
			{
				return (null);
			};
			if (key == "btt" || key == "hrc" || key == "crystal")
			{
				modeId = String(core.m_match && (core.m_match["customModeID"] || core.m_match["stage"]) || "");
				// Character BTT stages use Level 1 picker so fighters without their own
				// targettest_* aren't greyed; CustomMode applies pendingStageOverride.
				if (key == "btt" && core.matchCtl.characterIdFromTargetTestStage(modeId).length > 0)
				{
					modeId = "Level 1";
				};
				idx = core.matchCtl.findModeStageIndex(key, modeId);
				if (idx >= 0)
				{
					core.matchCtl.trySetMenuStageId(menu, idx);
				};
			};
			if (key == "hrc" || key == "arena")
			{
				core.matchCtl.queueSandbagOverride(core.getRM());
			};
			if (!ensureCssInitialized(menu))
			{
				return (menu);
			};
			log("opened CSS " + preferred[0] + " (reset+show)");
			return (menu);
		}

		/** Seed static mode pickers before opening character select. */
		internal function applyModeStatics(key:String):void
		{
			var modeId:String;
			var diffIdx:int;
			var DiffCls:Class;
			var ClassicCls:Class;
			var AllStarCls:Class;
			var MultiCls:Class;
			var ArenaCls:Class;
			modeId = "";
			if (core.m_match)
			{
				modeId = String(core.m_match["customModeID"] || core.m_match["stage"] || "");
			};
			try
			{
				if (key == "classic")
				{
					ClassicCls = EngineRefs.ssf2("menus.ClassicModeMenu") as Class;
					DiffCls = EngineRefs.ssf2("enums.Difficulty") as Class;
					if (ClassicCls)
					{
						if (core.m_match && core.m_match["lives"] !== undefined)
						{
							ClassicCls["lives"] = int(core.m_match["lives"]);
						};
						diffIdx = difficultyIndex(core.m_match ? core.m_match["difficulty"] : null, DiffCls);
						ClassicCls["difficulty"] = diffIdx;
					};
				}
				else if (key == "allstar")
				{
					AllStarCls = EngineRefs.ssf2("menus.AllStarModeMenu") as Class;
					DiffCls = EngineRefs.ssf2("enums.Difficulty") as Class;
					if (AllStarCls)
					{
						if (core.m_match && core.m_match["lives"] !== undefined)
						{
							AllStarCls["lives"] = int(core.m_match["lives"]);
						};
						diffIdx = difficultyIndex(core.m_match ? core.m_match["difficulty"] : null, DiffCls);
						AllStarCls["difficulty"] = diffIdx;
					};
				}
				else if (key == "multiman")
				{
					MultiCls = EngineRefs.ssf2("menus.MultiManMenu") as Class;
					if (MultiCls)
					{
						MultiCls["SELECTED_MULTI_MAN_MODE"] = resolveMultimanModeId(modeId);
					};
				}
				else if (key == "arena")
				{
					ArenaCls = EngineRefs.ssf2("menus.ArenaModeMenu") as Class;
					if (ArenaCls)
					{
						ArenaCls["SELECTED_ARENA_MODE"] = resolveArenaModeId(modeId);
					};
				};
			}
			catch (err:*)
			{
				log("applyModeStatics: " + err);
			};
		}

		/** Arena only accepts soccer|basketball — prefs often leak crystal/multiman ids. */
		internal function resolveArenaModeId(raw:String):String
		{
			var id:String;
			id = String(raw || "").toLowerCase();
			if (id == "soccer" || id == "basketball")
			{
				return (id);
			};
			return ("soccer");
		}

		internal function resolveMultimanModeId(raw:String):String
		{
			var id:String;
			id = String(raw || "").toLowerCase();
			if (id == "man10" || id == "man100" || id == "min3" || id == "endless" || id == "cruel")
			{
				return (id);
			};
			return ("man10");
		}

		private function difficultyIndex(raw:*, DiffCls:Class):int
		{
			var list:Array;
			var i:int;
			var val:int;
			if (raw === undefined || raw === null)
			{
				return (1);
			};
			if (typeof raw == "string" || raw is String)
			{
				try
				{
					if (DiffCls && DiffCls[String(raw)] !== undefined)
					{
						val = int(DiffCls[String(raw)]);
					}
					else
					{
						val = 2;
					};
				}
				catch (e1:*)
				{
					val = 2;
				};
			}
			else
			{
				val = int(raw);
			};
			list = null;
			try
			{
				if (DiffCls)
				{
					list = [DiffCls["EASY"], DiffCls["NORMAL"], DiffCls["HARD"], DiffCls["INSANE"]];
				};
			}
			catch (e2:*)
			{
			};
			if (!list)
			{
				list = [1, 2, 3, 5];
			};
			i = 0;
			while (i < list.length)
			{
				if (int(list[i]) == val)
				{
					return (i);
				};
				i++;
			};
			return (1);
		}

		/** Create GameObj via reset() once, then show once. Guards show→MENU_SHOW reentry. */
		private function ensureCssInitialized(menu:*):Boolean
		{
			var MC:Class;
			if (!menu)
			{
				return (false);
			};
			if (m_cssInitBusy)
			{
				return (menuHasGame(menu));
			};
			m_cssInitBusy = true;
			try
			{
				MC = menuController();
				try
				{
					if (MC)
					{
						MC["CurrentCharacterSelectMenu"] = menu;
					};
				}
				catch (wireErr:*)
				{
				};
				if (!core.m_didCssReset || !menuHasGame(menu))
				{
					try
					{
						menu["reset"]();
						core.m_didCssReset = true;
						log("CSS reset() — GameObj ready=" + isCssReady(menu));
					}
					catch (resetErr:*)
					{
						log("CSS reset failed: " + resetErr);
						return (false);
					};
				};
				if (!core.m_didCssShow)
				{
					try
					{
						if (menu["show"])
						{
							menu["show"]();
						};
						core.m_didCssShow = true;
						log("CSS show() done");
					}
					catch (showErr:*)
					{
						log("CSS show failed: " + showErr);
						return (false);
					};
				};
				return (true);
			}
			finally
			{
				m_cssInitBusy = false;
			};
			return (false);
		}

		internal function menuHasGame(menu:*):Boolean
		{
			try
			{
				return (menu && menu["GameObj"] != null);
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function tryOpenMenuSoft(screen:String):Boolean
		{
			var MC:Class;
			var menu:*;
			var names:Array;
			var i:int;
			var key:String;
			if (core.m_customIntroActive)
			{
				return (false);
			};
			MC = menuController();
			if (!MC)
			{
				return (false);
			};
			key = String(screen || "").toLowerCase();
			names = MENU_ALIASES[key] as Array;
			if (!names)
			{
				names = [key + "Menu", key];
			};
			i = 0;
			while (i < names.length)
			{
				try
				{
					menu = MC[names[i]];
					if (menu && menu.show)
					{
						// Soft dispose (no true) after home is up — safer than boot-time wipe.
						try
						{
							MC["disposeAllMenus"]();
						}
						catch (dispErr:*)
						{
						};
						menu.show();
						log("opened menu " + names[i]);
						core.musicCtl.ensureMenuMusicPlaying();
						return (true);
					};
				}
				catch (err:*)
				{
				};
				i++;
			};
			return (false);
		}

		internal function callUpdateDisplay(menu:*):void
		{
			if (!menu)
			{
				return;
			};
			if (!menuHasGame(menu))
			{
				// Reset only — do not show from update path (avoids MENU_SHOW recursion).
				if (!m_cssInitBusy && (!core.m_didCssReset || !menuHasGame(menu)))
				{
					try
					{
						var MC:Class = menuController();
						if (MC)
						{
							MC["CurrentCharacterSelectMenu"] = menu;
						};
						menu["reset"]();
						core.m_didCssReset = true;
						log("CSS reset() from updateDisplay path");
					}
					catch (resetErr:*)
					{
						log("CSS reset (update path) failed: " + resetErr);
					};
				};
				return;
			};
			try
			{
				if (menu["updateDisplay"])
				{
					menu["updateDisplay"]();
				};
			}
			catch (err:*)
			{
				log("updateDisplay: " + err);
			};
		}

		internal function isCssReady(menu:*):Boolean
		{
			var boxes:*;
			var settings:*;
			if (!menu)
			{
				return (false);
			};
			try
			{
				if (!menu["GameObj"] || !menu["GameObj"]["PlayerSettings"])
				{
					return (false);
				};
				settings = menu["GameObj"]["PlayerSettings"];
				if (!settings || settings["length"] < 1)
				{
					return (false);
				};
				boxes = menu["CharSelectionBoxes"];
				if (!boxes || boxes["length"] < 1)
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

		internal function preparePlayerCostume(charId:String, settings:*, index:int):void
		{
			var MH:Class;
			var MP:Class;
			var RM:Class;
			var costume:*;
			if (!charId || !settings)
			{
				return;
			};
			try
			{
				MH = EngineRefs.ModHost as Class;
				MP = EngineRefs.ModPatches as Class;
				RM = EngineRefs.ResourceManager as Class;
				if (MH && MP)
				{
					MH["door"](MP["PALETTE_LOAD_COSTUME_FILE"], [charId], undefined);
				};
				if (!RM)
				{
					return;
				};
				costume = RM["getCostume"](charId, null, -1);
				if (!costume || (!costume["paletteSwap"] && !costume["base"]))
				{
					settings[index]["costume"] = 0;
					costume = RM["getCostume"](charId, null, 0);
				};
			}
			catch (err:*)
			{
				log("preparePlayerCostume: " + err);
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
