package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	/**
	 * Edit-mode input on Stage Select: mouse and gamepad drag and drop of stage icons, drop
	 * cells, and adding a stage to the current page.
	 */
	public class StageEditInput
	{
		private static const DRAG_PX:int = 5;

		private var mod:StageEditorMod;
		private var m_gamepadDrag:Boolean;
		private var m_gamepadSelectLetGo:Boolean;
		private var m_dragStart:Point;
		private var m_dragOrig:Point;
		private var m_lastClickId:String;

		public function StageEditInput(owner:StageEditorMod)
		{
			mod = owner;
			m_gamepadDrag = false;
			m_gamepadSelectLetGo = true;
			m_lastClickId = "";
		}

		internal function hookEditInput():void
		{
			var icons:DisplayObjectContainer;
			if (mod.m_iconHooked)
			{
				return;
			};
			icons = mod.m_layout.liveIcons();
			if (!icons)
			{
				return;
			};
			icons.addEventListener(MouseEvent.MOUSE_DOWN, onGridMouseDown, true, 80);
			icons.addEventListener(MouseEvent.CLICK, onGridClickBlock, true, 80);
			mod.m_iconHooked = true;
		}

		internal function unhookEditInput():void
		{
			var icons:DisplayObjectContainer;
			if (!mod.m_iconHooked)
			{
				return;
			};
			icons = mod.m_layout.liveIcons();
			if (icons)
			{
				icons.removeEventListener(MouseEvent.MOUSE_DOWN, onGridMouseDown, true);
				icons.removeEventListener(MouseEvent.CLICK, onGridClickBlock, true);
			};
			mod.m_iconHooked = false;
		}

		private function onGridClickBlock(e:MouseEvent):void
		{
			if (mod.m_editing)
			{
				e.stopImmediatePropagation();
			};
		}

		private function onGridMouseDown(e:MouseEvent):void
		{
			var id:String;
			var clip:DisplayObject;
			if (!mod.m_editing)
			{
				return;
			};
			clip = iconFromEvent(e);
			id = mod.m_layout.readStageId(clip);
			if (!id || id == "xpstage" || id == "sxp")
			{
				return;
			};
			e.stopImmediatePropagation();
			if (mod.m_mode == StageEditorMod.MODE_SORT)
			{
				beginDrag(id, clip, false, e);
			}
			else if (mod.m_mode == StageEditorMod.MODE_REMOVE)
			{
				mod.m_book.toggleRemoveId(id);
			};
		}

		internal function notifyPageFull():void
		{
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("This page is full (" + StageEditorMod.MAX_ROWS + " rows, " + StageEditorMod.MAX_COLS + " per row).");
				};
			}
			catch (err:*)
			{
			};
		}

		internal function addStageToPage(id:String):void
		{
			var rows:Array;
			if (!id || GridRows.isPinned(id) && GridRows.inRows(mod.m_book.pageRows(mod.m_livePage), id))
			{
				return;
			};
			if (GridRows.inRows(mod.m_book.pageRows(mod.m_livePage), id))
			{
				return;
			};
			rows = GridRows.cloneRows(mod.m_book.pageRows(mod.m_livePage));
			if (rows.length < 1)
			{
				rows = [[]];
			};
			if (!GridRows.tryAdd(rows, id, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS))
			{
				notifyPageFull();
				return;
			};
			GridRows.overflow(rows, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS);
			mod.m_book.setPageRows(mod.m_livePage, rows);
			mod.m_store.applyGrid(true);
			if (mod.m_allowTraining)
			{
				mod.m_store.revealTrainingStage(id);
			};
			mod.m_addUi.rebuildBench();
		}

		private function beginDrag(id:String, clip:DisplayObject, fromBench:Boolean, e:MouseEvent):void
		{
			m_gamepadDrag = false;
			beginDragAt(id, clip, fromBench, e.stageX, e.stageY);
		}

		private function beginDragAt(id:String, clip:DisplayObject, fromBench:Boolean, stageX:Number, stageY:Number):void
		{
			if (!clip)
			{
				return;
			};
			mod.m_dragId = id;
			mod.m_dragClip = clip;
			mod.m_dragFromBench = fromBench;
			mod.m_dragging = false;
			m_dragStart = new Point(stageX, stageY);
			m_dragOrig = new Point(clip.x, clip.y);
		}

		private function beginGamepadDrag(id:String):void
		{
			var clip:DisplayObject;
			var pt:Point;
			if (!id || m_gamepadDrag || mod.m_dragId)
			{
				return;
			};
			clip = mod.m_layout.findIcon(mod.m_layout.liveIcons(), id);
			pt = handStagePoint();
			if (!clip || !pt)
			{
				return;
			};
			m_gamepadDrag = true;
			beginDragAt(id, clip, false, pt.x, pt.y);
		}

		private function extraBarUnderHand():Boolean
		{
			var pt:Point;
			var btns:Array;
			var i:int;
			var btn:DisplayObject;
			var bounds:Rectangle;
			pt = handStagePoint();
			if (!pt)
			{
				return (false);
			};
			btns = [mod.m_editBtn, mod.m_bgBtn, mod.m_sortBtn, mod.m_removeBtn, mod.m_restoreBtn, mod.m_addBtn, mod.m_pageBtn, mod.m_confirmBtn, mod.m_removeAllBtn];
			i = 0;
			while (i < btns.length)
			{
				btn = btns[i] as DisplayObject;
				if (btn && btn.visible && btn.stage)
				{
					bounds = btn.getBounds(btn.stage);
					if (bounds.containsPoint(pt))
					{
						return (true);
					};
				};
				i++;
			};
			return (false);
		}

		private function stageIdUnderHand():String
		{
			var icons:DisplayObjectContainer;
			var pt:Point;
			var i:int;
			var child:DisplayObject;
			var id:String;
			var bounds:Rectangle;
			icons = mod.m_layout.liveIcons();
			pt = handStagePoint();
			if (!icons || !pt)
			{
				return ("");
			};
			i = icons.numChildren - 1;
			while (i >= 0)
			{
				child = icons.getChildAt(i);
				id = mod.m_layout.readStageId(child);
				if (child && child.visible && id && id != "xpstage" && id != "sxp")
				{
					try
					{
						bounds = child.getBounds(child.stage);
						if (bounds.containsPoint(pt))
						{
							return (id);
						};
					}
					catch (err:*)
					{
					};
				};
				i--;
			};
			return ("");
		}

		private function handStagePoint():Point
		{
			var hand:*;
			var mc:DisplayObject;
			hand = mod.m_layout.sssHand();
			try
			{
				mc = hand ? ((hand["HandMC"] as DisplayObject) || (hand["Hand"] as DisplayObject)) : null;
			}
			catch (err:*)
			{
				mc = null;
			};
			if (!mc)
			{
				mc = mod.m_sxpUi.findSelectHand(mod.m_layout.resolveSubMenu(null) as DisplayObjectContainer);
			};
			if (!mc)
			{
				return (null);
			};
			return (mc.localToGlobal(new Point(0, 0)));
		}

		private function dragToward(stageX:Number, stageY:Number):void
		{
			var pt:Point;
			if (!mod.m_editing || !mod.m_dragClip || !mod.m_dragId)
			{
				return;
			};
			if (!mod.m_dragging)
			{
				if (Point.distance(m_dragStart, new Point(stageX, stageY)) < DRAG_PX)
				{
					return;
				};
				mod.m_dragging = true;
				mod.m_sortPickId = "";
				mod.m_dragClip.alpha = 0.85;
				if (mod.m_dragClip.parent)
				{
					try
					{
						mod.m_dragClip.parent.setChildIndex(mod.m_dragClip, mod.m_dragClip.parent.numChildren - 1);
					}
					catch (zErr:*)
					{
					};
				};
			};
			pt = mod.m_dragClip.parent ? mod.m_dragClip.parent.globalToLocal(new Point(stageX, stageY)) : new Point(stageX, stageY);
			mod.m_dragClip.x = pt.x;
			mod.m_dragClip.y = pt.y;
		}

		internal function onEditMouseMove(e:MouseEvent):void
		{
			if (m_gamepadDrag)
			{
				return;
			};
			dragToward(e.stageX, e.stageY);
		}

		internal function onEditMouseUp(e:MouseEvent):void
		{
			if (m_gamepadDrag)
			{
				return;
			};
			finishDrag(e.stageX, e.stageY);
		}

		private function finishDrag(stageX:Number, stageY:Number):void
		{
			var id:String;
			if (!mod.m_editing || !mod.m_dragId)
			{
				return;
			};
			id = mod.m_dragId;
			if (mod.m_dragging)
			{
				if (!applyLiveDrop(id, mod.m_dragFromBench, stageX, stageY) && mod.m_dragClip && m_dragOrig)
				{
					mod.m_dragClip.x = m_dragOrig.x;
					mod.m_dragClip.y = m_dragOrig.y;
				};
				m_lastClickId = "";
				mod.m_sortPickId = "";
			}
			else
			{
				if (mod.m_dragClip)
				{
					mod.m_dragClip.x = m_dragOrig.x;
					mod.m_dragClip.y = m_dragOrig.y;
					mod.m_dragClip.alpha = 1;
				};
				if (mod.m_mode == StageEditorMod.MODE_SORT)
				{
					mod.m_book.sortClick(id);
				};
			};
			endDrag(false);
		}

		internal function pollGamepadEdit():void
		{
			var pt:Point;
			var id:String;
			var held:Boolean;
			if (!mod.m_editing)
			{
				if (m_gamepadDrag)
				{
					endDrag(true);
				};
				return;
			};
			held = mod.m_sxpUi.sxpSelectHeld();
			if (mod.m_mode == StageEditorMod.MODE_REMOVE)
			{
				if (m_gamepadDrag)
				{
					endDrag(true);
				};
				if (!held)
				{
					m_gamepadSelectLetGo = true;
					return;
				};
				if (!m_gamepadSelectLetGo || extraBarUnderHand())
				{
					return;
				};
				id = stageIdUnderHand();
				if (!id)
				{
					return;
				};
				m_gamepadSelectLetGo = false;
				mod.m_book.toggleRemoveId(id);
				return;
			};
			if (mod.m_mode != StageEditorMod.MODE_SORT)
			{
				if (m_gamepadDrag)
				{
					endDrag(true);
				};
				return;
			};
			if (mod.m_dragId && !m_gamepadDrag)
			{
				return;
			};
			held = mod.m_sxpUi.sxpSelectHeld();
			pt = handStagePoint();
			if (m_gamepadDrag)
			{
				if (held)
				{
					if (pt)
					{
						dragToward(pt.x, pt.y);
					};
				}
				else if (pt)
				{
					finishDrag(pt.x, pt.y);
				}
				else
				{
					endDrag(true);
				};
				return;
			};
			if (!held)
			{
				m_gamepadSelectLetGo = true;
				return;
			};
			if (!m_gamepadSelectLetGo || extraBarUnderHand())
			{
				return;
			};
			id = stageIdUnderHand();
			if (!id)
			{
				return;
			};
			m_gamepadSelectLetGo = false;
			beginGamepadDrag(id);
		}

		internal function endDrag(resetPos:Boolean):void
		{
			if (resetPos && mod.m_dragClip && m_dragOrig)
			{
				mod.m_dragClip.x = m_dragOrig.x;
				mod.m_dragClip.y = m_dragOrig.y;
			};
			if (mod.m_dragClip)
			{
				mod.m_dragClip.alpha = 1;
			};
			mod.m_dragId = "";
			mod.m_dragClip = null;
			mod.m_dragging = false;
			m_gamepadDrag = false;
			mod.m_dragFromBench = false;
		}

		private function applyLiveDrop(id:String, fromBench:Boolean, stageX:Number, stageY:Number):Boolean
		{
			var rows:Array;
			var cell:Object;
			if (!id)
			{
				return (false);
			};
			cell = liveCellAt(stageX, stageY);
			if (!cell)
			{
				return (false);
			};
			rows = GridRows.cloneRows(mod.m_book.pageRows(mod.m_livePage));
			GridRows.moveId(rows, id, int(cell.row), int(cell.col), String(cell.mode) == "newrow", !fromBench, StageEditorMod.MAX_ROWS);
			GridRows.overflow(rows, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS);
			mod.m_book.setPageRows(mod.m_livePage, rows);
			mod.m_store.applyGrid(true);
			return (true);
		}

		internal function liveCellAt(stageX:Number, stageY:Number):Object
		{
			var icons:DisplayObjectContainer;
			var mappings:Object;
			var block:Object;
			var rows:Array;
			var pos:Object;
			var size:Object;
			var pt:Point;
			var r:int;
			var c:int;
			var maxCols:int;
			var shift:Number;
			var vis:Array;
			var localX:Number;
			var localY:Number;
			var newRowY:Number;
			icons = mod.m_layout.liveIcons();
			mappings = EditorEngine.mappings();
			if (!icons || !mappings)
			{
				return (null);
			};
			block = mod.m_book.pageBlock(mappings);
			rows = block ? (block._rows as Array) : null;
			pos = block ? block._pos : null;
			size = block ? block._size : null;
			if (!rows || !pos || !size)
			{
				return (null);
			};
			pt = icons.globalToLocal(new Point(stageX, stageY));
			localX = pt.x;
			localY = pt.y;
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
			newRowY = Number(pos.y) + Number(size.height) * rows.length;
			if (localY >= newRowY - 4 && rows.length < StageEditorMod.MAX_ROWS)
			{
				return ({
					"row": rows.length,
					"col": 0,
					"mode": "newrow"
				});
			};
			if (localY >= newRowY - 4 && rows.length > 0)
			{
				vis = rows[rows.length - 1] as Array;
				return ({
					"row": rows.length - 1,
					"col": vis ? vis.length : 0,
					"mode": "insert"
				});
			};
			r = int(Math.floor((localY - Number(pos.y) + Number(size.height) * 0.5) / Number(size.height)));
			if (r < 0 || r >= rows.length)
			{
				return (null);
			};
			vis = (rows[r] as Array) || [];
			shift = (maxCols - vis.length) * Number(size.width) * 0.5;
			c = int(Math.round((localX - Number(pos.x) - shift) / Number(size.width)));
			if (c < 0)
			{
				c = 0;
			};
			if (c > vis.length)
			{
				c = vis.length;
			};
			if (c > StageEditorMod.MAX_COLS)
			{
				c = StageEditorMod.MAX_COLS;
			};
			return ({
				"row": r,
				"col": c,
				"mode": "insert"
			});
		}

		private function iconFromEvent(e:MouseEvent):DisplayObject
		{
			var icons:DisplayObjectContainer;
			var cur:DisplayObject;
			icons = mod.m_layout.liveIcons();
			cur = e.target as DisplayObject;
			while (cur && cur != icons)
			{
				if (cur.parent == icons)
				{
					return (cur);
				};
				cur = cur.parent;
			};
			return (null);
		}
	}
}
