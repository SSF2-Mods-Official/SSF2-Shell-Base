package
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import ssf2mm.shared.LucideIcons;

	/**
	 * Theme colors menu, swatch picker, and chrome recolor.
	 */
	public class MusicUiTheme
	{
		private var ui:MusicPlayerUi;

		public function MusicUiTheme(owner:MusicPlayerUi)
		{
			ui = owner;
		}

		internal function openThemeColorsMenu():void
		{
			var panel:Sprite;
			var card:Sprite;
			var items:Array;
			var i:int;
			var row:Sprite;
			var swatch:Sprite;
			var tf:TextField;
			var cardH:Number;
			ui.m_dialogs.closeSettingsOverlay();
			items = [
				{"label": "UI / text color", "key": "ui"},
				{"label": "Symbol tint", "key": "symbol"},
				{"label": "Selection color", "key": "select"},
				{"label": "Reset defaults", "key": "reset"},
				{"label": "Back", "key": "back"}
			];
			panel = new Sprite();
			panel.graphics.beginFill(0x000000, 0.62);
			panel.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			panel.graphics.endFill();
			cardH = 240;
			card = new Sprite();
			card.x = ui.m_gw * 0.5 - 170;
			card.y = Math.max(12, (ui.m_gh - cardH) * 0.5 - 40);
			card.graphics.beginFill(0x121218, 0.98);
			card.graphics.lineStyle(1, MusicTheme.ui(), 0.22);
			card.graphics.drawRoundRect(0, 0, 340, cardH, 14, 14);
			card.graphics.endFill();
			panel.addChild(card);
			card.addChild(ui.makeText("My Jukebox colors", 18, 10, 15, MusicTheme.ui(), true));
			i = 0;
			while (i < items.length)
			{
				row = new Sprite();
				row.graphics.beginFill(0x1A1A22, 1);
				row.graphics.drawRoundRect(0, 0, 304, 30, 8, 8);
				row.graphics.endFill();
				row.x = 18;
				row.y = 42 + i * 36;
				row.buttonMode = true;
				if (items[i].key == "ui" || items[i].key == "symbol" || items[i].key == "select")
				{
					swatch = new Sprite();
					swatch.graphics.beginFill(
						items[i].key == "ui" ? MusicTheme.ui()
						: (items[i].key == "symbol" ? MusicTheme.symbol() : MusicTheme.select()), 1);
					swatch.graphics.lineStyle(1, 0xFFFFFF, 0.4);
					swatch.graphics.drawRoundRect(0, 0, 22, 22, 4, 4);
					swatch.graphics.endFill();
					swatch.x = 8;
					swatch.y = 4;
					swatch.mouseEnabled = false;
					row.addChild(swatch);
					tf = ui.makeText(String(items[i].label), 40, 6, 13, MusicTheme.ui(), false);
				}
				else
				{
					tf = ui.makeText(String(items[i].label), 12, 6, 13, MusicTheme.ui(), false);
				};
				row.addChild(tf);
				row.addEventListener(MouseEvent.CLICK, (function (key:String):Function
				{
					return function (e:MouseEvent):void
					{
						e.stopPropagation();
						runThemeColorAction(key);
					};
				})(String(items[i].key)));
				card.addChild(row);
				i++;
			};
			ui.m_blockingOverlay = panel;
			ui.m_modalKind = "theme";
			ui.m_modalItems = items;
			ui.m_modalIndex = 0;
			ui.m_modalOnConfirm = function ():void
			{
				if (ui.m_modalItems && ui.m_modalIndex >= 0 && ui.m_modalIndex < ui.m_modalItems.length)
				{
					runThemeColorAction(String(ui.m_modalItems[ui.m_modalIndex].key));
				};
			};
			ui.m_modalOnBack = function ():void
			{
				ui.m_dialogs.dismissBlockingOverlay();
				ui.m_trackSettings.openTrackSettingsMenu();
			};
			ui.addChild(panel);
			ui.m_dialogs.highlightModalRows(card, 42, 36, 304, 30);
			ui.m_modalRefresh = function ():void
			{
				ui.m_dialogs.highlightModalRows(card, 42, 36, 304, 30);
			};
		}

		private function runThemeColorAction(key:String):void
		{
			if (key == "back")
			{
				ui.m_dialogs.dismissBlockingOverlay();
				ui.m_trackSettings.openTrackSettingsMenu();
				return;
			};
			if (key == "reset")
			{
				MusicTheme.resetDefaults();
				ui.m_tileArtCache = {};
				ui.m_dialogs.dismissBlockingOverlay();
				applyChromeTheme();
				ui.paint();
				if (ui.m_npBar)
				{
					ui.m_npBar.layout(ui.m_gw, ui.m_gh);
				};
				openThemeColorsMenu();
				return;
			};
			openColorSwatchPicker(key);
		}

		private function openColorSwatchPicker(key:String):void
		{
			var start:uint;
			var picker:MusicColorPicker;
			var showGlow:Boolean;
			ui.m_dialogs.dismissBlockingOverlay();
			if (key == "ui")
			{
				start = MusicTheme.ui();
			}
			else if (key == "symbol")
			{
				start = MusicTheme.symbol();
			}
			else
			{
				start = MusicTheme.select();
			};
			showGlow = (key == "symbol");
			picker = new MusicColorPicker(ui.m_gw, ui.m_gh, start, function (c:uint):void
			{
				if (key == "ui")
				{
					MusicTheme.setUi(c);
				}
				else if (key == "symbol")
				{
					MusicTheme.setSymbol(c);
					MusicTheme.setSymbolGlow(picker.glowEnabled);
				}
				else
				{
					MusicTheme.setSelect(c);
				};
				ui.m_tileArtCache = {};
				if (picker && picker.parent)
				{
					picker.parent.removeChild(picker);
				};
				ui.m_blockingOverlay = null;
				ui.m_dialogs.clearModalNav();
				applyChromeTheme();
				ui.paint();
				if (ui.m_npBar)
				{
					ui.m_npBar.layout(ui.m_gw, ui.m_gh);
				};
				openThemeColorsMenu();
			}, function ():void
			{
				if (picker && picker.parent)
				{
					picker.parent.removeChild(picker);
				};
				ui.m_blockingOverlay = null;
				ui.m_dialogs.clearModalNav();
				openThemeColorsMenu();
			}, showGlow, showGlow ? MusicTheme.symbolGlow() : false);
			ui.m_blockingOverlay = picker;
			ui.m_modalKind = "color";
			ui.m_modalItems = null;
			ui.m_modalOnConfirm = function ():void
			{
				picker.confirm();
			};
			ui.m_modalOnBack = function ():void
			{
				picker.cancel();
			};
			ui.addChild(picker);
		}

		internal function applyChromeTheme():void
		{
			var fmt:TextFormat;
			if (ui.m_title)
			{
				fmt = ui.m_title.defaultTextFormat;
				fmt.color = MusicTheme.ui();
				ui.m_title.defaultTextFormat = fmt;
				ui.m_title.setTextFormat(fmt);
			};
			if (ui.m_backBtn)
			{
				fmt = ui.m_backBtn.defaultTextFormat;
				fmt.color = MusicTheme.ui();
				ui.m_backBtn.defaultTextFormat = fmt;
				ui.m_backBtn.setTextFormat(fmt);
			};
			if (ui.m_backArrow)
			{
				ui.m_backArrow.graphics.clear();
				LucideIcons.draw(ui.m_backArrow.graphics, LucideIcons.ARROW_LEFT, 20, MusicTheme.ui(), 2);
			};
			if (ui.m_helpTf)
			{
				fmt = new TextFormat("_sans", 20, MusicTheme.ui(), true);
				ui.m_helpTf.defaultTextFormat = fmt;
				ui.m_helpTf.setTextFormat(fmt);
				ui.m_helpTf.textColor = MusicTheme.ui();
			};
			if (ui.m_searchInput)
			{
				ui.m_searchInput.textColor = MusicTheme.ui();
				ui.m_searchInput.defaultTextFormat = new TextFormat("_sans", 13, MusicTheme.ui());
				if (ui.m_searchInput.text)
				{
					ui.m_searchInput.setTextFormat(ui.m_searchInput.defaultTextFormat);
				};
			};
			ui.buildTabHits();
			if (ui.m_scrollThumb)
			{
				ui.m_scroll.paintSongScrollbar();
			};
		}
	}
}
