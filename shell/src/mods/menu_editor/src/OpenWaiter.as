package
{
	import flash.display.Stage;
	import flash.events.Event;

	/**
	 * "Open the editor once its menu is on screen." start() tries now, then once per frame
	 * until isReady() is true or maxTries frames pass. stop() removes the ENTER_FRAME listener;
	 * the editor calls it from onBootEnd.
	 * Log lines: "<tag> open tries=N", "<tag> giveup tries=N", "<tag> open no stage".
	 */
	public class OpenWaiter
	{
		private var m_tag:String;
		private var m_isReady:Function;
		private var m_enter:Function;
		private var m_log:Function;
		private var m_maxTries:int;
		private var m_tries:int;
		private var m_stage:Stage;

		public function OpenWaiter(tag:String, isReady:Function, enter:Function, log:Function, maxTries:int = 30)
		{
			m_tag = tag;
			m_isReady = isReady;
			m_enter = enter;
			m_log = log;
			m_maxTries = maxTries;
			m_tries = 0;
			m_stage = null;
		}

		public function get waiting():Boolean
		{
			return (m_stage != null);
		}

		public function start(st:Stage):void
		{
			stop();
			m_tries = 0;
			if (tryEnter())
			{
				return;
			};
			if (!st)
			{
				m_log(m_tag + " open no stage");
				return;
			};
			m_stage = st;
			st.addEventListener(Event.ENTER_FRAME, onFrame);
		}

		public function stop():void
		{
			if (!m_stage)
			{
				return;
			};
			try
			{
				m_stage.removeEventListener(Event.ENTER_FRAME, onFrame);
			}
			catch (err:*)
			{
			};
			m_stage = null;
		}

		private function onFrame(e:Event):void
		{
			m_tries++;
			if (tryEnter())
			{
				stop();
				return;
			};
			if (m_tries > m_maxTries)
			{
				stop();
				m_log(m_tag + " giveup tries=" + m_tries);
			};
		}

		private function tryEnter():Boolean
		{
			if (!m_isReady())
			{
				return (false);
			};
			m_log(m_tag + " open tries=" + m_tries);
			m_enter();
			return (true);
		}
	}
}
