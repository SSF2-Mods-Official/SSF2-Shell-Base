package
{
	import flash.utils.getTimer;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Stage Select pages in memory: the page grid, page count, remove/sort edits on a page,
	 * and switching the live page from the engine's page gesture and stage-select hooks.
	 */
	public class StagePages
	{
		private static const PAGE_COUNT:int = 4;
		private static const SXP_CYCLE_MS:int = 200;

		private var mod:StageEditorMod;
		private var m_sxpCycleAt:int;

		public function StagePages(owner:StageEditorMod)
		{
			mod = owner;
			m_sxpCycleAt = 0;
		}

		internal function pageCount():int
		{
			var n:int;
			n = mod.m_grid ? mod.m_grid.length : 1;
			if (n < 1)
			{
				n = 1;
			};
			return (n);
		}

		internal function flattenAllPages():Array
		{
			var out:Array;
			var i:int;
			out = [];
			i = 0;
			while (i < pageCount())
			{
				out = out.concat(GridRows.flatten(pageRows(i)));
				i++;
			};
			return (out);
		}

		internal function addNewPage():void
		{
			if (!mod.m_grid)
			{
				mod.m_grid = emptyGrid();
			};
			if (mod.m_grid.length >= StageEditorMod.MAX_PAGES)
			{
				try
				{
					if (mod.m_host)
					{
						mod.m_host.notify("Maximum " + StageEditorMod.MAX_PAGES + " Stage Select pages.");
					};
				}
				catch (err:*)
				{
				};
				return;
			};
			mod.m_grid.push([[]]);
			mod.m_livePage = mod.m_grid.length - 1;
			mod.m_editPage = mod.m_livePage;
			mod.m_store.applyGrid(true);
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("Stage Select page " + (mod.m_livePage + 1) + "/" + pageCount());
				};
			}
			catch (nerr:*)
			{
			};
			if (mod.m_mode == StageEditorMod.MODE_ADD)
			{
				mod.m_addScroll = 0;
				mod.m_addUi.rebuildAddPopup();
			};
		}

		internal function setPageTotal(n:int):void
		{
			if (!mod.m_grid)
			{
				mod.m_grid = emptyGrid();
			};
			GridRows.resizePages(mod.m_grid, n, StageEditorMod.MAX_PAGES);
			if (mod.m_livePage >= mod.m_grid.length)
			{
				mod.m_livePage = mod.m_grid.length - 1;
			};
			if (mod.m_livePage < 0)
			{
				mod.m_livePage = 0;
			};
			mod.m_editPage = mod.m_livePage;
			mod.m_store.applyGrid(true);
			mod.m_addUi.syncAddPageControls();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("Stage Select pages: " + pageCount());
				};
			}
			catch (nerr:*)
			{
			};
		}

		internal function hasRemoveSelection():Boolean
		{
			var id:String;
			for (id in mod.m_removeIds)
			{
				if (mod.m_removeIds[id])
				{
					return (true);
				};
			};
			return (false);
		}

		internal function toggleRemoveId(id:String):void
		{
			if (!id || GridRows.isPinned(id))
			{
				return;
			};
			if (mod.m_removeIds[id])
			{
				delete mod.m_removeIds[id];
			}
			else
			{
				mod.m_removeIds[id] = true;
			};
			mod.m_bar.layoutBottomButtons();
		}

		internal function confirmRemove():void
		{
			var id:String;
			var rows:Array;
			if (!hasRemoveSelection())
			{
				return;
			};
			rows = GridRows.cloneRows(pageRows(mod.m_livePage));
			for (id in mod.m_removeIds)
			{
				if (mod.m_removeIds[id])
				{
					GridRows.removeId(rows, id);
				};
			};
			mod.m_removeIds = {};
			ensureRandomOnPage(rows);
			setPageRows(mod.m_livePage, rows);
			mod.m_store.applyGrid(true);
			mod.m_bar.layoutBottomButtons();
		}

		internal function removeAllOnPage():void
		{
			var rows:Array;
			rows = [["random"]];
			mod.m_removeIds = {};
			setPageRows(mod.m_livePage, rows);
			mod.m_store.applyGrid(true);
			mod.m_bar.layoutBottomButtons();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("Removed all stages on this page. Random kept.");
				};
			}
			catch (err:*)
			{
			};
		}

		private function ensureRandomOnPage(rows:Array):void
		{
			var line:Array;
			if (!rows)
			{
				return;
			};
			if (GridRows.inRows(rows, "random"))
			{
				return;
			};
			if (rows.length < 1)
			{
				rows.push(["random"]);
				return;
			};
			line = rows[0] as Array;
			if (!line)
			{
				rows[0] = ["random"];
				return;
			};
			line.unshift("random");
		}

		internal function sortClick(id:String):void
		{
			var rows:Array;
			var targetRow:int;
			var targetCol:int;
			if (!id)
			{
				return;
			};
			if (!mod.m_sortPickId)
			{
				mod.m_sortPickId = id;
				return;
			};
			if (mod.m_sortPickId == id)
			{
				mod.m_sortPickId = "";
				return;
			};
			rows = GridRows.cloneRows(pageRows(mod.m_livePage));
			targetRow = GridRows.rowOf(rows, id);
			targetCol = GridRows.colOf(rows, id);
			GridRows.removeId(rows, mod.m_sortPickId);
			if (targetRow >= 0)
			{
				GridRows.insertAt(rows, targetRow, targetCol, mod.m_sortPickId);
			}
			else
			{
				GridRows.insertAt(rows, rows.length, 0, mod.m_sortPickId);
			};
			mod.m_sortPickId = "";
			GridRows.overflow(rows, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS);
			setPageRows(mod.m_livePage, rows);
			mod.m_store.applyGrid(true);
		}

		internal function onPageGesture(ctx:Object):void
		{
			var chords:Array;
			if (!ctx)
			{
				return;
			};
			chords = (ctx.chords as Array) || [];
			if (chords.indexOf("TAUNT") < 0 || chords.indexOf("SHIELD") >= 0)
			{
				return;
			};
			ctx.cancel = true;
			ctx.consume = true;
			cycleLivePage();
		}

		internal function onStageSelectHook(ctx:Object):void
		{
			var id:String;
			var GC:Class;
			if (!ctx)
			{
				return;
			};
			id = String(ctx.requestedId || ctx.stageId || "");
			if (mod.m_bgPicking && id && id != "xpstage")
			{
				mod.m_bgPicking = false;
				mod.m_bar.layoutBottomButtons();
			};
			if (mod.m_editing)
			{
				ctx.cancel = true;
				try
				{
					GC = EngineRefs.GameController as Class;
					GC["isStarted"] = false;
				}
				catch (stopErr:*)
				{
				};
				return;
			};
			if (id != "xpstage")
			{
				return;
			};
			ctx.cancel = true;
			try
			{
				GC = EngineRefs.GameController as Class;
				GC["isStarted"] = false;
			}
			catch (err:*)
			{
			};
			cycleLivePage();
		}

		internal function cycleLivePage():void
		{
			var n:int;
			var now:int;
			now = getTimer();
			if (m_sxpCycleAt > 0 && (now - m_sxpCycleAt) < SXP_CYCLE_MS)
			{
				mod.log("SXP cycle ignored debounce dt=" + (now - m_sxpCycleAt));
				return;
			};
			n = pageCount();
			if (n <= 1)
			{
				mod.log("SXP cycle skipped pageCount=" + n);
				try
				{
					if (mod.m_host)
					{
						mod.m_host.notify("Only one Stage Select page.");
					};
				}
				catch (err:*)
				{
				};
				return;
			};
			m_sxpCycleAt = now;
			mod.m_livePage = (mod.m_livePage + 1) % n;
			if (mod.m_livePage < 0)
			{
				mod.m_livePage = 0;
			};
			mod.log("SXP page -> P" + (mod.m_livePage + 1) + " n=" + GridRows.flatten(pageRows(mod.m_livePage)).length);
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("Stage Select page " + (mod.m_livePage + 1));
				};
			}
			catch (notifyErr:*)
			{
			};
			if (mod.m_editing)
			{
				mod.m_editPage = mod.m_livePage;
				mod.m_removeIds = {};
				mod.m_sortPickId = "";
				if (mod.m_mode == StageEditorMod.MODE_ADD)
				{
					mod.m_addScroll = 0;
					mod.m_addUi.rebuildAddPopup();
				};
				mod.m_bar.layoutBottomButtons();
			};
		}

		internal function pageBlock(mappings:Object):Object
		{
			var normal:Object;
			normal = mappings.stage_select_screen.normal;
			if (mod.m_livePage < 0 || mod.m_livePage >= pageCount())
			{
				mod.m_livePage = 0;
			};
			return ({
				"_rows": pageRows(mod.m_livePage),
				"_pos": normal.position,
				"_size": normal.icon_size
			});
		}

		internal function emptyGrid():Array
		{
			return ([[[]], [[]], [[]], [[]]]);
		}

		internal function cloneGrid(src:Array):Array
		{
			var out:Array;
			var i:int;
			var n:int;
			out = emptyGrid();
			n = src ? src.length : PAGE_COUNT;
			if (n < PAGE_COUNT)
			{
				n = PAGE_COUNT;
			};
			i = 0;
			while (src && i < n)
			{
				if (i >= out.length)
				{
					out.push([[]]);
				};
				out[i] = GridRows.cloneRows(src[i] as Array);
				i++;
			};
			return (out);
		}

		internal function pageRows(page:int):Array
		{
			if (!mod.m_grid || page < 0 || page >= mod.m_grid.length || !mod.m_grid[page])
			{
				return ([[]]);
			};
			return (mod.m_grid[page] as Array);
		}

		internal function setPageRows(page:int, rows:Array):void
		{
			if (!mod.m_grid)
			{
				mod.m_grid = emptyGrid();
			};
			if (page < 0 || page > mod.m_grid.length || page >= StageEditorMod.MAX_PAGES)
			{
				return;
			};
			if (page == mod.m_grid.length)
			{
				mod.m_grid.push(GridRows.cloneRows(rows));
				return;
			};
			mod.m_grid[page] = GridRows.cloneRows(rows);
		}

		internal function otherPageRows(page:int):Array
		{
			var out:Array;
			var i:int;
			out = [];
			i = 0;
			while (i < pageCount())
			{
				if (i != page)
				{
					out = out.concat(GridRows.cloneRows(pageRows(i)));
				};
				i++;
			};
			return (out);
		}
	}
}
