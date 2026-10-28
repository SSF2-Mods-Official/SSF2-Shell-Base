package
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	/**
	 * Song list view: rows, action rows, marquee, frequency bar, and list background.
	 */
	public class MusicUiSongList
	{
		private var ui:MusicPlayerUi;
		private static const ROW_H:int = 31;
		private var m_marqueeRows:Array;

		public function MusicUiSongList(owner:MusicPlayerUi)
		{
			ui = owner;
			m_marqueeRows = [];
		}

		/** Shrink font until the full label fits in the tile width (no ellipsis crop). */
		internal function fitLabelToWidth(tf:TextField, maxW:Number, startSize:int):void
		{
			var size:int;
			var fmt:TextFormat;
			if (!tf)
			{
				return;
			};
			size = startSize;
			fmt = tf.defaultTextFormat;
			while (size > 7)
			{
				fmt.size = size;
				tf.setTextFormat(fmt);
				tf.defaultTextFormat = fmt;
				if (tf.textWidth <= maxW - 2)
				{
					break;
				};
				size--;
			};
		}

		internal function visibleSongRows():int
		{
			return (Math.max(1, int((songListBottom() - songListTop()) / ROW_H)));
		}

		private function songListTop():int
		{
			return (ui.m_tab == MusicPlayerUi.TAB_SEARCH ? 100 : 78);
		}

		internal function songListBottom():int
		{
			return (ui.m_listBottom);
		}

		private function showsListActions():Boolean
		{
			var cell:Object;
			if (ui.m_view != MusicPlayerUi.VIEW_SONGS || (ui.m_tab != MusicPlayerUi.TAB_STAGE && ui.m_tab != MusicPlayerUi.TAB_PLAYLIST && ui.m_tab != MusicPlayerUi.TAB_SERIES))
			{
				return (false);
			};
			if (ui.m_gridIndex < 0 || ui.m_gridIndex >= ui.m_gridCells.length)
			{
				return (false);
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			if (!cell)
			{
				return (false);
			};
			if (ui.m_tab == MusicPlayerUi.TAB_STAGE)
			{
				return (cell.kind == "stage" || cell.kind == "other");
			};
			if (ui.m_tab == MusicPlayerUi.TAB_SERIES)
			{
				return (cell.kind == "series");
			};
			if (cell.kind == "search" || cell.kind == "pack" || cell.kind == "legacy")
			{
				return (false);
			};
			return (cell.kind == "playlist" || cell.kind == "uploads");
		}

		internal function displayList():Array
		{
			var out:Array;
			if (ui.m_listMode == "add")
			{
				if (ui.m_addSubView == MusicPlayerUi.ADD_PENDING)
				{
					out = pendingIds();
					out.push("__act_commit__");
					return (out);
				};
				if (ui.m_tab == MusicPlayerUi.TAB_SEARCH)
				{
					out = ui.m_songIds ? ui.m_songIds.concat() : [];
					out.push("__act_added_tab__");
					out.push("__act_commit__");
					return (out);
				};
				if (ui.m_addSubView == MusicPlayerUi.ADD_SONGS)
				{
					out = ui.m_addPool ? ui.m_addPool.concat() : [];
					out.push("__act_added_tab__");
					return (out);
				};
				// Album browse uses paintAddAlbums, not this list.
				return ([]);
			};
			if (ui.m_listMode == "remove")
			{
				out = ui.m_songIds ? ui.m_songIds.concat() : [];
				out.push("__act_commit__");
				return (out);
			};
			out = ui.m_songIds ? ui.m_songIds.concat() : [];
			if (showsListActions())
			{
				if (ui.m_songs.isUploadsContext())
				{
					out.push("__act_remove__");
					out.push("__act_upload__");
					out.push("__act_rename__");
					out.push("__act_loop__");
				}
				else if (ui.m_trackSettings.isSeriesContext())
				{
					out.push("__act_add__");
					out.push("__act_upload__");
					out.push("__act_series_settings__");
				}
				else if (ui.m_songs.isCustomPlaylistContext())
				{
					out.push("__act_add__");
					out.push("__act_remove__");
					out.push("__act_upload__");
					out.push("__act_rename_pl__");
					out.push("__act_delete_pl__");
					out.push("__act_save_pack__");
				}
				else
				{
					out.push("__act_add__");
					out.push("__act_remove__");
					out.push("__act_upload__");
					if (ui.m_tab == MusicPlayerUi.TAB_STAGE && ui.m_contextId
						&& ui.m_contextId != MusicSeriesResolver.KEY_OTHER
						&& ui.m_contextId != MusicSeriesResolver.KEY_ALL)
					{
						out.push("__act_reset__");
					};
				};
			};
			return (out);
		}

		internal function isActionId(tid:String):Boolean
		{
			return (tid && tid.indexOf("__act_") == 0);
		}

		private function actionLabel(tid:String):String
		{
			var n:int;
			if (tid == "__act_add__")
			{
				return ("Add Songs");
			};
			if (tid == "__act_remove__")
			{
				return ("Remove Songs");
			};
			if (tid == "__act_upload__")
			{
				return ("Upload Songs");
			};
			if (tid == "__act_series_settings__")
			{
				return ("Series Settings");
			};
			if (tid == "__act_reset__")
			{
				return ("Reset to Default");
			};
			if (tid == "__act_rename__")
			{
				return ("Rename Songs");
			};
			if (tid == "__act_loop__")
			{
				return ("Update Loop");
			};
			if (tid == "__act_rename_pl__")
			{
				return ("Rename Playlist");
			};
			if (tid == "__act_delete_pl__")
			{
				return ("Delete Playlist");
			};
			if (tid == "__act_save_pack__")
			{
				return ("Save as Pack");
			};
			if (tid == "__act_added_tab__")
			{
				return ("Added Songs (" + pendingCount() + ")");
			};
			n = pendingCount();
			return ("Confirm additions" + (n > 0 ? ("  (" + n + ")") : "") + "  — Start");
		}

		private function pendingIds():Array
		{
			var out:Array;
			var k:String;
			out = [];
			if (!ui.m_pending)
			{
				return (out);
			};
			for (k in ui.m_pending)
			{
				if (ui.m_pending[k])
				{
					out.push(k);
				};
			};
			out.sort(ui.m_songs.sortSongsByTitle);
			return (out);
		}

		internal function pendingCount():int
		{
			var k:String;
			var n:int;
			n = 0;
			if (!ui.m_pending)
			{
				return (0);
			};
			for (k in ui.m_pending)
			{
				if (ui.m_pending[k])
				{
					n++;
				};
			};
			return (n);
		}

		internal function paintSongs():void
		{
			var i:int;
			var y:int;
			m_marqueeRows = [];
			var end:int;
			var freqCtx:String;
			var list:Array;
			var listBottom:int;
			list = displayList();
			ui.m_scroll.ensureSongScrollFor(list);
			listBottom = songListBottom();
			end = Math.min(list.length, ui.m_songScroll + visibleSongRows());
			freqCtx = (ui.m_tab == MusicPlayerUi.TAB_STAGE && ui.m_contextId
				&& ui.m_contextId != MusicSeriesResolver.KEY_ALL
				&& !ui.m_listMode) ? ui.m_contextId : null;
			i = ui.m_songScroll;
			while (i < end)
			{
				y = songListTop() + (i - ui.m_songScroll) * ROW_H;
				if (y + ROW_H > listBottom)
				{
					break;
				};
				paintSongRow(String(list[i]), i, y, freqCtx);
				i++;
			};
			if (list.length < 1)
			{
				addRow("(no songs)", 36, 78, false, MusicTheme.uiSoft(), 11);
			};
			ui.m_scroll.paintSongScrollbar();
		}

		/** One song/action row: title, duration, add-mode preview button, click hit, freq bar. */
		private function paintSongRow(tid:String, i:int, y:int, freqCtx:String):void
		{
			var sel:Boolean;
			var nowId:String;
			var isNow:Boolean;
			var action:Boolean;
			var queued:Boolean;
			var tfClip:TextField;
			sel = i == ui.m_songIndex;
			action = isActionId(tid);
			nowId = ui.currentTrackId();
			isNow = !action && !ui.m_listMode && nowId
				&& MusicPacks.canonicalTrackId(tid) == MusicPacks.canonicalTrackId(nowId);
			queued = !action && ui.m_pending && ui.m_pending[tid];
			addRow(songRowTitle(tid, action, queued, isNow), 36, y, sel || isNow || queued, (sel || isNow || action) ? MusicTheme.select() : (queued ? MusicTheme.select() : MusicTheme.ui()), 11);
			if (ui.m_rows.length > 0)
			{
				tfClip = TextField(ui.m_rows[ui.m_rows.length - 1]);
				tfClip.autoSize = TextFieldAutoSize.NONE;
				tfClip.wordWrap = false;
				tfClip.multiline = false;
				tfClip.width = Math.max(80, ui.m_gw - (ui.m_listMode == "add" && !action ? 120 : 80));
				tfClip.height = ROW_H;
				// Marquee only the focused/playing row — scrolling every title leaks work.
				if (sel || isNow)
				{
					registerRowMarquee(tfClip, tfClip.width);
				};
			};
			if (!action)
			{
				addDurationLabel(tid, y);
			};
			if (ui.m_listMode == "add" && !action)
			{
				addPreviewButton(i, y);
			};
			addRowHit(i, y, action);
			if (ui.m_editMode && sel && freqCtx && freqCtx != MusicSeriesResolver.KEY_OTHER && !action)
			{
				drawFreq(ui.m_store.frequency(freqCtx, tid));
			};
		}

		private function songRowTitle(tid:String, action:Boolean, queued:Boolean, isNow:Boolean):String
		{
			var title:String;
			if (action)
			{
				return (actionLabel(tid));
			};
			title = ui.m_catalog.songTitleOrPlaceholder(tid);
			if (ui.m_listMode == "add")
			{
				title = (queued ? "✓  " : "     ") + title;
			}
			else if (ui.m_listMode == "remove" && queued)
			{
				title = "−  " + title;
			};
			if (isNow)
			{
				title = title + "  (now playing)";
			};
			return (title);
		}

		private function addDurationLabel(tid:String, y:int):void
		{
			var durTf:TextField;
			durTf = ui.makeText(ui.m_catalog.songDurationLabel(tid), 0, y + 2, 12, MusicTheme.uiSoft(), false);
			durTf.x = ui.m_gw - (ui.m_listMode == "add" ? 58 : 28) - durTf.textWidth;
			ui.m_listLayer.addChild(durTf);
			ui.m_rows.push(durTf);
		}

		/** Add mode: small play button that previews the row without queueing it. */
		private function addPreviewButton(idx:int, y:int):void
		{
			var playBtn:Sprite;
			playBtn = new Sprite();
			playBtn.graphics.beginFill(MusicTheme.select(), 0.95);
			playBtn.graphics.drawRoundRect(0, 0, 22, 18, 4, 4);
			playBtn.graphics.endFill();
			playBtn.graphics.beginFill(0x111118, 1);
			playBtn.graphics.moveTo(8, 4);
			playBtn.graphics.lineTo(16, 9);
			playBtn.graphics.lineTo(8, 14);
			playBtn.graphics.lineTo(8, 4);
			playBtn.graphics.endFill();
			playBtn.x = ui.m_gw - 50;
			playBtn.y = y + 3;
			playBtn.buttonMode = true;
			playBtn.useHandCursor = true;
			playBtn.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				var rows:Array;
				e.stopPropagation();
				rows = displayList();
				if (rows && idx >= 0 && idx < rows.length && !isActionId(String(rows[idx])))
				{
					ui.m_input.previewTrack(String(rows[idx]));
				};
			});
			ui.m_listLayer.addChild(playBtn);
		}

		private function addRowHit(idx:int, y:int, action:Boolean):void
		{
			var hit:Sprite;
			hit = new Sprite();
			hit.graphics.beginFill(0xFFFFFF, 0.001);
			hit.graphics.drawRect(28, y - 2, Math.max(80, ui.m_gw - (ui.m_listMode == "add" && !action ? 80 : 56)), ROW_H);
			hit.graphics.endFill();
			hit.buttonMode = true;
			hit.useHandCursor = true;
			hit.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				var rows:Array;
				e.stopPropagation();
				ui.m_songIndex = idx;
				rows = displayList();
				if (rows && idx >= 0 && idx < rows.length && !isActionId(String(rows[idx])))
				{
					updateSongListBackground(String(rows[idx]));
				};
				ui.m_input.activateSong();
				ui.paint();
			});
			ui.m_listLayer.addChild(hit);
		}

		internal function hideActionBar():void
		{
			if (ui.m_actionBar)
			{
				ui.m_actionBar.visible = false;
				while (ui.m_actionBar.numChildren > 0)
				{
					ui.m_actionBar.removeChildAt(0);
				};
			};
		}

		internal function updateSongListBackground(tid:String):void
		{
			var sid:String;
			var ctxStage:String;
			if (!tid)
			{
				ui.m_transport.refreshPreviewBg(MusicStageVisuals.WAITING_ROOM_ID);
				return;
			};
			sid = ui.m_catalog ? ui.m_catalog.stageForTrack(tid) : null;
			// Prefer resolved stage art for the highlighted song. Fall back to the
			// open stage folder only when the track has no stage mapping.
			if (!sid && ui.m_view == MusicPlayerUi.VIEW_SONGS && ui.m_contextId
				&& ui.m_contextId != "__search__"
				&& ui.m_contextId.indexOf("__") != 0
				&& ui.m_tab == MusicPlayerUi.TAB_STAGE)
			{
				ctxStage = ui.m_previewStageId || ui.m_contextId;
				if (ctxStage && ctxStage != MusicStageVisuals.OTHER_STAGE_ID)
				{
					sid = ctxStage;
				};
			};
			if (!sid || sid == MusicStageVisuals.OTHER_STAGE_ID)
			{
				sid = MusicStageVisuals.WAITING_ROOM_ID;
			};
			// Accept select-icon stages even when previewer label is missing.
			if (sid != MusicStageVisuals.WAITING_ROOM_ID
				&& !MusicStageVisuals.hasStageSelectIcon(sid)
				&& !MusicStageVisuals.hasStagePreview(sid))
			{
				sid = MusicStageVisuals.WAITING_ROOM_ID;
			};
			ui.m_transport.refreshPreviewBg(sid);
			if (sid != MusicStageVisuals.WAITING_ROOM_ID)
			{
				ui.m_previewStageId = sid;
			};
		}

		private function registerRowMarquee(tf:TextField, maxW:Number):void
		{
			if (!tf || !(maxW > 0))
			{
				return;
			};
			tf.width = maxW;
			tf.scrollH = 0;
			if (tf.maxScrollH <= 0)
			{
				return;
			};
			if (!m_marqueeRows)
			{
				m_marqueeRows = [];
			};
			m_marqueeRows.push({"tf": tf, "maxW": maxW, "scroll": 0, "pause": 30});
		}

		internal function tickRowMarquees():void
		{
			var i:int;
			var row:Object;
			var tf:TextField;
			var maxH:int;
			if (!m_marqueeRows)
			{
				return;
			};
			i = 0;
			while (i < m_marqueeRows.length)
			{
				row = m_marqueeRows[i];
				i++;
				tf = row.tf as TextField;
				if (!tf || !tf.parent)
				{
					continue;
				};
				maxH = tf.maxScrollH;
				if (maxH <= 0)
				{
					tf.scrollH = 0;
					continue;
				};
				if (int(row.pause) > 0)
				{
					row.pause = int(row.pause) - 1;
					if (int(row.pause) <= 0 && Number(row.scroll) >= maxH - 0.5)
					{
						row.scroll = 0;
						row.pause = 55;
						tf.scrollH = 0;
					};
					continue;
				};
				row.scroll = Number(row.scroll) + 0.85;
				if (row.scroll >= maxH)
				{
					row.scroll = maxH;
					row.pause = 75;
				};
				tf.scrollH = int(row.scroll);
			};
		}

		private function drawFreq(value:Number):void
		{
			var i:int;
			var v:int;
			ui.m_freqBar.graphics.clear();
			v = int(Math.round(value));
			i = 0;
			while (i <= 5)
			{
				ui.m_freqBar.graphics.beginFill(i <= v ? MusicTheme.select() : 0x444444, 0.95);
				ui.m_freqBar.graphics.drawRect(i * 28, 0, 22, 10);
				ui.m_freqBar.graphics.endFill();
				i++;
			};
		}

		internal function clearRows():void
		{
			var i:int;
			ui.m_freqBar.graphics.clear();
			i = ui.m_listLayer.numChildren - 1;
			while (i >= 0)
			{
				ui.m_listLayer.removeChildAt(i);
				i--;
			};
			ui.m_rows = [];
		}

		private function addRow(text:String, x:int, y:int, bold:Boolean, color:uint, size:int = 10):void
		{
			var tf:TextField;
			tf = ui.makeText(text, x, y, size, color, bold);
			ui.m_listLayer.addChild(tf);
			ui.m_rows.push(tf);
		}
	}
}
