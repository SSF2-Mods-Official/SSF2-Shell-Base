package com.sbxmod.paletteMaker
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFieldAutoSize;

	/**
	 * Full-screen achievements browser: categories, pagination, completed filter.
	 */
	public class AchievementsPopup extends PopupBase
	{
		public var onClose:Function = null;
		public var onBuyHint:Function = null;

		private static const STAGE_W:Number = 640;
		private static const STAGE_H:Number = 360;
		private static const PANEL_W:Number = 620;
		private static const PANEL_H:Number = 340;
		private static const ROW_H:Number = 34;
		private static const PAGE_SIZE:int = 7;

		private var listHolder:Sprite;
		private var headerTf:TextField;
		private var pageTf:TextField;
		private var catButtons:Array;
		private var prevBtn:Sprite;
		private var nextBtn:Sprite;
		private var filterLockedBtn:Sprite;
		private var filterDoneBtn:Sprite;
		private var filterAllBtn:Sprite;

		private var category:String = "all";
		/** locked | done | all */
		private var progressFilter:String = "locked";
		private var pageIndex:int = 0;
		private var filtered:Array = [];

		private static const CATEGORIES:Array = [
			{ "id": "all", "label": "All", "color": 0x8899AA, "row": 0x22222C, "rowAlt": 0x1E1E28 },
			{ "id": "ritual", "label": "Rituals", "color": 0x66BBFF, "row": 0x1A2A3A, "rowAlt": 0x162432 },
			{ "id": "group", "label": "Groups", "color": 0x88DD77, "row": 0x1A2E1A, "rowAlt": 0x162816 },
			{ "id": "sheet", "label": "Sheets", "color": 0xFFCC66, "row": 0x2E2A1A, "rowAlt": 0x282416 },
			{ "id": "roster", "label": "Roster", "color": 0xFF8866, "row": 0x2E1E1A, "rowAlt": 0x281A16 },
			{ "id": "mile", "label": "Miles", "color": 0xCC99FF, "row": 0x261A2E, "rowAlt": 0x221628 },
			{ "id": "secret", "label": "Secrets", "color": 0xFF66AA, "row": 0x2E1A26, "rowAlt": 0x281622 },
			{ "id": "flavor", "label": "Flavor", "color": 0x66DDCC, "row": 0x1A2E2C, "rowAlt": 0x162826 }
		];

		public function AchievementsPopup()
		{
			mouseEnabled = false;
			mouseChildren = false;
			buildPanel();
			visible = false;
		}

		private function buildPanel():void
		{
			var title:TextField;
			var closeBtn:Sprite;
			var i:int;
			var cat:Object;
			var btn:Sprite;
			var label:TextField;
			var bx:Number;

			makeBackdrop(0, 0, STAGE_W, STAGE_H, onBackdropClick);
			makePanel(PANEL_W, PANEL_H, 0.98, 0x555566, true);
			panel.x = (STAGE_W - PANEL_W) * 0.5;
			panel.y = (STAGE_H - PANEL_H) * 0.5;

			title = makeLabel("Achievements", 13, true);
			title.x = 10;
			title.y = 4;
			panel.addChild(title);

			headerTf = makeLabel("Cookies: 0  |  Unlocked: 0/0", 9, false, 0xCCCCAA);
			headerTf.x = 120;
			headerTf.y = 7;
			panel.addChild(headerTf);

			closeBtn = makeTextButton("Close", 56, 18);
			closeBtn.x = PANEL_W - 66;
			closeBtn.y = 5;
			closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hide();
				if (onClose != null) onClose();
			});
			panel.addChild(closeBtn);

			catButtons = [];
			bx = 10;
			i = 0;
			while (i < CATEGORIES.length)
			{
				cat = CATEGORIES[i];
				btn = makeTextButton(String(cat.label), 70, 18);
				btn.x = bx;
				btn.y = 28;
				btn.name = String(cat.id);
				btn.addEventListener(MouseEvent.CLICK, onCategoryClick);
				panel.addChild(btn);
				catButtons.push(btn);
				bx += 74;
				i++;
			};

			filterLockedBtn = makeTextButton("Incomplete", 78, 18);
			filterLockedBtn.x = 10;
			filterLockedBtn.y = 50;
			filterLockedBtn.name = "locked";
			filterLockedBtn.addEventListener(MouseEvent.CLICK, onProgressFilterClick);
			panel.addChild(filterLockedBtn);

			filterDoneBtn = makeTextButton("Completed", 78, 18);
			filterDoneBtn.x = 92;
			filterDoneBtn.y = 50;
			filterDoneBtn.name = "done";
			filterDoneBtn.addEventListener(MouseEvent.CLICK, onProgressFilterClick);
			panel.addChild(filterDoneBtn);

			filterAllBtn = makeTextButton("All", 40, 18);
			filterAllBtn.x = 174;
			filterAllBtn.y = 50;
			filterAllBtn.name = "all";
			filterAllBtn.addEventListener(MouseEvent.CLICK, onProgressFilterClick);
			panel.addChild(filterAllBtn);

			pageTf = makeLabel("Page 1/1", 9, false, 0xAAAAAA);
			pageTf.x = 224;
			pageTf.y = 52;
			panel.addChild(pageTf);

			prevBtn = makeTextButton("Prev", 50, 18);
			prevBtn.x = PANEL_W - 170;
			prevBtn.y = 50;
			prevBtn.addEventListener(MouseEvent.CLICK, onPrevPage);
			panel.addChild(prevBtn);

			nextBtn = makeTextButton("Next", 50, 18);
			nextBtn.x = PANEL_W - 114;
			nextBtn.y = 50;
			nextBtn.addEventListener(MouseEvent.CLICK, onNextPage);
			panel.addChild(nextBtn);

			listHolder = new Sprite();
			listHolder.x = 10;
			listHolder.y = 74;
			panel.addChild(listHolder);
		}

		private function onBackdropClick(e:MouseEvent):void
		{
			hide();
			if (onClose != null) onClose();
		}

		private function onCategoryClick(e:MouseEvent):void
		{
			var btn:Sprite = e.currentTarget as Sprite;
			if (!btn)
			{
				return;
			};
			category = btn.name;
			pageIndex = 0;
			rebuildList();
		}

		private function onProgressFilterClick(e:MouseEvent):void
		{
			var btn:Sprite = e.currentTarget as Sprite;
			if (!btn)
			{
				return;
			};
			progressFilter = btn.name;
			pageIndex = 0;
			rebuildList();
		}

		private function onPrevPage(e:MouseEvent):void
		{
			if (pageIndex > 0)
			{
				pageIndex--;
				rebuildList();
			};
		}

		private function onNextPage(e:MouseEvent):void
		{
			var pages:int = Math.max(1, Math.ceil(filtered.length / Number(PAGE_SIZE)));
			if (pageIndex < pages - 1)
			{
				pageIndex++;
				rebuildList();
			};
		}

		/** Full-stage overlay; ignores px/py from older callers. */
		public function showAt(px:Number = 0, py:Number = 0):void
		{
			x = 0;
			y = 0;
			setOpen(true);
			pageIndex = 0;
			rebuildList();
		}

		public function refresh():void
		{
			if (visible)
			{
				rebuildList();
			};
		}

		public function hide():void
		{
			setOpen(false);
		}

		private function rebuildList():void
		{
			var catalog:Array;
			var i:int;
			var def:Object;
			var unlocked:Boolean;
			var hinted:Boolean;
			var row:Sprite;
			var titleTf:TextField;
			var descTf:TextField;
			var hintBtn:Sprite;
			var rowY:Number;
			var cookies:int;
			var unlockedCount:int;
			var cost:int;
			var id:String;
			var start:int;
			var end:int;
			var pages:int;
			var tags:Array;
			var tag:String;
			var matchCat:Boolean;
			var btn:Sprite;
			var pageItems:Array;

			while (listHolder.numChildren > 0)
			{
				listHolder.removeChildAt(0);
			};

			catalog = PaletteMakerAchievements.getCatalog();
			cookies = PaletteMakerAchievements.getCookies();
			unlockedCount = PaletteMakerAchievements.getUnlockedCount();
			headerTf.text = "Cookies: " + cookies + "  |  Unlocked: " + unlockedCount + "/" + catalog.length;

			i = 0;
			while (i < catButtons.length)
			{
				btn = catButtons[i] as Sprite;
				tintCategoryButton(btn, btn.name == category, 70, categoryColor(String(btn.name)));
				i++;
			};
			tintButton(filterLockedBtn, progressFilter == "locked", 78);
			tintButton(filterDoneBtn, progressFilter == "done", 78);
			tintButton(filterAllBtn, progressFilter == "all", 40);

			filtered = [];
			i = 0;
			while (i < catalog.length)
			{
				def = catalog[i];
				id = String(def.id);
				unlocked = PaletteMakerAchievements.isUnlocked(id);
				if (progressFilter == "locked" && unlocked)
				{
					i++;
					continue;
				};
				if (progressFilter == "done" && !unlocked)
				{
					i++;
					continue;
				};
				matchCat = (category == "all");
				if (!matchCat)
				{
					tags = def.tags is Array ? (def.tags as Array) : [];
					for each (tag in tags)
					{
						if (String(tag) == category)
						{
							matchCat = true;
							break;
						};
					};
				};
				if (matchCat)
				{
					filtered.push(def);
				};
				i++;
			};

			pages = Math.max(1, Math.ceil(filtered.length / Number(PAGE_SIZE)));
			if (pageIndex >= pages)
			{
				pageIndex = pages - 1;
			};
			if (pageIndex < 0)
			{
				pageIndex = 0;
			};
			pageTf.text = "Page " + (pageIndex + 1) + "/" + pages
				+ "  (" + filtered.length + " shown)";

			start = pageIndex * PAGE_SIZE;
			end = Math.min(filtered.length, start + PAGE_SIZE);
			pageItems = filtered.slice(start, end);
			rowY = 0;
			i = 0;
			while (i < pageItems.length)
			{
				def = pageItems[i];
				id = String(def.id);
				unlocked = PaletteMakerAchievements.isUnlocked(id);
				hinted = PaletteMakerAchievements.hasHint(id);
				tag = primaryTag(def);
				row = new Sprite();
				row.y = rowY;
				row.graphics.lineStyle(1, categoryColor(tag), 0.7);
				row.graphics.beginFill(rowColorForTag(tag, i % 2 == 0), 1);
				row.graphics.drawRoundRect(0, 0, PANEL_W - 20, ROW_H, 3, 3);
				row.graphics.endFill();
				// Category color stripe on the left.
				row.graphics.lineStyle(0, 0, 0);
				row.graphics.beginFill(categoryColor(tag), 1);
				row.graphics.drawRect(1, 1, 4, ROW_H - 2);
				row.graphics.endFill();

				if (unlocked)
				{
					titleTf = makeLabel("★ " + String(def.title), 9, true, 0xAAFFAA);
					titleTf.x = 8;
					titleTf.y = 2;
					row.addChild(titleTf);
					descTf = makeLabel(clip(String(def.desc), 90), 8, false, 0xDDDDDD);
					descTf.x = 8;
					descTf.y = 16;
					row.addChild(descTf);
				}
				else if (hinted)
				{
					titleTf = makeLabel("???", 9, true, categoryColor(tag));
					titleTf.x = 8;
					titleTf.y = 2;
					row.addChild(titleTf);
					descTf = makeLabel(clip("Hint: " + String(def.hint), 90), 8, false, 0xCCCC88);
					descTf.x = 8;
					descTf.y = 16;
					row.addChild(descTf);
				}
				else
				{
					titleTf = makeLabel("???", 9, true, 0x888899);
					titleTf.x = 8;
					titleTf.y = 2;
					row.addChild(titleTf);
					descTf = makeLabel("Locked achievement", 8, false, 0x666677);
					descTf.x = 8;
					descTf.y = 16;
					row.addChild(descTf);
					cost = int(def.cookieHintCost);
					if (cost <= 0) cost = 12;
					hintBtn = makeTextButton("Hint (" + cost + ")", 78, 18);
					hintBtn.x = PANEL_W - 20 - 86;
					hintBtn.y = 7;
					hintBtn.name = id;
					hintBtn.addEventListener(MouseEvent.CLICK, onHintClick);
					row.addChild(hintBtn);
				};
				listHolder.addChild(row);
				rowY += ROW_H + 2;
				i++;
			};
		}

		private function primaryTag(def:Object):String
		{
			var tags:Array;
			if (!def)
			{
				return "all";
			};
			tags = def.tags is Array ? (def.tags as Array) : [];
			if (tags.length > 0)
			{
				return String(tags[0]);
			};
			return "all";
		}

		private function categoryColor(catId:String):uint
		{
			var cat:Object;
			for each (cat in CATEGORIES)
			{
				if (String(cat.id) == catId)
				{
					return uint(cat.color);
				};
			};
			return 0x8899AA;
		}

		private function rowColorForTag(catId:String, even:Boolean):uint
		{
			var cat:Object;
			for each (cat in CATEGORIES)
			{
				if (String(cat.id) == catId)
				{
					return even ? uint(cat.row) : uint(cat.rowAlt);
				};
			};
			return even ? 0x22222C : 0x1E1E28;
		}

		private function tintCategoryButton(btn:Sprite, on:Boolean, w:Number, accent:uint):void
		{
			var label:TextField;
			if (!btn)
			{
				return;
			};
			btn.graphics.clear();
			btn.graphics.beginFill(on ? accent : 0x2A2A35, on ? 0.35 : 1);
			btn.graphics.lineStyle(1, on ? accent : 0x666677, 1);
			btn.graphics.drawRoundRect(0, 0, w, 18, 4, 4);
			btn.graphics.endFill();
			label = btn.numChildren > 0 ? (btn.getChildAt(0) as TextField) : null;
			if (label)
			{
				label.textColor = on ? accent : 0xFFFFFF;
			};
		}

		private function tintButton(btn:Sprite, on:Boolean, w:Number):void
		{
			var label:TextField;
			if (!btn)
			{
				return;
			};
			btn.graphics.clear();
			btn.graphics.beginFill(on ? 0x3A4A66 : 0x2A2A35, 1);
			btn.graphics.lineStyle(1, on ? 0x88AACC : 0x666677, 1);
			btn.graphics.drawRoundRect(0, 0, w, 18, 4, 4);
			btn.graphics.endFill();
			label = btn.numChildren > 0 ? (btn.getChildAt(0) as TextField) : null;
			if (label)
			{
				label.textColor = on ? 0x88CCFF : 0xFFFFFF;
			};
		}

		private function onHintClick(e:MouseEvent):void
		{
			var btn:Sprite = e.currentTarget as Sprite;
			var id:String;
			if (!btn)
			{
				return;
			};
			id = btn.name;
			if (onBuyHint != null)
			{
				onBuyHint(id);
			}
			else
			{
				PaletteMakerAchievements.buyHint(id);
			};
			rebuildList();
		}

		private function clip(s:String, maxLen:int):String
		{
			if (!s)
			{
				return "";
			};
			if (s.length <= maxLen)
			{
				return s;
			};
			return s.substr(0, maxLen - 1) + "…";
		}
	}
}
