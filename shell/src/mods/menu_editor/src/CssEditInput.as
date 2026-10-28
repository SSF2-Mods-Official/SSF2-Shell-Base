package
{
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Edit-mode input on Character Select: bar button clicks, mouse drag and drop of portraits,
	 * hit tests for cells, icons, and page tiles, and the gamepad hand driving the same actions.
	 */
	public class CssEditInput
	{
		private static const DRAG_PX:int = 5;

		private var mod:CssEditorMod;
		private var m_dragStart:Point;
		private var m_gamepadLetGo:Boolean;

		public function CssEditInput(owner:CssEditorMod)
		{
			mod = owner;
			m_gamepadLetGo = true;
		}

		private function notifyRowLimit():void
		{
			var MM:*;
			try
			{
				MM = EngineRefs.MultiplayerManager;
				MM["notify"]("Hard limit of " + CssEditorMod.MAX_ROWS + " rows on this Character Select page.");
			}
			catch (err:*)
			{
				mod.cssLog("row limit notify failed");
			};
		}

		internal function onEditClick(e:MouseEvent):void
		{
			mod.cssLog("edit click editing=" + (mod.m_editing ? 1 : 0));
			if (mod.m_editing)
			{
				mod.exitLiveEdit(false);
			}
			else
			{
				mod.enterLiveEdit();
			};
		}

		internal function onSortClick(e:MouseEvent):void
		{
			mod.m_mode = CssEditorMod.MODE_SORT;
			mod.m_addUi.closeAddPopup();
			mod.m_chrome.layoutBar();
		}

		internal function onAddClick(e:MouseEvent):void
		{
			if (mod.m_mode == CssEditorMod.MODE_ADD && mod.m_addPopup)
			{
				mod.m_addUi.closeAddPopup();
				mod.m_mode = CssEditorMod.MODE_SORT;
			}
			else
			{
				mod.m_mode = CssEditorMod.MODE_ADD;
				mod.m_addUi.openAddPopup();
			};
			mod.m_chrome.layoutBar();
		}

		internal function onRemoveClick(e:MouseEvent):void
		{
			mod.m_mode = CssEditorMod.MODE_REMOVE;
			mod.m_removeIds = {};
			mod.m_addUi.closeAddPopup();
			mod.m_chrome.layoutBar();
		}

		internal function onRestoreClick(e:MouseEvent):void
		{
			mod.m_roster.onRestore();
			mod.m_chrome.layoutBar();
		}

		internal function onConfirmClick(e:MouseEvent):void
		{
			var rows:Array;
			var mappings:Object;
			var next:Array;
			var r:int;
			var c:int;
			var line:Array;
			var id:String;
			var kept:Array;
			var dropRandom:Boolean;
			if (!hasRemoveSelection())
			{
				return;
			};
			mappings = EditorEngine.mappings();
			rows = mappings ? GridRows.cloneRows(mappings.character_select_screen.rows as Array) : null;
			if (!rows)
			{
				return;
			};
			dropRandom = Boolean(mod.m_removeIds["random"]) && mod.m_paging.characterRemains(rows, mod.m_removeIds);
			next = [];
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				kept = [];
				c = 0;
				while (line && c < line.length)
				{
					id = String(line[c]);
					if (!mod.m_removeIds[id] || mod.m_paging.isPageNav(id) || (GridRows.isPinned(id) && !(id == "random" && dropRandom)))
					{
						kept.push(id);
					};
					c++;
				};
				if (kept.length > 0)
				{
					next.push(kept);
				};
				r++;
			};
			if (!dropRandom && !GridRows.inRows(next, "random"))
			{
				next.push(["random"]);
			};
			mod.m_roster.applyRows(next, true);
			mod.m_removeIds = {};
			mod.m_mode = CssEditorMod.MODE_SORT;
			mod.m_chrome.layoutBar();
		}

		internal function onRemoveAllClick(e:MouseEvent):void
		{
			mod.m_roster.applyRows([mod.m_paging.pageCount() > 1 ? ["random", CssEditorMod.PAGE_PREV, CssEditorMod.PAGE_NEXT] : ["random"]], true);
			mod.m_removeIds = {};
			mod.m_mode = CssEditorMod.MODE_SORT;
			mod.m_chrome.layoutBar();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("Cleared this roster. Random kept.");
				};
			}
			catch (err:*)
			{
			};
		}

		internal function hasRemoveSelection():Boolean
		{
			var id:String;
			if (!mod.m_removeIds)
			{
				return (false);
			};
			for (id in mod.m_removeIds)
			{
				if (mod.m_removeIds[id] && (!GridRows.isPinned(id) || id == "random"))
				{
					return (true);
				};
			};
			return (false);
		}

		internal function onEditMouseDown(e:MouseEvent):void
		{
			var id:String;
			if (!mod.m_editing || isBarTarget(e.target as DisplayObject))
			{
				return;
			};
			id = iconIdAt(e.stageX, e.stageY);
			if (!id)
			{
				return;
			};
			e.stopImmediatePropagation();
			if (mod.m_mode == CssEditorMod.MODE_REMOVE)
			{
				if (mod.m_paging.canMarkForRemove(id))
				{
					mod.m_removeIds[id] = !mod.m_removeIds[id];
				};
				mod.m_chrome.layoutBar();
				return;
			};
			if (mod.m_mode != CssEditorMod.MODE_SORT)
			{
				return;
			};
			mod.m_dragId = id;
			mod.m_dragging = false;
			m_dragStart = new Point(e.stageX, e.stageY);
		}

		internal function onEditMouseMove(e:MouseEvent):void
		{
			if (mod.m_gamepadDrag)
			{
				return;
			};
			dragToward(e.stageX, e.stageY);
		}

		internal function onEditMouseUp(e:MouseEvent):void
		{
			if (mod.m_gamepadDrag)
			{
				return;
			};
			finishDrag(e.stageX, e.stageY);
		}

		private function dragToward(stageX:Number, stageY:Number):void
		{
			var child:DisplayObject;
			var pt:Point;
			if (!mod.m_editing || mod.m_dragId == "" || !m_dragStart)
			{
				return;
			};
			if (!mod.m_dragging && Point.distance(m_dragStart, new Point(stageX, stageY)) >= DRAG_PX)
			{
				mod.m_dragging = true;
			};
			if (!mod.m_dragging || !mod.m_icons)
			{
				return;
			};
			child = iconClip(mod.m_dragId);
			if (!child)
			{
				return;
			};
			child.visible = true;
			mod.m_layout.raiseIcon(child);
			try
			{
				pt = mod.m_icons.globalToLocal(new Point(stageX, stageY));
				child.x = pt.x;
				child.y = pt.y;
			}
			catch (err:*)
			{
			};
		}

		private function finishDrag(stageX:Number, stageY:Number):void
		{
			var id:String;
			var cell:Object;
			if (!mod.m_editing || mod.m_dragId == "")
			{
				mod.m_dragId = "";
				mod.m_dragging = false;
				mod.m_gamepadDrag = false;
				return;
			};
			id = mod.m_dragId;
			try
			{
				if (!mod.m_dragging && mod.m_paging.isPageNav(id))
				{
					mod.m_paging.activatePageTile(id);
				}
				else if (mod.m_dragging)
				{
					cell = cellAt(stageX, stageY);
					if (cell)
					{
						dropIcon(id, cell);
					};
				};
			}
			catch (err:*)
			{
			};
			mod.m_dragId = "";
			mod.m_dragging = false;
			mod.m_gamepadDrag = false;
		}

		private function dropIcon(id:String, cell:Object):void
		{
			var mappings:Object;
			var rows:Array;
			var line:Array;
			var srcRow:int;
			var srcCol:int;
			var rowIndex:int;
			var col:int;
			var sole:Boolean;
			var r:int;
			mappings = EditorEngine.mappings();
			if (!mappings)
			{
				return;
			};
			rows = GridRows.cloneRows(mappings.character_select_screen.rows as Array);
			srcRow = -1;
			srcCol = -1;
			sole = false;
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				if (line && line.indexOf(id) >= 0)
				{
					srcRow = r;
					srcCol = line.indexOf(id);
					sole = line.length == 1;
					break;
				};
				r++;
			};
			GridRows.removeId(rows, id, true);
			rowIndex = int(cell.row);
			if (sole && srcRow >= 0 && srcRow < rowIndex)
			{
				rowIndex--;
			};
			if (String(cell.mode) == "newrow")
			{
				if (rows.length >= CssEditorMod.MAX_ROWS)
				{
					mod.cssLog("row limit rows=" + rows.length);
					notifyRowLimit();
					return;
				};
				rows.push([id]);
			}
			else
			{
				while (rows.length <= rowIndex)
				{
					if (rows.length >= CssEditorMod.MAX_ROWS)
					{
						mod.cssLog("row limit rows=" + rows.length);
						notifyRowLimit();
						return;
					};
					rows.push([]);
				};
				line = rows[rowIndex] as Array;
				if (!line)
				{
					line = [];
					rows[rowIndex] = line;
				};
				col = int(cell.col);
				if (!sole && srcRow == int(cell.row) && srcCol >= 0 && srcCol < col)
				{
					col--;
				};
				if (col < 0)
				{
					col = 0;
				};
				if (col >= line.length)
				{
					line.push(id);
				}
				else
				{
					line.splice(col, 0, id);
				};
			};
			mod.m_roster.applyRows(rows, true);
		}

		internal function cellAt(stageX:Number, stageY:Number):Object
		{
			var pt:Point;
			var mappings:Object;
			var rows:Array;
			var r:int;
			var c:int;
			var vis:Array;
			var gridBottom:Number;
			var rowRight:Number;
			var shift:Number;
			var rowLeft:Number;
			var n:int;
			if (!mod.m_icons || mod.m_cell <= 0 || !mod.m_icons.stage)
			{
				return (null);
			};
			mappings = EditorEngine.mappings();
			rows = mappings ? (mappings.character_select_screen.rows as Array) : null;
			if (!rows)
			{
				return (null);
			};
			try
			{
				pt = mod.m_icons.globalToLocal(new Point(stageX, stageY));
			}
			catch (err:*)
			{
				return (null);
			};
			gridBottom = mod.m_originY + rows.length * mod.m_cell;
			if (pt.y >= gridBottom && pt.y < gridBottom + mod.m_cell && pt.x >= mod.m_originX - 8 && pt.x <= mod.m_originX + mod.m_maxCols * mod.m_cell + 8)
			{
				return ({"mode": "newrow", "row": rows.length, "col": 0});
			};
			if (pt.y < mod.m_originY || pt.y >= gridBottom)
			{
				return (null);
			};
			r = int(Math.floor((pt.y - mod.m_originY) / mod.m_cell));
			if (r < 0 || r >= rows.length)
			{
				return (null);
			};
			vis = (rows[r] as Array) || [];
			n = mod.m_layout.portraitLen(vis);
			shift = (mod.m_maxCols - n) * mod.m_cell * 0.5;
			rowLeft = mod.m_originX + shift;
			rowRight = rowLeft + n * mod.m_cell;
			if (pt.x < rowLeft - mod.m_cell * 0.25 || pt.x > rowRight + mod.m_cell * 0.5)
			{
				return (null);
			};
			c = int(Math.round((pt.x - rowLeft) / mod.m_cell));
			if (c < 0)
			{
				c = 0;
			};
			if (c > vis.length)
			{
				c = vis.length;
			};
			return ({"mode": "insert", "row": r, "col": c});
		}

		private function pageTileAt(stageX:Number, stageY:Number):String
		{
			var id:String;
			var clip:Sprite;
			var local:Point;
			if (!mod.m_pageClips || mod.m_paging.pageCount() <= 1)
			{
				return ("");
			};
			for (id in mod.m_pageClips)
			{
				clip = mod.m_pageClips[id] as Sprite;
				if (!clip || !clip.visible || !clip.stage)
				{
					continue;
				};
				try
				{
					local = clip.globalToLocal(new Point(stageX, stageY));
				}
				catch (err:*)
				{
					continue;
				};
				if (local.x >= -21 && local.x < 21 && local.y >= -21 && local.y < 21)
				{
					return (id);
				};
			};
			return ("");
		}

		private function iconIdAt(stageX:Number, stageY:Number):String
		{
			var mappings:Object;
			var rows:Array;
			var line:Array;
			var cell:Object;
			var col:int;
			var pageId:String;
			pageId = pageTileAt(stageX, stageY);
			if (pageId)
			{
				return (pageId);
			};
			cell = cellAt(stageX, stageY);
			if (!cell || String(cell.mode) == "newrow")
			{
				return ("");
			};
			mappings = EditorEngine.mappings();
			rows = mappings ? (mappings.character_select_screen.rows as Array) : null;
			if (!rows || int(cell.row) < 0 || int(cell.row) >= rows.length)
			{
				return ("");
			};
			line = rows[int(cell.row)] as Array;
			col = int(cell.col);
			if (!line || col < 0 || col >= line.length)
			{
				return ("");
			};
			return (String(line[col]));
		}

		internal function iconClip(id:String):DisplayObject
		{
			var hash:Object;
			if (mod.m_pageClips && mod.m_pageClips[id])
			{
				return (mod.m_pageClips[id] as DisplayObject);
			};
			if (!mod.m_menu)
			{
				return (null);
			};
			try
			{
				hash = mod.m_menu.CharMCHash as Object;
			}
			catch (err:*)
			{
				hash = null;
			};
			return (hash ? (hash[id] as DisplayObject) : null);
		}

		private function isBarTarget(target:DisplayObject):Boolean
		{
			var node:DisplayObject;
			node = target;
			while (node)
			{
				if (node == mod.m_editBtn || node == mod.m_sortBtn || node == mod.m_addBtn || node == mod.m_removeBtn || node == mod.m_restoreBtn || node == mod.m_confirmBtn || node == mod.m_removeAllBtn || node == mod.m_addPopup)
				{
					return (true);
				};
				node = node.parent;
			};
			return (false);
		}

		internal function pollGamepadEdit():void
		{
			var pt:Point;
			var held:Boolean;
			var id:String;
			held = attackHeld();
			pt = handStagePoint();
			if (!mod.m_editing)
			{
				pollGamepadBrowse(pt, held);
				return;
			};
			if (mod.m_mode != CssEditorMod.MODE_SORT)
			{
				pollGamepadPick(pt, held);
				return;
			};
			if (mod.m_dragId != "" && !mod.m_gamepadDrag)
			{
				return;
			};
			if (mod.m_gamepadDrag)
			{
				if (held && pt)
				{
					dragToward(pt.x, pt.y);
				}
				else if (!held)
				{
					finishDrag(pt ? pt.x : 0, pt ? pt.y : 0);
				};
				return;
			};
			if (!gamepadPressStarts(pt, held) || pressBarAt(pt))
			{
				return;
			};
			id = iconIdAt(pt.x, pt.y);
			if (!id)
			{
				return;
			};
			m_gamepadLetGo = false;
			mod.m_gamepadDrag = true;
			mod.m_dragId = id;
			mod.m_dragging = false;
			m_dragStart = new Point(pt.x, pt.y);
		}

		/** Not editing: a fresh press clicks a bar button or a page arrow under the hand. */
		private function pollGamepadBrowse(pt:Point, held:Boolean):void
		{
			var id:String;
			if (mod.m_gamepadDrag)
			{
				finishDrag(pt ? pt.x : 0, pt ? pt.y : 0);
			};
			if (!gamepadPressStarts(pt, held) || pressBarAt(pt))
			{
				return;
			};
			id = iconIdAt(pt.x, pt.y);
			if (mod.m_paging.isPageNav(id))
			{
				m_gamepadLetGo = false;
				mod.m_paging.activatePageTile(id);
			};
		}

		/** Add or Remove mode: a fresh press clicks a bar button, toggles a remove mark, or adds a tile. */
		private function pollGamepadPick(pt:Point, held:Boolean):void
		{
			var id:String;
			if (mod.m_gamepadDrag)
			{
				finishDrag(pt ? pt.x : 0, pt ? pt.y : 0);
			};
			if (!gamepadPressStarts(pt, held) || pressBarAt(pt))
			{
				return;
			};
			if (mod.m_mode == CssEditorMod.MODE_REMOVE)
			{
				id = iconIdAt(pt.x, pt.y);
				if (mod.m_paging.canMarkForRemove(id))
				{
					m_gamepadLetGo = false;
					mod.m_removeIds[id] = !mod.m_removeIds[id];
					mod.m_chrome.layoutBar();
				};
			}
			else if (mod.m_mode == CssEditorMod.MODE_ADD)
			{
				id = addTileAt(pt);
				if (id)
				{
					m_gamepadLetGo = false;
					mod.m_addUi.addCharacter(id);
				};
			};
		}

		/** True on a press that follows a release with the hand on screen; a release re-arms the next press. */
		private function gamepadPressStarts(pt:Point, held:Boolean):Boolean
		{
			if (!held)
			{
				m_gamepadLetGo = true;
				return (false);
			};
			return (m_gamepadLetGo && pt != null);
		}

		/** Clicks the bar button under pt; true when one was there. */
		private function pressBarAt(pt:Point):Boolean
		{
			var btn:Sprite;
			btn = barUnderPoint(pt);
			if (!btn)
			{
				return (false);
			};
			m_gamepadLetGo = false;
			btn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
			return (true);
		}

		private function attackHeld():Boolean
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			try
			{
				SD = EngineRefs.SaveData as Class;
				list = SD["Controllers"];
			}
			catch (err:*)
			{
				return (false);
			};
			if (!list)
			{
				return (false);
			};
			i = 0;
			while (i < list["length"])
			{
				c = list[i];
				try
				{
					if (c && (c.IsDown(c._BUTTON2) || c.IsDown(c._START)))
					{
						return (true);
					};
				}
				catch (cErr:*)
				{
				};
				i++;
			};
			return (false);
		}

		internal function handStagePoint():Point
		{
			var chips:*;
			var i:int;
			var hand:DisplayObject;
			var hb:DisplayObject;
			var chosen:DisplayObject;
			if (!mod.m_menu)
			{
				return (null);
			};
			try
			{
				chips = mod.m_menu.PlayerChips;
			}
			catch (err:*)
			{
				return (null);
			};
			if (!chips)
			{
				return (null);
			};
			chosen = null;
			i = 0;
			while (i < chips.length)
			{
				hand = null;
				try
				{
					hand = chips[i].HandMC as DisplayObject;
				}
				catch (handErr:*)
				{
					hand = null;
				};
				if (hand && hand.stage && hand.visible)
				{
					chosen = hand;
					break;
				};
				i++;
			};
			if (!chosen)
			{
				return (null);
			};
			try
			{
				hb = chosen["hitBox"] as DisplayObject;
			}
			catch (hbErr:*)
			{
				hb = null;
			};
			if (hb)
			{
				return (hb.localToGlobal(new Point(hb.width * 0.5, hb.height * 0.5)));
			};
			return (chosen.localToGlobal(new Point(0, 0)));
		}

		private function barUnderPoint(pt:Point):Sprite
		{
			var btns:Array;
			var i:int;
			var btn:Sprite;
			var bounds:Rectangle;
			if (!pt)
			{
				return (null);
			};
			btns = [mod.m_editBtn, mod.m_sortBtn, mod.m_addBtn, mod.m_removeBtn, mod.m_restoreBtn, mod.m_confirmBtn, mod.m_removeAllBtn];
			if (mod.m_addPopup && mod.m_addPopup.stage)
			{
				btns.push(mod.m_addPopup.getChildByName("addAll"));
				btns.push(mod.m_addPopup.getChildByName("close"));
				btns.push(mod.m_addPopup.getChildByName("prev"));
				btns.push(mod.m_addPopup.getChildByName("next"));
				btns.push(mod.m_addPopup.getChildByName("pageMinus"));
				btns.push(mod.m_addPopup.getChildByName("pagePlus"));
			};
			i = 0;
			while (i < btns.length)
			{
				btn = btns[i] as Sprite;
				if (btn && btn.visible && btn.stage)
				{
					bounds = btn.getBounds(btn.stage);
					if (bounds.containsPoint(pt))
					{
						return (btn);
					};
				};
				i++;
			};
			return (null);
		}

		private function addTileAt(pt:Point):String
		{
			var i:int;
			var child:DisplayObject;
			var local:Point;
			if (!pt || !mod.m_addTray)
			{
				return ("");
			};
			try
			{
				local = mod.m_addTray.globalToLocal(pt);
			}
			catch (err:*)
			{
				return ("");
			};
			i = mod.m_addTray.numChildren - 1;
			while (i >= 0)
			{
				child = mod.m_addTray.getChildAt(i);
				if (child && child.name && local.x >= child.x && local.x < child.x + 42 && local.y >= child.y && local.y < child.y + 42)
				{
					return (child.name);
				};
				i--;
			};
			return ("");
		}
	}
}
