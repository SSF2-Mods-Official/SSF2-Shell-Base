package
{
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Pad/keyboard input: per-frame poll, hold-repeat, list/grid moves, key handler, input holdoff.
	 */
	public class MusicUiInput
	{
		private var ui:MusicPlayerUi;
		private static const ADD_ALBUMS:String = "albums";
		private static const HOLD_DELAY:int = 16;
		private static const HOLD_FAST:int = 3;
		private static const HOLD_TURBO:int = 1;
		private static const KEY_E:uint = 69;
		private static const KEY_N:uint = 78;
		private var m_prevKeys:Object;
		/** True once Shield/Grab fired a combo while Taunt was held (suppress tap→tabs). */
		private var m_tauntChordUsed:Boolean;
		private var m_saveDataCls:Class;

		public function MusicUiInput(owner:MusicPlayerUi)
		{
			ui = owner;
			m_prevKeys = {};
			m_tauntChordUsed = false;
		}

		internal function seedPrevKeys():void
		{
			m_prevKeys.up = padDown("UP");
			m_prevKeys.down = padDown("DOWN");
			m_prevKeys.left = padDown("LEFT");
			m_prevKeys.right = padDown("RIGHT");
			m_prevKeys.ok = padDown("BUTTON2");
			m_prevKeys.back = padDown("BUTTON1");
			m_prevKeys.taunt = padDown("TAUNT");
			m_prevKeys.jump = padDown("JUMP");
			m_prevKeys.shield = padDown("SHIELD");
			m_prevKeys.grab = padDown("GRAB");
			m_prevKeys.start = padDown("START");
		}

		internal function onFrame(e:Event):void
		{
			var up:Boolean;
			var down:Boolean;
			var left:Boolean;
			var right:Boolean;
			var ok:Boolean;
			var back:Boolean;
			if (!ui.m_open)
			{
				return;
			};
			tickFrameVisuals();
			up = padDown("UP");
			down = padDown("DOWN");
			left = padDown("LEFT");
			right = padDown("RIGHT");
			ok = padDown("BUTTON2");
			back = padDown("BUTTON1");
			if (ui.m_blockingOverlay)
			{
				pollModalNav(up, down, left, right, ok, back);
				latchKeys(up, down, left, right, ok, back);
				return;
			};
			pollMediaButtons();
			pollTauntChord();
			// Expanded now-playing: media + expand/back only — no album grid/list nav.
			if (ui.m_npBar && ui.m_npBar.expanded)
			{
				if (back && !m_prevKeys.back)
				{
					ui.m_transport.onNpExpand();
				};
				latchKeys(up, down, left, right, ok, back);
				return;
			};
			tickHold(up, down);
			if (ui.m_listMode == "add" && ui.m_addSubView == ADD_ALBUMS)
			{
				pollAddAlbumsNav(left, right, ok, back);
			}
			else if (ui.m_view == MusicPlayerUi.VIEW_GRID)
			{
				pollGridNav(left, right, ok, back);
			}
			else
			{
				pollSongListNav(left, right, ok, back);
			};
			latchKeys(up, down, left, right, ok, back);
		}

		/** Keep the jukebox on top and advance spin / marquee / now-playing text. */
		private function tickFrameVisuals():void
		{
			var st:Object;
			if (ui.parent)
			{
				ui.parent.setChildIndex(ui, ui.parent.numChildren - 1);
			};
			if (ui.m_npBar)
			{
				st = null;
				if (ui.m_playback && ui.m_playback.getState is Function)
				{
					st = ui.m_playback.getState();
				};
				ui.m_npBar.tickSpin(st ? Boolean(st.paused) : true);
				ui.m_npBar.tickMarquee();
			};
			ui.m_songList.tickRowMarquees();
			ui.m_transport.refreshNowPlayingMeta();
		}

		/** Modal overlay owns the pad: move its selection, confirm, or back out. */
		private function pollModalNav(up:Boolean, down:Boolean, left:Boolean, right:Boolean, ok:Boolean, back:Boolean):void
		{
			if (up && !m_prevKeys.up && ui.m_modalItems)
			{
				if (ui.m_modalKind == "tiles")
				{
					ui.m_modalIndex = Math.max(0, ui.m_modalIndex - 6);
				}
				else
				{
					ui.m_modalIndex = (ui.m_modalIndex - 1 + ui.m_modalItems.length) % ui.m_modalItems.length;
				};
				if (ui.m_modalRefresh != null)
				{
					ui.m_modalRefresh();
				};
			};
			if (down && !m_prevKeys.down && ui.m_modalItems)
			{
				if (ui.m_modalKind == "tiles")
				{
					ui.m_modalIndex = Math.min(ui.m_modalItems.length - 1, ui.m_modalIndex + 6);
				}
				else
				{
					ui.m_modalIndex = (ui.m_modalIndex + 1) % ui.m_modalItems.length;
				};
				if (ui.m_modalRefresh != null)
				{
					ui.m_modalRefresh();
				};
			};
			if (left && !m_prevKeys.left && ui.m_modalItems && ui.m_modalKind == "tiles")
			{
				ui.m_modalIndex = Math.max(0, ui.m_modalIndex - 1);
				if (ui.m_modalRefresh != null)
				{
					ui.m_modalRefresh();
				};
			};
			if (right && !m_prevKeys.right && ui.m_modalItems && ui.m_modalKind == "tiles")
			{
				ui.m_modalIndex = Math.min(ui.m_modalItems.length - 1, ui.m_modalIndex + 1);
				if (ui.m_modalRefresh != null)
				{
					ui.m_modalRefresh();
				};
			};
			if (ok && !m_prevKeys.ok && ui.m_modalOnConfirm != null)
			{
				ui.m_modalOnConfirm();
			};
			if (back && !m_prevKeys.back)
			{
				if (ui.m_modalOnBack != null)
				{
					ui.m_modalOnBack();
				}
				else
				{
					ui.m_dialogs.dismissBlockingOverlay();
				};
			};
		}

		/** Jump = play/pause, Shield = prev, Grab = next, Start = commit edit or loop toggle. */
		private function pollMediaButtons():void
		{
			if (padDown("JUMP") && !m_prevKeys.jump)
			{
				ui.m_transport.mediaPlayPause();
			};
			if (padDown("SHIELD") && !m_prevKeys.shield && !padDown("TAUNT"))
			{
				ui.m_transport.mediaPrev();
			};
			if (padDown("GRAB") && !m_prevKeys.grab && !padDown("TAUNT"))
			{
				ui.m_transport.mediaNext();
			};
			if (padDown("START") && !m_prevKeys.start)
			{
				if (ui.m_listMode == "add" || ui.m_listMode == "remove")
				{
					ui.m_edit.commitPending();
				}
				else
				{
					ui.m_transport.mediaToggleLoop();
				};
			};
		}

		// Taunt hold + Shield = settings; Taunt hold + Grab = expand;
		// Taunt tap (press+release, no chord) = cycle tabs.
		private function pollTauntChord():void
		{
			if (padDown("TAUNT") && !m_prevKeys.taunt)
			{
				m_tauntChordUsed = false;
			};
			if (padDown("TAUNT"))
			{
				if (padDown("SHIELD") && !m_prevKeys.shield)
				{
					m_tauntChordUsed = true;
					ui.m_trackSettings.openTrackSettingsMenu();
				}
				else if (padDown("GRAB") && !m_prevKeys.grab)
				{
					m_tauntChordUsed = true;
					ui.m_transport.onNpExpand();
				};
			};
			if (!padDown("TAUNT") && m_prevKeys.taunt && !m_tauntChordUsed)
			{
				if (ui.m_view == MusicPlayerUi.VIEW_GRID)
				{
					cycleTab(1);
				};
			};
		}

		private function pollAddAlbumsNav(left:Boolean, right:Boolean, ok:Boolean, back:Boolean):void
		{
			if (left && !m_prevKeys.left)
			{
				ui.m_edit.moveAddAlbum(-1);
			};
			if (right && !m_prevKeys.right)
			{
				ui.m_edit.moveAddAlbum(1);
			};
			if (ok && !m_prevKeys.ok)
			{
				ui.m_edit.enterAddAlbumSongs();
			};
			if (back && !m_prevKeys.back)
			{
				ui.m_edit.backFromAddMode();
			};
		}

		private function pollGridNav(left:Boolean, right:Boolean, ok:Boolean, back:Boolean):void
		{
			if (left && !m_prevKeys.left)
			{
				ui.m_grid.moveGrid(-1);
			};
			if (right && !m_prevKeys.right)
			{
				ui.m_grid.moveGrid(1);
			};
			if (ok && !m_prevKeys.ok)
			{
				ui.m_songs.enterSongsFromGrid();
			};
			if (back && !m_prevKeys.back)
			{
				ui.close();
			};
		}

		private function pollSongListNav(left:Boolean, right:Boolean, ok:Boolean, back:Boolean):void
		{
			if (ui.m_editMode && ui.m_tab == MusicPlayerUi.TAB_STAGE)
			{
				if (left && !m_prevKeys.left)
				{
					nudgeFreq(-1);
				};
				if (right && !m_prevKeys.right)
				{
					nudgeFreq(1);
				};
			};
			if (ok && !m_prevKeys.ok)
			{
				activateSong();
			};
			if (back && !m_prevKeys.back)
			{
				if (ui.m_listMode == "add")
				{
					ui.m_edit.backFromAddMode();
				}
				else if (ui.m_listMode)
				{
					ui.m_listMode = null;
					ui.m_pending = {};
					ui.m_editMode = false;
					ui.m_songs.reloadContextSongs();
					ui.paint();
				}
				else if (ui.m_editMode)
				{
					ui.m_editMode = false;
					ui.paint();
				}
				else if (ui.m_tab == MusicPlayerUi.TAB_SEARCH)
				{
					ui.selectTab(MusicPlayerUi.TAB_STAGE);
				}
				else
				{
					ui.m_songs.exitSongs();
				};
			};
		}

		/** Remember this frame's buttons for edge detection next frame. */
		private function latchKeys(up:Boolean, down:Boolean, left:Boolean, right:Boolean, ok:Boolean, back:Boolean):void
		{
			m_prevKeys.up = up;
			m_prevKeys.down = down;
			m_prevKeys.left = left;
			m_prevKeys.right = right;
			m_prevKeys.ok = ok;
			m_prevKeys.back = back;
			m_prevKeys.taunt = padDown("TAUNT");
			m_prevKeys.jump = padDown("JUMP");
			m_prevKeys.shield = padDown("SHIELD");
			m_prevKeys.grab = padDown("GRAB");
			m_prevKeys.start = padDown("START");
		}

		private function tickHold(up:Boolean, down:Boolean):void
		{
			var period:int;
			if (up && !down)
			{
				if (!m_prevKeys.up)
				{
					navVert(-1);
					ui.m_holdDir = -1;
					ui.m_holdAge = 0;
				}
				else if (ui.m_holdDir == -1)
				{
					ui.m_holdAge++;
					period = ui.m_holdAge > 50 ? HOLD_TURBO : HOLD_FAST;
					if (ui.m_holdAge >= HOLD_DELAY && ((ui.m_holdAge - HOLD_DELAY) % period) == 0)
					{
						navVert(-1);
					};
				};
			}
			else if (down && !up)
			{
				if (!m_prevKeys.down)
				{
					navVert(1);
					ui.m_holdDir = 1;
					ui.m_holdAge = 0;
				}
				else if (ui.m_holdDir == 1)
				{
					ui.m_holdAge++;
					period = ui.m_holdAge > 50 ? HOLD_TURBO : HOLD_FAST;
					if (ui.m_holdAge >= HOLD_DELAY && ((ui.m_holdAge - HOLD_DELAY) % period) == 0)
					{
						navVert(1);
					};
				};
			}
			else
			{
				ui.m_holdDir = 0;
				ui.m_holdAge = 0;
			};
		}

		internal function navVert(delta:int):void
		{
			if (ui.m_listMode == "add" && ui.m_addSubView == ADD_ALBUMS)
			{
				ui.m_edit.moveAddAlbum(delta * MusicPlayerUi.COLS);
			}
			else if (ui.m_view == MusicPlayerUi.VIEW_GRID)
			{
				ui.m_grid.moveGrid(delta * MusicPlayerUi.COLS);
			}
			else
			{
				moveSong(delta);
			};
		}

		private function cycleTab(delta:int):void
		{
			var next:int;
			next = (ui.m_tab + delta + 4) % 4;
			ui.selectTab(next);
		}

		private function moveSong(delta:int):void
		{
			var n:int;
			var list:Array;
			var tid:String;
			list = ui.m_songList.displayList();
			n = list ? list.length : 0;
			if (n < 1)
			{
				return;
			};
			ui.playUiSfx("menu_hover");
			ui.m_songIndex = (ui.m_songIndex + delta + n) % n;
			ui.m_scroll.ensureSongScrollFor(list);
			tid = String(list[ui.m_songIndex]);
			if (!ui.m_songList.isActionId(tid))
			{
				ui.m_songList.updateSongListBackground(tid);
				MusicMem.snap("moveSong", "tid=" + tid);
			};
			ui.paint();
		}

		internal function activateSong():void
		{
			var tid:String;
			var list:Array;
			list = ui.m_songList.displayList();
			if (ui.m_songIndex < 0 || !list || ui.m_songIndex >= list.length)
			{
				return;
			};
			tid = String(list[ui.m_songIndex]);
			if (ui.m_songList.isActionId(tid))
			{
				ui.m_edit.runListAction(tid);
				return;
			};
			if (ui.m_listMode == "add" || ui.m_listMode == "remove")
			{
				if (!ui.m_pending)
				{
					ui.m_pending = {};
				};
				ui.m_pending[tid] = !ui.m_pending[tid];
				ui.playUiSfx("menu_select");
				ui.paint();
				return;
			};
			if (ui.m_listMode == "rename")
			{
				ui.m_dialogs.openTextPrompt("Rename song", ui.m_catalog ? ui.m_catalog.songTitle(tid) : tid, function (value:String):void
				{
					if (ui.m_catalog && value && value.length > 0)
					{
						ui.m_catalog.renameLocalTrack(tid, value);
					};
					ui.m_listMode = null;
					ui.m_songs.reloadContextSongs();
					ui.paint();
				});
				return;
			};
			if (ui.m_listMode == "loop")
			{
				ui.m_trackSettings.openLoopPrompt(tid);
				return;
			};
			ui.playUiSfx("menu_select");
			ui.m_queue = ui.m_songIds.concat();
			if (ui.m_playback && ui.m_playback.setQueue is Function)
			{
				ui.m_playback.setQueue(ui.m_queue, ui.m_songIds.indexOf(tid));
			};
			ui.m_npNavCell = ui.m_transport.snapshotNavContext();
			if (ui.m_onPick != null)
			{
				ui.m_onPick(tid, ui.m_contextId, ui.m_matchPick);
			};
			ui.m_transport.refreshNowPlayingMeta();
			ui.paint();
		}

		internal function previewTrack(tid:String):void
		{
			if (!tid)
			{
				return;
			};
			ui.playUiSfx("menu_select");
			if (ui.m_playback && ui.m_playback.preview is Function)
			{
				ui.m_playback.preview(tid);
			}
			else if (ui.m_onPick != null)
			{
				ui.m_onPick(tid, ui.m_contextId, false);
			};
			ui.m_transport.refreshNowPlayingMeta();
		}

		private function nudgeFreq(delta:int):void
		{
			var tid:String;
			var v:Number;
			if (!ui.m_editMode || ui.m_tab != MusicPlayerUi.TAB_STAGE || !ui.m_contextId)
			{
				return;
			};
			if (ui.m_contextId == MusicSeriesResolver.KEY_ALL || ui.m_contextId == MusicSeriesResolver.KEY_OTHER)
			{
				return;
			};
			if (ui.m_songIndex < 0 || ui.m_songIndex >= ui.m_songIds.length)
			{
				return;
			};
			tid = String(ui.m_songIds[ui.m_songIndex]);
			v = ui.m_store.frequency(ui.m_contextId, tid) + delta;
			ui.m_store.setFrequency(ui.m_contextId, tid, v);
			ui.paint();
		}

		internal function onKey(e:KeyboardEvent):Boolean
		{
			var code:uint;
			if (!ui.m_open)
			{
				return (false);
			};
			if (ui.m_blockingOverlay)
			{
				code = e.keyCode;
				if (code == 27 || code == 8)
				{
					if (ui.m_modalOnBack != null)
					{
						ui.m_modalOnBack();
					}
					else
					{
						ui.m_dialogs.dismissBlockingOverlay();
					};
					return (true);
				};
				if ((code == 13 || code == 32) && ui.m_modalOnConfirm != null)
				{
					ui.m_modalOnConfirm();
					return (true);
				};
				if ((code == 38 || code == 40) && ui.m_modalItems)
				{
					ui.m_modalIndex += (code == 40) ? 1 : -1;
					if (ui.m_modalIndex < 0)
					{
						ui.m_modalIndex = ui.m_modalItems.length - 1;
					};
					if (ui.m_modalIndex >= ui.m_modalItems.length)
					{
						ui.m_modalIndex = 0;
					};
					if (ui.m_modalRefresh != null)
					{
						ui.m_modalRefresh();
					};
					return (true);
				};
				return (true);
			};
			code = e.keyCode;
			if (ui.m_tab == MusicPlayerUi.TAB_SEARCH && ui.m_searchInput && ui.stage && ui.stage.focus == ui.m_searchInput)
			{
				if (code == 27)
				{
					ui.selectTab(MusicPlayerUi.TAB_STAGE);
				};
				return (true);
			};
			if (code == 80)
			{
				ui.m_transport.mediaPlayPause();
				return (true);
			};
			if (code == 219)
			{
				ui.m_transport.mediaPrev();
				return (true);
			};
			if (code == 221)
			{
				ui.m_transport.mediaNext();
				return (true);
			};
			if (code == 76)
			{
				ui.m_transport.mediaToggleLoop();
				return (true);
			};
			if (code == KEY_E && ui.m_view == MusicPlayerUi.VIEW_SONGS && ui.m_tab == MusicPlayerUi.TAB_STAGE)
			{
				ui.m_editMode = !ui.m_editMode;
				ui.paint();
				return (true);
			};
			if (code == KEY_E && ui.m_view == MusicPlayerUi.VIEW_GRID && ui.m_tab == MusicPlayerUi.TAB_SERIES
				&& ui.m_gridIndex >= 0 && ui.m_gridIndex < ui.m_gridCells.length
				&& ui.m_gridCells[ui.m_gridIndex].kind == "series")
			{
				ui.m_grid.beginRenameSeries(String(ui.m_gridCells[ui.m_gridIndex].id));
				return (true);
			};
			if (code == 86)
			{
				// V: toggle visualizer
				ui.m_transport.onNpExpand();
				return (true);
			};
			if (code == KEY_N && ui.m_view == MusicPlayerUi.VIEW_GRID && ui.m_tab == MusicPlayerUi.TAB_PLAYLIST)
			{
				ui.m_edit.createPlaylistQuick();
				return (true);
			};
			if (code == 81)
			{
				// Q: prev tab
				cycleTab(-1);
				return (true);
			};
			if (code == 87)
			{
				// W: next tab
				cycleTab(1);
				return (true);
			};
			if (code == 37 || code == 38 || code == 39 || code == 40
				|| code == 13 || code == 32 || code == 27)
			{
				return (true);
			};
			return (true);
		}

		internal function onHoldoffFrame(e:Event):void
		{
			var root:*;
			if (ui.m_releaseHoldoff)
			{
				if (padDown("BUTTON1") || padDown("BUTTON2"))
				{
					return;
				};
				ui.m_releaseHoldoff = false;
				blockInput(false);
			};
			root = e && e.currentTarget ? e.currentTarget : ui.resolveGameRoot();
			if (root)
			{
				root.removeEventListener(Event.ENTER_FRAME, onHoldoffFrame);
			};
		}

		private function padDown(which:String):Boolean
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			try
			{
				if (!m_saveDataCls)
				{
					m_saveDataCls = EngineRefs.ssf2("util.SaveData") as Class;
				};
				SD = m_saveDataCls;
				list = SD ? SD["Controllers"] : null;
				if (!list)
				{
					return (false);
				};
				i = 0;
				while (i < list.length)
				{
					c = list[i];
					i++;
					if (!c || !(c["IsDown"] is Function))
					{
						continue;
					};
					if (which == "UP" && Boolean(c["IsDown"](c["_UP"], true)))
					{
						return (true);
					};
					if (which == "DOWN" && Boolean(c["IsDown"](c["_DOWN"], true)))
					{
						return (true);
					};
					if (which == "LEFT" && Boolean(c["IsDown"](c["_LEFT"], true)))
					{
						return (true);
					};
					if (which == "RIGHT" && Boolean(c["IsDown"](c["_RIGHT"], true)))
					{
						return (true);
					};
					if (which == "BUTTON1" && Boolean(c["IsDown"](c["_BUTTON1"], true)))
					{
						return (true);
					};
					if (which == "BUTTON2" && Boolean(c["IsDown"](c["_BUTTON2"], true)))
					{
						return (true);
					};
					if (which == "TAUNT" && Boolean(c["IsDown"](c["_TAUNT"], true)))
					{
						return (true);
					};
					if (which == "JUMP" && Boolean(c["IsDown"](c["_JUMP"], true)))
					{
						return (true);
					};
					if (which == "SHIELD" && (Boolean(c["IsDown"](c["_SHIELD"], true))
						|| Boolean(c["IsDown"](c["_SHIELD2"], true))))
					{
						return (true);
					};
					if (which == "GRAB" && Boolean(c["IsDown"](c["_GRAB"], true)))
					{
						return (true);
					};
					if (which == "START" && Boolean(c["IsDown"](c["_START"], true)))
					{
						return (true);
					};
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function blockInput(on:Boolean):void
		{
			var MH:*;
			try
			{
				if (ui.m_host)
				{
					ui.m_host.setSessionFlag("music_player.overlay", on);
				};
				MH = EngineRefs.ssf2("modhost.ModHost");
				if (MH && MH["setInputBlocked"] is Function)
				{
					MH["setInputBlocked"](on);
				};
			}
			catch (err:*)
			{
			};
		}
	}
}
