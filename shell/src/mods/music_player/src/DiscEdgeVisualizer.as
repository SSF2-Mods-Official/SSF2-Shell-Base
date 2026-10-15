package
{
	import flash.filters.GlowFilter;

	/**
	 * Trap Nation–style rim: smooth filled wave fused to the disc, clearly reactive.
	 */
	public class DiscEdgeVisualizer extends MusicVisualizerBase
	{
		private var m_radius:Number;
		private var m_bars:int;
		private var m_smooth:Array;
		private var m_maxLen:Number;
		private var m_minPad:Number;

		public function DiscEdgeVisualizer(radius:Number)
		{
			var i:int;
			super();
			m_radius = radius;
			m_minPad = Math.max(4, radius * 0.028);
			m_maxLen = Math.max(14, radius * 0.2);
			m_bars = 64;
			m_smooth = [];
			i = 0;
			while (i < m_bars)
			{
				m_smooth.push(0.15);
				i++;
			};
			filters = [new GlowFilter(MusicTheme.ui(), 0.4, 7, 7, 1.2, 2)];
		}

		override protected function drawFrame():void
		{
			var i:int;
			var t:Number;
			var ang:Number;
			var level:Number;
			var target:Number;
			var band:int;
			var rOut:Number;
			var x:Number;
			var y:Number;
			var sum:Number;
			var k:int;
			var tmp:Array;
			var prv:Number;
			var nxt:Number;
			graphics.clear();
			if (m_radius < 8)
			{
				return;
			};
			i = 0;
			while (i < m_bars)
			{
				t = i / m_bars;
				band = int(3 + t * 220);
				sum = readLevel(band) * 1.2
					+ readLevel(band + 2) * 0.5
					+ readLevel(band - 2) * 0.4;
				target = sum / 2.1;
				// Punchy but capped — quiet stays low, hits rise clearly.
				target = Math.pow(Math.min(1, target * 1.35), 0.7);
				m_smooth[i] = Number(m_smooth[i]) * 0.62 + target * 0.38;
				i++;
			};
			// One light spatial pass — smooth lobes without killing motion.
			tmp = [];
			i = 0;
			while (i < m_bars)
			{
				prv = Number(m_smooth[(i - 1 + m_bars) % m_bars]);
				nxt = Number(m_smooth[(i + 1) % m_bars]);
				tmp[i] = prv * 0.18 + Number(m_smooth[i]) * 0.64 + nxt * 0.18;
				i++;
			};
			i = 0;
			while (i < m_bars)
			{
				m_smooth[i] = Number(tmp[i]);
				i++;
			};
			graphics.beginFill(MusicTheme.ui(), 0.9);
			i = 0;
			while (i <= m_bars)
			{
				t = (i % m_bars) / m_bars;
				ang = -Math.PI * 0.5 + Math.PI * 2 * t;
				level = Number(m_smooth[i % m_bars]);
				rOut = m_radius + m_minPad + m_maxLen * (0.12 + level * 0.88);
				x = Math.cos(ang) * rOut;
				y = Math.sin(ang) * rOut;
				if (i == 0)
				{
					graphics.moveTo(x, y);
				}
				else
				{
					graphics.lineTo(x, y);
				};
				i++;
			};
			i = m_bars;
			while (i >= 0)
			{
				t = (i % m_bars) / m_bars;
				ang = -Math.PI * 0.5 + Math.PI * 2 * t;
				x = Math.cos(ang) * m_radius;
				y = Math.sin(ang) * m_radius;
				graphics.lineTo(x, y);
				i--;
			};
			graphics.endFill();
			graphics.lineStyle(1.8, MusicTheme.ui(), 0.5, false, "normal", "round", "round");
			graphics.drawCircle(0, 0, m_radius + 0.5);
			drawRainbowFringe();
		}

		private function drawRainbowFringe():void
		{
			var i:int;
			var t:Number;
			var ang:Number;
			var cols:Array;
			var n:int;
			var a0:Number;
			var a1:Number;
			// Soft fringe derived from UI color + accents
			cols = [
				MusicTheme.ui(),
				MusicTheme.mix(MusicTheme.ui(), 0xFF8A3D, 0.35),
				MusicTheme.mix(MusicTheme.ui(), 0xF5D76E, 0.35),
				MusicTheme.mix(MusicTheme.ui(), 0x3DDC97, 0.35),
				MusicTheme.mix(MusicTheme.ui(), 0x4FC3F7, 0.35),
				MusicTheme.mix(MusicTheme.ui(), 0xB388FF, 0.35)
			];
			n = cols.length;
			i = 0;
			while (i < n)
			{
				a0 = -Math.PI * 0.5 + Math.PI * 2 * (i / n);
				a1 = -Math.PI * 0.5 + Math.PI * 2 * ((i + 1) / n);
				graphics.lineStyle(1.4, uint(cols[i]), 0.42, false, "normal", "round", "round");
				graphics.moveTo(Math.cos(a0) * (m_radius + 1.1), Math.sin(a0) * (m_radius + 1.1));
				t = 0.25;
				while (t <= 1.01)
				{
					ang = a0 + (a1 - a0) * Math.min(1, t);
					graphics.lineTo(Math.cos(ang) * (m_radius + 1.1), Math.sin(ang) * (m_radius + 1.1));
					t += 0.25;
				};
				i++;
			};
		}
	}
}
