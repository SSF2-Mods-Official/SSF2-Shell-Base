package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.geom.Point;
	import flash.net.FileFilter;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import ssf2mm.shared.LucideIcons;

	/**
	 * Per-track and per-series settings menus (series, stage art, loop point, artwork upload).
	 */
	public class MusicUiTrackSettings
	{
		private var ui:MusicPlayerUi;
		private var m_settingsTrackId:String;
		private var m_seriesSettingsKey:String;

		public function MusicUiTrackSettings(owner:MusicPlayerUi)
		{
			ui = owner;
		}

		internal function openTrackSettingsMenu():void
		{
			var tid:String;
			var panel:Sprite;
			var card:Sprite;
			var items:Array;
			var i:int;
			var row:Sprite;
			var iconHost:Sprite;
			var tf:TextField;
			var title:TextField;
			var iconCls:Class;
			var cardH:Number;
			var sel:uint;
			tid = ui.currentTrackId();
			if (!tid || !ui.m_catalog)
			{
				return;
			};
			m_settingsTrackId = tid;
			ui.m_dialogs.closeSettingsOverlay();
			if (ui.m_helpOverlay && ui.m_helpOverlay.parent)
			{
				ui.m_helpOverlay.parent.removeChild(ui.m_helpOverlay);
				ui.m_helpOverlay = null;
			};
			sel = MusicTheme.select();
			panel = new Sprite();
			panel.graphics.beginFill(0x000000, 0.62);
			panel.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			panel.graphics.endFill();
			items = [
				{"label": "Song name", "icon": LucideIcons.TYPE},
				{"label": "Artist", "icon": LucideIcons.PENCIL},
				{"label": "Music loop", "icon": LucideIcons.SLIDERS},
				{"label": "Series", "icon": LucideIcons.PALETTE},
				{"label": "Stage album art", "icon": LucideIcons.SHAPES},
				{"label": "My Jukebox colors", "icon": LucideIcons.PALETTE},
				{"label": "Close", "icon": null}
			];
			cardH = 48 + items.length * 32 + 14;
			card = new Sprite();
			card.x = Math.max(12, Math.min(ui.m_gw - 356, ui.m_gw - 100 - 170));
			card.y = Math.max(8, ui.m_gh - MusicNowPlayingBar.BAR_H - cardH - 12);
			card.graphics.beginFill(0x121218, 0.98);
			card.graphics.lineStyle(1, MusicTheme.ui(), 0.22);
			card.graphics.drawRoundRect(0, 0, 340, cardH, 14, 14);
			card.graphics.endFill();
			panel.addChild(card);
			title = ui.makeText("Song settings", 18, 10, 15, MusicTheme.ui(), true);
			card.addChild(title);
			tf = ui.makeText(ui.m_catalog.songTitle(tid), 18, 30, 11, MusicTheme.uiSoft(), false);
			tf.width = 300;
			tf.autoSize = TextFieldAutoSize.NONE;
			card.addChild(tf);
			i = 0;
			while (i < items.length)
			{
				row = new Sprite();
				row.graphics.beginFill(i == items.length - 1 ? 0x2A2A34 : 0x1A1A22, 1);
				row.graphics.drawRoundRect(0, 0, 304, 28, 8, 8);
				row.graphics.endFill();
				row.x = 18;
				row.y = 50 + i * 32;
				row.buttonMode = true;
				row.useHandCursor = true;
				iconCls = items[i].icon as Class;
				if (iconCls)
				{
					iconHost = new Sprite();
					iconHost.x = 4;
					iconHost.y = 0;
					iconHost.mouseEnabled = false;
					LucideIcons.draw(iconHost.graphics, iconCls, 26, MusicTheme.ui(), 5);
					row.addChild(iconHost);
				};
				tf = ui.makeText(String(items[i].label), iconCls ? 36 : 12, 5, 12, MusicTheme.ui(), false);
				row.addChild(tf);
				row.addEventListener(MouseEvent.CLICK, (function (action:String):Function
				{
					return function (e:MouseEvent):void
					{
						e.stopPropagation();
						runTrackSettingAction(action);
					};
				})(String(items[i].label)));
				card.addChild(row);
				i++;
			};
			panel.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				if (e.target == panel)
				{
					ui.m_dialogs.closeSettingsOverlay();
				};
			});
			ui.m_settingsOverlay = panel;
			ui.m_blockingOverlay = panel;
			ui.m_modalKind = "settings";
			ui.m_modalItems = items;
			ui.m_modalIndex = 0;
			ui.m_modalOnConfirm = function ():void
			{
				if (ui.m_modalItems && ui.m_modalIndex >= 0 && ui.m_modalIndex < ui.m_modalItems.length)
				{
					runTrackSettingAction(String(ui.m_modalItems[ui.m_modalIndex].label));
				};
			};
			ui.m_modalOnBack = ui.m_dialogs.closeSettingsOverlay;
			ui.addChild(panel);
			ui.m_dialogs.highlightModalRows(card, 50, 32, 304, 28);
			ui.m_modalRefresh = function ():void
			{
				ui.m_dialogs.highlightModalRows(card, 50, 32, 304, 28);
			};
		}

		private function runTrackSettingAction(action:String):void
		{
			var tid:String;
			var cur:String;
			tid = m_settingsTrackId || ui.currentTrackId();
			if (action == "Close" || !tid)
			{
				ui.m_dialogs.closeSettingsOverlay();
				return;
			};
			ui.m_dialogs.closeSettingsOverlay();
			if (action == "Song name")
			{
				ui.m_dialogs.openTextPrompt("Song name", ui.m_catalog.songTitle(tid), function (value:String):void
				{
					if (value && value.length > 0)
					{
						ui.m_catalog.renameLocalTrack(tid, value);
						ui.m_transport.refreshNowPlayingMeta();
						ui.paint();
					};
					openTrackSettingsMenu();
				}, openTrackSettingsMenu);
				return;
			};
			if (action == "Artist")
			{
				cur = ui.m_catalog.songArtist(tid) || "";
				ui.m_dialogs.openTextPrompt("Artist", cur, function (value:String):void
				{
					ui.m_catalog.setTrackArtist(tid, value || "");
					ui.m_transport.refreshNowPlayingMeta();
					ui.paint();
					openTrackSettingsMenu();
				}, openTrackSettingsMenu);
				return;
			};
			if (action == "Music loop")
			{
				openLoopPrompt(tid);
				return;
			};
			if (action == "Series")
			{
				openSeriesPicker(tid);
				return;
			};
			if (action == "Stage album art")
			{
				openStageArtPicker(tid);
				return;
			};
			if (action == "My Jukebox colors")
			{
				ui.m_theme.openThemeColorsMenu();
				return;
			};
		}

		private function openSeriesPicker(tid:String):void
		{
			var keys:Array;
			var custom:Object;
			var k:String;
			keys = MusicSeriesResolver.seriesKeys();
			custom = MusicOverrides.customSeries();
			for (k in custom)
			{
				if (k && keys.indexOf(k) < 0)
				{
					keys.push(k);
				};
			};
			keys.sort(function (a:String, b:String):int
			{
				var la:String = (MusicSeriesResolver.seriesLabel(a) || a).toLowerCase();
				var lb:String = (MusicSeriesResolver.seriesLabel(b) || b).toLowerCase();
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
			ui.m_dialogs.openFilterListPicker("Series", keys, function (key:String):String
			{
				return MusicSeriesResolver.seriesLabel(key) || key;
			}, function (key:String, row:Sprite):void
			{
				var host:Sprite;
				host = new Sprite();
				host.x = 18;
				host.y = 14;
				host.mouseEnabled = false;
				MusicSeriesResolver.attachIcon(host, key, 22, true);
				row.addChild(host);
			}, function (key:String):void
			{
				ui.m_catalog.setTrackSeriesKey(tid, key || "");
				MusicSeriesResolver.invalidate();
				ui.m_transport.refreshNowPlayingMeta();
				ui.m_transport.refreshSpinIcon();
				ui.paint();
				openTrackSettingsMenu();
			}, openTrackSettingsMenu, function ():void
			{
				ui.m_catalog.setTrackSeriesKey(tid, "");
				MusicSeriesResolver.invalidate();
				ui.m_transport.refreshNowPlayingMeta();
				ui.m_transport.refreshSpinIcon();
				ui.paint();
				openTrackSettingsMenu();
			});
		}

		private function openStageArtPicker(tid:String):void
		{
			var ids:Array;
			var i:int;
			var sid:String;
			ids = [];
			i = 0;
			while (ui.m_catalog && i < ui.m_catalog.stageIds.length)
			{
				sid = String(ui.m_catalog.stageIds[i]);
				i++;
				if (sid && MusicStageVisuals.hasStageSelectIcon(sid))
				{
					ids.push(sid);
				};
			};
			ids.push(MusicStageVisuals.TRAINING_GRID_ID);
			ids.push(MusicStageVisuals.WAITING_ROOM_ID);
			ui.m_dialogs.openTilePicker("Stage album art", ids, true, function (sidPick:String):void
			{
				ui.m_catalog.setTrackStageArt(tid, sidPick || "");
				ui.m_transport.refreshNowPlayingMeta();
				ui.m_transport.refreshSpinIcon();
				ui.m_songList.updateSongListBackground(tid);
				ui.paint();
				openTrackSettingsMenu();
			}, function ():void
			{
				beginUploadTrackArt(tid, "stage");
			}, openTrackSettingsMenu, function ():void
			{
				ui.m_catalog.setTrackStageArt(tid, "");
				ui.m_transport.refreshNowPlayingMeta();
				ui.m_transport.refreshSpinIcon();
				ui.m_songList.updateSongListBackground(tid);
				ui.paint();
				openTrackSettingsMenu();
			});
		}

		private function beginUploadTrackArt(tid:String, kind:String):void
		{
			var file:File;
			try
			{
				file = new File();
				file.addEventListener(Event.SELECT, function (e:Event):void
				{
					var src:File;
					var dest:File;
					var dir:File;
					src = e.target as File;
					if (!src || !src.exists)
					{
						openTrackSettingsMenu();
						return;
					};
					try
					{
						dir = File.applicationStorageDirectory.resolvePath("music_player/art");
						if (!dir.exists)
						{
							dir.createDirectory();
						};
						dest = dir.resolvePath(kind + "_" + tid + "_" + src.name);
						src.copyTo(dest, true);
						if (kind == "stage")
						{
							ui.m_catalog.setTrackStageArt(tid, "file:" + dest.nativePath);
						}
						else
						{
							ui.m_catalog.setTrackSymbolKey(tid, "file:" + dest.nativePath);
						};
						ui.m_transport.refreshNowPlayingMeta();
						ui.m_transport.refreshSpinIcon();
						ui.paint();
					}
					catch (copyErr:*)
					{
						trace("[music_player] art upload failed: " + copyErr);
					};
					openTrackSettingsMenu();
				});
				file.addEventListener(Event.CANCEL, function (e:Event):void
				{
					openTrackSettingsMenu();
				});
				file.browseForOpen("Upload " + kind + " art", [
					new FileFilter("Images", "*.png;*.jpg;*.jpeg;*.gif;*.webp")
				]);
			}
			catch (err:*)
			{
				openTrackSettingsMenu();
			};
		}

		internal function isSeriesContext():Boolean
		{
			var cell:Object;
			if (ui.m_tab != MusicPlayerUi.TAB_SERIES)
			{
				return (false);
			};
			if (ui.m_contextId && ui.m_contextId != MusicSeriesResolver.KEY_ALL
				&& ui.m_contextId != MusicSeriesResolver.KEY_OTHER
				&& ui.m_contextId != MusicPlayerUi.NEW_SERIES_HUB)
			{
				return (true);
			};
			if (ui.m_gridIndex < 0 || ui.m_gridIndex >= ui.m_gridCells.length)
			{
				return (false);
			};
			cell = ui.m_gridCells[ui.m_gridIndex];
			return Boolean(cell && cell.kind == "series");
		}

		private function currentSeriesKey():String
		{
			var cell:Object;
			if (ui.m_contextId && ui.m_tab == MusicPlayerUi.TAB_SERIES)
			{
				return (ui.m_contextId);
			};
			if (ui.m_gridIndex >= 0 && ui.m_gridIndex < ui.m_gridCells.length)
			{
				cell = ui.m_gridCells[ui.m_gridIndex];
				if (cell && cell.kind == "series")
				{
					return String(cell.id);
				};
			};
			return (null);
		}

		internal function openSeriesSettingsMenu():void
		{
			var key:String;
			var panel:Sprite;
			var card:Sprite;
			var items:Array;
			var i:int;
			var row:Sprite;
			var tf:TextField;
			var isCustom:Boolean;
			key = currentSeriesKey();
			if (!key)
			{
				return;
			};
			m_seriesSettingsKey = key;
			isCustom = Boolean(MusicOverrides.getCustomSeries(key)
				&& String(key).indexOf("custom:") == 0);
			ui.m_dialogs.dismissBlockingOverlay();
			items = [
				{"label": "Rename series", "key": "rename"},
				{"label": "Change symbol", "key": "symbol"},
				{"label": "Change album art", "key": "art"}
			];
			if (isCustom || MusicOverrides.getCustomSeries(key))
			{
				items.push({"label": "Delete series", "key": "delete"});
			};
			items.push({"label": "Back", "key": "back"});
			panel = new Sprite();
			panel.graphics.beginFill(0x000000, 0.62);
			panel.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			panel.graphics.endFill();
			card = new Sprite();
			card.x = ui.m_gw * 0.5 - 170;
			card.y = Math.max(16, ui.m_gh * 0.5 - 140);
			card.graphics.beginFill(0x121218, 0.98);
			card.graphics.lineStyle(1, MusicTheme.ui(), 0.22);
			card.graphics.drawRoundRect(0, 0, 340, 52 + items.length * 36, 14, 14);
			card.graphics.endFill();
			panel.addChild(card);
			card.addChild(ui.makeText("Series settings", 18, 10, 15, MusicTheme.ui(), true));
			tf = ui.makeText(MusicOverrides.seriesLabel(key) || MusicSeriesResolver.seriesLabel(key) || key,
				18, 30, 11, 0xAAAAAA, false);
			tf.width = 300;
			tf.autoSize = TextFieldAutoSize.NONE;
			card.addChild(tf);
			i = 0;
			while (i < items.length)
			{
				row = new Sprite();
				row.graphics.beginFill(0x1A1A22, 1);
				row.graphics.drawRoundRect(0, 0, 304, 30, 8, 8);
				row.graphics.endFill();
				row.x = 18;
				row.y = 52 + i * 36;
				row.buttonMode = true;
				row.addChild(ui.makeText(String(items[i].label), 12, 6, 13, MusicTheme.ui(), false));
				row.addEventListener(MouseEvent.CLICK, (function (k:String):Function
				{
					return function (e:MouseEvent):void
					{
						e.stopPropagation();
						runSeriesSettingAction(k);
					};
				})(String(items[i].key)));
				card.addChild(row);
				i++;
			};
			ui.m_blockingOverlay = panel;
			ui.m_modalKind = "seriesSettings";
			ui.m_modalItems = items;
			ui.m_modalIndex = 0;
			ui.m_modalOnConfirm = function ():void
			{
				if (ui.m_modalItems && ui.m_modalIndex >= 0 && ui.m_modalIndex < ui.m_modalItems.length)
				{
					runSeriesSettingAction(String(ui.m_modalItems[ui.m_modalIndex].key));
				};
			};
			ui.m_modalOnBack = ui.m_dialogs.dismissBlockingOverlay;
			ui.addChild(panel);
			ui.m_dialogs.highlightModalRows(card, 52, 36, 304, 30);
			ui.m_modalRefresh = function ():void
			{
				ui.m_dialogs.highlightModalRows(card, 52, 36, 304, 30);
			};
		}

		private function runSeriesSettingAction(action:String):void
		{
			var key:String;
			var ids:Array;
			var i:int;
			var sid:String;
			key = m_seriesSettingsKey;
			if (action == "back" || !key)
			{
				ui.m_dialogs.dismissBlockingOverlay();
				return;
			};
			ui.m_dialogs.dismissBlockingOverlay();
			if (action == "rename")
			{
				ui.m_grid.beginRenameSeries(key);
				return;
			};
			if (action == "delete")
			{
				ui.m_dialogs.openTextPrompt("Type DELETE to remove series", "", function (value:String):void
				{
					if (String(value).toUpperCase() != "DELETE")
					{
						openSeriesSettingsMenu();
						return;
					};
					MusicOverrides.removeCustomSeries(key);
					MusicSeriesResolver.invalidate();
					ui.m_tileArtCache = {};
					ui.m_songs.exitSongs();
				}, openSeriesSettingsMenu);
				return;
			};
			if (action == "symbol")
			{
				ui.m_dialogs.openFilterListPicker("Series symbol", MusicSeriesResolver.allSymbolKeys(),
					function (k:String):String
					{
						return MusicSeriesResolver.seriesLabel(k) || k;
					},
					function (k:String, row:Sprite):void
					{
						var host:Sprite;
						host = new Sprite();
						host.x = 18;
						host.y = 14;
						host.mouseEnabled = false;
						MusicSeriesResolver.attachIcon(host, k, 22, true);
						row.addChild(host);
					},
					function (picked:String):void
					{
						MusicOverrides.setCustomSeriesFields(key, {"symbolKey": picked || ""});
						ui.m_tileArtCache = {};
						MusicSeriesResolver.invalidate();
						ui.m_grid.rebuildGrid();
						ui.paint();
						openSeriesSettingsMenu();
					}, openSeriesSettingsMenu, function ():void
					{
						MusicOverrides.setCustomSeriesFields(key, {"symbolKey": ""});
						ui.m_tileArtCache = {};
						ui.m_grid.rebuildGrid();
						ui.paint();
						openSeriesSettingsMenu();
					});
				return;
			};
			if (action == "art")
			{
				ids = [];
				i = 0;
				while (ui.m_catalog && i < ui.m_catalog.stageIds.length)
				{
					sid = String(ui.m_catalog.stageIds[i]);
					i++;
					if (sid && MusicStageVisuals.hasStageSelectIcon(sid))
					{
						ids.push(sid);
					};
				};
				ui.m_dialogs.openTilePicker("Series album art", ids, true, function (sidPick:String):void
				{
					MusicOverrides.setCustomSeriesFields(key, {"stageArt": sidPick || ""});
					ui.m_tileArtCache = {};
					ui.m_grid.rebuildGrid();
					ui.paint();
					openSeriesSettingsMenu();
				}, function ():void
				{
					openSeriesSettingsMenu();
				}, openSeriesSettingsMenu, function ():void
				{
					MusicOverrides.setCustomSeriesFields(key, {"stageArt": ""});
					ui.m_tileArtCache = {};
					ui.m_grid.rebuildGrid();
					ui.paint();
					openSeriesSettingsMenu();
				});
			};
		}

		internal function openLoopPrompt(tid:String):void
		{
			var current:String;
			var ms:Number;
			ms = ui.m_catalog ? ui.m_catalog.effectiveLoopMs(tid) : 0;
			current = String(int(Math.max(0, Math.round(ms))));
			ui.m_dialogs.openTextPrompt("Loop point (milliseconds)", current, function (value:String):void
			{
				var n:Number;
				n = Number(value);
				if (isNaN(n) || n < 0)
				{
					n = 0;
				};
				if (ui.m_catalog)
				{
					ui.m_catalog.setLoopMs(tid, n);
				};
				ui.m_listMode = null;
				ui.paint();
				openTrackSettingsMenu();
			}, openTrackSettingsMenu);
		}
	}
}
