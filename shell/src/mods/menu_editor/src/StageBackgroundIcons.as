package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.net.URLRequest;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.StageBackgroundCatalog;

	/** Stage-select icon art, hover preview, and a click that starts the default stage. */
	public class StageBackgroundIcons
	{
		/** Set Stage BG on one of these slots. Args: slot id, asset path, display name. */
		public static var onUseAsBackground:Function;

		private static var s_synced:Boolean = false;

		public static function invalidate():void
		{
			s_synced = false;
			StageBackgroundCatalog.invalidate();
		}

		/** Puts each pack on the stage grid once the editor's pages exist. */
		public static function sync(mod:StageEditorMod):void
		{
			var found:Object;
			var id:String;
			var ids:Array;
			var i:int;
			var have:Object;
			if (!mod || !mod.m_grid || !mod.m_book)
			{
				return;
			};
			if (!s_synced)
			{
				StageBackgroundCatalog.reload();
				s_synced = true;
			};
			found = StageBackgroundCatalog.map();
			ids = mod.m_book.flattenAllPages();
			have = {};
			i = 0;
			while (ids && i < ids.length)
			{
				have[String(ids[i])] = true;
				i++;
			};
			for (id in found)
			{
				if (have[id])
				{
					continue;
				};
				if (!GridRows.tryAdd(mod.m_book.pageRows(0), id, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS))
				{
					GridRows.placeOnFirstOpenPage(mod.m_grid, id, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS, StageEditorMod.MAX_PAGES);
				};
			};
		}

		public static function decorate(child:DisplayObject, id:String):void
		{
			var row:Object;
			if (!child || !id || child["stageBgBound"])
			{
				return;
			};
			row = StageBackgroundCatalog.row(id);
			if (!row)
			{
				return;
			};
			child["stageBgBound"] = true;
			ensureSelectable(id, String(row.defaultStage || ""));
			paintIcon(child as MovieClip, String(row.preview || ""));
			child.addEventListener(MouseEvent.ROLL_OVER, onOver);
			child.addEventListener(MouseEvent.ROLL_OUT, onOut);
			var file:Boolean = hasFile(id);
			if (!file)
			{
				child.addEventListener(MouseEvent.CLICK, onClick, true);
			};
			log("decorate id=" + id + " hasFile=" + (file ? 1 : 0) + " click=" + (file ? 0 : 1) + " clip=" + child.x + "," + child.y + " size=" + child.width + "x" + child.height);
		}

		private static function onOver(e:MouseEvent):void
		{
			var clip:DisplayObject = e.currentTarget as DisplayObject;
			var id:String = clip ? String(clip["stageID"] || clip.name || "") : "";
			var row:Object = StageBackgroundCatalog.row(id);
			if (!row || !row.preview)
			{
				return;
			};
			setTimeout(function ():void
			{
				showPreview(String(row.preview), String(row.name || id));
			}, 0);
		}

		private static function onOut(e:MouseEvent):void
		{
			clearPreview();
		}

		private static function onClick(e:MouseEvent):void
		{
			var clip:DisplayObject = e.currentTarget as DisplayObject;
			var id:String = clip ? String(clip["stageID"] || clip.name || "") : "";
			var row:Object = StageBackgroundCatalog.resolve(id);
			var info:Object;
			var asset:String;
			var game:*;
			log("click id=" + id + " row=" + (row ? 1 : 0) + " target=" + (e.target ? e.target.name : ""));
			if (!row)
			{
				return;
			};
			e.stopImmediatePropagation();
			asset = String(row.asset || "");
			info = StageBackgroundCatalog.row(id);
			if (backgroundPicking())
			{
				trace("[stage_background] lock slot=" + id + " asset=" + assetName(asset));
				if (onUseAsBackground != null)
				{
					onUseAsBackground(id, asset, info ? String(info.name || id) : id);
				};
				return;
			};
			StageBackgroundPlayer.remember(asset);
			game = matchGame();
			log("slot=" + id + " default=" + row.defaultStage + " asset=" + assetName(asset) + " game=" + (game ? 1 : 0));
			startMatch(game, String(row.defaultStage));
		}

		public static function showPreview(path:String, label:String):void
		{
			var previewer:MovieClip = previewerClip();
			var loader:Loader;
			if (!previewer || !path)
			{
				return;
			};
			clearPreview();
			var stock:DisplayObject = previewer.getChildByName("mc");
			var boxW:Number = stock && stock.width > 8 ? stock.width : 220;
			var boxH:Number = stock && stock.height > 8 ? stock.height : 140;
			var ox:Number = stock ? stock.x : 0;
			var oy:Number = stock ? stock.y : 0;
			if (stock)
			{
				stock.visible = false;
			};
			loader = new Loader();
			loader.name = "stageBgPreview";
			loader.mouseEnabled = false;
			loader.mouseChildren = false;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (ev:Event):void
			{
				placeCentered(loader, previewer, boxW, boxH, ox, oy, "stageBgPreview");
			});
			try
			{
				loader.load(new URLRequest(new File(path).url));
				previewer.addChild(loader);
			}
			catch (err:*)
			{
			};
			setLabel(label);
		}

		public static function clearPreview():void
		{
			var previewer:MovieClip = previewerClip();
			var shot:DisplayObject;
			var mc:DisplayObject;
			if (!previewer)
			{
				return;
			};
			shot = previewer.getChildByName("stageBgPreview");
			if (shot && shot.parent)
			{
				shot.parent.removeChild(shot);
			};
			mc = previewer.getChildByName("mc");
			if (mc)
			{
				mc.visible = true;
			};
		}

		private static function paintIcon(clip:MovieClip, path:String):void
		{
			var loader:Loader;
			if (!clip || !path || clip.getChildByName("stageBgIcon"))
			{
				return;
			};
			var boxW:Number = clip.width > 8 ? clip.width : 48;
			var boxH:Number = clip.height > 8 ? clip.height : 28;
			log("icon " + clip.name + " box=" + boxW + "x" + boxH);
			loader = new Loader();
			loader.name = "stageBgIcon";
			loader.mouseEnabled = false;
			loader.mouseChildren = false;
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (ev:Event):void
			{
				placeCentered(loader, clip, boxW, boxH, 0, 0, "stageBgIcon");
			});
			try
			{
				loader.load(new URLRequest(new File(path).url));
				clip.addChild(loader);
			}
			catch (err:*)
			{
			};
		}

		/** The slot and the preview clip are centered. The bitmap's top-left sits at half the box. */
		private static function placeCentered(loader:Loader, parent:DisplayObject, boxW:Number, boxH:Number, ox:Number, oy:Number, childName:String):void
		{
			var content:DisplayObject = loader.content;
			var host:DisplayObjectContainer = parent as DisplayObjectContainer;
			if (!content || !host)
			{
				log("placed skip name=" + childName + " content=" + (content ? 1 : 0) + " host=" + (host ? 1 : 0));
				return;
			};
			content.width = boxW;
			content.height = boxH;
			content.x = ox - boxW * 0.5;
			content.y = oy - boxH * 0.5;
			log("placed name=" + childName + " x=" + content.x + " y=" + content.y + " w=" + content.width + " h=" + content.height);
			content.name = childName;
			try
			{
				content["mouseEnabled"] = false;
				content["mouseChildren"] = false;
			}
			catch (mouseErr:*)
			{
			};
			host.addChild(content);
			if (loader.parent)
			{
				loader.parent.removeChild(loader);
			};
		}

		private static function backgroundPicking():Boolean
		{
			var host:*;
			var flagged:*;
			host = EngineRefs.ModHost;
			try
			{
				flagged = host ? host.getSessionFlag("camera_background.picking", null) : null;
				return (flagged != null && String(flagged) != "null" && String(flagged) != "false");
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private static function matchGame():*
		{
			var MC:*;
			var GC:*;
			try
			{
				MC = EngineRefs.MenuController;
				if (MC && MC["CurrentCharacterSelectMenu"])
				{
					return (MC["CurrentCharacterSelectMenu"]["GameObj"]);
				};
			}
			catch (cssErr:*)
			{
			};
			GC = EngineRefs.ssf2("controllers.GameController");
			return (GC ? GC["currentGame"] : null);
		}

		/** StageButton.button_CLICK returns before STAGE_SELECT when the id has no FileName. */
		private static function ensureSelectable(id:String, defaultStage:String):void
		{
			var RM:*;
			var Res:Class;
			var donor:*;
			var file:String;
			var enc:String;
			var key:String;
			var type:int;
			if (!id || !defaultStage)
			{
				return;
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				Res = EngineRefs.ssf2("util.Resource") as Class;
				if (!RM || !RM.poolHash || !Res)
				{
					log("resource skip id=" + id + " rm=" + (RM ? 1 : 0));
					return;
				};
				if (RM.poolHash[id] && RM.poolHash[id].FileName)
				{
					return;
				};
				donor = RM.getResourceByID(defaultStage);
				file = donor && donor.FileName ? String(donor.FileName) : "";
				if (!file)
				{
					log("resource skip id=" + id + " donor=" + defaultStage);
					return;
				};
				enc = donor.EncryptedFileName ? String(donor.EncryptedFileName) : file;
				key = donor.PassKey ? String(donor.PassKey) : "";
				type = int(donor.Type);
				RM.poolHash[id] = new Res(id, file, enc, key, type);
				log("resource id=" + id + " file=" + file + " type=" + type);
			}
			catch (err:*)
			{
				log("resource fail id=" + id + " " + err);
			};
		}

		private static function hasFile(id:String):Boolean
		{
			var RM:*;
			var res:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM && RM.getResourceByID is Function ? RM.getResourceByID(id) : null;
				return (Boolean(res && res.FileName));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private static function startMatch(game:*, stageId:String):void
		{
			var GC:*;
			var RM:*;
			var Main:*;
			var MC:*;
			var Utils:*;
			var n:int;
			var i:int;
			if (!game || !stageId)
			{
				log("start abort game=" + (game ? 1 : 0) + " stage=" + stageId);
				return;
			};
			log("start stage=" + stageId);
			GC = EngineRefs.ssf2("controllers.GameController");
			RM = EngineRefs.ssf2("util.ResourceManager");
			Main = EngineRefs.Main;
			MC = EngineRefs.ssf2("controllers.MenuController");
			Utils = EngineRefs.ssf2("util.Utils");
			if (!GC || !RM)
			{
				return;
			};
			try
			{
				GC["isStarted"] = true;
				game["LevelData"]["stage"] = stageId;
				game["LevelData"]["randSeed"] = 1 + int(Math.random() * 999);
				if (Utils && Utils.setRandSeed is Function)
				{
					Utils.setRandSeed(game["LevelData"]["randSeed"]);
				};
				if (Utils && Utils.shuffleRandom is Function)
				{
					Utils.shuffleRandom();
				};
				n = game["PlayerSettings"] ? game["PlayerSettings"].length : 0;
				if (Main && Main.prepRandomCharacters is Function)
				{
					Main.prepRandomCharacters(n);
				};
				RM.queueResources([stageId]);
				i = 1;
				while (i <= n)
				{
					RM.queuePlayerCharacterResource(game["PlayerSettings"][i - 1], i - 1);
					i++;
				};
				RM.load({
					"oncomplete": function (done:* = null):void
					{
						if (MC && MC.disposeAllMenus is Function)
						{
							MC.disposeAllMenus();
						};
						GC.startMatch(game);
					},
					"flushUnused": true
				});
			}
			catch (err:*)
			{
				trace("[stage_background] start failed: " + err);
				try
				{
					GC["isStarted"] = false;
				}
				catch (stopErr:*)
				{
				};
			};
		}

		private static function previewerClip():MovieClip
		{
			var MC:*;
			var menu:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController");
				menu = MC ? MC["stageSelectMenu"] : null;
				return (menu && menu.SubMenu ? menu.SubMenu.stage_sample.previewer as MovieClip : null);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private static function setLabel(label:String):void
		{
			var MC:*;
			var menu:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController");
				menu = MC ? MC["stageSelectMenu"] : null;
				if (menu && menu.SubMenu && menu.SubMenu.stage_sample)
				{
					menu.SubMenu.stage_sample.stage_txt.text = label;
				};
			}
			catch (err:*)
			{
			};
		}

		private static function log(msg:String):void
		{
			var GL:*;
			try
			{
				GL = EngineRefs.GameLog;
				if (GL && GL.write is Function)
				{
					GL.write("[stage_background] " + msg);
				};
			}
			catch (err:*)
			{
			};
			trace("[stage_background] " + msg);
		}

		private static function assetName(path:String):String
		{
			var slash:int = path ? Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\")) : -1;
			return (slash >= 0 ? path.substr(slash + 1) : path);
		}
	}
}
