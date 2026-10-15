package
{
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;

	/**
	 * The Add to roster popup: paged tiles of characters not on any page, Add All, and the
	 * page-count field.
	 */
	public class CssAddPopup
	{
		private static const ADD_PITCH:int = 48;

		private var mod:CssEditorMod;
		private var m_addScroll:int;
		private var m_addCols:int;
		private var m_addPageSize:int;

		public function CssAddPopup(owner:CssEditorMod)
		{
			mod = owner;
			m_addScroll = 0;
			m_addCols = 8;
			m_addPageSize = 32;
		}

		private function pendingAddIds():Array
		{
			var mappings:Object;
			var ids:Array;
			var used:Array;
			var pending:Array;
			var i:int;
			var id:String;
			mappings = EditorEngine.mappings();
			pending = [];
			if (!mappings)
			{
				return (pending);
			};
			ids = mod.m_roster.collectIds(mappings);
			ids.sort();
			used = GridRows.flatten(mappings.character_select_screen.rows as Array);
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (used.indexOf(id) < 0 && !mod.m_paging.placedAnywhere(id))
				{
					pending.push(id);
				};
				i++;
			};
			return (pending);
		}

		internal function openAddPopup():void
		{
			var parent:DisplayObjectContainer;
			var size:Object;
			var origin:Point;
			var pw:Number;
			var ph:Number;
			var tileRows:int;
			closeAddPopup();
			if (!EditorEngine.mappings() || !mod.m_host)
			{
				return;
			};
			parent = mod.m_chrome.chromeParent();
			if (!parent)
			{
				return;
			};
			size = mod.m_chrome.cssGameSize();
			pw = size.w - 72;
			ph = 300;
			tileRows = int((ph - 96) / ADD_PITCH);
			if (tileRows < 1)
			{
				tileRows = 1;
			};
			m_addCols = int((pw - 24) / ADD_PITCH);
			if (m_addCols < 1)
			{
				m_addCols = 1;
			};
			m_addPageSize = m_addCols * tileRows;
			m_addScroll = 0;
			mod.m_addPopup = new Sprite();
			mod.m_addPopup.name = "cssChrome";
			origin = mod.m_chrome.chromeLocal(-size.w * 0.5 + 36, -size.h * 0.5 + 28);
			mod.m_addPopup.x = origin.x;
			mod.m_addPopup.y = origin.y;
			mod.m_addPopup.graphics.beginFill(0x101018, 0.94);
			mod.m_addPopup.graphics.lineStyle(1, 0xE8A020, 0.95);
			mod.m_addPopup.graphics.drawRoundRect(0, 0, pw, ph, 8, 8);
			mod.m_addPopup.graphics.endFill();
			addPopupHeader(pw);
			addPopupFooter(ph);
			mod.m_addTray = new Sprite();
			mod.m_addTray.x = 12;
			mod.m_addTray.y = 40;
			mod.m_addPopup.addChild(mod.m_addTray);
			mod.m_addPopup.addEventListener(MouseEvent.MOUSE_WHEEL, onAddWheel);
			parent.addChild(mod.m_addPopup);
			refreshAddTiles();
			mod.m_chrome.layoutBar();
		}

		/** Title, Add All, and Close along the top of the Add popup. */
		private function addPopupHeader(pw:Number):void
		{
			var title:TextField;
			var btn:Sprite;
			title = new TextField();
			title.name = "title";
			title.x = 12;
			title.y = 8;
			title.width = pw - 220;
			title.height = 22;
			title.selectable = false;
			title.mouseEnabled = false;
			title.defaultTextFormat = new TextFormat("_sans", 13, 0xE8A020, true);
			title.text = "Add to roster";
			mod.m_addPopup.addChild(title);
			btn = mod.m_chrome.makeBarButton("Add All", onAddAllClick, 96, CssEditorMod.BTN_H);
			btn.name = "addAll";
			btn.x = pw - 190;
			btn.y = 6;
			mod.m_addPopup.addChild(btn);
			btn = mod.m_chrome.makeBarButton("Close", onAddCloseClick, 72, CssEditorMod.BTN_H);
			btn.name = "close";
			btn.x = pw - 82;
			btn.y = 6;
			mod.m_addPopup.addChild(btn);
		}

		/** Prev/Next, the page counter, and the Pages - field + row along the bottom of the Add popup. */
		private function addPopupFooter(ph:Number):void
		{
			var btn:Sprite;
			var pageLabel:TextField;
			var pageField:TextField;
			var pageCounter:TextField;
			btn = mod.m_chrome.makeBarButton("Prev", onAddPrevClick, 72, CssEditorMod.BTN_H);
			btn.name = "prev";
			btn.x = 12;
			btn.y = ph - 36;
			mod.m_addPopup.addChild(btn);
			btn = mod.m_chrome.makeBarButton("Next", onAddNextClick, 72, CssEditorMod.BTN_H);
			btn.name = "next";
			btn.x = 92;
			btn.y = ph - 36;
			mod.m_addPopup.addChild(btn);
			pageCounter = new TextField();
			pageCounter.name = "addPageCounter";
			pageCounter.selectable = false;
			pageCounter.mouseEnabled = false;
			pageCounter.width = 48;
			pageCounter.height = 22;
			pageCounter.defaultTextFormat = new TextFormat("_sans", 12, 0xF2F2F2, true);
			pageCounter.text = "0/0";
			pageCounter.x = 172;
			pageCounter.y = ph - 32;
			mod.m_addPopup.addChild(pageCounter);
			pageLabel = new TextField();
			pageLabel.selectable = false;
			pageLabel.mouseEnabled = false;
			pageLabel.autoSize = TextFieldAutoSize.LEFT;
			pageLabel.defaultTextFormat = new TextFormat("_sans", 12, 0xF2F2F2, true);
			pageLabel.text = "Pages";
			pageLabel.x = 230;
			pageLabel.y = ph - 32;
			mod.m_addPopup.addChild(pageLabel);
			btn = mod.m_chrome.makeBarButton("-", onPageMinusClick, 28, CssEditorMod.BTN_H);
			btn.name = "pageMinus";
			btn.x = 282;
			btn.y = ph - 36;
			mod.m_addPopup.addChild(btn);
			pageField = new TextField();
			pageField.name = "pageField";
			pageField.type = TextFieldType.INPUT;
			pageField.restrict = "0-9";
			pageField.maxChars = 2;
			pageField.width = 36;
			pageField.height = 22;
			pageField.x = 314;
			pageField.y = ph - 34;
			pageField.background = true;
			pageField.backgroundColor = 0x2A2A36;
			pageField.border = true;
			pageField.borderColor = 0xE8A020;
			pageField.defaultTextFormat = new TextFormat("_sans", 14, 0xF2F2F2, true, null, null, null, null, "center");
			pageField.text = String(mod.m_paging.pageCount());
			pageField.addEventListener(FocusEvent.FOCUS_OUT, onPageFieldChange);
			pageField.addEventListener(KeyboardEvent.KEY_DOWN, onPageFieldKey);
			mod.m_addPopup.addChild(pageField);
			btn = mod.m_chrome.makeBarButton("+", onPagePlusClick, 28, CssEditorMod.BTN_H);
			btn.name = "pagePlus";
			btn.x = 354;
			btn.y = ph - 36;
			mod.m_addPopup.addChild(btn);
		}

		private function refreshAddTiles():void
		{
			var pending:Array;
			var title:TextField;
			var i:int;
			var shown:int;
			var id:String;
			var hit:Sprite;
			var mc:MovieClip;
			var pageSize:int;
			if (!mod.m_addPopup || !mod.m_addTray)
			{
				return;
			};
			while (mod.m_addTray.numChildren > 0)
			{
				hit = mod.m_addTray.getChildAt(0) as Sprite;
				if (hit)
				{
					hit.removeEventListener(MouseEvent.CLICK, onAddIdClick);
				};
				mod.m_addTray.removeChildAt(0);
			};
			pending = pendingAddIds();
			pageSize = m_addPageSize > 0 ? m_addPageSize : 1;
			if (m_addScroll < 0)
			{
				m_addScroll = 0;
			};
			if (pending.length > 0 && m_addScroll >= pending.length)
			{
				m_addScroll = int(Math.floor((pending.length - 1) / pageSize) * pageSize);
			};
			title = mod.m_addPopup.getChildByName("title") as TextField;
			if (title)
			{
				title.text = pending.length > 0 ? "Add to roster  (" + pending.length + ")" : "Everyone is already on the roster";
			};
			shown = 0;
			i = m_addScroll;
			while (i < pending.length && shown < pageSize)
			{
				id = String(pending[i]);
				hit = new Sprite();
				hit.name = id;
				hit.graphics.beginFill(0x2A2A36, 1);
				hit.graphics.lineStyle(1, 0xE8A020, 0.7);
				hit.graphics.drawRoundRect(0, 0, 42, 42, 4, 4);
				hit.graphics.endFill();
				hit.x = (shown % m_addCols) * ADD_PITCH;
				hit.y = int(shown / m_addCols) * ADD_PITCH;
				hit.buttonMode = true;
				hit.mouseChildren = false;
				mc = EditorEngine.libraryMC(id + "_select");
				if (mc)
				{
					try
					{
						mc.gotoAndStop(1);
					}
					catch (frameErr:*)
					{
					};
					mc.mouseEnabled = false;
					mc.mouseChildren = false;
					mc.x = 21;
					mc.y = 21;
					hit.addChild(mc);
				};
				hit.addEventListener(MouseEvent.CLICK, onAddIdClick);
				mod.m_addTray.addChild(hit);
				shown++;
				i++;
			};
			syncAddPageControls(pending.length);
		}

		private function syncAddPageControls(count:int):void
		{
			var field:TextField;
			var counter:TextField;
			var pageSize:int;
			var total:int;
			var current:int;
			if (!mod.m_addPopup)
			{
				return;
			};
			field = mod.m_addPopup.getChildByName("pageField") as TextField;
			if (field && field.text != String(mod.m_paging.pageCount()))
			{
				field.text = String(mod.m_paging.pageCount());
			};
			pageSize = m_addPageSize > 0 ? m_addPageSize : 1;
			total = count <= 0 ? 0 : int(Math.ceil(count / pageSize));
			current = total <= 0 ? 0 : int(m_addScroll / pageSize) + 1;
			counter = mod.m_addPopup.getChildByName("addPageCounter") as TextField;
			if (counter)
			{
				counter.text = current + "/" + total;
			};
		}

		private function onAddPrevClick(e:MouseEvent):void
		{
			var pageSize:int;
			if (e)
			{
				e.stopPropagation();
			};
			pageSize = m_addPageSize > 0 ? m_addPageSize : 1;
			m_addScroll -= pageSize;
			if (m_addScroll < 0)
			{
				m_addScroll = 0;
			};
			refreshAddTiles();
		}

		private function onAddNextClick(e:MouseEvent):void
		{
			var pending:Array;
			var pageSize:int;
			if (e)
			{
				e.stopPropagation();
			};
			pageSize = m_addPageSize > 0 ? m_addPageSize : 1;
			pending = pendingAddIds();
			if (m_addScroll + pageSize < pending.length)
			{
				m_addScroll += pageSize;
			};
			refreshAddTiles();
		}

		private function onAddCloseClick(e:MouseEvent):void
		{
			if (e)
			{
				e.stopPropagation();
			};
			closeAddPopup();
			mod.m_mode = CssEditorMod.MODE_SORT;
			mod.m_chrome.layoutBar();
		}

		private function onPageMinusClick(e:MouseEvent):void
		{
			if (e)
			{
				e.stopPropagation();
			};
			mod.m_paging.setPageCount(mod.m_paging.pageCount() - 1);
		}

		private function onPagePlusClick(e:MouseEvent):void
		{
			if (e)
			{
				e.stopPropagation();
			};
			mod.m_paging.setPageCount(mod.m_paging.pageCount() + 1);
		}

		private function onPageFieldChange(e:Event):void
		{
			applyPageField();
		}

		private function onPageFieldKey(e:KeyboardEvent):void
		{
			if (e && e.keyCode == 13)
			{
				e.stopPropagation();
				applyPageField();
			};
		}

		private function applyPageField():void
		{
			var field:TextField;
			var n:int;
			if (!mod.m_addPopup)
			{
				return;
			};
			field = mod.m_addPopup.getChildByName("pageField") as TextField;
			if (!field)
			{
				return;
			};
			n = int(field.text);
			if (n < 1)
			{
				n = 1;
			};
			if (n > CssEditorMod.MAX_PAGES)
			{
				n = CssEditorMod.MAX_PAGES;
			};
			if (n != mod.m_paging.pageCount())
			{
				mod.m_paging.setPageCount(n);
			}
			else
			{
				field.text = String(mod.m_paging.pageCount());
			};
		}

		private function onAddWheel(e:MouseEvent):void
		{
			if (!mod.m_addPopup)
			{
				return;
			};
			if (e.delta > 0)
			{
				onAddPrevClick(null);
			}
			else if (e.delta < 0)
			{
				onAddNextClick(null);
			};
		}

		private function onAddAllClick(e:MouseEvent):void
		{
			var pending:Array;
			var mappings:Object;
			var rows:Array;
			var pageSize:int;
			var i:int;
			var end:int;
			var id:String;
			var added:int;
			if (e)
			{
				e.stopPropagation();
			};
			mappings = EditorEngine.mappings();
			if (!mappings)
			{
				return;
			};
			pending = pendingAddIds();
			pageSize = m_addPageSize > 0 ? m_addPageSize : 1;
			end = m_addScroll + pageSize;
			if (end > pending.length)
			{
				end = pending.length;
			};
			rows = GridRows.cloneRows(mappings.character_select_screen.rows as Array);
			added = 0;
			i = m_addScroll;
			while (i < end)
			{
				id = String(pending[i]);
				if (id && !mod.m_paging.placedAnywhere(id))
				{
					GridRows.insertBeforePinned(rows, id);
					added++;
				};
				i++;
			};
			if (added > 0)
			{
				mod.m_roster.applyRows(rows, true);
			};
			mod.cssLog("add all scroll=" + m_addScroll + " added=" + added);
			refreshAddTiles();
		}

		private function onAddIdClick(e:MouseEvent):void
		{
			var id:String;
			id = e.currentTarget ? String(e.currentTarget.name) : "";
			if (id)
			{
				addCharacter(id);
			};
		}

		internal function addCharacter(id:String):void
		{
			var mappings:Object;
			var rows:Array;
			mappings = EditorEngine.mappings();
			if (!id || !mappings)
			{
				return;
			};
			if (mod.m_paging.placedAnywhere(id))
			{
				mod.cssLog("add refused id=" + id + " already on a page");
				refreshAddTiles();
				return;
			};
			rows = GridRows.cloneRows(mappings.character_select_screen.rows as Array);
			GridRows.insertBeforePinned(rows, id);
			mod.m_roster.applyRows(rows, true);
			refreshAddTiles();
		}

		internal function closeAddPopup():void
		{
			var names:Array;
			var i:int;
			var btn:Sprite;
			var field:TextField;
			if (mod.m_addPopup)
			{
				names = ["close", "prev", "next", "pageMinus", "pagePlus", "addAll"];
				i = 0;
				while (i < names.length)
				{
					btn = mod.m_addPopup.getChildByName(String(names[i])) as Sprite;
					if (btn)
					{
						btn.removeEventListener(MouseEvent.CLICK, onAddCloseClick);
						btn.removeEventListener(MouseEvent.CLICK, onAddPrevClick);
						btn.removeEventListener(MouseEvent.CLICK, onAddNextClick);
						btn.removeEventListener(MouseEvent.CLICK, onPageMinusClick);
						btn.removeEventListener(MouseEvent.CLICK, onPagePlusClick);
						btn.removeEventListener(MouseEvent.CLICK, onAddAllClick);
					};
					i++;
				};
				field = mod.m_addPopup.getChildByName("pageField") as TextField;
				if (field)
				{
					field.removeEventListener(FocusEvent.FOCUS_OUT, onPageFieldChange);
					field.removeEventListener(KeyboardEvent.KEY_DOWN, onPageFieldKey);
				};
				if (mod.m_addTray)
				{
					i = 0;
					while (i < mod.m_addTray.numChildren)
					{
						mod.m_addTray.getChildAt(i).removeEventListener(MouseEvent.CLICK, onAddIdClick);
						i++;
					};
				};
				mod.m_addPopup.removeEventListener(MouseEvent.MOUSE_WHEEL, onAddWheel);
				if (mod.m_addPopup.parent)
				{
					mod.m_addPopup.parent.removeChild(mod.m_addPopup);
				};
			};
			mod.m_addPopup = null;
			mod.m_addTray = null;
		}
	}
}
