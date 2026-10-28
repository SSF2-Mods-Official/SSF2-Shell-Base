package com.sbxmod.paletteMaker
{
	/** Each vanilla character gets their own stage when the series has more than one. */
	public class StudioHomeStages
	{
		public function StudioHomeStages()
		{
		}

		private static var parsed:Object = null;

		/**
		 * stages: one stage per character. leftovers: one each for a vanilla id missing from stages.
		 * Sandbag is restarea. Ganondorf is palaceoftwilight. Zelda is hylianskies.
		 */
		private static const HOME_JSON:String =
			'{"stages":{"mario":"kingdom1","luigi":"kingdom2","peach":"galaxytours","bowser":"finaldestination","waluigi":"emeraldcave","yoshi":"yoshisstory","wario":"warioware","donkeykong":"junglehijinx","link":"hyrulecastle64","zelda":"hylianskies","sheik":"hyruletemple","ganondorf":"palaceoftwilight","pikachu":"saffroncity","pichu":"lakeofrage","jigglypuff":"pokemoncolosseum","lucario":"snowpointtemple","kirby":"dreamland","dedede":"dededearena","metaknight":"butterbuilding","bandanadee":"rainbowroute","fox":"sectorz","falco":"meteovoyage","krystal":"krazoapalace","samus":"phase8","zamus":"crateria","captainfalcon":"sandocean","ness":"saturnvalley","marth":"castlesiege","pit":"palutenasshrine","isaac":"venuslighthouse","chibirobo":"desk","gameandwatch":"flatzoneplus","sonic":"greenhillzone","tails":"casinonightzone","megaman":"skullfortress","ryu":"suzakucastle","pacman":"pacmaze","lloyd":"towerofsalvation","simon":"draculascastle","bomberman":"bombfactory","blackmage":"chaosshrine","sora":"theworldthatneverwas","rayman":"fairyglade","goku":"planetnamek","luffy":"thousandsunny","naruto":"konohavillage","ichigo":"huecomundo","sandbag":"restarea"},'
			+ '"vanilla":["mario","luigi","peach","bowser","yoshi","wario","waluigi","donkeykong","link","zelda","sheik","ganondorf","pikachu","pichu","jigglypuff","lucario","kirby","dedede","metaknight","bandanadee","fox","falco","krystal","samus","zamus","captainfalcon","ness","marth","pit","isaac","chibirobo","gameandwatch","sonic","tails","megaman","ryu","pacman","lloyd","simon","bomberman","blackmage","sora","rayman","goku","luffy","naruto","ichigo","sandbag"],'
			+ '"leftovers":["homeruncontest","bowserscastle","battlefield","finaldestination","smashville","clocktown","skypillar","skysanctuary","finalvalley","yoshisisland","yoshisisland64","centralhighway","worldtournament","twilighttown","waitingroom","gangplankgalleon","peachscastle","fourside","devilsmachine","lunarcore","metalcavern","jungleisland","nintendo3ds"]}';

		/** Series stage, or a leftover stage for a vanilla id that is not in the map. Empty for anyone else. */
		public static function homeStageFor(statsName:String):String
		{
			var data:Object;
			var stages:Object;
			var vanilla:Array;
			var leftovers:Array;
			var idx:int;
			var missing:int;
			var i:int;
			var who:String;
			if (!statsName)
			{
				return "";
			};
			who = statsName == "gigabowser" ? "bowser" : statsName;
			data = map();
			if (!data)
			{
				return "";
			};
			stages = data.stages;
			if (stages && stages[who])
			{
				return String(stages[who]);
			};
			vanilla = data.vanilla as Array;
			leftovers = data.leftovers as Array;
			if (!vanilla || !leftovers)
			{
				return "";
			};
			idx = vanilla.indexOf(who);
			if (idx < 0)
			{
				return "";
			};
			missing = 0;
			i = 0;
			while (i < idx)
			{
				if (!stages || !stages[vanilla[i]])
				{
					missing++;
				};
				i++;
			};
			if (missing >= leftovers.length)
			{
				return "restarea";
			};
			return String(leftovers[missing]);
		}

		/** Bowser's home stage is Final Destination, and that open plays Bowser's castle. */
		public static function homeSongFor(statsName:String):String
		{
			if (statsName == "bowser" || statsName == "gigabowser")
			{
				return "bgm_bowserscastle";
			};
			return "";
		}

		private static function map():Object
		{
			if (parsed)
			{
				return parsed;
			};
			try
			{
				parsed = JSON.parse(HOME_JSON);
			}
			catch (err:Error)
			{
				parsed = {};
			};
			return parsed;
		}
	}
}
