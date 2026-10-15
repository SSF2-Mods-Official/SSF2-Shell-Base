package
{
	import flash.display.MovieClip;

	/** Soft platform for menu stage scripts (Smashville getPlatform(...).getMC()). */
	public class MenuBgPlatformStub
	{
		private var m_mc:MovieClip;

		public function MenuBgPlatformStub(mc:MovieClip)
		{
			super();
			m_mc = mc || new MovieClip();
		}

		public function getMC():MovieClip
		{
			return m_mc;
		}

		public function getInstanceName():String
		{
			return m_mc && m_mc.name ? m_mc.name : "";
		}
	}
}
