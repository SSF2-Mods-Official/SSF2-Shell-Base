package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;

	/**
	 * The Add stages popup: paged tiles of unused stages, Add All, the Extras and Training
	 * toggles, and the page-count field.
	 */
	public class StageAddPopup
	{
		private static const ADD_COLS:int = 10;
		private static const ADD_ROWS:int = 3;
		private static const ADD_TILE_PITCH_X:int = 52;
		private static const ADD_TILE_PITCH_Y:int = 40;

		private var mod:StageEditorMod;
		private var m_addHolds:Object;

		public function StageAddPopup(owner:StageEditorMod)
		{
			mod = owner;
			m_addHolds = {};
		}

		private function addPageSize():int
		{
			return (ADD_COLS * ADD_ROWS);
		}

		internal function rebuildBench():void
		{
			if (mod.m_addPopup)
			{
				rebuildAddPopup();
			};
		}

		internal function openAddPopup():void
		{
			var sub:*;
			var size:Object;
			closeAddPopup();
			sub = mod.m_layout.resolveSubMenu(null);
			if (!sub)
			{
				return;
			};
			size = mod.m_layout.gameSize();
			mod.m_addScroll = 0;
			mod.m_addPopup = new Sprite();
			mod.m_addPopup.x = -size.w * 0.5 + 36;
			mod.m_addPopup.y = -size.h * 0.5 + 28;
			mod.m_addPopup.graphics.beginFill(0x101018, 0.94);
			mod.m_addPopup.graphics.lineStyle(1, 0xE8A020, 0.95);
			mod.m_addPopup.graphics.drawRoundRect(0, 0, size.w - 72, 264, 8, 8);
			mod.m_addPopup.graphics.endFill();
			addPopupHeader(Number(size.w));
			addPopupFooter();
			mod.m_addPopup.addEventListener(MouseEvent.MOUSE_WHEEL, onAddWheel, true);
			try
			{
				sub.addChild(mod.m_addPopup);
			}
			catch (err:*)
			{
				mod.m_addPopup = null;
				return;
			};
			rebuildAddPopup();
		}

		/** Title, Close, and the Extras / Add All / Training row of the Add popup. */
		private function addPopupHeader(gameW:Number):void
		{
			var title:TextField;
			var closeBtn:Sprite;
			var extrasBtn:Sprite;
			var addAllBtn:Sprite;
			var trainBtn:Sprite;
			title = new TextField();
			title.name = "title";
			title.x = 12;
			title.y = 8;
			title.autoSize = TextFieldAutoSize.LEFT;
			title.selectable = false;
			title.mouseEnabled = false;
			title.defaultTextFormat = new TextFormat("_sans", 13, 0xE8A020, true);
			title.text = "Add stages";
			mod.m_addPopup.addChild(title);
			closeBtn = mod.m_bar.makeBarButton("Close", onAddCloseClick);
			closeBtn.x = gameW - 72 - StageEditorMod.BTN_W - 10;
			closeBtn.y = 6;
			closeBtn.name = "close";
			mod.m_addPopup.addChild(closeBtn);
			mod.m_layout.hookSssHandClip(closeBtn);
			extrasBtn = mod.m_bar.makeBarButton("Extras", onExtrasToggleClick);
			extrasBtn.x = 12;
			extrasBtn.y = 38;
			extrasBtn.name = "extras";
			mod.m_addPopup.addChild(extrasBtn);
			mod.m_layout.hookSssHandClip(extrasBtn);
			addAllBtn = mod.m_bar.makeBarButton("Add All", onAddAllClick);
			addAllBtn.x = extrasBtn.x + StageEditorMod.BTN_W + 8;
			addAllBtn.y = 38;
			addAllBtn.name = "addAll";
			mod.m_addPopup.addChild(addAllBtn);
			mod.m_layout.hookSssHandClip(addAllBtn);
			trainBtn = mod.m_bar.makeBarButton("Training", onTrainToggleClick);
			trainBtn.x = addAllBtn.x + StageEditorMod.BTN_W + 8;
			trainBtn.y = 38;
			trainBtn.name = "train";
			mod.m_addPopup.addChild(trainBtn);
			mod.m_layout.hookSssHandClip(trainBtn);
		}

		/** Prev/Next, the page counter, and the Pages - field + row along the bottom of the Add popup. */
		private function addPopupFooter():void
		{
			var prevBtn:Sprite;
			var nextBtn:Sprite;
			var minusBtn:Sprite;
			var plusBtn:Sprite;
			var pageLabel:TextField;
			var pageField:TextField;
			var pageCounter:TextField;
			prevBtn = mod.m_bar.makeBarButton("Prev", onAddPrevClick);
			prevBtn.x = 12;
			prevBtn.y = 220;
			prevBtn.name = "prev";
			mod.m_addPopup.addChild(prevBtn);
			mod.m_layout.hookSssHandClip(prevBtn);
			nextBtn = mod.m_bar.makeBarButton("Next", onAddNextClick);
			nextBtn.x = 12 + StageEditorMod.BTN_W + 8;
			nextBtn.y = 220;
			nextBtn.name = "next";
			mod.m_addPopup.addChild(nextBtn);
			mod.m_layout.hookSssHandClip(nextBtn);
			pageCounter = new TextField();
			pageCounter.name = "addPageCounter";
			pageCounter.autoSize = TextFieldAutoSize.LEFT;
			pageCounter.selectable = false;
			pageCounter.mouseEnabled = false;
			pageCounter.defaultTextFormat = new TextFormat("_sans", 12, 0xF2F2F2, true);
			pageCounter.text = "0/0";
			pageCounter.x = nextBtn.x + StageEditorMod.BTN_W + 10;
			pageCounter.y = 224;
			mod.m_addPopup.addChild(pageCounter);
			pageLabel = new TextField();
			pageLabel.name = "pageLabel";
			pageLabel.autoSize = TextFieldAutoSize.LEFT;
			pageLabel.selectable = false;
			pageLabel.mouseEnabled = false;
			pageLabel.defaultTextFormat = new TextFormat("_sans", 12, 0xF2F2F2, true);
			pageLabel.text = "Pages";
			pageLabel.x = pageCounter.x + 56;
			pageLabel.y = 224;
			mod.m_addPopup.addChild(pageLabel);
			minusBtn = mod.m_bar.makeMiniButton("-", 28, onPageMinusClick);
			minusBtn.x = pageLabel.x + 52;
			minusBtn.y = 220;
			minusBtn.name = "pageMinus";
			mod.m_addPopup.addChild(minusBtn);
			mod.m_layout.hookSssHandClip(minusBtn);
			pageField = new TextField();
			pageField.name = "pageField";
			pageField.type = TextFieldType.INPUT;
			pageField.restrict = "0-9";
			pageField.maxChars = 2;
			pageField.width = 36;
			pageField.height = 22;
			pageField.x = minusBtn.x + 32;
			pageField.y = 222;
			pageField.background = true;
			pageField.backgroundColor = 0x2A2A36;
			pageField.border = true;
			pageField.borderColor = 0xE8A020;
			pageField.defaultTextFormat = new TextFormat("_sans", 14, 0xF2F2F2, true, null, null, null, null, "center");
			pageField.text = String(mod.m_book.pageCount());
			pageField.addEventListener(FocusEvent.FOCUS_OUT, onPageFieldChange);
			pageField.addEventListener(KeyboardEvent.KEY_DOWN, onPageFieldKey);
			mod.m_addPopup.addChild(pageField);
			plusBtn = mod.m_bar.makeMiniButton("+", 28, onPagePlusClick);
			plusBtn.x = pageField.x + 40;
			plusBtn.y = 220;
			plusBtn.name = "pagePlus";
			mod.m_addPopup.addChild(plusBtn);
			mod.m_layout.hookSssHandClip(plusBtn);
		}

		internal function closeAddPopup():void
		{
			var closeBtn:Sprite;
			var prevBtn:Sprite;
			var nextBtn:Sprite;
			var trainBtn:Sprite;
			var extrasBtn:Sprite;
			var addAllBtn:Sprite;
			var minusBtn:Sprite;
			var plusBtn:Sprite;
			var pageField:TextField;
			clearAddHolds();
			if (!mod.m_addPopup)
			{
				return;
			};
			closeBtn = mod.m_addPopup.getChildByName("close") as Sprite;
			prevBtn = mod.m_addPopup.getChildByName("prev") as Sprite;
			nextBtn = mod.m_addPopup.getChildByName("next") as Sprite;
			trainBtn = mod.m_addPopup.getChildByName("train") as Sprite;
			extrasBtn = mod.m_addPopup.getChildByName("extras") as Sprite;
			addAllBtn = mod.m_addPopup.getChildByName("addAll") as Sprite;
			minusBtn = mod.m_addPopup.getChildByName("pageMinus") as Sprite;
			plusBtn = mod.m_addPopup.getChildByName("pagePlus") as Sprite;
			pageField = mod.m_addPopup.getChildByName("pageField") as TextField;
			mod.m_bar.detachBarButton(closeBtn, onAddCloseClick);
			mod.m_bar.detachBarButton(prevBtn, onAddPrevClick);
			mod.m_bar.detachBarButton(nextBtn, onAddNextClick);
			mod.m_bar.detachBarButton(trainBtn, onTrainToggleClick);
			mod.m_bar.detachBarButton(extrasBtn, onExtrasToggleClick);
			mod.m_bar.detachBarButton(addAllBtn, onAddAllClick);
			mod.m_bar.detachBarButton(minusBtn, onPageMinusClick);
			mod.m_bar.detachBarButton(plusBtn, onPagePlusClick);
			if (pageField)
			{
				pageField.removeEventListener(FocusEvent.FOCUS_OUT, onPageFieldChange);
				pageField.removeEventListener(KeyboardEvent.KEY_DOWN, onPageFieldKey);
			};
			mod.m_addPopup.removeEventListener(MouseEvent.MOUSE_WHEEL, onAddWheel, true);
			if (mod.m_addPopup.parent)
			{
				mod.m_addPopup.parent.removeChild(mod.m_addPopup);
			};
			mod.m_addPopup = null;
		}

		internal function rebuildAddPopup():void
		{
			var ids:Array;
			var i:int;
			var hold:Sprite;
			var pageSize:int;
			var shown:int;
			var title:TextField;
			if (!mod.m_addPopup)
			{
				return;
			};
			clearAddHolds();
			ids = mod.m_catalog.unusedIds();
			pageSize = addPageSize();
			if (mod.m_addScroll < 0)
			{
				mod.m_addScroll = 0;
			};
			if (mod.m_addScroll > Math.max(0, ids.length - 1))
			{
				mod.m_addScroll = int(Math.floor(Math.max(0, ids.length - 1) / pageSize) * pageSize);
			};
			title = mod.m_addPopup.getChildByName("title") as TextField;
			if (title)
			{
				title.text = ids.length <= 0 ? "Add stages  (none left)" : "Add stages  (" + ids.length + ")";
			};
			shown = 0;
			i = mod.m_addScroll;
			while (i < ids.length && shown < pageSize)
			{
				hold = makeAddHold(String(ids[i]));
				if (hold)
				{
					hold.x = 16 + (shown % ADD_COLS) * ADD_TILE_PITCH_X;
					hold.y = 74 + int(shown / ADD_COLS) * ADD_TILE_PITCH_Y;
					mod.m_addPopup.addChild(hold);
					m_addHolds[String(ids[i])] = hold;
					shown++;
				};
				i++;
			};
			syncAddPageControls();
		}

		private function makeAddHold(id:String):Sprite
		{
			var hold:Sprite;
			var mc:MovieClip;
			hold = new Sprite();
			hold.name = id;
			hold.mouseEnabled = true;
			hold.mouseChildren = false;
			hold.buttonMode = true;
			hold.graphics.beginFill(0x2A2A36, 1);
			hold.graphics.lineStyle(1, 0xE8A020, 0.7);
			hold.graphics.drawRoundRect(0, 0, StageEditorMod.ADD_TILE_W, StageEditorMod.ADD_TILE_H, 4, 4);
			hold.graphics.endFill();
			mc = EditorEngine.libraryMC(id + "_stage_select");
			if (mc)
			{
				try
				{
					mc.gotoAndStop(1);
				}
				catch (err:*)
				{
				};
				mc.x = StageEditorMod.ADD_TILE_W * 0.5;
				mc.y = StageEditorMod.ADD_TILE_H * 0.5;
				hold.addChild(mc);
			}
			else
			{
				hold.addChild(mod.m_catalog.makeStageTileLabel(id, StageEditorMod.ADD_TILE_W, StageEditorMod.ADD_TILE_H, 0, 0));
			};
			hold.addEventListener(MouseEvent.CLICK, onAddHoldClick);
			hold.addEventListener(MouseEvent.MOUSE_OVER, mod.m_bar.onBarButtonOver);
			hold.addEventListener(MouseEvent.MOUSE_OUT, mod.m_bar.onBarButtonOut);
			mod.m_layout.hookSssHandClip(hold);
			return (hold);
		}

		private function clearAddHolds():void
		{
			var key:String;
			var hold:Sprite;
			for (key in m_addHolds)
			{
				hold = m_addHolds[key] as Sprite;
				if (hold)
				{
					mod.m_layout.unhookSssHandClip(hold);
					hold.removeEventListener(MouseEvent.CLICK, onAddHoldClick);
					hold.removeEventListener(MouseEvent.MOUSE_OVER, mod.m_bar.onBarButtonOver);
					hold.removeEventListener(MouseEvent.MOUSE_OUT, mod.m_bar.onBarButtonOut);
					if (hold.parent)
					{
						hold.parent.removeChild(hold);
					};
				};
			};
			m_addHolds = {};
		}

		private function onAddHoldClick(e:MouseEvent):void
		{
			var hold:Sprite;
			hold = e.currentTarget as Sprite;
			if (!hold || !hold.name)
			{
				return;
			};
			e.stopPropagation();
			mod.m_input.addStageToPage(hold.name);
		}

		private function onAddAllClick(e:MouseEvent):void
		{
			var ids:Array;
			var rows:Array;
			var i:int;
			var added:int;
			var id:String;
			var pageSize:int;
			e.stopPropagation();
			ids = mod.m_catalog.unusedIds();
			pageSize = addPageSize();
			rows = GridRows.cloneRows(mod.m_book.pageRows(mod.m_livePage));
			if (rows.length < 1)
			{
				rows = [[]];
			};
			added = 0;
			i = mod.m_addScroll;
			while (i < ids.length && i < mod.m_addScroll + pageSize)
			{
				id = String(ids[i]);
				if (GridRows.tryAdd(rows, id, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS))
				{
					added++;
					if (mod.m_allowTraining)
					{
						mod.m_store.revealTrainingStage(id);
					};
				}
				else
				{
					break;
				};
				i++;
			};
			if (added <= 0)
			{
				mod.m_input.notifyPageFull();
				return;
			};
			GridRows.overflow(rows, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS);
			mod.m_book.setPageRows(mod.m_livePage, rows);
			mod.m_store.applyGrid(true);
			rebuildBench();
			if (i < ids.length && i < mod.m_addScroll + pageSize)
			{
				mod.m_input.notifyPageFull();
			};
		}

		private function onAddCloseClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_bar.setEditMode(StageEditorMod.MODE_SORT);
		}

		private function onPageMinusClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_book.setPageTotal(mod.m_book.pageCount() - 1);
		}

		private function onPagePlusClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_book.setPageTotal(mod.m_book.pageCount() + 1);
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
			if (n != mod.m_book.pageCount())
			{
				mod.m_book.setPageTotal(n);
			}
			else
			{
				syncAddPageControls();
			};
		}

		internal function syncAddPageControls():void
		{
			var field:TextField;
			var trainBtn:Sprite;
			var extrasBtn:Sprite;
			var prevBtn:Sprite;
			var nextBtn:Sprite;
			var counter:TextField;
			var ids:Array;
			var pageSize:int;
			var total:int;
			var current:int;
			var hasPrev:Boolean;
			var hasNext:Boolean;
			if (!mod.m_addPopup)
			{
				return;
			};
			field = mod.m_addPopup.getChildByName("pageField") as TextField;
			if (field && field.text != String(mod.m_book.pageCount()))
			{
				field.text = String(mod.m_book.pageCount());
			};
			trainBtn = mod.m_addPopup.getChildByName("train") as Sprite;
			if (trainBtn)
			{
				trainBtn.alpha = mod.m_allowTraining ? 1 : 0.4;
			};
			extrasBtn = mod.m_addPopup.getChildByName("extras") as Sprite;
			if (extrasBtn)
			{
				extrasBtn.alpha = mod.m_showExtraStages ? 1 : 0.4;
			};
			ids = mod.m_catalog.unusedIds();
			pageSize = addPageSize();
			total = ids.length <= 0 ? 0 : int(Math.ceil(ids.length / pageSize));
			current = total <= 0 ? 0 : int(Math.floor(mod.m_addScroll / pageSize) + 1);
			hasPrev = mod.m_addScroll > 0;
			hasNext = mod.m_addScroll + pageSize < ids.length;
			prevBtn = mod.m_addPopup.getChildByName("prev") as Sprite;
			if (prevBtn)
			{
				prevBtn.alpha = hasPrev ? 1 : 0.35;
				prevBtn.mouseEnabled = hasPrev;
			};
			nextBtn = mod.m_addPopup.getChildByName("next") as Sprite;
			if (nextBtn)
			{
				nextBtn.alpha = hasNext ? 1 : 0.35;
				nextBtn.mouseEnabled = hasNext;
			};
			counter = mod.m_addPopup.getChildByName("addPageCounter") as TextField;
			if (counter)
			{
				counter.text = current + "/" + total;
			};
		}

		private function onExtrasToggleClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_showExtraStages = !mod.m_showExtraStages;
			mod.m_addScroll = 0;
			rebuildAddPopup();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify(mod.m_showExtraStages ? "Showing extra / special-mode stages." : "Hiding extra / special-mode stages.");
				};
			}
			catch (err:*)
			{
			};
		}

		private function onTrainToggleClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_store.setAllowTraining(!mod.m_allowTraining);
		}

		private function onAddPrevClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (mod.m_addScroll <= 0)
			{
				return;
			};
			mod.m_addScroll -= addPageSize();
			if (mod.m_addScroll < 0)
			{
				mod.m_addScroll = 0;
			};
			rebuildAddPopup();
		}

		private function onAddNextClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (mod.m_addScroll + addPageSize() >= mod.m_catalog.unusedIds().length)
			{
				return;
			};
			mod.m_addScroll += addPageSize();
			rebuildAddPopup();
		}

		private function onAddWheel(e:MouseEvent):void
		{
			mod.m_addScroll += (e.delta > 0 ? -addPageSize() : addPageSize());
			rebuildAddPopup();
			e.stopPropagation();
		}
	}
}
