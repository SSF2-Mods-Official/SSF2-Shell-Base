package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;

	/**
	 * Character Select pages: page count, the prev/next nav tiles, switching pages, and which
	 * page already holds a character.
	 */
	public class CssPaging
	{
		private var mod:CssEditorMod;

		public function CssPaging(owner:CssEditorMod)
		{
			mod = owner;
		}

		internal function pageCount():int
		{
			return (mod.m_pages && mod.m_pages.length > 0 ? mod.m_pages.length : 1);
		}

		internal function isPageNav(id:String):Boolean
		{
			return (id == CssEditorMod.PAGE_PREV || id == CssEditorMod.PAGE_NEXT);
		}

		internal function rememberPage(cleaned:Array):void
		{
			if (!mod.m_pages || mod.m_pages.length < 1)
			{
				mod.m_pages = [GridRows.cloneRows(cleaned)];
				mod.m_page = 0;
				return;
			};
			while (mod.m_pages.length <= mod.m_page)
			{
				mod.m_pages.push([]);
			};
			mod.m_pages[mod.m_page] = GridRows.cloneRows(cleaned);
		}

		internal function ensureNavOn(rows:Array):Array
		{
			var last:Array;
			rows = stripNav(rows);
			if (rows.length < 1)
			{
				rows.push([]);
			};
			last = rows[rows.length - 1] as Array;
			if (!last)
			{
				last = [];
				rows[rows.length - 1] = last;
			};
			if (pageCount() > 2)
			{
				last.push(CssEditorMod.PAGE_PREV);
			};
			last.push(CssEditorMod.PAGE_NEXT);
			return (rows);
		}

		internal function dropNavId(rows:Array, drop:String):Array
		{
			return (GridRows.filterIds(rows, function(id:String):Boolean
			{
				return (id != drop);
			}));
		}

		private function stripNav(rows:Array):Array
		{
			return (GridRows.filterIds(rows, function(id:String):Boolean
			{
				return (!isPageNav(id));
			}));
		}

		private function absorbRows(dest:Array, src:Array):void
		{
			var ids:Array;
			var i:int;
			var id:String;
			ids = GridRows.flatten(src);
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (id && !isPageNav(id) && !GridRows.inRows(dest, id))
				{
					GridRows.insertBeforePinned(dest, id);
				};
				i++;
			};
		}

		internal function setPageCount(n:int):void
		{
			var mappings:Object;
			var cur:Array;
			var field:TextField;
			var dropped:Array;
			var i:int;
			if (n < 1)
			{
				n = 1;
			};
			if (n > CssEditorMod.MAX_PAGES)
			{
				n = CssEditorMod.MAX_PAGES;
			};
			mappings = EditorEngine.mappings();
			cur = mappings ? GridRows.cloneRows(mappings.character_select_screen.rows as Array) : [[]];
			if (!mod.m_pages || mod.m_pages.length < 1)
			{
				mod.m_pages = [cur];
				mod.m_page = 0;
			}
			else
			{
				mod.m_pages[mod.m_page] = cur;
			};
			while (mod.m_pages.length < n)
			{
				mod.m_pages.push([[]]);
			};
			while (mod.m_pages.length > n)
			{
				dropped = mod.m_pages[mod.m_pages.length - 1] as Array;
				mod.m_pages.pop();
				if (mod.m_pages.length > 0 && dropped)
				{
					absorbRows(mod.m_pages[mod.m_pages.length - 1] as Array, dropped);
				};
			};
			if (mod.m_page >= mod.m_pages.length)
			{
				mod.m_page = mod.m_pages.length - 1;
			};
			if (n > 1)
			{
				i = 0;
				while (i < mod.m_pages.length)
				{
					mod.m_pages[i] = ensureNavOn(mod.m_pages[i] as Array);
					i++;
				};
			}
			else
			{
				mod.m_pages[0] = stripNav(mod.m_pages[0] as Array);
				mod.m_page = 0;
			};
			mod.m_roster.applyRows(GridRows.cloneRows(mod.m_pages[mod.m_page] as Array), true);
			if (mod.m_addPopup)
			{
				field = mod.m_addPopup.getChildByName("pageField") as TextField;
				if (field)
				{
					field.text = String(pageCount());
				};
			};
		}

		private function showPage(index:int):void
		{
			var mappings:Object;
			var n:int;
			n = pageCount();
			if (n <= 1 || !mod.m_pages)
			{
				return;
			};
			if (index < 0)
			{
				index = n - 1;
			};
			if (index >= n)
			{
				index = 0;
			};
			mappings = EditorEngine.mappings();
			if (mappings && mappings.character_select_screen)
			{
				mod.m_pages[mod.m_page] = GridRows.cloneRows(mappings.character_select_screen.rows as Array);
			};
			mod.m_page = index;
			mod.m_roster.applyRows(GridRows.cloneRows(mod.m_pages[mod.m_page] as Array), true);
		}

		internal function activatePageTile(id:String):void
		{
			if (pageCount() <= 1)
			{
				return;
			};
			if (id == CssEditorMod.PAGE_PREV)
			{
				showPage(mod.m_page - 1);
			}
			else if (id == CssEditorMod.PAGE_NEXT)
			{
				showPage(mod.m_page + 1);
			};
		}

		internal function pageClip(icons:DisplayObjectContainer, id:String):DisplayObject
		{
			var clip:Sprite;
			var tf:TextField;
			if (!isPageNav(id) || !icons)
			{
				return (null);
			};
			clip = mod.m_pageClips ? (mod.m_pageClips[id] as Sprite) : null;
			if (clip && clip.parent == icons)
			{
				return (clip);
			};
			clip = new Sprite();
			clip.name = id;
			clip.graphics.beginFill(0x2A2A36, 1);
			clip.graphics.lineStyle(2, 0xE8A020, 1);
			clip.graphics.drawRoundRect(-21, -21, 42, 42, 6, 6);
			clip.graphics.endFill();
			tf = new TextField();
			tf.x = -21;
			tf.y = -14;
			tf.width = 42;
			tf.height = 28;
			tf.wordWrap = false;
			tf.multiline = true;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", 8, 0xF2F2F2, true, null, null, null, null, "center");
			tf.text = id == CssEditorMod.PAGE_PREV ? "Previous\nPage" : "Next\nPage";
			clip.addChild(tf);
			clip.mouseChildren = false;
			clip.buttonMode = true;
			clip.addEventListener(MouseEvent.CLICK, onPageTileClick);
			icons.addChild(clip);
			if (!mod.m_pageClips)
			{
				mod.m_pageClips = {};
			};
			mod.m_pageClips[id] = clip;
			return (clip);
		}

		internal function hidePageClips():void
		{
			var id:String;
			var clip:DisplayObject;
			if (!mod.m_pageClips)
			{
				return;
			};
			for (id in mod.m_pageClips)
			{
				clip = mod.m_pageClips[id] as DisplayObject;
				if (clip)
				{
					mod.m_layout.hideCssClip(clip);
				};
			};
		}

		private function onPageTileClick(e:MouseEvent):void
		{
			var id:String;
			if (mod.m_editing)
			{
				return;
			};
			id = e.currentTarget ? String(e.currentTarget.name) : "";
			if (isPageNav(id))
			{
				e.stopPropagation();
				EditBar.playSfx("menu_hover");
				activatePageTile(id);
			};
		}

		internal function characterRemains(rows:Array, drop:Object):Boolean
		{
			var ids:Array;
			var i:int;
			var id:String;
			if (!rows)
			{
				return (false);
			};
			ids = GridRows.flatten(rows);
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (id && id != "random" && !isPageNav(id) && !(drop && drop[id]))
				{
					return (true);
				};
				i++;
			};
			return (false);
		}

		private function rosterHasCharacter():Boolean
		{
			var mappings:Object;
			mappings = EditorEngine.mappings();
			if (!mappings || !mappings.character_select_screen)
			{
				return (false);
			};
			return (characterRemains(mappings.character_select_screen.rows as Array, null));
		}

		internal function canMarkForRemove(id:String):Boolean
		{
			if (!id || isPageNav(id))
			{
				return (false);
			};
			if (id == "random")
			{
				return (rosterHasCharacter());
			};
			return (!GridRows.isPinned(id));
		}

		private function occupiedElsewhere(id:String):Boolean
		{
			var i:int;
			if (!id || GridRows.isPinned(id) || isPageNav(id) || !mod.m_pages || mod.m_pages.length < 2)
			{
				return (false);
			};
			i = 0;
			while (i < mod.m_pages.length)
			{
				if (i != mod.m_page && GridRows.inRows(mod.m_pages[i] as Array, id))
				{
					return (true);
				};
				i++;
			};
			return (false);
		}

		internal function claimedByEarlierPage(id:String):Boolean
		{
			var i:int;
			if (!id || GridRows.isPinned(id) || isPageNav(id) || !mod.m_pages || mod.m_page <= 0)
			{
				return (false);
			};
			i = 0;
			while (i < mod.m_page && i < mod.m_pages.length)
			{
				if (GridRows.inRows(mod.m_pages[i] as Array, id))
				{
					return (true);
				};
				i++;
			};
			return (false);
		}

		internal function placedAnywhere(id:String):Boolean
		{
			var mappings:Object;
			var rows:Array;
			if (!id || GridRows.isPinned(id) || isPageNav(id) || occupiedElsewhere(id))
			{
				return (true);
			};
			mappings = EditorEngine.mappings();
			rows = mappings && mappings.character_select_screen ? (mappings.character_select_screen.rows as Array) : null;
			return (GridRows.inRows(rows, id));
		}
	}
}
