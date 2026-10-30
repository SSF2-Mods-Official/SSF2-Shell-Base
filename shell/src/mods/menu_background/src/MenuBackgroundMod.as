package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.utils.getQualifiedClassName;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/**
	 * Use a stage's camera backgrounds as the menu backdrop.
	 * Manage Mods dropdown + Save and Apply (polls the settings in mod.json live).
	 * Stage Select TAUNT+SHIELD picks the hovered stage (like Camera BG's Shield).
	 *
	 * PSB-style: live stage-library clips are tracked and disposed before a match
	 * (MenuStageStub.dispose / setMenuStageStub(null)), then re-painted when menus return.
	 */
	public class MenuBackgroundMod extends Sprite
	{
		private static const INFO_REL:String = "data/ssf2mm/menu_background/mod.json";
		private static const SAVE_KEY:String = "menu_background_stage_id";
		/** mod.json stamp the saved pick was made against; a newer mod.json (Manager edit) wins. */
		private static const SAVE_STAMP_KEY:String = "menu_background_info_stamp";
		private var m_host:*;
		private var m_stageId:String;
		/** Temporary SSS backdrop while a camera BG is queued — not written to SAVE_KEY. */
		private var m_previewId:String;
		private var m_lastInfoStamp:String;
		private var m_pollAccum:int;
		private var m_armed:Boolean;
		private var m_pendingContainer:*;
		private var m_pendingMenu:*;
		/** Live camera BG clips currently parented under menus (PSB _cameraBackgrounds). */
		private var m_liveClips:Array;
		/** True while a match is loading/running — do not re-instantiate stage library clips. */
		private var m_matchSuspended:Boolean;
		/** PSB-style stage class host (initialize/update for hearts/clouds/etc). */
		private var m_stub:MenuBgStageStub;
		/** Mod Menu pick flow: Attack locks menu BG; B returns. */
		private var m_awaitingPick:Boolean;
		/** Last unknown backdrop id already written to the log. */
		private var m_skipLogged:String;
		/** One delayed paint after a stage file loads before its clips exist. */
		private var m_paintRetry:Function;

		public function MenuBackgroundMod()
		{
			super();
			m_stageId = null;
			m_previewId = null;
			m_lastInfoStamp = "";
			m_pollAccum = 0;
			m_armed = false;
			m_liveClips = [];
			m_matchSuspended = false;
			m_stub = null;
			m_awaitingPick = false;
			m_skipLogged = "";
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			};
			loadSettings();
			host.addHook("STAGE_SELECT_GESTURE", onGesture);
			host.addHook("STAGE_SELECT", onStageSelectPick);
			host.addHook("MENU_SHOW", onMenuShow);
			host.addHook("ATTRACT_MEDIA", onAttractMedia);
			host.addHook("QUEUE_MATCH_RESOURCES", onQueueMatchResources);
			host.addHook("MODE_START", onModeStart);
			host.addHook("MATCH_END", onMatchEnd);
			host.addHook("MODE_END", onMatchEnd);
			host.patch("applyMenuBackground", onApplyMenuBackground);
			host.addEventListener("mod_menu.ready", onMenuReady);
			host.addEventListener("menu_background.preview", onPreviewEvent);
			host.addEventListener("menu_background.clearPreview", onClearPreviewEvent);
			armStage();
			registerMenu();
		}

		public function onBootEnd():void
		{
			disposeLiveClips();
			cancelPaintRetry();
			disarmStage();
			disarmPickPoll();
			m_awaitingPick = false;
			m_previewId = null;
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("STAGE_SELECT_GESTURE", onGesture);
					m_host["removeHook"]("STAGE_SELECT", onStageSelectPick);
					m_host["removeHook"]("MENU_SHOW", onMenuShow);
					m_host["removeHook"]("ATTRACT_MEDIA", onAttractMedia);
					m_host["removeHook"]("QUEUE_MATCH_RESOURCES", onQueueMatchResources);
					m_host["removeHook"]("MODE_START", onModeStart);
					m_host["removeHook"]("MATCH_END", onMatchEnd);
					m_host["removeHook"]("MODE_END", onMatchEnd);
					m_host["unpatch"]("applyMenuBackground");
					m_host["removeEventListener"]("mod_menu.ready", onMenuReady);
					m_host["removeEventListener"]("menu_background.preview", onPreviewEvent);
					m_host["removeEventListener"]("menu_background.clearPreview", onClearPreviewEvent);
					m_host.emit("mod_menu.unregister", {"id": "menu_background"});
				}
				catch (err:*)
				{
				};
			};
			m_host = null;
		}

		/**
		 * Earliest match teardown — resources are about to load for StageData.
		 * Mirrors PSB disposing MenuStageStub before the match stage is built.
		 * If the match stage is the same SWF we used for menu BG, unload+requeue it
		 * so StageData gets a clean ApplicationDomain (avoids MovingPlatform #1009).
		 */
		private function onQueueMatchResources(ctx:Object):void
		{
			var matchStage:String;
			var RM:*;
			var res:*;
			suspendForMatch();
			matchStage = resolveMatchStageId(ctx);
			if (!matchStage)
			{
				return;
			};
			// Always force a clean stage SWF when it was already Loaded (menu BG,
			// jukebox preview, etc.). multimode Resource.load() no-ops when
			// Loaded=true and skips validateResource → MovingPlatform #1009.
			// Stage is already in the match queue — only unload (do not requeue).
			try
			{
				RM = EngineRefs.ResourceManager;
				res = RM.getResourceByID(matchStage);
				if (!res || !res.Loaded)
				{
					return;
				};
				if (RM.unloadResource is Function)
				{
					RM.unloadResource(res);
				};
				// unloadResource only works if the stage is in resources[]; force otherwise.
				if (res.Loaded && res.unload is Function)
				{
					res.unload();
				};
			}
			catch (err:*)
			{
				trace("[menu_background] match stage unload failed: " + err);
			};
		}

		/** Same-frame as startMatch after stage MC create; StageData is next frame. */
		private function onModeStart(ctx:Object):void
		{
			suspendForMatch();
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

		private function onMatchEnd(ctx:Object):void
		{
			var hadPreview:Boolean;
			hadPreview = Boolean(m_previewId);
			m_previewId = null;
			armStage();
			if (!m_matchSuspended)
			{
				if (hadPreview)
				{
					reapplyLiveMenus();
				};
				return;
			};
			m_matchSuspended = false;
			// Menus are usually recreated after match; MENU_SHOW will paint. Nudge any survivors.
			if (m_stageId || hadPreview)
			{
				reapplyLiveMenus();
			};
		}

		/** Attract demo / How to Play / intro — fully drop menu stage BG, restore after. */
		private function onAttractMedia(ctx:Object):void
		{
			var active:Boolean;
			if (!ctx)
			{
				return;
			};
			active = Boolean(ctx["active"]);
			if (active)
			{
				suspendForMatch();
				return;
			};
			m_matchSuspended = false;
			armStage();
			if (m_stageId)
			{
				reapplyLiveMenus();
			};
		}

		private function suspendForMatch():void
		{
			m_matchSuspended = true;
			disarmStage();
			disposeLiveClips();
			m_pendingContainer = null;
			m_pendingMenu = null;
		}

		/**
		 * PSB MenuStageStub.dispose: stop timelines, detach clips, drop refs.
		 * Keeps the stage SWF loaded; only releases live library instances held by menus.
		 */
		private function disposeLiveClips():void
		{
			var Utils:*;
			var i:int;
			var clip:MovieClip;
			if (m_stub)
			{
				try
				{
					m_stub.dispose();
				}
				catch (stubErr:*)
				{
				};
				m_stub = null;
			};
			try
			{
				Utils = EngineRefs.Utils;
			}
			catch (uErr:*)
			{
				Utils = null;
			};
			i = 0;
			while (m_liveClips && i < m_liveClips.length)
			{
				clip = m_liveClips[i] as MovieClip;
				i++;
				if (!clip)
				{
					continue;
				};
				try
				{
					if (Utils)
					{
						Utils.recursiveMovieClipPlay(clip, false, false);
					};
				}
				catch (stopErr:*)
				{
				};
				try
				{
					if (clip.parent)
					{
						clip.parent.removeChild(clip);
					};
				}
				catch (remErr:*)
				{
				};
			};
			m_liveClips = [];
			// Also scrub any BackgroundContainers we still know about (orphaned after disposeAllMenus).
			clearPendingContainer(Utils);
			scrubKnownMenuContainers(Utils);
		}

		private function clearPendingContainer(Utils:*):void
		{
			var child:*;
			if (!m_pendingContainer)
			{
				return;
			};
			try
			{
				while (m_pendingContainer.numChildren > 0)
				{
					child = m_pendingContainer.getChildAt(0);
					if (Utils && child is MovieClip)
					{
						try
						{
							Utils.recursiveMovieClipPlay(child as MovieClip, false, false);
						}
						catch (e:*)
						{
						};
					};
					m_pendingContainer.removeChildAt(0);
				};
			}
			catch (err:*)
			{
			};
			m_pendingContainer = null;
		}

		private function scrubKnownMenuContainers(Utils:*):void
		{
			var MC:*;
			var names:Array;
			var i:int;
			var menu:*;
			var container:*;
			var child:*;
			var MH:*;
			try
			{
				MH = EngineRefs.ModHost;
				if (MH && MH["getSessionFlag"] is Function
					&& Boolean(MH["getSessionFlag"]("music_player.overlay", false)))
				{
					return;
				};
			}
			catch (overlayErr:*)
			{
			};
			try
			{
				MC = EngineRefs.MenuController;
			}
			catch (err:*)
			{
				return;
			};
			if (!MC)
			{
				return;
			};
			// Clear any leftover stage clips from every menu container.
			names = ["mainMenu", "titleMenu", "vsMenu", "soloMenu", "optionsMenu", "stageSelectMenu", "vaultMenu", "onlineMenu", "groupMenu", "rulesMenu"];
			i = 0;
			while (i < names.length)
			{
				try
				{
					menu = MC[names[i]];
				}
				catch (nameErr:*)
				{
					menu = null;
				};
				i++;
				if (!menu)
				{
					continue;
				};
				container = null;
				try
				{
					container = menu["BackgroundContainer"];
				}
				catch (pubErr:*)
				{
					container = null;
				};
				if (!container && m_host && m_host.safeReadProp)
				{
					container = m_host.safeReadProp(menu, ["BackgroundContainer", "m_backgroundContainer"]);
				};
				if (!container)
				{
					continue;
				};
				try
				{
					while (container.numChildren > 0)
					{
						child = container.getChildAt(0);
						if (Utils && child is MovieClip)
						{
							try
							{
								Utils.recursiveMovieClipPlay(child as MovieClip, false, false);
							}
							catch (stopErr:*)
							{
							};
						};
						container.removeChildAt(0);
					};
				}
				catch (clearErr:*)
				{
				};
			};
		}

		/** Skip stage BG during disclaimer / intro movies — paint once real menus show. */
		private function isIntroOrDisclaimer(menu:*):Boolean
		{
			var name:String;
			if (!menu)
			{
				return (true);
			};
			try
			{
				name = getQualifiedClassName(menu);
			}
			catch (err:*)
			{
				name = "";
			};
			if (!name)
			{
				return (true);
			};
			return (name.indexOf("Disclaimer") >= 0
				|| name.indexOf("IntroMenu") >= 0
				|| name.indexOf("Intro2Menu") >= 0
				|| name.indexOf("Intro3Menu") >= 0);
		}

		/** Re-paint when a real menu shows (not during boot intros). */
		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var container:*;
			var paintId:String;
			if (!ctx || m_matchSuspended)
			{
				return;
			};
			armStage();
			menu = ctx["menu"];
			paintId = paintIdFor(menu);
			if (!paintId || isIntroOrDisclaimer(menu))
			{
				return;
			};
			container = null;
			try
			{
				container = menu["BackgroundContainer"];
			}
			catch (err:*)
			{
				container = null;
			};
			if (!container && m_host && m_host.safeReadProp)
			{
				container = m_host.safeReadProp(menu, ["BackgroundContainer", "m_backgroundContainer"]);
			};
			if (container)
			{
				ensureAndPaint(paintId, container, "space");
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
			if (m_awaitingPick && chordHas(chords, "SPECIAL")
				&& !chordHas(chords, "GRAB") && !chordHas(chords, "SHIELD") && !chordHas(chords, "TAUNT"))
			{
				ctx.cancel = true;
				ctx.consume = true;
				cancelMenuPick();
				return;
			};
			if (!chordHas(chords, "TAUNT") || !chordHas(chords, "SHIELD"))
			{
				return;
			};
			stageId = resolveStageId(ctx);
			if (!stageId || stageId == "random")
			{
				return;
			};
			ctx.cancel = true;
			ctx.consume = true;
			setStageId(stageId, true);
			notify("Menu BG: " + stageDisplayName(stageId));
			playSfx("menu_selectstage");
			registerMenu();
		}

		private function onStageSelectPick(ctx:Object):void
		{
			var stageId:String;
			if (!ctx || !m_awaitingPick)
			{
				return;
			};
			stageId = resolveStageId(ctx);
			if (!stageId && ctx["stageId"])
			{
				stageId = String(ctx["stageId"]);
			};
			if (!stageId || stageId == "random")
			{
				return;
			};
			m_awaitingPick = false;
			setStageId(stageId, true);
			notify("Menu BG: " + stageDisplayName(stageId));
			playSfx("menu_selectstage");
			registerMenu();
			ctx.cancel = true;
			ctx.consume = true;
			leaveStageSelectToModMenu();
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
			label = m_stageId
				? ("Menu BG: " + stageDisplayName(m_stageId))
				: "Menu Background";
			try
			{
				m_host.emit("mod_menu.register", {
					"id": "menu_background",
					"label": label,
					"section": "Essentials",
					"notes": "Select to open Stage Select. Attack locks that stage as the menu backdrop; B returns to Mod Menu. TAUNT+SHIELD also works on Stage Select.",
					"onSelect": beginMenuPick
				});
			}
			catch (err:*)
			{
			};
		}

		private function beginMenuPick():void
		{
			var MC:*;
			var menu:*;
			m_awaitingPick = true;
			notify("Pick a stage to use as background");
			try
			{
				var MM:* = EngineRefs.MultiplayerManager;
				if (MM && MM["notify"])
				{
					MM["notify"]("Pick a stage to use as background");
				};
			}
			catch (nErr:*)
			{
			};
			try
			{
				MC = EngineRefs.MenuController;
				menu = MC ? MC["stageSelectMenu"] : null;
				if (menu && menu["show"] is Function)
				{
					menu["show"]();
				};
			}
			catch (err:*)
			{
			};
			armPickPoll();
		}

		private function cancelMenuPick():void
		{
			if (!m_awaitingPick)
			{
				return;
			};
			m_awaitingPick = false;
			disarmPickPoll();
			playSfx("menu_back");
			leaveStageSelectToModMenu();
		}

		private function leaveStageSelectToModMenu():void
		{
			var MC:*;
			var menu:*;
			disarmPickPoll();
			try
			{
				MC = EngineRefs.MenuController;
				menu = MC ? MC["stageSelectMenu"] : null;
				if (menu && menu["isOnscreen"] is Function && menu["isOnscreen"]()
					&& menu["removeSelf"] is Function)
				{
					menu["removeSelf"]();
				};
			}
			catch (err:*)
			{
			};
			try
			{
				if (m_host)
				{
					m_host.emit("mod_menu.open", {});
				};
			}
			catch (openErr:*)
			{
			};
		}

		private function armPickPoll():void
		{
			var st:*;
			disarmPickPoll();
			st = gameStage();
			if (!st)
			{
				return;
			};
			st.addEventListener(Event.ENTER_FRAME, onPickPoll, false, 0, true);
		}

		private function disarmPickPoll():void
		{
			var st:*;
			st = gameStage();
			if (st)
			{
				try
				{
					st.removeEventListener(Event.ENTER_FRAME, onPickPoll);
				}
				catch (err:*)
				{
				};
			};
		}

		private function onPickPoll(e:Event):void
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			if (!m_awaitingPick)
			{
				disarmPickPoll();
				return;
			};
			try
			{
				SD = EngineRefs.SaveData as Class;
				list = SD ? SD["Controllers"] : null;
				if (!list)
				{
					return;
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
						&& !Boolean(c["IsDown"](c["_BUTTON2"]))
						&& !Boolean(c["IsDown"](c["_GRAB"]))
						&& !Boolean(c["IsDown"](c["_SHIELD"])))
					{
						cancelMenuPick();
						return;
					};
				};
			}
			catch (err:*)
			{
			};
		}

		private function onApplyMenuBackground(menu:*, id:*, container:*):void
		{
			var paintId:String;
			if (m_matchSuspended || isIntroOrDisclaimer(menu))
			{
				defaultMenuBg(id, container);
				return;
			};
			paintId = paintIdFor(menu);
			if (!paintId || !container)
			{
				defaultMenuBg(id, container);
				return;
			};
			m_pendingMenu = menu;
			m_pendingContainer = container;
			ensureAndPaint(paintId, container, id);
		}

		private function ensureAndPaint(stageId:String, container:*, fallbackId:*):void
		{
			var RM:*;
			var known:Boolean;
			var mustLoad:Boolean;
			if (m_matchSuspended)
			{
				defaultMenuBg(fallbackId, container);
				return;
			};
			known = false;
			try
			{
				RM = EngineRefs.ResourceManager;
				if (RM && RM.getResourceByID(stageId, true))
				{
					known = true;
				}
				else if (RM && RM.getResourceByID(stageId, false))
				{
					known = true;
				};
			}
			catch (knownErr:*)
			{
				known = true;
			};
			if (!known)
			{
				if (m_skipLogged != stageId)
				{
					m_skipLogged = stageId;
					EngineRefs.gameLog("[menu_background] skip unknown stage " + stageId);
				};
				if (m_stageId == stageId)
				{
					m_stageId = null;
					if (m_host)
					{
						try
						{
							m_host.saveExtSet(SAVE_KEY, null);
						}
						catch (clearErr:*)
						{
						};
					};
				};
				defaultMenuBg(fallbackId, container);
				return;
			};
			if (!m_host || !m_host.ensureResourcesLoaded)
			{
				defaultMenuBg(fallbackId, container);
				return;
			};
			mustLoad = true;
			try
			{
				RM = EngineRefs.ResourceManager;
				mustLoad = !RM || !RM.getResourceByID(stageId, true);
			}
			catch (loadedErr:*)
			{
				mustLoad = true;
			};
			m_host.ensureResourcesLoaded([stageId], function():void
			{
				finishPaint(stageId, container, fallbackId, mustLoad);
			}, function():void
			{
				if (!m_matchSuspended)
				{
					defaultMenuBg(fallbackId, container);
				};
			});
		}

		/** A stage file can finish loading a frame before its camera clips exist. */
		private function finishPaint(stageId:String, container:*, fallbackId:*, allowRetry:Boolean):void
		{
			var painted:Boolean;
			if (m_matchSuspended)
			{
				return;
			};
			painted = paintStageBackgrounds(stageId, container);
			if (allowRetry)
			{
				schedulePaintRetry(stageId, container, fallbackId);
				return;
			};
			if (!painted)
			{
				defaultMenuBg(fallbackId, container);
			};
		}

		private function schedulePaintRetry(stageId:String, container:*, fallbackId:*):void
		{
			var root:*;
			cancelPaintRetry();
			root = EngineRefs.Main ? EngineRefs.Main["Root"] : null;
			if (!root)
			{
				defaultMenuBg(fallbackId, container);
				return;
			};
			m_paintRetry = function(e:Event):void
			{
				cancelPaintRetry();
				EngineRefs.gameLog("[menu_background] repaint id=" + stageId);
				finishPaint(stageId, container, fallbackId, false);
			};
			root.addEventListener(Event.ENTER_FRAME, m_paintRetry, false, 0, true);
		}

		private function cancelPaintRetry():void
		{
			var root:*;
			if (m_paintRetry == null)
			{
				return;
			};
			root = EngineRefs.Main ? EngineRefs.Main["Root"] : null;
			if (root)
			{
				root.removeEventListener(Event.ENTER_FRAME, m_paintRetry);
			};
			m_paintRetry = null;
		}

		private function paintStageBackgrounds(stageId:String, container:*):Boolean
		{
			var RM:*;
			var Utils:*;
			var res:*;
			var cam:Object;
			var arr:Array;
			var i:int;
			var entry:Object;
			var linkage:String;
			var clip:MovieClip;
			var child:*;
			if (!container || m_matchSuspended)
			{
				return false;
			};
			try
			{
				Utils = EngineRefs.Utils;
			}
			catch (uErr:*)
			{
				Utils = null;
			};
			// Replace previous live clips (PSB setMenuStageStub(null) before rebuild).
			disposeLiveClips();
			try
			{
				while (container.numChildren > 0)
				{
					child = container.getChildAt(0);
					if (Utils && child is MovieClip)
					{
						try
						{
							Utils.recursiveMovieClipPlay(child as MovieClip, false, false);
						}
						catch (stopErr:*)
						{
						};
					};
					container.removeChildAt(0);
				};
			}
			catch (clearErr:*)
			{
			};
			try
			{
				RM = EngineRefs.ResourceManager;
				res = RM.getResourceByID(stageId, true);
				if (!res)
				{
					return false;
				};
				cam = res.getProp("camera") as Object;
				arr = cam && cam.backgrounds is Array ? cam.backgrounds as Array : null;
				if (!arr || arr.length < 1)
				{
					return false;
				};
				m_liveClips = [];
				i = 0;
				while (i < arr.length)
				{
					entry = arr[i];
					i++;
					if (!entry)
					{
						continue;
					};
					linkage = String(entry.linkage_id || entry.linkage || "");
					if (!linkage)
					{
						continue;
					};
					clip = RM.getLibraryMC(linkage) as MovieClip;
					if (!clip)
					{
						continue;
					};
					// PSB: foreground camera layers stay hidden on menus; do not offset —
					// submenu is already centered, clips are authored around (0,0).
					if (entry.foreground)
					{
						clip.visible = false;
					};
					container.addChild(clip);
					m_liveClips.push(clip);
					if (Utils)
					{
						try
						{
							Utils.recursiveMovieClipPlay(clip, true, true);
						}
						catch (playErr:*)
						{
						};
					};
				};
				m_pendingContainer = container;
				if (m_liveClips.length < 1)
				{
					return false;
				};
				bootStageStub(stageId, res, container);
				return true;
			}
			catch (err:*)
			{
				trace("[menu_background] paint failed: " + err);
			};
			return false;
		}

		/**
		 * PSB: after camera BG clips are on the menu, run the stage class so scripted
		 * layers (hearts/clouds/weather) attach to getCameraBackgrounds()[0].mc.
		 */
		private function bootStageStub(stageId:String, res:*, container:*):void
		{
			var stageClass:Class;
			var bgList:Array;
			var i:int;
			var weather:MovieClip;
			if (!res || m_matchSuspended)
			{
				return;
			};
			try
			{
				stageClass = res.getProp("stage") as Class;
			}
			catch (propErr:*)
			{
				stageClass = null;
			};
			if (!stageClass)
			{
				return;
			};
			bgList = [];
			i = 0;
			while (i < m_liveClips.length)
			{
				bgList.push({"mc": m_liveClips[i]});
				i++;
			};
			try
			{
				if (m_stub)
				{
					m_stub.dispose();
					m_stub = null;
				};
				m_stub = new MenuBgStageStub();
				m_stub.setCameraBackgrounds(bgList);
				m_stub.initStageClass(stageClass, stageId);
				weather = m_stub.getWeatherMC();
				if (weather && container)
				{
					layoutMenuWeather(weather, container);
					container.addChild(weather);
					if (m_liveClips.indexOf(weather) < 0)
					{
						m_liveClips.push(weather);
					};
				};
			}
			catch (stubErr:*)
			{
				trace("[menu_background] stage stub failed: " + stubErr);
				try
				{
					if (m_stub)
					{
						m_stub.dispose();
					};
				}
				catch (e:*)
				{
				};
				m_stub = null;
			};
		}

		/**
		 * Menu submenu origin is screen-center; RainWeather spawns in stage space (0..W).
		 * Offset weather so rain covers the full viewport instead of only the right half.
		 */
		private function layoutMenuWeather(weather:MovieClip, container:*):void
		{
			var MainCls:*;
			var w:Number;
			var h:Number;
			if (!weather)
			{
				return;
			};
			w = 853;
			h = 480;
			try
			{
				MainCls = EngineRefs.Main;
				if (MainCls)
				{
					w = Number(MainCls["Width"]) || w;
					h = Number(MainCls["Height"]) || h;
				};
			}
			catch (err:*)
			{
			};
			weather.x = -w * 0.5;
			weather.y = -h * 0.5;
			weather.visible = true;
		}

		private function defaultMenuBg(id:*, container:*):void
		{
			var RM:*;
			var clip:*;
			if (!container || !id)
			{
				return;
			};
			try
			{
				RM = EngineRefs.ResourceManager;
				clip = RM.getLibraryMC("menu_bg_" + id);
				if (clip)
				{
					container.addChild(clip);
				};
			}
			catch (err:*)
			{
			};
		}

		private function setStageId(stageId:String, persist:Boolean):void
		{
			m_stageId = stageId && stageId.length > 0 ? stageId : null;
			if (persist && m_host)
			{
				try
				{
					m_host.saveExtSet(SAVE_KEY, m_stageId);
				}
				catch (err:*)
				{
				};
			};
			reapplyLiveMenus();
		}

		private function onPreviewEvent(e:*):void
		{
			var data:Object;
			var id:String;
			data = (e && e.data) ? e.data : e;
			id = (data && data.stageId) ? String(data.stageId) : null;
			if (id == "null")
			{
				id = null;
			};
			m_previewId = id && id.length > 0 ? id : null;
			reapplyLiveMenus();
		}

		private function onClearPreviewEvent(e:*):void
		{
			if (!m_previewId)
			{
				return;
			};
			m_previewId = null;
			reapplyLiveMenus();
		}

		private function isStageSelectMenu(menu:*):Boolean
		{
			var name:String;
			var MC:*;
			if (!menu)
			{
				return (false);
			};
			try
			{
				MC = EngineRefs.MenuController;
				if (MC && MC["stageSelectMenu"] == menu)
				{
					return (true);
				};
			}
			catch (mcErr:*)
			{
			};
			try
			{
				name = getQualifiedClassName(menu);
				if (name && name.indexOf("StageSelectMenu") >= 0)
				{
					return (true);
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function paintIdFor(menu:*):String
		{
			if (m_previewId && isStageSelectMenu(menu))
			{
				return (m_previewId);
			};
			return (m_stageId);
		}

		private function reapplyLiveMenus():void
		{
			var MC:*;
			var names:Array;
			var i:int;
			var menu:*;
			var container:*;
			var MH:*;
			var paintId:String;
			if (m_matchSuspended)
			{
				return;
			};
			try
			{
				MH = EngineRefs.ModHost;
				if (MH && MH["getSessionFlag"] is Function
					&& Boolean(MH["getSessionFlag"]("music_player.overlay", false)))
				{
					return;
				};
			}
			catch (overlayErr:*)
			{
			};
			try
			{
				MC = EngineRefs.MenuController;
				if (!MC)
				{
					return;
				};
				// Paint onscreen menus only (title / main / vault / solo / …) — not intros.
				names = ["mainMenu", "titleMenu", "vsMenu", "soloMenu", "optionsMenu", "stageSelectMenu", "vaultMenu", "onlineMenu", "groupMenu", "rulesMenu", "dataMenu"];
				i = 0;
				while (i < names.length)
				{
					try
					{
						menu = MC[names[i]];
					}
					catch (nameErr:*)
					{
						menu = null;
					};
					i++;
					if (!menu || isIntroOrDisclaimer(menu))
					{
						continue;
					};
					try
					{
						if (menu["isOnscreen"] is Function && !menu["isOnscreen"]())
						{
							continue;
						};
					}
					catch (screenErr:*)
					{
					};
					container = null;
					try
					{
						container = menu["BackgroundContainer"];
					}
					catch (pubErr:*)
					{
						container = null;
					};
					if (!container && m_host && m_host.safeReadProp)
					{
						container = m_host.safeReadProp(menu, ["BackgroundContainer", "m_backgroundContainer"]);
					};
					if (!container)
					{
						continue;
					};
					paintId = paintIdFor(menu);
					if (paintId)
					{
						ensureAndPaint(paintId, container, "space");
					}
					else
					{
						try
						{
							while (container.numChildren > 0)
							{
								container.removeChildAt(0);
							};
						}
						catch (e:*)
						{
						};
						defaultMenuBg("space", container);
					};
				};
			}
			catch (err:*)
			{
			};
		}

		private function loadSettings():void
		{
			var fromInfo:String;
			var saved:String;
			var savedStamp:String;
			fromInfo = readInfoStageId();
			if (m_host)
			{
				try
				{
					saved = m_host.saveExtGet(SAVE_KEY, null) as String;
					savedStamp = m_host.saveExtGet(SAVE_STAMP_KEY, null) as String;
				}
				catch (err:*)
				{
				};
			};
			if (saved && savedStamp == m_lastInfoStamp)
			{
				m_stageId = saved;
			}
			else
			{
				m_stageId = fromInfo || saved;
				saveInfoStamp();
			};
			trace("[menu_background] loadSettings stage=" + m_stageId + " info=" + fromInfo + " saved=" + saved + " stampMatch=" + (savedStamp == m_lastInfoStamp));
		}

		private function saveInfoStamp():void
		{
			if (!m_host || !m_lastInfoStamp)
			{
				return;
			};
			try
			{
				m_host.saveExtSet(SAVE_STAMP_KEY, m_lastInfoStamp);
			}
			catch (err:*)
			{
			};
		}

		private function readInfoStageId():String
		{
			var file:File;
			var data:Object;
			var settings:Array;
			var i:int;
			var row:Object;
			var stamp:String;
			try
			{
				file = File.applicationDirectory.resolvePath(INFO_REL);
				if (!file || !file.exists)
				{
					return null;
				};
				stamp = String(file.modificationDate ? file.modificationDate.getTime() : 0) + ":" + file.size;
				m_lastInfoStamp = stamp;
				data = JsonFile.read(file);
				settings = data && data["settings"] is Array ? data["settings"] as Array : null;
				i = 0;
				while (settings && i < settings.length)
				{
					row = settings[i];
					i++;
					if (!row || String(row["id"] || "") != "stageId")
					{
						continue;
					};
					return String(row["value"] || "") || null;
				};
			}
			catch (err:*)
			{
			};
			return null;
		}

		private function pollInfo():void
		{
			var file:File;
			var stamp:String;
			var next:String;
			try
			{
				file = File.applicationDirectory.resolvePath(INFO_REL);
				if (!file || !file.exists)
				{
					return;
				};
				stamp = String(file.modificationDate ? file.modificationDate.getTime() : 0) + ":" + file.size;
				if (stamp == m_lastInfoStamp)
				{
					return;
				};
				next = readInfoStageId();
				saveInfoStamp();
				if (next != m_stageId)
				{
					m_stageId = next;
					if (m_host)
					{
						try
						{
							m_host.saveExtSet(SAVE_KEY, m_stageId);
						}
						catch (saveErr:*)
						{
						};
					};
					reapplyLiveMenus();
				};
			}
			catch (err:*)
			{
			};
		}

		private function armStage():void
		{
			var st:*;
			if (m_armed)
			{
				return;
			};
			st = gameStage();
			if (!st)
			{
				return;
			};
			st.addEventListener(Event.ENTER_FRAME, onFrame, false, 0, true);
			m_armed = true;
		}

		private function disarmStage():void
		{
			var st:*;
			if (!m_armed)
			{
				return;
			};
			st = gameStage();
			if (st)
			{
				try
				{
					st.removeEventListener(Event.ENTER_FRAME, onFrame);
				}
				catch (err:*)
				{
				};
			};
			m_armed = false;
		}

		private function onFrame(e:Event):void
		{
			m_pollAccum++;
			if (m_pollAccum < 30)
			{
				return;
			};
			m_pollAccum = 0;
			pollInfo();
		}

		private function gameStage():*
		{
			var MainCls:Class;
			var root:*;
			try
			{
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? (MainCls["Root"] || MainCls["root"]) : null;
				if (root && root.stage)
				{
					return root.stage;
				};
			}
			catch (err:*)
			{
			};
			return this.stage;
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

		private function stageDisplayName(stageId:String):String
		{
			var RM:*;
			var mappings:*;
			var meta:Object;
			var stageMap:Object;
			try
			{
				RM = EngineRefs.ResourceManager;
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

		private function chordHas(chords:Array, name:String):Boolean
		{
			return chords && chords.indexOf(name) >= 0;
		}

		private function notify(msg:String):void
		{
			var menu:*;
			try
			{
				var MC:* = EngineRefs.MenuController;
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

		private function playSfx(id:String):void
		{
			try
			{
				var SQ:* = EngineRefs.SoundQueue;
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
