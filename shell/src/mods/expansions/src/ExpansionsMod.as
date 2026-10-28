package
{
	import flash.display.Sprite;

	/**
	 * Built-in expansions pack: drop-in events, drop-in characters, and real CSS slots.
	 * Parts boot in the order the separate packs used to boot (alphabetical by old id).
	 */
	public class ExpansionsMod extends Sprite
	{
		private var m_parts:Array;

		public function ExpansionsMod()
		{
			super();
			m_parts = [new EventExpansionsMod(), new ExpansionLoaderMod(), new RealExpansionsMod()];
		}

		public function onBoot(host:*):void
		{
			forward("onBoot", [host]);
			trace("[expansions] boot parts=" + m_parts.length);
		}

		public function onBootEnd():void
		{
			forward("onBootEnd", []);
		}

		private function forward(method:String, args:Array):void
		{
			for each (var part:* in m_parts)
			{
				if (!(method in part))
				{
					continue;
				};
				try
				{
					(part[method] as Function).apply(part, args);
				}
				catch (err:*)
				{
					trace("[expansions] " + method + " failed in " + part + ": " + err);
				};
			}
		}
	}
}
