package
{
	import flash.display.DisplayObject;
	import flash.display.Sprite;

	/**
	 * Now-playing bar wiring: transport buttons, media keys, expand/collapse, now-playing metadata and backgrounds.
	 */
	public class MusicUiTransport
	{
		private var ui:MusicPlayerUi;
		private var m_npStageId:String;
		private var m_npSeriesKey:String;

		public function MusicUiTransport(owner:MusicPlayerUi)
		{
			ui = owner;
			m_npStageId = null;
			m_npSeriesKey = null;
		}

		internal function onNpSettings():void
		{
			ui.m_trackSettings.openTrackSettingsMenu();
		}

		internal function onNpVolume(vol:Number, save:Boolean = false):void
		{
			if (ui.m_playback && ui.m_playback.applyBgmVolume is Function)
			{
				ui.m_playback.applyBgmVolume(vol, save);
			};
		}

		internal function refreshSpinIcon():void
		{
			var key:String;
			var holder:Sprite;
			var icon:DisplayObject;
			var tid:String;
			var sid:String;
			if (!ui.m_npBar)
			{
				return;
			};
			tid = ui.currentTrackId();
			sid = null;
			key = null;
			if (tid && ui.m_catalog && ui.m_catalog.songMeta[tid])
			{
				if (ui.m_catalog.songMeta[tid].symbolKey)
				{
					key = String(ui.m_catalog.songMeta[tid].symbolKey);
				};
				if (ui.m_catalog.songMeta[tid].seriesKey && !key)
				{
					key = String(ui.m_catalog.songMeta[tid].seriesKey);
				};
			};
			if (tid && ui.m_catalog)
			{
				sid = ui.m_catalog.stageForTrack(tid);
			};
			// Disc art uses stage_select icons (attachTileArt), not stagePreviewer frames.
			if (!sid || sid == MusicStageVisuals.OTHER_STAGE_ID
				|| !MusicStageVisuals.hasStageSelectIcon(sid))
			{
				sid = MusicStageVisuals.WAITING_ROOM_ID;
				if (!key)
				{
					key = MusicSeriesResolver.KEY_ALL;
				};
			}
			else if (!key)
			{
				key = MusicSeriesResolver.keyForStage(sid);
			};
			ui.m_npBar.setCdStageArt(sid);
			holder = new Sprite();
			icon = MusicSeriesResolver.attachIcon(holder, key, 28, true);
			if (icon)
			{
				ui.m_npBar.setSpinIcon(icon);
			};
		}

		internal function refreshSpaceBg():void
		{
			var wash:Sprite;
			var i:int;
			i = ui.m_bgLayer.numChildren - 1;
			while (i >= 0)
			{
				ui.m_bgLayer.removeChildAt(i);
				i--;
			};
			ui.m_bgLayer.graphics.clear();
			ui.m_bgLayer.graphics.beginFill(0x08080C, 1);
			ui.m_bgLayer.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			ui.m_bgLayer.graphics.endFill();
			// Same asset menus use: library linkage menu_bg_space.
			MusicStageVisuals.attachMenuBg(ui.m_bgLayer, MusicStageVisuals.SPACE_BG_ID, ui.m_gw, ui.m_gh);
			wash = new Sprite();
			wash.graphics.beginFill(0x050508, 0.55);
			wash.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			wash.graphics.endFill();
			ui.m_bgLayer.addChild(wash);
		}

		internal function refreshPreviewBg(stageId:String):void
		{
			var wash:Sprite;
			var art:DisplayObject;
			var i:int;
			i = ui.m_bgLayer.numChildren - 1;
			while (i >= 0)
			{
				ui.m_bgLayer.removeChildAt(i);
				i--;
			};
			ui.m_bgLayer.graphics.clear();
			ui.m_bgLayer.graphics.beginFill(0x08080C, 1);
			ui.m_bgLayer.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			ui.m_bgLayer.graphics.endFill();
			if (stageId)
			{
				// List browse: lightweight select-icons only (no stagePreviewer clones).
				art = MusicStageVisuals.attachStageBackdrop(ui.m_bgLayer, stageId, ui.m_gw, ui.m_gh);
				if (!art && stageId != MusicStageVisuals.WAITING_ROOM_ID)
				{
					MusicStageVisuals.attachStageBackdrop(ui.m_bgLayer,
						MusicStageVisuals.WAITING_ROOM_ID, ui.m_gw, ui.m_gh);
				};
			}
			else
			{
				MusicStageVisuals.attachMenuBg(ui.m_bgLayer, MusicStageVisuals.SPACE_BG_ID, ui.m_gw, ui.m_gh);
			};
			wash = new Sprite();
			wash.graphics.beginFill(0x050508, stageId ? 0.72 : 0.55);
			wash.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			wash.graphics.endFill();
			ui.m_bgLayer.addChild(wash);
		}

		internal function refreshNowPlayingMeta():void
		{
			var title:String;
			var artist:String;
			var stageName:String;
			var seriesName:String;
			var tid:String;
			var sid:String;
			var st:Object;
			var prevTid:String;
			if (!ui.m_npBar)
			{
				return;
			};
			title = "";
			artist = "";
			stageName = "";
			seriesName = "";
			tid = ui.currentTrackId();
			prevTid = ui.m_lastSpinTrackId;
			try
			{
				if (!tid && ui.m_host && ui.m_host.getSessionFlag is Function)
				{
					title = String(ui.m_host.getSessionFlag("music_player.now_playing") || "");
					tid = String(ui.m_host.getSessionFlag("music_player.now_id") || "");
				}
				else if (ui.m_host && ui.m_host.getSessionFlag is Function)
				{
					title = String(ui.m_host.getSessionFlag("music_player.now_playing") || "");
				};
			}
			catch (err:*)
			{
			};
			if (tid && ui.m_catalog && ui.m_catalog.isUploadTrack(tid))
			{
				title = ui.m_catalog.songTitle(tid);
				if (!title)
				{
					title = tid;
				};
				artist = ui.m_catalog.songArtist(tid);
				if (!artist)
				{
					artist = "";
					stageName = "Uploaded Song";
				};
				ui.m_npBar.setTrack(title, artist, stageName, "");
				if (ui.m_playback && ui.m_playback.getState is Function)
				{
					st = ui.m_playback.getState();
					if (st)
					{
						ui.m_npBar.setPlayback(Boolean(st.paused), Number(st.posMs || 0), Number(st.durMs || 0));
					};
				};
				if (tid != prevTid)
				{
					ui.m_lastSpinTrackId = tid;
					refreshSpinIcon();
					if (ui.m_open && ui.m_view == MusicPlayerUi.VIEW_SONGS)
					{
						ui.m_songs.selectNowPlayingInList();
						ui.m_songList.updateSongListBackground(tid);
						ui.paint();
					};
				};
				return;
			};
			if (tid && ui.m_catalog)
			{
				if (!title)
				{
					title = ui.m_catalog.songTitle(tid);
				};
				artist = ui.m_catalog.songArtist(tid);
				sid = ui.m_catalog.stageForTrack(tid);
			};
			m_npStageId = sid;
			m_npSeriesKey = sid && sid != MusicStageVisuals.OTHER_STAGE_ID
				? MusicSeriesResolver.keyForStage(sid) : null;
			if (sid && sid != MusicStageVisuals.OTHER_STAGE_ID)
			{
				stageName = MusicStageVisuals.stageDisplayName(sid);
				seriesName = MusicSeriesResolver.seriesLabel(m_npSeriesKey);
			};
			ui.m_npBar.setTrack(title, artist, stageName, seriesName);
			if (ui.m_playback && ui.m_playback.getState is Function)
			{
				st = ui.m_playback.getState();
				if (st)
				{
					ui.m_npBar.setPlayback(Boolean(st.paused), Number(st.posMs || 0), Number(st.durMs || 0));
				};
			};
			if (tid && tid != prevTid)
			{
				ui.m_lastSpinTrackId = tid;
				refreshSpinIcon();
				if (ui.m_open && ui.m_view == MusicPlayerUi.VIEW_SONGS)
				{
					ui.m_songs.selectNowPlayingInList();
					if (!ui.m_songList.isActionId(tid))
					{
						ui.m_songList.updateSongListBackground(tid);
					};
					ui.paint();
				};
			};
			if (ui.m_playback && ui.m_playback.getRepeatOne is Function)
			{
				ui.m_npBar.setRepeatOne(Boolean(ui.m_playback.getRepeatOne()));
			};
			if (ui.m_playback && ui.m_playback.getShuffle is Function)
			{
				ui.m_npBar.setShuffle(Boolean(ui.m_playback.getShuffle()));
			};
		}

		internal function mediaPlayPause():void
		{
			var list:Array;
			var tid:String;
			ui.playUiSfx("menu_select");
			if (ui.m_view == MusicPlayerUi.VIEW_SONGS && ui.m_listMode == "add")
			{
				list = ui.m_songList.displayList();
				if (list && ui.m_songIndex >= 0 && ui.m_songIndex < list.length)
				{
					tid = String(list[ui.m_songIndex]);
					if (!ui.m_songList.isActionId(tid))
					{
						ui.m_input.previewTrack(tid);
						return;
					};
				};
			};
			if (ui.m_playback && ui.m_playback.togglePause is Function)
			{
				ui.m_playback.togglePause();
			};
		}

		internal function mediaPrev():void
		{
			ui.playUiSfx("menu_hover");
			if (ui.m_playback && ui.m_playback.prev is Function)
			{
				ui.m_playback.prev();
			};
		}

		internal function mediaNext():void
		{
			ui.playUiSfx("menu_hover");
			if (ui.m_playback && ui.m_playback.next is Function)
			{
				ui.m_playback.next();
			};
		}

		internal function mediaToggleLoop():void
		{
			ui.playUiSfx("menu_select");
			if (ui.m_playback && ui.m_playback.cyclePlayMode is Function)
			{
				ui.m_playback.cyclePlayMode();
			}
			else if (ui.m_playback && ui.m_playback.toggleRepeat is Function)
			{
				ui.m_playback.toggleRepeat();
			};
			syncNpPlayMode();
		}

		internal function onNpPrev():void
		{
			if (ui.m_playback && ui.m_playback.prev is Function)
			{
				ui.m_playback.prev();
			};
		}

		internal function onNpPlay():void
		{
			if (ui.m_playback && ui.m_playback.togglePause is Function)
			{
				ui.m_playback.togglePause();
			};
		}

		internal function onNpNext():void
		{
			if (ui.m_playback && ui.m_playback.next is Function)
			{
				ui.m_playback.next();
			};
		}

		internal function onNpExpand():void
		{
			var on:Boolean;
			var tid:String;
			var sid:String;
			if (!ui.m_npBar)
			{
				return;
			};
			on = !ui.m_npBar.expanded;
			if (on)
			{
				setJukeboxChromeVisible(false);
				ui.m_npBar.setExpanded(true);
				tid = ui.currentTrackId();
				sid = tid && ui.m_catalog ? ui.m_catalog.stageForTrack(tid) : null;
				if (!sid || sid == MusicStageVisuals.OTHER_STAGE_ID
					|| !MusicStageVisuals.hasStageSelectIcon(sid))
				{
					sid = MusicStageVisuals.WAITING_ROOM_ID;
				};
				ui.m_npBar.setCdStageArt(sid);
			}
			else
			{
				ui.m_npBar.clearFullscreenPreview();
				ui.m_npBar.setExpanded(false);
				setJukeboxChromeVisible(true);
				refreshSpinIcon();
				ui.paint();
			};
		}

		/** Hide grid/list chrome so expanded now-playing is a true fullscreen stage. */
		private function setJukeboxChromeVisible(on:Boolean):void
		{
			if (ui.m_gridLayer)
			{
				ui.m_gridLayer.visible = on && ui.m_view == MusicPlayerUi.VIEW_GRID;
				ui.m_gridLayer.mouseEnabled = on;
				ui.m_gridLayer.mouseChildren = on;
			};
			if (ui.m_listLayer)
			{
				ui.m_listLayer.visible = on && ui.m_view == MusicPlayerUi.VIEW_SONGS;
				ui.m_listLayer.mouseEnabled = on;
				ui.m_listLayer.mouseChildren = on;
			};
			if (ui.m_uiLayer)
			{
				ui.m_uiLayer.visible = on;
				ui.m_uiLayer.mouseEnabled = on;
				ui.m_uiLayer.mouseChildren = on;
			};
			if (ui.m_scrollBar)
			{
				ui.m_scrollBar.visible = on && ui.m_scrollBar.visible;
				if (!on)
				{
					ui.m_scrollBar.visible = false;
				};
				ui.m_scrollBar.mouseEnabled = on;
				ui.m_scrollBar.mouseChildren = on;
			};
			if (ui.m_searchRow && !on)
			{
				ui.m_searchRow.visible = false;
			};
			if (ui.m_actionBar && !on)
			{
				ui.m_actionBar.visible = false;
			};
			if (ui.m_bgLayer)
			{
				ui.m_bgLayer.visible = on;
				ui.m_bgLayer.mouseEnabled = on;
				ui.m_bgLayer.mouseChildren = on;
			};
		}

		internal function onNpSeek(ratio:Number):void
		{
			if (ui.m_playback && ui.m_playback.seek is Function)
			{
				ui.m_playback.seek(ratio);
			};
		}

		internal function snapshotNavContext():Object
		{
			var cell:Object;
			if (ui.m_gridIndex >= 0 && ui.m_gridIndex < ui.m_gridCells.length)
			{
				cell = ui.m_gridCells[ui.m_gridIndex];
			}
			else if (ui.m_contextId)
			{
				cell = {
					"id": ui.m_contextId,
					"kind": ui.m_tab == MusicPlayerUi.TAB_SERIES ? "series"
						: (ui.m_tab == MusicPlayerUi.TAB_PLAYLIST ? "playlist" : "stage"),
					"label": ui.m_title ? ui.m_title.text : ui.m_contextId
				};
			}
			else
			{
				return (null);
			};
			return ({"tab": ui.m_tab, "cell": cell, "stageGridMode": ui.m_stageGridMode});
		}

		private function openNavContext(ctx:Object):void
		{
			var tab:int;
			var cell:Object;
			var i:int;
			if (!ctx || !ctx.cell)
			{
				return;
			};
			tab = int(ctx.tab);
			cell = ctx.cell;
			ui.m_stageGridMode = ctx.stageGridMode ? String(ctx.stageGridMode) : null;
			ui.m_tab = tab;
			ui.m_listMode = null;
			ui.m_addSubView = null;
			ui.m_view = MusicPlayerUi.VIEW_GRID;
			ui.m_grid.rebuildGrid();
			i = 0;
			while (i < ui.m_gridCells.length)
			{
				if (String(ui.m_gridCells[i].id) == String(cell.id)
					&& String(ui.m_gridCells[i].kind) == String(cell.kind))
				{
					ui.m_gridIndex = i;
					ui.m_songs.enterSongsFromGrid();
					return;
				};
				i++;
			};
			ui.m_gridIndex = 0;
			ui.m_songs.enterSongsFromGrid();
		}

		internal function onNpTitleClick():void
		{
			if (ui.m_npNavCell)
			{
				openNavContext(ui.m_npNavCell);
			}
			else
			{
				onNpSeriesClick();
			};
		}

		internal function onNpStageClick():void
		{
			if (m_npStageId && m_npStageId != MusicStageVisuals.OTHER_STAGE_ID)
			{
				ui.openStageSongs(m_npStageId);
			}
			else if (m_npStageId == MusicStageVisuals.OTHER_STAGE_ID)
			{
				ui.m_tab = MusicPlayerUi.TAB_STAGE;
				ui.m_grid.rebuildGrid();
				ui.m_gridIndex = 0;
				ui.m_songs.enterSongsFromGrid();
			};
		}

		internal function onNpSeriesClick():void
		{
			var i:int;
			if (!m_npSeriesKey)
			{
				return;
			};
			ui.m_tab = MusicPlayerUi.TAB_SERIES;
			ui.m_grid.rebuildGrid();
			i = 0;
			while (i < ui.m_gridCells.length)
			{
				if (ui.m_gridCells[i].kind == "series" && String(ui.m_gridCells[i].id) == m_npSeriesKey)
				{
					ui.m_gridIndex = i;
					ui.m_songs.enterSongsFromGrid();
					return;
				};
				i++;
			};
		}

		internal function onNpRepeat():void
		{
			if (ui.m_playback && ui.m_playback.cyclePlayMode is Function)
			{
				ui.m_playback.cyclePlayMode();
			}
			else if (ui.m_playback && ui.m_playback.toggleRepeat is Function)
			{
				ui.m_playback.toggleRepeat();
			};
			syncNpPlayMode();
		}

		private function syncNpPlayMode():void
		{
			if (!ui.m_npBar || !ui.m_playback)
			{
				return;
			};
			if (ui.m_playback.getRepeatOne is Function)
			{
				ui.m_npBar.setRepeatOne(Boolean(ui.m_playback.getRepeatOne()));
			};
			if (ui.m_playback.getShuffle is Function)
			{
				ui.m_npBar.setShuffle(Boolean(ui.m_playback.getShuffle()));
			};
		}
	}
}
