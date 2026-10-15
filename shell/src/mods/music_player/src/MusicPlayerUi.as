package
{
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import ssf2mm.shared.LucideIcons;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Ultimate-style Music hub: By Stage (My Music) / By Series / Playlists grids,
	 * song lists, and YouTube-style now-playing bar.
	 */
	public class MusicPlayerUi extends Sprite
	{
		internal static const TAB_STAGE:int = 0;
		internal static const TAB_SERIES:int = 1;
		internal static const TAB_PLAYLIST:int = 2;
		internal static const TAB_SEARCH:int = 3;
		internal static const VIEW_GRID:int = 0;
		internal static const VIEW_SONGS:int = 1;
		internal static const NEW_SERIES_HUB:String = "__new_series__";
		internal static const ADD_SONGS:String = "albumSongs";
		internal static const ADD_PENDING:String = "added";
		internal static const CELL:int = 86;
		internal static const GAP:int = 15;
		internal static const COLS:int = 6;
		internal static const LABEL_H:int = 18;

		internal var m_host:*;
		internal var m_catalog:MusicCatalog;
		internal var m_onlineMode:Boolean;
		internal var m_store:MusicPlaylistStore;
		internal var m_open:Boolean;
		/** True when JukeboxMenu owns the display list (not a root overlay). */
		private var m_hosted:Boolean;
		internal var m_tab:int;
		internal var m_view:int;
		internal var m_matchPick:Boolean;
		private var m_deepLink:String;
		internal var m_onPick:Function;
		private var m_onClose:Function;
		internal var m_editMode:Boolean;

		internal var m_gw:int = 853;
		internal var m_gh:int = 480;
		internal var m_listBottom:int;

		internal var m_bgLayer:Sprite;
		internal var m_uiLayer:Sprite;
		internal var m_gridLayer:Sprite;
		internal var m_listLayer:Sprite;
		internal var m_npBar:MusicNowPlayingBar;

		internal var m_title:TextField;
		private var m_tabs:TextField;
		private var m_tabHits:Sprite;
		internal var m_scrollBar:Sprite;
		internal var m_scrollThumb:Sprite;
		internal var m_actionBar:Sprite;
		internal var m_listMode:String;
		internal var m_pending:Object;
		internal var m_addPool:Array;
		internal var m_searchInput:TextField;
		internal var m_searchQuery:String;
		internal var m_searchRow:Sprite;
		internal var m_backBtn:TextField;
		internal var m_backArrow:Sprite;
		private var m_backHit:Sprite;
		private var m_helpBtn:Sprite;
		internal var m_helpOverlay:Sprite;
		internal var m_rows:Array;
		internal var m_gridCells:Array;
		internal var m_gridIndex:int;
		internal var m_gridScroll:int;
		internal var m_songIds:Array;
		internal var m_songIndex:int;
		internal var m_songScroll:int;
		internal var m_contextId:String;
		internal var m_previewStageId:String;
		internal var m_settingsOverlay:Sprite;
		internal var m_blockingOverlay:Sprite;
		internal var m_modalKind:String;
		internal var m_modalItems:Array;
		internal var m_modalIndex:int;
		internal var m_modalOnConfirm:Function;
		internal var m_modalOnBack:Function;
		/** Refresh selection highlight / list when m_modalIndex changes. */
		internal var m_modalRefresh:Function;
		internal var m_helpTf:TextField;
		internal var m_addSubView:String;
		internal var m_stageGridMode:String;
		internal var m_npNavCell:Object;
		internal var m_addTargetCell:Object;

		internal var m_holdAge:int;
		internal var m_holdDir:int;
		internal var m_releaseHoldoff:Boolean;
		private var m_suspendedMenus:Array;
		internal var m_freqBar:Sprite;
		internal var m_queue:Array;
		internal var m_playback:*;
		internal var m_lastSpinTrackId:String;
		/** Cached tile art (attachSeriesTile + badge) keyed by kind:id. */
		internal var m_tileArtCache:Object;

		internal var m_scroll:MusicUiScroll;
		internal var m_search:MusicUiSearch;
		internal var m_dialogs:MusicUiDialogs;
		internal var m_trackSettings:MusicUiTrackSettings;
		internal var m_theme:MusicUiTheme;
		internal var m_onlineView:MusicUiOnline;
		internal var m_grid:MusicUiGrid;
		internal var m_songs:MusicUiSongs;
		internal var m_songList:MusicUiSongList;
		internal var m_edit:MusicUiPlaylistEdit;
		internal var m_input:MusicUiInput;
		internal var m_transport:MusicUiTransport;

		public function MusicPlayerUi(host:*, catalog:MusicCatalog, store:MusicPlaylistStore)
		{
			super();
			m_scroll = new MusicUiScroll(this);
			m_search = new MusicUiSearch(this);
			m_dialogs = new MusicUiDialogs(this);
			m_trackSettings = new MusicUiTrackSettings(this);
			m_theme = new MusicUiTheme(this);
			m_onlineView = new MusicUiOnline(this);
			m_grid = new MusicUiGrid(this);
			m_songs = new MusicUiSongs(this);
			m_songList = new MusicUiSongList(this);
			m_edit = new MusicUiPlaylistEdit(this);
			m_input = new MusicUiInput(this);
			m_transport = new MusicUiTransport(this);
			m_host = host;
			m_catalog = catalog;
			m_store = store;
			m_open = false;
			m_hosted = false;
			m_rows = [];
			m_gridCells = [];
			m_songIds = [];
			m_queue = [];
			m_suspendedMenus = [];
			m_playback = null;
			m_listMode = null;
			m_addPool = [];
			m_actionBar = null;
			m_searchInput = null;
			m_searchQuery = "";
			m_searchRow = null;
			m_addSubView = null;
			m_addTargetCell = null;
			m_lastSpinTrackId = null;
			m_stageGridMode = null;
			m_npNavCell = null;
			m_tileArtCache = {};
		}

		/** Optional playback controller from MusicPlayerMod: play/pause/prev/next/state. */
		public function setPlaybackController(ctl:*):void
		{
			m_playback = ctl;
		}

		public function isOpen():Boolean
		{
			return (m_open);
		}

		public function showPlaylistTab():void
		{
			selectTab(TAB_PLAYLIST);
		}

		public function open(deepLinkStageId:String, matchPick:Boolean, onPick:Function, onClose:Function,
			hostParent:* = null):void
		{
			var root:*;
			if (m_open)
			{
				return;
			};
			m_onPick = onPick;
			m_onClose = onClose;
			m_matchPick = matchPick;
			m_deepLink = deepLinkStageId;
			m_editMode = false;
			m_listMode = null;
			m_addSubView = null;
			m_addTargetCell = null;
			m_tab = TAB_STAGE;
			m_view = VIEW_GRID;
			m_gridIndex = 0;
			m_gridScroll = 0;
			m_songIndex = 0;
			m_songScroll = 0;
			m_holdAge = 0;
			m_holdDir = 0;
			m_contextId = null;
			m_lastSpinTrackId = null;
			m_hosted = hostParent != null;
			root = hostParent ? hostParent : resolveGameRoot();
			if (!root)
			{
				return;
			};
			refreshGameSize();
			m_listBottom = m_gh - MusicNowPlayingBar.BAR_H - 12;
			m_open = true;
			m_releaseHoldoff = false;
			m_input.blockInput(true);
			if (!m_hosted)
			{
				suspendUnderlyingMenus();
			};
			MusicSeriesResolver.invalidate();
			MusicSeriesResolver.ensureBuilt(m_catalog.stageIds);
			MusicSongLibrary.syncUploads(m_catalog, m_edit.onFoldersChanged);
			MusicSongLibrary.syncLegacy(m_catalog);
			if (m_playback && m_playback.registerFolders is Function)
			{
				m_playback.registerFolders();
			};
			buildChrome();
			root.addChild(this);
			root.addEventListener(Event.ENTER_FRAME, m_input.onFrame);
			if (m_host && m_host.addKeyListener)
			{
				m_host.addKeyListener(m_input.onKey);
			};
			if (m_deepLink)
			{
				openStageSongs(m_deepLink);
			}
			else
			{
				m_grid.rebuildGrid();
				m_transport.refreshPreviewBg(null);
				paint();
			};
			// Disc art from playing song after open sync — not browse context.
			m_transport.refreshSpinIcon();
			m_theme.applyChromeTheme();
			if (m_catalog && m_host)
			{
				m_catalog.startPackMetaCache(m_host);
			};
			// Stage Select GRAB opens this UI — do not treat that same press as Next.
			m_input.seedPrevKeys();
		}

		public function close():void
		{
			var root:*;
			if (!m_open)
			{
				return;
			};
			m_scroll.endScrollDrag();
			m_search.clearSearchField();
			m_open = false;
			root = parent;
			if (root)
			{
				root.removeEventListener(Event.ENTER_FRAME, m_input.onFrame);
			};
			try
			{
				removeEventListener(MouseEvent.MOUSE_WHEEL, m_scroll.onWheel);
			}
			catch (wheelErr:*)
			{
			};
			if (m_helpOverlay && m_helpOverlay.parent)
			{
				m_helpOverlay.parent.removeChild(m_helpOverlay);
				m_helpOverlay = null;
			};
			if (m_host && m_host.removeKeyListener)
			{
				try
				{
					m_host.removeKeyListener(m_input.onKey);
				}
				catch (err:*)
				{
				};
			};
			if (parent)
			{
				parent.removeChild(this);
			};
			m_grid.invalidateGridCaches();
			MusicStageVisuals.clearPreviewBitmaps();
			if (m_bgLayer)
			{
				while (m_bgLayer.numChildren > 0)
				{
					m_bgLayer.removeChildAt(0);
				};
			};
			if (!m_hosted)
			{
				resumeUnderlyingMenus();
			};
			m_hosted = false;
			m_releaseHoldoff = true;
			root = resolveGameRoot();
			if (root)
			{
				root.addEventListener(Event.ENTER_FRAME, m_input.onHoldoffFrame);
			}
			else
			{
				m_input.blockInput(false);
				m_releaseHoldoff = false;
			};
			if (m_onClose != null)
			{
				m_onClose();
			};
		}

		private function buildChrome():void
		{
			while (numChildren > 0)
			{
				removeChildAt(0);
			};
			mouseEnabled = true;
			mouseChildren = true;
			m_bgLayer = new Sprite();
			m_uiLayer = new Sprite();
			m_gridLayer = new Sprite();
			m_listLayer = new Sprite();
			m_gridLayer.mouseEnabled = true;
			m_gridLayer.mouseChildren = true;
			m_listLayer.mouseEnabled = true;
			m_listLayer.mouseChildren = true;
			addChild(m_bgLayer);
			addChild(m_uiLayer);
			addChild(m_gridLayer);
			addChild(m_listLayer);
			m_title = makeText("My Jukebox", 24, 12, 22, MusicTheme.ui(), true);
			m_tabs = makeText("", 24, 42, 13, MusicTheme.uiSoft(), false);
			m_tabs.width = m_gw - 48;
			m_tabHits = new Sprite();
			m_uiLayer.addChild(m_tabHits);
			buildTabHits();
			m_helpBtn = buildHelpButton();
			m_uiLayer.addChild(m_helpBtn);
			m_backBtn = makeText("Close", 0, 14, 13, MusicTheme.ui(), false);
			m_backBtn.mouseEnabled = false;
			m_backArrow = drawBackArrow(0, 18);
			m_uiLayer.addChild(m_backArrow);
			m_backHit = new Sprite();
			m_backHit.graphics.beginFill(0xFFFFFF, 0.001);
			m_backHit.graphics.drawRect(0, 0, 100, 28);
			m_backHit.graphics.endFill();
			m_backHit.buttonMode = true;
			m_backHit.useHandCursor = true;
			m_backHit.addEventListener(MouseEvent.CLICK, onBackClick);
			m_uiLayer.addChild(m_backHit);
			layoutCloseControl();
			m_freqBar = new Sprite();
			m_freqBar.x = 36;
			m_freqBar.y = m_listBottom - 28;
			m_uiLayer.addChild(m_backBtn);
			m_uiLayer.addChild(m_title);
			m_uiLayer.addChild(m_tabs);
			m_uiLayer.addChild(m_freqBar);
			// Tabs must stay above title/labels for mouse hits.
			m_uiLayer.setChildIndex(m_tabHits, m_uiLayer.numChildren - 1);
			m_npBar = new MusicNowPlayingBar();
			m_npBar.layout(m_gw, m_gh);
			m_npBar.setCallbacks(m_transport.onNpPrev, m_transport.onNpPlay, m_transport.onNpNext, m_transport.onNpExpand);
			m_npBar.setRepeatCallback(m_transport.onNpRepeat);
			m_npBar.setSeekCallback(m_transport.onNpSeek);
			m_npBar.setSettingsCallback(m_transport.onNpSettings);
			m_npBar.setVolumeCallback(m_transport.onNpVolume);
			m_npBar.setMetaNavigateCallbacks(m_transport.onNpStageClick, m_transport.onNpSeriesClick);
			m_npBar.setTitleNavigateCallback(m_transport.onNpTitleClick);
			if (m_playback && m_playback.getRepeatOne is Function)
			{
				m_npBar.setRepeatOne(Boolean(m_playback.getRepeatOne()));
			};
			if (m_playback && m_playback.getShuffle is Function)
			{
				m_npBar.setShuffle(Boolean(m_playback.getShuffle()));
			};
			addChild(m_npBar);
			m_scroll.ensureScrollBar();
			addChild(m_scrollBar);
			m_helpOverlay = null;
			m_rows = [];
			addEventListener(MouseEvent.MOUSE_WHEEL, m_scroll.onWheel);
			m_transport.refreshSpaceBg();
		}

		internal function safeBringToFront(child:DisplayObject):void
		{
			if (!child || child.parent != this || numChildren < 1)
			{
				return;
			};
			try
			{
				setChildIndex(child, numChildren - 1);
			}
			catch (err:*)
			{
			};
		}

		private function buildHelpButton():Sprite
		{
			var btn:Sprite;
			btn = new Sprite();
			btn.x = m_gw - 44;
			btn.y = 10;
			m_helpTf = new TextField();
			m_helpTf.autoSize = TextFieldAutoSize.LEFT;
			m_helpTf.selectable = false;
			m_helpTf.mouseEnabled = false;
			m_helpTf.defaultTextFormat = new TextFormat("_sans", 20, MusicTheme.ui(), true);
			m_helpTf.text = "?";
			m_helpTf.x = 6;
			m_helpTf.y = 0;
			btn.addChild(m_helpTf);
			btn.graphics.beginFill(0xFFFFFF, 0.001);
			btn.graphics.drawRect(0, 0, 28, 28);
			btn.graphics.endFill();
			btn.buttonMode = true;
			btn.useHandCursor = true;
			btn.addEventListener(MouseEvent.CLICK, onHelpClick);
			return (btn);
		}

		internal function buildTabHits():void
		{
			var labels:Array;
			var i:int;
			var x0:int;
			var hit:Sprite;
			var tf:TextField;
			var tabIndex:int;
			var w:Number;
			while (m_tabHits && m_tabHits.numChildren > 0)
			{
				m_tabHits.removeChildAt(0);
			};
			if (!m_tabHits)
			{
				return;
			};
			labels = ["By Stage", "By Series", "Playlists", "Search"];
			x0 = 24;
			i = 0;
			while (i < 4)
			{
				tabIndex = i;
				hit = new Sprite();
				hit.x = x0;
				hit.y = 40;
				tf = new TextField();
				tf.autoSize = TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.mouseEnabled = false;
				tf.defaultTextFormat = new TextFormat("_sans", 13,
					i == m_tab ? MusicTheme.select() : MusicTheme.uiSoft(), i == m_tab);
				tf.text = i == m_tab ? ("[" + labels[i] + "]") : labels[i];
				hit.addChild(tf);
				w = Math.max(70, tf.textWidth + 16);
				hit.graphics.beginFill(0xFFFFFF, 0.001);
				hit.graphics.drawRect(-4, -2, w, 22);
				hit.graphics.endFill();
				hit.buttonMode = true;
				hit.useHandCursor = true;
				hit.addEventListener(MouseEvent.CLICK, (function (idx:int):Function
				{
					return function (e:MouseEvent):void
					{
						e.stopPropagation();
						selectTab(idx);
					};
				})(tabIndex));
				m_tabHits.addChild(hit);
				x0 += int(w) + 18;
				i++;
			};
			if (m_tabs)
			{
				m_tabs.visible = false;
			};
			m_search.ensureSearchRow();
			if (m_searchRow)
			{
				m_searchRow.visible = m_tab == TAB_SEARCH;
				m_searchRow.x = 24;
				m_searchRow.y = 64;
			};
		}

		internal function selectTab(idx:int):void
		{
			var keepAdd:Boolean;
			keepAdd = m_listMode == "add"
				&& (idx == TAB_STAGE || idx == TAB_SERIES || idx == TAB_SEARCH);
			if (m_tab == idx && m_view == VIEW_GRID && idx != TAB_SEARCH && !keepAdd)
			{
				return;
			};
			if (m_tab != idx || m_view != VIEW_GRID || idx == TAB_SEARCH)
			{
				playUiSfx("menu_select");
			};
			m_tab = idx;
			if (!keepAdd)
			{
				m_listMode = null;
				m_addSubView = null;
				m_addTargetCell = null;
			};
			m_editMode = false;
			m_stageGridMode = null;
			if (idx == TAB_SEARCH)
			{
				m_view = VIEW_SONGS;
				m_contextId = "__search__";
				m_gridCells = [{"id": "__search__", "kind": "search", "label": "Search"}];
				m_gridIndex = 0;
				m_search.ensureSearchRow();
				m_search.runSearchLive(m_searchQuery || "");
				if (m_searchInput && stage)
				{
					try
					{
						stage.focus = m_searchInput;
					}
					catch (focusErr:*)
					{
					};
				};
				return;
			};
			m_search.clearSearchField();
			m_view = VIEW_GRID;
			m_gridIndex = 0;
			m_gridScroll = 0;
			m_grid.rebuildGrid();
			m_transport.refreshPreviewBg(null);
			paint();
		}

		private function onBackClick(e:MouseEvent):void
		{
			e.stopPropagation();
			playUiSfx("menu_back");
			if (m_listMode == "add")
			{
				m_edit.backFromAddMode();
				return;
			};
			if (m_view == VIEW_SONGS)
			{
				if (m_editMode)
				{
					m_editMode = false;
					paint();
				}
				else if (m_tab == TAB_SEARCH)
				{
					selectTab(TAB_STAGE);
				}
				else
				{
					m_songs.exitSongs();
				};
			}
			else if (m_view == VIEW_GRID && m_listMode == "add")
			{
				m_edit.backFromAddMode();
			}
			else if (m_view == VIEW_GRID && (m_stageGridMode == "other_stages"
				|| m_stageGridMode == "expansion_stages"))
			{
				m_stageGridMode = null;
				m_gridIndex = 0;
				m_gridScroll = 0;
				m_grid.rebuildGrid();
				m_transport.refreshPreviewBg(null);
				paint();
			}
			else
			{
				close();
			};
		}

		private function onHelpClick(e:MouseEvent):void
		{
			e.stopPropagation();
			playUiSfx("menu_select");
			toggleHelp();
		}

		private function toggleHelp():void
		{
			var tip:Function;
			if (m_helpOverlay && m_helpOverlay.parent)
			{
				m_helpOverlay.parent.removeChild(m_helpOverlay);
				m_helpOverlay = null;
				return;
			};
			m_helpOverlay = new Sprite();
			m_helpOverlay.graphics.beginFill(0x000000, 0.55);
			m_helpOverlay.graphics.drawRect(0, 0, m_gw, m_gh);
			m_helpOverlay.graphics.endFill();
			tip = function (label:String, x:Number, y:Number):void
			{
				var tf:TextField;
				var box:Sprite;
				box = new Sprite();
				box.graphics.beginFill(0x16161E, 0.95);
				box.graphics.lineStyle(1, MusicTheme.ui(), 0.85);
				box.graphics.drawRoundRect(0, 0, Math.max(70, label.length * 7.2), 22, 6, 6);
				box.graphics.endFill();
				box.x = x;
				box.y = y;
				tf = makeText(label, 6, 2, 11, MusicTheme.ui(), true);
				box.addChild(tf);
				m_helpOverlay.addChild(box);
			};
			// Header
			tip("Back · Special", Math.max(8, m_gw - 168), 8);
			tip("Tabs · Taunt", m_gw * 0.5 - 48, 8);
			tip("Select · Attack", 24, 68);
			// Single clean row above the miniplayer — no stacked bottom-left pile
			var yBar:Number = m_gh - MusicNowPlayingBar.BAR_H - 26;
			tip("Prev · Shield", 8, yBar);
			tip("Play/Pause · Jump", 108, yBar);
			tip("Next · Grab", 248, yBar);
			tip("Loop · Start", 358, yBar);
			tip("Settings · Taunt+Shield", Math.max(8, m_gw - 340), yBar);
			tip("Expand · Taunt+Grab", Math.max(8, m_gw - 160), yBar);
			m_helpOverlay.buttonMode = true;
			m_helpOverlay.addEventListener(MouseEvent.CLICK, function (ev:MouseEvent):void
			{
				toggleHelp();
			});
			addChild(m_helpOverlay);
		}

		/** Called after boot-time stage song warm so tile badges populate immediately. */
		public function onCatalogReady():void
		{
			var cell:Object;
			var i:int;
			if (!m_open)
			{
				return;
			};
			if (m_tab == TAB_SEARCH)
			{
				// Keep the typed query — rebuildGrid used to swap in Uploaded Songs.
				m_search.runSearchLive(m_searchQuery || (m_searchInput ? m_searchInput.text : ""));
				return;
			};
			m_grid.rebuildGrid();
			if (m_view == VIEW_SONGS && m_contextId)
			{
				cell = null;
				i = 0;
				while (i < m_gridCells.length)
				{
					if (String(m_gridCells[i].id) == m_contextId)
					{
						cell = m_gridCells[i];
						m_gridIndex = i;
						break;
					};
					i++;
				};
				if (!cell)
				{
					cell = {"id": m_contextId, "kind": m_tab == TAB_SERIES ? "series" : "stage"};
				};
				m_songIds = m_songs.songsForContext(cell);
				m_queue = m_songIds.concat();
				m_songs.selectNowPlayingInList();
				m_songs.syncPlaybackQueue();
				m_songs.hydrateSongs(m_songIds);
			};
			paint();
		}

		internal function openStageSongs(stageId:String):void
		{
			var i:int;
			m_tab = TAB_STAGE;
			m_grid.rebuildGrid();
			i = 0;
			while (i < m_gridCells.length)
			{
				if (m_gridCells[i].id == stageId)
				{
					m_gridIndex = i;
					break;
				};
				i++;
			};
			m_songs.enterSongsFromGrid();
		}

		internal function currentTrackId():String
		{
			var st:Object;
			var tid:String;
			tid = null;
			try
			{
				if (m_playback && m_playback.getState is Function)
				{
					st = m_playback.getState();
					if (st && st.trackId)
					{
						tid = String(st.trackId);
					};
				};
				if (!tid && m_host && m_host.getSessionFlag is Function)
				{
					tid = String(m_host.getSessionFlag("music_player.now_id") || "");
				};
			}
			catch (err:*)
			{
			};
			return (tid && tid.length > 0 ? tid : null);
		}

		internal function paint():void
		{
			if (m_npBar && m_npBar.expanded)
			{
				return;
			};
			m_songList.clearRows();
			updateTabLabel();
			if (m_backBtn)
			{
				m_backBtn.visible = true;
				m_backBtn.text = (m_view == VIEW_SONGS || m_listMode == "add") ? "Back" : "Close";
				layoutCloseControl();
			};
			if (m_view == VIEW_GRID)
			{
				m_gridLayer.visible = true;
				m_listLayer.visible = false;
				m_songList.hideActionBar();
				m_grid.paintGrid();
			}
			else
			{
				m_gridLayer.visible = false;
				m_listLayer.visible = true;
				m_songList.paintSongs();
				m_songList.hideActionBar();
			};
			m_transport.refreshNowPlayingMeta();
			if (m_tab == TAB_SEARCH)
			{
				m_search.ensureSearchRow();
				if (m_searchRow)
				{
					m_searchRow.visible = true;
					if (m_searchRow.parent == this)
					{
						setChildIndex(m_searchRow, numChildren - 1);
					};
				};
			};
		}

		private function updateTabLabel():void
		{
			buildTabHits();
			if (m_tab == TAB_SEARCH)
			{
				m_title.text = m_searchQuery ? ("Search: " + m_searchQuery) : "Search";
			}
			else if (m_listMode == "add")
			{
				m_title.text = "Add Songs to " + m_edit.addTargetLabel();
			}
			else if (m_view == VIEW_SONGS && m_listMode == "add" && m_addSubView == ADD_PENDING)
			{
				m_title.text = "Added Songs (" + m_songList.pendingCount() + ")";
			}
			else if (m_view == VIEW_SONGS && m_gridIndex >= 0 && m_gridIndex < m_gridCells.length)
			{
				m_title.text = String(m_gridCells[m_gridIndex].label);
			}
			else
			{
				m_title.text = "My Jukebox";
			};
		}

		/** Close/Back sits to the left of the ? button (right side of the header). */
		private function layoutCloseControl():void
		{
			var right:Number;
			var labelW:Number;
			right = m_gw - 52;
			if (m_helpBtn)
			{
				m_helpBtn.x = m_gw - 44;
				m_helpBtn.y = 10;
			};
			labelW = m_backBtn ? m_backBtn.textWidth + 4 : 40;
			if (m_backBtn)
			{
				m_backBtn.x = right - labelW;
				m_backBtn.y = 14;
			};
			if (m_backArrow)
			{
				m_backArrow.x = right - labelW - 18;
				m_backArrow.y = 12;
			};
			if (m_backHit)
			{
				m_backHit.x = right - labelW - 20;
				m_backHit.y = 8;
				m_backHit.graphics.clear();
				m_backHit.graphics.beginFill(0xFFFFFF, 0.001);
				m_backHit.graphics.drawRect(0, 0, labelW + 24, 28);
				m_backHit.graphics.endFill();
			};
		}

		internal function playUiSfx(id:String):void
		{
			var SQ:*;
			try
			{
				SQ = EngineRefs.ssf2("audio.SoundQueue");
				if (SQ && SQ.instance && SQ.instance.playSoundEffect)
				{
					SQ.instance.playSoundEffect(id);
				};
			}
			catch (err:*)
			{
			};
		}

		private function drawBackArrow(x:Number, y:Number):Sprite
		{
			var s:Sprite;
			s = new Sprite();
			s.x = x;
			s.y = y;
			s.mouseEnabled = false;
			LucideIcons.draw(s.graphics, LucideIcons.ARROW_LEFT, 20, MusicTheme.ui(), 2);
			return (s);
		}

		internal function makeText(text:String, x:int, y:int, size:int, color:uint, bold:Boolean):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.x = x;
			tf.y = y;
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", size, color, bold);
			tf.text = text;
			return (tf);
		}

		private function suspendUnderlyingMenus():void
		{
			var menus:Array;
			var i:int;
			var menu:*;
			m_suspendedMenus = [];
			menus = MusicLiveMenus.onscreen();
			i = 0;
			while (i < menus.length)
			{
				menu = menus[i];
				i++;
				if (!menu)
				{
					continue;
				};
				try
				{
					if (menu["killEvents"] is Function)
					{
						menu["killEvents"]();
						m_suspendedMenus.push(menu);
					};
				}
				catch (oneErr:*)
				{
				};
			};
		}

		private function resumeUnderlyingMenus():void
		{
			var i:int;
			var menu:*;
			i = 0;
			while (i < m_suspendedMenus.length)
			{
				menu = m_suspendedMenus[i];
				i++;
				try
				{
					if (menu && menu["isOnscreen"] is Function && Boolean(menu["isOnscreen"]())
						&& menu["makeEvents"] is Function)
					{
						menu["makeEvents"]();
					};
				}
				catch (err:*)
				{
				};
			};
			m_suspendedMenus = [];
		}

		internal function resolveGameRoot():*
		{
			var MainCls:Class;
			try
			{
				MainCls = EngineRefs.ssf2("Main") as Class;
				if (MainCls && MainCls["Root"])
				{
					return (MainCls["Root"]);
				};
			}
			catch (err:*)
			{
			};
			try
			{
				if (m_host && m_host.stage)
				{
					return (m_host.stage);
				};
			}
			catch (err2:*)
			{
			};
			return (null);
		}

		private function refreshGameSize():void
		{
			var MainCls:Class;
			m_gw = 853;
			m_gh = 480;
			try
			{
				MainCls = EngineRefs.ssf2("Main") as Class;
				if (MainCls)
				{
					if (MainCls["Width"])
					{
						m_gw = int(MainCls["Width"]);
					};
					if (MainCls["Height"])
					{
						m_gh = int(MainCls["Height"]);
					};
				};
			}
			catch (err:*)
			{
			};
		}
	}
}
