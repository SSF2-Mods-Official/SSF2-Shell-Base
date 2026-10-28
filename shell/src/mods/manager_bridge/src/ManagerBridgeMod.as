package
{
	import flash.display.Sprite;

	/**
	 * Built-in link to SSF2 Mod Manager and the SSF2 Stream extension:
	 * launch.json deep links, instant match, and the game.log bridge.
	 */
	public class ManagerBridgeMod extends Sprite
	{
		private var m_parts:Array;

		public function ManagerBridgeMod()
		{
			super();
			m_parts = [new Ssf2StreamMod()];
		}

		public function onBoot(host:*):void
		{
			forward("onBoot", [host]);
			trace("[manager_bridge] boot parts=" + m_parts.length);
		}

		public function onBootStart(host:*):void
		{
			forward("onBootStart", [host]);
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
					trace("[manager_bridge] " + method + " failed in " + part + ": " + err);
				};
			}
		}
	}
}
