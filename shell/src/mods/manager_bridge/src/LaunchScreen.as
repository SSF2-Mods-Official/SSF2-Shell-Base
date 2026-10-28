package
{
	/** Launch screen names from launch.json. cssedit opens Versus character select. sssedit opens stage select. */
	public class LaunchScreen
	{
		public static function menuKey(screen:String):String
		{
			var key:String;
			key = String(screen || "").toLowerCase();
			if (key == "cssedit")
			{
				return ("versus_css");
			};
			if (key == "sssedit")
			{
				return ("sss");
			};
			return (key);
		}
	}
}
