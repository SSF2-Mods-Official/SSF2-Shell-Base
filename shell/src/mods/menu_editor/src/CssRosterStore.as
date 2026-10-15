package
{
	/**
	 * Character Select roster persistence and sync: saved rows and page book (css_editor_rows,
	 * css_editor_pages), stock defaults, id sanitizing, Random, and seen-expansion placement.
	 */
	public class CssRosterStore
	{
		private static const SAVE_KEY:String = "css_editor_rows";
		private static const SAVE_KEY_OLD:String = "css_editor.rows";
		private static const SAVE_PAGES:String = "css_editor_pages";
		private static const SAVE_SEEN:String = "css_editor_seen_expansions";

		private var mod:CssEditorMod;
		private var m_defaultIcon:Object;

		public function CssRosterStore(owner:CssEditorMod)
		{
			mod = owner;
		}

		internal function onRestore():void
		{
			var mappings:Object;
			if (!mod.m_defaults)
			{
				captureDefaults();
			};
			if (!mod.m_defaults)
			{
				return;
			};
			mod.m_pages = null;
			mod.m_page = 0;
			applyRows(GridRows.cloneRows(mod.m_defaults), false);
			mod.m_paging.hidePageClips();
			clearSaved();
			mappings = EditorEngine.mappings();
			markInstalledExpansionsSeen(mappings);
			if (mappings && mappings.character_select_screen)
			{
				if (mod.m_defaultPos)
				{
					mappings.character_select_screen.position.x = Number(mod.m_defaultPos.x);
					mappings.character_select_screen.position.y = Number(mod.m_defaultPos.y);
				};
				if (m_defaultIcon)
				{
					mappings.character_select_screen.icon_size.width = Number(m_defaultIcon.width);
					mappings.character_select_screen.icon_size.height = Number(m_defaultIcon.height);
				};
			};
			mod.m_removeIds = {};
			mod.m_mode = CssEditorMod.MODE_SORT;
			mod.m_addUi.closeAddPopup();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("Character Select restored to the original roster.");
				};
			}
			catch (err:*)
			{
			};
		}

		internal function captureDefaults():void
		{
			var disk:Object;
			var screen:Object;
			var og:Object;
			og = loadOgScreen();
			disk = og ? og : EditorEngine.appJson("data/misc/mappings.json");
			if (og)
			{
				screen = og;
			}
			else if (disk && disk.character_select_screen)
			{
				screen = disk.character_select_screen;
			}
			else
			{
				return;
			};
			mod.m_defaults = GridRows.cloneRows(screen.rows as Array);
			if (screen.position)
			{
				mod.m_defaultPos = {
					"x": Number(screen.position.x),
					"y": Number(screen.position.y)
				};
			};
			if (screen.icon_size)
			{
				m_defaultIcon = {
					"width": Number(screen.icon_size.width || 42),
					"height": Number(screen.icon_size.height || 42)
				};
			};
		}

		internal function applySaved():void
		{
			var mappings:Object;
			var saved:Array;
			var liveCount:int;
			var placed:int;
			try
			{
				if (!mod.m_host)
				{
					return;
				};
				mappings = EditorEngine.mappings();
				if (!mappings || !mappings.character_select_screen)
				{
					return;
				};
				liveCount = GridRows.flatten(mappings.character_select_screen.rows as Array).length;
				if (loadPageBook())
				{
					saved = GridRows.cloneRows(mod.m_pages[mod.m_page] as Array);
					placed = finishSavedRoster(saved, mappings, true);
					mod.cssLog("applySaved branch=pages savedIds=" + GridRows.flatten(saved).length + " liveIds=" + liveCount + " placed=" + placed);
					return;
				};
				saved = EditorSave.loadRows(mod.m_host, SAVE_KEY, SAVE_KEY_OLD);
				if (saved && GridRows.flatten(saved).length > 0)
				{
					placed = finishSavedRoster(saved, mappings, false);
					mod.cssLog("applySaved branch=rows savedIds=" + GridRows.flatten(saved).length + " liveIds=" + liveCount + " placed=" + placed);
					return;
				};
				if (saveKeyPresent())
				{
					mod.cssLog("applySaved branch=unreadable liveIds=" + liveCount);
					return;
				};
				saved = GridRows.cloneRows(mappings.character_select_screen.rows as Array);
				placed = placeUnseenExpansions(saved, mappings);
				if (placed > 0)
				{
					applyRows(saved, true);
				};
				mod.cssLog("applySaved branch=nosave liveIds=" + liveCount + " placed=" + placed);
			}
			catch (stepErr:*)
			{
				mod.cssLog("fail step=applySaved err=" + stepErr);
			};
		}

		private function finishSavedRoster(saved:Array, mappings:Object, fromBook:Boolean):int
		{
			var placed:int;
			if (seedSeenIfUnset(mappings))
			{
				applyRows(saved, false);
				return (0);
			};
			placed = placeUnseenExpansions(saved, mappings);
			if (placed > 0)
			{
				if (fromBook && mod.m_pages && mod.m_page >= 0 && mod.m_page < mod.m_pages.length)
				{
					mod.m_pages[mod.m_page] = GridRows.cloneRows(saved);
				};
				applyRows(saved, true);
			}
			else
			{
				applyRows(saved, false);
			};
			return (placed);
		}

		private function saveKeyPresent():Boolean
		{
			return (EditorSave.has(mod.m_host, SAVE_PAGES) || EditorSave.has(mod.m_host, SAVE_KEY, SAVE_KEY_OLD));
		}

		private function writeRows(rows:Array):void
		{
			var how:int;
			try
			{
				how = EditorSave.setJson(mod.m_host, SAVE_KEY, GridRows.cloneRows(rows));
				if (how == 0)
				{
					mod.cssLog("writeRows failed " + EditorSave.lastError);
					return;
				};
				mod.cssLog("writeRows ids=" + GridRows.flatten(rows).length + (how == 2 ? " raw" : ""));
			}
			catch (stepErr:*)
			{
				mod.cssLog("fail step=writeRows err=" + stepErr);
			};
		}

		private function clearSaved():void
		{
			mod.m_pages = null;
			mod.m_page = 0;
			EditorSave.clearKeys(mod.m_host, [SAVE_KEY, SAVE_KEY_OLD, SAVE_PAGES]);
		}

		private function loadPageBook():Boolean
		{
			var book:Object;
			var pages:*;
			var i:int;
			var line:Array;
			book = EditorSave.getJson(mod.m_host, SAVE_PAGES);
			if (!book)
			{
				return (false);
			};
			pages = GridRows.asList(book.pages);
			if (!pages || pages.length < 1)
			{
				return (false);
			};
			mod.m_pages = [];
			i = 0;
			while (i < pages.length && i < CssEditorMod.MAX_PAGES)
			{
				line = GridRows.toRows(pages[i]);
				mod.m_pages.push(line ? line : [[]]);
				i++;
			};
			mod.m_page = int(book.page);
			if (mod.m_page < 0 || mod.m_page >= mod.m_pages.length)
			{
				mod.m_page = 0;
			};
			scrubCrossPageDupes();
			return (true);
		}

		private function scrubCrossPageDupes():void
		{
			var seen:Object;
			var i:int;
			var rows:Array;
			var out:Array;
			var r:int;
			var c:int;
			var line:Array;
			var next:Array;
			var id:String;
			var dropped:int;
			if (!mod.m_pages || mod.m_pages.length < 2)
			{
				return;
			};
			seen = {};
			dropped = 0;
			i = 0;
			while (i < mod.m_pages.length)
			{
				rows = mod.m_pages[i] as Array;
				out = [];
				r = 0;
				while (rows && r < rows.length)
				{
					line = rows[r] as Array;
					next = [];
					c = 0;
					while (line && c < line.length)
					{
						id = String(line[c]);
						if (!id)
						{
							c++;
							continue;
						};
						if (GridRows.isPinned(id) || mod.m_paging.isPageNav(id) || !seen[id])
						{
							next.push(id);
							if (!GridRows.isPinned(id) && !mod.m_paging.isPageNav(id))
							{
								seen[id] = true;
							};
						}
						else
						{
							dropped++;
						};
						c++;
					};
					out.push(next);
					r++;
				};
				if (out.length < 1)
				{
					out.push([]);
				};
				mod.m_pages[i] = out;
				i++;
			};
			if (dropped > 0)
			{
				mod.cssLog("scrub cross-page dropped=" + dropped);
				writePages();
			};
		}

		private function writePages():void
		{
			var book:Object;
			try
			{
				if (!mod.m_host)
				{
					return;
				};
				if (!mod.m_pages || mod.m_pages.length < 1)
				{
					mod.m_pages = [[]];
					mod.m_page = 0;
				};
				book = {"page": mod.m_page, "pages": mod.m_pages};
				mod.cssLog("writePages pages=" + mod.m_pages.length + " page=" + mod.m_page + " ids=" + countPageIds());
				EditorSave.setJson(mod.m_host, SAVE_PAGES, book);
			}
			catch (stepErr:*)
			{
				mod.cssLog("fail step=writePages err=" + stepErr);
			};
		}

		internal function applyRows(rows:Array, persist:Boolean):void
		{
			var mappings:Object;
			var cleaned:Array;
			try
			{
				if (!rows)
				{
					return;
				};
				mappings = EditorEngine.mappings();
				if (!mappings || !mappings.character_select_screen)
				{
					return;
				};
				cleaned = sanitizeCssRows(rows, mappings);
				if (mod.m_paging.pageCount() > 1)
				{
					cleaned = mod.m_paging.ensureNavOn(cleaned);
				};
				mappings.character_select_screen.rows = cleaned;
				syncRandom(mappings, cleaned);
				mod.m_layout.hideLeftoverIcons(cleaned);
				mod.m_paging.rememberPage(cleaned);
				if (persist && mod.m_host)
				{
					writeRows(cleaned);
					writePages();
				};
			}
			catch (stepErr:*)
			{
				mod.cssLog("fail step=applyRows err=" + stepErr);
			};
		}

		private function sanitizeCssRows(rows:Array, mappings:Object):Array
		{
			var out:Array;
			var r:int;
			var c:int;
			var line:Array;
			var next:Array;
			var id:String;
			var seen:Object;
			out = [];
			seen = {};
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				next = [];
				if (line)
				{
					c = 0;
					while (c < line.length)
					{
						id = String(line[c]);
						if (id && !seen[id] && isAllowedCssId(id, mappings))
						{
							if (mod.m_paging.claimedByEarlierPage(id))
							{
								mod.cssLog("drop cross-page id=" + id);
							}
							else
							{
								next.push(id);
								seen[id] = true;
							};
						};
						c++;
					};
				};
				out.push(next);
				r++;
			};
			if (out.length <= 0)
			{
				out.push([]);
			};
			return (out);
		}

		private function isAllowedCssId(id:String, mappings:Object):Boolean
		{
			if (id == "random")
			{
				return (true);
			};
			if (mod.m_paging.isPageNav(id))
			{
				return (mod.m_paging.pageCount() > 1);
			};
			if (id == "cxp" || id == "xp")
			{
				return (false);
			};
			if (isJunkId(id))
			{
				return (false);
			};
			if (mappings.character && mappings.character[id])
			{
				return (true);
			};
			return (false);
		}

		private function seedSeenIfUnset(mappings:Object):Boolean
		{
			var seen:Object;
			seen = EditorSave.loadIdSet(mod.m_host, SAVE_SEEN);
			if (seen["*"])
			{
				return (false);
			};
			markInstalledExpansionsSeen(mappings);
			return (true);
		}

		private function markInstalledExpansionsSeen(mappings:Object):void
		{
			var seen:Object;
			var ids:Array;
			var i:int;
			if (!mappings)
			{
				return;
			};
			seen = EditorSave.loadIdSet(mod.m_host, SAVE_SEEN);
			seen["*"] = true;
			ids = expansionIds(mappings);
			i = 0;
			while (i < ids.length)
			{
				seen[String(ids[i])] = true;
				i++;
			};
			EditorSave.writeIdSet(mod.m_host, SAVE_SEEN, seen);
		}

		private function placeUnseenExpansions(rows:Array, mappings:Object):int
		{
			var seen:Object;
			var ids:Array;
			var i:int;
			var id:String;
			var placed:int;
			if (!rows || !mappings)
			{
				return (0);
			};
			seen = EditorSave.loadIdSet(mod.m_host, SAVE_SEEN);
			ids = expansionIds(mappings);
			placed = 0;
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (id && !seen[id] && !GridRows.inRows(rows, id) && isAllowedCssId(id, mappings) && !GridRows.isPinned(id))
				{
					GridRows.insertBeforePinned(rows, id);
					seen[id] = true;
					placed++;
				};
				i++;
			};
			if (placed > 0)
			{
				seen["*"] = true;
				EditorSave.writeIdSet(mod.m_host, SAVE_SEEN, seen);
			};
			return (placed);
		}

		private function expansionIds(mappings:Object):Array
		{
			var ids:Array;
			var id:String;
			ids = [];
			if (!mappings || !mappings.character)
			{
				return (ids);
			};
			for (id in mappings.character)
			{
				if (isExpansionChar(id, mappings) && ids.indexOf(id) < 0)
				{
					ids.push(id);
				};
			};
			return (ids);
		}

		private function isExpansionChar(id:String, mappings:Object):Boolean
		{
			var entry:Object;
			var file:String;
			entry = mappings.character ? mappings.character[id] : null;
			if (!entry)
			{
				return (false);
			};
			file = String(entry.file || entry.file_pub || "");
			return (file.indexOf("expansions/") >= 0);
		}

		internal function collectIds(mappings:Object):Array
		{
			var ids:Array;
			var id:String;
			ids = [];
			if (mappings.character)
			{
				for (id in mappings.character)
				{
					if (ids.indexOf(id) < 0 && isAllowedCssId(id, mappings))
					{
						ids.push(id);
					};
				};
			};
			GridRows.appendMissing(ids, GridRows.flatten(mappings.character_select_screen.rows as Array), []);
			if (ids.indexOf("random") < 0)
			{
				ids.push("random");
			};
			return (ids);
		}

		private function syncRandom(mappings:Object, rows:Array):void
		{
			var list:Array;
			var ids:Array;
			var i:int;
			var id:String;
			var exclude:Array;
			ids = GridRows.flatten(rows);
			list = [];
			exclude = (mappings.exclude_character_from_random as Array) || [];
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (!GridRows.isPinned(id) && mappings.character && mappings.character[id] && exclude.indexOf(id) < 0)
				{
					list.push(id);
				};
				i++;
			};
			if (!mappings.random_characters)
			{
				mappings.random_characters = {};
			};
			mappings.random_characters.characters = list;
		}

		internal function isCssExpansionId(id:String):Boolean
		{
			return (id == "cxp" || id == "xp");
		}

		private function isJunkId(id:String):Boolean
		{
			if (!id)
			{
				return (true);
			};
			if (id == "obama" || id == "masterhand" || id == "masterhan")
			{
				return (true);
			};
			if (id.length >= 6 && id.substr(0, 5) == "empty")
			{
				return (true);
			};
			return (false);
		}

		private function countPageIds():int
		{
			var n:int;
			var i:int;
			if (!mod.m_pages)
			{
				return (0);
			};
			n = 0;
			i = 0;
			while (i < mod.m_pages.length)
			{
				n += GridRows.flatten(mod.m_pages[i] as Array).length;
				i++;
			};
			return (n);
		}

		private function loadOgScreen():Object
		{
			var data:Object;
			data = EditorEngine.appJson("data/ssf2mm/menu_editor/og_character_select.json");
			return (data && data.rows ? data : null);
		}
	}
}
