package
{
	/**
	 * Persistent My Jukebox UI colors (overrides.json theme block).
	 */
	public class MusicTheme
	{
		public static const DEFAULT_UI:uint = 0xFFFFFF;
		public static const DEFAULT_SYMBOL:uint = 0xFFFFFF;
		public static const DEFAULT_SELECT:uint = 0xE8A020;

		public static function ui():uint
		{
			return MusicOverrides.themeColor("ui", DEFAULT_UI);
		}

		/** Soft secondary text/icons derived from UI color. */
		public static function uiSoft():uint
		{
			return mix(ui(), 0x6A6A78, 0.42);
		}

		public static function symbol():uint
		{
			return MusicOverrides.themeColor("symbol", DEFAULT_SYMBOL);
		}

		public static function symbolGlow():Boolean
		{
			return MusicOverrides.themeFlag("symbolGlow", false);
		}

		public static function setSymbolGlow(on:Boolean):void
		{
			MusicOverrides.setThemeFlag("symbolGlow", on);
		}

		public static function mix(a:uint, b:uint, t:Number):uint
		{
			var ar:int;
			var ag:int;
			var ab:int;
			var br:int;
			var bg:int;
			var bb:int;
			t = Math.max(0, Math.min(1, t));
			ar = (a >> 16) & 0xFF;
			ag = (a >> 8) & 0xFF;
			ab = a & 0xFF;
			br = (b >> 16) & 0xFF;
			bg = (b >> 8) & 0xFF;
			bb = b & 0xFF;
			return (uint(ar + (br - ar) * t) << 16)
				| (uint(ag + (bg - ag) * t) << 8)
				| uint(ab + (bb - ab) * t);
		}

		public static function select():uint
		{
			return MusicOverrides.themeColor("select", DEFAULT_SELECT);
		}

		public static function setUi(c:uint):void
		{
			MusicOverrides.setThemeColor("ui", c);
		}

		public static function setSymbol(c:uint):void
		{
			MusicOverrides.setThemeColor("symbol", c);
		}

		public static function setSelect(c:uint):void
		{
			MusicOverrides.setThemeColor("select", c);
		}

		public static function resetDefaults():void
		{
			MusicOverrides.setThemeColor("ui", DEFAULT_UI);
			MusicOverrides.setThemeColor("symbol", DEFAULT_SYMBOL);
			MusicOverrides.setThemeColor("select", DEFAULT_SELECT);
			MusicOverrides.setThemeFlag("symbolGlow", false);
		}
	}
}
