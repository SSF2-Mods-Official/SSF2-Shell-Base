package
{
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.geom.Point;

	/**
	 * Jukebox scrollbar (grid + song list), wheel, and scroll-window clamping.
	 */
	public class MusicUiScroll
	{
		private var ui:MusicPlayerUi;
		private var m_scrollTrackH:Number;
		private var m_scrollThumbH:Number;
		private var m_scrollMax:int;
		private var m_scrollDragging:Boolean;
		private var m_scrollDragOffset:Number;
		private var m_scrollMode:String;

		public function MusicUiScroll(owner:MusicPlayerUi)
		{
			ui = owner;
			m_scrollTrackH = 0;
			m_scrollThumbH = 18;
			m_scrollMax = 0;
			m_scrollDragging = false;
			m_scrollDragOffset = 0;
			m_scrollMode = "grid";
		}

		internal function ensureScrollBar():void
		{
			if (!ui.m_scrollBar)
			{
				ui.m_scrollBar = new Sprite();
				ui.m_scrollBar.buttonMode = true;
				ui.m_scrollBar.useHandCursor = true;
				ui.m_scrollBar.mouseEnabled = true;
				ui.m_scrollBar.mouseChildren = true;
				ui.m_scrollThumb = new Sprite();
				ui.m_scrollThumb.buttonMode = true;
				ui.m_scrollThumb.useHandCursor = true;
				ui.m_scrollBar.addChild(ui.m_scrollThumb);
				ui.m_scrollBar.addEventListener(MouseEvent.MOUSE_DOWN, onScrollTrackDown);
				ui.m_scrollThumb.addEventListener(MouseEvent.MOUSE_DOWN, onScrollThumbDown);
				ui.m_scrollBar.visible = false;
			};
			if (ui.m_scrollBar.parent != ui)
			{
				ui.addChild(ui.m_scrollBar);
			};
		}

		internal function onWheel(e:MouseEvent):void
		{
			if (!ui.m_open)
			{
				return;
			};
			if (ui.m_blockingOverlay || ui.m_helpOverlay)
			{
				return;
			};
			if (ui.m_npBar && ui.m_npBar.expanded)
			{
				return;
			};
			if (e.delta > 0)
			{
				ui.m_input.navVert(-1);
			}
			else if (e.delta < 0)
			{
				ui.m_input.navVert(1);
			};
		}

		internal function paintGridScrollbar(rowsVis:int, rowPitch:int):void
		{
			var totalRows:int;
			var trackH:Number;
			var maxScrollRows:int;
			var scrollRows:int;
			totalRows = Math.max(1, int(Math.ceil(ui.m_gridCells.length / Number(MusicPlayerUi.COLS))));
			if (ui.m_view != MusicPlayerUi.VIEW_GRID || totalRows <= rowsVis)
			{
				hideScrollBar();
				return;
			};
			trackH = rowsVis * rowPitch - MusicPlayerUi.GAP;
			maxScrollRows = Math.max(1, totalRows - rowsVis);
			scrollRows = int(ui.m_gridScroll / MusicPlayerUi.COLS);
			if (scrollRows > maxScrollRows)
			{
				scrollRows = maxScrollRows;
			};
			showScrollBar("grid", trackH, rowsVis / totalRows, scrollRows / maxScrollRows, maxScrollRows);
		}

		internal function paintSongScrollbar():void
		{
			var vis:int;
			var total:int;
			var trackH:Number;
			var maxScroll:int;
			var list:Array;
			list = ui.m_songList.displayList();
			vis = ui.m_songList.visibleSongRows();
			total = list ? list.length : 0;
			if (ui.m_view != MusicPlayerUi.VIEW_SONGS || total <= vis)
			{
				hideScrollBar();
				return;
			};
			trackH = Math.max(40, ui.m_songList.songListBottom() - 78);
			maxScroll = Math.max(1, total - vis);
			showScrollBar("songs", trackH, vis / Number(total), ui.m_songScroll / Number(maxScroll), maxScroll);
		}

		internal function hideScrollBar():void
		{
			ensureScrollBar();
			ui.m_scrollBar.visible = false;
			m_scrollMax = 0;
			if (!m_scrollDragging)
			{
				endScrollDrag();
			};
		}

		private function showScrollBar(mode:String, trackH:Number, visibleRatio:Number, scrollRatio:Number, maxScroll:int):void
		{
			var thumbY:Number;
			ensureScrollBar();
			m_scrollMode = mode;
			m_scrollMax = maxScroll;
			m_scrollTrackH = trackH;
			m_scrollThumbH = Math.max(24, trackH * Math.min(1, visibleRatio));
			if (m_scrollThumbH > trackH)
			{
				m_scrollThumbH = trackH;
			};
			thumbY = (trackH - m_scrollThumbH) * Math.max(0, Math.min(1, scrollRatio));
			ui.m_scrollBar.visible = true;
			ui.m_scrollBar.x = 8;
			ui.m_scrollBar.y = 68;
			ui.m_scrollBar.graphics.clear();
			// Wide invisible hit + visible track (left side).
			ui.m_scrollBar.graphics.beginFill(0xFFFFFF, 0.001);
			ui.m_scrollBar.graphics.drawRect(-2, 0, 20, trackH);
			ui.m_scrollBar.graphics.endFill();
			ui.m_scrollBar.graphics.beginFill(0x2A2A35, 0.55);
			ui.m_scrollBar.graphics.drawRoundRect(0, 0, 12, trackH, 6, 6);
			ui.m_scrollBar.graphics.endFill();
			ui.m_scrollThumb.graphics.clear();
			ui.m_scrollThumb.graphics.beginFill(MusicTheme.ui(), 0.98);
			ui.m_scrollThumb.graphics.drawRoundRect(1, 0, 10, m_scrollThumbH, 5, 5);
			ui.m_scrollThumb.graphics.endFill();
			ui.m_scrollThumb.x = 0;
			if (!m_scrollDragging)
			{
				ui.m_scrollThumb.y = thumbY;
			};
			ui.safeBringToFront(ui.m_scrollBar);
		}

		private function onScrollThumbDown(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!ui.m_scrollBar || !ui.m_scrollBar.visible || m_scrollMax < 1)
			{
				return;
			};
			m_scrollDragging = true;
			// Offset from top of thumb in track coordinates.
			m_scrollDragOffset = ui.m_scrollBar.mouseY - ui.m_scrollThumb.y;
			if (ui.stage)
			{
				ui.stage.addEventListener(MouseEvent.MOUSE_MOVE, onScrollDragMove, false, 0, true);
				ui.stage.addEventListener(MouseEvent.MOUSE_UP, onScrollDragUp, false, 0, true);
			};
		}

		private function onScrollTrackDown(e:MouseEvent):void
		{
			var localY:Number;
			var ratio:Number;
			e.stopPropagation();
			if (!ui.m_scrollBar || !ui.m_scrollBar.visible || m_scrollMax < 1)
			{
				return;
			};
			if (e.target == ui.m_scrollThumb || (e.target is DisplayObject && ui.m_scrollThumb.contains(e.target as DisplayObject)))
			{
				return;
			};
			localY = ui.m_scrollBar.mouseY - m_scrollThumbH * 0.5;
			ratio = localY / Math.max(1, m_scrollTrackH - m_scrollThumbH);
			applyScrollRatio(ratio, true);
			ui.playUiSfx("menu_hover");
			onScrollThumbDown(e);
		}

		private function onScrollDragMove(e:MouseEvent):void
		{
			var localY:Number;
			var travel:Number;
			var ratio:Number;
			var local:Point;
			if (!m_scrollDragging || !ui.m_scrollBar)
			{
				return;
			};
			travel = Math.max(1, m_scrollTrackH - m_scrollThumbH);
			// Stage coords — bar.mouseY freezes once the cursor leaves the thin track.
			local = ui.m_scrollBar.globalToLocal(new Point(e.stageX, e.stageY));
			localY = local.y - m_scrollDragOffset;
			if (localY < 0)
			{
				localY = 0;
			};
			if (localY > travel)
			{
				localY = travel;
			};
			ui.m_scrollThumb.y = localY;
			ratio = localY / travel;
			// Repaint list while dragging (thumb y preserved while m_scrollDragging).
			applyScrollRatio(ratio, true);
		}

		private function onScrollDragUp(e:MouseEvent):void
		{
			endScrollDrag();
			if (ui.m_open)
			{
				ui.paint();
			};
		}

		internal function endScrollDrag():void
		{
			m_scrollDragging = false;
			if (ui.stage)
			{
				ui.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onScrollDragMove);
				ui.stage.removeEventListener(MouseEvent.MOUSE_UP, onScrollDragUp);
			};
		}

		private function applyScrollRatio(ratio:Number, fullPaint:Boolean = true):void
		{
			var idx:int;
			var rowsVis:int;
			var vis:int;
			var maxScroll:int;
			var list:Array;
			if (ratio < 0)
			{
				ratio = 0;
			};
			if (ratio > 1)
			{
				ratio = 1;
			};
			idx = int(Math.round(ratio * m_scrollMax));
			if (m_scrollMode == "songs")
			{
				// Do NOT call ensureSongScroll here — it pulls scroll back to the
				// current selection and cancels drag-down.
				ui.m_songScroll = idx;
				list = ui.m_songList.displayList();
				vis = ui.m_songList.visibleSongRows();
				maxScroll = Math.max(0, (list ? list.length : 0) - vis);
				if (ui.m_songScroll > maxScroll)
				{
					ui.m_songScroll = maxScroll;
				};
				if (ui.m_songScroll < 0)
				{
					ui.m_songScroll = 0;
				};
				if (ui.m_songIndex < ui.m_songScroll)
				{
					ui.m_songIndex = ui.m_songScroll;
				};
				vis = ui.m_songList.visibleSongRows();
				if (ui.m_songIndex >= ui.m_songScroll + vis)
				{
					ui.m_songIndex = ui.m_songScroll + vis - 1;
				};
			}
			else
			{
				ui.m_gridScroll = idx * MusicPlayerUi.COLS;
				ensureGridScroll();
				rowsVis = Math.max(1, int((ui.m_listBottom - 72) / (MusicPlayerUi.CELL + MusicPlayerUi.LABEL_H + MusicPlayerUi.GAP)));
				if (ui.m_gridIndex < ui.m_gridScroll)
				{
					ui.m_gridIndex = ui.m_gridScroll;
				};
				if (ui.m_gridIndex >= ui.m_gridScroll + MusicPlayerUi.COLS * rowsVis)
				{
					ui.m_gridIndex = Math.min(ui.m_gridCells.length - 1, ui.m_gridScroll);
				};
			};
			if (fullPaint)
			{
				ui.paint();
			};
		}

		internal function ensureSongScrollFor(list:Array):void
		{
			var vis:int;
			var maxScroll:int;
			vis = ui.m_songList.visibleSongRows();
			maxScroll = Math.max(0, (list ? list.length : 0) - vis);
			// Keep the highlighted row inside the visible window.
			if (ui.m_songIndex < ui.m_songScroll)
			{
				ui.m_songScroll = ui.m_songIndex;
			};
			if (ui.m_songIndex >= ui.m_songScroll + vis)
			{
				ui.m_songScroll = ui.m_songIndex - vis + 1;
			};
			if (ui.m_songScroll > maxScroll)
			{
				ui.m_songScroll = maxScroll;
			};
			if (ui.m_songScroll < 0)
			{
				ui.m_songScroll = 0;
			};
		}

		internal function ensureGridScroll():void
		{
			var rowsVis:int;
			var row:int;
			var rowPitch:int;
			rowPitch = MusicPlayerUi.CELL + MusicPlayerUi.LABEL_H + MusicPlayerUi.GAP;
			rowsVis = Math.max(2, int((ui.m_listBottom - 72) / rowPitch));
			row = int(ui.m_gridIndex / MusicPlayerUi.COLS);
			while (ui.m_gridScroll > ui.m_gridIndex)
			{
				ui.m_gridScroll -= MusicPlayerUi.COLS;
			};
			while (ui.m_gridScroll < 0)
			{
				ui.m_gridScroll = 0;
			};
			while (row >= int(ui.m_gridScroll / MusicPlayerUi.COLS) + rowsVis)
			{
				ui.m_gridScroll += MusicPlayerUi.COLS;
			};
			while (row < int(ui.m_gridScroll / MusicPlayerUi.COLS) && ui.m_gridScroll >= MusicPlayerUi.COLS)
			{
				ui.m_gridScroll -= MusicPlayerUi.COLS;
			};
		}

		internal function ensureSongScroll():void
		{
			ensureSongScrollFor(ui.m_songList.displayList());
		}
	}
}
