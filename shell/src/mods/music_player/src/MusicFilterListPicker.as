package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;

	/**
	 * Modal text-filtered list picker (series, stage art, …). One instance per open; the
	 * modal callbacks on MusicPlayerUi point at this instance until the overlay is dismissed.
	 */
	public class MusicFilterListPicker
	{
		private static const MAX_VIS:int = 5;
		private static const LIST_H:Number = MAX_VIS * 32;

		private var ui:MusicPlayerUi;
		private var dialogs:MusicUiDialogs;
		private var m_title:String;
		private var m_keys:Array;
		private var m_labelFn:Function;
		private var m_decorateFn:Function;
		private var m_onPick:Function;
		private var m_onCancel:Function;
		private var m_onDefault:Function;
		private var m_onUpload:Function;
		private var m_panel:Sprite;
		private var m_card:Sprite;
		private var m_input:TextField;
		private var m_listHost:Sprite;
		private var m_scrollBar:Sprite;
		private var m_tipTf:TextField;
		private var m_scroll:int;
		private var m_filtered:Array;

		public function MusicFilterListPicker(owner:MusicPlayerUi, dlg:MusicUiDialogs, title:String, keys:Array,
			labelFn:Function, decorateFn:Function, onPick:Function, onCancel:Function,
			onDefault:Function, onUpload:Function)
		{
			ui = owner;
			dialogs = dlg;
			m_title = title;
			m_keys = keys;
			m_labelFn = labelFn;
			m_decorateFn = decorateFn;
			m_onPick = onPick;
			m_onCancel = onCancel;
			m_onDefault = onDefault;
			m_onUpload = onUpload;
			m_scroll = 0;
			m_filtered = [];
		}

		internal function open():void
		{
			buildCard();
			m_input.addEventListener(Event.CHANGE, onInputChange);
			m_panel.addEventListener(MouseEvent.MOUSE_WHEEL, onWheel);
			addButtons(60 + LIST_H + 18);
			ui.m_modalIndex = 0;
			rebuild();
			ui.m_blockingOverlay = m_panel;
			ui.m_modalKind = "filter";
			ui.m_modalOnConfirm = confirmSelection;
			ui.m_modalOnBack = cancel;
			ui.m_modalRefresh = rebuild;
			ui.addChild(m_panel);
			if (ui.stage)
			{
				ui.stage.focus = m_input;
			};
		}

		private function buildCard():void
		{
			var cardH:Number;
			cardH = 66 + LIST_H + 52;
			m_panel = new Sprite();
			m_panel.graphics.beginFill(0x000000, 0.62);
			m_panel.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			m_panel.graphics.endFill();
			m_card = new Sprite();
			m_card.x = ui.m_gw * 0.5 - 180;
			m_card.y = Math.max(10, (ui.m_gh - cardH) * 0.5 - 30);
			m_card.graphics.beginFill(0x121218, 0.98);
			m_card.graphics.lineStyle(1, MusicTheme.ui(), 0.22);
			m_card.graphics.drawRoundRect(0, 0, 360, cardH, 12, 12);
			m_card.graphics.endFill();
			m_panel.addChild(m_card);
			m_card.addChild(ui.makeText(m_title, 14, 8, 14, MusicTheme.ui(), true));
			m_input = new TextField();
			m_input.type = TextFieldType.INPUT;
			m_input.border = true;
			m_input.borderColor = 0x555566;
			m_input.background = true;
			m_input.backgroundColor = 0x1A1A22;
			m_input.textColor = MusicTheme.ui();
			m_input.defaultTextFormat = new TextFormat("_sans", 13, MusicTheme.ui());
			m_input.x = 14;
			m_input.y = 30;
			m_input.width = 332;
			m_input.height = 24;
			m_input.text = "";
			m_card.addChild(m_input);
			m_listHost = new Sprite();
			m_listHost.x = 10;
			m_listHost.y = 60;
			m_card.addChild(m_listHost);
			m_scrollBar = new Sprite();
			m_scrollBar.x = 346;
			m_scrollBar.y = 60;
			m_card.addChild(m_scrollBar);
			m_tipTf = ui.makeText("", 14, 60 + LIST_H + 2, 10, 0xAAAAAA, false);
			m_tipTf.width = 330;
			m_tipTf.autoSize = TextFieldAutoSize.NONE;
			m_card.addChild(m_tipTf);
		}

		private function rebuild():void
		{
			var i:int;
			var shown:int;
			var maxScroll:int;
			filterKeys();
			ui.m_modalItems = m_filtered;
			maxScroll = Math.max(0, m_filtered.length - MAX_VIS);
			clampSelectionAndScroll(maxScroll);
			while (m_listHost.numChildren > 0)
			{
				m_listHost.removeChildAt(0);
			};
			shown = 0;
			i = m_scroll;
			while (i < m_filtered.length && shown < MAX_VIS)
			{
				m_listHost.addChild(buildRow(String(m_filtered[i]), i, shown));
				shown++;
				i++;
			};
			paintScrollBar(maxScroll);
		}

		private function filterKeys():void
		{
			var q:String;
			var i:int;
			var key:String;
			q = (m_input.text || "").toLowerCase();
			m_filtered = [];
			i = 0;
			while (i < m_keys.length)
			{
				key = String(m_keys[i]);
				i++;
				if (q && String(m_labelFn(key)).toLowerCase().indexOf(q) < 0
					&& key.toLowerCase().indexOf(q) < 0)
				{
					continue;
				};
				m_filtered.push(key);
			};
		}

		private function clampSelectionAndScroll(maxScroll:int):void
		{
			if (ui.m_modalIndex < 0)
			{
				ui.m_modalIndex = 0;
			};
			if (ui.m_modalIndex >= m_filtered.length)
			{
				ui.m_modalIndex = Math.max(0, m_filtered.length - 1);
			};
			if (ui.m_modalIndex < m_scroll)
			{
				m_scroll = ui.m_modalIndex;
			};
			if (ui.m_modalIndex >= m_scroll + MAX_VIS)
			{
				m_scroll = ui.m_modalIndex - MAX_VIS + 1;
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

		private function buildRow(key:String, selAbs:int, shown:int):Sprite
		{
			var row:Sprite;
			row = new Sprite();
			row.graphics.beginFill(selAbs == ui.m_modalIndex ? 0x2A2418 : 0x1A1A22, 1);
			if (selAbs == ui.m_modalIndex)
			{
				row.graphics.lineStyle(1, MusicTheme.select(), 0.9);
			};
			row.graphics.drawRoundRect(0, 0, 330, 28, 6, 6);
			row.graphics.endFill();
			row.y = shown * 32;
			row.buttonMode = true;
			if (m_decorateFn != null)
			{
				m_decorateFn(key, row);
			};
			row.addChild(ui.makeText(String(m_labelFn(key)), 40, 5, 12, MusicTheme.ui(), false));
			row.addEventListener(MouseEvent.CLICK, rowClick(key));
			row.addEventListener(MouseEvent.ROLL_OVER, rowOver(key, selAbs));
			return (row);
		}

		private function rowClick(picked:String):Function
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

		private function rowOver(picked:String, abs:int):Function
		{
			return function (e:MouseEvent):void
			{
				m_tipTf.text = String(m_labelFn(picked));
				ui.m_modalIndex = abs;
				rebuild();
			};
		}

		private function paintScrollBar(maxScroll:int):void
		{
			var trackH:Number;
			var thumbH:Number;
			m_scrollBar.graphics.clear();
			if (m_filtered.length > MAX_VIS)
			{
				trackH = LIST_H;
				m_scrollBar.graphics.beginFill(0x2A2A34, 1);
				m_scrollBar.graphics.drawRoundRect(0, 0, 6, trackH, 3, 3);
				m_scrollBar.graphics.endFill();
				thumbH = Math.max(16, trackH * (MAX_VIS / m_filtered.length));
				m_scrollBar.graphics.beginFill(MusicTheme.select(), 1);
				m_scrollBar.graphics.drawRoundRect(0,
					(trackH - thumbH) * (m_scroll / Math.max(1, maxScroll)), 6, thumbH, 3, 3);
				m_scrollBar.graphics.endFill();
			};
		}

		private function onInputChange(e:Event):void
		{
			m_scroll = 0;
			rebuild();
		}

		private function onWheel(e:MouseEvent):void
		{
			var maxScroll:int;
			e.stopPropagation();
			maxScroll = Math.max(0, m_filtered.length - MAX_VIS);
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

		private function addButtons(btnY:Number):void
		{
			if (m_onDefault != null)
			{
				m_card.addChild(dialogs.promptButton("Default", 14, btnY, function ():void
				{
					dialogs.dismissBlockingOverlay();
					if (m_onDefault != null)
					{
						m_onDefault();
					};
				}));
			};
			if (m_onUpload != null)
			{
				m_card.addChild(dialogs.promptButton("Upload…", m_onDefault != null ? 100 : 14, btnY, function ():void
				{
					dialogs.dismissBlockingOverlay();
					if (m_onUpload != null)
					{
						m_onUpload();
					};
				}));
			};
			m_card.addChild(dialogs.promptButton("Cancel · Special",
				(m_onDefault != null || m_onUpload != null) ? 200 : 14, btnY, cancel));
		}

		private function confirmSelection():void
		{
			var picked:String;
			if (!m_filtered || m_filtered.length < 1)
			{
				return;
			};
			if (ui.m_modalIndex < 0 || ui.m_modalIndex >= m_filtered.length)
			{
				return;
			};
			picked = String(m_filtered[ui.m_modalIndex]);
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
