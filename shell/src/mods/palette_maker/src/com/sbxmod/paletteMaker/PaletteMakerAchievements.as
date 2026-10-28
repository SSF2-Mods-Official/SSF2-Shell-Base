package com.sbxmod.paletteMaker
{
	import flash.net.SharedObject;
	import flash.utils.getTimer;

	/**
	 * Palette Maker–only achievements, cookies, and hints.
	 */
	public class PaletteMakerAchievements
	{
		private static const SO_NAME:String = "ssf2_palette_maker_achievements";
		private static const COOKIES_PER_SAVE:int = 5;

		private static var s_catalog:Array = null;
		private static var s_byId:Object = null;
		private static var s_cookies:int = 0;
		private static var s_unlocked:Object = null;
		private static var s_hints:Object = null;
		private static var s_counters:Object = null;
		private static var s_flags:Object = null;
		private static var s_loaded:Boolean = false;

		/** Session-only state (reset on editor show). */
		private static var s_sessionTools:Object = null;
		private static var s_sessionLastTool:String = "";
		private static var s_sessionUndidAfterRedo:Boolean = false;
		private static var s_sessionJustRedid:Boolean = false;
		private static var s_sessionExported:Boolean = false;
		private static var s_sessionImported:Boolean = false;
		private static var s_sessionCreatedGroup:Boolean = false;
		private static var s_sessionDeletedGroup:Boolean = false;
		private static var s_sessionFrozeThenPicked:Boolean = false;
		private static var s_sessionFroze:Boolean = false;
		private static var s_sessionIsolateHeld:Boolean = false;
		private static var s_sessionSelectAllThenInvert:Boolean = false;
		private static var s_sessionDidSelectAll:Boolean = false;
		private static var s_sessionMagSelects:int = 0;
		private static var s_sessionOpenedCs:Boolean = false;

		public static function resetSession():void
		{
			s_sessionTools = {};
			s_sessionLastTool = "";
			s_sessionUndidAfterRedo = false;
			s_sessionJustRedid = false;
			s_sessionExported = false;
			s_sessionImported = false;
			s_sessionCreatedGroup = false;
			s_sessionDeletedGroup = false;
			s_sessionFrozeThenPicked = false;
			s_sessionFroze = false;
			s_sessionIsolateHeld = false;
			s_sessionSelectAllThenInvert = false;
			s_sessionDidSelectAll = false;
			s_sessionMagSelects = 0;
			s_sessionOpenedCs = false;
		}

		public static function getCookies():int
		{
			ensureLoaded();
			return s_cookies;
		}

		public static function getCatalog():Array
		{
			ensureCatalog();
			return s_catalog;
		}

		public static function isUnlocked(id:String):Boolean
		{
			ensureLoaded();
			return s_unlocked && s_unlocked[id] != null;
		}

		public static function hasHint(id:String):Boolean
		{
			ensureLoaded();
			return s_hints && s_hints[id] == true;
		}

		public static function getUnlockedCount():int
		{
			var id:String;
			var n:int;
			ensureLoaded();
			n = 0;
			for (id in s_unlocked)
			{
				n++;
			};
			return n;
		}

		/** Public unlock for edge-case hooks that don't map cleanly to track events. */
		public static function unlock(id:String):void
		{
			ensureLoaded();
			tryUnlock(id);
		}

		public static function buyHint(id:String):Boolean
		{
			var def:Object;
			var cost:int;
			ensureLoaded();
			ensureCatalog();
			def = s_byId[id];
			if (!def || isUnlocked(id) || hasHint(id))
			{
				return false;
			};
			cost = int(def.cookieHintCost);
			if (cost <= 0)
			{
				cost = 12;
			};
			if (s_cookies < cost)
			{
				try { Ssf2.MultiplayerManager.notify("Need " + cost + " cookies for a hint"); } catch (e:Error) { };
				return false;
			};
			s_cookies -= cost;
			s_hints[id] = true;
			incCounter("hints_bought", 1);
			flush();
			try { Ssf2.MultiplayerManager.notify("Hint unlocked (−" + cost + " cookies)"); } catch (e2:Error) { };
			track("hint_bought", { "id": id });
			return true;
		}

		public static function awardCookies(n:int, reason:String = null):void
		{
			ensureLoaded();
			if (n <= 0)
			{
				return;
			};
			s_cookies += n;
			incCounter("cookies_earned", n);
			flush();
			try
			{
				Ssf2.MultiplayerManager.notify("+" + n + " cookies" + (reason ? (" — " + reason) : ""));
			}
			catch (err:Error)
			{
			};
			checkCookieMilestones();
			if (s_cookies >= 100) tryUnlock("secret_cookie_hoard");
			if (s_cookies >= 50) tryUnlock("flavor_cookie_fifty");
			if (s_cookies >= 20) tryUnlock("flavor_cookie_twenty");
		}

		public static function track(event:String, data:Object = null):void
		{
			ensureLoaded();
			ensureCatalog();
			if (!s_sessionTools)
			{
				resetSession();
			};
			if (!data)
			{
				data = {};
			};
			switch (event)
			{
				case "tool_used":
					trackToolUsed(data);
					break;
				case "costume_saved":
					trackCostumeSaved(data);
					break;
				case "palette_flash_cycle":
					tryUnlock("secret_flash_costume");
					break;
				case "group_created":
					trackGroupCreated(data);
					break;
				case "group_deleted":
					s_sessionDeletedGroup = true;
					incCounter("groups_deleted", 1);
					tryUnlock("group_delete");
					if (s_sessionCreatedGroup)
					{
						tryUnlock("ritual_create_then_delete_group");
					};
					break;
				case "group_reordered":
					incCounter("groups_reordered", 1);
					tryUnlock("group_reorder");
					break;
				case "group_locked":
					tryUnlock("group_lock");
					break;
				case "group_match_all":
					tryUnlock("group_match_all");
					break;
				case "isolate":
					if (data.on)
					{
						s_sessionIsolateHeld = true;
						tryUnlock("ritual_isolate_on");
					};
					break;
				case "freeze":
					if (data.on)
					{
						s_sessionFroze = true;
						tryUnlock("ritual_freeze");
					};
					break;
				case "sheet_import":
					trackSheetImport(data);
					break;
				case "sheet_export":
					s_sessionExported = true;
					incCounter("sheet_exports", 1);
					tryUnlock("sheet_export_first");
					if (s_sessionImported)
					{
						tryUnlock("ritual_export_then_import");
					};
					break;
				case "selection_inverted":
					if (s_sessionDidSelectAll)
					{
						tryUnlock("ritual_invert_after_select_all");
					};
					break;
				case "select_all":
					s_sessionDidSelectAll = true;
					break;
				case "deselect_all":
					if (int(data.selectedCount) <= 0)
					{
						tryUnlock("secret_deselect_nothing");
					};
					break;
				case "magnifier_select":
					trackMagnifierSelect(data);
					break;
				case "settings_opened":
					tryUnlock("ritual_open_settings");
					break;
				case "achievements_opened":
					if (getUnlockedCount() == 0)
					{
						tryUnlock("secret_peek_achievements");
					};
					tryUnlock("ritual_open_achievements");
					break;
				case "hint_bought":
					if (getUnlockedCount() == 0)
					{
						tryUnlock("secret_hint_before_unlock");
					};
					if (getCounter("hints_bought") >= 5) tryUnlock("mile_hints_5");
					if (getCounter("hints_bought") >= 20) tryUnlock("mile_hints_20");
					break;
				case "highlight_unchanged":
					if (data.on && s_sessionIsolateHeld)
					{
						tryUnlock("ritual_isolate_highlight");
					};
					break;
				case "shortcut_used":
					tryUnlock("ritual_use_shortcut");
					incCounter("shortcuts_used", 1);
					if (getCounter("shortcuts_used") >= 10)
					{
						tryUnlock("mile_shortcuts_10");
					};
					break;
			};
			flush();
		}

		private static function trackToolUsed(data:Object):void
		{
			var toolId:String;
			var selectedCount:int;
			toolId = String(data.toolId || "");
			if (toolId)
			{
				s_sessionTools[toolId] = true;
				s_sessionLastTool = toolId;
				markFlag("tool_" + toolId);
				incCounter("tool_" + toolId, 1);
				incCounter("tools_total", 1);
				if (toolId == "UD")
				{
					incCounter("undos", 1);
					if (s_sessionJustRedid)
					{
						s_sessionUndidAfterRedo = true;
						tryUnlock("ritual_undo_after_redo");
					};
					s_sessionJustRedid = false;
					if (getCounter("undos") >= 100)
					{
						tryUnlock("mile_undo_100");
					};
				}
				else if (toolId == "RD")
				{
					s_sessionJustRedid = true;
					incCounter("redos", 1);
				}
				else if (toolId == "SA")
				{
					s_sessionDidSelectAll = true;
					tryUnlock("ritual_select_all");
				}
				else if (toolId == "IS")
				{
					if (s_sessionDidSelectAll)
					{
						s_sessionSelectAllThenInvert = true;
						tryUnlock("ritual_invert_after_select_all");
					};
					tryUnlock("ritual_invert");
				}
				else if (toolId == "DA")
				{
					selectedCount = int(data.selectedCount);
					if (selectedCount <= 0)
					{
						tryUnlock("secret_deselect_nothing");
					};
				}
				else if (toolId == "DI")
				{
					if (data.on)
					{
						s_sessionIsolateHeld = true;
						tryUnlock("ritual_isolate_on");
					};
				}
				else if (toolId == "FZ")
				{
					if (data.on)
					{
						s_sessionFroze = true;
						tryUnlock("ritual_freeze");
					};
				}
				else if (toolId == "RB")
				{
					tryUnlock("ritual_recolor_base");
				}
				else if (toolId == "RO")
				{
					tryUnlock("ritual_recolor_og");
				}
				else if (toolId == "RA")
				{
					tryUnlock("ritual_reset_active");
				}
				else if (toolId == "CS")
				{
					s_sessionOpenedCs = true;
					tryUnlock("ritual_open_cs");
				}
				else if (toolId == "ST")
				{
					tryUnlock("ritual_open_settings");
				};
				checkAllToolsSession();
				checkToolMilestones(toolId);
			};
		}

		private static function trackCostumeSaved(data:Object):void
		{
			var stats:String;
			var name:String;
			var author:String;
			stats = String(data.statsName || "");
			name = String(data.costumeName || "");
			author = String(data.author || "");
			incCounter("saves", 1);
			if (stats)
			{
				markFlag("char_" + stats);
				tryUnlock("roster_" + stats);
			};
			if (author && author.length > 0)
			{
				tryUnlock("ritual_save_with_author");
				markFlag("saved_with_author");
			};
			if (name && name.toLowerCase().indexOf("oc") >= 0)
			{
				tryUnlock("secret_oc_name");
			};
			if (data.flashCycle)
			{
				tryUnlock("secret_flash_costume");
			};
			if (s_sessionIsolateHeld)
			{
				tryUnlock("secret_isolate_session_save");
			};
			if (s_sessionFroze)
			{
				tryUnlock("ritual_save_while_frozen");
			};
			checkSaveMilestones();
			checkDistinctChars();
			// Cookies only for first save of a costume name — not overwrite spam.
			if (data.isNew == true)
			{
				awardCookies(COOKIES_PER_SAVE, "costume saved");
			};
		}

		private static function trackGroupCreated(data:Object):void
		{
			var groupCount:int;
			s_sessionCreatedGroup = true;
			incCounter("groups_created", 1);
			groupCount = int(data.groupCount);
			tryUnlock("group_first");
			if (groupCount >= 3) tryUnlock("group_3");
			if (groupCount >= 5) tryUnlock("group_5");
			if (groupCount >= 8) tryUnlock("group_8");
			if (groupCount >= 12) tryUnlock("group_12");
			if (s_sessionDeletedGroup)
			{
				tryUnlock("ritual_create_then_delete_group");
			};
		}

		private static function trackSheetImport(data:Object):void
		{
			var multi:Boolean;
			s_sessionImported = true;
			incCounter("sheet_imports", 1);
			multi = data.multi == true;
			tryUnlock("sheet_import_first");
			if (multi)
			{
				tryUnlock("sheet_import_multi");
			};
			if (s_sessionExported)
			{
				tryUnlock("ritual_export_then_import");
			};
		}

		private static function trackMagnifierSelect(data:Object):void
		{
			s_sessionMagSelects++;
			incCounter("mag_selects", 1);
			if (s_sessionFroze)
			{
				s_sessionFrozeThenPicked = true;
				tryUnlock("ritual_freeze_then_pick");
			};
			if (s_sessionMagSelects >= 25 && !s_sessionOpenedCs)
			{
				tryUnlock("ritual_mag_25_no_cs");
			};
			if (getCounter("mag_selects") >= 100)
			{
				tryUnlock("mile_mag_100");
			};
		}

		/** True if palette has a swap cycle / collision that can strobe colors. */
		public static function hasFlashCycle(paletteData:Object):Boolean
		{
			var map:Object;
			var sources:Array;
			var a:String;
			var b:String;
			var c:String;
			var i:int;
			var j:int;
			map = buildRgbMap(paletteData);
			if (!map)
			{
				return false;
			};
			sources = [];
			for (a in map)
			{
				sources.push(a);
			};
			i = 0;
			while (i < sources.length)
			{
				a = String(sources[i]);
				b = String(map[a]);
				if (a != b && map[b] != null)
				{
					c = String(map[b]);
					if (c == a)
					{
						return true;
					};
					// Replacement lands on another still-mapped source → order-dependent flash.
					if (b != a && c != b)
					{
						j = 0;
						while (j < sources.length)
						{
							if (String(sources[j]) == b && a != b)
							{
								return true;
							};
							j++;
						};
					};
				};
				i++;
			};
			return false;
		}

		private static function buildRgbMap(paletteData:Object):Object
		{
			var map:Object;
			var blocks:Array;
			var block:Object;
			var colors:Array;
			var repls:Array;
			var i:int;
			var src:uint;
			var dst:uint;
			var srcKey:String;
			var dstKey:String;
			if (!paletteData)
			{
				return null;
			};
			map = {};
			blocks = [paletteData.paletteSwap, paletteData.paletteSwapPA];
			for each (block in blocks)
			{
				if (!block || !(block.colors is Array) || !(block.replacements is Array))
				{
					continue;
				};
				colors = block.colors as Array;
				repls = block.replacements as Array;
				i = 0;
				while (i < colors.length && i < repls.length)
				{
					src = uint(colors[i]) & 0xFFFFFF;
					dst = uint(repls[i]) & 0xFFFFFF;
					srcKey = src.toString(16);
					dstKey = dst.toString(16);
					// Keep non-identity mappings; identity doesn't flash.
					if (src != dst)
					{
						map[srcKey] = dstKey;
					}
					else if (map[srcKey] == null)
					{
						map[srcKey] = dstKey;
					};
					i++;
				};
			};
			return map;
		}

		private static function tryUnlock(id:String):void
		{
			var def:Object;
			if (!id || isUnlocked(id))
			{
				return;
			};
			ensureCatalog();
			def = s_byId[id];
			if (!def)
			{
				return;
			};
			s_unlocked[id] = getTimer();
			flush();
			try
			{
				Ssf2.MultiplayerManager.notify("★ Achievement: " + String(def.title));
			}
			catch (nErr:Error)
			{
			};
			try
			{
				Ssf2.SoundQueue.instance.playSoundEffect("menu_unlock");
			}
			catch (sErr:Error)
			{
			};
			checkUnlockCountMilestones();
			if (s_cookies >= 20) tryUnlock("flavor_cookie_twenty");
			if (s_cookies >= 50) tryUnlock("flavor_cookie_fifty");
			if (s_cookies >= 100) tryUnlock("secret_cookie_hoard");
		}

		private static function checkUnlockCountMilestones():void
		{
			var n:int = getUnlockedCount();
			if (n >= 25) tryUnlock("mile_unlock_25");
			if (n >= 50) tryUnlock("mile_unlock_50");
			if (n >= 100) tryUnlock("mile_unlock_100");
		}

		private static function checkAllToolsSession():void
		{
			var needed:Array = ["UD", "RD", "DI", "FZ", "SA", "DA", "IS", "RA", "RB", "RO", "NG", "CS", "ST", "IC", "EC"];
			var t:String;
			for each (t in needed)
			{
				if (!s_sessionTools[t])
				{
					return;
				};
			};
			tryUnlock("secret_all_tools_session");
		}

		private static function checkToolMilestones(toolId:String):void
		{
			if (toolId == "NG" && getCounter("tool_NG") >= 10)
			{
				tryUnlock("mile_groups_tool_10");
			};
			if (toolId == "IS" && getCounter("tool_IS") >= 25)
			{
				tryUnlock("mile_invert_25");
			};
		}

		private static function checkSaveMilestones():void
		{
			var n:int = getCounter("saves");
			if (n >= 1) tryUnlock("mile_save_1");
			if (n >= 5) tryUnlock("mile_save_5");
			if (n >= 10) tryUnlock("mile_save_10");
			if (n >= 25) tryUnlock("mile_save_25");
			if (n >= 50) tryUnlock("mile_save_50");
			if (n >= 100) tryUnlock("mile_save_100");
		}

		private static function checkDistinctChars():void
		{
			var id:String;
			var n:int = 0;
			for (id in s_flags)
			{
				if (id && id.indexOf("char_") == 0)
				{
					n++;
				};
			};
			if (n >= 5) tryUnlock("mile_chars_5");
			if (n >= 10) tryUnlock("mile_chars_10");
			if (n >= 20) tryUnlock("mile_chars_20");
			if (n >= 30) tryUnlock("mile_chars_30");
			if (n >= 40) tryUnlock("mile_chars_40");
		}

		private static function checkCookieMilestones():void
		{
			var n:int = getCounter("cookies_earned");
			if (n >= 25) tryUnlock("mile_cookies_25");
			if (n >= 100) tryUnlock("mile_cookies_100");
			if (n >= 250) tryUnlock("mile_cookies_250");
			if (n >= 500) tryUnlock("mile_cookies_500");
		}

		private static function markFlag(key:String):void
		{
			if (!s_flags)
			{
				s_flags = {};
			};
			s_flags[key] = true;
		}

		private static function incCounter(key:String, by:int):void
		{
			if (!s_counters)
			{
				s_counters = {};
			};
			s_counters[key] = int(s_counters[key]) + by;
		}

		private static function getCounter(key:String):int
		{
			if (!s_counters)
			{
				return 0;
			};
			return int(s_counters[key]);
		}

		private static function ensureLoaded():void
		{
			var so:SharedObject;
			if (s_loaded)
			{
				return;
			};
			s_unlocked = {};
			s_hints = {};
			s_counters = {};
			s_flags = {};
			s_cookies = 0;
			try
			{
				so = SharedObject.getLocal(SO_NAME);
				if (so && so.data)
				{
					s_cookies = int(so.data.cookies);
					if (so.data.unlocked) s_unlocked = cloneSimple(so.data.unlocked);
					if (so.data.hints) s_hints = cloneSimple(so.data.hints);
					if (so.data.counters) s_counters = cloneSimple(so.data.counters);
					if (so.data.flags) s_flags = cloneSimple(so.data.flags);
				};
			}
			catch (err:Error)
			{
			};
			s_loaded = true;
			ensureCatalog();
		}

		private static function flush():void
		{
			var so:SharedObject;
			try
			{
				so = SharedObject.getLocal(SO_NAME);
				so.data.cookies = s_cookies;
				so.data.unlocked = cloneSimple(s_unlocked);
				so.data.hints = cloneSimple(s_hints);
				so.data.counters = cloneSimple(s_counters);
				so.data.flags = cloneSimple(s_flags);
				so.flush();
			}
			catch (err:Error)
			{
			};
		}

		private static function cloneSimple(src:Object):Object
		{
			var out:Object = {};
			var k:String;
			if (!src)
			{
				return out;
			};
			for (k in src)
			{
				out[k] = src[k];
			};
			return out;
		}

		private static function ensureCatalog():void
		{
			if (s_catalog)
			{
				return;
			};
			s_catalog = [];
			s_byId = {};
			buildCatalog();
		}

		private static function add(id:String, title:String, desc:String, hint:String, cost:int = 12, tags:Array = null):void
		{
			var def:Object;
			if (s_byId[id])
			{
				return;
			};
			def = {
				"id": id,
				"title": title,
				"desc": desc,
				"hint": hint,
				"cookieHintCost": cost,
				"tags": tags ? tags : []
			};
			s_catalog.push(def);
			s_byId[id] = def;
		}

		private static function buildCatalog():void
		{
			buildRoster();
			buildRituals();
			buildGroups();
			buildSheets();
			buildMilestones();
			buildSecrets();
			buildFlavorExtras();
		}

		private static function buildRoster():void
		{
			var roster:Array = [
				["mario", "Plumbing Remodel", "Save a costume for Mario.", "Someone in red overalls needs a new coat.", 10],
				["luigi", "Green Thread", "Save a costume for Luigi.", "The taller brother wants a palette.", 10],
				["peach", "Royal Repaint", "Save a costume for Peach.", "A princess deserves couture colors.", 10],
				["bowser", "Koopa Couture", "Save a costume for Bowser.", "Spiky royalty wants new scales.", 10],
				["yoshi", "Egg Dye", "Save a costume for Yoshi.", "A dino that swallows colors whole.", 10],
				["wario", "Garlic Gloss", "Save a costume for Wario.", "Greed looks good in new hues.", 10],
				["waluigi", "Wah-lette", "Save a costume for Waluigi.", "Lanky villain energy, recolored.", 10],
				["donkeykong", "Banana Peel Polish", "Save a costume for Donkey Kong.", "A barrel of fun needs a barrel of paint.", 10],
				["link", "Triforce Tint", "Save a costume for Link.", "Hero of Time, hero of swatches.", 10],
				["zelda", "Hyrule Hue", "Save a costume for Zelda.", "Wisdom wears a new shade.", 10],
				["sheik", "Shadow Veil", "Save a costume for Sheik.", "A disguise within a disguise.", 10],
				["ganondorf", "Gerudo Gloss", "Save a costume for Ganondorf.", "Evil never looked so curated.", 10],
				["pikachu", "Volt Varnish", "Save a costume for Pikachu.", "Shockingly stylish cheeks.", 10],
				["pichu", "Tiny Spark Coat", "Save a costume for Pichu.", "Small mouse, big palette.", 10],
				["jigglypuff", "Mic Drop Makeover", "Save a costume for Jigglypuff.", "Sing a lullaby in new colors.", 10],
				["lucario", "Aura Accent", "Save a costume for Lucario.", "Feel the hues of auras.", 10],
				["kirby", "Pink Optional", "Save a costume for Kirby.", "Inhale colors, spit style.", 10],
				["dedede", "Hammer Hue", "Save a costume for King Dedede.", "Royal penguin needs a fresh coat.", 10],
				["metaknight", "Masked Matte", "Save a costume for Meta Knight.", "A mask hides more than a face.", 10],
				["bandanadee", "Bandana Blend", "Save a costume for Bandana Dee.", "Spear and scarf, recolored.", 10],
				["fox", "Arwing Airbrush", "Save a costume for Fox.", "Corneria calling — new paint.", 10],
				["falco", "Ace Accent", "Save a costume for Falco.", "Birds of a feather, custom leather.", 10],
				["krystal", "Cerinian Coat", "Save a costume for Krystal.", "Staff, staff, and more swatches.", 10],
				["samus", "Power Suit Polish", "Save a costume for Samus.", "Varia looks better customized.", 10],
				["zamus", "Zero Suit Swatch", "Save a costume for Zero Suit Samus.", "No armor, all attitude, new colors.", 10],
				["captainfalcon", "Show Me Your Hues", "Save a costume for Captain Falcon.", "Blood Falcon wishes he had this fit.", 10],
				["ness", "PK Paint", "Save a costume for Ness.", "Home-run colors from Eagleland.", 10],
				["marth", "Falchion Finish", "Save a costume for Marth.", "A lord's blade deserves a lord's palette.", 10],
				["pit", "Angel Airbrush", "Save a costume for Pit.", "Wings optional, colors not.", 10],
				["isaac", "Venus Varnish", "Save a costume for Isaac.", "Psynergy in every pixel.", 10],
				["chibirobo", "Plug & Paint", "Save a costume for Chibi-Robo.", "Tiny robot, tidy palette.", 10],
				["gameandwatch", "LCD Remaster", "Save a costume for Mr. Game & Watch.", "2D never looked so 2.0.", 10],
				["sonic", "Blue Optional", "Save a costume for Sonic.", "Gotta go fast… into the color picker.", 10],
				["tails", "Twin Tail Tint", "Save a costume for Tails.", "Two tails, infinite hues.", 10],
				["megaman", "Robot Master Remix", "Save a costume for Mega Man.", "Copy a palette, save the world.", 10],
				["ryu", "Hadouken Hue", "Save a costume for Ryu.", "The answer is in the paint.", 10],
				["pacman", "Waka Waka Wash", "Save a costume for PAC-MAN.", "Dots optional; colors required.", 10],
				["lloyd", "Exsphere Accent", "Save a costume for Lloyd.", "Twin blades, twin tones.", 10],
				["simon", "Whip Stitch", "Save a costume for Simon.", "Vampire hunter chic.", 10],
				["bomberman", "Fuse Fashion", "Save a costume for Bomberman.", "Light the fuse, pick the palette.", 10],
				["blackmage", "Cursor Couture", "Save a costume for Black Mage.", "Vivi vibes, custom robes.", 10],
				["sora", "Keyblade Coat", "Save a costume for Sora.", "Hearts and hues connected.", 10],
				["rayman", "Limbless Luster", "Save a costume for Rayman.", "No limbs, no limits on color.", 10],
				["goku", "Saiyan Swatch", "Save a costume for Goku.", "Power level: chromatic.", 10],
				["luffy", "Straw Hat Stain", "Save a costume for Luffy.", "Pirate king of palettes.", 10],
				["naruto", "Shadow Clone Coat", "Save a costume for Naruto.", "Believe it — in new colors.", 10],
				["ichigo", "Bankai Blend", "Save a costume for Ichigo.", "Soul Reaper, color keeper.", 10],
				["sandbag", "Punching Bag Paint", "Save a costume for Sandbag.", "Even training dummies want style.", 14],
				["buu", "Pink Optional II", "Save a costume for Buu.", "Expansion mischief in pastel.", 12],
				["hero", "Luminary Lacquer", "Save a costume for Hero.", "A true hero picks their own armor.", 12],
				["knight", "Hollow Hue", "Save a costume for Knight.", "Dreams of nail and shade.", 12],
				["littlemac", "Title Bout Tint", "Save a costume for Little Mac.", "Eye of the tiger, eye of the eyedropper.", 12],
				["donkeykong_clone", "Clone Barrel", "Save a costume for a DK clone.", "Expansion ape wants a peel.", 14],
				["fox_clone", "Clone Arwing", "Save a costume for a Fox clone.", "Another pilot, another paint job.", 14],
				["ganondorf_clone", "Clone Gerudo", "Save a costume for a Ganon clone.", "Evil doppelgänger couture.", 14],
				["goku_clone", "Clone Saiyan", "Save a costume for a Goku clone.", "Another universe, same grind.", 14],
				["link_clone", "Clone Triforce", "Save a costume for a Link clone.", "Parallel hero, parallel palette.", 14],
				["sonic_clone", "Clone Blue", "Save a costume for a Sonic clone.", "Faster than the eyedropper.", 14],
				["vegeta_clone", "Prideful Paint", "Save a costume for Vegeta clone.", "Prince of all palettes.", 14]
			];
			var row:Array;
			for each (row in roster)
			{
				add("roster_" + row[0], String(row[1]), String(row[2]), String(row[3]), int(row[4]), ["roster"]);
			};
		}

		private static function buildRituals():void
		{
			add("ritual_select_all", "Whole Rainbow", "Use Select All on the swatch grid.", "One shortcut grabs every chip.", 8, ["ritual"]);
			add("ritual_invert", "Negative Space", "Invert your color selection.", "Flip who is chosen.", 8, ["ritual"]);
			add("ritual_invert_after_select_all", "Photographic Negative", "Invert right after Select All.", "Select everything, then flip it.", 14, ["ritual"]);
			add("ritual_isolate_on", "Tunnel Vision", "Turn Isolate Mode on.", "Dim the noise; keep the signal.", 8, ["ritual"]);
			add("ritual_freeze", "Time Out", "Freeze the studio character.", "Hit pause on the mannequin.", 8, ["ritual"]);
			add("ritual_freeze_then_pick", "Still Life Study", "Pick a color with the magnifier while frozen.", "Freeze first, then sample.", 14, ["ritual"]);
			add("ritual_undo_after_redo", "Second Thoughts", "Undo immediately after a redo.", "Yo-yo the history stack.", 12, ["ritual"]);
			add("ritual_recolor_base", "Back to Basics", "Use Recolor to Base.", "Return selected chips to costume base.", 8, ["ritual"]);
			add("ritual_recolor_og", "Original Recipe", "Use Recolor to OG.", "Restore the stock originals.", 8, ["ritual"]);
			add("ritual_reset_active", "Clean Slate Slice", "Use Reset Active.", "Nuke just the active set.", 8, ["ritual"]);
			add("ritual_open_cs", "Mixer Desk", "Open Color Settings.", "Groups live behind CS.", 8, ["ritual"]);
			add("ritual_open_settings", "Preferences Pane", "Open Palette Maker Settings.", "The gear with the toggles.", 8, ["ritual"]);
			add("ritual_open_achievements", "Trophy Case", "Open the Achievements panel.", "Peek at your cookie jar.", 8, ["ritual"]);
			add("ritual_save_with_author", "Signed Work", "Save a costume with an author name filled.", "Credit yourself in the author box.", 10, ["ritual"]);
			add("ritual_mag_25_no_cs", "Eye for Detail", "Magnifier-select 25 colors in a session without opening CS.", "Stay on the sprite; skip Color Settings.", 18, ["ritual"]);
			add("ritual_isolate_highlight", "Diff Check", "Enable Highlight Unchanged while Isolate is on.", "Two vision modes at once.", 14, ["ritual"]);
			add("ritual_export_then_import", "Round Trip", "Export a color sheet then import one in the same session.", "Sheet out, sheet in.", 14, ["ritual"]);
			add("ritual_create_then_delete_group", "Group Therapy", "Create a group and delete a group in one session.", "Make it, then scrap it.", 12, ["ritual"]);
			add("ritual_save_while_frozen", "Mannequin Moment", "Save a costume while the character is frozen.", "Don't thaw before you commit.", 12, ["ritual"]);
			add("ritual_use_shortcut", "Hotkey Hero", "Trigger any tool via a Ctrl shortcut.", "Skip the toolbar click once.", 10, ["ritual"]);
			add("ritual_hue_drag", "Wheel Spinner", "Adjust hue on a selection via the hue slider.", "Nudge the rainbow arrow.", 10, ["ritual"]);
			add("ritual_alpha_edit", "Ghost Protocol", "Change alpha on selected colors.", "Transparency is a feature.", 10, ["ritual"]);
			add("ritual_brightness", "Exposure Pass", "Change brightness on selected colors.", "Lift or crush the values.", 10, ["ritual"]);
			add("ritual_saturation", "Juice It", "Change saturation on selected colors.", "More pop or more mute.", 10, ["ritual"]);
			add("ritual_match_preview", "Discord Fit Check", "Keep Discord costume preview enabled while editing.", "Let friends see the WIP.", 12, ["ritual"]);
			add("ritual_sort_original", "Museum Order", "Enable Sort by original.", "Line swatches up by stock order.", 10, ["ritual"]);
			add("ritual_hide_ui", "Immersive Mode", "Hide the Palette Maker UI.", "Clear the HUD for a moment.", 10, ["ritual"]);
			add("ritual_unique_pa", "Accessory Awareness", "Toggle an mcName / unique accessory dropdown entry.", "Swap a hat or prop visibility.", 14, ["ritual"]);
			add("ritual_clipboard_export", "Code Courier", "Copy a costume code to the clipboard.", "Export button, not the sheet.", 10, ["ritual"]);
			add("ritual_online_import", "Vault Raider", "Open online / Color Vault import.", "Pull someone else's work.", 12, ["ritual"]);
			add("ritual_locker", "Costume Closet", "Open the costume locker / selector.", "Browse saved fits.", 10, ["ritual"]);
			add("ritual_primary_pick", "Primary Directive", "Change a group's primary color via pick.", "CS primary pick mode.", 14, ["ritual"]);
			add("ritual_eyedropper", "Pipette Pro", "Use the Color Settings eyedropper.", "Sample into the wheel.", 12, ["ritual"]);
			add("ritual_hex_edit", "Hex Speaks", "Type a hex color into Color Settings.", "Six digits of truth.", 12, ["ritual"]);
			add("ritual_dont_use_swatch", "Ignore the Chip", "Use Don't Use Swatch on a group.", "Keep the edit without the face.", 14, ["ritual"]);
			add("ritual_group_rename", "Name Tag", "Rename a color group.", "CS rename field.", 10, ["ritual"]);
			add("ritual_group_disable", "Mute Layer", "Disable a color group.", "Toggle enabled off.", 12, ["ritual"]);
			add("ritual_pulse_watch", "Neon Border", "Trigger a selection pulse on the sprite.", "Select colors and watch them throb.", 10, ["ritual"]);
			add("ritual_partner_form", "Linked Forms", "Edit a linked-form character (e.g. Zelda/Sheik).", "Two bodies, one costume file.", 14, ["ritual"]);
			add("ritual_rest_tod", "Golden Hour", "Change Rest Area time of day while editing.", "Studio lighting, remixed.", 12, ["ritual"]);
			add("ritual_rest_music", "Studio Playlist", "Change Rest Area music while editing.", "Soundtrack optional.", 12, ["ritual"]);
			add("ritual_batch_cache", "Cache Diplomat", "Respond to the batch palette cache prompt.", "Say yes or no to the cache dialog.", 14, ["ritual"]);
			add("ritual_deselect_all", "Hands Off", "Use Deselect All with colors selected.", "Clear the selection cleanly.", 8, ["ritual"]);
			add("ritual_new_group_tool", "Group From Grid", "Create a group with the NG tool.", "Select, then NG.", 8, ["ritual"]);
		}

		private static function buildGroups():void
		{
			add("group_first", "First Cluster", "Create your first color group.", "NG with a selection.", 8, ["group"]);
			add("group_3", "Trio Layer", "Have 3 groups on one character.", "Stack a few layers.", 10, ["group"]);
			add("group_5", "Quintet", "Have 5 groups on one character.", "Keep stacking.", 12, ["group"]);
			add("group_8", "Octet Orchestra", "Have 8 groups on one character.", "Ambitious layering.", 14, ["group"]);
			add("group_12", "Dozen Layers", "Have 12 groups on one character.", "Maximum bureaucracy.", 18, ["group"]);
			add("group_delete", "Disband", "Delete a color group.", "CS delete.", 8, ["group"]);
			add("group_reorder", "Priority Shuffle", "Drag-reorder group priority.", "Slide a group chip.", 10, ["group"]);
			add("group_lock", "Padlock Palette", "Lock a color group.", "CS lock toggle.", 10, ["group"]);
			add("group_match_all", "Matchmaker", "Enable Match All on a group.", "One primary rules them all.", 12, ["group"]);
			add("group_shared_color", "Shared Custody", "Put the same color in two groups.", "Overlap members.", 16, ["group"]);
			add("group_auto_accept", "AUTO Pilot", "Keep an auto-generated group.", "Don't delete the AUTO ones.", 12, ["group"]);
			add("group_export_json", "Group Luggage", "Export color groups JSON.", "Settings → Export color groups.", 12, ["group"]);
			add("group_import_json", "Group Immigration", "Import color groups JSON.", "Settings → Import color groups.", 12, ["group"]);
			add("group_big_members", "Crowd Control", "Create a group with 20+ members.", "Select a huge chunk first.", 16, ["group"]);
			add("group_solo_member", "Solo Act", "Create a group with exactly one color.", "Lonely little layer.", 10, ["group"]);
			add("group_after_isolate", "Isolated Club", "Create a group while Isolate is on.", "Tunnel vision + NG.", 12, ["group"]);
			add("group_while_frozen", "Frozen Committee", "Create a group while frozen.", "FZ then NG.", 12, ["group"]);
			add("group_lock_then_edit", "Break-in Attempt", "Try to edit colors in a locked group.", "Get the locked toast.", 14, ["group"]);
			add("group_priority_top", "Top Billing", "Move a group to first priority.", "Drag it to the front.", 12, ["group"]);
			add("group_rename_funny", "Comedy Label", "Rename a group to something with 12+ characters.", "Long names welcome.", 12, ["group"]);
			add("group_enable_toggle", "On/Off Switch", "Toggle a group enabled twice.", "Disable then enable.", 10, ["group"]);
			add("group_match_undo", "Unmatch", "Undo Match All on a group.", "CS undo match.", 12, ["group"]);
			add("group_primary_from_mag", "Sprite Primary", "Set primary by picking from the sprite.", "Primary pick + magnifier.", 14, ["group"]);
			add("group_use_swatch", "Face Value", "Enable Use Swatch on a group.", "Show the chip face.", 10, ["group"]);
			add("group_session_five_creates", "Assembly Line", "Create 5 groups in one session.", "NG spam (with purpose).", 14, ["group"]);
		}

		private static function buildSheets():void
		{
			add("sheet_import_first", "Sheet Music In", "Import a color sheet PNG.", "IC tool.", 10, ["sheet"]);
			add("sheet_export_first", "Sheet Music Out", "Export a color sheet PNG.", "EC tool.", 10, ["sheet"]);
			add("sheet_import_multi", "Binder Full", "Import multiple color sheets at once.", "Multi-select PNGs.", 14, ["sheet"]);
			add("sheet_export_heavy", "Dense Strip", "Export a sheet with 40+ colors.", "Busy palettes welcome.", 14, ["sheet"]);
			add("sheet_after_recolor", "Document the Crime", "Export a sheet after a heavy recolor.", "Change a lot, then EC.", 12, ["sheet"]);
			add("sheet_reimport_own", "Self Reference", "Import a sheet you just exported.", "Round-trip your strip.", 14, ["sheet"]);
			add("sheet_pack_save", "Pack Mentality", "Save a pack from multi-sheet import.", "IC with 2+ PNGs → pack.", 16, ["sheet"]);
			add("sheet_stock_write", "Stock Stamp", "Write colors onto a stock sheet preview.", "Pack browser stock strip.", 16, ["sheet"]);
			add("sheet_bad_png", "Not a Sheet", "Attempt to import a non-sheet image.", "Wrong PNG bottom strip.", 12, ["sheet"]);
			add("sheet_empty_fail", "Blank Page", "Hit an empty sheet import edge case.", "No palette row.", 14, ["sheet"]);
			add("sheet_linked_export", "Double Feature", "Export a sheet on a linked-form character.", "Zelda/Sheik style.", 14, ["sheet"]);
			add("sheet_unique_pa_export", "Prop Poster", "Export a sheet that includes unique PA sprites.", "Accessories in the collage.", 16, ["sheet"]);
			add("sheet_import_partial", "Partial Apply", "Import a sheet shorter than the palette.", "Fewer strip colors than bases.", 12, ["sheet"]);
			add("sheet_import_apply", "Strip Applied", "Successfully apply an imported strip.", "Colors land on swatches.", 10, ["sheet"]);
		}

		private static function buildMilestones():void
		{
			add("mile_save_1", "First Commit", "Save your first costume.", "Hit Save once.", 8, ["mile"]);
			add("mile_save_5", "Warming Up", "Save 5 costumes.", "Keep committing fits.", 10, ["mile"]);
			add("mile_save_10", "Double Digits", "Save 10 costumes.", "Portfolio starting.", 10, ["mile"]);
			add("mile_save_25", "Closet Filler", "Save 25 costumes.", "Serious hobby energy.", 12, ["mile"]);
			add("mile_save_50", "Wardrobe", "Save 50 costumes.", "Half a hundred fits.", 14, ["mile"]);
			add("mile_save_100", "Fashion Empire", "Save 100 costumes.", "Triple digits.", 18, ["mile"]);
			add("mile_chars_5", "Pentathlon Paint", "Save costumes for 5 different characters.", "Spread the love.", 10, ["mile"]);
			add("mile_chars_10", "Decathlon Dye", "Save costumes for 10 different characters.", "Tour the roster.", 12, ["mile"]);
			add("mile_chars_20", "Exhibition Tour", "Save costumes for 20 different characters.", "Halfway around the CSS.", 14, ["mile"]);
			add("mile_chars_30", "Nearly Full House", "Save costumes for 30 different characters.", "Most of the cast.", 16, ["mile"]);
			add("mile_chars_40", "Roster Regular", "Save costumes for 40 different characters.", "Almost everyone.", 18, ["mile"]);
			add("mile_cookies_25", "Cookie Starter", "Earn 25 cookies lifetime.", "Saves pay cookies.", 10, ["mile"]);
			add("mile_cookies_100", "Cookie Jar", "Earn 100 cookies lifetime.", "Keep saving.", 12, ["mile"]);
			add("mile_cookies_250", "Bakery Run", "Earn 250 cookies lifetime.", "Sweet progress.", 14, ["mile"]);
			add("mile_cookies_500", "Cookie Tycoon", "Earn 500 cookies lifetime.", "Hint budget secured.", 18, ["mile"]);
			add("mile_hints_5", "Spoiler Lite", "Buy 5 achievement hints.", "Spend cookies on ???.", 12, ["mile"]);
			add("mile_hints_20", "Walkthrough Buyer", "Buy 20 achievement hints.", "No shame in spoilers.", 16, ["mile"]);
			add("mile_undo_100", "Ctrl+Z Lifestyle", "Undo 100 times lifetime.", "History is a circle.", 14, ["mile"]);
			add("mile_mag_100", "Pixel Surgeon", "Magnifier-select 100 times lifetime.", "Click the sprite a lot.", 14, ["mile"]);
			add("mile_groups_tool_10", "Groupie", "Use the NG tool 10 times.", "New Group muscle memory.", 12, ["mile"]);
			add("mile_invert_25", "Flip Addiction", "Invert selection 25 times lifetime.", "IS spam, but make it fashion.", 12, ["mile"]);
			add("mile_unlock_25", "Quarter Collection", "Unlock 25 achievements.", "Fill the case.", 12, ["mile"]);
			add("mile_unlock_50", "Half Collection", "Unlock 50 achievements.", "Halfway (sort of).", 14, ["mile"]);
			add("mile_unlock_100", "Century Club", "Unlock 100 achievements.", "Triple-digit trophies.", 18, ["mile"]);
			add("mile_shortcuts_10", "Keyboard Cowboy", "Use Ctrl shortcuts 10 times.", "Hands on home row.", 12, ["mile"]);
		}

		private static function buildSecrets():void
		{
			add("secret_oc_name", "Original Character Do Not Steal", "Save a costume whose name contains \"OC\".", "Name it like a DeviantArt upload.", 20, ["secret"]);
			add("secret_flash_costume", "Game-Breaking Fashion", "Cause a character's colors to flash with a cyclic palette swap.", "Map colors into each other until they strobe. Congrats, you broke it.", 22, ["secret"]);
			add("secret_deselect_nothing", "Deselect the Void", "Use Deselect All when nothing is selected.", "Clear an already-empty selection.", 14, ["secret"]);
			add("secret_peek_achievements", "Spoiler Seeker", "Open Achievements before unlocking any.", "Tour the ??? wall first.", 14, ["secret"]);
			add("secret_hint_before_unlock", "Pay to Peek", "Buy a hint before unlocking any achievement.", "Cookies before glory.", 16, ["secret"]);
			add("secret_all_tools_session", "Toolbox Tour", "Use every tool once in a single session.", "UD through EC, no skips.", 20, ["secret"]);
			add("secret_isolate_session_save", "Isolation Chamber", "Save while Isolate has been used this session.", "Dim mode, then commit.", 12, ["secret"]);
			add("secret_long_name", "Title Card", "Save a costume with a 20+ character name.", "Write a novel in the slot.", 14, ["secret"]);
			add("secret_same_name_author", "Ego Mirror", "Save with costume name equal to author name.", "Sign it twice.", 16, ["secret"]);
			add("secret_default_name", "Lazy Label", "Save while still using a default-ish costume name.", "Barely renamed.", 14, ["secret"]);
			add("secret_sandbag_only", "Training Arc", "Save three Sandbag costumes.", "Punching bag couture streak.", 16, ["secret"]);
			add("secret_both_linked", "Dual Identity", "Save costumes for both forms of a linked pair across sessions.", "Zelda and Sheik both get love.", 18, ["secret"]);
			add("secret_clone_trio", "Clone Wars", "Save costumes for 3 different expansion clones.", "Doppelgängers unite.", 18, ["secret"]);
			add("secret_zero_cookie_hint", "Broke Scholar", "Open Achievements while holding 0 cookies.", "Window shop the hints.", 12, ["secret"]);
			add("secret_spend_last_cookie", "Last Crumb", "Buy a hint that spends your final cookies.", "Down to zero.", 16, ["secret"]);
			add("secret_invert_empty", "Invert Nothing", "Invert selection when nothing is selected.", "Select all by accident.", 12, ["secret"]);
			add("secret_undo_empty", "Undo the Void", "Press Undo with an empty undo stack.", "Nothing to take back.", 12, ["secret"]);
			add("secret_redo_empty", "Redo the Void", "Press Redo with an empty redo stack.", "Nothing to restore.", 12, ["secret"]);
			add("secret_cs_no_group", "Settings for Nobody", "Open Color Settings with no active group.", "Empty CS attempt.", 12, ["secret"]);
			add("secret_ng_empty", "Group of None", "Try New Group with no selection.", "Get the Select colors first toast.", 10, ["secret"]);
			add("secret_save_blank_name", "Untitled Rejected", "Attempt to save with a blank name.", "Rename costume before saving.", 10, ["secret"]);
			add("secret_rapid_save", "Spam Save", "Save twice within a few seconds.", "Commit, commit again.", 14, ["secret"]);
			add("secret_author_emoji", "Signature Style", "Save with an author name of 1 character.", "Minimal credit.", 14, ["secret"]);
			add("secret_palette_identity", "Untouched Masterpiece", "Save without changing any colors from the loaded baseline.", "Stock is a look.", 16, ["secret"]);
			add("secret_full_invert_recolor", "Opposite Day", "Select all, invert, then recolor to OG.", "Chaos pipeline.", 16, ["secret"]);
			add("secret_freeze_isolate", "Cryo Isolation", "Have Freeze and Isolate on together.", "Two modes, one vibe.", 12, ["secret"]);
			add("secret_mag_miss", "Missed Pixel", "Click magnifier where there is no palette color.", "Empty air sample.", 14, ["secret"]);
			add("secret_hide_then_shortcut", "Invisible Hotkeys", "Use a Ctrl shortcut while UI is hidden.", "HUD off, keys on.", 16, ["secret"]);
			add("secret_achievements_cookie_label", "Bean Counter", "Open Settings and see your cookie count on Achievements.", "The button tells the truth.", 10, ["secret"]);
			add("secret_hint_hard", "Deep Lore", "Buy a hint costing 20+ cookies.", "Pay premium for spoilers.", 18, ["secret"]);
			add("secret_all_roster_classic", "Classic Completionist", "Unlock every classic roster stamp achievement.", "Paint the whole CSS.", 24, ["secret"]);
			add("secret_expansion_stamp", "Expansion Pack Rat", "Unlock 4 expansion roster stamps.", "Clones and guests.", 18, ["secret"]);
			add("secret_cookie_hoard", "Scrooge McCookie", "Hold 100 cookies at once.", "Don't spend, just flex.", 16, ["secret"]);
			add("secret_cookie_broke", "Empty Tin", "Hit exactly 0 cookies after buying a hint.", "Spend it all.", 14, ["secret"]);
			add("secret_session_tools_half", "Half Toolkit", "Use 8 different tools in one session.", "Variety hour.", 12, ["secret"]);
			add("secret_group_then_sheet", "Layered Export", "Create a group then export a color sheet.", "Structure, then document.", 12, ["secret"]);
			add("secret_import_then_save", "Adopt & Commit", "Import a sheet then save the costume.", "Foreign colors, your name.", 12, ["secret"]);
			add("secret_recolor_chain", "Base → OG → Base", "Use RB then RO then RB in one session.", "Ping-pong baselines.", 14, ["secret"]);
			add("secret_da_after_sa", "Whiplash Selection", "Select All then Deselect All.", "All on, all off.", 10, ["secret"]);
			add("secret_lock_notify", "Padlock Toast", "Trigger the group locked notification.", "Edit while locked.", 12, ["secret"]);
			add("secret_priority_battle", "Layer Wars", "Reorder groups 5 times lifetime.", "Drag drama.", 12, ["secret"]);
			add("secret_mag_deselect", "Precise Eraser", "Deselect a color via magnifier click.", "Click a selected pixel to drop it.", 12, ["secret"]);
			add("secret_open_shortcuts", "Cheat Sheet", "Open the Keyboard Shortcuts panel.", "Settings → Keyboard Shortcuts.", 8, ["secret"]);
		}

		private static function buildFlavorExtras():void
		{
			// Pad to 200+ with situational flavor that still has unique copy.
			var flavors:Array = [
				["flavor_red_bias", "Seeing Red", "Save a costume after heavily shifting hues toward red.", "Warm the whole cast.", 14],
				["flavor_blue_bias", "Feeling Blue", "Save after a cool blue push.", "Cold palette energy.", 14],
				["flavor_mono", "Monochrome Mood", "Push saturation way down then save.", "Gray is a lifestyle.", 14],
				["flavor_neon", "Neon Nights", "Crank saturation high then save.", "Club lighting.", 14],
				["flavor_ghost", "Almost Invisible", "Drop alpha low on several colors then save.", "Fashionably translucent.", 16],
				["flavor_high_contrast", "Posterize Punch", "Mix near-black and near-white replacements.", "No midtones, only vibes.", 14],
				["flavor_skin_preserve", "Face First", "Recolor everything but leave skin-ish tones.", "Keep the face familiar.", 16],
				["flavor_invert_save", "Negative Fit", "Invert selection and save without deselecting.", "Commit the flipped set.", 14],
				["flavor_group_only_edit", "Stay in Your Lane", "Recolor only via an active group.", "Group discipline.", 12],
				["flavor_no_groups_save", "Freehand", "Save with zero groups on the character.", "Ungrouped artist.", 12],
				["flavor_many_undos", "Indecisive", "Undo 10 times in one session.", "History scrubbing.", 12],
				["flavor_redo_streak", "Forward Again", "Redo 5 times in one session.", "Trust your past self.", 12],
				["flavor_slider_marathon", "Knob Twister", "Touch hue, sat, bright, and alpha in one session.", "All four sliders.", 12],
				["flavor_pa_focus", "Portrait Priority", "Spend a session mostly on PA colors.", "HUD face matters.", 14],
				["flavor_body_focus", "Body Work", "Spend a session mostly on body swap colors.", "Full-body remodel.", 14],
				["flavor_accessory_on", "Hat On", "Enable a unique accessory while editing.", "mcName visible.", 12],
				["flavor_accessory_off", "Hat Off", "Disable a unique accessory while editing.", "Clean silhouette.", 12],
				["flavor_compare_loaded", "Vs Loaded", "Use Highlight Unchanged vs loaded costume.", "Diff against what you opened.", 12],
				["flavor_compare_original", "Vs Original", "Use Highlight Unchanged vs original.", "Diff against stock.", 12],
				["flavor_always_isolate", "Permanent Blinders", "Edit with Always isolate enabled.", "Settings toggle.", 10],
				["flavor_quick_save", "Speedrun Save", "Save within a minute of opening the editor.", "In and out.", 14],
				["flavor_long_session", "Deep Work", "Save after a long editing session.", "Take your time.", 14],
				["flavor_name_color_word", "Literal Palette", "Save a costume named after a color word.", "Try \"Blue\" or \"Crimson\".", 14],
				["flavor_name_ssf", "Meta Branding", "Save a costume with \"SSF\" in the name.", "House pride.", 14],
				["flavor_name_v2", "Version Two", "Save a costume with \"v2\" or \"2\" in the name.", "Iteration culture.", 12],
				["flavor_author_anon", "Anonymous", "Save with author set to anon/anonymous.", "Mystery designer.", 14],
				["flavor_copy_then_edit", "Fork It", "Load a costume then change and save under a new name.", "Derivative, but make it yours.", 12],
				["flavor_team_colors", "Faction Fit", "Aim for team-like red/blue/green sets.", "Smash team energy.", 14],
				["flavor_gold_trim", "Gilded", "Add golden accents to a dark costume.", "Rich trim.", 14],
				["flavor_silver_chrome", "Chrome Finish", "Push several colors toward metallic gray.", "Shiny.", 14],
				["flavor_pastel", "Pastel Wave", "Save a soft pastel-heavy costume.", "Gentle tones.", 14],
				["flavor_earth", "Earth Tones", "Save a browns/greens costume.", "Dirtcore.", 14],
				["flavor_void", "Voidcore", "Save a mostly black costume.", "Fashionably grim.", 14],
				["flavor_blanc", "Blank Canvas", "Save a mostly white costume.", "Studio light leak.", 14],
				["flavor_complement", "Complement Clash", "Use opposing hues on adjacent parts.", "Color theory homework.", 14],
				["flavor_analogous", "Neighbor Hues", "Keep replacements in a tight hue band.", "Analogous harmony.", 14],
				["flavor_triadic", "Triangle Trade", "Use three spaced hues across the body.", "Triadic flex.", 16],
				["flavor_skin_swap", "New Complexion", "Recolor skin tones drastically.", "Bold choice.", 14],
				["flavor_eye_pop", "Eye Contact", "Recolor eye-related chips carefully.", "Tiny but important.", 16],
				["flavor_outline", "Line Work", "Recolor outline/dark edge colors.", "Ink pass.", 14],
				["flavor_shade", "Shade Stack", "Preserve shade ladders while recoloring.", "Keep the gradients reading.", 16],
				["flavor_flat", "Flat Design", "Collapse shade variety toward flats.", "Minimal shading.", 14],
				["flavor_swap_shoes", "Sole Search", "Focus a recolor on footwear colors.", "Kickers first.", 14],
				["flavor_swap_hair", "Salon Day", "Focus a recolor on hair colors.", "New do.", 14],
				["flavor_swap_clothes", "Wardrobe Swap", "Focus a recolor on clothing colors.", "Outfit pass.", 14],
				["flavor_glove", "Hand Care", "Focus gloves/hand accents.", "Detail work.", 14],
				["flavor_belt", "Belt Buckle Energy", "Focus small accessory chips.", "Tiny wins.", 14],
				["flavor_emoji_name", "Sticker Name", "Use punctuation-heavy costume name.", "!!! names welcome.", 12],
				["flavor_spaces_name", "Multi Word", "Save a multi-word costume name.", "Spaces allowed.", 10],
				["flavor_lowercase", "quiet luxury", "Save an all-lowercase costume name.", "soft branding.", 12],
				["flavor_uppercase", "LOUD LUXURY", "Save an all-caps costume name.", "SCREAM THE FIT.", 12],
				["flavor_number_name", "Serial Number", "Save a costume named with mostly digits.", "007 energy.", 14],
				["flavor_palette_count", "Swatch Maximalist", "Work on a character with a huge mixed palette.", "Busy sprites welcome.", 14],
				["flavor_tiny_palette", "Minimal Kit", "Work on a character with a tiny palette.", "Few chips, big choices.", 14],
				["flavor_second_save", "Revision", "Save the same character twice in a session.", "Iterate in place.", 12],
				["flavor_switch_char", "Touring Artist", "Edit more than one character across sessions.", "Move down the CSS.", 10],
				["flavor_back_out", "Maybe Later", "Leave the editor without saving once.", "Back button bravery.", 10],
				["flavor_reload_costume", "Fresh Load", "Load a costume into the editor then save.", "Locker → edit → save.", 10],
				["flavor_stock_start", "From Scratch Stock", "Start from stock base and save a custom.", "Blank canvas from CSS.", 10],
				["flavor_cookie_spend_save", "Earn & Burn", "Earn cookies from a save then buy a hint.", "Economy loop.", 12],
				["flavor_open_both_popups", "Settings Tour", "Open Shortcuts and Achievements from Settings.", "Both buttons.", 10],
				["flavor_close_settings_clickout", "Click Away", "Close Settings by clicking outside.", "Stage dismiss.", 10],
				["flavor_tool_hint", "Tooltip Reader", "Hover tools until the hint text updates.", "Read the label.", 10],
				["flavor_secret_hunter", "Conspiracy Board", "Unlock 5 secret-tagged achievements.", "Chase the ???.", 18],
				["flavor_ritual_hunter", "Habit Builder", "Unlock 10 ritual achievements.", "Do the little dances.", 14],
				["flavor_roster_hunter", "CSS Tourist", "Unlock 15 roster stamps.", "Travel the cast.", 14],
				["flavor_group_hunter", "Layer Lord", "Unlock 8 group achievements.", "Groups are life.", 14],
				["flavor_sheet_hunter", "Sheet Geek", "Unlock 6 sheet achievements.", "PNG lifestyle.", 14],
				["flavor_mile_hunter", "Grinder", "Unlock 10 milestone achievements.", "Numbers go up.", 14],
				["flavor_balanced", "Well Rounded", "Unlock at least one of each tag type.", "Roster, ritual, group, sheet, mile, secret.", 16],
				["flavor_no_hints", "Hard Mode", "Unlock 20 achievements without buying hints.", "Pure discovery.", 18],
				["flavor_hint_addict", "Guide Enjoyer", "Have 10 hints purchased at once.", "Spoilers library.", 16],
				["flavor_cookie_twenty", "Pocket Change", "Hold at least 20 cookies.", "Small stash.", 10],
				["flavor_cookie_fifty", "Bakery Stash", "Hold at least 50 cookies.", "Medium stash.", 12],
				["flavor_recolor_og_all", "Factory Reset Lite", "Select all and Recolor to OG.", "SA + RO.", 12],
				["flavor_recolor_base_all", "Baseline Hug", "Select all and Recolor to Base.", "SA + RB.", 12],
				["flavor_reset_after_chaos", "Damage Control", "Reset Active after a wild invert.", "Clean up.", 12],
				["flavor_ng_after_invert", "Invert → Group", "Invert selection then make a group.", "IS then NG.", 12],
				["flavor_freeze_export", "Frozen Portrait", "Export a color sheet while frozen.", "FZ + EC.", 12],
				["flavor_isolate_import", "Quiet Import", "Import a sheet while Isolate is on.", "DI + IC.", 12],
				["flavor_mag_group", "Pick Into Group", "Magnifier-select into an active group.", "Group selected, then pick.", 12],
				["flavor_deselect_group", "Leave the Club", "Deselect while a group is active.", "Drop group selection.", 10],
				["flavor_cs_lock_unlock", "Locksmith", "Lock and unlock the same group.", "Toggle twice.", 12],
				["flavor_drag_priority_save", "Priority Commit", "Reorder groups then save.", "Layers matter on disk.", 12],
				["flavor_author_long", "Credit Roll", "Save with a long author name (16+).", "Sign your full government name.", 12],
				["flavor_name_palette", "Named After Tool", "Save a costume named like a tool (e.g. Invert).", "Meta naming.", 14],
				["flavor_sandbag_flash", "Broken Dummy", "Cause a flash cycle on Sandbag.", "Even the bag can strobe.", 20],
				["flavor_mario_oc", "Mushroom Kingdom OC", "Save a Mario costume with OC in the name.", "Combo secret.", 18],
				["flavor_sonic_blue_optional", "Not Blue", "Save a Sonic costume that isn't mostly blue.", "Heresy.", 16],
				["flavor_kirby_not_pink", "Not Pink", "Save a Kirby costume that isn't mostly pink.", "Shape remains.", 16],
				["flavor_goku_not_orange", "Gi Alternatives", "Save a Goku costume without classic orange.", "New gi day.", 16],
				["flavor_link_green_optional", "Tunics Optional", "Save a Link costume without classic green.", "Hylian haute.", 16],
				["flavor_final_cookie_flex", "Payday", "Reach 5 cookies exactly from a save award.", "Math!", 14]
			];
			var row:Array;
			for each (row in flavors)
			{
				add(String(row[0]), String(row[1]), String(row[2]), String(row[3]), int(row[4]), ["flavor"]);
			};
		}
	}
}
