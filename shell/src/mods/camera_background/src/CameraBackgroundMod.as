package
{
	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.MusicOverrideCodec;
	import flash.utils.getQualifiedClassName;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.utils.setTimeout;

	/**
	 * Stage Select Shield: pick another stage's camera backgrounds for the match.
	 * Sets ModHost session flag backgroundStage (engine APPLY_BACKGROUND_STAGE + overlayBG).
	 * After overlay, boots the same PSB-style stage stub as menu_background so scripted
	 * layers (hearts/clouds) update on the overlay clips — match-safe (no SSF2API steal).
	 * Match music is left to My Jukebox.
	 */
	public class CameraBackgroundMod extends Sprite
	{
		private static const MENU_SPACE:String = "menu_space";
		private static const FLAG:String = "backgroundStage";
		private static const FLAG_PICKING:String = "camera_background.picking";
		private static const ONLINE_MODE:int = 4;
		private static const ONLINE_ARENA_MODE:int = 14;
		private var m_host:*;
		private var m_bgStageId:String;
		/** Mod Menu → Stage Select: next Attack confirms camera BG only. */
		private var m_awaitingBgPick:Boolean;
		/** Stage id whose library was used as an overlay last match. */
		internal var m_lastOverlayId:String;
		private var m_overlay:CameraBgOverlay;

		public function CameraBackgroundMod()
		{
			super();
			m_bgStageId = null;
			m_overlay = new CameraBgOverlay(this);
			m_awaitingBgPick = false;
			m_lastOverlayId = null;
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			};
			host.addHook("STAGE_SELECT_GESTURE", onGesture);
			host.addHook("STAGE_SELECT", onStageSelect);
			host.addHook("QUEUE_MATCH_RESOURCES", onQueueResources);
			host.addHook("MATCH_START", onMatchStartStamp);
			host.addHook("SETTINGS_APPLY", onSettingsApply);
			host.addHook("MATCH_END", onMatchRetry);
			host.addHook("MODE_END", onMatchEnd);
			host.addHook("MENU_SHOW", onMenuShow);
			host.patch("applyBackgroundStage", onApplyBackgroundStage);
			host.addEventListener("mod_menu.ready", onMenuReady);
			host.addEventListener("camera_background.beginPick", onBeginPickEvent);
			host.addEventListener("camera_background.cancelPick", onCancelPickEvent);
			host.addEventListener("camera_background.useSpace", onUseSpace);
			registerMenu();
		}

		public function onBootEnd():void
		{
			m_overlay.dispose();
			clearPick();
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("STAGE_SELECT_GESTURE", onGesture);
					m_host["removeHook"]("STAGE_SELECT", onStageSelect);
					m_host["removeHook"]("QUEUE_MATCH_RESOURCES", onQueueResources);
					m_host["removeHook"]("MATCH_START", onMatchStartStamp);
					m_host["removeHook"]("SETTINGS_APPLY", onSettingsApply);
					m_host["removeHook"]("MATCH_END", onMatchRetry);
					m_host["removeHook"]("MODE_END", onMatchEnd);
					m_host["removeHook"]("MENU_SHOW", onMenuShow);
					m_host["unpatch"]("applyBackgroundStage");
					m_host["removeEventListener"]("mod_menu.ready", onMenuReady);
					m_host["removeEventListener"]("camera_background.beginPick", onBeginPickEvent);
					m_host["removeEventListener"]("camera_background.cancelPick", onCancelPickEvent);
					m_host["removeEventListener"]("camera_background.useSpace", onUseSpace);
					m_host.emit("mod_menu.unregister", {"id": "camera_background"});
				}
				catch (err:*)
				{
					trace("[camera_background] onBootEnd failed: " + err);
				};
			};
			m_host = null;
		}

		private function onMenuReady(e:*):void
		{
			registerMenu();
		}

		private function registerMenu():void
		{
			var label:String;
			if (!m_host)
			{
				return;
			};
			label = m_bgStageId ? ("Camera BG: " + stageDisplayName(m_bgStageId)) : "Camera Background (SHIELD)";
			try
			{
				m_host.emit("mod_menu.register", {
					"id": "camera_background",
					"label": label,
					"section": "Essentials",
					"notes": "SHIELD on Stage Select locks another stage as camera BG. From this menu: Attack picks BG only, then pick the real stage normally.",
					"visible": isStageSelectOnscreen,
					"onSelect": beginMenuPick
				});
			}
			catch (err:*)
			{
				trace("[camera_background] registerMenu failed: " + err);
			};
		}

		private function isStageSelectOnscreen():Boolean
		{
			var MC:Class;
			var menu:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				menu = MC ? MC["stageSelectMenu"] : null;
				if (menu && menu["isOnscreen"] is Function)
				{
					return Boolean(menu["isOnscreen"]());
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function onBeginPickEvent(e:*):void
		{
			beginMenuPick();
		}

		private function onCancelPickEvent(e:*):void
		{
			setPicking(false);
		}

		private function reviveStageSelectHand():void
		{
			var MC:*;
			var menu:*;
			var hand:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController");
				menu = MC ? MC["stageSelectMenu"] : null;
				hand = menu ? menu["selectHand"] : null;
				if (hand)
				{
					if (hand["killEvents"] is Function)
					{
						hand["killEvents"]();
					};
					if (hand["makeEvents"] is Function)
					{
						hand["makeEvents"]();
					};
				};
			}
			catch (err:*)
			{
			};
		}

		private function beginMenuPick():void
		{
			setPicking(true);
			notify("Pick a stage to use as background");
			toast("Pick a stage to use as background");
		}

		/**
		 * Engine asks for BG stage id, then calls overlayBG. Return id and arm a
		 * next-frame boot so Vcam.BGs already include the overlay sprites.
		 */
		private function onApplyBackgroundStage(sd:*):String
		{
			var id:String;
			id = resolveBgStageId();
			if (id == MENU_SPACE)
			{
				if (paintMenuSpace())
				{
					hideMatchBgs(sd);
				};
				return (null);
			};
			if (id && sd)
			{
				m_overlay.arm(sd);
			};
			return id && id.length > 0 ? id : null;
		}

		/** Space BG on the stage select bar. */
		public function useMenuSpace():void
		{
			setPicking(false);
			m_bgStageId = MENU_SPACE;
			setFlag(MENU_SPACE);
			notify("BG: Space");
			EngineRefs.gameLog("[camera_background] space bg");
		}

		private function onUseSpace(e:*):void
		{
			useMenuSpace();
		}

		private function paintMenuSpace():Boolean
		{
			var GC:*;
			var RM:*;
			var Main:*;
			var bg:MovieClip;
			var space:MovieClip;
			try
			{
				GC = EngineRefs.GameController;
				bg = GC ? GC["background"] as MovieClip : null;
				if (!bg || bg.getChildByName("menuSpaceBg"))
				{
					return (bg != null && bg.getChildByName("menuSpaceBg") != null);
				};
				RM = EngineRefs.ResourceManager;
				space = RM.getLibraryMC("menu_bg_space") as MovieClip;
				if (!space)
				{
					return (false);
				};
				space.name = "menuSpaceBg";
				space.mouseEnabled = false;
				space.mouseChildren = false;
				Main = EngineRefs.Main;
				space.x = Number(Main["Width"]) * 0.5;
				space.y = Number(Main["Height"]) * 0.5;
				bg.addChildAt(space, 0);
				EngineRefs.gameLog("[camera_background] space bg");
				return (true);
			}
			catch (err:*)
			{
				trace("[camera_background] paintMenuSpace failed: " + err);
			};
			return (false);
		}

		private function hideMatchBgs(sd:*):void
		{
			var bgs:*;
			var i:int;
			var entry:*;
			try
			{
				bgs = sd && sd["CamRef"] ? sd["CamRef"]["BGs"] : null;
			}
			catch (err:*)
			{
				return;
			};
			i = 0;
			while (bgs && i < bgs.length)
			{
				entry = bgs[i];
				if (entry && entry.sprite)
				{
					entry.sprite.visible = false;
				};
				i++;
			};
		}

		private function onGesture(ctx:Object):void
		{
			var chords:Array;
			var stageId:String;
			if (!ctx)
			{
				return;
			};
			chords = (ctx.chords as Array) || [];
			if (chordHas(chords, "SPECIAL") && !chordHas(chords, "GRAB") && !chordHas(chords, "SHIELD") && !chordHas(chords, "TAUNT"))
			{
				if (m_bgStageId)
				{
					clearPick();
					notify("");
					playSfx("menu_back");
					ctx.cancel = true;
					ctx.consume = true;
				};
				return;
			};
			if (!chordHas(chords, "SHIELD") || chordHas(chords, "TAUNT"))
			{
				return;
			};
			stageId = resolveStageId(ctx);
			if (!stageId)
			{
				return;
			};
			ctx.cancel = true;
			ctx.consume = true;
			if (m_bgStageId)
			{
				clearPick();
				notify("");
				playSfx("menu_back");
				return;
			};
			if (stageId == "random")
			{
				stageId = pickRandomStage();
			};
			if (!stageId || !stageHasFile(stageId))
			{
				playSfx("menu_error");
				return;
			};
			m_bgStageId = stageId;
			setFlag(stageId);
			emitMenuPreview(stageId);
			notify("BG: " + stageDisplayName(stageId));
			playSfx("menu_selectstage");
			registerMenu();
		}

		private function onStageSelect(ctx:Object):void
		{
			var stageId:String;
			if (!ctx)
			{
				return;
			};
			if (!m_awaitingBgPick)
			{
				writeHostBg(ctx["game"]);
				return;
			};
			stageId = resolveStageId(ctx);
			if (!stageId && ctx["stageId"])
			{
				stageId = String(ctx["stageId"]);
			};
			if (stageId && stageId != "random" && stageHasFile(stageId))
			{
				setPicking(false);
				m_bgStageId = stageId;
				setFlag(stageId);
				emitMenuPreview(stageId);
				notify("BG: " + stageDisplayName(stageId));
				playSfx("menu_selectstage");
				registerMenu();
				ctx.cancel = true;
				ctx.consume = true;
				reviveStageSelectHand();
				toast("Camera BG locked — now pick the match stage");
			};
		}

		private function onQueueResources(ctx:Object):void
		{
			var queue:*;
			var matchStage:String;
			var bgId:String;
			if (!ctx)
			{
				return;
			};
			queue = ctx["queue"];
			if (!(queue is Function))
			{
				return;
			};
			adoptNetBg(ctx["game"]);
			bgId = resolveBgStageId();
			matchStage = resolveMatchStageId(ctx);
			if (matchStage && (matchStage == bgId || matchStage == m_lastOverlayId))
			{
				unloadLoadedStage(matchStage);
				m_lastOverlayId = null;
			};
			if (bgId && matchStage && matchStage == bgId)
			{
				try
				{
					if (m_host)
					{
						m_host.setSessionFlag(FLAG, null);
					};
				}
				catch (flagErr:*)
				{
					trace("[camera_background] onQueueResources failed: " + flagErr);
				};
				m_bgStageId = null;
				trace("[camera_background] skip overlay — BG is match stage " + matchStage);
			}
			else if (bgId == MENU_SPACE)
			{
				EngineRefs.gameLog("[camera_background] space bg");
			}
			else if (bgId)
			{
				trace("[camera_background] queue BG stage " + bgId);
				queue(bgId);
			};
		}

		/** Drop a loaded stage SWF so the match queue reloads a clean copy. */
		private function unloadLoadedStage(stageId:String):void
		{
			var RM:*;
			var res:*;
			if (!stageId)
			{
				return;
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM.getResourceByID(stageId, true);
				if (res && res.Loaded && RM.unloadResource is Function)
				{
					trace("[camera_background] unload dirty stage " + stageId);
					RM.unloadResource(res);
				};
			}
			catch (err:*)
			{
				trace("[camera_background] unload failed: " + err);
			};
		}

		private function resolveMatchStageId(ctx:Object):String
		{
			var id:String;
			var game:*;
			if (!ctx)
			{
				return null;
			};
			id = ctx["stageId"] as String;
			if (id && id != "random")
			{
				return id;
			};
			try
			{
				game = ctx["game"];
				if (game && game["LevelData"] && game["LevelData"]["stage"])
				{
					return String(game["LevelData"]["stage"]);
				};
			}
			catch (err:*)
			{
			};
			return null;
		}

		/** Retry starts another match. Keep backgroundStage so the camera stage stays. */
		private function onMatchRetry(ctx:Object):void
		{
			m_overlay.dispose();
			var id:String = resolveBgStageId();
			EngineRefs.gameLog("[camera_background] match retry keep id=" + (id && id.length > 0 ? id : "none"));
		}

		/** endMatch fires this on a retry too. The flag stays until the events menu. */
		private function onMatchEnd(ctx:Object):void
		{
			m_overlay.dispose();
		}

		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var q:String;
			menu = ctx ? ctx["menu"] : null;
			q = menu ? getQualifiedClassName(menu) : "";
			if (q.indexOf("ExpansionEventMenu") < 0 && q.indexOf("MainMenu") < 0)
			{
				return;
			};
			if (!m_bgStageId && !resolveBgStageId())
			{
				return;
			};
			EngineRefs.gameLog("[camera_background] menu clear " + q);
			clearPick();
		}

		/** After MatchSettings export, stamp camera BG id into replay JSON. */
		private function onMatchStartStamp(ctx:Object):void
		{
			setTimeout(function ():void
			{
				stampReplayBackgroundStage();
			}, 0);
		}

		private function stampReplayBackgroundStage():void
		{
			var GC:*;
			var sd:*;
			var rd:*;
			var ms:Object;
			var id:String;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				sd = GC ? GC["stageData"] : null;
				if (!sd || sd["ReplayMode"])
				{
					return;
				};
				rd = sd["ReplayDataObj"];
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
				id = m_bgStageId;
				if (!id && m_host)
				{
					try
					{
						id = m_host.getSessionFlag(FLAG, null) as String;
					}
					catch (flagErr:*)
					{
						id = null;
					};
				};
				if (id && id.length > 0)
				{
					ms[FLAG] = id;
				};
			}
			catch (err:*)
			{
				trace("[camera_background] stampReplayBackgroundStage failed: " + err);
			};
		}

		/**
		 * Replay import: restore backgroundStage from data / session flag.
		 * Never index GameSettings for unknown keys — it is sealed (#1069).
		 */
		private function onSettingsApply(ctx:Object):void
		{
			var data:Object;
			var id:String;
			var flagged:*;
			if (!ctx)
			{
				return;
			};
			data = ctx["data"] as Object;
			id = "";
			if (data && String(data["musicOverride"]).indexOf("|") >= 0)
			{
				applyNetBg(MusicOverrideCodec.decode(data["musicOverride"]).bg);
				return;
			};
			// Only read extras from the raw import object (not sealed GameSettings).
			if (data && data[FLAG] != null && String(data[FLAG]) != "null")
			{
				id = String(data[FLAG]);
			};
			if (!id && m_host)
			{
				try
				{
					flagged = m_host.getSessionFlag(FLAG, null);
					if (flagged != null && String(flagged).length > 0 && String(flagged) != "null")
					{
						id = String(flagged);
					};
				}
				catch (flagErr:*)
				{
				};
			};
			if (!id)
			{
				return;
			};
			if (stageHasFile(id))
			{
				m_bgStageId = id;
				setFlag(id);
				try
				{
					var RM:* = EngineRefs.ssf2("util.ResourceManager");
					if (RM && RM.queueResources is Function)
					{
						RM.queueResources([id]);
					};
				}
				catch (qErr:*)
				{
				};
				trace("[camera_background] SETTINGS_APPLY restore BG " + id);
				return;
			};
			clearPick();
			try
			{
				if (data)
				{
					data[FLAG] = null;
				};
			}
			catch (dataErr:*)
			{
			};
			trace("[camera_background] SETTINGS_APPLY dropped missing backgroundStage " + id);
		}

		/** Online host: add the locked bg to musicOverride, the one host string every player receives. */
		private function writeHostBg(game:*):void
		{
			var ld:*;
			var bg:String;
			try
			{
				if (!game || !(int(game["GameMode"]) == ONLINE_MODE || int(game["GameMode"]) == ONLINE_ARENA_MODE))
				{
					return;
				};
				ld = game["LevelData"];
				bg = resolveBgStageId();
				if (!ld || !bg)
				{
					return;
				};
				ld["musicOverride"] = MusicOverrideCodec.withBg(ld["musicOverride"], bg);
				trace("[camera_background] net bg host=" + bg + " value=" + ld["musicOverride"]);
			}
			catch (err:*)
			{
				trace("[camera_background] net bg host failed: " + err);
			};
		}

		/** Live match: the host bg rides in musicOverride as track|bg=stageId. */
		private function adoptNetBg(game:*):void
		{
			var raw:String;
			try
			{
				if (!game || !game["LevelData"])
				{
					return;
				};
				raw = String(game["LevelData"]["musicOverride"] || "");
			}
			catch (err:*)
			{
				return;
			};
			if (raw.indexOf("|") < 0)
			{
				return;
			};
			applyNetBg(MusicOverrideCodec.decode(raw).bg);
		}

		/** Host's bg from musicOverride replaces this player's own pick; a missing stage means none. */
		private function applyNetBg(id:String):void
		{
			var applied:Boolean = false;
			if (id == MENU_SPACE)
			{
				m_bgStageId = id;
				setFlag(id);
				applied = true;
			}
			else if (id && stageHasFile(id))
			{
				m_bgStageId = id;
				setFlag(id);
				try
				{
					var RM:* = EngineRefs.ssf2("util.ResourceManager");
					if (RM && RM.queueResources is Function)
					{
						RM.queueResources([id]);
					};
				}
				catch (qErr:*)
				{
					trace("[camera_background] net bg queue failed: " + qErr);
				};
				applied = true;
			}
			else
			{
				clearPick();
			};
			trace("[camera_background] net bg from=musicOverride id=" + id + " applied=" + applied);
		}

		/** Prefer live pick, else session flag (replay sanitize sets the flag). */
		internal function resolveBgStageId():String
		{
			var id:String;
			var flagged:*;
			id = m_bgStageId;
			if (id && id.length > 0)
			{
				return (id);
			};
			if (m_host)
			{
				try
				{
					flagged = m_host.getSessionFlag(FLAG, null);
					if (flagged != null && String(flagged).length > 0 && String(flagged) != "null")
					{
						id = String(flagged);
						m_bgStageId = id;
						return (id);
					};
				}
				catch (err:*)
				{
				};
			};
			return (null);
		}

		private function setFlag(id:String):void
		{
			if (!m_host)
			{
				return;
			};
			try
			{
				m_host.setSessionFlag(FLAG, id);
			}
			catch (err:*)
			{
				trace("[camera_background] setFlag failed: " + err);
			};
		}

		private function setPicking(on:Boolean):void
		{
			m_awaitingBgPick = on;
			if (!m_host)
			{
				return;
			};
			try
			{
				m_host.setSessionFlag(FLAG_PICKING, on ? true : null);
			}
			catch (err:*)
			{
			};
		}

		private function emitMenuPreview(stageId:String):void
		{
			if (!m_host)
			{
				return;
			};
			try
			{
				if (stageId && stageId.length > 0)
				{
					m_host.emit("menu_background.preview", {"stageId": stageId});
				}
				else
				{
					m_host.emit("menu_background.clearPreview", {});
				};
			}
			catch (err:*)
			{
			};
		}

		private function clearPick():void
		{
			m_bgStageId = null;
			setPicking(false);
			if (m_host)
			{
				try
				{
					m_host.setSessionFlag(FLAG, null);
				}
				catch (err:*)
				{
				};
			};
			emitMenuPreview(null);
		}

		private function stageHasFile(stageId:String):Boolean
		{
			var RM:*;
			if (stageId == MENU_SPACE)
			{
				return (true);
			};
			var res:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM.getResourceByID(stageId);
				return Boolean(res && res.FileName);
			}
			catch (err:*)
			{
			};
			return false;
		}

		private function pickRandomStage():String
		{
			try
			{
				var SS:* = EngineRefs.ssf2("engine.StageSetting");
				if (SS && SS.getRandomStage is Function)
				{
					return String(SS.getRandomStage(false, false, true));
				};
			}
			catch (err:*)
			{
			};
			return null;
		}

		private function stageDisplayName(stageId:String):String
		{
			var RM:*;
			var mappings:*;
			var meta:Object;
			var stageMap:Object;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				mappings = RM.getResourceByID("mappings");
				meta = mappings && mappings.getProp("metadata") ? mappings.getProp("metadata") : null;
				stageMap = meta && meta.stage ? meta.stage : null;
				if (stageMap && stageMap[stageId] && stageMap[stageId].name)
				{
					return String(stageMap[stageId].name);
				};
			}
			catch (err:*)
			{
			};
			return stageId;
		}

		private function resolveStageId(ctx:Object):String
		{
			var stageId:String;
			stageId = ctx.stageId as String;
			if (!stageId && ctx.hoverTarget && m_host && m_host.safeReadProp)
			{
				stageId = m_host.safeReadProp(ctx.hoverTarget, ["StageID", "stageID", "m_stageID", "id"]) as String;
			};
			if (!stageId && ctx.hoverTarget)
			{
				try
				{
					stageId = String(ctx.hoverTarget.StageID);
				}
				catch (err:*)
				{
				};
			};
			return stageId;
		}

		private function chordHas(chords:Array, name:String):Boolean
		{
			return chords && chords.indexOf(name) >= 0;
		}

		private function notify(msg:String):void
		{
			var menu:*;
			try
			{
				var MC:* = EngineRefs.ssf2("controllers.MenuController");
				menu = MC && MC.stageSelectMenu ? MC.stageSelectMenu.SubMenu : null;
				if (menu && menu.stage_sample && menu.stage_sample.stage_txt)
				{
					menu.stage_sample.stage_txt.text = msg || "";
				};
			}
			catch (err:*)
			{
			};
		}

		/** MultiplayerManager toast (top of screen). */
		private function toast(msg:String):void
		{
			var MM:* = EngineRefs.MultiplayerManager;
			try
			{
				if (MM && MM["notify"] is Function)
				{
					MM["notify"](msg);
				};
			}
			catch (err:*)
			{
				trace("[camera_background] toast failed: " + err);
			};
		}

		private function playSfx(id:String):void
		{
			try
			{
				var SQ:* = EngineRefs.ssf2("audio.SoundQueue");
				if (SQ && SQ.instance && SQ.instance.playSoundEffect)
				{
					SQ.instance.playSoundEffect(id);
				};
			}
			catch (err:*)
			{
			};
		}
	}
}


