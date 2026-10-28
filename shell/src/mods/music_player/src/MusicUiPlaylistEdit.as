package
{
	import flash.display.Sprite;
	import flash.events.FileListEvent;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.net.FileFilter;
	import flash.text.TextField;

	/**
	 * Playlist editing: add/remove songs, album browse for adds, rename/delete/save-as-pack, uploads.
	 */
	public class MusicUiPlaylistEdit
	{
		private var ui:MusicPlayerUi;
		private var m_uploadFile:File;
		private var m_uploadQueue:Array;
		private var m_uploadBar:Sprite;
		private var m_uploadDone:int;
		private var m_uploadCount:int;
		private var m_addAlbumCells:Array;
		private var m_addAlbumIndex:int;

		public function MusicUiPlaylistEdit(owner:MusicPlayerUi)
		{
			ui = owner;
			m_uploadFile = null;
			m_addAlbumCells = [];
			m_addAlbumIndex = 0;
		}

		internal function backFromAddMode():void
		{
			if (ui.m_addSubView == MusicPlayerUi.ADD_SONGS || ui.m_addSubView == MusicPlayerUi.ADD_PENDING)
			{
				ui.m_addSubView = null;
				ui.m_view = MusicPlayerUi.VIEW_GRID;
				ui.m_gridScroll = 0;
				ui.paint();
				return;
			};
			ui.m_listMode = null;
			ui.m_addSubView = null;
			ui.m_addTargetCell = null;
			ui.m_pending = {};
			ui.m_editMode = false;
			ui.m_view = MusicPlayerUi.VIEW_SONGS;
			ui.m_songs.reloadContextSongs();
			ui.paint();
		}

		private function enterAddSongsMode():void
		{
			ui.m_listMode = "add";
			ui.m_editMode = false;
			ui.m_pending = {};
			ui.m_addSubView = null;
			ui.m_addTargetCell = (ui.m_gridIndex >= 0 && ui.m_gridIndex < ui.m_gridCells.length)
				? ui.m_gridCells[ui.m_gridIndex] : null;
			ui.m_addPool = [];
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			ui.m_view = MusicPlayerUi.VIEW_GRID;
			ui.m_transport.refreshPreviewBg(MusicStageVisuals.WAITING_ROOM_ID);
			ui.paint();
		}

		internal function addTargetLabel():String
		{
			if (!ui.m_addTargetCell)
			{
				return ("Playlist");
			};
			return (String(ui.m_addTargetCell.label || ui.m_addTargetCell.id || "Playlist"));
		}

		internal function enterAddBrowseSongs(cell:Object):void
		{
			var have:Object;
			var list:Array;
			var i:int;
			var tid:String;
			var pool:Array;
			if (!cell)
			{
				return;
			};
			have = {};
			if (ui.m_addTargetCell)
			{
				list = ui.m_songs.songsForContext(ui.m_addTargetCell);
				i = 0;
				while (i < list.length)
				{
					have[String(list[i])] = true;
					i++;
				};
			};
			pool = [];
			list = ui.m_songs.songsForContext(cell);
			i = 0;
			while (i < list.length)
			{
				tid = String(list[i]);
				i++;
				tid = MusicPacks.canonicalTrackId(tid);
				if (tid && !have[tid])
				{
					pool.push(tid);
				};
			};
			ui.m_addPool = pool;
			ui.m_addSubView = MusicPlayerUi.ADD_SONGS;
			ui.m_view = MusicPlayerUi.VIEW_SONGS;
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			if (ui.m_addPool.length > 0)
			{
				ui.m_songList.updateSongListBackground(String(ui.m_addPool[0]));
			}
			else
			{
				ui.m_transport.refreshPreviewBg(ui.m_songs.previewStageForCell(cell) || MusicStageVisuals.WAITING_ROOM_ID);
			};
			ui.paint();
		}

		private function paintAddAlbums():void
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
			var iconKey:String;
			var stageFill:String;
			var rowPitch:int;
			var cellIndex:int;
			var tip:TextField;
			while (ui.m_gridLayer.numChildren > 0)
			{
				ui.m_gridLayer.removeChildAt(0);
			};
			tip = ui.makeText("Pick an album · Added Songs (" + ui.m_songList.pendingCount() + ") below", 36, 68, 12, MusicTheme.uiSoft(), false);
			ui.m_gridLayer.addChild(tip);
			hit = new Sprite();
			hit.graphics.beginFill(MusicTheme.select(), 0.95);
			hit.graphics.drawRoundRect(0, 0, 160, 24, 6, 6);
			hit.graphics.endFill();
			hit.x = ui.m_gw - 200;
			hit.y = 66;
			label = ui.makeText("Added (" + ui.m_songList.pendingCount() + ")", 8, 3, 11, 0x111118, true);
			hit.addChild(label);
			hit.buttonMode = true;
			hit.useHandCursor = true;
			hit.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				e.stopPropagation();
				openAddedSongsView();
			});
			ui.m_gridLayer.addChild(hit);
			cols = MusicPlayerUi.COLS;
			rowPitch = MusicPlayerUi.CELL + MusicPlayerUi.LABEL_H + MusicPlayerUi.GAP;
			rowsVis = Math.max(2, int((ui.m_listBottom - 100) / rowPitch));
			start = ui.m_gridScroll;
			i = start;
			while (m_addAlbumCells && i < m_addAlbumCells.length && i < start + cols * rowsVis)
			{
				cell = m_addAlbumCells[i];
				col = (i - start) % cols;
				row = int((i - start) / cols);
				x0 = 36 + col * (MusicPlayerUi.CELL + MusicPlayerUi.GAP);
				y0 = 100 + row * rowPitch;
				sel = i == m_addAlbumIndex;
				holder = new Sprite();
				holder.x = x0 + MusicPlayerUi.CELL * 0.5;
				holder.y = y0 + MusicPlayerUi.CELL * 0.5;
				iconKey = cell.seriesKey ? String(cell.seriesKey)
					: (cell.kind == "stage" ? MusicSeriesResolver.keyForStage(String(cell.id)) : String(cell.id));
				if (cell.kind == "other")
				{
					iconKey = MusicSeriesResolver.KEY_OTHER;
				};
				stageFill = cell.kind == "stage" ? String(cell.id) : ui.m_songs.previewStageForCell(cell);
				MusicSeriesResolver.attachSeriesTile(holder, iconKey, stageFill, MusicPlayerUi.CELL, MusicPlayerUi.CELL, true);
				holder.graphics.lineStyle(sel ? 2 : 1, sel ? MusicTheme.select() : 0x555566, 0.95);
				holder.graphics.drawRoundRect(-MusicPlayerUi.CELL * 0.5, -MusicPlayerUi.CELL * 0.5, MusicPlayerUi.CELL, MusicPlayerUi.CELL, 8, 8);
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
						m_addAlbumIndex = idx;
						enterAddAlbumSongs();
					};
				})(cellIndex));
				ui.m_gridLayer.addChild(hit);
				label = ui.makeText(String(cell.label || ""), x0, y0 + MusicPlayerUi.CELL + 2, 10,
					sel ? MusicTheme.select() : MusicTheme.uiSoft(), false);
				label.width = MusicPlayerUi.CELL;
				label.height = MusicPlayerUi.LABEL_H + 2;
				ui.m_songList.fitLabelToWidth(label, MusicPlayerUi.CELL, 10);
				ui.m_gridLayer.addChild(label);
				i++;
			};
			ui.m_scroll.hideScrollBar();
		}

		internal function enterAddAlbumSongs():void
		{
			var cell:Object;
			var have:Object;
			var list:Array;
			var i:int;
			var tid:String;
			var pool:Array;
			if (!m_addAlbumCells || m_addAlbumIndex < 0 || m_addAlbumIndex >= m_addAlbumCells.length)
			{
				return;
			};
			cell = m_addAlbumCells[m_addAlbumIndex];
			have = {};
			if (ui.m_addTargetCell)
			{
				list = ui.m_songs.songsForContext(ui.m_addTargetCell);
				i = 0;
				while (i < list.length)
				{
					have[String(list[i])] = true;
					i++;
				};
			};
			pool = [];
			list = ui.m_songs.songsForContext(cell);
			i = 0;
			while (i < list.length)
			{
				tid = String(list[i]);
				i++;
				if (tid && !have[tid])
				{
					pool.push(tid);
				};
			};
			ui.m_addPool = pool;
			ui.m_addSubView = MusicPlayerUi.ADD_SONGS;
			ui.m_view = MusicPlayerUi.VIEW_SONGS;
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			if (ui.m_addPool.length > 0)
			{
				ui.m_songList.updateSongListBackground(String(ui.m_addPool[0]));
			}
			else
			{
				ui.m_transport.refreshPreviewBg(ui.m_songs.previewStageForCell(cell) || MusicStageVisuals.WAITING_ROOM_ID);
			};
			ui.paint();
		}

		private function openAddedSongsView():void
		{
			ui.m_addSubView = MusicPlayerUi.ADD_PENDING;
			ui.m_view = MusicPlayerUi.VIEW_SONGS;
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			ui.paint();
		}

		private function enterRemoveSongsMode():void
		{
			ui.m_listMode = "remove";
			ui.m_editMode = false;
			ui.m_pending = {};
			ui.m_addPool = [];
			ui.m_songs.reloadContextSongs();
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			ui.paint();
		}

		private function resetStageToDefault():void
		{
			if (ui.m_tab != MusicPlayerUi.TAB_STAGE || !ui.m_contextId)
			{
				return;
			};
			if (ui.m_contextId == MusicSeriesResolver.KEY_OTHER || ui.m_contextId == MusicSeriesResolver.KEY_ALL)
			{
				return;
			};
			ui.m_store.restoreStageDefaults(ui.m_contextId);
			ui.m_listMode = null;
			ui.m_editMode = false;
			ui.m_songs.reloadContextSongs();
			ui.paint();
		}

		private function beginUploadSong():void
		{
			try
			{
				if (m_uploadFile)
				{
					m_uploadFile.removeEventListener(FileListEvent.SELECT_MULTIPLE, onUploadMulti);
				};
				m_uploadFile = new File();
				m_uploadFile.addEventListener(FileListEvent.SELECT_MULTIPLE, onUploadMulti);
				m_uploadFile.browseForOpenMultiple("Upload songs", [
					new FileFilter("Audio", "*.mp3;*.wav;*.ogg;*.m4a;*.aac;*.swf")
				]);
			}
			catch (err:*)
			{
				trace("[music_player] multi upload browse failed: " + err);
				ui.playUiSfx("menu_error");
			};
		}

		private function onUploadMulti(e:FileListEvent):void
		{
			var files:Array;
			files = e.files;
			if (!files || files.length < 1)
			{
				return;
			};
			m_uploadQueue = files.concat();
			m_uploadCount = m_uploadQueue.length;
			m_uploadDone = 0;
			showUploadProgress(0, m_uploadCount);
			ingestNextUpload();
		}

		private function ingestNextUpload():void
		{
			var src:File;
			if (!m_uploadQueue || m_uploadQueue.length < 1)
			{
				hideUploadProgress();
				ui.m_listMode = null;
				ui.m_editMode = false;
				ui.m_pending = {};
				ui.m_songs.reloadContextSongs();
				ui.paint();
				ui.playUiSfx("menu_select");
				return;
			};
			src = m_uploadQueue.shift() as File;
			showUploadProgress(m_uploadDone, m_uploadCount);
			ingestOneUpload(src);
		}

		private function ingestOneUpload(src:File):void
		{
			var dest:File;
			var rawDest:File;
			var base:String;
			var tid:String;
			var ext:String;
			var nameOnly:String;
			var dot:int;
			try
			{
				if (!src || !src.exists)
				{
					m_uploadDone++;
					ingestNextUpload();
					return;
				};
				nameOnly = src.name ? String(src.name) : "";
				if (!nameOnly && src.nativePath)
				{
					nameOnly = String(src.nativePath).split("\\").pop().split("/").pop();
				};
				ext = "mp3";
				base = nameOnly;
				dot = nameOnly.lastIndexOf(".");
				if (dot > 0)
				{
					ext = nameOnly.substring(dot + 1).toLowerCase();
					base = nameOnly.substring(0, dot);
				};
				if (!ext)
				{
					ext = "mp3";
				};
				tid = "bgm_upload_" + base.split(" ").join("_").toLowerCase();
				tid = tid.split("-").join("_");
				tid = sanitizeTrackId(tid);
				if (tid.length < 12)
				{
					tid = "bgm_upload_" + String(new Date().time);
				};
				// Always store as .mp3 — Flash Sound cannot play M4A/MP4 "mp3" renames.
				dest = MusicSongLibrary.destForUpload(tid);
				if (dest.parent && !dest.parent.exists)
				{
					dest.parent.createDirectory();
				};
				rawDest = dest;
				if (ext != "mp3" || !MusicUploadTranscode.isFlashMp3(src))
				{
					rawDest = new File(dest.nativePath + ".src." + ext);
				};
				src.copyTo(rawDest, true);
				MusicUploadTranscode.ensureFlashMp3(rawDest, dest, function (out:File):void
				{
					finishUpload(tid, base, out);
					if (rawDest && rawDest.exists && rawDest.nativePath != out.nativePath)
					{
						try
						{
							rawDest.deleteFile();
						}
						catch (delErr:*)
						{
						};
					};
					m_uploadDone++;
					showUploadProgress(m_uploadDone, m_uploadCount);
					ingestNextUpload();
				}, function (msg:String):void
				{
					trace("[music_player] upload convert failed: " + msg);
					try
					{
						if (rawDest && rawDest.exists)
						{
							rawDest.deleteFile();
						};
					}
					catch (cleanupErr:*)
					{
					};
					m_uploadDone++;
					ingestNextUpload();
				});
			}
			catch (err:*)
			{
				trace("[music_player] upload failed: " + err);
				m_uploadDone++;
				ingestNextUpload();
			};
		}

		private function finishUpload(tid:String, base:String, dest:File):void
		{
			if (!dest || !dest.exists)
			{
				return;
			};
			if (ui.m_catalog)
			{
				ui.m_catalog.rememberLocalTrack(tid, base, dest.nativePath);
			};
			if (ui.m_playback && ui.m_playback.registerUpload is Function)
			{
				ui.m_playback.registerUpload(tid);
			};
			if (!ui.m_songs.isUploadsContext())
			{
				addTrackToCurrentList(tid);
			};
		}

		internal function onFoldersChanged():void
		{
			if (ui.m_playback && ui.m_playback.registerFolders is Function)
			{
				ui.m_playback.registerFolders();
			};
			if (!ui.m_open)
			{
				return;
			};
			ui.m_grid.rebuildGrid();
			if (ui.m_view == MusicPlayerUi.VIEW_SONGS)
			{
				ui.m_songs.reloadContextSongs();
			};
			ui.paint();
		}

		private function showUploadProgress(done:int, total:int):void
		{
			var tf:TextField;
			var ratio:Number;
			if (!m_uploadBar)
			{
				m_uploadBar = new Sprite();
			};
			if (m_uploadBar.parent != ui)
			{
				ui.addChild(m_uploadBar);
			};
			while (m_uploadBar.numChildren > 0)
			{
				m_uploadBar.removeChildAt(0);
			};
			m_uploadBar.graphics.clear();
			m_uploadBar.graphics.beginFill(0x000000, 0.55);
			m_uploadBar.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			m_uploadBar.graphics.endFill();
			m_uploadBar.graphics.beginFill(0x16161E, 1);
			m_uploadBar.graphics.drawRoundRect(ui.m_gw * 0.5 - 180, ui.m_gh * 0.5 - 36, 360, 72, 10, 10);
			m_uploadBar.graphics.endFill();
			ratio = total > 0 ? done / total : 0;
			m_uploadBar.graphics.beginFill(0x333333, 1);
			m_uploadBar.graphics.drawRoundRect(ui.m_gw * 0.5 - 150, ui.m_gh * 0.5 + 4, 300, 12, 6, 6);
			m_uploadBar.graphics.endFill();
			m_uploadBar.graphics.beginFill(MusicTheme.select(), 1);
			m_uploadBar.graphics.drawRoundRect(ui.m_gw * 0.5 - 150, ui.m_gh * 0.5 + 4, Math.max(4, 300 * ratio), 12, 6, 6);
			m_uploadBar.graphics.endFill();
			tf = ui.makeText("Converting " + Math.min(done + 1, total) + " / " + total, ui.m_gw * 0.5 - 150, ui.m_gh * 0.5 - 24, 14, 0xFFFFFF, true);
			m_uploadBar.addChild(tf);
			ui.safeBringToFront(m_uploadBar);
		}

		private function hideUploadProgress():void
		{
			if (m_uploadBar && m_uploadBar.parent)
			{
				m_uploadBar.parent.removeChild(m_uploadBar);
			};
		}

		private function addTrackToCurrentList(tid:String):void
		{
			var cell:Object;
			var sid:String;
			var stages:Array;
			var i:int;
			if (!tid || ui.m_gridIndex < 0 || ui.m_gridIndex >= ui.m_gridCells.length)
			{
				return;
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			if (cell.kind == "playlist")
			{
				ui.m_store.addSongToPlaylist(String(cell.id), tid);
				return;
			};
			if (cell.kind == "series")
			{
				stages = MusicSeriesResolver.stagesForSeries(String(cell.id));
				i = 0;
				while (stages && i < stages.length)
				{
					ui.m_store.addSong(String(stages[i]), tid);
					i++;
				};
				return;
			};
			if (cell.kind == "stage" || cell.kind == "other")
			{
				sid = cell.kind == "other" || String(cell.id) == MusicSeriesResolver.KEY_OTHER
					? MusicStageVisuals.OTHER_STAGE_ID : String(cell.id);
				ui.m_store.addSong(sid, tid);
			};
		}

		private function sanitizeTrackId(raw:String):String
		{
			var out:String;
			var i:int;
			var ch:String;
			var code:int;
			out = "";
			i = 0;
			while (raw && i < raw.length)
			{
				ch = raw.charAt(i);
				code = raw.charCodeAt(i);
				i++;
				if ((code >= 48 && code <= 57) || (code >= 65 && code <= 90)
					|| (code >= 97 && code <= 122) || ch == "_")
				{
					out += ch;
				}
				else
				{
					out += "_";
				};
			};
			return (out);
		}

		private function removeTrackFromCurrentList(tid:String):Boolean
		{
			var cell:Object;
			var sid:String;
			if (!tid || ui.m_gridIndex < 0 || ui.m_gridIndex >= ui.m_gridCells.length)
			{
				return (false);
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			if (cell.kind == "uploads" || cell.id == MusicPlaylistStore.UPLOAD_PLAYLIST_ID)
			{
				if (ui.m_catalog)
				{
					ui.m_catalog.forgetLocalTrack(tid);
				};
				if (ui.m_store)
				{
					ui.m_store.purgeTrack(tid);
				};
				return (true);
			};
			if (cell.kind == "playlist")
			{
				return (ui.m_store.removeSongFromPlaylist(String(cell.id), tid));
			};
			if (cell.kind == "stage" || cell.kind == "other")
			{
				sid = cell.kind == "other" || String(cell.id) == MusicSeriesResolver.KEY_OTHER
					? MusicStageVisuals.OTHER_STAGE_ID : String(cell.id);
				return (ui.m_store.removeSong(sid, tid));
			};
			return (false);
		}

		internal function moveAddAlbum(delta:int):void
		{
			var n:int;
			n = m_addAlbumCells ? m_addAlbumCells.length : 0;
			if (n < 1)
			{
				return;
			};
			m_addAlbumIndex = (m_addAlbumIndex + delta + n * 8) % n;
			ui.playUiSfx("menu_hover");
			ui.paint();
		}

		internal function runListAction(tid:String):void
		{
			ui.playUiSfx("menu_select");
			if (tid == "__act_add__")
			{
				enterAddSongsMode();
				return;
			};
			if (tid == "__act_remove__")
			{
				enterRemoveSongsMode();
				return;
			};
			if (tid == "__act_upload__")
			{
				beginUploadSong();
				return;
			};
			if (tid == "__act_series_settings__")
			{
				ui.m_trackSettings.openSeriesSettingsMenu();
				return;
			};
			if (tid == "__act_reset__")
			{
				resetStageToDefault();
				return;
			};
			if (tid == "__act_rename__")
			{
				ui.m_listMode = "rename";
				ui.m_pending = {};
				ui.m_songIndex = 0;
				ui.m_songScroll = 0;
				ui.paint();
				return;
			};
			if (tid == "__act_loop__")
			{
				ui.m_listMode = "loop";
				ui.m_pending = {};
				ui.m_songIndex = 0;
				ui.m_songScroll = 0;
				ui.paint();
				return;
			};
			if (tid == "__act_rename_pl__")
			{
				renameCurrentPlaylist();
				return;
			};
			if (tid == "__act_delete_pl__")
			{
				deleteCurrentPlaylist();
				return;
			};
			if (tid == "__act_save_pack__")
			{
				saveCurrentPlaylistAsPack();
				return;
			};
			if (tid == "__act_added_tab__")
			{
				openAddedSongsView();
				return;
			};
			if (tid == "__act_commit__")
			{
				commitPending();
			};
		}

		private function renameCurrentPlaylist():void
		{
			var cell:Object;
			var id:String;
			if (!ui.m_songs.isCustomPlaylistContext())
			{
				return;
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			id = String(cell.id);
			ui.m_dialogs.openTextPrompt("Rename playlist", ui.m_store.playlistLabel(id), function (value:String):void
			{
				if (value && value.length > 0)
				{
					ui.m_store.renamePlaylist(id, value);
					ui.m_grid.rebuildGrid();
					ui.paint();
				};
			});
		}

		private function deleteCurrentPlaylist():void
		{
			var cell:Object;
			var id:String;
			if (!ui.m_songs.isCustomPlaylistContext())
			{
				return;
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			id = String(cell.id);
			ui.m_dialogs.openTextPrompt("Type DELETE to confirm", "", function (value:String):void
			{
				if (value && String(value).toUpperCase() == "DELETE")
				{
					ui.m_store.deletePlaylist(id);
					ui.m_songs.exitSongs();
				};
			});
		}

		private function saveCurrentPlaylistAsPack():void
		{
			var cell:Object;
			var id:String;
			var songs:Array;
			var slug:String;
			if (!ui.m_songs.isCustomPlaylistContext())
			{
				return;
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			id = String(cell.id);
			songs = ui.m_store.songsForPlaylist(id);
			slug = MusicPacks.savePlaylistAsPack(id, ui.m_store.playlistLabel(id), songs, ui.m_catalog);
			if (slug)
			{
				if (ui.m_playback && ui.m_playback.registerFolders is Function)
				{
					ui.m_playback.registerFolders();
				};
				ui.m_grid.rebuildGrid();
				ui.paint();
				ui.playUiSfx("menu_select");
			}
			else
			{
				ui.playUiSfx("menu_error");
			};
		}

		internal function commitPending():void
		{
			var k:String;
			var n:int;
			var target:Object;
			n = 0;
			target = ui.m_addTargetCell;
			if (ui.m_pending)
			{
				for (k in ui.m_pending)
				{
					if (!ui.m_pending[k])
					{
						continue;
					};
					if (ui.m_listMode == "add")
					{
						if (target)
						{
							addTrackToCell(target, k);
						}
						else
						{
							addTrackToCurrentList(k);
						};
						n++;
					}
					else if (ui.m_listMode == "remove")
					{
						if (removeTrackFromCurrentList(k))
						{
							n++;
						};
					};
				};
			};
			ui.m_pending = {};
			ui.m_listMode = null;
			ui.m_addSubView = null;
			ui.m_addTargetCell = null;
			ui.m_grid.invalidateGridCaches();
			ui.m_editMode = false;
			ui.m_view = MusicPlayerUi.VIEW_SONGS;
			ui.m_songs.reloadContextSongs();
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			ui.paint();
			ui.playUiSfx(n > 0 ? "menu_select" : "menu_error");
		}

		private function addTrackToCell(cell:Object, tid:String):void
		{
			var sid:String;
			var stages:Array;
			var i:int;
			if (!tid || !cell)
			{
				return;
			};
			tid = MusicPacks.canonicalTrackId(tid);
			if (cell.kind == "playlist")
			{
				ui.m_store.addSongToPlaylist(String(cell.id), tid);
				return;
			};
			if (cell.kind == "series")
			{
				stages = MusicSeriesResolver.stagesForSeries(String(cell.id));
				i = 0;
				while (stages && i < stages.length)
				{
					ui.m_store.addSong(String(stages[i]), tid);
					i++;
				};
				return;
			};
			if (cell.kind == "stage" || cell.kind == "other")
			{
				sid = cell.kind == "other" || String(cell.id) == MusicSeriesResolver.KEY_OTHER
					? MusicStageVisuals.OTHER_STAGE_ID : String(cell.id);
				ui.m_store.addSong(sid, tid);
			};
		}

		internal function createPlaylistQuick():void
		{
			var slot:Object;
			slot = ui.m_store.nextPlaylistSlot();
			ui.m_store.createPlaylist(String(slot.id), String(slot.label), MusicSeriesResolver.KEY_ALL);
			ui.m_grid.rebuildGrid();
			ui.paint();
		}
	}
}
