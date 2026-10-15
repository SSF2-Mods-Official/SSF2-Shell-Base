package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Load extra stage: the picker overlay of extra stages with files, and starting a match on
	 * the picked stage straight through the engine.
	 */
	public class StageExtraMatch
	{
		private var mod:StageEditorMod;
		private var m_extraOverlay:Sprite;
		private var m_extraOffset:int;
		private var m_extraList:Array;
		private var m_extraKeyFn:Function;

		public function StageExtraMatch(owner:StageEditorMod)
		{
			mod = owner;
			m_extraOffset = 0;
		}

		internal function readCssGame():*
		{
			var MC:Class;
			var css:*;
			var game:*;
			game = null;
			try
			{
				MC = EngineRefs.MenuController as Class;
				css = MC["CurrentCharacterSelectMenu"];
				if (css)
				{
					game = css.GameObj;
				};
			}
			catch (err:*)
			{
			};
			return (game);
		}

		internal function resolveStageGame():*
		{
			var GC:Class;
			var game:*;
			game = mod.m_matchGame;
			if (!game)
			{
				game = readCssGame();
			};
			if (!game)
			{
				try
				{
					GC = EngineRefs.GameController as Class;
					game = GC["currentGame"];
				}
				catch (gcErr:*)
				{
				};
			};
			if (game)
			{
				mod.m_matchGame = game;
			}
			else
			{
				mod.log("resolveStageGame failed css=" + readCssGame() + " cached=" + mod.m_matchGame);
			};
			return (game);
		}

		internal function openExtraPicker():void
		{
			var st:Stage;
			if (mod.m_editing || m_extraOverlay || !mod.m_host)
			{
				return;
			};
			if (!mod.isStageSelectOnscreen())
			{
				try
				{
					mod.m_host.notify("Open Stage Select first.");
				}
				catch (err:*)
				{
				};
				return;
			};
			m_extraList = mod.m_catalog.collectExtraStages();
			m_extraOffset = 0;
			st = mod.m_host.stage as Stage;
			if (!st)
			{
				return;
			};
			try
			{
				mod.m_host.setInputBlocked(true);
				mod.m_host.setSessionFlag("mod_menu.overlay", true);
			}
			catch (blockErr:*)
			{
			};
			m_extraOverlay = buildExtraOverlay(m_extraList);
			st.addChild(m_extraOverlay);
			m_extraKeyFn = onExtraKey;
			try
			{
				mod.m_host.addKeyListener(m_extraKeyFn);
			}
			catch (keyErr:*)
			{
			};
		}

		/** Dimmed backdrop, title, hint, and up to three columns of 16 clickable stage names. */
		private function buildExtraOverlay(list:Array):Sprite
		{
			var overlay:Sprite;
			var tf:TextField;
			var i:int;
			var item:Object;
			var col:int;
			var row:int;
			overlay = new Sprite();
			overlay.graphics.beginFill(0x000000, 0.72);
			overlay.graphics.drawRect(0, 0, 640, 360);
			overlay.graphics.endFill();
			overlay.graphics.beginFill(0x141414, 0.94);
			overlay.graphics.lineStyle(1, 0xE8A020, 0.9);
			overlay.graphics.drawRect(40, 28, 560, 304);
			overlay.graphics.endFill();
			overlay.addChild(extraLabel(36, 16, 0xE8A020, true, "Load extra stage"));
			overlay.addChild(extraLabel(308, 11, 0xAAAAAA, false, "Click a stage to start. Esc closes."));
			if (list.length <= 0)
			{
				overlay.addChild(extraLabel(72, 13, 0xCCCCCC, false, "No extra stages with files."));
			};
			i = 0;
			while (i < list.length)
			{
				item = list[i];
				col = int(i / 16);
				row = i % 16;
				if (col > 2)
				{
					break;
				};
				tf = new TextField();
				tf.x = 52 + col * 180;
				tf.y = 64 + row * 15;
				tf.width = 170;
				tf.height = 16;
				tf.selectable = false;
				tf.mouseEnabled = true;
				tf.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, false);
				tf.text = String(item.name);
				bindExtraRow(tf, String(item.id));
				overlay.addChild(tf);
				i++;
			};
			return (overlay);
		}

		private function extraLabel(y:Number, size:int, color:uint, bold:Boolean, text:String):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.x = 52;
			tf.y = y;
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", size, color, bold);
			tf.text = text;
			return (tf);
		}

		private function bindExtraRow(tf:TextField, id:String):void
		{
			tf.addEventListener(MouseEvent.MOUSE_OVER, function (e:MouseEvent):void
			{
				tf.textColor = 0xE8A020;
			});
			tf.addEventListener(MouseEvent.MOUSE_OUT, function (e:MouseEvent):void
			{
				tf.textColor = 0xFFFFFF;
			});
			tf.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				startExtraStage(id);
			});
		}

		private function onExtraKey(e:KeyboardEvent):Boolean
		{
			if (e.keyCode == 27 || e.keyCode == 112)
			{
				closeExtraPicker();
				if (e.keyCode == 112)
				{
					try
					{
						mod.m_host.setSessionFlag("mod_menu.skip_f1", true);
					}
					catch (err:*)
					{
					};
				};
				return (true);
			};
			return (true);
		}

		internal function closeExtraPicker():void
		{
			if (m_extraOverlay)
			{
				if (m_extraOverlay.parent)
				{
					m_extraOverlay.parent.removeChild(m_extraOverlay);
				};
				m_extraOverlay = null;
			};
			if (mod.m_host && m_extraKeyFn != null)
			{
				try
				{
					mod.m_host["removeKeyListener"](m_extraKeyFn);
				}
				catch (err:*)
				{
				};
			};
			m_extraKeyFn = null;
			try
			{
				if (mod.m_host && !mod.m_editing)
				{
					mod.m_host.setInputBlocked(false);
					mod.m_host.setSessionFlag("mod_menu.overlay", false);
				};
			}
			catch (err2:*)
			{
			};
		}

		private function startExtraStage(id:String):void
		{
			var game:*;
			try
			{
				closeExtraPicker();
				if (!id || !mod.m_catalog.hasStageFile(id))
				{
					mod.log("startExtraStage blocked — no file for " + id);
					try
					{
						if (mod.m_host)
						{
							mod.m_host.notify("Stage file missing: " + id);
						};
					}
					catch (nerr:*)
					{
					};
					return;
				};
				game = resolveStageGame();
				if (!game)
				{
					mod.log("startExtraStage blocked — no game object");
					try
					{
						if (mod.m_host)
						{
							mod.m_host.notify("Could not resolve match settings.");
						};
					}
					catch (nerr2:*)
					{
					};
					return;
				};
				startStageMatchDirect(game, id);
			}
			catch (stepErr:*)
			{
				mod.log("fail step=startExtraStage err=" + stepErr);
			};
		}

		private function startStageMatchDirect(game:*, id:String):void
		{
			var eng:Object;
			var loadingMask:MovieClip;
			var GC:Class;
			try
			{
				eng = matchEngineClasses();
				if (!eng)
				{
					mod.log("startStageMatchDirect missing engine class");
					return;
				};
				if (!canStartStageMatch(eng, game, id))
				{
					return;
				};
				eng.GC["isStarted"] = true;
				game["LevelData"]["stage"] = id;
				loadingMask = showLoadingMask(eng);
				queueMatchResources(eng, game, id);
				eng.RM["load"]({"oncomplete": matchCompleteHandler(eng, game, id, loadingMask)});
			}
			catch (err:*)
			{
				try
				{
					GC = EngineRefs.GameController as Class;
					GC["isStarted"] = false;
				}
				catch (resetErr:*)
				{
				};
				mod.log("startStageMatchDirect failed: " + err);
				mod.notifyUser("Could not load " + id + ".");
			};
		}

		/** {GC, RM, MainCls, UtilsCls, MC, ModeCls}, or null when any engine class is missing. */
		private function matchEngineClasses():Object
		{
			var eng:Object;
			eng = {
				"GC": EngineRefs.GameController as Class,
				"RM": EngineRefs.ResourceManager as Class,
				"MainCls": EngineRefs.Main as Class,
				"UtilsCls": EngineRefs.Utils as Class,
				"MC": EngineRefs.MenuController as Class,
				"ModeCls": EngineRefs.ssf2("enums.Mode") as Class
			};
			if (!eng.GC || !eng.RM || !eng.MainCls || !eng.UtilsCls || !eng.MC || !eng.ModeCls)
			{
				return (null);
			};
			return (eng);
		}

		/** False (with a log line and a notice) when a match is running, the game is online, or the stage file is missing. */
		private function canStartStageMatch(eng:Object, game:*, id:String):Boolean
		{
			var res:*;
			if (Boolean(eng.GC["isStarted"]))
			{
				mod.log("startStageMatchDirect blocked — already started");
				return (false);
			};
			if (game["GameMode"] === eng.ModeCls["ONLINE"])
			{
				mod.log("startStageMatchDirect blocked — online " + id);
				mod.notifyUser("Load extra stage is offline-only.");
				return (false);
			};
			res = eng.RM["getResourceByID"](id);
			if (!res || !res["FileName"])
			{
				mod.log("startStageMatchDirect blocked — resource missing " + id);
				mod.notifyUser("Stage file missing: " + id);
				return (false);
			};
			return (true);
		}

		private function showLoadingMask(eng:Object):MovieClip
		{
			var loadingMask:MovieClip;
			var root:*;
			loadingMask = eng.RM["getLibraryMC"]("loadingMask") as MovieClip;
			if (loadingMask)
			{
				loadingMask.x = Number(eng.MainCls["Width"]) / 2;
				loadingMask.y = Number(eng.MainCls["Height"]) / 2;
				root = eng.MainCls["Root"];
				if (root)
				{
					root.addChild(loadingMask);
				};
			};
			return (loadingMask);
		}

		/** Seeds the match RNG, then queues the stage and every player character. */
		private function queueMatchResources(eng:Object, game:*, id:String):void
		{
			var playerSettings:*;
			var i:int;
			game["LevelData"]["randSeed"] = eng.UtilsCls["randomInteger"](1, 1000);
			eng.UtilsCls["setRandSeed"](game["LevelData"]["randSeed"]);
			eng.UtilsCls["shuffleRandom"]();
			playerSettings = game["PlayerSettings"];
			eng.MainCls["prepRandomCharacters"](playerSettings ? playerSettings["length"] : 0);
			eng.RM["queueResources"]([id]);
			if (playerSettings)
			{
				i = 1;
				while (i <= playerSettings["length"])
				{
					eng.RM["queuePlayerCharacterResource"](playerSettings[i - 1], i - 1);
					i++;
				};
			};
		}

		/** The ResourceManager oncomplete: drops the mask, closes the menus, and starts the match. */
		private function matchCompleteHandler(eng:Object, game:*, id:String, loadingMask:MovieClip):Function
		{
			return (function (e:* = null):void
			{
				try
				{
					if (loadingMask && loadingMask.parent)
					{
						loadingMask.parent.removeChild(loadingMask);
					};
					eng.MC["disposeAllMenus"]();
					eng.GC["startMatch"](game);
					mod.log("startMatch " + id);
				}
				catch (doneErr:*)
				{
					eng.GC["isStarted"] = false;
					mod.log("startMatch failed: " + doneErr);
					mod.notifyUser("Could not load " + id + ".");
				};
			});
		}
	}
}
