package
{

	/**
	 * Song context: which tracks a grid cell holds, resource hydration, and the playback queue handoff.
	 */
	public class MusicUiSongs
	{
		private var ui:MusicPlayerUi;

		public function MusicUiSongs(owner:MusicPlayerUi)
		{
			ui = owner;
		}

		internal function enterSongsFromGrid():void
		{
			var cell:Object;
			if (ui.m_gridIndex < 0 || ui.m_gridIndex >= ui.m_gridCells.length)
			{
				return;
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			if (cell.kind == "other_stages_hub")
			{
				ui.m_stageGridMode = "other_stages";
				ui.m_gridIndex = 0;
				ui.m_gridScroll = 0;
				ui.m_grid.rebuildGrid();
				ui.m_transport.refreshPreviewBg(null);
				ui.paint();
				return;
			};
			if (cell.kind == "expansion_stages_hub")
			{
				ui.m_stageGridMode = "expansion_stages";
				ui.m_gridIndex = 0;
				ui.m_gridScroll = 0;
				ui.m_grid.rebuildGrid();
				ui.m_transport.refreshPreviewBg(null);
				ui.paint();
				return;
			};
			if (cell.kind == "new_series")
			{
				ui.m_grid.beginNewSeries();
				return;
			};
			if (ui.m_listMode == "add")
			{
				ui.m_edit.enterAddBrowseSongs(cell);
				return;
			};
			if (cell.kind == "new")
			{
				ui.m_edit.createPlaylistQuick();
				return;
			};
			if (cell.kind == "online_wait")
			{
				return;
			};
			if (cell.kind == "online")
			{
				ui.m_onlineView.beginOnlineBrowse();
				return;
			};
			if (cell.kind == "online_back")
			{
				ui.m_onlineMode = false;
				ui.m_gridIndex = 0;
				ui.m_grid.rebuildGrid();
				ui.paint();
				return;
			};
			if (cell.kind == "online_updates")
			{
				ui.m_onlineView.installOnlineUpdates();
				return;
			};
			if (cell.kind == "online_mod")
			{
				ui.m_onlineView.installOnlineMod(cell);
				return;
			};
			ui.m_contextId = String(cell.id);
			ui.m_view = MusicPlayerUi.VIEW_SONGS;
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			ui.m_editMode = false;
			ui.m_listMode = null;
			ui.m_songIds = songsForContext(cell);
			ui.m_queue = ui.m_songIds.concat();
			ui.m_previewStageId = previewStageForCell(cell);
			selectNowPlayingInList();
			loadContextResources(cell);
			if (ui.m_songIds.length > 0 && ui.m_songIndex >= 0 && ui.m_songIndex < ui.m_songIds.length)
			{
				ui.m_songList.updateSongListBackground(String(ui.m_songIds[ui.m_songIndex]));
			}
			else
			{
				ui.m_transport.refreshPreviewBg(ui.m_previewStageId || MusicStageVisuals.WAITING_ROOM_ID);
			};
			syncPlaybackQueue();
			ui.paint();
		}

		internal function syncPlaybackQueue():void
		{
			var idx:int;
			if (!ui.m_queue || ui.m_queue.length < 1)
			{
				return;
			};
			idx = ui.m_songIndex;
			if (idx < 0 || idx >= ui.m_queue.length)
			{
				idx = 0;
			};
			if (ui.m_playback && ui.m_playback.setQueue is Function)
			{
				ui.m_playback.setQueue(ui.m_queue, idx);
			};
		}

		/** If the live track is in this list, select it. */
		internal function selectNowPlayingInList():void
		{
			var tid:String;
			var i:int;
			tid = ui.currentTrackId();
			if (!tid || !ui.m_songIds)
			{
				return;
			};
			i = 0;
			tid = MusicPacks.canonicalTrackId(tid);
			while (i < ui.m_songIds.length)
			{
				if (MusicPacks.canonicalTrackId(String(ui.m_songIds[i])) == tid)
				{
					ui.m_songIndex = i;
					ui.m_scroll.ensureSongScroll();
					return;
				};
				i++;
			};
		}

		internal function exitSongs():void
		{
			ui.m_view = MusicPlayerUi.VIEW_GRID;
			ui.m_editMode = false;
			ui.m_listMode = null;
			ui.m_addPool = [];
			ui.m_contextId = null;
			ui.m_grid.rebuildGrid();
			ui.m_transport.refreshPreviewBg(null);
			ui.paint();
		}

		internal function songsForContext(cell:Object):Array
		{
			if (!cell)
			{
				return ([]);
			};
			if (cell.kind == "all" || cell.id == MusicSeriesResolver.KEY_ALL)
			{
				return (songsForAllCell());
			};
			if (cell.kind == "other" || cell.id == MusicSeriesResolver.KEY_OTHER)
			{
				return (songsForOtherSeries());
			};
			if (cell.kind == "stage")
			{
				return (songsForStageCell(String(cell.id)));
			};
			if (cell.kind == "series")
			{
				return (songsForSeriesCell(String(cell.id)));
			};
			if (cell.kind == "uploads" || cell.id == MusicPlaylistStore.UPLOAD_PLAYLIST_ID)
			{
				return (ui.m_catalog ? ui.m_catalog.uploadTrackIds() : []);
			};
			if (cell.kind == "legacy" || cell.id == MusicPlaylistStore.LEGACY_PLAYLIST_ID)
			{
				return (ui.m_catalog ? ui.m_catalog.legacyTrackIds() : []);
			};
			if (cell.kind == "pack")
			{
				return (MusicPacks.songsForPack(String(cell.id)));
			};
			if (cell.kind == "playlist")
			{
				return (ui.m_store.songsForPlaylist(String(cell.id)));
			};
			if (cell.kind == "search" || cell.id == "__search__")
			{
				return (ui.m_songIds ? ui.m_songIds.concat() : []);
			};
			return ([]);
		}

		/** Push each id of `list` once into `out`; skipEmpty also drops "" ids. */
		private function appendUnique(out:Array, seen:Object, list:Array, skipEmpty:Boolean):void
		{
			var j:int;
			var tid:String;
			j = 0;
			while (j < list.length)
			{
				tid = String(list[j]);
				j++;
				if ((!skipEmpty || tid) && !seen[tid])
				{
					seen[tid] = true;
					out.push(tid);
				};
			};
		}

		/** All: every catalog stage list + Other, deduped, sorted by title. */
		private function songsForAllCell():Array
		{
			var out:Array;
			var seen:Object;
			var i:int;
			out = [];
			seen = {};
			i = 0;
			while (i < ui.m_catalog.stageIds.length)
			{
				appendUnique(out, seen, ui.m_store.songsForStage(String(ui.m_catalog.stageIds[i])), false);
				i++;
			};
			appendUnique(out, seen, ui.m_store.songsForStage(MusicStageVisuals.OTHER_STAGE_ID), false);
			out.sort(sortSongsByTitle);
			return (out);
		}

		/** Stage album: its playlist, then loose tracks of the stage's series. */
		private function songsForStageCell(stageId:String):Array
		{
			var out:Array;
			var seen:Object;
			var loose:Array;
			out = [];
			seen = {};
			appendUnique(out, seen, ui.m_store.songsForStage(stageId), true);
			loose = ui.m_catalog ? ui.m_catalog.looseTracksForSeries(MusicSeriesResolver.keyForStage(stageId)) : [];
			appendUnique(out, seen, loose, true);
			return (out);
		}

		/** Series album: every stage in the series (ingested once), then loose series tracks. */
		private function songsForSeriesCell(seriesKey:String):Array
		{
			var out:Array;
			var seen:Object;
			var stages:Array;
			var i:int;
			var sid:String;
			var loose:Array;
			out = [];
			seen = {};
			stages = MusicSeriesResolver.stagesForSeries(seriesKey);
			i = 0;
			while (i < stages.length)
			{
				sid = String(stages[i]);
				i++;
				if (ui.m_catalog)
				{
					ui.m_catalog.ensureStageData(sid);
					ui.m_catalog.ingestStageSongsOnce(sid);
				};
				appendUnique(out, seen, ui.m_store.songsForStage(sid), false);
			};
			loose = ui.m_catalog ? ui.m_catalog.looseTracksForSeries(seriesKey) : [];
			appendUnique(out, seen, loose, true);
			return (out);
		}

		internal function sortSongsByTitle(a:String, b:String):int
		{
			var ta:String;
			var tb:String;
			ta = (ui.m_catalog ? ui.m_catalog.songTitleOrPlaceholder(a) : a).toLowerCase();
			tb = (ui.m_catalog ? ui.m_catalog.songTitleOrPlaceholder(b) : b).toLowerCase();
			if (ta < tb)
			{
				return (-1);
			};
			if (ta > tb)
			{
				return (1);
			};
			return (0);
		}

		internal function previewStageForCell(cell:Object):String
		{
			var stages:Array;
			var meta:Object;
			if (!cell)
			{
				return (null);
			};
			if (cell.kind == "stage")
			{
				return String(cell.id);
			};
			if (cell.kind == "series")
			{
				meta = MusicOverrides.getCustomSeries(String(cell.id));
				if (meta && meta.stageArt)
				{
					return String(meta.stageArt);
				};
				stages = MusicSeriesResolver.stagesForSeries(String(cell.id));
				return stages.length > 0 ? String(stages[0]) : null;
			};
			if (cell.kind == "other")
			{
				return (MusicStageVisuals.OTHER_STAGE_ID);
			};
			return (null);
		}

		private function loadContextResources(cell:Object):void
		{
			var sid:String;
			var stages:Array;
			var i:int;
			if (!cell || !ui.m_catalog)
			{
				return;
			};
			if (cell.kind == "stage")
			{
				sid = String(cell.id);
				// songcache.json only — never queue stage SWFs for music lists.
				ui.m_catalog.ingestStageSongsOnce(sid);
			}
			else if (cell.kind == "series")
			{
				stages = MusicSeriesResolver.stagesForSeries(String(cell.id));
				i = 0;
				while (stages && i < stages.length)
				{
					ui.m_catalog.ingestStageSongsOnce(String(stages[i]));
					i++;
				};
			};
			ui.m_songIds = songsForContext(cell);
			ui.m_queue = ui.m_songIds.concat();
			selectNowPlayingInList();
			syncPlaybackQueue();
			hydrateSongs(ui.m_songIds);
			if (ui.m_open && ui.m_view == MusicPlayerUi.VIEW_SONGS)
			{
				ui.paint();
			};
		}

		internal function hydrateSongs(songs:Array):void
		{
			var need:Array;
			var i:int;
			var tid:String;
			var focus:Array;
			// Never bulk-load playlist SWFs — list.json has meta; playTrack loads one song.
			if (!songs || !ui.m_host || !(ui.m_host.ensureResourcesLoaded is Function))
			{
				return;
			};
			need = [];
			focus = [];
			tid = ui.currentTrackId();
			if (tid)
			{
				focus.push(tid);
			};
			if (ui.m_songIndex >= 0 && ui.m_songIndex < songs.length)
			{
				focus.push(String(songs[ui.m_songIndex]));
			};
			i = 0;
			while (i < focus.length && need.length < 2)
			{
				tid = MusicPacks.canonicalTrackId(String(focus[i]));
				i++;
				if (tid && ui.m_catalog && ui.m_catalog.trackNeedsLoad(tid) && need.indexOf(tid) < 0)
				{
					need.push(tid);
				};
			};
			if (need.length < 1)
			{
				return;
			};
			ui.m_host.ensureResourcesLoaded(need, function ():void
			{
				var j:int;
				j = 0;
				while (j < need.length)
				{
					if (ui.m_catalog)
					{
						ui.m_catalog.refreshTrackMeta(String(need[j]));
						ui.m_catalog.cacheTrackDuration(String(need[j]));
					};
					j++;
				};
				if (ui.m_open)
				{
					ui.paint();
					ui.m_transport.refreshNowPlayingMeta();
				};
			}, null);
		}

		internal function isCustomPlaylistContext():Boolean
		{
			var cell:Object;
			if (ui.m_tab != MusicPlayerUi.TAB_PLAYLIST || ui.m_gridIndex < 0 || ui.m_gridIndex >= ui.m_gridCells.length)
			{
				return (false);
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			return Boolean(cell && cell.kind == "playlist" && !ui.m_store.isBuiltinPlaylist(String(cell.id)));
		}

		internal function reloadContextSongs():void
		{
			var cell:Object;
			if (ui.m_gridIndex >= 0 && ui.m_gridIndex < ui.m_gridCells.length)
			{
				cell = ui.m_gridCells[ui.m_gridIndex];
				ui.m_songIds = songsForContext(cell);
			}
			else
			{
				ui.m_songIds = [];
			};
			ui.m_queue = ui.m_songIds.concat();
			syncPlaybackQueue();
		}

		internal function isUploadsContext():Boolean
		{
			var cell:Object;
			if (ui.m_gridIndex < 0 || ui.m_gridIndex >= ui.m_gridCells.length)
			{
				return (false);
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			return Boolean(cell && (cell.kind == "uploads" || cell.id == MusicPlaylistStore.UPLOAD_PLAYLIST_ID));
		}

		/**
		 * By Series → Other: only tracks that are not already on a stage with a
		 * known franchise series (avoids duplicating legit stage songs).
		 */
		private function songsForOtherSeries():Array
		{
			var out:Array;
			var seen:Object;
			var claimed:Object;
			var i:int;
			var j:int;
			var sid:String;
			var tid:String;
			var list:Array;
			var key:String;
			var stages:Array;
			out = [];
			seen = {};
			claimed = {};
			i = 0;
			while (ui.m_catalog && i < ui.m_catalog.stageIds.length)
			{
				sid = String(ui.m_catalog.stageIds[i]);
				i++;
				key = MusicSeriesResolver.keyForStage(sid);
				if (!key || key == MusicSeriesResolver.KEY_OTHER
					|| key == MusicSeriesResolver.KEY_UNKNOWN)
				{
					continue;
				};
				list = ui.m_store.songsForStage(sid);
				j = 0;
				while (list && j < list.length)
				{
					tid = MusicPacks.canonicalTrackId(String(list[j]));
					j++;
					if (tid)
					{
						claimed[tid] = true;
					};
				};
				list = ui.m_catalog.defaultStageSongs[sid] as Array;
				j = 0;
				while (list && j < list.length)
				{
					tid = MusicPacks.canonicalTrackId(String(list[j]));
					j++;
					if (tid)
					{
						claimed[tid] = true;
					};
				};
			};
			list = ui.m_store.songsForStage(MusicStageVisuals.OTHER_STAGE_ID);
			j = 0;
			while (list && j < list.length)
			{
				tid = MusicPacks.canonicalTrackId(String(list[j]));
				j++;
				if (tid && !claimed[tid] && !seen[tid])
				{
					seen[tid] = true;
					out.push(tid);
				};
			};
			stages = MusicSeriesResolver.stagesForSeries(MusicSeriesResolver.KEY_UNKNOWN);
			i = 0;
			while (stages && i < stages.length)
			{
				sid = String(stages[i]);
				i++;
				list = ui.m_store.songsForStage(sid);
				j = 0;
				while (list && j < list.length)
				{
					tid = MusicPacks.canonicalTrackId(String(list[j]));
					j++;
					if (tid && !claimed[tid] && !seen[tid])
					{
						seen[tid] = true;
						out.push(tid);
					};
				};
			};
			out.sort(sortSongsByTitle);
			return (out);
		}
	}
}
