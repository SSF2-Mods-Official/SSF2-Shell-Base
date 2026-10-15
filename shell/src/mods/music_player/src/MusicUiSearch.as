package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;

	/**
	 * Search tab: input row and live results.
	 */
	public class MusicUiSearch
	{
		private var ui:MusicPlayerUi;

		public function MusicUiSearch(owner:MusicPlayerUi)
		{
			ui = owner;
		}

		internal function ensureSearchRow():void
		{
			if (!ui.m_searchRow)
			{
				ui.m_searchRow = new Sprite();
				ui.m_searchRow.graphics.beginFill(0x16161E, 0.98);
				ui.m_searchRow.graphics.lineStyle(1, MusicTheme.select(), 0.9);
				ui.m_searchRow.graphics.drawRoundRect(0, 0, Math.max(200, ui.m_gw - 48), 28, 6, 6);
				ui.m_searchRow.graphics.endFill();
				ui.m_searchInput = new TextField();
				ui.m_searchInput.type = TextFieldType.INPUT;
				ui.m_searchInput.border = false;
				ui.m_searchInput.background = true;
				ui.m_searchInput.backgroundColor = 0x16161E;
				ui.m_searchInput.textColor = MusicTheme.ui();
				ui.m_searchInput.defaultTextFormat = new TextFormat("_sans", 13, MusicTheme.ui());
				ui.m_searchInput.x = 10;
				ui.m_searchInput.y = 4;
				ui.m_searchInput.width = Math.max(180, ui.m_gw - 68);
				ui.m_searchInput.height = 22;
				ui.m_searchInput.selectable = true;
				ui.m_searchInput.mouseEnabled = true;
				ui.m_searchInput.addEventListener(Event.CHANGE, onSearchInputChange);
				ui.m_searchInput.addEventListener(KeyboardEvent.KEY_DOWN, onSearchKey);
				ui.m_searchRow.addChild(ui.m_searchInput);
			};
			if (ui.m_searchRow.parent != ui)
			{
				ui.addChild(ui.m_searchRow);
			};
			ui.m_searchRow.x = 24;
			ui.m_searchRow.y = 64;
			ui.m_searchRow.visible = ui.m_tab == MusicPlayerUi.TAB_SEARCH;
			ui.m_searchRow.mouseEnabled = true;
			ui.m_searchRow.mouseChildren = true;
			if (ui.m_searchInput)
			{
				ui.m_searchInput.width = Math.max(180, ui.m_gw - 68);
				ui.m_searchInput.text = ui.m_searchQuery || "";
			};
			ui.setChildIndex(ui.m_searchRow, ui.numChildren - 1);
		}

		private function onSearchInputChange(e:Event):void
		{
			runSearchLive(ui.m_searchInput ? ui.m_searchInput.text : "");
		}

		private function onSearchKey(e:KeyboardEvent):void
		{
			if (e.keyCode == 27)
			{
				e.stopPropagation();
				ui.selectTab(MusicPlayerUi.TAB_STAGE);
			};
		}

		internal function clearSearchField():void
		{
			if (ui.m_searchRow)
			{
				ui.m_searchRow.visible = false;
			};
			try
			{
				if (ui.stage)
				{
					ui.stage.focus = null;
				};
			}
			catch (err:*)
			{
			};
		}

		internal function runSearchLive(query:String):void
		{
			var q:String;
			var ids:Array;
			var i:int;
			var tid:String;
			var title:String;
			var artist:String;
			var hit:Array;
			var keepAdd:Boolean;
			var have:Object;
			var list:Array;
			keepAdd = ui.m_listMode == "add";
			q = query ? String(query).toLowerCase() : "";
			while (q.length > 0 && (q.charAt(0) == " " || q.charAt(0) == "\t"))
			{
				q = q.substring(1);
			};
			while (q.length > 0 && (q.charAt(q.length - 1) == " " || q.charAt(q.length - 1) == "\t"))
			{
				q = q.substring(0, q.length - 1);
			};
			ui.m_searchQuery = query || "";
			have = {};
			if (keepAdd && ui.m_addTargetCell)
			{
				list = ui.m_songs.songsForContext(ui.m_addTargetCell);
				i = 0;
				while (list && i < list.length)
				{
					have[MusicPacks.canonicalTrackId(String(list[i]))] = true;
					i++;
				};
			};
			hit = [];
			if (q.length > 0)
			{
				ids = ui.m_catalog ? ui.m_catalog.allTrackIds() : [];
				i = 0;
				while (i < ids.length)
				{
					tid = MusicPacks.canonicalTrackId(String(ids[i]));
					i++;
					if (!tid || have[tid])
					{
						continue;
					};
					title = ui.m_catalog.songTitleOrPlaceholder(tid).toLowerCase();
					artist = "";
					if (ui.m_catalog.songMeta[tid] && ui.m_catalog.songMeta[tid].artist)
					{
						artist = String(ui.m_catalog.songMeta[tid].artist).toLowerCase();
					};
					if (title.indexOf(q) >= 0 || artist.indexOf(q) >= 0 || tid.toLowerCase().indexOf(q) >= 0)
					{
						hit.push(tid);
					};
				};
				hit.sort(ui.m_songs.sortSongsByTitle);
			};
			ui.m_tab = MusicPlayerUi.TAB_SEARCH;
			ui.m_view = MusicPlayerUi.VIEW_SONGS;
			if (!keepAdd)
			{
				ui.m_listMode = null;
				ui.m_addSubView = null;
			}
			else
			{
				ui.m_listMode = "add";
				ui.m_addSubView = MusicPlayerUi.ADD_SONGS;
				ui.m_addPool = hit.concat();
			};
			ui.m_editMode = false;
			ui.m_contextId = "__search__";
			ui.m_gridCells = [{"id": "__search__", "kind": "search", "label": "Search"}];
			ui.m_gridIndex = 0;
			ui.m_songIds = hit;
			ui.m_queue = hit.concat();
			ui.m_songIndex = 0;
			ui.m_songScroll = 0;
			ui.m_title.text = keepAdd
				? ("Add Songs to " + ui.m_edit.addTargetLabel())
				: (q.length > 0 ? ("Search: " + query) : "Search");
			if (hit.length > 0)
			{
				ui.m_songList.updateSongListBackground(String(hit[0]));
			}
			else
			{
				ui.m_transport.refreshPreviewBg(MusicStageVisuals.WAITING_ROOM_ID);
			};
			ui.paint();
		}
	}
}
