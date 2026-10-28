package
{
	import flash.filesystem.File;
	import flash.filesystem.FileStream;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/**
	 * catalog.json: menus, modes, stages, items and music for the Mod Manager.
	 */
	internal class StreamCatalog
	{
		private var core:Ssf2StreamMod;
		private static const CATALOG_MENUS:Array = [
			{"id": "home", "label": "(default / home)"},
			{"id": "group", "label": "Group"},
			{"id": "online", "label": "Online"},
			{"id": "data", "label": "Data"},
			{"id": "options", "label": "Options"},
			{"id": "controls", "label": "Controls"},
			{"id": "vault", "label": "Vault"},
			{"id": "solo", "label": "Solo"},
			{"id": "versus_css", "label": "Versus CSS"},
			{"id": "training_css", "label": "Training CSS"},
			{"id": "classic", "label": "Classic"},
			{"id": "allstar", "label": "All-Star"},
			{"id": "btt", "label": "Break the Targets"},
			{"id": "hrc", "label": "Home-Run Contest"},
			{"id": "multiman", "label": "Multi-Man"},
			{"id": "crystal", "label": "Crystal Smash"},
			{"id": "rttf", "label": "Race to the Finish"},
			{"id": "arena", "label": "Arena"}
		];

		private static const SPECIAL_MODE_FLAGS:Array = [
			{"id": "MINI", "label": "Mini", "bit": 1},
			{"id": "MEGA", "label": "Mega", "bit": 2},
			{"id": "SLOW", "label": "Slow", "bit": 4},
			{"id": "LIGHTNING", "label": "Lightning", "bit": 8},
			{"id": "VAMPIRE", "label": "Vampire", "bit": 16},
			{"id": "VENGEANCE", "label": "Vengeance", "bit": 32},
			{"id": "FREEZE", "label": "Freeze", "bit": 64},
			{"id": "EGG", "label": "Egg", "bit": 128},
			{"id": "DRAMATIC", "label": "Dramatic", "bit": 256},
			{"id": "TURBO", "label": "Turbo", "bit": 512},
			{"id": "INVISIBLE", "label": "Invisible", "bit": 1024},
			{"id": "METAL", "label": "Metal", "bit": 2048},
			{"id": "LIGHT", "label": "Light", "bit": 4096},
			{"id": "HEAVY", "label": "Heavy", "bit": 8192},
			{"id": "SSF1", "label": "SSF1", "bit": 16384}
		];

		public function StreamCatalog(owner:Ssf2StreamMod)
		{
			core = owner;
		}

		internal function dumpCatalog():void
		{
			var RM:Class;
			var mappings:*;
			var out:Object;
			var chars:Array;
			var stages:Array;
			var music:Array;
			var id:String;
			var entry:*;
			var label:String;
			var file:File;
			var stream:FileStream;
			chars = [];
			stages = [];
			music = [];
			try
			{
				RM = EngineRefs.ResourceManager as Class;
				mappings = RM["getResourceByID"]("mappings").getProp("metadata");
			}
			catch (rmErr:*)
			{
				log("dumpCatalog: no ResourceManager yet — " + rmErr);
				return;
			};
			if (!mappings)
			{
				log("dumpCatalog: mappings missing");
				return;
			};
			try
			{
				if (mappings.character)
				{
					for (id in mappings.character)
					{
						entry = mappings.character[id];
						label = entry && entry.name ? String(entry.name) : id;
						chars.push({"id": id, "label": label});
					};
				};
				if (mappings.stage)
				{
					for (id in mappings.stage)
					{
						entry = mappings.stage[id];
						label = entry && entry.name ? String(entry.name) : id;
						stages.push({"id": id, "label": label});
					};
				};
				if (mappings.music)
				{
					for (id in mappings.music)
					{
						music.push({"id": id, "label": core.musicCtl.prettyMusicLabel(id)});
					};
				};
			}
			catch (mapErr:*)
			{
				log("dumpCatalog map walk: " + mapErr);
			};
			chars.sortOn(["label", "id"], Array.CASEINSENSITIVE);
			stages.sortOn(["label", "id"], Array.CASEINSENSITIVE);
			music.sortOn(["label", "id"], Array.CASEINSENSITIVE);
			out = {
				"characters": chars,
				"stages": stages,
				"music": music,
				"menus": CATALOG_MENUS,
				"items": readItemsList(),
				"targetStages": buildTargetStagesCatalog(RM, mappings),
				"hrcStages": readModeStageList(RM, "homeruncontest_mode", "hrcStageList"),
				"crystalStages": readModeStageList(RM, "crystals_mode", "crystalStageList"),
				"multimanModes": [
					{"id": "man10", "label": "10-Man"},
					{"id": "man100", "label": "100-Man"},
					{"id": "min3", "label": "3-Minute"},
					{"id": "endless", "label": "Endless"},
					{"id": "cruel", "label": "Cruel"}
				],
				"arenaModes": [
					{"id": "soccer", "label": "Soccer"},
					{"id": "basketball", "label": "Basketball"}
				],
				"difficulties": [
					{"id": "EASY", "label": "Easy", "value": 1},
					{"id": "NORMAL", "label": "Normal", "value": 2},
					{"id": "HARD", "label": "Hard", "value": 3},
					{"id": "INSANE", "label": "Insane", "value": 5}
				],
				"specialModes": SPECIAL_MODE_FLAGS,
				"source": "live",
				"writtenUtc": new Date().toUTCString()
			};
			try
			{
				file = core.bridgeFile("catalog.json");
				if (!file)
				{
					log("dumpCatalog: no writable bridge dir");
					return;
				};
				if (!JsonFile.write(file, out))
				{
					log("dumpCatalog write: failed " + file.nativePath);
					return;
				};
				log("catalog dumped chars=" + chars.length + " stages=" + stages.length + " music=" + music.length);
			}
			catch (writeErr:*)
			{
				log("dumpCatalog write: " + writeErr);
			};
		}

		private function readItemsList():Array
		{
			var out:Array;
			var itemsListCls:Class;
			var data:Array;
			var i:int;
			var entry:*;
			var label:String;
			out = [];
			try
			{
				itemsListCls = EngineRefs.ssf2("items.ItemsListData") as Class;
				data = itemsListCls ? (itemsListCls["DATA"] as Array) : null;
				if (!data)
				{
					return (out);
				};
				i = 0;
				while (i < data.length)
				{
					entry = data[i];
					label = entry && entry.displayName ? String(entry.displayName) : ("item_" + i);
					out.push({"id": String(i), "label": label, "value": i});
					i++;
				};
			}
			catch (err:*)
			{
			};
			return (out);
		}

		internal function readModeStageList(RM:Class, resId:String, prop:String):Array
		{
			var res:*;
			var list:Array;
			var out:Array;
			var i:int;
			var item:*;
			var id:String;
			var label:String;
			out = [];
			if (!RM)
			{
				return (out);
			};
			try
			{
				res = RM["getResourceByID"](resId);
				if (!res || !res["getProp"])
				{
					return (out);
				};
				list = res.getProp(prop) as Array;
				if (!list)
				{
					return (out);
				};
				i = 0;
				while (i < list.length)
				{
					item = list[i];
					if (item)
					{
						id = item.id != null ? String(item.id) : String(item);
						label = item.name != null ? String(item.name) : id;
						out.push({"id": id, "label": label});
					};
					i++;
				};
			}
			catch (err:*)
			{
			};
			return (out);
		}

		/**
		 * BTT dropdown: Level 1–4 from mode list (no meta "Character"),
		 * plus every character targettest_* stage that exists.
		 */
		private function buildTargetStagesCatalog(RM:Class, mappings:*):Array
		{
			var out:Array;
			var levels:Array;
			var charsOnly:Array;
			var i:int;
			var item:*;
			var id:String;
			var low:String;
			var charId:String;
			var entry:*;
			var label:String;
			var chars:Object;
			out = [];
			charsOnly = [];
			levels = readModeStageList(RM, "targets_mode", "targetStageList");
			i = 0;
			while (i < levels.length)
			{
				item = levels[i];
				id = item ? String(item["id"] || "") : "";
				low = id.toLowerCase();
				if (id.length > 0 && low != "character")
				{
					out.push(item);
				};
				i++;
			};
			chars = mappings && mappings.character ? mappings.character : null;
			if (mappings && mappings.stage)
			{
				for (id in mappings.stage)
				{
					low = String(id).toLowerCase();
					if (low.indexOf("targettest_") != 0)
					{
						continue;
					};
					charId = String(id).substr("targettest_".length);
					if (charId.length < 1 || charId == "2" || charId == "3" || charId == "4")
					{
						continue;
					};
					label = charId;
					if (chars && chars[charId] && chars[charId].name)
					{
						label = String(chars[charId].name);
					}
					else
					{
						entry = mappings.stage[id];
						if (entry && entry.name)
						{
							label = String(entry.name);
						};
					};
					charsOnly.push({"id": id, "label": label});
				};
			};
			charsOnly.sortOn(["label", "id"], Array.CASEINSENSITIVE);
			i = 0;
			while (i < charsOnly.length)
			{
				out.push(charsOnly[i]);
				i++;
			};
			return (out);
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
