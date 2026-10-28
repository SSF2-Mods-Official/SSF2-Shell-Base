package
{
	import com.mcleodgaming.ssf2.menus.EventMenu;
	import com.mcleodgaming.ssf2.menus.ExpansionEventMenu;
	import com.mcleodgaming.ssf2.modes.ExpansionEventOrchestrator;
	import flash.display.Sprite;
	import flash.system.ApplicationDomain;
	import flash.utils.getQualifiedClassName;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Boot mod: scan expansions/events, merge into event_mode.eventList, wire EventMenu + series.
	 */
	public class EventExpansionsMod extends Sprite
	{
		private var m_host:*;
		private var m_loader:ExpansionEventLoader;
		private var m_series:EventSeriesController;
		private var m_banana:GameBananaClient;
		private var m_browsing:Boolean;
		private var m_installing:Boolean;
		private var m_updates:Array;
		private var m_notifyCls:Class;

		public function EventExpansionsMod()
		{
			super();
			m_host = null;
			m_loader = null;
			m_series = null;
			m_banana = null;
			m_browsing = false;
			m_installing = false;
			m_updates = [];
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			m_series = new EventSeriesController(host);
			m_loader = new ExpansionEventLoader(host);
			m_banana = new GameBananaClient(dbg);
			if (host)
			{
				try
				{
					host.patch("event_expansions.resolveId", onResolveId);
					host.patch("event_expansions.modeClass", ExpansionEventOrchestrator.modeClassForEvent);
					host["replaceClass"](EventMenu, ExpansionEventMenu);
					host.patch("event_expansions.browseDownloads", onBrowseDownloads);
					host.patch("event_expansions.installEvent", onInstallEvent);
					host.addHook("MENU_SHOW", onMenuShow);
					host.addHook("MODE_END", onModeEnd);
					host.addHook("AFTER_BOOT", onAfterBoot);
					host.addHook("RESOURCE_LOADED", onResourceLoaded);
				}
				catch (err:*)
				{
					trace("[event_expansions] hook/patch failed: " + err);
				};
			};
			m_loader.scanAndLoad(function ():void
			{
				mergeAndPushToMenu();
				dbg("scan complete packs=" + ExpansionEventRegistry.getPackIds().length);
			});
			dbg("boot");
		}

		public function onBootEnd():void
		{
			m_host = null;
			trace("[event_expansions] onBootEnd");
		}

		private function onResolveId(eventMatchID:String):String
		{
			var pack:Object;
			var list:Array;
			var i:int;
			if (!eventMatchID)
			{
				return null;
			};
			pack = ExpansionEventRegistry.getPack(eventMatchID);
			if (pack)
			{
				if (m_host && m_host.setSessionFlag is Function)
				{
					m_host.setSessionFlag(EventSeriesController.FLAG_LAST_WIN, eventMatchID);
				};
				return eventMatchID;
			};
			try
			{
				list = ExpansionEventRegistry.getMenuList();
				i = 0;
				while (i < list.length)
				{
					if (list[i] && list[i].id === eventMatchID)
					{
						return eventMatchID;
					};
					i++;
				};
			}
			catch (err:*)
			{
			};
			return null;
		}

		private function onAfterBoot(ctx:Object):void
		{
			mergeAndPushToMenu();
		}

		/** EventMenu asks for the GameBanana event list; answered async via setDownloadList. */
		private function onBrowseDownloads():Boolean
		{
			if (m_browsing)
			{
				dbg("browseDownloads ignored, already in flight");
				return true;
			};
			if (!m_banana)
			{
				dbg("browseDownloads with no client");
				return false;
			};
			m_browsing = true;
			dbg("browseDownloads start");
			m_banana.fetchEventList(function (records:Array):void
			{
				m_browsing = false;
				dbg("browseDownloads ok n=" + (records ? records.length : -1));
				checkUpdates(records, toDownloadEntries(records));
			}, function (msg:String):void
			{
				m_browsing = false;
				dbg("browseDownloads error: " + msg);
				pushDownloadList([], msg);
			});
			return true;
		}

		/** EventMenu asks to install a submission; progress is reported via setDownloadStatus. */
		private function onInstallEvent(modId:*, modName:*):Boolean
		{
			var id:int = int(modId);
			var name:String = modName != null ? String(modName) : ("Mod " + id);
			var rowId:String = "gb." + id;
			if (String(modId) == "updates")
			{
				installUpdates();
				return true;
			};
			if (isOwned(id))
			{
				dbg("installEvent owned id=" + id);
				return true;
			};
			if (m_installing)
			{
				dbg("installEvent ignored, already installing");
				return true;
			};
			if (!m_banana || id <= 0)
			{
				dbg("installEvent bad args modId=" + modId);
				return false;
			};
			m_installing = true;
			dbg("installEvent start " + id + " " + name);
			m_banana.installMod(id, name, function (msg:String, done:Boolean, ok:Boolean):void
			{
				dbg("installEvent " + id + ": " + msg + (done ? " (done ok=" + ok + ")" : ""));
				pushDownloadStatus(rowId, msg);
				if (!done)
				{
					return;
				};
				m_installing = false;
				if (ok)
				{
					rescan();
				};
			});
			return true;
		}

		private function checkUpdates(records:Array, entries:Array):void
		{
			var installed:Array;
			var queue:Array = [];
			var i:int;
			var pack:Object;
			var known:Object = {};
			m_updates = [];
			if (!m_banana)
			{
				pushDownloadList(entries, null);
				return;
			};
			markInstalled(entries);
			i = 0;
			while (records && i < records.length)
			{
				if (records[i])
				{
					known[int(records[i].modId)] = true;
				};
				i++;
			};
			installed = m_banana.installedPacks();
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
			var step:Function;
			step = function ():void
			{
				var next:Object;
				if (queue.length < 1)
				{
					finishUpdatePrompt(entries);
					return;
				};
				next = queue.shift();
				m_banana.fetchLatestFile(int(next.modId), function (file:Object):void
				{
					if (file && int(file.fileId) > 0 && int(file.fileId) != int(next.fileId))
					{
						m_updates.push({"modId": int(next.modId), "name": String(next.name)});
					};
					step();
				}, function (msg:String):void
				{
					step();
				});
			};
			step();
		}

		private function finishUpdatePrompt(entries:Array):void
		{
			var n:int = m_updates ? m_updates.length : 0;
			var notice:String = null;
			if (n > 0)
			{
				notice = n + (n == 1 ? " event has a new update. Download it?" : " events have new updates. Download them?");
				entries.unshift({
					"id": "gb.updates",
					"modId": "updates",
					"name": "Yes — download " + n + (n == 1 ? " update" : " updates"),
					"description": "Replaces the installed files with the newer ones.",
					"expansion": true,
					"downloadItem": true
				});
				toast(notice);
			};
			pushDownloadList(entries, notice);
		}

		private function installUpdates():void
		{
			var queue:Array;
			var step:Function;
			if (!m_updates || m_updates.length < 1)
			{
				toast("No updates to download");
				return;
			};
			if (m_installing)
			{
				return;
			};
			queue = m_updates.concat();
			m_installing = true;
			toast("Downloading " + queue.length + " updates...");
			step = function ():void
			{
				var item:Object;
				if (queue.length < 1)
				{
					m_installing = false;
					m_updates = [];
					toast("Download complete");
					rescan();
					return;
				};
				item = queue.shift();
				m_banana.installMod(int(item.modId), String(item.name), function (msg:String, done:Boolean, ok:Boolean):void
				{
					pushDownloadStatus("gb." + item.modId, String(item.name) + ": " + msg);
					if (!done)
					{
						return;
					};
					step();
				});
			};
			step();
		}

		private function toast(msg:String):void
		{
			var cls:Class;
			var domain:ApplicationDomain;
			if (!msg)
			{
				return;
			};
			cls = m_notifyCls;
			if (!cls)
			{
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
				m_notifyCls = cls;
			};
			if (cls)
			{
				try
				{
					cls["notify"](msg);
					return;
				}
				catch (callErr:*)
				{
				};
			};
		}

		private function isOwned(modId:int):Boolean
		{
			var installed:Array;
			var i:int = 0;
			if (!m_banana || modId <= 0)
			{
				return false;
			};
			installed = m_banana.installedPacks();
			while (installed && i < installed.length)
			{
				if (installed[i] && int(installed[i].modId) == modId)
				{
					return true;
				};
				i++;
			};
			return false;
		}

		/** Rows whose mod id is already on disk are shown, and they are not downloads. */
		private function markInstalled(entries:Array):void
		{
			var installed:Array = m_banana.installedPacks();
			var owned:Object = {};
			var n:int = 0;
			var i:int = 0;
			var pack:Object;
			var entry:Object;
			while (installed && i < installed.length)
			{
				pack = installed[i];
				i++;
				if (pack && int(pack.modId) > 0)
				{
					owned[int(pack.modId)] = true;
				};
			};
			i = 0;
			while (entries && i < entries.length)
			{
				entry = entries[i];
				i++;
				if (!entry || !owned[int(entry.modId)])
				{
					continue;
				};
				entry.installed = true;
				entry.downloadItem = false;
				entry.name = String(entry.name) + " (installed)";
				entry.description = "Already installed.";
				n++;
			};
			dbg("download owned n=" + n);
		}

		private function toDownloadEntries(records:Array):Array
		{
			var out:Array = [];
			var rec:Object;
			var i:int;
			i = 0;
			while (records && i < records.length)
			{
				rec = records[i] as Object;
				i++;
				if (!rec)
				{
					continue;
				};
				out.push({
					"id": "gb." + rec.modId,
					"modId": rec.modId,
					"name": String(rec.name),
					"description": "By " + (rec.creator || "unknown") + " - select to download and install.",
					"creator": rec.creator,
					"expansion": true,
					"downloadItem": true,
					"profileUrl": rec.profileUrl
				});
			};
			return out;
		}

		private function pushDownloadList(entries:Array, errorMessage:String):void
		{
			var menu:* = getEventMenu();
			if (!menu)
			{
				dbg("pushDownloadList: no event menu");
				return;
			};
			try
			{
				menu.setDownloadList(entries, errorMessage);
			}
			catch (err:*)
			{
				dbg("setDownloadList FAIL: " + err);
			};
		}

		private function pushDownloadStatus(rowId:String, message:String):void
		{
			var menu:* = getEventMenu();
			if (!menu)
			{
				return;
			};
			try
			{
				menu.setDownloadStatus(rowId, message);
				toast(message);
			}
			catch (err:*)
			{
				dbg("setDownloadStatus FAIL: " + err);
			};
		}

		private function getEventMenu():*
		{
			var MC:Class;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				return MC["eventMenu"];
			}
			catch (err:*)
			{
				dbg("getEventMenu: " + err);
			};
			return null;
		}

		/** Re-read expansions/events after an install so the new pack shows up without a relaunch. */
		private function rescan():void
		{
			if (!m_loader)
			{
				return;
			};
			dbg("rescan after install");
			m_loader.scanAndLoad(function ():void
			{
				mergeAndPushToMenu();
				pushListToMenu(getEventMenu());
				dbg("rescan complete packs=" + ExpansionEventRegistry.getPackIds().length);
			});
		}

		private function onResourceLoaded(ctx:Object):void
		{
			var id:String;
			try
			{
				id = ctx ? String(ctx.id || ctx.resourceId || "") : "";
				if (id == "event_mode" || id.indexOf("event") >= 0)
				{
					mergeAndPushToMenu();
				};
			}
			catch (err:*)
			{
			};
		}

		private function onModeEnd(ctx:Object):void
		{
			if (m_series)
			{
				m_series.onModeEnd(ctx);
			};
		}

		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var startSeries:String;
			var startEvent:String;
			menu = ctx ? ctx.menu : null;
			try
			{
				if (menu && isEventMenu(menu))
				{
					pushListToMenu(menu);
					startSeries = m_host ? String(m_host.getSessionFlag(EventSeriesController.FLAG_SERIES_START, null) || "") : "";
					if (startSeries)
					{
						m_host.setSessionFlag(EventSeriesController.FLAG_SERIES_START, null);
						try
						{
							if ("removeSelf" in menu)
							{
								menu.removeSelf();
							};
						}
						catch (rsErr:*)
						{
						};
						m_series.beginSeries(startSeries);
						return;
					};
					startEvent = m_host ? String(m_host.getSessionFlag(EventSeriesController.FLAG_START_EVENT, null) || "") : "";
					if (startEvent)
					{
						m_host.setSessionFlag(EventSeriesController.FLAG_START_EVENT, null);
						try
						{
							if ("removeSelf" in menu)
							{
								menu.removeSelf();
							};
						}
						catch (rs2:*)
						{
						};
						m_series.beginEvent(startEvent);
						return;
					};
				};
				if (m_series)
				{
					m_series.onMenuShow(ctx);
				};
			}
			catch (menuErr:*)
			{
				dbg("MENU_SHOW FAIL: " + menuErr);
			};
		}

		private function mergeAndPushToMenu():void
		{
			var RM:Class;
			var list:Array;
			var packIds:Array;
			var i:int;
			var entry:Object;
			var slim:Object;
			var found:Boolean;
			var j:int;

			ExpansionEventRegistry.buildMenuList();
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager") as Class;
				list = RM["getResourceByID"]("event_mode").getProp("eventList") as Array;
				if (list)
				{
					// Merge every playable pack (including series members) so EventMode can resolve classAPI.
					packIds = ExpansionEventRegistry.getPackIds();
					i = 0;
					while (i < packIds.length)
					{
						entry = ExpansionEventRegistry.findEventEntry(String(packIds[i]));
						if (!entry || !(entry.classAPI is Class))
						{
							i++;
							continue;
						};
						slim = sanitizeEventListEntry(entry);
						found = false;
						j = 0;
						while (j < list.length)
						{
							if (list[j] && list[j].id === slim.id)
							{
								list[j].expansion = true;
								list[j].classAPI = slim.classAPI;
								if (slim.chooseCharacter != null)
								{
									list[j].chooseCharacter = slim.chooseCharacter;
								};
								found = true;
								break;
							};
							j++;
						};
						if (!found)
						{
							list.push(slim);
						};
						i++;
					};
				};
			}
			catch (err:*)
			{
				trace("[event_expansions] merge eventList: " + err);
			};
			// Do not touch MenuController.eventMenu here — getter constructs it early and can crash boot.
			// MENU_SHOW (onMenuShow) pushes the expansion list once the menu exists.
		}

		/** Fields safe to expose on event_mode.eventList (no File/folder host props). */
		private function sanitizeEventListEntry(entry:Object):Object
		{
			var out:Object = {
				"id": entry.id,
				"name": entry.name,
				"description": entry.description != null ? entry.description : "",
				"creator": entry.creator != null ? entry.creator : "",
				"expansion": true,
				"classAPI": entry.classAPI,
				"chooseCharacter": entry.chooseCharacter === true
			};
			if (entry.allStar)
			{
				out.allStar = true;
			};
			if (entry.special)
			{
				out.special = entry.special;
			};
			return out;
		}

		private function pushListToMenu(menu:*):void
		{
			var menuList:Array;
			if (!menu)
			{
				return;
			};
			menuList = ExpansionEventRegistry.getMenuList();
			try
			{
				if ("attachExpansionChrome" in menu)
				{
					menu.attachExpansionChrome();
				};
				if ("setExpansionList" in menu)
				{
					menu.setExpansionList(menuList);
				};
			}
			catch (err:*)
			{
				dbg("setExpansionList FAIL: " + err);
			};
		}

		private function isEventMenu(menu:*):Boolean
		{
			var name:String;
			try
			{
				name = getQualifiedClassName(menu);
				if (name && name.indexOf("EventMenu") >= 0)
				{
					return true;
				};
			}
			catch (err:*)
			{
			};
			return menu && ("setExpansionList" in menu);
		}

		private function dbg(msg:String):void
		{
			var line:String;
			var MH:Class;
			line = "[event_expansions] " + msg;
			trace(line);
			try
			{
				MH = EngineRefs.ssf2("modhost.ModHost") as Class;
				if (MH && MH["appendGameLog"])
				{
					MH["appendGameLog"](line);
				};
			}
			catch (logErr:*)
			{
			};
		}
	}
}
