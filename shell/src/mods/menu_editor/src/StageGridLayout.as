package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.utils.getQualifiedClassName;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Lays out the live Stage Select grid each frame: places, spawns, and hides stage icons,
	 * and keeps the edit chrome and the select hand above them.
	 */
	public class StageGridLayout
	{
		private var mod:StageEditorMod;
		private var m_stageBtns:Object;
		private var m_spawnedIds:Object;
		private var m_compactOn:Boolean;
		private var m_frameOn:Boolean;

		public function StageGridLayout(owner:StageEditorMod)
		{
			mod = owner;
			m_stageBtns = {};
			m_spawnedIds = {};
			m_compactOn = false;
		}

		internal function sssHand():*
		{
			if (!mod.m_cachedSss)
			{
				return (null);
			};
			try
			{
				return (mod.m_cachedSss["selectHand"]);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function hookSssHandClip(clip:DisplayObject):void
		{
			var hand:*;
			if (!clip)
			{
				return;
			};
			hand = sssHand();
			try
			{
				if (hand && hand["addClickEventClipCheckBounds"])
				{
					hand["addClickEventClipCheckBounds"](clip);
				};
			}
			catch (err:*)
			{
			};
		}

		internal function unhookSssHandClip(clip:DisplayObject):void
		{
			var hand:*;
			if (!clip)
			{
				return;
			};
			hand = sssHand();
			try
			{
				if (hand && hand["removeClickEventClipCheckBounds"])
				{
					hand["removeClickEventClipCheckBounds"](clip);
				};
			}
			catch (err:*)
			{
			};
		}

		private function raiseHand():void
		{
			var hand:*;
			var mc:DisplayObject;
			var sub:DisplayObjectContainer;
			sub = resolveSubMenu(null) as DisplayObjectContainer;
			hand = sssHand();
			mc = null;
			try
			{
				if (hand)
				{
					mc = (hand["HandMC"] as DisplayObject) || (hand["Hand"] as DisplayObject) || (hand["m_hand"] as DisplayObject);
				};
			}
			catch (err:*)
			{
				mc = null;
			};
			if (!mc)
			{
				mc = mod.m_handClip;
			};
			if (!mc || (mc.parent == null))
			{
				mc = mod.m_sxpUi.findSelectHand(sub);
			};
			if (!mc)
			{
				mc = scanHandClip(sub);
			};
			if (!mc)
			{
				mc = mod.m_sxpUi.findNamedClip(sub, "stageselect_hand");
			};
			if (!mc || !mc.parent)
			{
				return;
			};
			mod.m_handClip = mc;
			try
			{
				mc["mouseEnabled"] = false;
				mc["mouseChildren"] = false;
			}
			catch (mouseErr:*)
			{
			};
			raiseInContainer(mc, sub);
		}

		private function raiseInContainer(obj:DisplayObject, root:DisplayObjectContainer):void
		{
			var cur:DisplayObject;
			cur = obj;
			if (!cur)
			{
				return;
			};
			if (root)
			{
				while (cur.parent && cur.parent != root)
				{
					cur = cur.parent;
				};
			};
			raiseDisplay(cur);
		}

		private function raiseDisplay(obj:DisplayObject):void
		{
			if (!obj || !obj.parent)
			{
				return;
			};
			try
			{
				obj.parent.setChildIndex(obj, obj.parent.numChildren - 1);
			}
			catch (zErr:*)
			{
			};
		}

		internal function scanHandClip(host:DisplayObjectContainer):DisplayObject
		{
			var i:int;
			var child:DisplayObject;
			var qn:String;
			if (!host)
			{
				return (null);
			};
			i = 0;
			while (i < host.numChildren)
			{
				child = host.getChildAt(i);
				if (child is MovieClip)
				{
					qn = getQualifiedClassName(child).toLowerCase();
					if (qn.indexOf("hand") >= 0 || (child.name && child.name.toLowerCase().indexOf("hand") >= 0))
					{
						return (child);
					};
				};
				i++;
			};
			return (null);
		}

		internal function liveIcons():DisplayObjectContainer
		{
			if (!mod.m_cachedSss)
			{
				return (null);
			};
			try
			{
				return (mod.m_cachedSss.StageSelectionIconsMC as DisplayObjectContainer);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function resolveSubMenu(menu:*):*
		{
			var sub:*;
			if (!menu)
			{
				menu = mod.m_cachedSss;
			};
			if (!menu)
			{
				return (null);
			};
			try
			{
				sub = menu["SubMenu"] || menu["m_subMenu"] || menu["subMenu"];
			}
			catch (err:*)
			{
				sub = null;
			};
			return (sub);
		}

		internal function gameSize():Object
		{
			var MainCls:*;
			var gw:Number;
			var gh:Number;
			gw = 853;
			gh = 480;
			try
			{
				MainCls = EngineRefs.Main;
				if (MainCls)
				{
					gw = Number(MainCls["Width"] || gw);
					gh = Number(MainCls["Height"] || gh);
				};
			}
			catch (mainErr:*)
			{
			};
			return ({
				"w": gw,
				"h": gh
			});
		}

		internal function startCompact():void
		{
			if (!mod.m_host)
			{
				return;
			};
			if (!m_compactOn)
			{
				m_compactOn = true;
				try
				{
					mod.m_host.setSessionFlag("stage_editor.paging", true);
				}
				catch (flagErr:*)
				{
				};
			};
			if (mod.m_cachedSss)
			{
				attachFrame();
			};
		}

		internal function stopCompact():void
		{
			if (!m_compactOn)
			{
				return;
			};
			m_compactOn = false;
			try
			{
				if (mod.m_host)
				{
					mod.m_host.setSessionFlag("stage_editor.paging", false);
				};
			}
			catch (flagErr:*)
			{
			};
			detachFrame();
		}

		private function attachFrame():void
		{
			var st:Stage;
			if (m_frameOn || !mod.m_host)
			{
				return;
			};
			st = mod.m_host.stage as Stage;
			if (!st)
			{
				return;
			};
			m_frameOn = true;
			st.addEventListener(Event.ENTER_FRAME, compactFrame, false, -10000);
		}

		internal function detachFrame():void
		{
			var st:Stage;
			if (!m_frameOn)
			{
				return;
			};
			m_frameOn = false;
			try
			{
				st = mod.m_host ? (mod.m_host.stage as Stage) : null;
				if (st)
				{
					st.removeEventListener(Event.ENTER_FRAME, compactFrame, false);
				};
			}
			catch (err:*)
			{
			};
		}

		private function stageRowsWithDragGap(rows:Array):Array
		{
			var out:Array;
			var cell:Object;
			var g:Point;
			var r:int;
			var c:int;
			var line:Array;
			var next:Array;
			var id:String;
			var rowIndex:int;
			var col:int;
			if (!mod.m_dragClip || !mod.m_dragClip.stage)
			{
				return (rows);
			};
			try
			{
				g = mod.m_dragClip.localToGlobal(new Point(0, 0));
				cell = mod.m_input.liveCellAt(g.x, g.y);
			}
			catch (err:*)
			{
				return (rows);
			};
			if (!cell)
			{
				return (rows);
			};
			out = [];
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				next = [];
				c = 0;
				while (line && c < line.length)
				{
					id = String(line[c]);
					if (id != mod.m_dragId)
					{
						next.push(id);
					};
					c++;
				};
				out.push(next);
				r++;
			};
			if (String(cell.mode) == "newrow")
			{
				out.push([""]);
				return (out);
			};
			rowIndex = int(cell.row);
			while (out.length <= rowIndex)
			{
				out.push([]);
			};
			line = out[rowIndex] as Array;
			if (!line)
			{
				line = [];
				out[rowIndex] = line;
			};
			col = int(cell.col);
			if (col < 0)
			{
				col = 0;
			};
			if (col > line.length)
			{
				col = line.length;
			};
			line.splice(col, 0, "");
			return (out);
		}

		internal function compactFrame(e:Event):void
		{
			var menu:*;
			var icons:DisplayObjectContainer;
			var mappings:Object;
			var rows:Array;
			var pos:Object;
			var size:Object;
			var block:Object;
			var maxCols:int;
			if (!mod.m_menusReady)
			{
				return;
			};
			if (!mod.m_cachedSss)
			{
				return;
			};
			try
			{
				if (!mod.m_cachedSss.isOnscreen())
				{
					return;
				};
			}
			catch (onErr:*)
			{
				return;
			};
			mappings = EditorEngine.mappings();
			if (!mappings || !mappings.stage_select_screen)
			{
				return;
			};
			menu = mod.m_cachedSss;
			try
			{
				icons = menu.StageSelectionIconsMC as DisplayObjectContainer;
			}
			catch (iconErr:*)
			{
				return;
			};
			if (!icons)
			{
				return;
			};
			mod.m_input.pollGamepadEdit();
			StageBackgroundIcons.sync(mod);
			StageAssetSlot.sync(mod);
			block = mod.m_book.pageBlock(mappings);
			rows = block ? (block._rows as Array) : null;
			pos = block ? block._pos : null;
			size = block ? block._size : null;
			if (!rows || !pos || !size)
			{
				return;
			};
			maxCols = layoutStageIcons(menu, icons, rows, pos, size);
			try
			{
				hideEnginePager(menu);
				mod.m_sxpUi.showSxp(menu, mod.m_sxpUi.resolveSxpClip(menu), pos, size, maxCols);
			}
			catch (sxpErr:*)
			{
				mod.log("showSxp failed: " + sxpErr);
			};
			if (!mod.m_sxpUi.sxpSelectHeld())
			{
				mod.m_sxpSelectLetGo = true;
			};
			raiseSssChrome();
		}

		/** Places the page rows on the live grid and hides every other icon. Returns the column count used. */
		private function layoutStageIcons(menu:*, icons:DisplayObjectContainer, rows:Array, pos:Object, size:Object):int
		{
			var keep:Object;
			var maxCols:int;
			var r:int;
			var i:int;
			var child:DisplayObject;
			var id:String;
			if (mod.m_editing && mod.m_dragging && mod.m_dragId && !mod.m_dragFromBench)
			{
				rows = stageRowsWithDragGap(rows);
			};
			keep = {};
			if (mod.m_editing && mod.m_dragging && mod.m_dragId && !mod.m_dragFromBench)
			{
				keep[mod.m_dragId] = true;
			};
			maxCols = 1;
			r = 0;
			while (r < rows.length)
			{
				maxCols = Math.max(maxCols, (rows[r] as Array) ? (rows[r] as Array).length : 0);
				r++;
			};
			if (maxCols > StageEditorMod.MAX_COLS)
			{
				maxCols = StageEditorMod.MAX_COLS;
			};
			r = 0;
			while (r < rows.length)
			{
				placeStageRow(menu, icons, (rows[r] as Array) || [], r, pos, size, maxCols, keep);
				r++;
			};
			i = 0;
			while (i < icons.numChildren)
			{
				child = icons.getChildAt(i);
				id = readStageId(child);
				if (id != "xpstage" && id != "sxp" && !keep[id])
				{
					hideClip(child);
				};
				i++;
			};
			return (maxCols);
		}

		private function placeStageRow(menu:*, icons:DisplayObjectContainer, vis:Array, r:int, pos:Object, size:Object, maxCols:int, keep:Object):void
		{
			var shift:Number;
			var c:int;
			var child:DisplayObject;
			var id:String;
			shift = (maxCols - vis.length) * Number(size.width) * 0.5;
			c = 0;
			while (c < vis.length)
			{
				id = String(vis[c]);
				if (!id)
				{
					c++;
					continue;
				};
				keep[id] = true;
				child = findIcon(icons, id);
				if (!child)
				{
					child = spawnStageIcon(icons, id, Number(size.width), Number(size.height));
				};
				if (child)
				{
					placeStageIcon(menu, child, id, Number(pos.x) + Number(size.width) * c + shift, Number(pos.y) + Number(size.height) * r);
				};
				c++;
			};
		}

		private function placeStageIcon(menu:*, child:DisplayObject, id:String, x:Number, y:Number):void
		{
			child.visible = true;
			try
			{
				child["mouseEnabled"] = true;
				child["mouseChildren"] = true;
			}
			catch (mouseErr:*)
			{
			};
			child.alpha = 1;
			if (mod.m_editing && mod.m_mode == StageEditorMod.MODE_REMOVE && mod.m_removeIds && mod.m_removeIds[id])
			{
				child.alpha = 0.4;
			}
			else if (mod.m_editing && mod.m_mode == StageEditorMod.MODE_SORT && mod.m_sortPickId == id)
			{
				child.alpha = 0.55;
			};
			if (!(mod.m_editing && mod.m_dragging && mod.m_dragId == id && !mod.m_dragFromBench))
			{
				child.x = x;
				child.y = y;
			};
			if (m_spawnedIds[id])
			{
				bindStageButton(menu, child, id);
			};
			StageBackgroundIcons.decorate(child, id);
			StageAssetSlot.decorate(child, id);
		}

		/** Hooks the hand onto the bar buttons and keeps the edit chrome and hand above the grid. */
		private function raiseSssChrome():void
		{
			hookSssHandClip(mod.m_editBtn);
			hookSssHandClip(mod.m_bgBtn);
			if (mod.m_editing)
			{
				if (!mod.m_iconHooked)
				{
					mod.m_input.hookEditInput();
				};
				hookSssHandClip(mod.m_sortBtn);
				hookSssHandClip(mod.m_removeBtn);
				hookSssHandClip(mod.m_restoreBtn);
				hookSssHandClip(mod.m_addBtn);
				hookSssHandClip(mod.m_pageBtn);
				hookSssHandClip(mod.m_confirmBtn);
				hookSssHandClip(mod.m_removeAllBtn);
				mod.m_bar.layoutBottomButtons();
				raiseDisplay(mod.m_addPopup);
			};
			raiseDisplay(mod.m_sxpClip);
			raiseDisplay(mod.m_xpBtn);
			raiseDisplay(mod.m_bgBtn);
			raiseDisplay(mod.m_uploadBtn);
			raiseDisplay(mod.m_editBtn);
			raiseHand();
			if (mod.m_handClip && mod.m_editBtn && mod.m_handClip.parent && mod.m_handClip.parent == mod.m_editBtn.parent)
			{
				try
				{
					mod.m_handClip["mouseEnabled"] = false;
					mod.m_handClip["mouseChildren"] = false;
				}
				catch (handMouseErr:*)
				{
				};
				mod.m_handClip.parent.setChildIndex(mod.m_handClip, mod.m_handClip.parent.numChildren - 1);
			};
		}

		internal function findIcon(icons:DisplayObjectContainer, id:String):DisplayObject
		{
			var i:int;
			var child:DisplayObject;
			i = 0;
			while (i < icons.numChildren)
			{
				child = icons.getChildAt(i);
				if (readStageId(child) == id)
				{
					return (child);
				};
				i++;
			};
			return (null);
		}

		internal function readStageId(child:DisplayObject):String
		{
			if (!child)
			{
				return ("");
			};
			try
			{
				if (child["stageID"])
				{
					return (String(child["stageID"]));
				};
			}
			catch (err:*)
			{
			};
			if (child.name && child.name != "")
			{
				return (child.name);
			};
			return ("");
		}

		private function spawnStageIcon(icons:DisplayObjectContainer, id:String, cellW:Number, cellH:Number):DisplayObject
		{
			var mc:MovieClip;
			var w:Number;
			var h:Number;
			if (!id || id == "xpstage")
			{
				return (null);
			};
			mc = EditorEngine.libraryMC(id + "_stage_select");
			if (!mc)
			{
				w = cellW > 8 ? cellW : StageEditorMod.ADD_TILE_W;
				h = cellH > 28 ? cellH : StageEditorMod.ADD_TILE_H;
				mc = new MovieClip();
				mc.name = id;
				mc.graphics.beginFill(0x2A2A36, 1);
				mc.graphics.lineStyle(1, 0xE8A020, 0.85);
				mc.graphics.drawRoundRect(-w * 0.5, -h * 0.5, w - 2, h - 2, 4, 4);
				mc.graphics.endFill();
				mc.addChild(mod.m_catalog.makeStageTileLabel(id, w - 4, h - 4, -w * 0.5 + 2, -h * 0.5 + 2));
			}
			else
			{
				try
				{
					mc.gotoAndStop(1);
				}
				catch (err:*)
				{
				};
			};
			try
			{
				mc["stageID"] = id;
			}
			catch (idErr:*)
			{
			};
			icons.addChild(mc);
			m_spawnedIds[id] = true;
			return (mc);
		}

		private function hideClip(child:DisplayObject):void
		{
			if (!child)
			{
				return;
			};
			child.visible = false;
			try
			{
				child["mouseEnabled"] = false;
			}
			catch (err:*)
			{
			};
		}

		private function bindStageButton(menu:*, child:DisplayObject, id:String):void
		{
			var SB:Class;
			var game:*;
			var btn:*;
			var prev:Object;
			var hand:*;
			if (!menu || !child || !id || !(child is MovieClip))
			{
				return;
			};
			prev = m_stageBtns[id] as Object;
			if (prev && prev.clip == child)
			{
				return;
			};
			try
			{
				SB = EngineRefs.ssf2("controllers.StageButton") as Class;
				game = mod.m_extra.resolveStageGame();
				if (!SB || !game)
				{
					return;
				};
				btn = new SB(game, child as MovieClip, id);
				btn.makeEvents();
				hand = sssHand();
				m_stageBtns[id] = {
					"clip": child,
					"btn": btn
				};
				try
				{
					if (hand && hand["ensureStageButton"])
					{
						hand["ensureStageButton"](btn);
					};
				}
				catch (handErr:*)
				{
				};
			}
			catch (err:*)
			{
			};
		}

		private function hideEnginePager(menu:*):void
		{
			var sub:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			var tf:TextField;
			var host:DisplayObjectContainer;
			var inner:DisplayObject;
			var label:String;
			sub = resolveSubMenu(menu) as DisplayObjectContainer;
			if (!sub)
			{
				return;
			};
			i = 0;
			while (i < sub.numChildren)
			{
				child = sub.getChildAt(i);
				if (child == mod.m_sxpWrap || child == mod.m_sxpClip || child == mod.m_xpBtn || child == mod.m_addPopup || child == mod.m_editBtn || child == mod.m_bgBtn || child == mod.m_sortBtn || child == mod.m_removeBtn || child == mod.m_restoreBtn || child == mod.m_addBtn || child == mod.m_pageBtn || child == mod.m_confirmBtn || child == mod.m_removeAllBtn)
				{
					i++;
					continue;
				};
				tf = child as TextField;
				if (tf && tf.text && tf.text.indexOf(" - ") >= 0 && tf.width <= 100)
				{
					tf.visible = false;
					tf.mouseEnabled = false;
					i++;
					continue;
				};
				host = child as DisplayObjectContainer;
				if (host && host.numChildren == 1 && child.width <= 36 && child.height <= 30)
				{
					inner = host.getChildAt(0);
					tf = inner as TextField;
					label = tf ? tf.text : "";
					if (label == "<" || label == ">")
					{
						child.visible = false;
						try
						{
							child["mouseEnabled"] = false;
							child["mouseChildren"] = false;
						}
						catch (mouseErr:*)
						{
						};
					};
				};
				i++;
			};
		}
	}
}
