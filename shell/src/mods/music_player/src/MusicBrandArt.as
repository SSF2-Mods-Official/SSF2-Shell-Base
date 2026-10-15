package
{
	import flash.display.MovieClip;
	import ssf2mm.shared.EngineRefs;

	/** SSF2 title logo — same linkage AttractMode uses. */
	public class MusicBrandArt
	{
		private static const LOGO_LINK:String = "menu_main_fla.SuperSmashFlash2Logo_16";

		public static function createSsf2Logo():MovieClip
		{
			var RM:*;
			var clip:MovieClip;
			var logoClass:Class;
			clip = null;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				try
				{
					clip = RM["getLibraryMC"](LOGO_LINK) as MovieClip;
				}
				catch (e1:*)
				{
				};
				if (!clip && RM["getLibraryClass"] is Function)
				{
					try
					{
						logoClass = RM["getLibraryClass"](LOGO_LINK) as Class;
						if (logoClass)
						{
							clip = new logoClass() as MovieClip;
						};
					}
					catch (e2:*)
					{
					};
				};
			}
			catch (rmErr:*)
			{
			};
			if (!clip)
			{
				try
				{
					logoClass = EngineRefs.cls(LOGO_LINK) as Class;
					if (logoClass)
					{
						clip = new logoClass() as MovieClip;
					};
				}
				catch (e3:*)
				{
				};
			};
			if (clip)
			{
				try
				{
					clip.gotoAndStop(clip.totalFrames > 1 ? clip.totalFrames : 1);
				}
				catch (playErr:*)
				{
				};
			};
			return (clip);
		}
	}
}
