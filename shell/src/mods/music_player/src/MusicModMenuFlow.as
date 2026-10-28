package
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.getQualifiedClassName;
	import flash.utils.setTimeout;

	/**
	 * Menu-side flow: catalog warmup, playlist launch screen, menu show/hide, title/attract BGM release.
	 */
	public class MusicModMenuFlow
	{
		private var mod:MusicPlayerMod;
		private var m_playlistLaunchTries:int;

		public function MusicModMenuFlow(owner:MusicPlayerMod)
		{
			mod = owner;
			m_playlistLaunchTries = 0;
		}

		private function openPlaylistLaunch():void
		{
			mod.openPlayer();
			if (mod.m_ui && mod.m_ui.isOpen())
			{
				mod.m_ui.showPlaylistTab();
				m_playlistLaunchTries = 0;
				if (mod.m_host && mod.m_host.setSessionFlag is Function)
				{
					mod.m_host.setSessionFlag("music_player.open_jukebox", null);
				};
				return;
			};
			// Deep link skips the title menu, so Main.Root may not exist yet.
			m_playlistLaunchTries++;
			if (m_playlistLaunchTries < 40)
			{
				setTimeout(openPlaylistLaunch, 250);
			};
		}

		private function wantJukeboxLaunch():Boolean
		{
			if (readLaunchScreen() == "jukebox")
			{
				return true;
			};
			try
			{
				if (mod.m_host && mod.m_host.getSessionFlag is Function)
				{
					return Boolean(mod.m_host.getSessionFlag("music_player.open_jukebox"));
				};
			}
			catch (flagErr:*)
			{
			};
			return false;
		}

		private function readLaunchScreen():String
		{
			var file:File;
			var stream:FileStream;
			var text:String;
			var data:Object;
			try
			{
				file = File.applicationDirectory.resolvePath("expansions/state/launch.json");
				if (!file.exists)
				{
					return "";
				};
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				text = stream.readUTFBytes(stream.bytesAvailable);
				stream.close();
				data = JSON.parse(text);
				return data && data.screen ? String(data.screen).toLowerCase() : "";
			}
			catch (err:*)
			{
			};
			return "";
		}

		internal function onResourcePoolReady(ctx:Object):void
		{
			warmCatalog();
		}

		/** One-shot song list when a stage (or expansion stage) SWF finishes loading. */
		internal function onResourceLoaded(ctx:Object):void
		{
			var id:String;
			if (!ctx || !mod.m_catalog)
			{
				return;
			};
			id = ctx["id"] != null ? String(ctx["id"]) : "";
			if (!id)
			{
				return;
			};
			if (id.indexOf("bgm_") == 0 || id.indexOf("bgm_legacy_") == 0)
			{
				mod.m_catalog.refreshTrackMeta(id);
				if (mod.m_ui && mod.m_ui.isOpen() && mod.m_ui.onCatalogReady is Function)
				{
					mod.m_ui.onCatalogReady();
				};
			};
			if (mod.m_catalog.ingestStageSongsOnce(id))
			{
				MusicSeriesResolver.invalidate();
				if (mod.m_ui && mod.m_ui.isOpen() && mod.m_ui.onCatalogReady is Function)
				{
					mod.m_ui.onCatalogReady();
				};
			};
		}

		/** Roster rebuild only — never bulk-preload stage SWFs (breaks match start). */
		internal function warmCatalog():void
		{
			var i:int;
			var sid:String;
			var ingested:int;
			if (!mod.m_catalog)
			{
				return;
			};
			if (mod.m_catalog.rebuildIfNeeded())
			{
				trace("[music_player] catalog refreshed stages=" + mod.m_catalog.stageIds.length
					+ " other=" + mod.m_catalog.otherSongIds.length);
			};
			MusicSongLibrary.syncUploads(mod.m_catalog, null);
			MusicSongLibrary.syncLegacy(mod.m_catalog);
			MusicPacks.sync(mod.m_catalog);
			if (mod.m_store && mod.m_store.migrateStripPackIds is Function)
			{
				mod.m_store.migrateStripPackIds();
			};
			if (mod.m_store && mod.m_store.migrateLegacyTrackIds is Function)
			{
				mod.m_store.migrateLegacyTrackIds();
			};
			mod.m_loader.registerKnownUploads();
			mod.m_loader.registerKnownLegacy();
			// Opportunistically lock songs for stages already in the pool (no load).
			ingested = 0;
			i = 0;
			while (i < mod.m_catalog.stageIds.length)
			{
				sid = String(mod.m_catalog.stageIds[i]);
				i++;
				if (mod.m_catalog.ingestStageSongsOnce(sid))
				{
					ingested++;
				};
			};
			mod.m_catalog.ingestStageSongsOnce(MusicStageVisuals.TRAINING_GRID_ID);
			if (ingested > 0)
			{
				trace("[music_player] ingested song lists for " + ingested + " loaded stages");
			};
			if (mod.m_ui && mod.m_ui.isOpen() && mod.m_ui.onCatalogReady is Function)
			{
				mod.m_ui.onCatalogReady();
			};
		}

		internal function onMenuReady(e:*):void
		{
			mod.registerMenu();
		}

		internal function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var q:String;
			menu = ctx ? ctx["menu"] : null;
			if (!menu)
			{
				return;
			};
			MusicLiveMenus.noteShow(menu);
			mod.m_input.armMenuJukeboxChord();
			q = getQualifiedClassName(menu);
			if (mod.m_menu && mod.m_menu.isOpen() && q.indexOf("JukeboxMenu") < 0)
			{
				mod.m_menu.hideStockMenu(menu);
			};
			// Title kills BGM — drop jukebox hold so menu music can resume after title.
			if (q.indexOf("TitleMenu") >= 0)
			{
				releaseBgmForTitle();
				if (wantJukeboxLaunch() && !(mod.m_ui && mod.m_ui.isOpen()))
				{
					openPlaylistLaunch();
				};
			}
			else if (q.indexOf("SoundMenu") >= 0)
			{
				mod.m_buttons.attachSoundsButton(menu);
			}
			else if (q.indexOf("StageSelectMenu") >= 0)
			{
				mod.m_buttons.attachSssButton(menu);
			}
			else if (q.indexOf("MatchResultsMenu") >= 0)
			{
				mod.m_transport.freezePlaylistAdvance();
			};
		}

		/** Title (and attract) stop all audio; lingering hold would leave menus silent. */
		private function releaseBgmForTitle():void
		{
			mod.m_expectAdvance = false;
			mod.m_announceHud = false;
			mod.m_paused = true;
			mod.m_pausePos = 0;
			mod.m_local.stopLocalPlayback();
			mod.m_nowPlaying.setBgmHold(false);
			try
			{
				if (mod.m_host && mod.m_host.setSessionFlag is Function)
				{
					mod.m_host.setSessionFlag("music_player.now_playing", "");
					mod.m_host.setSessionFlag("music_player.now_id", "");
				};
			}
			catch (flagErr:*)
			{
			};
		}

		/** Attract demo/intro owns BGM — release jukebox hold and skip match overrides. */
		internal function onAttractMedia(ctx:Object):void
		{
			var active:Boolean;
			active = Boolean(ctx && ctx["active"]);
			if (active)
			{
				mod.m_musicOverrideId = null;
				mod.m_musicClaimAt = 0;
				mod.m_pendingMatchMusicId = null;
				releaseBgmForTitle();
				try
				{
					if (mod.m_host && mod.m_host.setSessionFlag is Function)
					{
						mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_CLAIM_ID, null);
						mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_CLAIM_AT, null);
						mod.m_host.setSessionFlag(MusicPlayerMod.FLAG_OVERRIDE, null);
					};
				}
				catch (claimErr:*)
				{
				};
				if (mod.m_catalog)
				{
					mod.m_catalog.pausePackMetaCache(true);
				};
				MusicMem.snap("attract:suspend");
			}
			else
			{
				if (mod.m_catalog)
				{
					mod.m_catalog.pausePackMetaCache(false);
				};
				MusicMem.snap("attract:resume");
			};
		}

		internal function isAttractActive():Boolean
		{
			try
			{
				if (mod.m_host && mod.m_host.getSessionFlag is Function)
				{
					return Boolean(mod.m_host.getSessionFlag("attractActive"));
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function onMenuHide(ctx:Object):void
		{
			var menu:*;
			menu = ctx ? ctx["menu"] : null;
			MusicLiveMenus.noteHide(menu);
			if (menu && menu == mod.m_soundsMenu)
			{
				mod.m_buttons.detachSoundsButton();
			};
			if (menu && menu == mod.m_sssMenu)
			{
				mod.m_buttons.detachSssButton();
			};
		}
	}
}
