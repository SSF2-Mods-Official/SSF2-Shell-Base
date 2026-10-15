package com.sbxmod.paletteMaker
{
	import ssf2mm.shared.EngineRefs;

	/**
	 * Runtime bridge to SSF2 engine types so palette_maker compiles src-only
	 * (no decompiled scripts / engine SWCs), matching other external mods.
	 */
	public class Ssf2
	{
		public static function cls(name:String):*
		{
			return EngineRefs.cls(name);
		}

		/** One game.log line through ModHost.appendGameLog. Never throws. */
		public static function gameLog(line:String):void
		{
			EngineRefs.gameLog(line);
		}

		public static function get Main():*
		{
			return EngineRefs.Main;
		}

		public static function get Utils():*
		{
			return EngineRefs.Utils;
		}

		public static function get ResourceManager():*
		{
			return EngineRefs.ResourceManager;
		}

		public static function get Resource():*
		{
			return EngineRefs.ssf2("util.Resource");
		}

		public static function get Base64():*
		{
			return EngineRefs.ssf2("util.Base64");
		}

		public static function get SoundQueue():*
		{
			return EngineRefs.SoundQueue;
		}

		public static function get MenuController():*
		{
			return EngineRefs.MenuController;
		}

		public static function get GameController():*
		{
			return EngineRefs.GameController;
		}

		public static function get Game():*
		{
			return EngineRefs.ssf2("controllers.Game");
		}

		public static function get EventButton():*
		{
			return EngineRefs.ssf2("controllers.EventButton");
		}

		public static function get HudMenu():*
		{
			return EngineRefs.ssf2("menus.HudMenu");
		}

		public static function get Stats():*
		{
			return EngineRefs.ssf2("engine.Stats");
		}

		public static function get MultiplayerManager():*
		{
			return EngineRefs.MultiplayerManager;
		}

		public static function get Config():*
		{
			return EngineRefs.ssf2("Config");
		}

		public static function get Mode():*
		{
			return EngineRefs.ssf2("enums.Mode");
		}

		public static function get CState():*
		{
			return EngineRefs.ssf2("enums.CState");
		}

		public static function get SSF2API():*
		{
			return EngineRefs.ssf2("api.SSF2API");
		}

		public static function get ModHost():*
		{
			return EngineRefs.ModHost;
		}

		public static function get ModHooks():*
		{
			return EngineRefs.ModHooks;
		}

		public static function get ModPatches():*
		{
			return EngineRefs.ModPatches;
		}

		public static function get SaveData():*
		{
			return EngineRefs.SaveData;
		}
	}
}
