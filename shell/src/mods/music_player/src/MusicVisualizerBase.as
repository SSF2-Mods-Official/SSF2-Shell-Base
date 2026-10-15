package
{
	import flash.display.Sprite;
	import flash.media.SoundMixer;
	import flash.utils.ByteArray;

	public class MusicVisualizerBase extends Sprite
	{
		protected var m_bytes:ByteArray;
		protected var m_active:Boolean;

		public function MusicVisualizerBase()
		{
			super();
			m_bytes = new ByteArray();
			m_active = false;
			mouseEnabled = false;
			mouseChildren = false;
		}

		public function start():void
		{
			m_active = true;
		}

		public function stop():void
		{
			m_active = false;
			graphics.clear();
		}

		public function tick():void
		{
			if (!m_active)
			{
				return;
			};
			sampleAudio();
			drawFrame();
		}

		protected function sampleAudio():void
		{
			try
			{
				m_bytes.length = 0;
				SoundMixer.computeSpectrum(m_bytes, false, 0);
			}
			catch (err:*)
			{
			};
		}

		protected function drawFrame():void
		{
		}

		/** Spectrum band 0–255 (left channel). Values are ~0–1. */
		protected function readLevel(index:int):Number
		{
			var v:Number;
			if (!m_bytes || m_bytes.length < 4)
			{
				return (0);
			};
			index = index < 0 ? 0 : (index > 255 ? 255 : index);
			try
			{
				m_bytes.position = index * 4;
				v = Math.abs(m_bytes.readFloat());
				if (v > 1)
				{
					v = 1;
				};
				return (v);
			}
			catch (err:*)
			{
			};
			return (0);
		}
	}
}
