package
{
	import flash.system.ApplicationDomain;
	import flash.filesystem.File;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Online tab: GameBanana pack browse, update check, and install.
	 */
	public class MusicUiOnline
	{
		private var ui:MusicPlayerUi;
		private var m_online:MusicOnline;
		private var m_onlineRecords:Array;
		private var m_onlineUpdates:Array;
		private var m_onlineStatus:String;

		public function MusicUiOnline(owner:MusicPlayerUi)
		{
			ui = owner;
		}

		internal function buildOnlineGrid():void
		{
			var i:int;
			var rec:Object;
			ui.m_gridCells.push({"id": "__online_back__", "kind": "online_back", "label": "< Playlists"});
			if (m_onlineUpdates && m_onlineUpdates.length > 0)
			{
				ui.m_gridCells.push({
					"id": "__online_updates__",
					"kind": "online_updates",
					"label": "Yes — download " + m_onlineUpdates.length + " updates"
				});
			};
			i = 0;
			while (m_onlineRecords && i < m_onlineRecords.length)
			{
				rec = m_onlineRecords[i];
				i++;
				ui.m_gridCells.push({
					"id": "gb." + rec.modId,
					"kind": "online_mod",
					"modId": rec.modId,
					"label": String(rec.name)
				});
			};
			if (!m_onlineRecords || m_onlineRecords.length < 1)
			{
				ui.m_gridCells.push({
					"id": "__online_wait__",
					"kind": "online_wait",
					"label": m_onlineStatus ? m_onlineStatus : "Contacting GameBanana..."
				});
			};
		}

		internal function beginOnlineBrowse():void
		{
			ui.m_onlineMode = true;
			m_onlineRecords = [];
			m_onlineUpdates = [];
			m_onlineStatus = "Contacting GameBanana...";
			ui.m_gridIndex = 0;
			ui.m_view = MusicPlayerUi.VIEW_GRID;
			if (!m_online)
			{
				m_online = new MusicOnline(function (line:String):void
				{
					trace("[music_player] " + line);
				});
			};
			ui.m_grid.rebuildGrid();
			ui.paint();
			m_online.fetchEventList(function (records:Array):void
			{
				m_onlineRecords = records || [];
				if (m_onlineRecords.length < 1)
				{
					m_onlineStatus = "No music packs posted yet";
					onlineToast(m_onlineStatus);
					ui.m_grid.rebuildGrid();
					ui.paint();
					return;
				};
				m_onlineStatus = "";
				checkOnlineUpdates();
			}, function (msg:String):void
			{
				m_onlineRecords = [];
				m_onlineStatus = msg;
				onlineToast(msg);
				ui.m_grid.rebuildGrid();
				ui.paint();
			});
		}

		private function checkOnlineUpdates():void
		{
			var installed:Array;
			var queue:Array = [];
			var known:Object = {};
			var i:int;
			var pack:Object;
			var step:Function;
			m_onlineUpdates = [];
			i = 0;
			while (m_onlineRecords && i < m_onlineRecords.length)
			{
				known[int(m_onlineRecords[i].modId)] = true;
				i++;
			};
			installed = m_online.installedPacks();
			i = 0;
			while (installed && i < installed.length)
			{
				pack = installed[i];
				i++;
				if (pack && known[int(pack.modId)])
				{
					queue.push(pack);
				};
			};
			step = function ():void
			{
				var next:Object;
				if (queue.length < 1)
				{
					if (m_onlineUpdates.length > 0)
					{
						onlineToast(m_onlineUpdates.length + " music packs have new updates. Download them?");
					};
					ui.m_grid.rebuildGrid();
					ui.paint();
					return;
				};
				next = queue.shift();
				m_online.fetchLatestFile(int(next.modId), function (file:Object):void
				{
					if (file && int(file.fileId) > 0 && int(file.fileId) != int(next.fileId))
					{
						m_onlineUpdates.push({"modId": int(next.modId), "name": String(next.name)});
					};
					step();
				}, function (msg:String):void
				{
					step();
				});
			};
			step();
		}

		internal function installOnlineMod(cell:Object):void
		{
			if (!m_online || !cell)
			{
				return;
			};
			onlineToast("Starting download...");
			try
			{
				m_online.installMod(int(cell.modId), String(cell.label), function (msg:String, done:Boolean, ok:Boolean):void
				{
					onlineToast(msg);
					if (done && ok)
					{
						syncInstalledPacks("online install sync");
						ui.m_onlineMode = false;
						ui.m_grid.rebuildGrid();
						ui.paint();
					};
				});
			}
			catch (err:*)
			{
				trace("[music_player] online install start failed (" + cell.modId + "): " + err);
				onlineToast("Download failed");
			};
		}

		/** Re-scan expansions/songs/packs after a download so new packs show up. */
		private function syncInstalledPacks(step:String):void
		{
			if (!ui.m_catalog)
			{
				return;
			};
			try
			{
				MusicPacks.sync(ui.m_catalog);
			}
			catch (err:*)
			{
				trace("[music_player] " + step + " failed: " + err);
			};
		}

		internal function installOnlineUpdates():void
		{
			var queue:Array;
			var step:Function;
			if (!m_onlineUpdates || m_onlineUpdates.length < 1)
			{
				return;
			};
			queue = m_onlineUpdates.concat();
			onlineToast("Downloading " + queue.length + " updates...");
			step = function ():void
			{
				var item:Object;
				if (queue.length < 1)
				{
					onlineToast("Download complete");
					syncInstalledPacks("online update sync");
					ui.m_onlineMode = false;
					m_onlineUpdates = [];
					ui.m_grid.rebuildGrid();
					ui.paint();
					return;
				};
				item = queue.shift();
				try
				{
					m_online.installMod(int(item.modId), String(item.name), function (msg:String, done:Boolean, ok:Boolean):void
					{
						onlineToast(String(item.name) + ": " + msg);
						if (!done)
						{
							return;
						};
						step();
					});
				}
				catch (err:*)
				{
					trace("[music_player] online update start failed (" + item.modId + "): " + err);
					step();
				};
			};
			step();
		}

		private function onlineToast(msg:String):void
		{
			var cls:Class;
			var domain:ApplicationDomain;
			if (!msg)
			{
				return;
			};
			try
			{
				cls = EngineRefs.ssf2("net.MultiplayerManager") as Class;
			}
			catch (err:*)
			{
			};
			domain = ApplicationDomain.currentDomain;
			while (!cls && domain)
			{
				try
				{
					if (domain.hasDefinition("com.mcleodgaming.ssf2.net.MultiplayerManager"))
					{
						cls = domain.getDefinition("com.mcleodgaming.ssf2.net.MultiplayerManager") as Class;
					};
				}
				catch (err2:*)
				{
				};
				domain = domain.parentDomain;
			};
			if (cls)
			{
				try
				{
					cls["notify"](msg);
				}
				catch (callErr:*)
				{
				};
			};
		}
	}
}
