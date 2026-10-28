package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.media.SoundMixer;
	import flash.media.Video;
	import flash.net.NetStream;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.VideoOverlay;

	/**
	 * Boot intro: stock intros, custom FLV intros, skip-to-title, vault redirect
	 * and the post-intro destination. Runs before the title screen.
	 */
	internal class StreamBootIntro
	{
		private var core:Ssf2StreamMod;
		private var m_introProbeLeft:int;
		private var m_customIntroSkipArmed:Boolean;
		/** After custom/skip intro: "vault" | "title" | "". */
		private var m_postIntroMenu:String;

		public function StreamBootIntro(owner:Ssf2StreamMod)
		{
			core = owner;
			m_customIntroSkipArmed = false;
			m_postIntroMenu = "";
		}

		internal function wantDeepLinkBoot():Boolean
		{
			if (core.cssCtl.wantImmediateMatch())
			{
				return (true);
			};
			if (core.m_screen && core.m_screen.length > 0 && core.m_screen != "home")
			{
				return (true);
			};
			return (false);
		}

		private function wantVaultIntroBoot():Boolean
		{
			return (String(core.m_screen || "").toLowerCase() == "vault"
				&& String(core.m_vaultAction || "intro").toLowerCase() == "intro");
		}

		internal function wantVaultCostumesBoot():Boolean
		{
			return (String(core.m_screen || "").toLowerCase() == "vault"
				&& String(core.m_vaultAction || "").toLowerCase() == "costumes");
		}

		private function wantVaultManageBoot():Boolean
		{
			return (String(core.m_screen || "").toLowerCase() == "vault"
				&& String(core.m_vaultAction || "").toLowerCase() == "manage");
		}

		/** Opens the manage-costumes character grid on the vault menu. */
		internal function openManageCostumesGrid():void
		{
			setTimeout(function():void
			{
				var MC:Class;
				var menu:*;
				try
				{
					MC = core.cssCtl.menuController();
					menu = MC ? MC["vaultMenu"] : null;
					if (menu && menu.showManageCostumesGrid != null)
					{
						menu.showManageCostumesGrid();
						holdCostumeGrid(menu);
						log("manage costumes grid");
						log("costume grid hold");
					}
					else
					{
						log("manage costumes grid missing");
					};
				}
				catch (err:*)
				{
					log("manage costumes grid: " + err);
				};
			}, 200);
		}

		/** Calls palette.holdCostumeGrid so the icon under the cursor is not confirmed. */
		private function holdCostumeGrid(menu:*):void
		{
			var ModHostCls:Class;
			var ran:*;
			var sub:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			var grid:DisplayObject;
			try
			{
				ModHostCls = EngineRefs.ModHost as Class;
				if (ModHostCls)
				{
					ran = ModHostCls["door"]("palette.holdCostumeGrid", [menu], false);
					if (ran == true)
					{
						return;
					};
				};
			}
			catch (doorErr:*)
			{
			};
			if (!menu)
			{
				return;
			};
			try
			{
				menu.resetControlsLetGo(true);
			}
			catch (letGoErr:*)
			{
			};
			sub = menu.SubMenu as DisplayObjectContainer;
			if (!sub)
			{
				return;
			};
			grid = null;
			i = 0;
			while (i < sub.numChildren)
			{
				child = sub.getChildAt(i);
				if (child.x == -295 && child.y == -120)
				{
					grid = child;
				};
				i++;
			};
			if (!grid)
			{
				return;
			};
			MovieClip(grid).mouseEnabled = false;
			MovieClip(grid).mouseChildren = false;
			setTimeout(function():void
			{
				MovieClip(grid).mouseEnabled = true;
				MovieClip(grid).mouseChildren = true;
				try
				{
					menu.resetControlsLetGo(true);
				}
				catch (armErr:*)
				{
				};
			}, 400);
		}

		private function wantVaultCacheWarmBoot():Boolean
		{
			return (String(core.m_screen || "").toLowerCase() == "vault"
				&& String(core.m_vaultAction || "").toLowerCase() == "cachewarm");
		}

		private function beginPaletteCacheWarm():void
		{
			setTimeout(function():void
			{
				var ModHostCls:Class;
				var options:Object;
				try
				{
					ModHostCls = EngineRefs.ModHost as Class;
					options = { "exitWhenDone": true };
					if (core.m_vaultCacheChar)
					{
						options["pendingChars"] = [core.m_vaultCacheChar];
					};
					ModHostCls["door"]("palette.startPaletteMakerPreload", [options], undefined);
					log("palette cache warm char=" + (core.m_vaultCacheChar || "all"));
				}
				catch (err:*)
				{
					log("palette cache warm failed: " + err);
				};
			}, 800);
		}

		private function configureIntroDestination():void
		{
			if (wantVaultIntroBoot())
			{
				m_postIntroMenu = "vault";
				core.m_redirectVaultToTitle = false;
			}
			else
			{
				m_postIntroMenu = "title";
				core.m_redirectVaultToTitle = ((!core.m_screen || core.m_screen == "home") && !core.cssCtl.wantImmediateMatch());
			};
		}

		internal function showPostIntroDestination():void
		{
			if (core.m_customIntroActive)
			{
				return;
			};
			if (m_postIntroMenu == "vault")
			{
				core.cssCtl.tryOpenMenuSoft("vault");
				return;
			};
			showTitleAfterBootSkip();
		}

		/** Skip disclaimer/intro when deep-linking or bootIntro=skip; optionally play a chosen intro. */
		internal function onBeforeInitialMenu(ctx:Object):void
		{
			try
			{
				routeInitialMenu(ctx);
			}
			catch (err:*)
			{
				core.logStepError("BEFORE_INITIAL_MENU", err);
			};
		}

		/** Cancels the stock intro when the launch skips it, deep-links, or plays its own intro. */
		private function routeInitialMenu(ctx:Object):void
		{
			var intro:String;
			if (!ctx)
			{
				return;
			};
			intro = String(core.m_bootIntro || "default").toLowerCase();
			configureIntroDestination();
			if (wantVaultCacheWarmBoot())
			{
				ctx["cancel"] = true;
				beginPaletteCacheWarm();
				log("BEFORE_INITIAL_MENU vault cache warm");
				return;
			};
			if (wantVaultManageBoot())
			{
				ctx["cancel"] = true;
				log("BEFORE_INITIAL_MENU vault manage costumes");
				return;
			};
			if (wantVaultCostumesBoot())
			{
				ctx["cancel"] = true;
				log("BEFORE_INITIAL_MENU vault costumes — skip intro");
				return;
			};
			if (wantDeepLinkBoot() && !wantVaultIntroBoot())
			{
				ctx["cancel"] = true;
				if (!core.m_screen || core.m_screen == "home")
				{
					showPostIntroDestination();
				};
				log("BEFORE_INITIAL_MENU skipped (deepLink=" + wantDeepLinkBoot() + " intro=" + intro + ")");
				return;
			};
			if (intro == "skip" || intro == "none")
			{
				ctx["cancel"] = true;
				showPostIntroDestination();
				log("BEFORE_INITIAL_MENU skip intro → " + m_postIntroMenu);
				return;
			};
			if (startBootIntroPlayback(intro, true))
			{
				ctx["cancel"] = true;
			}
			else if (wantVaultIntroBoot())
			{
				core.m_intro3ToVault = true;
			};
		}

		/** Play bootIntro pref; returns true if disclaimer chain was cancelled. */
		internal function startBootIntroPlayback(intro:String, fromHook:Boolean=false):Boolean
		{
			try
			{
				return (playIntroByName(intro, fromHook));
			}
			catch (err:*)
			{
				core.logStepError("startBootIntroPlayback intro=" + intro, err);
			};
			return (false);
		}

		/** skip | default | intro1/v8 | intro2/v9 | intro3/beta | custom:*. True when this started an intro. */
		private function playIntroByName(intro:String, fromHook:Boolean):Boolean
		{
			intro = String(intro || core.m_bootIntro || "default").toLowerCase();
			configureIntroDestination();
			if (intro == "skip" || intro == "none" || intro == "default")
			{
				if (!fromHook && intro != "default")
				{
					showPostIntroDestination();
				};
				if (intro == "default" && wantVaultIntroBoot())
				{
					core.m_intro3ToVault = true;
					if (!fromHook)
					{
						playBootIntro3();
						return (true);
					};
					return (false);
				};
				if (!fromHook && intro == "default")
				{
					return (false);
				};
				return (false);
			};
			if (intro == "intro1" || intro == "v8")
			{
				playBootIntro("ssf2intro_v8", "IntroMenu", "introMenu");
				return (true);
			};
			if (intro == "intro2" || intro == "v9")
			{
				playBootIntro("ssf2intro_v9", "Intro2Menu", "intro2Menu");
				return (true);
			};
			if (intro == "intro3" || intro == "beta")
			{
				playBootIntro3();
				return (true);
			};
			if (intro.indexOf("custom:") == 0)
			{
				playCustomBootIntro();
				return (true);
			};
			return (false);
		}

		/** Stop menu BGM and hide menus before Stream-driven intro playback. */
		private function prepareIntroPresentation():void
		{
			var MC:Class;
			core.musicCtl.stopPreviewMusic();
			try
			{
				MC = core.cssCtl.menuController();
				if (MC && MC["disposeAllMenus"])
				{
					MC["disposeAllMenus"]();
				};
			}
			catch (prepErr:*)
			{
			};
		}

		private function playCustomBootIntro():void
		{
			var path:String;
			var file:File;
			var MainCls:Class;
			var root:*;
			var st:Stage;
			var w:Number;
			var h:Number;
			configureIntroDestination();
			path = core.m_bootIntroPath || "";
			if (path.length < 1)
			{
				log("custom intro: no bootIntroPath");
				showPostIntroDestination();
				return;
			};
			try
			{
				file = introFile(path);
				if (!file.exists)
				{
					log("custom intro missing: " + path);
					showPostIntroDestination();
					return;
				};
			}
			catch (fe:*)
			{
				log("custom intro path error: " + fe);
				showPostIntroDestination();
				return;
			};
			prepareIntroPresentation();
			finishCustomBootIntro();
			try
			{
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? MainCls["Root"] : null;
				if (!root)
				{
					log("custom intro: Main.Root missing");
					showPostIntroDestination();
					return;
				};
				st = root.stage as Stage;
				w = st ? st.stageWidth : 850;
				h = st ? st.stageHeight : 480;
				if (w < 64)
				{
					w = 850;
				};
				if (h < 64)
				{
					h = 480;
				};
				core.m_customIntroActive = true;
				if (st && tryPlayCustomIntroNet(file, st, w, h))
				{
					return;
				};
				core.m_customIntroActive = false;
				log("custom intro: NetStream play failed");
				showPostIntroDestination();
			}
			catch (err:*)
			{
				log("playCustomBootIntro: " + err);
				core.m_customIntroActive = false;
				finishCustomBootIntro();
				showPostIntroDestination();
			};
		}

		/** Relative boot paths are not valid in new File() and throw Error #2004. */
		private function introFile(path:String):File
		{
			var native:String = (path || "").split("\\").join("/");
			if (native.indexOf("file:") == 0 || native.indexOf("app:") == 0 || native.indexOf("app-storage:") == 0)
			{
				return new File(native);
			};
			if (native.length > 2 && native.charAt(1) == ":")
			{
				return new File(native);
			};
			if (native.indexOf("//") == 0)
			{
				return new File("\\\\" + native.substr(2).split("/").join("\\"));
			};
			while (native.length > 0 && native.charAt(0) == "/")
			{
				native = native.substr(1);
			};
			return File.applicationDirectory.resolvePath(native);
		}

		/**
		 * Copy MP4 into applicationStorageDirectory then NetStream.play(url).
		 * Playing paths outside the AIR app dir often StreamNotFound; appendBytes never starts.
		 */
		private function tryPlayCustomIntroNet(file:File, st:Stage, w:Number, h:Number):Boolean
		{
			var MainCls:Class;
			var gameW:Number;
			var gameH:Number;
			var ext:String;
			var overlay:VideoOverlay;
			var localCopy:File;
			MainCls = EngineRefs.Main as Class;
			gameW = MainCls ? Number(MainCls["Width"]) || w : w;
			gameH = MainCls ? Number(MainCls["Height"]) || h : h;
			if (gameW < 64)
			{
				gameW = w;
			};
			if (gameH < 64)
			{
				gameH = h;
			};
			// Prefer .flv (Flash-safe); keep .mp4 when the source is mp4.
			ext = file.extension ? String(file.extension).toLowerCase() : "";
			overlay = new VideoOverlay(log);
			core.m_introOverlay = overlay;
			if (!overlay.play(st, file, w, h, onCustomIntroDone, {
				"copyName": ext == "mp4" ? "boot_intro.mp4" : "boot_intro.flv",
				"pillarWidth": gameW,
				"pillarHeight": gameH,
				"watchdogMs": 3000,
				"stopRequiresStart": true,
				"onInput": onCustomIntroInput,
				"onStatus": onCustomIntroStatus,
				"onStart": onCustomIntroStart
			}))
			{
				if (core.m_introOverlay == overlay)
				{
					core.m_introOverlay = null;
				};
				return (false);
			};
			armCustomIntroControllerSkip(st);
			try
			{
				localCopy = overlay.localCopy;
				log("boot custom intro net play url=" + localCopy.url
					+ " path=" + localCopy.nativePath
					+ " size=" + localCopy.size
					+ " from=" + file.nativePath
					+ " srcSize=" + file.size);
			}
			catch (logErr:*)
			{
			};
			return (true);
		}

		private function onCustomIntroDone(reason:String):void
		{
			if (reason == "watchdog")
			{
				log("custom intro watchdog â€” no Play.Start, aborting to title");
			}
			else if (reason.indexOf("fatal:") == 0)
			{
				log("custom intro net fatal " + reason.substr(6));
			};
			endCustomBootIntro();
		}

		private function onCustomIntroInput():Boolean
		{
			if (!core.m_customIntroActive)
			{
				return (false);
			};
			skipCustomBootIntro();
			return (true);
		}

		private function onCustomIntroStart(code:String):void
		{
			log("intro handler exit " + code);
			armIntroFrameProbe();
		}

		private function onCustomIntroStatus(code:String, info:Object, kind:String):void
		{
			var ns:NetStream;
			if (kind == "play")
			{
				log("custom intro playStatus " + code);
				return;
			};
			ns = core.m_introOverlay ? core.m_introOverlay.netStream : null;
			log("custom intro net " + code
				+ " level=" + String(info.level || "")
				+ " desc=" + String(info.description || "")
				+ " details=" + String(info.details || "")
				+ " time=" + (ns ? ns.time : -1)
				+ " bytes=" + (ns ? ns.bytesLoaded : 0) + "/" + (ns ? ns.bytesTotal : 0));
		}

		/** Drop the video and show the title. A busy attract intro used to remove only the video. */
		private function skipCustomBootIntro():void
		{
			log("custom intro skip → title");
			endCustomBootIntro();
			if (core.m_attract && core.m_attract.isBusy())
			{
				core.m_attract.requestSkipToTitle();
			};
		}

		private function armIntroFrameProbe():void
		{
			var st:Stage;
			if (m_introProbeLeft > 0)
			{
				return;
			};
			m_introProbeLeft = 3;
			st = core.m_introOverlay && core.m_introOverlay.layer ? core.m_introOverlay.layer.stage : null;
			if (!st)
			{
				log("intro probe no stage");
				m_introProbeLeft = 0;
				return;
			};
			st.addEventListener(Event.ENTER_FRAME, onIntroFrameProbe);
		}

		private function onIntroFrameProbe(e:Event):void
		{
			var st:Stage;
			var v:Video;
			m_introProbeLeft--;
			v = core.m_introOverlay ? core.m_introOverlay.video : null;
			log("intro frame left=" + m_introProbeLeft
				+ " time=" + (core.m_introOverlay && core.m_introOverlay.netStream ? core.m_introOverlay.netStream.time : -1)
				+ " video=" + (v ? (v.videoWidth + "x" + v.videoHeight) : "none")
				+ " active=" + core.m_customIntroActive);
			if (m_introProbeLeft <= 0)
			{
				st = e.currentTarget as Stage;
				if (st)
				{
					st.removeEventListener(Event.ENTER_FRAME, onIntroFrameProbe);
				};
			};
		}

		internal function suppressMenusDuringCustomIntro(menu:*):void
		{
			var layer:Sprite;
			if (!core.m_customIntroActive || !menu)
			{
				return;
			};
			try
			{
				if (menu["removeSelf"])
				{
					menu["removeSelf"]();
					log("custom intro hid menu " + core.safeName(menu));
				};
			}
			catch (err:*)
			{
			};
			layer = core.m_introOverlay ? core.m_introOverlay.layer : null;
			if (layer && layer.parent)
			{
				try
				{
					layer.parent.setChildIndex(layer, layer.parent.numChildren - 1);
				}
				catch (zErr:*)
				{
				};
			};
		}

		internal function isIntroPresentationMenu(menu:*):Boolean
		{
			var qn:String;
			qn = core.safeName(menu);
			if (!qn || qn.length < 1)
			{
				return (false);
			};
			return (qn.indexOf("IntroMenu") >= 0 || qn.indexOf("Intro2Menu") >= 0
				|| qn.indexOf("Intro3Menu") >= 0);
		}

		private function armCustomIntroControllerSkip(st:Stage):void
		{
			m_customIntroSkipArmed = false;
			setTimeout(function ():void
			{
				if (core.m_customIntroActive)
				{
					m_customIntroSkipArmed = true;
				};
			}, 450);
			if (!st)
			{
				return;
			};
			try
			{
				st.removeEventListener(Event.ENTER_FRAME, onCustomIntroControllerFrame);
			}
			catch (e0:*)
			{
			};
			st.addEventListener(Event.ENTER_FRAME, onCustomIntroControllerFrame, false, 0, true);
		}

		private function disarmCustomIntroControllerSkip():void
		{
			var MainCls:Class;
			var st:*;
			m_customIntroSkipArmed = false;
			try
			{
				MainCls = EngineRefs.Main as Class;
				st = MainCls && MainCls["Root"] ? MainCls["Root"].stage : null;
				if (st)
				{
					st.removeEventListener(Event.ENTER_FRAME, onCustomIntroControllerFrame);
				};
			}
			catch (err:*)
			{
			};
			if (core.m_introOverlay && core.m_introOverlay.layer && core.m_introOverlay.layer.stage)
			{
				try
				{
					core.m_introOverlay.layer.stage.removeEventListener(Event.ENTER_FRAME, onCustomIntroControllerFrame);
				}
				catch (e2:*)
				{
				};
			};
		}

		private function onCustomIntroControllerFrame(e:Event):void
		{
			if (!core.m_customIntroActive)
			{
				disarmCustomIntroControllerSkip();
				return;
			};
			// AttractMode polls when busy — avoid double-skip races.
			if (core.m_attract && core.m_attract.isBusy())
			{
				return;
			};
			if (!m_customIntroSkipArmed)
			{
				return;
			};
			if (AttractMode.anyControllerSkipDown())
			{
				endCustomBootIntro();
			};
		}

		private function endCustomBootIntro():void
		{
			if (!core.m_customIntroActive && !core.m_introOverlay)
			{
				return;
			};
			core.runStep("endCustomBootIntro", "disarmControllerSkip", disarmCustomIntroControllerSkip);
			core.m_customIntroActive = false;
			core.runStep("endCustomBootIntro", "finishCustomBootIntro", finishCustomBootIntro);
			core.runStep("endCustomBootIntro", "showPostIntroDestination", showPostIntroDestination);
		}

		internal function finishCustomBootIntro():void
		{
			var overlay:VideoOverlay;
			core.runStep("finishCustomBootIntro", "disarmControllerSkip", disarmCustomIntroControllerSkip);
			overlay = core.m_introOverlay;
			core.m_introOverlay = null;
			if (overlay)
			{
				try
				{
					overlay.dispose();
				}
				catch (disposeErr:*)
				{
					core.logStepError("finishCustomBootIntro dispose", disposeErr);
				};
			};
		}

		internal function showTitleAfterBootSkip():void
		{
			var MC:Class;
			var title:*;
			// Landed on title — don't steal the user's later Vault navigations.
			core.m_redirectVaultToTitle = false;
			try
			{
				MC = core.cssCtl.menuController();
				if (!MC)
				{
					log("showTitleAfterBootSkip: MenuController missing");
					return;
				};
				try
				{
					title = MC["titleMenu"];
				}
				catch (tmErr:*)
				{
					log("showTitleAfterBootSkip titleMenu get: " + tmErr);
					return;
				};
				if (title && ("show" in title) && title["show"] is Function)
				{
					title["show"]();
					log("showTitleAfterBootSkip ok");
				}
				else
				{
					log("showTitleAfterBootSkip: titleMenu.show unavailable");
				};
			}
			catch (err:*)
			{
				log("showTitleAfterBootSkip: " + err);
			};
		}

		internal function playBootIntro3():void
		{
			var MC:Class;
			var intro:*;
			try
			{
				MC = core.cssCtl.menuController();
				if (!MC)
				{
					showPostIntroDestination();
					return;
				};
				intro = MC["intro3Menu"];
				if (intro && intro["setVault"])
				{
					intro["setVault"](wantVaultIntroBoot() || core.m_intro3ToVault || m_postIntroMenu == "vault");
				};
				if (intro && intro["show"])
				{
					prepareIntroPresentation();
					intro["show"]();
					log("boot intro3 (ssf2intro_beta)");
					return;
				};
			}
			catch (err:*)
			{
				log("playBootIntro3: " + err);
			};
			showPostIntroDestination();
		}

		private function playBootIntro(resourceId:String, classLeaf:String, menuProp:String):void
		{
			var MC:Class;
			var RM:Class;
			var intro:*;
			var Cls:Class;
			configureIntroDestination();
			try
			{
				MC = core.cssCtl.menuController();
				RM = EngineRefs.ResourceManager as Class;
				if (RM && resourceId)
				{
					try
					{
						if (!Boolean(RM["getResourceByID"](resourceId, true)))
						{
							RM["queueResources"]([resourceId]);
							RM["load"]({"oncomplete": function (e:* = null):void
							{
								playBootIntro(resourceId, classLeaf, menuProp);
							}});
							log("boot intro loading " + resourceId);
							return;
						};
					}
					catch (loadErr:*)
					{
					};
				};
				if (MC && menuProp && MC[menuProp])
				{
					intro = MC[menuProp];
				};
				if (!intro)
				{
					try
					{
						Cls = EngineRefs.ssf2("menus." + classLeaf) as Class;
						if (Cls)
						{
							intro = new Cls();
							if (MC && menuProp)
							{
								MC[menuProp] = intro;
							};
						};
					}
					catch (clsErr:*)
					{
					};
				};
				if (intro && intro["show"])
				{
					prepareIntroPresentation();
					intro["show"]();
					log("boot intro " + resourceId);
					return;
				};
			}
			catch (err:*)
			{
				log("playBootIntro: " + err);
			};
			core.m_redirectVaultToTitle = false;
			showPostIntroDestination();
		}

		internal function openPaletteMaker(charName:String):Boolean
		{
			var ModHostCls:Class;
			var ModPatchesCls:Class;
			var RM:Class;
			var MC:Class;
			var charId:String;
			var resId:String;
			charId = String(charName || "mario");
			if (charId.length < 1)
			{
				charId = "mario";
			};
			try
			{
				ModHostCls = EngineRefs.ModHost as Class;
				ModPatchesCls = EngineRefs.ModPatches as Class;
				RM = EngineRefs.ResourceManager as Class;
				MC = core.cssCtl.menuController();
				if (!ModHostCls || !ModPatchesCls || !RM || !MC)
				{
					log("openPaletteMaker: engine classes missing");
					return (false);
				};
				ModHostCls["door"](ModPatchesCls["PALETTE_SHOW_LOADING_SCREEN"], [charId, true], undefined);
				resId = String(RM["getResourceIdForCharacter"](charId));
				RM["queueResources"]([resId]);
				ModHostCls["door"](ModPatchesCls["PALETTE_LOAD_COSTUME_FILE"], [charId], undefined);
				RM["load"]({"oncomplete": function (e:* = null):void
				{
					setTimeout(function ():void
					{
						try
						{
							ModHostCls["door"](ModPatchesCls["PALETTE_MENU_SET_CHARACTER"], [charId], undefined);
							if (MC["paletteMakerMenu"] && MC["paletteMakerMenu"]["show"])
							{
								MC["paletteMakerMenu"]["show"]();
								log("opened palette maker " + charId);
							};
						}
						catch (pmErr:*)
						{
							log("openPaletteMaker show: " + pmErr);
						};
					}, 30);
				}});
				return (true);
			}
			catch (err:*)
			{
				log("openPaletteMaker: " + err);
				return (false);
			};
			return (false);
		}

		internal function maybeRedirectVaultToTitle(menu:*):void
		{
			var qn:String;
			var MC:Class;
			if (!core.m_redirectVaultToTitle || !menu)
			{
				return;
			};
			qn = core.safeName(menu);
			if (qn.indexOf("VaultMenu") < 0)
			{
				return;
			};
			try
			{
				core.m_redirectVaultToTitle = false;
				try
				{
					menu["removeSelf"]();
				}
				catch (rmErr:*)
				{
				};
				MC = core.cssCtl.menuController();
				if (MC && MC["titleMenu"] && MC["titleMenu"]["show"])
				{
					MC["titleMenu"]["show"]();
					log("boot intro → title (skipped vault)");
				};
			}
			catch (err:*)
			{
				core.m_redirectVaultToTitle = false;
				log("maybeRedirectVaultToTitle: " + err);
			};
		}

		internal function isBootGateMenu(menu:*):Boolean
		{
			var qn:String;
			qn = core.safeName(menu);
			if (!qn || qn.length < 1)
			{
				return (false);
			};
			return (qn.indexOf("Disclaimer") >= 0 || qn.indexOf("IntroMenu") >= 0
				|| qn.indexOf("Intro2Menu") >= 0 || qn.indexOf("Intro3Menu") >= 0);
		}

		internal function stopActiveIntroPlayback():void
		{
			var MC:Class;
			var SQ:Class;
			var names:Array;
			var i:int;
			var menu:*;
			var content:*;
			// Always kill SoundQueue / mixer — Intro3 timeline can keep firing
			// after isOnscreen flips false.
			core.m_customIntroActive = false;
			core.m_intro3ToVault = false;
			finishCustomBootIntro();
			MC = core.cssCtl.menuController();
			names = ["introMenu", "intro2Menu", "intro3Menu"];
			i = 0;
			if (MC)
			{
				while (i < names.length)
				{
					try
					{
						menu = MC[names[i]];
						if (menu)
						{
							// Menu.subMenu is the real timeline MC (ssf2intro_*).
							// removeSelf alone does NOT stop it — audio keeps playing.
							try
							{
								content = null;
								if (menu["subMenu"] != null)
								{
									content = menu["subMenu"];
								}
								else
								{
									content = menu["content"] || menu["movieClip"] || menu["mc"] || menu["display"];
								};
								if (content)
								{
									if (content["stop"] is Function)
									{
										content["stop"]();
									};
									if (content["gotoAndStop"] is Function)
									{
										content["gotoAndStop"](1);
									};
								};
							}
							catch (contentErr:*)
							{
							};
							try
							{
								if (menu["killEvents"] is Function)
								{
									menu["killEvents"]();
								};
							}
							catch (killErr:*)
							{
							};
							try
							{
								if (menu["removeSelf"] is Function)
								{
									menu["removeSelf"]();
								};
							}
							catch (remErr:*)
							{
							};
							try
							{
								menu["visible"] = false;
							}
							catch (visErr:*)
							{
							};
						};
					}
					catch (menuErr:*)
					{
					};
					i++;
				};
			};
			try
			{
				SQ = EngineRefs.SoundQueue as Class;
				if (SQ && SQ["instance"])
				{
					SQ["instance"]["stopMusic"]();
					SQ["instance"]["stopAllSounds"]();
				};
			}
			catch (soundErr:*)
			{
			};
			try
			{
				SoundMixer.stopAll();
			}
			catch (mixErr:*)
			{
			};
			log("stopped intro playback");
		}

		internal function pickRandomBootIntroIfNeeded():void
		{
			var pool:Array;
			var pick:Object;
			var i:int;
			var entry:Object;
			var intro:String;
			var path:String;
			if (String(core.m_bootIntro || "").toLowerCase() != "random")
			{
				return;
			};
			pool = [];
			if (core.m_randomPool && core.m_randomPool.length > 0)
			{
				for (i = 0; i < core.m_randomPool.length; i++)
				{
					entry = core.m_randomPool[i] as Object;
					if (!entry)
					{
						continue;
					};
					intro = String(entry.bootIntro || "").toLowerCase();
					if (!intro || intro == "random" || intro == "skip" || intro == "none")
					{
						continue;
					};
					path = entry.bootIntroPath ? String(entry.bootIntroPath) : "";
					if (intro.indexOf("custom:") == 0 && path.length < 1)
					{
						continue;
					};
					pool.push(entry);
				};
			};
			if (pool.length < 1)
			{
				log("random intro: empty pool → skip");
				core.m_bootIntro = "skip";
				core.m_bootIntroPath = "";
				return;
			};
			pick = pool[int(Math.floor(Math.random() * pool.length))] as Object;
			if (!pick)
			{
				core.m_bootIntro = "default";
				core.m_bootIntroPath = "";
				return;
			};
			core.m_bootIntro = String(pick.bootIntro || "default").toLowerCase();
			core.m_bootIntroPath = pick.bootIntroPath ? String(pick.bootIntroPath) : "";
			log("random intro picked " + core.m_bootIntro + " path=" + (core.m_bootIntroPath || "(none)")
				+ " from " + pool.length);
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
