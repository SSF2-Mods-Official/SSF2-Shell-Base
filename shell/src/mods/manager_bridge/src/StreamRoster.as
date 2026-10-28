package
{
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Applies the requested roster and rules onto the CSS before a match starts.
	 */
	internal class StreamRoster
	{
		private var core:Ssf2StreamMod;

		public function StreamRoster(owner:Ssf2StreamMod)
		{
			core = owner;
		}

		/**
		 * Apply launch.json roster onto CSS. Training's updateDisplay() forces P2 random,
		 * so we set players via setPlayer AFTER init and avoid re-calling updateDisplay.
		 */
		internal function applyRosterFromMatch(menu:*):void
		{
			var players:Array;
			var settings:*;
			var i:int;
			var charId:String;
			var training:Boolean;
			var versusLike:Boolean;
			var game:*;
			var slot:*;
			var key:String;
			if (!menu || !core.m_match)
			{
				return;
			};
			players = core.m_match["players"] as Array;
			if (!players || !core.cssCtl.menuHasGame(menu))
			{
				return;
			};
			try
			{
				game = menu["GameObj"];
				settings = game["PlayerSettings"];
				key = core.cssCtl.cssScreenKey();
				training = key == "training_css";
				versusLike = key == "versus_css" || key == "css" || key == "arena";
				i = 0;
				while (i < players.length && i < settings["length"])
				{
					slot = players[i];
					charId = core.cssCtl.playerCharId(slot);
					if (isEmptyRosterSlot(slot, charId))
					{
						clearRosterSlot(menu, settings, i);
						i++;
						continue;
					};
					if (charId.length > 0)
					{
						applyRosterSlot(menu, settings, i, slot, charId, training, versusLike);
					};
					i++;
				};
				refreshRosterNames(menu);
				snapPlayerChipsToGrid(menu);
				scheduleArmCssMatchReady(menu);
				applyRulesFromMatch(game);
				log("applied roster from launch prefs");
			}
			catch (err:*)
			{
				log("applyRoster failed: " + err);
			};
		}

		/** A slot is empty when it says exist:false, or names no character (or "none"). */
		private function isEmptyRosterSlot(slot:*, charId:String):Boolean
		{
			var emptySlot:Boolean;
			emptySlot = false;
			try
			{
				if (slot && !(slot is String) && typeof slot != "string"
					&& slot["exist"] !== undefined && !Boolean(slot["exist"]))
				{
					emptySlot = true;
				};
				if (!charId || charId.length < 1
					|| String(charId).toLowerCase() == "none")
				{
					emptySlot = true;
				};
			}
			catch (emptyErr:*)
			{
			};
			return (emptySlot);
		}

		/** Turns a CSS player slot off (setPlayer null when the menu has it). */
		private function clearRosterSlot(menu:*, settings:*, i:int):void
		{
			try
			{
				settings[i]["exist"] = false;
				settings[i]["name"] = null;
				if (menu["setPlayer"])
				{
					menu["setPlayer"](i + 1, null);
				}
				else
				{
					settings[i]["character"] = null;
				};
			}
			catch (clearErr:*)
			{
				settings[i]["exist"] = false;
			};
		}

		/** Human/CPU, level, team and tag for one slot, then setPlayer, costume and CPU level. */
		private function applyRosterSlot(menu:*, settings:*, i:int, slot:*, charId:String,
			training:Boolean, versusLike:Boolean):void
		{
			var human:Boolean;
			var level:int;
			var team:int;
			var tagName:String;
			settings[i]["exist"] = true;
			human = true;
			level = 1;
			team = 0;
			tagName = "";
			try
			{
				if (slot && !(slot is String) && typeof slot != "string")
				{
					if (slot["human"] !== undefined)
					{
						human = Boolean(slot["human"]);
					};
					if (slot["level"] !== undefined && !isNaN(Number(slot["level"])))
					{
						level = int(slot["level"]);
						if (level < 1)
						{
							level = 1;
						};
						if (level > 9)
						{
							level = 9;
						};
					};
					if (slot["team"] !== undefined && !isNaN(Number(slot["team"])))
					{
						team = int(slot["team"]);
					};
					if (slot["name"] !== undefined && slot["name"] != null)
					{
						tagName = String(slot["name"] || "");
					};
					if (slot["exist"] !== undefined)
					{
						settings[i]["exist"] = Boolean(slot["exist"]);
					};
				}
				else if (training)
				{
					human = i == 0;
				}
				else if (!versusLike)
				{
					human = i == 0;
				};
			}
			catch (flagErr:*)
			{
				human = i == 0 || !training;
			};
			try
			{
				settings[i]["human"] = human;
				settings[i]["level"] = level;
				if (team > 0)
				{
					settings[i]["team"] = team;
				};
				if (human && tagName.length > 0)
				{
					settings[i]["name"] = tagName.substr(0, 10);
				}
				else
				{
					settings[i]["name"] = null;
				};
			}
			catch (setFlagErr:*)
			{
			};
			try
			{
				if (menu["setPlayer"])
				{
					menu["setPlayer"](i + 1, charId, -1);
				}
				else
				{
					settings[i]["character"] = charId;
				};
			}
			catch (setErr:*)
			{
				settings[i]["character"] = charId;
				log("setPlayer failed slot=" + (i + 1) + ": " + setErr);
			};
			core.cssCtl.preparePlayerCostume(charId, settings, i);
			try
			{
				if (!human && menu["setLevel"])
				{
					menu["setLevel"](i + 1, level);
				};
			}
			catch (lvlErr:*)
			{
			};
		}

		/** Name tags on the CSS: the menu's own updateNamesDisplay, else syncCssNameDisplays. */
		private function refreshRosterNames(menu:*):void
		{
			try
			{
				if (menu["updateNamesDisplay"])
				{
					menu["updateNamesDisplay"]();
				}
				else
				{
					syncCssNameDisplays(menu);
				};
			}
			catch (nameUiErr:*)
			{
				syncCssNameDisplays(menu);
			};
		}

		/** Move P1–P4 chips onto grid icons after programmatic setPlayer (stream apply / mode switch). */
		private function snapPlayerChipsToGrid(menu:*):void
		{
			var chips:*;
			var settings:*;
			var hash:Object;
			var i:int;
			var character:String;
			var expansion:int;
			var chip:*;
			var icon:*;
			if (!menu || !core.cssCtl.menuHasGame(menu))
			{
				return;
			};
			try
			{
				chips = menu["PlayerChips"];
				settings = menu["GameObj"]["PlayerSettings"];
				hash = menu["CharMCHash"];
				if (!chips || !settings || !hash)
				{
					return;
				};
				i = 0;
				while (i < settings["length"] && i < chips["length"])
				{
					if (!settings[i]["exist"])
					{
						i++;
						continue;
					};
					character = settings[i]["character"];
					if (!character)
					{
						i++;
						continue;
					};
					expansion = int(settings[i]["expansion"]);
					chip = chips[i];
					icon = hash[character];
					if (!icon)
					{
						icon = hash["c" + character];
					};
					if (character == "xp" || expansion >= 0)
					{
						icon = hash["cxp"];
					};
					if (chip)
					{
						chip["LastHit"] = character;
						if (chip["MC"] && icon)
						{
							chip["MC"].x = icon.x;
							chip["MC"].y = icon.y;
						};
					};
					i++;
				};
				if (menu["updateGameIsReady"])
				{
					menu["updateGameIsReady"]();
				};
			}
			catch (err:*)
			{
				log("snapPlayerChips failed: " + err);
			};
		}

		/** Programmatic CSS picks skip chip drop — finish ReadyDelay and show Ready to Fight. */
		private function armCssMatchReady(menu:*):void
		{
			var delay:*;
			if (!menu)
			{
				return;
			};
			try
			{
				delay = menu["ReadyDelay"];
				if (delay && delay["finish"])
				{
					delay["finish"]();
				};
			}
			catch (rdErr:*)
			{
			};
			snapPlayerChipsToGrid(menu);
			try
			{
				if (menu["updateGameIsReady"])
				{
					menu["updateGameIsReady"]();
				};
			}
			catch (uiErr:*)
			{
			};
		}

		/** CharMCHash can lag setPlayer — re-arm ready after grid icons settle. */
		internal function scheduleArmCssMatchReady(menu:*):void
		{
			if (!menu)
			{
				return;
			};
			setTimeout(function():void
			{
				armCssMatchReady(menu);
			}, 0);
			setTimeout(function():void
			{
				armCssMatchReady(menu);
			}, 50);
			setTimeout(function():void
			{
				armCssMatchReady(menu);
			}, 150);
		}

		private function syncCssNameDisplays(menu:*):void
		{
			var boxes:*;
			var settings:*;
			var i:int;
			var display:*;
			var nameTxt:*;
			var tag:String;
			if (!menu)
			{
				return;
			};
			try
			{
				boxes = menu["CharSelectionBoxes"] || menu["m_charSelectionBoxes"];
				settings = menu["GameObj"] ? menu["GameObj"]["PlayerSettings"] : null;
				if (!boxes || !settings)
				{
					return;
				};
				i = 0;
				while (i < boxes["length"] && i < settings["length"])
				{
					display = boxes[i];
					if (display && display["nameDisplay"] && display["nameDisplay"]["nameTxt"])
					{
						nameTxt = display["nameDisplay"]["nameTxt"];
						tag = settings[i]["name"] != null ? String(settings[i]["name"]) : "";
						nameTxt["text"] = tag.length > 0 ? tag : ("P" + (i + 1));
					};
					i++;
				};
			}
			catch (err:*)
			{
			};
		}

		internal function applyRulesFromMatch(game:*):void
		{
			var ld:*;
			var key:String;
			var modeId:String;
			if (!game || !core.m_match)
			{
				return;
			};
			try
			{
				ld = game["LevelData"];
				if (!ld)
				{
					return;
				};
				key = core.cssCtl.cssScreenKey();
				if (core.m_match["hazards"] !== undefined)
				{
					ld["hazards"] = Boolean(core.m_match["hazards"]);
				};
				if (core.m_match["specialModes"] !== undefined && !isNaN(Number(core.m_match["specialModes"])))
				{
					ld["specialModes"] = uint(core.m_match["specialModes"]);
				};
				if (core.m_match["difficulty"] !== undefined)
				{
					try
					{
						var DiffCls:Class = EngineRefs.ssf2("enums.Difficulty") as Class;
						if (typeof core.m_match["difficulty"] == "string" || core.m_match["difficulty"] is String)
						{
							ld["difficulty"] = DiffCls[String(core.m_match["difficulty"])];
						}
						else
						{
							ld["difficulty"] = int(core.m_match["difficulty"]);
						};
					}
					catch (diffErr:*)
					{
						ld["difficulty"] = int(core.m_match["difficulty"]);
					};
				};
				modeId = String(core.m_match["customModeID"] || "");
				if (!modeId && key != "versus_css" && key != "training_css" && key != "css")
				{
					modeId = String(core.m_match["stage"] || "");
				};
				if (key == "arena")
				{
					modeId = core.cssCtl.resolveArenaModeId(modeId);
				}
				else if (key == "multiman")
				{
					modeId = core.cssCtl.resolveMultimanModeId(modeId);
				};
				if (modeId && (key == "btt" || key == "hrc" || key == "crystal" || key == "multiman" || key == "arena"))
				{
					ld["customModeID"] = modeId;
				};
				if (core.m_match["scoreLimit"] !== undefined && !isNaN(Number(core.m_match["scoreLimit"])))
				{
					ld["scoreLimit"] = int(core.m_match["scoreLimit"]);
				};
				if (core.m_match["lives"] !== undefined && !isNaN(Number(core.m_match["lives"])) && (key == "classic" || key == "allstar"))
				{
					ld["lives"] = int(core.m_match["lives"]);
				};
				// Music override applies to every mode (versus, solo, arena, …).
				if (core.m_match["music"] !== undefined)
				{
					var musicId:String = String(core.m_match["music"] || "");
					ld["musicOverride"] = musicId.length > 0 ? musicId : null;
				};
				if (key != "versus_css")
				{
					return;
				};
				if (core.m_match["usingTime"] !== undefined)
				{
					game["UsingTime"] = Boolean(core.m_match["usingTime"]);
				};
				if (core.m_match["usingLives"] !== undefined)
				{
					game["UsingLives"] = Boolean(core.m_match["usingLives"]);
				};
				if (core.m_match["lives"] !== undefined && !isNaN(Number(core.m_match["lives"])))
				{
					game["Lives"] = int(core.m_match["lives"]);
				};
				if (core.m_match["time"] !== undefined && !isNaN(Number(core.m_match["time"])))
				{
					ld["time"] = int(core.m_match["time"]);
				};
				log("applied rules hazards=" + ld["hazards"] + " time=" + game["UsingTime"] + "/" + ld["time"] + " stock=" + game["UsingLives"] + "/" + game["Lives"]);
			}
			catch (err:*)
			{
				log("applyRules failed: " + err);
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
