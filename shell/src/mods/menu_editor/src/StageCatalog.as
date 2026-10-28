package
{
	import flash.text.TextField;
	import flash.text.TextFormat;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Which stages exist and what they are called: display names and tile labels, expansion
	 * and registry stages, extra stages with files, and the Add popup order.
	 */
	public class StageCatalog
	{
		private var mod:StageEditorMod;

		public function StageCatalog(owner:StageEditorMod)
		{
			mod = owner;
		}

		internal function unusedIds():Array
		{
			var mappings:Object;
			var all:Array;
			var used:Array;
			var out:Array;
			var i:int;
			var id:String;
			mappings = EditorEngine.mappings();
			out = [];
			if (!mappings)
			{
				return (out);
			};
			all = mod.m_store.collectIds(mappings, mod.m_book.otherPageRows(mod.m_livePage));
			used = GridRows.flatten(mod.m_book.pageRows(mod.m_livePage));
			i = 0;
			while (i < all.length)
			{
				id = String(all[i]);
				if (used.indexOf(id) < 0 && (mod.m_showExtraStages || !mod.m_store.isExtraAddStage(id)))
				{
					out.push(id);
				};
				i++;
			};
			return (sortAddIds(out));
		}

		private function vanillaDefaultOrder():Array
		{
			var out:Array;
			var i:int;
			out = [];
			if (!mod.m_defaultGrid)
			{
				return (out);
			};
			i = 0;
			while (i < mod.m_defaultGrid.length)
			{
				GridRows.appendMissing(out, GridRows.flatten(mod.m_defaultGrid[i] as Array), []);
				i++;
			};
			return (out);
		}

		private function compareIdAlpha(a:*, b:*):int
		{
			var sa:String;
			var sb:String;
			sa = String(a).toLowerCase();
			sb = String(b).toLowerCase();
			if (sa < sb)
			{
				return (-1);
			};
			if (sa > sb)
			{
				return (1);
			};
			return (0);
		}

		private function sortAddIds(ids:Array):Array
		{
			var vanilla:Array;
			var rest:Array;
			var xp:Array;
			var out:Array;
			var i:int;
			var id:String;
			out = [];
			rest = [];
			xp = [];
			if (!ids)
			{
				return (out);
			};
			vanilla = vanillaDefaultOrder();
			i = 0;
			while (i < vanilla.length)
			{
				id = String(vanilla[i]);
				if (ids.indexOf(id) >= 0 && out.indexOf(id) < 0)
				{
					out.push(id);
				};
				i++;
			};
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (!id || out.indexOf(id) >= 0)
				{
					i++;
					continue;
				};
				if (isRegistryStage(id))
				{
					xp.push(id);
				}
				else
				{
					rest.push(id);
				};
				i++;
			};
			rest.sort(compareIdAlpha);
			xp.sort(compareIdAlpha);
			i = 0;
			while (i < rest.length)
			{
				out.push(rest[i]);
				i++;
			};
			i = 0;
			while (i < xp.length)
			{
				out.push(xp[i]);
				i++;
			};
			return (out);
		}

		internal function ensureStageTitles():void
		{
			var mappings:Object;
			var id:String;
			var name:String;
			var SM:Class;
			var ids:Array;
			var i:int;
			mappings = EditorEngine.mappings();
			try
			{
				SM = EngineRefs.ssf2("menus.StageSelectMenu") as Class;
			}
			catch (err:*)
			{
				SM = null;
			};
			ids = [];
			if (mappings && mappings.stage)
			{
				for (id in mappings.stage)
				{
					if (ids.indexOf(id) < 0)
					{
						ids.push(id);
					};
				};
			};
			GridRows.appendMissing(ids, mod.m_book.flattenAllPages(), []);
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				name = stageDisplayName(id);
				if (mappings && mappings.stage && mappings.stage[id] && (!mappings.stage[id].name || String(mappings.stage[id].name).length <= 0))
				{
					mappings.stage[id].name = name;
				};
				if (SM && name)
				{
					try
					{
						SM["rememberStageName"](id, name);
					}
					catch (nErr:*)
					{
					};
				};
				i++;
			};
		}

		internal function stageDisplayName(id:String):String
		{
			var mappings:Object;
			var entry:Object;
			var n:String;
			var SM:Class;
			if (!id)
			{
				return ("");
			};
			mappings = EditorEngine.mappings();
			entry = mappings && mappings.stage ? mappings.stage[id] : null;
			if (entry && entry.name && String(entry.name).length > 0)
			{
				return (String(entry.name));
			};
			try
			{
				SM = EngineRefs.ssf2("menus.StageSelectMenu") as Class;
				n = SM ? String(SM["stageName"](id) || "") : "";
				if (n && n != "null")
				{
					return (n);
				};
			}
			catch (err:*)
			{
			};
			if (id.indexOf("targettest_") == 0)
			{
				return ("BTT " + prettyStageToken(id.substr(11)));
			};
			if (id.indexOf("targettest") == 0)
			{
				return ("Target Test" + (id.length > 10 ? " " + id.substr(10) : ""));
			};
			return (prettyStageToken(id));
		}

		private function prettyStageToken(raw:String):String
		{
			var s:String;
			s = raw || "";
			while (s.indexOf("_") >= 0)
			{
				s = s.replace("_", " ");
			};
			if (s.length > 0)
			{
				s = s.charAt(0).toUpperCase() + s.substr(1);
			};
			return (s);
		}

		internal function makeStageTileLabel(id:String, w:Number, h:Number, x:Number, y:Number):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.x = x + 2;
			tf.y = y + 2;
			tf.width = w - 4;
			tf.height = h - 4;
			tf.multiline = true;
			tf.wordWrap = true;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", 7, 0xF2F2F2, true, null, null, null, null, "center");
			tf.text = stageDisplayName(id);
			return (tf);
		}

		internal function stageExpansionList():Array
		{
			var RM:*;
			try
			{
				RM = EngineRefs.ResourceManager;
				if (RM && RM.getStageExpansions is Function)
				{
					return (RM.getStageExpansions() as Array);
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal function isRegistryStage(id:String):Boolean
		{
			var extras:Array;
			var i:int;
			if (!id)
			{
				return (false);
			};
			extras = stageExpansionList();
			i = 0;
			while (extras && i < extras.length)
			{
				if (extras[i] && String(extras[i].id) == id)
				{
					return (true);
				};
				i++;
			};
			return (false);
		}

		internal function hasStageFile(id:String):Boolean
		{
			var RM:Class;
			var res:*;
			if (!id || id == "random" || id == "xpstage")
			{
				return (false);
			};
			try
			{
				RM = EngineRefs.ResourceManager as Class;
				res = RM["getResourceByID"](id);
				if (res && res["FileName"])
				{
					return (true);
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function collectExtraStages():Array
		{
			var mappings:Object;
			var used:Object;
			var out:Array;
			var id:String;
			var i:int;
			var ids:Array;
			var name:String;
			mappings = EditorEngine.mappings();
			out = [];
			used = {};
			if (!mappings || !mappings.stage)
			{
				return (out);
			};
			ids = mod.m_book.flattenAllPages();
			i = 0;
			while (i < ids.length)
			{
				used[String(ids[i])] = true;
				i++;
			};
			for (id in mappings.stage)
			{
				if (used[id] || !hasStageFile(id))
				{
					continue;
				};
				name = String((mappings.stage[id] && mappings.stage[id].name) ? mappings.stage[id].name : id);
				out.push({
					"id": id,
					"name": name
				});
			};
			out.sortOn(["name", "id"], Array.CASEINSENSITIVE);
			return (out);
		}
	}
}
