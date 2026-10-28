package
{
	import flash.events.MouseEvent;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Event mode launches: event list, event button click, character override.
	 */
	internal class StreamEvents
	{
		private var core:Ssf2StreamMod;
		private var m_eventMenu:*;
		private var m_eventIndex:int;

		public function StreamEvents(owner:Ssf2StreamMod)
		{
			core = owner;
		}

		internal function startEventMatch(eventId:String):Boolean
		{
			var MC:Class;
			var RM:Class;
			var menu:*;
			var index:int;
			var onscreen:Boolean;
			if (core.m_eventStarted)
			{
				return (true);
			};
			if (!eventId || eventId.length < 1)
			{
				log("startEventMatch: no event id");
				return (false);
			};
			if (core.m_eventClickPending)
			{
				core.m_eventClickTries++;
				if (core.m_eventClickTries > 240)
				{
					log("event character preload timed out");
					onEventCharLoaded();
				};
				return (core.m_eventStarted);
			};
			try
			{
				MC = core.cssCtl.menuController();
				RM = EngineRefs.ResourceManager as Class;
				menu = MC ? MC["eventMenu"] : null;
				if (!menu || !menu.show || !RM || !RM["getResourceByID"]("event_mode"))
				{
					return (false);
				};
				onscreen = false;
				try
				{
					onscreen = Boolean(menu["isOnscreen"] && menu["isOnscreen"]());
				}
				catch (screenErr:*)
				{
				};
				if (!onscreen)
				{
					try
					{
						MC["disposeAllMenus"]();
					}
					catch (dispErr:*)
					{
					};
					menu = MC["eventMenu"];
					if (!menu || !menu.show)
					{
						return (false);
					};
					menu.show();
				};
				if (menu["startEventById"] is Function)
				{
					if (menu["startEventById"](eventId))
					{
						log("started event " + eventId);
						core.m_eventStarted = true;
						return (true);
					};
					core.m_eventClickTries++;
					if (core.m_eventClickTries > 180)
					{
						log("startEventById: " + eventId + " not on the menu");
						core.m_eventStarted = true;
						return (true);
					};
					return (false);
				};
				index = findEventIndex(eventId);
				if (index < 0)
				{
					log("startEventMatch: " + eventId + " not in event list");
					return (false);
				};
				if (!findNamed(menu["SubMenu"], "e" + index))
				{
					core.m_eventClickTries++;
					if (core.m_eventClickTries > 180)
					{
						log("startEventMatch: button missing for " + eventId);
						core.m_eventStarted = true;
						return (true);
					};
					return (false);
				};
				if (eventChoosesCharacter(index))
				{
					core.m_eventOverride = "";
					if (!clickEventButton(menu, index))
					{
						return (false);
					};
					log("event " + eventId + " chooseCharacter");
					core.m_eventStarted = true;
					return (true);
				};
				if (core.m_eventOverride && core.m_eventOverride.length > 0)
				{
					m_eventMenu = menu;
					m_eventIndex = index;
					core.m_eventClickPending = true;
					RM["queuePlayerCharacterResource"]({
						"character": core.m_eventOverride,
						"costume": -1,
						"expansion": -1,
						"exist": true
					}, 0);
					RM["load"]({"oncomplete": onEventCharLoaded});
					log("preloading event override " + core.m_eventOverride);
					return (false);
				};
				if (!clickEventButton(menu, index))
				{
					return (false);
				};
				log("started event " + eventId);
				core.m_eventStarted = true;
				return (true);
			}
			catch (err:*)
			{
				log("startEventMatch failed: " + err);
				return (false);
			};
			return (false);
		}

		private function onEventCharLoaded(e:* = null):void
		{
			core.m_eventClickPending = false;
			if (clickEventButton(m_eventMenu, m_eventIndex))
			{
				log("started event with override " + core.m_eventOverride);
			}
			else
			{
				log("event override click failed");
			};
			core.m_eventStarted = true;
		}

		private function readEventList():Array
		{
			var RM:Class;
			var res:*;
			try
			{
				RM = EngineRefs.ResourceManager as Class;
				res = RM ? RM["getResourceByID"]("event_mode") : null;
				if (res)
				{
					return (res["getProp"]("eventList") as Array);
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private function findEventIndex(eventId:String):int
		{
			var list:Array;
			var i:int;
			var item:*;
			list = readEventList();
			if (!list)
			{
				return (-1);
			};
			i = 0;
			while (i < list.length)
			{
				item = list[i];
				if (item && String(item["id"] || "") == eventId)
				{
					return (i);
				};
				i++;
			};
			return (-1);
		}

		private function eventChoosesCharacter(index:int):Boolean
		{
			var list:Array;
			list = readEventList();
			if (!list || index < 0 || index >= list.length || !list[index])
			{
				return (false);
			};
			try
			{
				return (Boolean(list[index]["chooseCharacter"]));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function clickEventButton(menu:*, index:int):Boolean
		{
			var btn:*;
			if (!menu)
			{
				return (false);
			};
			btn = findNamed(menu["SubMenu"], "e" + index);
			if (!btn)
			{
				return (false);
			};
			try
			{
				btn["visible"] = true;
				btn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
				return (true);
			}
			catch (err:*)
			{
				log("clickEventButton: " + err);
			};
			return (false);
		}

		private function findNamed(root:*, name:String):*
		{
			var i:int;
			var child:*;
			var hit:*;
			if (!root)
			{
				return (null);
			};
			try
			{
				if (String(root["name"]) == name)
				{
					return (root);
				};
				if (root["numChildren"] == undefined)
				{
					return (null);
				};
				i = 0;
				while (i < int(root["numChildren"]))
				{
					child = root["getChildAt"](i);
					hit = findNamed(child, name);
					if (hit)
					{
						return (hit);
					};
					i++;
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function applyEventCharacterOverride(ctx:Object):void
		{
			var GC:Class;
			var ModeCls:Class;
			var game:*;
			var settings:*;
			if (!core.m_eventOverride || core.m_eventOverride.length < 1)
			{
				return;
			};
			try
			{
				GC = EngineRefs.GameController as Class;
				ModeCls = EngineRefs.ssf2("enums.Mode") as Class;
				game = ctx && ctx["game"] ? ctx["game"] : (GC ? GC["currentGame"] : null);
				if (!game || !game["PlayerSettings"] || game["PlayerSettings"]["length"] < 1)
				{
					return;
				};
				if (ModeCls && game["GameMode"] != ModeCls["EVENT"])
				{
					return;
				};
				settings = game["PlayerSettings"];
				settings[0]["character"] = core.m_eventOverride;
				settings[0]["costume"] = -1;
				settings[0]["expansion"] = -1;
				settings[0]["exist"] = true;
				settings[0]["human"] = true;
				core.cssCtl.preparePlayerCostume(core.m_eventOverride, settings, 0);
				log("event override character " + core.m_eventOverride);
			}
			catch (err:*)
			{
				log("event override: " + err);
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
