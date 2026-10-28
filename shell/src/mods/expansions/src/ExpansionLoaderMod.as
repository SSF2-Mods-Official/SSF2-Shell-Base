package
{
	import com.mcleodgaming.ssf2.util.ExpansionResources;
	import com.mcleodgaming.ssf2.util.VectorIconSvg;
	import flash.display.Sprite;

	/**
	 * Enables drop-in character expansions under expansions/character/.
	 * Discovery/load APIs live on ModHost → ResourceManager; this pack owns the feature flag.
	 */
	public class ExpansionLoaderMod extends Sprite
	{
		public function ExpansionLoaderMod()
		{
			super();
		}

		public function onBoot(host:*):void
		{
			if (host)
			{
				try
				{
					host.patch("expansion_loader.rm", ExpansionResources.dispatch);
					host.patch("expansion_loader.vectorIcon", onVectorIcon);
					host["discoverAndLoadExpansions"](function():void
					{
						trace("[expansion_loader] discovery/load complete");
					});
				}
				catch (err:*)
				{
					trace("[expansion_loader] discover failed: " + err);
				};
			};
			trace("[expansion_loader] boot");
		}

		public function onVectorIcon(op:String, a:* = null, b:* = null):*
		{
			return VectorIconSvg.dispatch(op, a, b);
		}

		public function onBootEnd():void
		{
			trace("[expansion_loader] onBootEnd — drop-in slots remain until restart");
		}
	}
}
