package
{
	import flash.display.Sprite;

	/**
	 * Built-in debug pack: full debug console and the hitbox test menu.
	 */
	public class DebugMod extends Sprite
	{
		private var m_parts:Array;

		public function DebugMod()
		{
			super();
			m_parts = [new DebugConsoleMod(), new DebugHitboxMod()];
		}

		public function onBoot(host:*):void
		{
			forward("onBoot", [host]);
			trace("[debug] boot parts=" + m_parts.length);
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
					trace("[debug] " + method + " failed in " + part + ": " + err);
				};
			}
		}
	}
}
