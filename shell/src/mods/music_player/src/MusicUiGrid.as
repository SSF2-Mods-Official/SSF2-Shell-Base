package
{
	import flash.display.BlendMode;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Album grid: cell build, tile art cache, painting, and grid navigation.
	 */
	public class MusicUiGrid
	{
		private var ui:MusicPlayerUi;
		private static const OTHER_STAGES_HUB:String = "__other_stages_hub__";
		private static const EXPANSION_STAGES_HUB:String = "__expansion_stages_hub__";
		/** Cached songsForContext().length keyed by kind:id. */
		private var m_songCountCache:Object;
		/** Visible grid paint items for selection-only updates. */
		private var m_gridPaintItems:Array;

		public function MusicUiGrid(owner:MusicPlayerUi)
		{
			ui = owner;
			m_songCountCache = {};
			m_gridPaintItems = [];
		}

		internal function rebuildGrid():void
		{
			invalidateGridCaches();
			ui.m_gridCells = [];
			if (ui.m_tab == MusicPlayerUi.TAB_STAGE)
			{
				if (ui.m_stageGridMode == "other_stages")
				{
					ui.m_gridCells = buildHiddenStageCells();
				}
				else if (ui.m_stageGridMode == "expansion_stages")
				{
					ui.m_gridCells = buildExpansionStageCells();
				}
				else
				{
					addStageTabCells();
				};
			}
			else if (ui.m_tab == MusicPlayerUi.TAB_SERIES)
			{
				addSeriesTabCells();
			}
			else
			{
				// Search has its own stub cell — never fall through to Playlists
				// (that was replacing search hits with Uploaded Songs).
				if (ui.m_tab == MusicPlayerUi.TAB_SEARCH)
				{
					ui.m_gridCells = [{"id": "__search__", "kind": "search", "label": "Search"}];
				}
				else if (ui.m_onlineMode)
				{
					ui.m_onlineView.buildOnlineGrid();
				}
				else
				{
					addPlaylistTabCells();
				};
			};
			if (ui.m_gridIndex >= ui.m_gridCells.length)
			{
				ui.m_gridIndex = Math.max(0, ui.m_gridCells.length - 1);
			};
			ui.m_scroll.ensureGridScroll();
		}

		/** By Stage: catalog stages (minus Training Grid) + Other / Expansion hubs. */
		private function addStageTabCells():void
		{
			var i:int;
			var sid:String;
			i = 0;
			while (i < ui.m_catalog.stageIds.length)
			{
				sid = String(ui.m_catalog.stageIds[i]);
				i++;
				if (sid == MusicStageVisuals.TRAINING_GRID_ID)
				{
					continue;
				};
				ui.m_gridCells.push({
					"id": sid,
					"kind": "stage",
					"label": MusicStageVisuals.stageDisplayName(sid),
					"seriesKey": MusicSeriesResolver.keyForStage(sid)
				});
			};
			ui.m_gridCells.push({
				"id": OTHER_STAGES_HUB,
				"kind": "other_stages_hub",
				"label": "Other Stages"
			});
			ui.m_gridCells.push({
				"id": EXPANSION_STAGES_HUB,
				"kind": "expansion_stages_hub",
				"label": "Expansion Stages"
			});
		}

		/** By Series: All, Other, built-in series, user-created series, + New Series. */
		private function addSeriesTabCells():void
		{
			var i:int;
			var keys:Array;
			var k:String;
			var custom:Object;
			ui.m_gridCells.push({"id": MusicSeriesResolver.KEY_ALL, "kind": "all", "label": "All"});
			ui.m_gridCells.push({"id": MusicSeriesResolver.KEY_OTHER, "kind": "other", "label": "Other"});
			keys = MusicSeriesResolver.seriesKeys();
			i = 0;
			while (i < keys.length)
			{
				k = String(keys[i]);
				i++;
				ui.m_gridCells.push({
					"id": k,
					"kind": "series",
					"label": MusicOverrides.seriesLabel(k) || MusicSeriesResolver.seriesLabel(k),
					"seriesKey": k
				});
			};
			// User-created series
			custom = MusicOverrides.customSeries();
			for (k in custom)
			{
				if (!k || seriesKeyListed(keys, k))
				{
					continue;
				};
				ui.m_gridCells.push({
					"id": k,
					"kind": "series",
					"label": String(custom[k].label || k),
					"seriesKey": k,
					"customSeries": true
				});
			};
			ui.m_gridCells.push({
				"id": MusicPlayerUi.NEW_SERIES_HUB,
				"kind": "new_series",
				"label": "+ New Series"
			});
		}

		/** Playlists: Uploaded Songs, Legacy, enabled packs, custom playlists, + New, Online. */
		private function addPlaylistTabCells():void
		{
			var i:int;
			var k:String;
			var ids:Array;
			var packs:Array;
			ui.m_gridCells.push({
				"id": MusicPlaylistStore.UPLOAD_PLAYLIST_ID,
				"kind": "uploads",
				"label": "Uploaded Songs",
				"seriesKey": MusicSeriesResolver.KEY_ALL,
				"builtin": true
			});
			if (ui.m_catalog && ui.m_catalog.legacyTrackIds().length > 0)
			{
				ui.m_gridCells.push({
					"id": MusicPlaylistStore.LEGACY_PLAYLIST_ID,
					"kind": "legacy",
					"label": "Legacy Format",
					"seriesKey": MusicSeriesResolver.KEY_ALL,
					"builtin": true
				});
			};
			packs = MusicPacks.enabledPackEntries();
			i = 0;
			while (packs && i < packs.length)
			{
				k = String(packs[i].id);
				ui.m_gridCells.push({
					"id": k,
					"kind": "pack",
					"label": String(packs[i].label || k),
					"seriesKey": MusicSeriesResolver.KEY_ALL,
					"builtin": true
				});
				i++;
			};
			ids = ui.m_store.customPlaylistIds();
			i = 0;
			while (i < ids.length)
			{
				k = String(ids[i]);
				i++;
				ui.m_gridCells.push({
					"id": k,
					"kind": "playlist",
					"label": ui.m_store.playlistLabel(k),
					"seriesKey": ui.m_store.playlistIcon(k) || MusicSeriesResolver.KEY_ALL,
					"builtin": k == MusicPlaylistStore.MENU_PLAYLIST_ID
				});
			};
			ui.m_gridCells.push({"id": "__new__", "kind": "new", "label": "+ New"});
			ui.m_gridCells.push({"id": "__online__", "kind": "online", "label": "Download from Online"});
		}

		private function buildHiddenStageCells():Array
		{
			var out:Array;
			var seen:Object;
			var onSelect:Object;
			var i:int;
			var sid:String;
			var extras:Array;
			out = [];
			seen = {};
			onSelect = {};
			i = 0;
			while (i < ui.m_catalog.stageIds.length)
			{
				sid = String(ui.m_catalog.stageIds[i]);
				i++;
				if (sid)
				{
					onSelect[sid] = true;
				};
			};
			// Strict allowlist — pack stage ids must NOT dump every stage with pack songs.
			extras = [
				MusicStageVisuals.TRAINING_GRID_ID,
				"sandbagsoccer",
				"sandbagbasketball",
				MusicStageVisuals.WAITING_ROOM_ID
			];
			i = 0;
			while (i < extras.length)
			{
				addHiddenStageCell(out, seen, onSelect, String(extras[i]));
				i++;
			};
			out.sort(function (a:Object, b:Object):int
			{
				var la:String = String(a.label || "").toLowerCase();
				var lb:String = String(b.label || "").toLowerCase();
				if (la < lb)
				{
					return (-1);
				};
				if (la > lb)
				{
					return (1);
				};
				return (0);
			});
			return (out);
		}

		/** Dropped expansion/stage folders, minus stages already on the main By Stage grid. */
		private function buildExpansionStageCells():Array
		{
			var out:Array;
			var seen:Object;
			var onSelect:Object;
			var extras:Array;
			var RM:*;
			var i:int;
			var sid:String;
			out = [];
			seen = {};
			onSelect = {};
			i = 0;
			while (ui.m_catalog && i < ui.m_catalog.stageIds.length)
			{
				sid = String(ui.m_catalog.stageIds[i]);
				i++;
				if (sid)
				{
					onSelect[sid] = true;
					seen[sid] = true;
				};
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				if (RM && RM.getStageExpansions is Function)
				{
					extras = RM.getStageExpansions() as Array;
				};
			}
			catch (rmErr:*)
			{
				extras = null;
			};
			i = 0;
			while (extras && i < extras.length)
			{
				sid = extras[i] ? String(extras[i].id) : "";
				i++;
				addHiddenStageCell(out, seen, onSelect, sid);
			};
			out.sort(function (a:Object, b:Object):int
			{
				var la:String = String(a.label || "").toLowerCase();
				var lb:String = String(b.label || "").toLowerCase();
				if (la < lb)
				{
					return (-1);
				};
				if (la > lb)
				{
					return (1);
				};
				return (0);
			});
			return (out);
		}

		private function seriesKeyListed(keys:Array, id:String):Boolean
		{
			return Boolean(keys && keys.indexOf(id) >= 0);
		}

		internal function beginNewSeries():void
		{
			ui.m_dialogs.openTextPrompt("New series name", "My Series", function (value:String):void
			{
				var id:String;
				if (!value || value.length < 1)
				{
					return;
				};
				id = "custom:" + slugifySeriesId(value);
				MusicOverrides.putCustomSeries(id, value, MusicSeriesResolver.KEY_ALL, "battlefield");
				MusicSeriesResolver.invalidate();
				rebuildGrid();
				ui.paint();
			});
		}

		private function slugifySeriesId(value:String):String
		{
			var out:String;
			var i:int;
			var ch:String;
			var code:int;
			out = "";
			i = 0;
			while (i < value.length)
			{
				ch = value.charAt(i).toLowerCase();
				code = ch.charCodeAt(0);
				i++;
				if ((code >= 97 && code <= 122) || (code >= 48 && code <= 57))
				{
					out += ch;
				}
				else if (out.length > 0 && out.charAt(out.length - 1) != "_")
				{
					out += "_";
				};
			};
			if (out.length < 1)
			{
				out = "series";
			};
			return (out);
		}

		internal function beginRenameSeries(seriesKey:String):void
		{
			var cur:String;
			if (!seriesKey)
			{
				return;
			};
			cur = MusicOverrides.seriesLabel(seriesKey) || MusicSeriesResolver.seriesLabel(seriesKey) || seriesKey;
			ui.m_dialogs.openTextPrompt("Rename series", cur, function (value:String):void
			{
				if (value && value.length > 0)
				{
					MusicOverrides.setSeriesLabel(seriesKey, value);
					rebuildGrid();
					ui.paint();
				};
				ui.m_trackSettings.openSeriesSettingsMenu();
			}, ui.m_trackSettings.openSeriesSettingsMenu);
		}

		private function addHiddenStageCell(out:Array, seen:Object, onSelect:Object, id:String):void
		{
			if (!id || seen[id] || onSelect[id] || id == MusicStageVisuals.OTHER_STAGE_ID)
			{
				return;
			};
			if (id == "random" || id == "xpstage")
			{
				return;
			};
			seen[id] = true;
			if (ui.m_catalog)
			{
				ui.m_catalog.ensureStageData(id);
			};
			out.push({
				"id": id,
				"kind": "stage",
				"label": MusicStageVisuals.stageDisplayName(id),
				"seriesKey": MusicSeriesResolver.keyForStage(id)
			});
		}

		internal function paintGrid():void
		{
			var cols:int;
			var rowsVis:int;
			var start:int;
			var i:int;
			var cell:Object;
			var col:int;
			var row:int;
			var x0:int;
			var y0:int;
			var holder:Sprite;
			var hit:Sprite;
			var sel:Boolean;
			var label:TextField;
			var art:Sprite;
			var rowPitch:int;
			var cellIndex:int;
			while (ui.m_gridLayer.numChildren > 0)
			{
				ui.m_gridLayer.removeChildAt(0);
			};
			m_gridPaintItems = [];
			cols = MusicPlayerUi.COLS;
			rowPitch = MusicPlayerUi.CELL + MusicPlayerUi.LABEL_H + MusicPlayerUi.GAP;
			rowsVis = Math.max(2, int((ui.m_listBottom - 72) / rowPitch));
			start = ui.m_gridScroll;
			i = start;
			while (i < ui.m_gridCells.length && i < start + cols * rowsVis)
			{
				cell = ui.m_gridCells[i];
				col = (i - start) % cols;
				row = int((i - start) / cols);
				x0 = 36 + col * (MusicPlayerUi.CELL + MusicPlayerUi.GAP);
				y0 = 68 + row * rowPitch;
				sel = i == ui.m_gridIndex;
				holder = new Sprite();
				holder.x = x0 + MusicPlayerUi.CELL * 0.5;
				holder.y = y0 + MusicPlayerUi.CELL * 0.5;
				art = getOrBuildTileArt(cell);
				if (art.parent)
				{
					art.parent.removeChild(art);
				};
				holder.addChild(art);
				drawTileBorder(holder, sel);
				ui.m_gridLayer.addChild(holder);
				hit = new Sprite();
				hit.graphics.beginFill(0xFFFFFF, 0.001);
				hit.graphics.drawRect(x0, y0, MusicPlayerUi.CELL, MusicPlayerUi.CELL + MusicPlayerUi.LABEL_H);
				hit.graphics.endFill();
				hit.buttonMode = true;
				hit.useHandCursor = true;
				cellIndex = i;
				hit.addEventListener(MouseEvent.CLICK, (function (idx:int):Function
				{
					return function (e:MouseEvent):void
					{
						e.stopPropagation();
						ui.playUiSfx("menu_select");
						ui.m_gridIndex = idx;
						ui.m_scroll.ensureGridScroll();
						ui.m_songs.enterSongsFromGrid();
					};
				})(cellIndex));
				ui.m_gridLayer.addChild(hit);
				label = ui.makeText(String(cell.label || ""), x0, y0 + MusicPlayerUi.CELL + 2, 10,
					sel ? MusicTheme.select() : MusicTheme.uiSoft(), false);
				label.width = MusicPlayerUi.CELL;
				label.height = MusicPlayerUi.LABEL_H + 2;
				label.wordWrap = false;
				ui.m_songList.fitLabelToWidth(label, MusicPlayerUi.CELL, 10);
				ui.m_gridLayer.addChild(label);
				m_gridPaintItems.push({
					"index": i,
					"holder": holder,
					"label": label
				});
				i++;
			};
			ui.m_scroll.paintGridScrollbar(rowsVis, rowPitch);
		}

		private function paintGridSelectionOnly():void
		{
			var i:int;
			var item:Object;
			var sel:Boolean;
			var holder:Sprite;
			var label:TextField;
			if (!m_gridPaintItems || m_gridPaintItems.length < 1)
			{
				ui.paint();
				return;
			};
			i = 0;
			while (i < m_gridPaintItems.length)
			{
				item = m_gridPaintItems[i];
				i++;
				sel = int(item.index) == ui.m_gridIndex;
				holder = item.holder as Sprite;
				label = item.label as TextField;
				if (holder)
				{
					drawTileBorder(holder, sel);
				};
				if (label)
				{
					label.textColor = sel ? MusicTheme.select() : MusicTheme.uiSoft();
				};
			};
		}

		private function drawTileBorder(holder:Sprite, sel:Boolean):void
		{
			if (!holder)
			{
				return;
			};
			holder.graphics.clear();
			holder.graphics.lineStyle(sel ? 2 : 1, sel ? MusicTheme.select() : 0x555566, 0.95);
			holder.graphics.drawRoundRect(-MusicPlayerUi.CELL * 0.5, -MusicPlayerUi.CELL * 0.5, MusicPlayerUi.CELL, MusicPlayerUi.CELL, 8, 8);
		}

		private function cellCacheKey(cell:Object):String
		{
			if (!cell)
			{
				return ("");
			};
			return (String(cell.kind || "") + ":" + String(cell.id || ""));
		}

		internal function invalidateGridCaches():void
		{
			ui.m_tileArtCache = {};
			m_songCountCache = {};
			m_gridPaintItems = [];
		}

		private function getOrBuildTileArt(cell:Object):Sprite
		{
			var key:String;
			var art:Sprite;
			var iconKey:String;
			var stageFill:String;
			key = cellCacheKey(cell);
			art = ui.m_tileArtCache[key] as Sprite;
			if (art)
			{
				return (art);
			};
			art = new Sprite();
			iconKey = cell.seriesKey ? String(cell.seriesKey)
				: (cell.kind == "stage" ? MusicSeriesResolver.keyForStage(String(cell.id)) : String(cell.id));
			if (cell.kind == "all")
			{
				iconKey = MusicSeriesResolver.KEY_ALL;
			};
			if (cell.kind == "other" || cell.kind == "new")
			{
				iconKey = MusicSeriesResolver.KEY_OTHER;
			};
			stageFill = null;
			if (cell.kind == "stage")
			{
				stageFill = String(cell.id);
			}
			else if (cell.kind == "series")
			{
				stageFill = ui.m_songs.previewStageForCell(cell);
			};
			MusicSeriesResolver.attachSeriesTile(art, iconKey, stageFill, MusicPlayerUi.CELL, MusicPlayerUi.CELL, true);
			addSongCountBadge(art, cell);
			ui.m_tileArtCache[key] = art;
			return (art);
		}

		private function addSongCountBadge(holder:Sprite, cell:Object):void
		{
			var n:int;
			var badge:Sprite;
			var fill:Sprite;
			var tf:TextField;
			var size:Number;
			n = cachedSongCount(cell);
			size = 16.5;
			badge = new Sprite();
			badge.blendMode = BlendMode.LAYER;
			fill = new Sprite();
			fill.graphics.beginFill(MusicTheme.ui(), 0.95);
			fill.graphics.drawRect(0, 0, size, size);
			fill.graphics.endFill();
			badge.addChild(fill);
			tf = new TextField();
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", 9, 0x111118, true);
			tf.text = String(n);
			tf.x = (size - tf.textWidth) * 0.5 - 1;
			tf.y = (size - tf.textHeight) * 0.5 - 1;
			tf.blendMode = BlendMode.ERASE;
			badge.addChild(tf);
			badge.x = MusicPlayerUi.CELL * 0.5 - size - 3;
			badge.y = -MusicPlayerUi.CELL * 0.5 + 3;
			badge.mouseEnabled = false;
			badge.mouseChildren = false;
			holder.addChild(badge);
		}

		private function cachedSongCount(cell:Object):int
		{
			var key:String;
			var n:int;
			var hidden:Array;
			key = cellCacheKey(cell);
			if (key && m_songCountCache[key] != null)
			{
				return int(m_songCountCache[key]);
			};
			if (cell && (cell.kind == "other_stages_hub" || cell.id == OTHER_STAGES_HUB))
			{
				hidden = buildHiddenStageCells();
				n = hidden ? hidden.length : 0;
			}
			else if (cell && (cell.kind == "expansion_stages_hub" || cell.id == EXPANSION_STAGES_HUB))
			{
				hidden = buildExpansionStageCells();
				n = hidden ? hidden.length : 0;
			}
			else
			{
				n = ui.m_songs.songsForContext(cell).length;
			};
			if (key)
			{
				m_songCountCache[key] = n;
			};
			return (n);
		}

		internal function moveGrid(delta:int):void
		{
			var n:int;
			var prevScroll:int;
			var col:int;
			var row:int;
			var totalRows:int;
			var cand:int;
			n = ui.m_gridCells.length;
			if (n < 1)
			{
				return;
			};
			prevScroll = ui.m_gridScroll;
			if (delta == MusicPlayerUi.COLS || delta == -MusicPlayerUi.COLS)
			{
				col = ui.m_gridIndex % MusicPlayerUi.COLS;
				row = int(ui.m_gridIndex / MusicPlayerUi.COLS);
				totalRows = int(Math.ceil(n / Number(MusicPlayerUi.COLS)));
				if (delta < 0)
				{
					if (row <= 0)
					{
						cand = (totalRows - 1) * MusicPlayerUi.COLS + col;
						if (cand >= n)
						{
							cand = n - 1;
						};
						ui.m_gridIndex = cand;
					}
					else
					{
						ui.m_gridIndex -= MusicPlayerUi.COLS;
					};
				}
				else
				{
					if (ui.m_gridIndex + MusicPlayerUi.COLS >= n)
					{
						ui.m_gridIndex = col;
					}
					else
					{
						ui.m_gridIndex += MusicPlayerUi.COLS;
					};
				};
			}
			else
			{
				ui.m_gridIndex = (ui.m_gridIndex + delta + n * 8) % n;
			};
			ui.playUiSfx("menu_hover");
			ui.m_scroll.ensureGridScroll();
			if (ui.m_gridScroll == prevScroll && m_gridPaintItems && m_gridPaintItems.length > 0)
			{
				paintGridSelectionOnly();
			}
			else
			{
				ui.paint();
			};
		}
	}
}
