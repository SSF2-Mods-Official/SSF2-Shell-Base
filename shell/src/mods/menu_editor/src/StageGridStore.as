package
{
	/**
	 * Stage Select persistence and sync: stage_editor_grid, stage_editor_page_count,
	 * stage_editor_training, and stage_editor_seen_expansions; legacy page keys; stock defaults;
	 * id sanitizing; and pushing the grid into the engine mappings.
	 */
	public class StageGridStore
	{
		private static const SAVE_NORMAL:String = "stage_editor_normal_rows";
		private static const SAVE_PAST:String = "stage_editor_past_rows";
		private static const SAVE_NORMAL_OLD:String = "stage_editor.normal_rows";
		private static const SAVE_PAST_OLD:String = "stage_editor.past_rows";
		private static const SAVE_TRAINING:String = "stage_editor_training";
		private static const SAVE_P3:String = "stage_editor_p3_rows";
		private static const SAVE_P4:String = "stage_editor_p4_rows";
		private static const SAVE_EXTRA:String = "stage_editor_extra_pages";
		private static const SAVE_PAGE_COUNT:String = "stage_editor_page_count";
		private static const SAVE_GRID:String = "stage_editor_grid";
		private static const SAVE_SEEN_EXPANSIONS:String = "stage_editor_seen_expansions";

		private var mod:StageEditorMod;
		private var m_defaultScreen:Object;

		public function StageGridStore(owner:StageEditorMod)
		{
			mod = owner;
			m_defaultScreen = null;
		}

		internal function setAllowTraining(on:Boolean):void
		{
			var mappings:Object;
			mappings = EditorEngine.mappings();
			mod.m_allowTraining = on;
			if (mappings && mappings.stage && mappings.stage.traininggrid)
			{
				mappings.stage.traininggrid.training_only = !on;
				writeTrainingFlag("traininggrid", !on);
			};
			writeShowTraining(on);
			applyGrid(true);
			mod.m_addUi.rebuildAddPopup();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify(on ? "Training stages can appear on Stage Select." : "Training stages stay training-only.");
				};
			}
			catch (err:*)
			{
			};
		}

		internal function revealTrainingStage(id:String):void
		{
			var mappings:Object;
			if (!id || !mod.m_allowTraining)
			{
				return;
			};
			mappings = EditorEngine.mappings();
			if (!mappings || !mappings.stage || !mappings.stage[id])
			{
				return;
			};
			if (mappings.stage[id].training_only)
			{
				mappings.stage[id].training_only = false;
				writeTrainingFlag(id, false);
				writeShowTraining(true);
			};
		}

		private function writeShowTraining(on:Boolean):void
		{
			var bag:Object;
			try
			{
				bag = loadTrainingBag();
				bag["__show"] = on;
				EditorSave.setJson(mod.m_host, SAVE_TRAINING, bag);
			}
			catch (stepErr:*)
			{
				mod.log("fail step=writeShowTraining err=" + stepErr);
			};
		}

		internal function onRestore():void
		{
			if (!hasDefaultRows())
			{
				captureDefaults();
			};
			if (!hasDefaultRows())
			{
				return;
			};
			mod.m_grid = mod.m_book.cloneGrid(mod.m_defaultGrid);
			restoreWorkingScreen();
			restoreTrainingFromDisk();
			applyGrid(false);
			clearSaved();
			if (mod.m_editing)
			{
				mod.m_addUi.rebuildBench();
			};
			try
			{
				if (mod.m_host)
				{
					mod.m_host.notify("Stage Select restored to original mappings.");
				};
			}
			catch (err:*)
			{
			};
		}

		internal function captureDefaults():void
		{
			var original:Object;
			var disk:Object;
			var screen:Object;
			if (m_defaultScreen)
			{
				return;
			};
			original = EditorEngine.mappings("metadata_original");
			disk = EditorEngine.appJson("data/misc/mappings.json");
			screen = null;
			if (original && original.stage_select_screen)
			{
				screen = cloneObject(original.stage_select_screen);
			}
			else if (disk && disk.stage_select_screen)
			{
				screen = cloneObject(disk.stage_select_screen);
			};
			if (!screen)
			{
				return;
			};
			m_defaultScreen = screen;
			mod.m_defaultGrid = mod.m_book.emptyGrid();
			mod.m_defaultGrid[0] = GridRows.cloneRows(screen.normal ? screen.normal.rows as Array : null);
			mod.m_defaultGrid[1] = GridRows.cloneRows(screen.past ? screen.past.rows as Array : null);
			mod.m_defaultGrid[2] = [[]];
			mod.m_defaultGrid[3] = [[]];
		}

		private function hasDefaultRows():Boolean
		{
			return (GridRows.flatten(mod.m_defaultGrid ? mod.m_defaultGrid[0] as Array : null).length > 0);
		}

		private function liveOrDefault(block:Object, page:int):Array
		{
			var rows:Array;
			rows = block ? block.rows as Array : null;
			if (GridRows.flatten(rows).length > 0)
			{
				return (rows);
			};
			if (hasDefaultRows() && mod.m_defaultGrid && mod.m_defaultGrid[page])
			{
				return (mod.m_defaultGrid[page] as Array);
			};
			return (rows);
		}

		private function restoreWorkingScreen():void
		{
			var mappings:Object;
			var snap:Object;
			mappings = EditorEngine.mappings();
			snap = m_defaultScreen;
			if (!mappings || !snap)
			{
				return;
			};
			if (!mappings.stage_select_screen)
			{
				mappings.stage_select_screen = {};
			};
			if (snap.normal)
			{
				mappings.stage_select_screen.normal = cloneObject(snap.normal);
			};
			if (snap.past)
			{
				mappings.stage_select_screen.past = cloneObject(snap.past);
			};
			if (snap.hand_start)
			{
				mappings.stage_select_screen.hand_start = cloneObject(snap.hand_start);
			};
			if (snap.hand_bounds)
			{
				mappings.stage_select_screen.hand_bounds = cloneObject(snap.hand_bounds);
			};
		}

		internal function applySaved():void
		{
			var mappings:Object;
			var saved:Array;
			try
			{
				if (!mod.m_host)
				{
					return;
				};
				mappings = EditorEngine.mappings();
				if (!mappings || !mappings.stage_select_screen)
				{
					return;
				};
				applyTrainingOverrides(mappings);
				saved = loadSavedGrid();
				if (saved)
				{
					mod.m_grid = saved;
				}
				else
				{
					mod.m_grid = migrateOldPages(mappings);
					appendExtraPages();
				};
				applySavedPageCount();
				if (!saved && !hasSavedPageCount())
				{
					trimTrailingEmptyPages();
				};
				if (mod.m_livePage >= mod.m_book.pageCount())
				{
					mod.m_livePage = 0;
				};
				if (placeMissingExpansionStages())
				{
					applyGrid(true);
				}
				else
				{
					applyGrid(false);
				};
				mod.m_catalog.ensureStageTitles();
				mod.log("applySaved grid=" + (saved ? "SAVE_GRID" : "migrate") + " pages=" + mod.m_book.pageCount() + " counts=" + mod.pageCountsLog());
			}
			catch (stepErr:*)
			{
				mod.log("fail step=applySaved err=" + stepErr);
			};
		}

		private function placeMissingExpansionStages():Boolean
		{
			var extras:Array;
			var seen:Object;
			var used:Object;
			var changed:Boolean;
			var placed:Array;
			var ids:Array;
			var i:int;
			var id:String;
			extras = mod.m_catalog.stageExpansionList();
			if (!extras || extras.length <= 0)
			{
				return (false);
			};
			seen = EditorSave.loadIdSet(mod.m_host, SAVE_SEEN_EXPANSIONS);
			used = {};
			ids = mod.m_book.flattenAllPages();
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (id)
				{
					used[id] = true;
					seen[id] = true;
				};
				i++;
			};
			changed = false;
			placed = [];
			i = 0;
			while (i < extras.length)
			{
				id = extras[i] ? String(extras[i].id) : "";
				i++;
				if (!id || used[id] || seen[id])
				{
					continue;
				};
				if (!tryPlaceOnFirstOpenPage(id))
				{
					continue;
				};
				used[id] = true;
				seen[id] = true;
				changed = true;
				placed.push(id);
				mod.log("auto-placed expansion " + id);
			};
			EditorSave.writeIdSet(mod.m_host, SAVE_SEEN_EXPANSIONS, seen);
			if (changed && placed.length > 0)
			{
				try
				{
					if (mod.m_host)
					{
						mod.m_host.notify(placed.length == 1
							? ("Added " + mod.m_catalog.stageDisplayName(String(placed[0])) + " to Stage Select.")
							: ("Added " + placed.length + " new stages to Stage Select."));
					};
				}
				catch (err:*)
				{
				};
			};
			return (changed);
		}

		private function tryPlaceOnFirstOpenPage(id:String):Boolean
		{
			if (!mod.m_grid)
			{
				mod.m_grid = mod.m_book.emptyGrid();
			};
			return (GridRows.placeOnFirstOpenPage(mod.m_grid, id, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS, StageEditorMod.MAX_PAGES) >= 0);
		}

		private function appendExtraPages():void
		{
			var list:Array;
			var i:int;
			var rows:Array;
			list = GridRows.asList(EditorSave.getJson(mod.m_host, SAVE_EXTRA));
			if (!list)
			{
				return;
			};
			i = 0;
			while (i < list.length && mod.m_grid.length < StageEditorMod.MAX_PAGES)
			{
				rows = GridRows.toRows(list[i]);
				mod.m_grid.push(rows && rows.length > 0 ? rows : [[]]);
				i++;
			};
		}

		private function applySavedPageCount():void
		{
			var raw:*;
			raw = readSavedPageCount();
			if (raw == null || !mod.m_grid)
			{
				return;
			};
			GridRows.resizePages(mod.m_grid, int(raw), StageEditorMod.MAX_PAGES);
		}

		private function hasSavedPageCount():Boolean
		{
			return (readSavedPageCount() != null);
		}

		private function readSavedPageCount():*
		{
			var raw:*;
			raw = EditorSave.get(mod.m_host, SAVE_PAGE_COUNT);
			return (raw == null || String(raw) == "" ? null : raw);
		}

		private function loadSavedGrid():Array
		{
			return (GridRows.toPages(EditorSave.getJson(mod.m_host, SAVE_GRID), StageEditorMod.MAX_PAGES));
		}

		private function migrateOldPages(mappings:Object):Array
		{
			var grid:Array;
			var p0:Array;
			var p1:Array;
			var p3:Array;
			var p4:Array;
			grid = [];
			p0 = EditorSave.loadRows(mod.m_host, SAVE_NORMAL, SAVE_NORMAL_OLD);
			if (p0 && GridRows.flatten(p0).length > 0)
			{
				grid.push(p0);
			}
			else
			{
				grid.push(GridRows.cloneRows(liveOrDefault(mappings.stage_select_screen.normal, 0)));
			};
			p1 = EditorSave.loadRows(mod.m_host, SAVE_PAST, SAVE_PAST_OLD);
			grid.push((p1 && GridRows.flatten(p1).length > 0) ? p1 : [[]]);
			p3 = EditorSave.loadRows(mod.m_host, SAVE_P3, null);
			grid.push((p3 && GridRows.flatten(p3).length > 0) ? p3 : [[]]);
			p4 = EditorSave.loadRows(mod.m_host, SAVE_P4, null);
			grid.push((p4 && GridRows.flatten(p4).length > 0) ? p4 : [[]]);
			return (grid);
		}

		private function trimTrailingEmptyPages():void
		{
			while (mod.m_grid && mod.m_grid.length > 1 && GridRows.flatten(mod.m_book.pageRows(mod.m_grid.length - 1)).length <= 0)
			{
				mod.m_grid.pop();
			};
		}

		/** One save per changed key: grid, page count when it differs, then legacy keys that still hold a value. */
		private function writeGrid():void
		{
			var cleared:int;
			var count:String;
			try
			{
				EditorSave.setJson(mod.m_host, SAVE_GRID, gridToSave());
				count = String(mod.m_book.pageCount());
				if (String(EditorSave.get(mod.m_host, SAVE_PAGE_COUNT)) != count)
				{
					try
					{
						mod.m_host.saveExtSet(SAVE_PAGE_COUNT, count);
					}
					catch (err:*)
					{
					};
				};
				cleared = EditorSave.clearKeys(mod.m_host, [SAVE_NORMAL, SAVE_PAST, SAVE_NORMAL_OLD, SAVE_PAST_OLD, SAVE_P3, SAVE_P4, SAVE_EXTRA]);
				mod.log("writeGrid pages=" + mod.m_book.pageCount() + " legacyCleared=" + cleared);
			}
			catch (stepErr:*)
			{
				mod.log("fail step=writeGrid err=" + stepErr);
			};
		}

		private function gridToSave():Array
		{
			var out:Array;
			var i:int;
			out = [];
			i = 0;
			while (i < mod.m_book.pageCount())
			{
				out.push(GridRows.cloneRows(mod.m_book.pageRows(i)));
				i++;
			};
			return (out);
		}

		private function clearSaved():void
		{
			try
			{
				EditorSave.clearKeys(mod.m_host, [SAVE_NORMAL, SAVE_PAST, SAVE_NORMAL_OLD, SAVE_PAST_OLD, SAVE_P3, SAVE_P4, SAVE_EXTRA, SAVE_PAGE_COUNT, SAVE_GRID, SAVE_TRAINING, SAVE_SEEN_EXPANSIONS]);
			}
			catch (err:*)
			{
			};
		}

		internal function applyGrid(persist:Boolean):void
		{
			var mappings:Object;
			var i:int;
			try
			{
				if (!mod.m_grid)
				{
					return;
				};
				mappings = EditorEngine.mappings();
				if (!mappings || !mappings.stage_select_screen)
				{
					return;
				};
				i = 0;
				while (i < mod.m_book.pageCount())
				{
					mod.m_book.setPageRows(i, sanitize(mod.m_book.pageRows(i), mappings));
					i++;
				};
				mappings.stage_select_screen.normal.rows = engineSafeRows(mod.m_book.pageRows(0), mappings);
				if (m_defaultScreen && m_defaultScreen.past)
				{
					mappings.stage_select_screen.past = cloneObject(m_defaultScreen.past);
				};
				syncRandom(mappings);
				mod.m_catalog.ensureStageTitles();
				if (persist && mod.m_host)
				{
					writeGrid();
				};
			}
			catch (stepErr:*)
			{
				mod.log("fail step=applyGrid err=" + stepErr);
			};
		}

		private function sanitize(rows:Array, mappings:Object):Array
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
						if (id && !seen[id] && keepSavedStageId(id, mappings))
						{
							next.push(id);
							seen[id] = true;
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
			return (GridRows.cap(out, StageEditorMod.MAX_COLS, StageEditorMod.MAX_ROWS));
		}

		private function engineSafeRows(rows:Array, mappings:Object):Array
		{
			var out:Array;
			var r:int;
			var c:int;
			var line:Array;
			var next:Array;
			var id:String;
			out = [];
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				next = [];
				c = 0;
				while (line && c < line.length)
				{
					id = String(line[c]);
					if (id && canEngineBuildClip(id, mappings))
					{
						next.push(id);
					};
					c++;
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

		private function canEngineBuildClip(id:String, mappings:Object):Boolean
		{
			if (!id || id == "xpstage")
			{
				return (false);
			};
			if (id != "random" && !(mappings && mappings.stage && mappings.stage[id]) && !mod.m_catalog.isRegistryStage(id))
			{
				return (false);
			};
			return (EditorEngine.libraryMC(id + "_stage_select") != null);
		}

		private function clipOnlyRows(rows:Array, mappings:Object):Array
		{
			var out:Array;
			var r:int;
			var c:int;
			var line:Array;
			var next:Array;
			var id:String;
			out = [];
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				next = [];
				c = 0;
				while (line && c < line.length)
				{
					id = String(line[c]);
					if (id && isAllowedStageId(id, mappings))
					{
						next.push(id);
					};
					c++;
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

		private function hasStageSelectClip(id:String):Boolean
		{
			if (id == "random")
			{
				return (true);
			};
			if (id == "xpstage")
			{
				return (false);
			};
			return (hasClip(id, "_stage_select"));
		}

		private function keepSavedStageId(id:String, mappings:Object):Boolean
		{
			if (id == "random")
			{
				return (true);
			};
			if (id == "xpstage")
			{
				return (false);
			};
			if (mappings && mappings.stage && mappings.stage[id])
			{
				return (true);
			};
			return (mod.m_catalog.isRegistryStage(id));
		}

		private function isAllowedStageId(id:String, mappings:Object):Boolean
		{
			if (!keepSavedStageId(id, mappings))
			{
				return (false);
			};
			if (id == "random")
			{
				return (true);
			};
			if (hasStageSelectClip(id) || mod.m_catalog.hasStageFile(id))
			{
				return (true);
			};
			return (false);
		}

		internal function isExtraAddStage(id:String):Boolean
		{
			if (!id || id == "random" || id == "xpstage")
			{
				return (false);
			};
			if (mod.m_catalog.isRegistryStage(id))
			{
				return (false);
			};
			if (hasStageSelectClip(id))
			{
				return (false);
			};
			return (mod.m_catalog.hasStageFile(id));
		}

		internal function collectIds(mappings:Object, otherRows:Array):Array
		{
			var ids:Array;
			var id:String;
			var extras:Array;
			var i:int;
			ids = [];
			if (mappings.stage)
			{
				for (id in mappings.stage)
				{
					if (id == "xpstage")
					{
						continue;
					};
					if (otherRows && GridRows.inRows(otherRows, id) && id != "random")
					{
						continue;
					};
					if (ids.indexOf(id) < 0 && isAllowedStageId(id, mappings))
					{
						ids.push(id);
					};
				};
			};
			extras = mod.m_catalog.stageExpansionList();
			i = 0;
			while (extras && i < extras.length)
			{
				id = extras[i] ? String(extras[i].id) : "";
				if (id && ids.indexOf(id) < 0 && isAllowedStageId(id, mappings))
				{
					ids.push(id);
				};
				i++;
			};
			i = 0;
			while (i < mod.m_book.pageCount())
			{
				GridRows.appendMissing(ids, GridRows.flatten(mod.m_book.pageRows(i)), otherRows || []);
				i++;
			};
			if (ids.indexOf("random") < 0)
			{
				ids.push("random");
			};
			return (ids);
		}

		private function syncRandom(mappings:Object):void
		{
			var list:Array;
			var ids:Array;
			var i:int;
			var id:String;
			var entry:Object;
			ids = mod.m_book.flattenAllPages();
			list = [];
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (GridRows.isPinned(id) || list.indexOf(id) >= 0)
				{
					i++;
					continue;
				};
				entry = mappings.stage ? mappings.stage[id] : null;
				if (entry)
				{
					list.push(id);
				};
				i++;
			};
			if (!mappings.random_stages)
			{
				mappings.random_stages = {};
			};
			mappings.random_stages.stages = list;
		}

		private function writeTrainingFlag(id:String, value:Boolean):void
		{
			var bag:Object;
			try
			{
				bag = loadTrainingBag();
				if (value)
				{
					bag[id] = true;
				}
				else
				{
					bag[id] = false;
				};
				EditorSave.setJson(mod.m_host, SAVE_TRAINING, bag);
			}
			catch (stepErr:*)
			{
				mod.log("fail step=writeTrainingFlag err=" + stepErr);
			};
		}

		private function applyTrainingOverrides(mappings:Object):void
		{
			var bag:Object;
			var id:String;
			bag = loadTrainingBag();
			if (!mappings || !mappings.stage)
			{
				return;
			};
			mod.m_allowTraining = Boolean(bag && bag["__show"]);
			if (bag)
			{
				for (id in bag)
				{
					if (id == "__show")
					{
						continue;
					};
					if (mappings.stage[id])
					{
						mappings.stage[id].training_only = Boolean(bag[id]);
					};
				};
			};
			if (mod.m_allowTraining && mappings.stage.traininggrid)
			{
				mappings.stage.traininggrid.training_only = false;
			}
			else if (mappings.stage.traininggrid && (!bag || bag["traininggrid"] == null))
			{
				mappings.stage.traininggrid.training_only = true;
			};
		}

		private function restoreTrainingFromDisk():void
		{
			var disk:Object;
			var mappings:Object;
			var id:String;
			var diskEntry:Object;
			disk = EditorEngine.appJson("data/misc/mappings.json");
			mappings = EditorEngine.mappings();
			if (!mappings || !mappings.stage)
			{
				return;
			};
			if (disk && disk.stage)
			{
				for (id in mappings.stage)
				{
					diskEntry = disk.stage[id];
					if (diskEntry)
					{
						mappings.stage[id].training_only = Boolean(diskEntry.training_only);
					}
					else
					{
						mappings.stage[id].training_only = false;
					};
				};
			};
			if (mappings.stage.traininggrid)
			{
				mappings.stage.traininggrid.training_only = true;
			};
			EditorSave.clearKeys(mod.m_host, [SAVE_TRAINING]);
		}

		private function loadTrainingBag():Object
		{
			var bag:Object;
			bag = EditorSave.getJson(mod.m_host, SAVE_TRAINING) as Object;
			return (bag ? bag : {});
		}

		private function hasClip(id:String, suffix:String):Boolean
		{
			return (EditorEngine.libraryMC(id + suffix) != null);
		}

		private function cloneObject(obj:Object):Object
		{
			if (!obj)
			{
				return (null);
			};
			try
			{
				return (JSON.parse(JSON.stringify(obj)));
			}
			catch (err:*)
			{
			};
			return (obj);
		}
	}
}
