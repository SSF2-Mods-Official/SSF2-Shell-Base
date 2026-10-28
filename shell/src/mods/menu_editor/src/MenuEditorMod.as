package
{
	import flash.display.Sprite;

	/**
	 * Built-in menu editor pack: F1 Edit Character Select and F1 Edit Stages.
	 */
	public class MenuEditorMod extends Sprite
	{
		private var m_parts:Array;

		public function MenuEditorMod()
		{
			super();
			m_parts = [new CssEditorMod(), new StageEditorMod()];
		}

		public function onBoot(host:*):void
		{
			forward("onBoot", [host]);
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
					trace("[menu_editor] " + method + " failed in " + part + ": " + err);
				};
			}
		}
	}
}
