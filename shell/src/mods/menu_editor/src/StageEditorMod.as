package
{
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.utils.getQualifiedClassName;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Visual Stage Select grid editor. Persist normal/past rows via saveExt.
	 */
	public class StageEditorMod extends Sprite
	{
		internal static const MAX_PAGES:int = 99;
		internal static const ADD_TILE_W:int = 48;
		internal static const ADD_TILE_H:int = 28;
		internal static const MAX_COLS:int = 13;
		internal static const MAX_ROWS:int = 6;
		internal static const BTN_W:int = 118;
		internal static const MODE_SORT:int = 0;
		internal static const MODE_ADD:int = 1;
		internal static const MODE_REMOVE:int = 2;

		internal var m_bar:StageEditBar;
		internal var m_book:StagePages;
		internal var m_store:StageGridStore;
		internal var m_catalog:StageCatalog;
		internal var m_layout:StageGridLayout;
		internal var m_sxpUi:StageSxp;
		internal var m_input:StageEditInput;
		internal var m_addUi:StageAddPopup;
		internal var m_extra:StageExtraMatch;
		internal var m_host:*;
		internal var m_editing:Boolean;
		internal var m_mode:int;
		internal var m_editBtn:Sprite;
		internal var m_bgBtn:Sprite;
		internal var m_spaceBtn:Sprite;
		internal var m_bgPicking:Boolean;
		internal var m_sortBtn:Sprite;
		internal var m_removeBtn:Sprite;
		internal var m_restoreBtn:Sprite;
		internal var m_addBtn:Sprite;
		internal var m_pageBtn:Sprite;
		internal var m_confirmBtn:Sprite;
		internal var m_removeAllBtn:Sprite;
		internal var m_addPopup:Sprite;
		internal var m_addScroll:int;
		internal var m_removeIds:Object;
		internal var m_sortPickId:String;
		internal var m_dragId:String;
		internal var m_dragClip:DisplayObject;
		internal var m_dragFromBench:Boolean;
		internal var m_dragging:Boolean;
		private var m_editKeyFn:Function;
		internal var m_iconHooked:Boolean;
		internal var m_editPage:int;
		internal var m_livePage:int;
		internal var m_grid:Array;
		internal var m_defaultGrid:Array;
		internal var m_sxpClip:MovieClip;
		internal var m_sxpWrap:Sprite;
		internal var m_xpBtn:Sprite;
		internal var m_sxpSelectLetGo:Boolean;
		internal var m_handClip:DisplayObject;
		internal var m_cachedSss:*;
		internal var m_menusReady:Boolean;
		internal var m_matchGame:*;
		internal var m_allowTraining:Boolean;
		internal var m_showExtraStages:Boolean;
		private var m_openWait:OpenWaiter;

		public function StageEditorMod()
		{
			super();
			m_bar = new StageEditBar(this);
			m_book = new StagePages(this);
			m_store = new StageGridStore(this);
			m_catalog = new StageCatalog(this);
			m_layout = new StageGridLayout(this);
			m_sxpUi = new StageSxp(this);
			m_input = new StageEditInput(this);
			m_addUi = new StageAddPopup(this);
			m_extra = new StageExtraMatch(this);
			m_editing = false;
			m_mode = MODE_SORT;
			m_addScroll = 0;
			m_removeIds = {};
			m_sortPickId = "";
			m_dragId = "";
			m_dragFromBench = false;
			m_dragging = false;
			m_iconHooked = false;
			m_bgBtn = null;
			m_bgPicking = false;
			m_editPage = 0;
			m_livePage = 0;
			m_grid = m_book.emptyGrid();
			m_defaultGrid = m_book.emptyGrid();
			m_sxpClip = null;
			m_sxpWrap = null;
			m_xpBtn = null;
			m_sxpSelectLetGo = true;
			m_handClip = null;
			m_cachedSss = null;
			m_menusReady = false;
			m_matchGame = null;
			m_allowTraining = false;
			m_showExtraStages = false;
			m_openWait = new OpenWaiter("sssedit", isStageSelectOnscreen, enterFromWait, log);
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			};
			try
			{
				host.setSessionFlag("stage_editor.paging", true);
			}
			catch (flagErr:*)
			{
			};
			host.addHook("AFTER_BOOT", onAfterBoot);
			host.addHook("BEFORE_INITIAL_MENU", onMenusReady);
			host.addHook("MENU_SHOW", onMenuShow);
			host.addHook("MENU_HIDE", onMenuHide);
			host.addHook("STAGE_SELECT", m_book.onStageSelectHook);
			host.addHook("STAGE_SELECT_GESTURE", m_book.onPageGesture);
			host.addEventListener("mod_menu.ready", onMenuReady);
			host.addEventListener("stage_editor.open", onStageEditOpen);
			registerMenu();
			log("boot");
		}

		public function onBootEnd():void
		{
			m_openWait.stop();
			exitLiveEdit(false);
			m_extra.closeExtraPicker();
			m_bar.detachEditButton();
			m_layout.stopCompact();
			m_sxpUi.unhookSxpInput();
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("AFTER_BOOT", onAfterBoot);
					m_host["removeHook"]("BEFORE_INITIAL_MENU", onMenusReady);
					m_host["removeHook"]("MENU_SHOW", onMenuShow);
					m_host["removeHook"]("MENU_HIDE", onMenuHide);
					m_host["removeHook"]("STAGE_SELECT", m_book.onStageSelectHook);
					m_host["removeHook"]("STAGE_SELECT_GESTURE", m_book.onPageGesture);
					m_host["removeEventListener"]("mod_menu.ready", onMenuReady);
					m_host["removeEventListener"]("stage_editor.open", onStageEditOpen);
					m_host.emit("mod_menu.unregister", {"id": "stage_editor"});
					m_host.emit("mod_menu.unregister", {"id": "load_extra_stage"});
				}
				catch (err:*)
				{
				};
			};
			m_host = null;
		}

		private function onAfterBoot(ctx:Object):void
		{
			try
			{
				if (m_host)
				{
					m_host.setSessionFlag("stage_editor.paging", true);
				};
			}
			catch (flagErr:*)
			{
			};
			m_store.captureDefaults();
			m_store.applySaved();
			registerMenu();
		}

		private function onMenuReady(e:*):void
		{
			registerMenu();
		}

		private function onMenusReady(ctx:Object):void
		{
			m_menusReady = true;
			m_store.applySaved();
			m_layout.startCompact();
		}

		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var name:String;
			try
			{
				if (!ctx)
				{
					return;
				};
				menu = ctx.menu;
				if (!menu)
				{
					return;
				};
				try
				{
					name = getQualifiedClassName(menu);
				}
				catch (err:*)
				{
					return;
				};
				try
				{
					if (menu.GameObj)
					{
						m_matchGame = menu.GameObj;
					};
				}
				catch (gameErr:*)
				{
				};
				if (name && name.indexOf("StageSelectMenu") >= 0)
				{
					m_cachedSss = menu;
					if (!m_matchGame)
					{
						m_matchGame = m_extra.readCssGame();
					};
					m_menusReady = true;
					if (!m_editing)
					{
						m_store.applySaved();
					};
					m_layout.startCompact();
					m_bar.attachEditButton(menu);
					m_layout.compactFrame(null);
					log("Stage Select shown game=" + m_matchGame + " pages=" + m_book.pageCount() + " live=" + (m_livePage + 1));
				};
			}
			catch (stepErr:*)
			{
				log("fail step=onMenuShow err=" + stepErr);
			};
		}

		private function onMenuHide(ctx:Object):void
		{
			var menu:*;
			if (!ctx)
			{
				return;
			};
			menu = ctx.menu;
			if (menu && menu == m_cachedSss)
			{
				exitLiveEdit(false);
				m_bar.cancelBgPick();
				m_bar.detachEditButton();
				m_layout.detachFrame();
				m_cachedSss = null;
				m_sxpUi.unhookSxp();
				m_sxpUi.unhookSxpInput();
				if (m_xpBtn && m_xpBtn.parent)
				{
					m_xpBtn.parent.removeChild(m_xpBtn);
				};
				m_xpBtn = null;
				m_sxpClip = null;
				m_sxpWrap = null;
				m_handClip = null;
			};
		}

		private function registerMenu():void
		{
			if (!m_host)
			{
				return;
			};
			try
			{
				m_host.emit("mod_menu.register", {
					"id": "stage_editor",
					"label": "Edit Stages",
					"section": "Roster",
					"onSelect": openEditor
				});
				m_host.emit("mod_menu.register", {
					"id": "load_extra_stage",
					"label": "Load extra stage",
					"section": "Roster",
					"visible": isStageSelectOnscreen,
					"onSelect": m_extra.openExtraPicker
				});
			}
			catch (err:*)
			{
			};
		}

		private function openEditor():void
		{
			try
			{
				if (m_editing)
				{
					exitLiveEdit(false);
					return;
				};
				if (!isStageSelectOnscreen())
				{
					return;
				};
				enterLiveEdit();
			}
			catch (stepErr:*)
			{
				log("fail step=openEditor err=" + stepErr);
			};
		}

		private function onStageEditOpen(e:*):void
		{
			try
			{
				m_openWait.start(stageEditStage());
			}
			catch (stepErr:*)
			{
				log("fail step=onStageEditOpen err=" + stepErr);
			};
		}

		private function enterFromWait():void
		{
			if (!m_editing)
			{
				enterLiveEdit();
			};
		}

		private function stageEditStage():Stage
		{
			try
			{
				if (m_host && m_host.stage)
				{
					return (m_host.stage as Stage);
				};
			}
			catch (err:*)
			{
			};
			return (stage);
		}

		internal function enterLiveEdit():void
		{
			var st:Stage;
			try
			{
				if (m_editing || !m_host || !isStageSelectOnscreen())
				{
					return;
				};
				m_bar.cancelBgPick();
				m_editing = true;
				m_mode = MODE_SORT;
				m_editPage = m_livePage;
				m_dragId = "";
				m_dragging = false;
				m_sortPickId = "";
				m_removeIds = {};
				try
				{
					m_host.setSessionFlag("stage_editor.editing", true);
				}
				catch (flagErr:*)
				{
				};
				m_bar.updateEditButtonLabel();
				m_bar.updateModeLabel();
				m_bar.layoutBottomButtons();
				m_input.hookEditInput();
				st = m_host.stage as Stage;
				if (st)
				{
					st.addEventListener(MouseEvent.MOUSE_MOVE, m_input.onEditMouseMove, true, 80);
					st.addEventListener(MouseEvent.MOUSE_UP, m_input.onEditMouseUp, true, 80);
				};
				m_editKeyFn = onEditKey;
				try
				{
					m_host.addKeyListener(m_editKeyFn);
				}
				catch (keyErr:*)
				{
				};
			}
			catch (stepErr:*)
			{
				log("fail step=enterLiveEdit err=" + stepErr);
			};
		}

		internal function exitLiveEdit(viaF1:Boolean):void
		{
			var st:Stage;
			if (!m_editing)
			{
				return;
			};
			m_input.endDrag(false);
			m_addUi.closeAddPopup();
			m_store.applyGrid(true);
			m_input.unhookEditInput();
			m_editing = false;
			m_sortPickId = "";
			m_removeIds = {};
			m_bar.updateEditButtonLabel();
			m_bar.layoutBottomButtons();
			if (m_host)
			{
				st = m_host.stage as Stage;
				if (st)
				{
					st.removeEventListener(MouseEvent.MOUSE_MOVE, m_input.onEditMouseMove, true);
					st.removeEventListener(MouseEvent.MOUSE_UP, m_input.onEditMouseUp, true);
				};
				try
				{
					if (m_editKeyFn != null)
					{
						m_host["removeKeyListener"](m_editKeyFn);
					};
				}
				catch (err:*)
				{
				};
				m_editKeyFn = null;
				try
				{
					m_host.setSessionFlag("stage_editor.editing", false);
					if (viaF1)
					{
						m_host.setSessionFlag("mod_menu.skip_f1", true);
					};
				}
				catch (blockErr:*)
				{
				};
			};
		}

		private function onEditKey(e:KeyboardEvent):Boolean
		{
			if (!m_editing || !e)
			{
				return (false);
			};
			if (e.keyCode == 27)
			{
				if (m_mode == MODE_ADD)
				{
					m_bar.setEditMode(MODE_SORT);
				}
				else
				{
					exitLiveEdit(false);
				};
				return (true);
			};
			return (false);
		}

		internal function log(msg:String):void
		{
			var GL:*;
			try
			{
				GL = EngineRefs.GameLog;
				if (GL && GL.write is Function)
				{
					GL.write("[stage_editor] " + msg);
				};
			}
			catch (err:*)
			{
			};
			trace("[stage_editor] " + msg);
		}

		internal function pageCountsLog():String
		{
			var parts:Array;
			var i:int;
			parts = [];
			i = 0;
			while (i < m_book.pageCount())
			{
				parts.push("P" + (i + 1) + "=" + GridRows.flatten(m_book.pageRows(i)).length);
				i++;
			};
			return (parts.join(","));
		}

		internal function isStageSelectOnscreen():Boolean
		{
			try
			{
				if (m_cachedSss)
				{
					return (Boolean(m_cachedSss.isOnscreen()));
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function notifyUser(msg:String):void
		{
			try
			{
				if (m_host)
				{
					m_host.notify(msg);
				};
			}
			catch (err:*)
			{
			};
		}
	}
}
