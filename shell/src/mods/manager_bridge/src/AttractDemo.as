package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.system.System;
	import flash.utils.getQualifiedClassName;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Live CPU demo segment: stage and character picks, camera phases, fade,
	 * HUD hiding, end of demo, resource unload and abort back to title.
	 */
	internal class AttractDemo
	{
		private var core:AttractMode;
		/** 0–5s wide, 5–10s focus A, 10–15s focus B, 15–20s wide, 20–25s fade white. */
		private static const DEMO_PHASE_LEN:int = 30 * 5;
		private static const DEMO_MAX_FRAMES:int = DEMO_PHASE_LEN * 5;
		private var m_fadeLayer:Sprite;

		/** Base roster only — expansion SWFs (hero, Clone_*, etc.) spike privateMb hard. */
		private static const STOCK_DEMO_CHARS:Array = [
			"mario", "luigi", "peach", "bowser", "yoshi", "wario", "waluigi", "donkeykong",
			"link", "zelda", "sheik", "ganondorf", "samus", "zamus", "kirby", "metaknight",
			"dedede", "bandanadee", "fox", "falco", "krystal", "pikachu", "jigglypuff", "pichu",
			"lucario", "marth", "ike", "roy", "ness", "lucas", "captainfalcon", "pit",
			"palutena", "rob", "gameandwatch", "sonic", "tails", "megaman", "pacman",
			"villager", "olimar", "rosalina", "littlemac", "greninja", "mii", "cloud",
			"bayonetta", "ryu", "ken", "simon", "richter", "snake", "ivysaur", "charizard",
			"squirtle", "blackmage", "isaac", "sora", "lloyd", "ichigo", "naruto", "goku",
			"luffy", "bomberman", "rayman", "chibirobo", "obama", "sandbag", "masterhand"
		];

		public function AttractDemo(owner:AttractMode)
		{
			core = owner;
			m_fadeLayer = null;
		}

		internal function pickDemoStage(StageSetting:Class, RM:*):String
		{
			var stageId:String;
			var recent:String;
			var guard:int;
			stageId = "";
			guard = 0;
			// Demo SWFs are all unloaded after each segment, so there is no previous stage to avoid.
			recent = "";
			while (guard < 8)
			{
				guard++;
				try
				{
					if (StageSetting && StageSetting["getRandomStage"] is Function)
					{
						stageId = String(StageSetting["getRandomStage"](false, false, true) || "");
					};
				}
				catch (e2:*)
				{
					stageId = "";
				};
				if (stageId && stageId != recent)
				{
					return (stageId);
				};
			};
			if (!stageId)
			{
				stageId = "battlefield";
			};
			return (stageId);
		}

		internal function pickDemoChars(Stats:Class, count:int, RM:* = null):Array
		{
			var out:Array;
			var list:Array;
			var unlocked:Array;
			var stockSet:Object;
			var used:Object;
			var i:int;
			var pick:String;
			var id:String;
			var guard:int;
			out = [];
			used = {};
			stockSet = {};
			i = 0;
			while (i < STOCK_DEMO_CHARS.length)
			{
				stockSet[String(STOCK_DEMO_CHARS[i])] = true;
				i++;
			};
			list = [];
			unlocked = null;
			try
			{
				if (Stats && Stats["getCharacterList"] is Function)
				{
					unlocked = Stats["getCharacterList"](true, true) as Array;
				};
			}
			catch (err:*)
			{
				unlocked = null;
			};
			if (unlocked && unlocked.length > 0)
			{
				i = 0;
				while (i < unlocked.length)
				{
					id = String(unlocked[i] || "");
					i++;
					if (id && stockSet[id])
					{
						list.push(id);
					};
				};
			};
			if (list.length < count)
			{
				list = STOCK_DEMO_CHARS.concat();
			};
			i = 0;
			while (i < count)
			{
				guard = 0;
				do
				{
					pick = String(list[int(Math.random() * list.length)]);
					guard++;
				} while (used[pick] && guard < 40);
				used[pick] = true;
				out.push(pick);
				i++;
			};
			return out;
		}

		/** Demo LevelData: stage, seed, 2-minute timed match, no entrances, countdown or music override. */
		internal function setupDemoLevel(game:*, stageId:String, UtilsCls:Class):void
		{
			game["LevelData"]["stage"] = stageId;
			game["LevelData"]["randSeed"] = UtilsCls["randomInteger"](1, 1000);
			UtilsCls["setRandSeed"](game["LevelData"]["randSeed"]);
			UtilsCls["shuffleRandom"]();
			try
			{
				game["LevelData"]["time"] = 2;
				game["LevelData"]["usingTime"] = true;
				game["LevelData"]["usingLives"] = false;
				game["LevelData"]["showEntrances"] = false;
				game["LevelData"]["showCountdown"] = false;
				game["LevelData"]["musicOverride"] = null;
			}
			catch (ldErr:*)
			{
				log("LevelData flags: " + core.describeErr(ldErr));
			};
		}

		/** Four level-9 CPUs with the picked characters. */
		internal function assignDemoPlayers(playerSettings:*, chars:Array):void
		{
			var i:int;
			i = 0;
			while (i < 4 && i < playerSettings["length"])
			{
				playerSettings[i]["exist"] = true;
				playerSettings[i]["character"] = chars[i];
				playerSettings[i]["human"] = false;
				playerSettings[i]["level"] = 9;
				i++;
			};
		}

		/** Queues the stage and every player character, recording each id for the post-demo unload. */
		internal function queueDemoResources(RM:Class, playerSettings:*, stageId:String):void
		{
			var toLoad:Array;
			var i:int;
			toLoad = [stageId];
			core.m_demoLoadedIds = [stageId];
			rememberStageMusicIds(RM, stageId);
			i = 0;
			while (i < playerSettings["length"])
			{
				if (playerSettings[i]["exist"])
				{
					RM["queuePlayerCharacterResource"](playerSettings[i], i);
					try
					{
						if (playerSettings[i]["character"])
						{
							core.m_demoLoadedIds.push(String(playerSettings[i]["character"]));
						};
					}
					catch (chErr:*)
					{
					};
				};
				i++;
			};
			RM["queueResources"](toLoad);
		}

		/** Centers the engine loadingMask on Root while the demo loads. Null when it is not available. */
		internal function showDemoLoadingMask(RM:Class, MainCls:Class):MovieClip
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

		internal function shuffleInts(arr:Array):void
		{
			var i:int;
			var j:int;
			var t:*;
			i = arr.length - 1;
			while (i > 0)
			{
				j = int(Math.random() * (i + 1));
				t = arr[i];
				arr[i] = arr[j];
				arr[j] = t;
				i--;
			};
		}

		internal function tickDemoCamera():void
		{
			var phase:int;
			core.m_demoFrames++;
			if (!core.m_hudHidden && core.m_demoFrames > 2)
			{
				hideMatchHud();
			};
			phase = int(core.m_demoFrames / DEMO_PHASE_LEN);
			if (phase != core.m_demoPhase)
			{
				core.m_demoPhase = phase;
				applyDemoPhase(phase);
			};
			if (phase >= 4)
			{
				updateFade((core.m_demoFrames - DEMO_PHASE_LEN * 4) / Number(DEMO_PHASE_LEN));
			};
			if (core.m_demoFrames >= DEMO_MAX_FRAMES)
			{
				log("demo complete — fade end");
				endLiveDemo(true);
			};
		}

		private function applyDemoPhase(phase:int):void
		{
			var cam:*;
			var sd:*;
			var pid:int;
			var player:*;
			var mc:MovieClip;
			cam = getMatchCam();
			sd = getStageData();
			if (phase == 0)
			{
				camMaxZoomOut();
				log("demo phase wide");
				return;
			};
			if (phase == 1 || phase == 2)
			{
				pid = int(core.m_focusOrder[(phase - 1) % core.m_focusOrder.length]);
				try
				{
					if (cam && cam["removeAllZoomFocus"] is Function)
					{
						cam["removeAllZoomFocus"]();
					};
					player = sd && sd["getPlayerByID"] ? sd["getPlayerByID"](pid) : null;
					mc = player ? player["MC"] as MovieClip : null;
					if (cam && mc && cam["addZoomFocus"] is Function)
					{
						cam["addZoomFocus"](mc, 9999);
						log("demo phase focus P" + pid);
					};
				}
				catch (err:*)
				{
					log("demo focus: " + core.describeErr(err));
				};
				return;
			};
			if (phase == 3)
			{
				try
				{
					if (cam && cam["removeAllZoomFocus"] is Function)
					{
						cam["removeAllZoomFocus"]();
					};
				}
				catch (e2:*)
				{
				};
				camMaxZoomOut();
				log("demo phase zoom out");
				return;
			};
			if (phase == 4)
			{
				log("demo phase fade white");
				ensureFadeLayer();
			};
		}

		private function getStageData():*
		{
			var GC:Class;
			try
			{
				GC = EngineRefs.GameController as Class;
				return GC ? GC["stageData"] : null;
			}
			catch (err:*)
			{
			};
			return null;
		}

		private function getMatchCam():*
		{
			var sd:*;
			sd = getStageData();
			if (!sd)
			{
				return null;
			};
			try
			{
				if (sd["CamRef"])
				{
					return sd["CamRef"];
				};
			}
			catch (e1:*)
			{
			};
			try
			{
				if (sd["CAM"])
				{
					return sd["CAM"];
				};
			}
			catch (e2:*)
			{
			};
			return null;
		}

		internal function camMaxZoomOut():void
		{
			var cam:*;
			cam = getMatchCam();
			if (!cam)
			{
				return;
			};
			try
			{
				if (cam["removeAllZoomFocus"] is Function)
				{
					cam["removeAllZoomFocus"]();
				};
			}
			catch (e1:*)
			{
			};
			try
			{
				if (cam["maxZoomOut"] is Function)
				{
					cam["maxZoomOut"]();
				};
			}
			catch (e2:*)
			{
			};
		}

		internal function hideMatchHud():void
		{
			var sd:*;
			var hud:*;
			sd = getStageData();
			if (!sd)
			{
				return;
			};
			try
			{
				hud = sd["HudRef"];
				if (hud)
				{
					hud.visible = false;
				};
			}
			catch (e1:*)
			{
			};
			try
			{
				if (sd["HUD"])
				{
					sd["HUD"].visible = false;
				};
			}
			catch (e2:*)
			{
			};
			core.m_hudHidden = true;
		}

		private function ensureFadeLayer():void
		{
			var MainCls:Class;
			var root:*;
			var w:Number;
			var h:Number;
			if (m_fadeLayer)
			{
				return;
			};
			try
			{
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? MainCls["Root"] : null;
				w = MainCls ? Number(MainCls["Width"]) : 853;
				h = MainCls ? Number(MainCls["Height"]) : 480;
				if (!root)
				{
					return;
				};
				m_fadeLayer = new Sprite();
				m_fadeLayer.graphics.beginFill(0xFFFFFF, 1);
				m_fadeLayer.graphics.drawRect(0, 0, w, h);
				m_fadeLayer.graphics.endFill();
				m_fadeLayer.alpha = 0;
				m_fadeLayer.mouseEnabled = false;
				root.addChild(m_fadeLayer);
				try
				{
					// Cover gameplay + logo (fade on top).
					root.setChildIndex(m_fadeLayer, root.numChildren - 1);
				}
				catch (zErr:*)
				{
				};
			}
			catch (err:*)
			{
			};
		}

		private function updateFade(t:Number):void
		{
			ensureFadeLayer();
			if (!m_fadeLayer)
			{
				return;
			};
			if (t < 0)
			{
				t = 0;
			};
			if (t > 1)
			{
				t = 1;
			};
			m_fadeLayer.alpha = t;
			// Keep fade above logo every frame in case logo was re-added.
			try
			{
				if (m_fadeLayer.parent)
				{
					m_fadeLayer.parent.setChildIndex(m_fadeLayer, m_fadeLayer.parent.numChildren - 1);
				};
			}
			catch (zErr:*)
			{
			};
		}

		internal function hideFade():void
		{
			if (m_fadeLayer && m_fadeLayer.parent)
			{
				try
				{
					m_fadeLayer.parent.removeChild(m_fadeLayer);
				}
				catch (err:*)
				{
				};
			};
			m_fadeLayer = null;
		}

		internal function endLiveDemo(advance:Boolean, goTitle:Boolean = true):void
		{
			var SQ:*;
			var tid:String;
			// Never call endGame(true) — that fires no-contest / narrator VO.
			try
			{
				SQ = EngineRefs.SoundQueue;
				if (SQ && SQ.instance)
				{
					try
					{
						tid = "";
						if (SQ.instance["getMusicID"] is Function)
						{
							tid = String(SQ.instance["getMusicID"]() || "");
						}
						else if (SQ.instance["MusicID"] != null)
						{
							tid = String(SQ.instance["MusicID"]);
						}
						else if (SQ.instance["currentMusic"] != null)
						{
							tid = String(SQ.instance["currentMusic"]);
						};
						if (tid && core.m_demoLoadedIds.indexOf(tid) < 0)
						{
							core.m_demoLoadedIds.push(tid);
						};
					}
					catch (idErr:*)
					{
					};
					try
					{
						SQ.instance.stopMusic();
					}
					catch (e1:*)
					{
					};
					try
					{
						if (SQ.instance.stopAllSounds is Function)
						{
							SQ.instance.stopAllSounds();
						};
					}
					catch (e2:*)
					{
					};
					try
					{
						if (SQ.instance.stopVoice is Function)
						{
							SQ.instance.stopVoice();
						};
					}
					catch (e3:*)
					{
					};
				};
			}
			catch (sqErr:*)
			{
			};
			abortMatchToTitle(goTitle);
			// finishSegment owns unload when advancing; cancel path unloads below.
			if (advance)
			{
				core.finishSegment();
			}
			else
			{
				unloadDemoResources();
			};
		}

		/** Record stage BGM ids so unloadDemoResources can free them too. */
		internal function rememberStageMusicIds(RM:*, stageId:String):void
		{
			var res:*;
			var music:*;
			var i:int;
			var tid:String;
			if (!RM || !stageId)
			{
				return;
			};
			try
			{
				res = RM["getResourceByID"] is Function ? RM["getResourceByID"](stageId, true) : null;
				if (!res && RM["poolHash"])
				{
					res = RM["poolHash"][stageId];
				};
				if (!res)
				{
					return;
				};
				music = res.getProp("music");
				if (music is String)
				{
					tid = String(music);
					if (tid && core.m_demoLoadedIds.indexOf(tid) < 0)
					{
						core.m_demoLoadedIds.push(tid);
					};
					return;
				};
				if (music is Array)
				{
					i = 0;
					while (i < music.length)
					{
						tid = music[i] is String ? String(music[i])
							: (music[i] && music[i].id != null ? String(music[i].id) : "");
						i++;
						if (tid && core.m_demoLoadedIds.indexOf(tid) < 0)
						{
							core.m_demoLoadedIds.push(tid);
						};
					};
				};
			}
			catch (err:*)
			{
			};
		}

		/**
		 * Attract demos: unload every character/stage/music SWF the demo loaded.
		 * Keeping them for reuse grows privateMb because AIR does not reclaim
		 * ApplicationDomains before the next demo loads new ones.
		 */
		internal function unloadDemoResources():void
		{
			var RM:*;
			var ids:Array;
			var i:int;
			var id:String;
			var res:*;
			var typ:int;
			var freed:int;
			var chars:Array;
			var stages:Array;
			var music:Array;
			ids = core.m_demoLoadedIds;
			core.m_demoLoadedIds = [];
			if (!ids || ids.length < 1)
			{
				ResourceMem.snap("attract:trim", "n=0");
				return;
			};
			try
			{
				RM = EngineRefs.ResourceManager;
			}
			catch (rmErr:*)
			{
				RM = null;
			};
			if (!RM)
			{
				return;
			};
			// Group by kind, deduped by last occurrence; unknown types are left loaded.
			chars = [];
			stages = [];
			music = [];
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				i++;
				if (!id)
				{
					continue;
				};
				res = resolvePoolResource(RM, id);
				typ = res ? int(res["Type"]) : 0;
				if (typ == 1 || typ == 5)
				{
					moveToEnd(chars, id);
				}
				else if (typ == 2 || typ == 6)
				{
					moveToEnd(stages, id);
				}
				else if (typ == 8 || id.indexOf("bgm_") == 0)
				{
					moveToEnd(music, id);
				};
			};
			freed = 0;
			freed += unloadAll(RM, chars);
			freed += unloadAll(RM, stages);
			freed += unloadAll(RM, music);
			forceGc();
			setTimeout(function ():void
			{
				forceGc();
				ResourceMem.snap("attract:gc2");
			}, 250);
			ResourceMem.snap("attract:trim", "n=" + ids.length + " freed=" + freed + " kept=0"
				+ " chars=0 stages=0 music=0");
		}

		private function resolvePoolResource(RM:*, id:String):*
		{
			var res:*;
			if (!RM || !id)
			{
				return (null);
			};
			try
			{
				if (RM["resourcesHash"] && RM["resourcesHash"][id])
				{
					return RM["resourcesHash"][id];
				};
			}
			catch (e1:*)
			{
			};
			try
			{
				if (RM["poolHash"] && RM["poolHash"][id])
				{
					return RM["poolHash"][id];
				};
			}
			catch (e2:*)
			{
			};
			try
			{
				if (RM["getResourceByID"] is Function)
				{
					res = RM["getResourceByID"](id, false);
					return res;
				};
			}
			catch (e3:*)
			{
			};
			return (null);
		}

		private function moveToEnd(list:Array, id:String):void
		{
			var idx:int;
			idx = list.indexOf(id);
			if (idx >= 0)
			{
				list.splice(idx, 1);
			};
			list.push(id);
		}

		/** Unload every id in order. Returns how many were unloaded. */
		private function unloadAll(RM:*, ids:Array):int
		{
			var freed:int;
			var i:int;
			freed = 0;
			i = 0;
			while (i < ids.length)
			{
				if (forceUnloadId(RM, String(ids[i])))
				{
					freed++;
				};
				i++;
			};
			return (freed);
		}

		private function forceUnloadId(RM:*, id:String):Boolean
		{
			var res:*;
			var loader:*;
			if (!id)
			{
				return (false);
			};
			res = resolvePoolResource(RM, id);
			if (!res)
			{
				return (false);
			};
			try
			{
				if (RM["unloadResource"] is Function)
				{
					RM["unloadResource"](res);
				};
			}
			catch (e1:*)
			{
			};
			try
			{
				if (res["Loaded"] && res["unload"] is Function)
				{
					res["unload"]();
				};
			}
			catch (e2:*)
			{
			};
			try
			{
				loader = res["getLoader"] is Function ? res["getLoader"]() : null;
				if (loader && loader["unloadAndStop"] is Function)
				{
					loader["unloadAndStop"](true);
				};
			}
			catch (e3:*)
			{
			};
			return (true);
		}

		private function forceGc():void
		{
			var LC:Class;
			var a:*;
			var b:*;
			try
			{
				LC = EngineRefs.cls("flash.net.LocalConnection") as Class;
				if (LC)
				{
					a = new LC();
					b = new LC();
					try
					{
						a.connect("_ssf2mm_gc_a");
					}
					catch (c1:*)
					{
					};
					try
					{
						b.connect("_ssf2mm_gc_a");
					}
					catch (c2:*)
					{
					};
				};
			}
			catch (lcErr:*)
			{
			};
			try
			{
				System.gc();
			}
			catch (gcErr:*)
			{
			};
		}

		internal function abortMatchToTitle(goTitle:Boolean = true):void
		{
			var GC:Class;
			var MC:Class;
			var MainCls:Class;
			var root:*;
			var SQ:*;
			core.videoCtl.hideLogo();
			hideFade();
			try
			{
				GC = EngineRefs.GameController as Class;
				MC = EngineRefs.MenuController as Class;
				MainCls = EngineRefs.Main as Class;
				// endMatch removes stage/hud/weather/FX layers from Main.Root —
				// destroyStageData alone leaves glass-break / HUD FX stuck.
				if (GC)
				{
					try
					{
						if (GC["stageData"] && GC["stageData"]["CamRef"] && GC["stageData"]["CamRef"]["removeAllZoomFocus"])
						{
							GC["stageData"]["CamRef"]["removeAllZoomFocus"]();
						};
					}
					catch (camErr:*)
					{
					};
					try
					{
						if (GC["stageData"] && GC["stageData"]["deactivateCharacters"])
						{
							GC["stageData"]["deactivateCharacters"]();
						};
					}
					catch (e1:*)
					{
					};
					try
					{
						// Force endMatch cleanup even if flag was already cleared.
						GC["matchStarted"] = true;
						if (GC["endMatch"] is Function)
						{
							GC["endMatch"]();
						};
					}
					catch (emErr:*)
					{
						log("endMatch: " + core.describeErr(emErr));
					};
					try
					{
						GC["destroyStageData"]();
					}
					catch (e2:*)
					{
					};
					try
					{
						GC["isStarted"] = false;
						GC["matchStarted"] = false;
						GC["currentGame"] = null;
					}
					catch (stErr:*)
					{
					};
				};
				try
				{
					SQ = EngineRefs.SoundQueue;
					if (SQ && SQ.instance)
					{
						SQ.instance.stopMusic();
						if (SQ.instance.stopAllSounds is Function)
						{
							SQ.instance.stopAllSounds();
						};
					};
				}
				catch (sqErr:*)
				{
				};
				try
				{
					if (MainCls && MainCls["Root"] && MainCls["Root"].stage)
					{
						MainCls["Root"].stage.frameRate = MainCls["FRAMERATE"] || 30;
					};
				}
				catch (frErr:*)
				{
				};
				// Sweep any leftover match display objects on Root (FX that skipped endMatch).
				scrubRootMatchLeftovers(MainCls ? MainCls["Root"] : null);
				if (MC)
				{
					try
					{
						if (MC["matchResultsMenu"])
						{
							MC["matchResultsMenu"]["removeSelf"]();
							MC["matchResultsMenu"] = null;
						};
					}
					catch (e3:*)
					{
					};
					try
					{
						MC["removeAllMenus"]();
					}
					catch (e4:*)
					{
					};
				};
			}
			catch (err:*)
			{
				log("abortMatch: " + core.describeErr(err));
			};
			if (goTitle)
			{
				core.showTitle();
			};
		}

		/** Remove orphaned stage/HUD/FX clips left on Main.Root after a bad teardown. */
		private function scrubRootMatchLeftovers(root:*):void
		{
			var i:int;
			var ch:*;
			var n:String;
			var kill:Array;
			if (!root || !("numChildren" in root))
			{
				return;
			};
			kill = [];
			i = 0;
			while (i < root.numChildren)
			{
				ch = root.getChildAt(i);
				i++;
				if (!ch || ch == core.m_logoLayer || ch == m_fadeLayer || (core.m_howto && ch == core.m_howto.layer))
				{
					continue;
				};
				try
				{
					n = getQualifiedClassName(ch);
				}
				catch (qnErr:*)
				{
					n = "";
				};
				// Keep menu containers; drop known match layers / effect MCs.
				if (n.indexOf("HudMenu") >= 0 || n.indexOf("hud") >= 0
					|| n.indexOf("Vcam") >= 0 || n.indexOf("StageData") >= 0)
				{
					kill.push(ch);
					continue;
				};
				try
				{
					if (ch.name == "weather" || ch.name == "cutscene" || ch.name == "tags"
						|| ch.name == "stage" || ch.name == "background")
					{
						kill.push(ch);
					};
				}
				catch (nameErr:*)
				{
				};
			};
			i = 0;
			while (i < kill.length)
			{
				try
				{
					if (kill[i] && kill[i].parent)
					{
						kill[i].parent.removeChild(kill[i]);
					};
				}
				catch (rmErr:*)
				{
				};
				i++;
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
