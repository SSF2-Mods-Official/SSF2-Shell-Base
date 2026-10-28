package
{
	import flash.utils.getQualifiedClassName;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Series chaining: on win advance straight to the next event, skipping the Event Menu;
	 * on fail/quit return to Event Menu expansions mode.
	 */
	public class EventSeriesController
	{
		public static const FLAG_SERIES_ID:String = "event_expansions.seriesId";
		public static const FLAG_SERIES_INDEX:String = "event_expansions.seriesIndex";
		public static const FLAG_CURRENT_EVENT:String = "event_expansions.currentEventId";
		public static const FLAG_AWAITING_RETURN:String = "event_expansions.awaitingReturn";
		public static const FLAG_LAST_WIN:String = "event_expansions.lastWinId";
		public static const FLAG_SERIES_START:String = "event_expansions.seriesStart";
		public static const FLAG_START_EVENT:String = "event_expansions.startEventId";

		private var m_host:*;

		public function EventSeriesController(host:*)
		{
			m_host = host;
		}

		public function clearSeries():void
		{
			setFlag(FLAG_SERIES_ID, null);
			setFlag(FLAG_SERIES_INDEX, null);
			setFlag(FLAG_CURRENT_EVENT, null);
			setFlag(FLAG_AWAITING_RETURN, null);
			setFlag(FLAG_SERIES_START, null);
			setFlag(FLAG_START_EVENT, null);
		}

		public function beginSeries(seriesId:String):void
		{
			var series:Object = ExpansionEventRegistry.getSeries(seriesId);
			var events:Array;
			var firstId:String;
			if (!series)
			{
				trace("[event_expansions] unknown series " + seriesId);
				return;
			};
			events = series.events as Array;
			if (!events || events.length == 0)
			{
				return;
			};
			firstId = String(events[0]);
			setFlag(FLAG_SERIES_ID, seriesId);
			setFlag(FLAG_SERIES_INDEX, 0);
			setFlag(FLAG_CURRENT_EVENT, firstId);
			startEvent(firstId);
		}

		public function beginEvent(eventId:String):void
		{
			var pack:Object = ExpansionEventRegistry.getPack(eventId);
			setFlag(FLAG_SERIES_ID, pack && pack.seriesId ? pack.seriesId : null);
			setFlag(FLAG_SERIES_INDEX, pack && pack.seriesIndex != null ? pack.seriesIndex : null);
			setFlag(FLAG_CURRENT_EVENT, eventId);
			startEvent(eventId);
		}

		public function onModeEnd(ctx:Object):void
		{
			var game:*;
			var mode:*;
			var settings:Object;
			var eventId:String;
			try
			{
				game = ctx ? ctx.game : null;
				if (!game)
				{
					game = EngineRefs.ssf2("controllers.GameController")["currentGame"];
				};
				mode = game ? game.CustomModeObj : null;
				settings = mode ? mode.ModeSettings : null;
				eventId = settings && settings.eventMatchID ? String(settings.eventMatchID) : null;
				if (!eventId)
				{
					eventId = String(getFlag(FLAG_CURRENT_EVENT, null) || "");
				};
				if (eventId)
				{
					setFlag(FLAG_CURRENT_EVENT, eventId);
					setFlag(FLAG_AWAITING_RETURN, true);
				};
			}
			catch (err:*)
			{
				trace("[event_expansions] onModeEnd: " + err);
			};
		}

		public function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var awaiting:Boolean;
			var eventId:String;
			var lastWin:String;
			var seriesId:String;
			var index:int;
			var series:Object;
			var events:Array;
			var won:Boolean;

			menu = ctx ? ctx.menu : null;
			if (!menu || !isEventMenu(menu))
			{
				return;
			};
			awaiting = Boolean(getFlag(FLAG_AWAITING_RETURN, false));
			if (!awaiting)
			{
				return;
			};
			setFlag(FLAG_AWAITING_RETURN, null);
			eventId = String(getFlag(FLAG_CURRENT_EVENT, null) || "");
			lastWin = String(getFlag(FLAG_LAST_WIN, null) || "");
			seriesId = String(getFlag(FLAG_SERIES_ID, null) || "");
			won = Boolean(eventId && lastWin && lastWin == eventId);
			setFlag(FLAG_LAST_WIN, null);

			try
			{
				if ("setListMode" in menu)
				{
					menu.setListMode("expansions");
				};
			}
			catch (modeErr:*)
			{
			};

			if (!seriesId)
			{
				return;
			};

			series = ExpansionEventRegistry.getSeries(seriesId);
			events = series ? (series.events as Array) : null;
			index = int(getFlag(FLAG_SERIES_INDEX, 0));
			if (won && events && index < events.length - 1)
			{
				hideMenu(menu);
				advanceSeries(series, index);
			}
			else if (won && events && index >= events.length - 1)
			{
				hideMenu(menu);
				finishSeries(series);
			}
			else
			{
				clearSeries();
			};
		}

		private function advanceSeries(series:Object, index:int):void
		{
			var nextIndex:int = index + 1;
			var nextId:String = String(series.events[nextIndex]);
			setFlag(FLAG_SERIES_INDEX, nextIndex);
			setFlag(FLAG_CURRENT_EVENT, nextId);
			startEvent(nextId);
		}

		private function finishSeries(series:Object):void
		{
			clearSeries();
			showEventMenuExpansions();
		}

		public function startEvent(eventId:String):void
		{
			var GameClass:Class;
			var EventModeClass:Class;
			var ModeClass:Class;
			var MainClass:Class;
			var RM:Class;
			var MC:Class;
			var game:*;
			var mode:*;
			var modeClass:*;
			var SoundQueue:Class;

			ensureMergedIntoEventList();
			setFlag(FLAG_CURRENT_EVENT, eventId);
			setFlag(FLAG_AWAITING_RETURN, null);
			try
			{
				GameClass = EngineRefs.ssf2("controllers.Game") as Class;
				EventModeClass = EngineRefs.ssf2("modes.EventMode") as Class;
				ModeClass = EngineRefs.ssf2("enums.Mode") as Class;
				MainClass = EngineRefs.ssf2("Main") as Class;
				RM = EngineRefs.ssf2("util.ResourceManager") as Class;
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				// Expansion packs use ExpansionEventOrchestrator (avoids event_mode SSF2CustomMatch #1034).
				try
				{
					modeClass = EngineRefs.ssf2("modes.ExpansionEventOrchestrator");
				}
				catch (orchErr:*)
				{
					modeClass = RM["getResourceByID"]("event_mode").getProp("mode");
				};
				if (!(modeClass is Class))
				{
					modeClass = RM["getResourceByID"]("event_mode").getProp("mode");
				};
				game = new GameClass(MainClass.MAXPLAYERS, ModeClass.EVENT);
				mode = new EventModeClass(game, {"eventMatchID": eventId}, {"classAPI": modeClass});
				mode.PreviousMenu = MC["eventMenu"];
				try
				{
					SoundQueue = EngineRefs.ssf2("audio.SoundQueue") as Class;
					SoundQueue.instance.playSoundEffect("menu_selectstage");
					SoundQueue.instance.playSoundEffect("menu_crowd");
				}
				catch (sfxErr:*)
				{
				};
				trace("[event_expansions] startEvent " + eventId);
			}
			catch (err:*)
			{
				logLine("[event_expansions] startEvent failed: " + err);
				showEventMenuExpansions();
			};
		}

		private function logLine(line:String):void
		{
			var MH:Class;
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

		private function ensureMergedIntoEventList():void
		{
			var RM:Class;
			var list:Array;
			var packIds:Array;
			var i:int;
			var id:String;
			var entry:Object;
			var slim:Object;
			var found:Boolean;
			var j:int;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager") as Class;
				list = RM["getResourceByID"]("event_mode").getProp("eventList") as Array;
				if (!list)
				{
					return;
				};
				packIds = ExpansionEventRegistry.getPackIds();
				i = 0;
				while (i < packIds.length)
				{
					id = String(packIds[i]);
					entry = ExpansionEventRegistry.findEventEntry(id);
					if (!entry || !(entry.classAPI is Class))
					{
						i++;
						continue;
					};
					slim = {
						"id": entry.id,
						"name": entry.name,
						"description": entry.description != null ? entry.description : "",
						"creator": entry.creator != null ? entry.creator : "",
						"expansion": true,
						"classAPI": entry.classAPI,
						"chooseCharacter": entry.chooseCharacter === true
					};
					found = false;
					j = 0;
					while (j < list.length)
					{
						if (list[j] && list[j].id === id)
						{
							list[j].classAPI = slim.classAPI;
							list[j].expansion = true;
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
			}
			catch (err:*)
			{
				trace("[event_expansions] merge list: " + err);
			};
		}

		private function showEventMenuExpansions():void
		{
			var MC:Class;
			var menu:*;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController") as Class;
				menu = MC["eventMenu"];
				if (menu && "setListMode" in menu)
				{
					menu.setListMode("expansions");
				};
				if (menu && !menu.isOnscreen())
				{
					menu.show();
				};
			}
			catch (err:*)
			{
				trace("[event_expansions] showEventMenu: " + err);
			};
		}

		private function hideMenu(menu:*):void
		{
			try
			{
				if (menu && "removeSelf" in menu)
				{
					menu.removeSelf();
				};
			}
			catch (err:*)
			{
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
			try
			{
				return menu && ("setExpansionList" in menu) && ("getListMode" in menu);
			}
			catch (err2:*)
			{
			};
			return false;
		}

		private function setFlag(id:String, value:*):void
		{
			if (m_host && m_host.setSessionFlag is Function)
			{
				m_host.setSessionFlag(id, value);
			};
		}

		private function getFlag(id:String, defaultValue:* = undefined):*
		{
			if (m_host && m_host.getSessionFlag is Function)
			{
				return m_host.getSessionFlag(id, defaultValue);
			};
			return defaultValue;
		}
	}
}
