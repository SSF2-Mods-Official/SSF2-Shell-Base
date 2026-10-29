package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.filters.GlowFilter;
	import flash.geom.ColorTransform;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Series identity: exact stage-id map first, then tight name hints, then
	 * character seriesIcon / previewer logo match. Same icon linkage = same series.
	 */
	public class MusicSeriesResolver
	{
		public static const KEY_ALL:String = "__all__";
		public static const KEY_OTHER:String = "__other__";
		public static const KEY_UNKNOWN:String = "__unknown__";

		private static var s_stageKey:Object = {};
		private static var s_keyStages:Object = {};
		private static var s_keyLabel:Object = {};
		private static var s_iconLabels:Object = {};
		private static var s_built:Boolean = false;

		/** Exact stage id → {icon, label}. Covers stage-select roster. */
		private static const STAGE_SERIES:Object = {
			"battlefield": {"icon": "smash_icon", "label": "Super Smash Bros."},
			"battlefield2": {"icon": "smash_icon", "label": "Super Smash Bros."},
			"finaldestination": {"icon": "smash_icon", "label": "Super Smash Bros."},
			"metalcavern": {"icon": "smash_icon", "label": "Super Smash Bros."},
			"waitingroom": {"icon": "smash_icon", "label": "Super Smash Bros."},
			"desk": {"icon": "chibi_icon", "label": "Chibi-Robo", "stageLogo": true},
			"tinystage": {"icon": "smash_icon", "label": "Super Smash Bros."},
			"nintendo3ds": {"icon": "smash_icon", "label": "Super Smash Bros."},
			"urbanchampion": {"icon": "UrbanChampionSymbolSSS", "label": "Urban Champion"},
			"steeldiver": {"icon": "", "label": "Steel Diver", "stageLogo": true},
			"kingdom1": {"icon": "MarioSymbol", "label": "Super Mario"},
			"kingdom2": {"icon": "MarioSymbol", "label": "Super Mario"},
			"mushroomkingdom3": {"icon": "MarioSymbol", "label": "Super Mario"},
			"peachscastle": {"icon": "MarioSymbol", "label": "Super Mario"},
			"bowserscastle": {"icon": "MarioSymbol", "label": "Super Mario"},
			"galaxytours": {"icon": "MarioSymbol", "label": "Super Mario"},
			"yoshisisland64": {"icon": "Yoshi_Symbol", "label": "Yoshi"},
			"yoshisstory": {"icon": "Yoshi_Symbol", "label": "Yoshi"},
			"yoshisisland": {"icon": "Yoshi_Symbol", "label": "Yoshi"},
			"emeraldcave": {"icon": "warioseries", "label": "Wario"},
			"warioware": {"icon": "warioseries", "label": "Wario"},
			"junglehijinx": {"icon": "dkicon", "label": "Donkey Kong"},
			"gangplankgalleon": {"icon": "dkicon", "label": "Donkey Kong"},
			"jungleisland": {"icon": "SuperMonkeyBallSymbolSSS", "label": "Super Monkey Ball"},
			"hyrulecastle64": {"icon": "zeldaicon", "label": "The Legend of Zelda"},
			"hyruletemple": {"icon": "zeldaicon", "label": "The Legend of Zelda"},
			"hylianskies": {"icon": "zeldaicon", "label": "The Legend of Zelda"},
			"clocktown": {"icon": "zeldaicon", "label": "The Legend of Zelda"},
			"palaceoftwilight": {"icon": "zeldaicon", "label": "The Legend of Zelda"},
			"pokemoncolosseum": {"icon": "PokemonSymbol", "label": "Pokémon"},
			"saffroncity": {"icon": "PokemonSymbol", "label": "Pokémon"},
			"lakeofrage": {"icon": "PokemonSymbol", "label": "Pokémon"},
			"skypillar": {"icon": "PokemonSymbol", "label": "Pokémon"},
			"snowpointtemple": {"icon": "PokemonSymbol", "label": "Pokémon"},
			"dreamland": {"icon": "Kirby_Symbol", "label": "Kirby"},
			"rainbowroute": {"icon": "Kirby_Symbol", "label": "Kirby"},
			"butterbuilding": {"icon": "Kirby_Symbol", "label": "Kirby"},
			"dededearena": {"icon": "Kirby_Symbol", "label": "Kirby"},
			"sectorz": {"icon": "Starfox_Symbol", "label": "Star Fox"},
			"meteovoyage": {"icon": "Starfox_Symbol", "label": "Star Fox"},
			"krazoapalace": {"icon": "Starfox_Symbol", "label": "Star Fox"},
			"crateria": {"icon": "MetroidSymbolCSS", "label": "Metroid"},
			"phase8": {"icon": "MetroidSymbolCSS", "label": "Metroid"},
			"sandocean": {"icon": "fzero", "label": "F-Zero"},
			"fourside": {"icon": "mother_symbol1", "label": "EarthBound"},
			"saturnvalley": {"icon": "mother_symbol1", "label": "EarthBound"},
			"devilsmachine": {"icon": "mother_symbol1", "label": "EarthBound"},
			"castlesiege": {"icon": "marth_seriesIcon", "label": "Fire Emblem"},
			"palutenasshrine": {"icon": "piticon", "label": "Kid Icarus"},
			"venuslighthouse": {"icon": "GoldenSunSymbolSSS", "label": "Golden Sun"},
			"flatzoneplus": {"icon": "gameandwatch_icon", "label": "Game & Watch"},
			"greenhillzone": {"icon": "sonic_symbol1", "label": "Sonic"},
			"casinonightzone": {"icon": "sonic_symbol1", "label": "Sonic"},
			"skysanctuary": {"icon": "sonic_symbol1", "label": "Sonic"},
			"skullfortress": {"icon": "mmicon", "label": "Mega Man"},
			"centralhighway": {"icon": "mmicon", "label": "Mega Man"},
			"suzakucastle": {"icon": "streetfighter_icon", "label": "Street Fighter"},
			"pacmaze": {"icon": "pacmanicon", "label": "PAC-MAN"},
			"towerofsalvation": {"icon": "talesOf", "label": "Tales of"},
			"bombfactory": {"icon": "Bomberman_Symbol", "label": "Bomberman"},
			"draculascastle": {"icon": "castlevania_icon", "label": "Castlevania"},
			"chaosshrine": {"icon": "bmseries", "label": "Final Fantasy"},
			"lunarcore": {"icon": "bmseries", "label": "Final Fantasy"},
			"twilighttown": {"icon": "khicon", "label": "Kingdom Hearts"},
			"theworldthatneverwas": {"icon": "khicon", "label": "Kingdom Hearts"},
			"fairyglade": {"icon": "rayman_icon", "label": "Rayman"},
			"planetnamek": {"icon": "DragonBallsign", "label": "Dragon Ball"},
			"worldtournament": {"icon": "DragonBallsign", "label": "Dragon Ball"},
			"thousandsunny": {"icon": "luffy_icon", "label": "One Piece"},
			"konohavillage": {"icon": "Narutosymbol", "label": "Naruto"},
			"finalvalley": {"icon": "Narutosymbol", "label": "Naruto"},
			"huecomundo": {"icon": "bleach_symbol1", "label": "Bleach"},
			"smashville": {"icon": "", "label": "Animal Crossing", "stageLogo": true}
		};

		/** Tight name/id fragments only — no broad words like arena/temple/jungle. */
		private static const NAME_HINTS:Array = [
			{"re": "mushroom|peach.?castle|bowser|galaxy|mario|luigi", "icon": "MarioSymbol", "label": "Super Mario"},
			{"re": "yoshi", "icon": "Yoshi_Symbol", "label": "Yoshi"},
			{"re": "wario|emerald.?cave|palm.?tree", "icon": "warioseries", "label": "Wario"},
			{"re": "jungle.?hijinx|gangplank|donkey.?kong|\\bdk\\b", "icon": "dkicon", "label": "Donkey Kong"},
			{"re": "jungle.?island|monkey.?ball", "icon": "SuperMonkeyBallSymbolSSS", "label": "Super Monkey Ball"},
			{"re": "\\bdesk\\b|chibi.?robo", "icon": "chibi_icon", "label": "Chibi-Robo"},
			{"re": "hyrule|hylian|clock.?town|palace.?of.?twilight|zelda|ganon|gerudo", "icon": "zeldaicon", "label": "The Legend of Zelda"},
			{"re": "pokemon|pokémon|saffron|sky.?pillar|snowpoint|lake.?of.?rage|unova|pokemon.?master|atbapm|team.?rocket|pok.?mon", "icon": "PokemonSymbol", "label": "Pokémon"},
			{"re": "dream.?land|rainbow.?route|butter.?building|dedede", "icon": "Kirby_Symbol", "label": "Kirby"},
			{"re": "sector.?z|meteo|krazoa|corneria|star.?fox", "icon": "Starfox_Symbol", "label": "Star Fox"},
			{"re": "crateria|brinstar|norfair|phase.?8|metroid|samus", "icon": "MetroidSymbolCSS", "label": "Metroid"},
			{"re": "sand.?ocean|mute.?city|big.?blue|f.?zero", "icon": "fzero", "label": "F-Zero"},
			{"re": "fourside|saturn.?valley|devil.?s.?machine|earthbound|onett|ness", "icon": "mother_symbol1", "label": "EarthBound"},
			{"re": "castle.?siege|fire.?emblem|marth", "icon": "marth_seriesIcon", "label": "Fire Emblem"},
			{"re": "palutena|skyworld|kid.?icarus", "icon": "piticon", "label": "Kid Icarus"},
			{"re": "flat.?zone|game.?&.?watch", "icon": "gameandwatch_icon", "label": "Game & Watch"},
			{"re": "green.?hill|casino.?night|sky.?sanctuary|sonic", "icon": "sonic_symbol1", "label": "Sonic"},
			{"re": "skull.?fortress|central.?highway|wily|mega.?man", "icon": "mmicon", "label": "Mega Man"},
			{"re": "suzaku|street.?fighter", "icon": "streetfighter_icon", "label": "Street Fighter"},
			{"re": "pac.?maze|pac.?man|pacman", "icon": "pacmanicon", "label": "PAC-MAN"},
			{"re": "tower.?of.?salvation|tales", "icon": "talesOf", "label": "Tales of"},
			{"re": "bomb.?factory|bomberman", "icon": "Bomberman_Symbol", "label": "Bomberman"},
			{"re": "dracula|castlevania|simon", "icon": "castlevania_icon", "label": "Castlevania"},
			{"re": "chaos.?shrine|lunar.?core|black.?mage|final.?fantasy", "icon": "bmseries", "label": "Final Fantasy"},
			{"re": "binding.?of.?isaac", "icon": "isaac_icon", "label": "The Binding of Isaac"},
			{"re": "twilight.?town|world.?that.?never|kingdom.?hearts|sora", "icon": "khicon", "label": "Kingdom Hearts"},
			{"re": "venus.?lighthouse|golden.?sun", "icon": "GoldenSunSymbolSSS", "label": "Golden Sun"},
			{"re": "fairy.?glade|rayman", "icon": "rayman_icon", "label": "Rayman"},
			{"re": "namek|world.?tournament|dragon.?ball|goku", "icon": "DragonBallsign", "label": "Dragon Ball"},
			{"re": "thousand.?sunny|one.?piece|luffy", "icon": "luffy_icon", "label": "One Piece"},
			{"re": "konoha|final.?valley|naruto", "icon": "Narutosymbol", "label": "Naruto"},
			{"re": "hueco|bleach|ichigo", "icon": "bleach_symbol1", "label": "Bleach"},
			{"re": "smashville|animal.?crossing", "icon": "", "label": "Animal Crossing", "stageLogo": true},
			{"re": "steel.?diver", "icon": "", "label": "Steel Diver", "stageLogo": true},
			{"re": "urban.?champion", "icon": "UrbanChampionSymbolSSS", "label": "Urban Champion"},
			{"re": "battlefield|final.?destination|multi.?man|polygon|waiting.?room|metal.?cavern", "icon": "smash_icon", "label": "Super Smash Bros."}
		];

		public static function invalidate():void
		{
			s_stageKey = {};
			s_keyStages = {};
			s_keyLabel = {};
			s_iconLabels = {};
			s_built = false;
		}

		public static function mappedStageIds():Array
		{
			var out:Array;
			var sid:String;
			out = [];
			for (sid in STAGE_SERIES)
			{
				if (sid)
				{
					out.push(sid);
				};
			};
			return (out);
		}

		public static function ensureBuilt(stageIds:Array):void
		{
			var i:int;
			var sid:String;
			if (s_built && stageIds && stageIds.length > 0)
			{
				return;
			};
			loadCharacterIcons();
			s_stageKey = {};
			s_keyStages = {};
			i = 0;
			while (stageIds && i < stageIds.length)
			{
				sid = String(stageIds[i]);
				i++;
				if (!sid || sid == MusicStageVisuals.TRAINING_GRID_ID)
				{
					continue;
				};
				keyForStage(sid);
			};
			// Always register STAGE_SERIES (e.g. lunarcore) even if a build
			// temporarily omitted them from the select roster.
			for (sid in STAGE_SERIES)
			{
				if (sid && s_stageKey[sid] == null)
				{
					keyForStage(sid);
				};
			};
			s_built = true;
		}

		public static function keyForStage(stageId:String):String
		{
			var key:String;
			var exact:Object;
			var hint:Object;
			if (!stageId || stageId == MusicStageVisuals.OTHER_STAGE_ID)
			{
				return (KEY_OTHER);
			};
			if (s_stageKey[stageId] != null)
			{
				return String(s_stageKey[stageId]);
			};
			loadCharacterIcons();
			exact = STAGE_SERIES[stageId];
			if (exact)
			{
				key = seriesKeyFromEntry(exact, stageId);
				s_keyLabel[key] = String(exact.label);
				remember(stageId, key);
				return (key);
			};
			hint = hintForStage(stageId);
			if (hint)
			{
				key = seriesKeyFromEntry(hint, stageId);
				s_keyLabel[key] = String(hint.label);
				remember(stageId, key);
				return (key);
			};
			// Never clone stagePreviewer here — that leaked GBs when resolving many stages.
			key = KEY_UNKNOWN;
			s_keyLabel[key] = "Other";
			remember(stageId, key);
			return (key);
		}

		public static function seriesKeys():Array
		{
			var out:Array;
			var k:String;
			out = [];
			for (k in s_keyStages)
			{
				if (k != KEY_OTHER && k != KEY_UNKNOWN)
				{
					out.push(k);
				};
			};
			out.sort(function (a:String, b:String):int
			{
				var la:String = seriesLabel(a).toLowerCase();
				var lb:String = seriesLabel(b).toLowerCase();
				if (la < lb)
				{
					return (-1);
				};
				if (la > lb)
				{
					return (1);
				};
				return (0);
			});
			return (out);
		}

		/** Franchise symbol keys (icon:*) for the song-settings picker. */
		public static function allSymbolKeys():Array
		{
			var out:Array;
			var k:String;
			var icon:String;
			loadCharacterIcons();
			out = [];
			for (icon in s_iconLabels)
			{
				if (icon)
				{
					out.push("icon:" + icon);
				};
			};
			for (k in s_keyStages)
			{
				if (k && k.indexOf("icon:") == 0 && out.indexOf(k) < 0)
				{
					out.push(k);
				};
			};
			out.sort(function (a:String, b:String):int
			{
				var la:String = seriesLabel(a).toLowerCase();
				var lb:String = seriesLabel(b).toLowerCase();
				if (la < lb)
				{
					return (-1);
				};
				if (la > lb)
				{
					return (1);
				};
				return (0);
			});
			return (out);
		}

		public static function stagesForSeries(seriesKey:String):Array
		{
			var list:Array;
			list = s_keyStages[seriesKey] as Array;
			return list ? list.concat() : [];
		}

		public static function seriesLabel(seriesKey:String):String
		{
			var ov:String;
			if (!seriesKey)
			{
				return ("");
			};
			ov = MusicOverrides.seriesLabel(seriesKey);
			if (ov)
			{
				return (ov);
			};
			if (seriesKey == KEY_ALL)
			{
				return ("All");
			};
			if (seriesKey == KEY_OTHER || seriesKey == KEY_UNKNOWN)
			{
				return ("Other");
			};
			if (s_keyLabel[seriesKey])
			{
				return String(s_keyLabel[seriesKey]);
			};
			if (seriesKey.indexOf("icon:") == 0)
			{
				return (prettyIconName(seriesKey.substr(5)));
			};
			if (seriesKey.indexOf("stage:") == 0)
			{
				return (MusicStageVisuals.stageDisplayName(seriesKey.substr(6)));
			};
			return (seriesKey);
		}

		public static function iconLinkage(seriesKey:String):String
		{
			if (seriesKey == KEY_ALL)
			{
				return ("smash_icon");
			};
			if (seriesKey == KEY_OTHER || seriesKey == KEY_UNKNOWN)
			{
				return ("questionicon");
			};
			if (seriesKey.indexOf("icon:") == 0)
			{
				return (seriesKey.substr(5));
			};
			return (null);
		}

		/** Compact icon fitted inside maxSize box, centered at 0,0. Optional white tint. */
		public static function attachIcon(parent:Sprite, seriesKey:String, maxSize:Number,
			tintWhite:Boolean = false):DisplayObject
		{
			var holder:Sprite;
			var logo:DisplayObject;
			var link:String;
			var stages:Array;
			var sid:String;
			if (!parent)
			{
				return (null);
			};
			holder = new Sprite();
			parent.addChild(holder);
			if (seriesKey && seriesKey.indexOf("stage:") == 0)
			{
				sid = seriesKey.substr(6);
				logo = MusicStageVisuals.extractLiveLogo(sid);
				if (!logo)
				{
					logo = MusicStageVisuals.extractSelectLogo(sid);
				};
			};
			link = iconLinkage(seriesKey);
			if (!logo && link)
			{
				logo = tryLibraryIcon(link);
			};
			if (!logo && seriesKey != KEY_ALL && seriesKey != KEY_OTHER)
			{
				stages = stagesForSeries(seriesKey);
				sid = stages.length > 0 ? String(stages[0]) : null;
				if (sid)
				{
					logo = MusicStageVisuals.extractLiveLogo(sid);
					if (!logo)
					{
						logo = MusicStageVisuals.extractSelectLogo(sid);
					};
				};
			};
			// Never tint full _stage_select / albumMark — that paints a white rectangle.
			// Smash ball is the default when no franchise SymbolSSS / logo peel exists
			// (e.g. Smashville and Steel Diver have no library series export).
			if (!logo)
			{
				logo = tryLibraryIcon("smash_icon") || tryLibraryIcon("smash_symbol");
			};
			if (logo)
			{
				if (tintWhite)
				{
					applyTint(logo, MusicTheme.symbol());
				};
				if (MusicTheme.symbolGlow())
				{
					try
					{
						// Soft white halo behind tinted symbols (never uses symbol tint color).
						logo.filters = [new GlowFilter(0xFFFFFF, 0.28, 6, 6, 1, 2)];
					}
					catch (glowErr:*)
					{
					};
				};
				holder.addChild(logo);
				fitInBox(logo, maxSize * 0.72);
			};
			return (holder);
		}

		/**
		 * Series grid tile: stage preview fills the cell, white vector series
		 * symbol (50% larger than prior) centered on top. Masked to cell bounds.
		 */
		public static function attachSeriesTile(parent:Sprite, seriesKey:String, stageId:String,
			cellW:Number, cellH:Number, showSymbol:Boolean = true):Sprite
		{
			var tile:Sprite;
			var artHost:Sprite;
			var mask:Sprite;
			var preview:MovieClip;
			var symbolHost:Sprite;
			var fillId:String;
			var stages:Array;
			var dim:Sprite;
			var symbolSize:Number;
			var meta:Object;
			var iconKey:String;
			tile = new Sprite();
			if (parent)
			{
				parent.addChild(tile);
			};
			artHost = new Sprite();
			tile.addChild(artHost);
			mask = new Sprite();
			mask.graphics.beginFill(0xFFFFFF, 1);
			mask.graphics.drawRoundRect(-cellW * 0.5, -cellH * 0.5, cellW, cellH, 8, 8);
			mask.graphics.endFill();
			tile.addChild(mask);
			artHost.mask = mask;
			fillId = stageId;
			if (seriesKey && seriesKey.indexOf("stage:") == 0)
			{
				fillId = seriesKey.substr(6);
			};
			meta = MusicOverrides.getCustomSeries(seriesKey);
			if (meta && meta.stageArt)
			{
				fillId = String(meta.stageArt);
			};
			iconKey = seriesKey;
			if (meta && meta.symbolKey)
			{
				iconKey = String(meta.symbolKey);
			};
			if (!fillId || fillId == KEY_ALL || fillId == KEY_OTHER)
			{
				stages = stagesForSeries(seriesKey);
				fillId = stages.length > 0 ? String(stages[0]) : MusicStageVisuals.OTHER_STAGE_ID;
			};
			if (seriesKey == KEY_ALL)
			{
				fillId = "battlefield";
			};
			if (seriesKey == KEY_OTHER || seriesKey == KEY_UNKNOWN)
			{
				// attachTileArt rejects OTHER_STAGE_ID — use Training Grid art.
				if (!fillId || fillId == KEY_OTHER || fillId == KEY_UNKNOWN
					|| fillId == MusicStageVisuals.OTHER_STAGE_ID)
				{
					fillId = MusicStageVisuals.TRAINING_GRID_ID;
				};
			};
			preview = MusicStageVisuals.attachTileArt(artHost, fillId, cellW, cellH);
			if (preview)
			{
				// Host (with fill + icon) is top-left of cell; center it under the mask.
				if (preview.parent)
				{
					preview.parent.x = -cellW * 0.5;
					preview.parent.y = -cellH * 0.5;
				}
				else
				{
					preview.x -= cellW * 0.5;
					preview.y -= cellH * 0.5;
				};
			}
			else
			{
				artHost.graphics.beginFill(0x1A1A24, 1);
				artHost.graphics.drawRect(-cellW * 0.5, -cellH * 0.5, cellW, cellH);
				artHost.graphics.endFill();
			};
			if (showSymbol)
			{
				dim = new Sprite();
				dim.graphics.beginFill(0x050508, 0.35);
				dim.graphics.drawRect(-cellW * 0.5, -cellH * 0.5, cellW, cellH);
				dim.graphics.endFill();
				artHost.addChild(dim);
				symbolHost = new Sprite();
				tile.addChild(symbolHost);
				// 0.45 * 1.5 (earlier) * 1.2 = 0.81 of cell.
				symbolSize = Math.min(cellW, cellH) * 0.81;
				attachIcon(symbolHost, iconKey, symbolSize, true);
			};
			return (tile);
		}

		private static function applyTint(obj:DisplayObject, color:uint):void
		{
			var c:DisplayObjectContainer;
			var i:int;
			var ct:ColorTransform;
			var r:uint;
			var g:uint;
			var b:uint;
			if (!obj)
			{
				return;
			};
			r = (color >> 16) & 0xFF;
			g = (color >> 8) & 0xFF;
			b = color & 0xFF;
			ct = new ColorTransform(0, 0, 0, 1, r, g, b, 0);
			try
			{
				obj.transform.colorTransform = ct;
			}
			catch (err:*)
			{
			};
			if (!(obj is DisplayObjectContainer))
			{
				return;
			};
			c = DisplayObjectContainer(obj);
			i = 0;
			while (i < c.numChildren)
			{
				applyTint(c.getChildAt(i), color);
				i++;
			};
		}

		private static function loadCharacterIcons():void
		{
			var RM:*;
			var mappings:*;
			var meta:Object;
			var chars:Object;
			var id:String;
			var icon:String;
			var name:String;
			if (s_iconLabels && hasKeys(s_iconLabels))
			{
				return;
			};
			s_iconLabels = {};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				mappings = RM.getResourceByID("mappings");
				meta = mappings && mappings.getProp("metadata") ? mappings.getProp("metadata") : null;
				chars = meta && meta.character ? meta.character : null;
				if (!chars && mappings && mappings.getProp)
				{
					chars = mappings.getProp("character");
				};
				if (!chars && mappings)
				{
					try
					{
						chars = mappings["character"] || (mappings.data && mappings.data.character);
					}
					catch (propErr:*)
					{
					};
				};
			}
			catch (err:*)
			{
				chars = null;
			};
			if (!chars)
			{
				return;
			};
			for (id in chars)
			{
				if (!chars[id] || !chars[id].seriesIcon)
				{
					continue;
				};
				icon = String(chars[id].seriesIcon);
				name = chars[id].name ? String(chars[id].name) : id;
				if (!s_iconLabels[icon])
				{
					s_iconLabels[icon] = franchiseFromCharacter(name, icon);
				};
			};
		}

		private static function franchiseFromCharacter(charName:String, icon:String):String
		{
			var n:String;
			n = (charName || "").toLowerCase();
			if (n.indexOf("mario") >= 0 || n.indexOf("luigi") >= 0 || n.indexOf("peach") >= 0
				|| n.indexOf("bowser") >= 0)
			{
				return ("Super Mario");
			};
			if (n.indexOf("yoshi") >= 0)
			{
				return ("Yoshi");
			};
			if (n.indexOf("link") >= 0 || n.indexOf("zelda") >= 0 || n.indexOf("sheik") >= 0
				|| n.indexOf("ganon") >= 0)
			{
				return ("The Legend of Zelda");
			};
			if (n.indexOf("samus") >= 0 || n.indexOf("zamus") >= 0)
			{
				return ("Metroid");
			};
			if (n.indexOf("pikachu") >= 0 || n.indexOf("pichu") >= 0 || n.indexOf("jiggly") >= 0
				|| n.indexOf("lucario") >= 0)
			{
				return ("Pokémon");
			};
			if (n.indexOf("fox") >= 0 || n.indexOf("falco") >= 0 || n.indexOf("krystal") >= 0)
			{
				return ("Star Fox");
			};
			if (n.indexOf("kirby") >= 0 || n.indexOf("dedede") >= 0 || n.indexOf("meta knight") >= 0
				|| n.indexOf("bandana") >= 0)
			{
				return ("Kirby");
			};
			if (n.indexOf("donkey") >= 0 || n.indexOf("diddy") >= 0)
			{
				return ("Donkey Kong");
			};
			if (n.indexOf("sonic") >= 0 || n.indexOf("tails") >= 0)
			{
				return ("Sonic");
			};
			if (n.indexOf("marth") >= 0 || n.indexOf("ike") >= 0 || n.indexOf("roy") >= 0)
			{
				return ("Fire Emblem");
			};
			if (n.indexOf("captain falcon") >= 0 || n.indexOf("falcon") >= 0)
			{
				return ("F-Zero");
			};
			if (n.indexOf("simon") >= 0)
			{
				return ("Castlevania");
			};
			if (n.indexOf("wario") >= 0)
			{
				return ("Wario");
			};
			return (prettyIconName(icon));
		}

		private static function hintForStage(stageId:String):Object
		{
			var blob:String;
			var i:int;
			var h:Object;
			var re:RegExp;
			blob = (stageId + " " + MusicStageVisuals.stageDisplayName(stageId)).toLowerCase();
			i = 0;
			while (i < NAME_HINTS.length)
			{
				h = NAME_HINTS[i];
				i++;
				try
				{
					re = new RegExp(String(h.re), "i");
					if (re.test(blob))
					{
						return (h);
					};
				}
				catch (err:*)
				{
				};
			};
			return (null);
		}

		/**
		 * Best-effort series for a stock/pack track from id + title
		 * (e.g. bgm_ATBAPM "Aim to Be a Pokémon Master" → Pokémon).
		 */
		public static function seriesKeyForTrack(trackId:String, title:String = null):String
		{
			var blob:String;
			var i:int;
			var h:Object;
			var re:RegExp;
			var key:String;
			if (!trackId && !title)
			{
				return (null);
			};
			blob = ((trackId || "") + " " + (title || "")).toLowerCase();
			blob = blob.replace(/[àáâãäå]/g, "a").replace(/[èéêë]/g, "e")
				.replace(/[ìíîï]/g, "i").replace(/[òóôõö]/g, "o")
				.replace(/[ùúûü]/g, "u").replace(/ñ/g, "n");
			i = 0;
			while (i < NAME_HINTS.length)
			{
				h = NAME_HINTS[i];
				i++;
				if (!h || Boolean(h.stageLogo))
				{
					continue;
				};
				try
				{
					re = new RegExp(String(h.re), "i");
					if (re.test(blob))
					{
						key = seriesKeyFromEntry(h, trackId || "track");
						if (key && key.indexOf("icon:") == 0)
						{
							if (!s_keyLabel[key] && h.label)
							{
								s_keyLabel[key] = String(h.label);
							};
							return (key);
						};
					};
				}
				catch (err:*)
				{
				};
			};
			return (null);
		}

		/** icon:… for library symbols; stage:id when the stage supplies its own logo. */
		private static function seriesKeyFromEntry(entry:Object, stageId:String):String
		{
			var icon:String;
			if (!entry)
			{
				return ("icon:smash_icon");
			};
			icon = entry.icon != null ? String(entry.icon) : "";
			// Non-empty franchise icon wins over stageLogo (e.g. Desk → chibi_icon).
			if (icon.length > 0)
			{
				return ("icon:" + icon);
			};
			if (Boolean(entry.stageLogo))
			{
				return ("stage:" + stageId);
			};
			return ("stage:" + stageId);
		}

		private static function remember(stageId:String, key:String):void
		{
			var list:Array;
			s_stageKey[stageId] = key;
			list = s_keyStages[key] as Array;
			if (!list)
			{
				list = [];
				s_keyStages[key] = list;
			};
			if (list.indexOf(stageId) < 0)
			{
				list.push(stageId);
			};
		}

		private static function prettyIconName(icon:String):String
		{
			var s:String;
			if (!icon)
			{
				return ("Series");
			};
			s = icon.replace(/_/g, " ").replace(/icon/gi, "").replace(/symbol/gi, "");
			s = s.replace(/css$/i, "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
			if (s.length < 1)
			{
				return (icon);
			};
			return (s.charAt(0).toUpperCase() + s.substr(1));
		}

		private static function hasKeys(obj:Object):Boolean
		{
			var k:String;
			for (k in obj)
			{
				return (true);
			};
			return (false);
		}

		private static function tryLibraryIcon(name:String):MovieClip
		{
			var mc:MovieClip;
			mc = MusicStageVisuals.getLibraryMC(name);
			if (!mc)
			{
				return (null);
			};
			try
			{
				mc = mc.clone() as MovieClip;
			}
			catch (err:*)
			{
			};
			return (mc);
		}

		private static function fitInBox(obj:DisplayObject, box:Number):void
		{
			var b:*;
			var w:Number;
			var h:Number;
			var s:Number;
			if (!obj || box <= 0)
			{
				return;
			};
			obj.x = 0;
			obj.y = 0;
			obj.scaleX = 1;
			obj.scaleY = 1;
			b = obj.getBounds(obj);
			w = b.width > 0 ? b.width : obj.width;
			h = b.height > 0 ? b.height : obj.height;
			if (w <= 0 || h <= 0)
			{
				return;
			};
			s = Math.min(box / w, box / h);
			if (s > 0 && s < 50)
			{
				obj.scaleX = s;
				obj.scaleY = s;
			};
			// Recenter using scaled bounds so asymmetric symbols land on the CD hub.
			b = obj.getBounds(obj.parent || obj);
			if (obj.parent)
			{
				b = obj.getBounds(obj.parent);
				obj.x -= (b.left + b.right) * 0.5;
				obj.y -= (b.top + b.bottom) * 0.5;
			}
			else
			{
				obj.x = -((b.x + w * 0.5) * obj.scaleX);
				obj.y = -((b.y + h * 0.5) * obj.scaleY);
			};
		}
	}
}
