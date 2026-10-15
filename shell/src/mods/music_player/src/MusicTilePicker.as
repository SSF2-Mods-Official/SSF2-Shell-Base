package
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;

	/**
	 * Modal icon/stage tile picker (6 x 2 window, scrolls by row). One instance per open; the
	 * modal callbacks on MusicPlayerUi point at this instance until the overlay is dismissed.
	 */
	public class MusicTilePicker
	{
		private static const COLS:int = 6;
		private static const SIZE:Number = 72;
		private static const GAP:Number = 8;
		private static const MAX_ROWS:int = 2;

		private var ui:MusicPlayerUi;
		private var dialogs:MusicUiDialogs;
		private var m_title:String;
		private var m_ids:Array;
		private var m_stageMode:Boolean;
		private var m_onPick:Function;
		private var m_onUpload:Function;
		private var m_onCancel:Function;
		private var m_onDefault:Function;
		private var m_panel:Sprite;
		private var m_card:Sprite;
		private var m_host:Sprite;
		private var m_tipTf:TextField;
		private var m_scrollBar:Sprite;
		private var m_scroll:int;
		private var m_cardW:Number;
		private var m_cardH:Number;
		private var m_gridH:Number;

		public function MusicTilePicker(owner:MusicPlayerUi, dlg:MusicUiDialogs, title:String, ids:Array,
			stageMode:Boolean, onPick:Function, onUpload:Function, onCancel:Function, onDefault:Function)
		{
			ui = owner;
			dialogs = dlg;
			m_title = title;
			m_ids = ids;
			m_stageMode = stageMode;
			m_onPick = onPick;
			m_onUpload = onUpload;
			m_onCancel = onCancel;
			m_onDefault = onDefault;
			m_scroll = 0;
			m_gridH = MAX_ROWS * (SIZE + GAP);
			m_cardW = 16 + COLS * (SIZE + GAP) + 20;
			m_cardH = 44 + m_gridH + 56;
		}

		internal function open():void
		{
			buildCard();
			m_panel.addEventListener(MouseEvent.MOUSE_WHEEL, onWheel);
			addButtons();
			ui.m_modalIndex = 0;
			rebuild();
			ui.m_blockingOverlay = m_panel;
			ui.m_modalKind = "tiles";
			ui.m_modalOnConfirm = confirmSelection;
			ui.m_modalOnBack = cancel;
			ui.m_modalRefresh = rebuild;
			ui.addChild(m_panel);
		}

		private function buildCard():void
		{
			m_panel = new Sprite();
			m_panel.graphics.beginFill(0x000000, 0.62);
			m_panel.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			m_panel.graphics.endFill();
			m_card = new Sprite();
			m_card.x = Math.max(12, ui.m_gw * 0.5 - m_cardW * 0.5);
			m_card.y = Math.max(8, (ui.m_gh - m_cardH) * 0.5 - 36);
			m_card.graphics.beginFill(0x121218, 0.98);
			m_card.graphics.lineStyle(1, MusicTheme.ui(), 0.22);
			m_card.graphics.drawRoundRect(0, 0, m_cardW, m_cardH, 12, 12);
			m_card.graphics.endFill();
			m_panel.addChild(m_card);
			m_card.addChild(ui.makeText(m_title, 16, 10, 14, MusicTheme.ui(), true));
			m_host = new Sprite();
			m_host.x = 16;
			m_host.y = 36;
			m_card.addChild(m_host);
			m_scrollBar = new Sprite();
			m_scrollBar.x = m_cardW - 14;
			m_scrollBar.y = 36;
			m_card.addChild(m_scrollBar);
			m_tipTf = ui.makeText("", 16, 36 + m_gridH + 2, 11, 0xAAAAAA, false);
			m_tipTf.width = m_cardW - 40;
			m_tipTf.autoSize = TextFieldAutoSize.NONE;
			m_card.addChild(m_tipTf);
		}

		private function rebuild():void
		{
			var i:int;
			var shown:int;
			var maxScroll:int;
			var totalRows:int;
			ui.m_modalItems = m_ids;
			totalRows = Math.ceil(m_ids.length / Number(COLS));
			maxScroll = Math.max(0, totalRows - MAX_ROWS);
			clampSelectionAndScroll(maxScroll);
			while (m_host.numChildren > 0)
			{
				m_host.removeChildAt(0);
			};
			shown = 0;
			i = m_scroll * COLS;
			while (i < m_ids.length && shown < COLS * MAX_ROWS)
			{
				m_host.addChild(buildCell(String(m_ids[i]), i, shown));
				shown++;
				i++;
			};
			paintScrollBar(totalRows, maxScroll);
			if (ui.m_modalIndex >= 0 && ui.m_modalIndex < m_ids.length)
			{
				m_tipTf.text = tipFor(String(m_ids[ui.m_modalIndex]));
			};
		}

		private function clampSelectionAndScroll(maxScroll:int):void
		{
			var row:int;
			if (ui.m_modalIndex < 0)
			{
				ui.m_modalIndex = 0;
			};
			if (ui.m_modalIndex >= m_ids.length)
			{
				ui.m_modalIndex = Math.max(0, m_ids.length - 1);
			};
			row = int(ui.m_modalIndex / COLS);
			if (row < m_scroll)
			{
				m_scroll = row;
			};
			if (row >= m_scroll + MAX_ROWS)
			{
				m_scroll = row - MAX_ROWS + 1;
			};
			if (m_scroll > maxScroll)
			{
				m_scroll = maxScroll;
			};
			if (m_scroll < 0)
			{
				m_scroll = 0;
			};
		}

		private function buildCell(id:String, abs:int, shown:int):Sprite
		{
			var cell:Sprite;
			var hold:Sprite;
			cell = new Sprite();
			cell.x = (shown % COLS) * (SIZE + GAP);
			cell.y = int(shown / COLS) * (SIZE + GAP);
			cell.graphics.beginFill(abs == ui.m_modalIndex ? 0x2A2418 : 0x1A1A22, 1);
			if (abs == ui.m_modalIndex)
			{
				cell.graphics.lineStyle(2, MusicTheme.select(), 0.95);
			};
			cell.graphics.drawRoundRect(0, 0, SIZE, SIZE, 8, 8);
			cell.graphics.endFill();
			cell.buttonMode = true;
			if (m_stageMode)
			{
				hold = new Sprite();
				hold.x = SIZE * 0.5;
				hold.y = SIZE * 0.5;
				hold.mouseEnabled = false;
				hold.mouseChildren = false;
				cell.addChild(hold);
				MusicSeriesResolver.attachSeriesTile(hold, "stage:" + id, id,
					SIZE, SIZE, false);
			}
			else
			{
				MusicSeriesResolver.attachIcon(cell, id, SIZE * 0.7, true);
			};
			cell.addEventListener(MouseEvent.CLICK, cellClick(id));
			cell.addEventListener(MouseEvent.ROLL_OVER, cellOver(id, abs));
			return (cell);
		}

		private function tipFor(id:String):String
		{
			return (m_stageMode
				? MusicStageVisuals.stageDisplayName(id)
				: (MusicSeriesResolver.seriesLabel(id) || id));
		}

		private function cellClick(picked:String):Function
		{
			return function (e:MouseEvent):void
			{
				e.stopPropagation();
				dialogs.dismissBlockingOverlay();
				if (m_onPick != null)
				{
					m_onPick(picked);
				};
			};
		}

		private function cellOver(picked:String, abs:int):Function
		{
			return function (e:MouseEvent):void
			{
				m_tipTf.text = tipFor(picked);
				ui.m_modalIndex = abs;
				rebuild();
			};
		}

		private function paintScrollBar(totalRows:int, maxScroll:int):void
		{
			var trackH:Number;
			var thumbH:Number;
			m_scrollBar.graphics.clear();
			if (totalRows > MAX_ROWS)
			{
				trackH = m_gridH;
				m_scrollBar.graphics.beginFill(0x2A2A34, 1);
				m_scrollBar.graphics.drawRoundRect(0, 0, 6, trackH, 3, 3);
				m_scrollBar.graphics.endFill();
				thumbH = Math.max(16, trackH * (MAX_ROWS / totalRows));
				m_scrollBar.graphics.beginFill(MusicTheme.select(), 1);
				m_scrollBar.graphics.drawRoundRect(0,
					(trackH - thumbH) * (m_scroll / Math.max(1, maxScroll)), 6, thumbH, 3, 3);
				m_scrollBar.graphics.endFill();
			};
		}

		private function onWheel(e:MouseEvent):void
		{
			var maxScroll:int;
			e.stopPropagation();
			maxScroll = Math.max(0, Math.ceil(m_ids.length / Number(COLS)) - MAX_ROWS);
			if (e.delta > 0)
			{
				m_scroll = Math.max(0, m_scroll - 1);
			}
			else
			{
				m_scroll = Math.min(maxScroll, m_scroll + 1);
			};
			rebuild();
		}

		private function addButtons():void
		{
			if (m_onDefault != null)
			{
				m_card.addChild(dialogs.promptButton("Default", 16, m_cardH - 40, function ():void
				{
					dialogs.dismissBlockingOverlay();
					m_onDefault();
				}));
			};
			m_card.addChild(dialogs.promptButton("Upload…", m_onDefault != null ? 110 : 16, m_cardH - 40, function ():void
			{
				dialogs.dismissBlockingOverlay();
				if (m_onUpload != null)
				{
					m_onUpload();
				};
			}));
			m_card.addChild(dialogs.promptButton("Cancel · Special", m_onDefault != null ? 210 : 110, m_cardH - 40, cancel));
		}

		private function confirmSelection():void
		{
			var picked:String;
			if (!m_ids || m_ids.length < 1)
			{
				return;
			};
			if (ui.m_modalIndex < 0 || ui.m_modalIndex >= m_ids.length)
			{
				return;
			};
			picked = String(m_ids[ui.m_modalIndex]);
			dialogs.dismissBlockingOverlay();
			if (m_onPick != null)
			{
				m_onPick(picked);
			};
		}

		private function cancel():void
		{
			dialogs.dismissBlockingOverlay();
			if (m_onCancel != null)
			{
				m_onCancel();
			};
		}
	}
}
