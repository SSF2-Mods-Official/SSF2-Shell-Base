package ssf2mm.shared
{
	import flash.display.Graphics;
	import flash.geom.Matrix;

	/**
	 * Traces an SVG path "d" string into Flash Graphics. Supports M L H V C S Q T A Z,
	 * absolute and relative. Every point goes through the matrix (null = identity).
	 * The caller sets lineStyle / beginFill first.
	 */
	public class SvgPath
	{
		public static function draw(g:Graphics, d:String, m:Matrix = null):void
		{
			var tokens:Array;
			var i:int;
			var cmd:String;
			var cx:Number = 0;
			var cy:Number = 0;
			var startX:Number = 0;
			var startY:Number = 0;
			var lastCX:Number = 0;
			var lastCY:Number = 0;
			var lastCmd:String = "";
			var nums:Array;
			var n:int;
			var x:Number;
			var y:Number;
			var x1:Number;
			var y1:Number;
			var x2:Number;
			var y2:Number;
			var rx:Number;
			var ry:Number;
			var rot:Number;
			var large:Number;
			var sweep:Number;
			var mFirst:Boolean;
			var mRel:Boolean;
			if (!g || !d)
			{
				return;
			};
			if (!m)
			{
				m = new Matrix();
			};
			tokens = tokenize(d);
			i = 0;
			while (i < tokens.length)
			{
				if (isCommand(tokens[i]))
				{
					cmd = String(tokens[i]);
					i++;
				}
				else if (lastCmd)
				{
					cmd = lastCmd;
					if (cmd == "M")
					{
						cmd = "L";
					}
					else if (cmd == "m")
					{
						cmd = "l";
					};
				}
				else
				{
					i++;
					continue;
				};
				lastCmd = cmd;
				nums = [];
				while (i < tokens.length && !isCommand(tokens[i]))
				{
					nums.push(Number(tokens[i]));
					i++;
				};
				n = 0;
				if (cmd == "M" || cmd == "m")
				{
					mFirst = true;
					mRel = (cmd == "m");
					while (n + 1 < nums.length)
					{
						x = nums[n++];
						y = nums[n++];
						if (mRel)
						{
							x += cx;
							y += cy;
						};
						cx = x;
						cy = y;
						if (mFirst)
						{
							startX = cx;
							startY = cy;
							g.moveTo(px(m, cx, cy), py(m, cx, cy));
							mFirst = false;
							// SVG: extra coordinate pairs after M/m are implicit LineTos.
							cmd = mRel ? "l" : "L";
							lastCmd = cmd;
						}
						else
						{
							g.lineTo(px(m, cx, cy), py(m, cx, cy));
						};
					};
				}
				else if (cmd == "L" || cmd == "l")
				{
					while (n + 1 < nums.length)
					{
						x = nums[n++];
						y = nums[n++];
						if (cmd == "l")
						{
							x += cx;
							y += cy;
						};
						cx = x;
						cy = y;
						g.lineTo(px(m, cx, cy), py(m, cx, cy));
					};
				}
				else if (cmd == "H" || cmd == "h")
				{
					while (n < nums.length)
					{
						x = nums[n++];
						if (cmd == "h")
						{
							x += cx;
						};
						cx = x;
						g.lineTo(px(m, cx, cy), py(m, cx, cy));
					};
				}
				else if (cmd == "V" || cmd == "v")
				{
					while (n < nums.length)
					{
						y = nums[n++];
						if (cmd == "v")
						{
							y += cy;
						};
						cy = y;
						g.lineTo(px(m, cx, cy), py(m, cx, cy));
					};
				}
				else if (cmd == "C" || cmd == "c")
				{
					while (n + 5 < nums.length)
					{
						x1 = nums[n++];
						y1 = nums[n++];
						x2 = nums[n++];
						y2 = nums[n++];
						x = nums[n++];
						y = nums[n++];
						if (cmd == "c")
						{
							x1 += cx;
							y1 += cy;
							x2 += cx;
							y2 += cy;
							x += cx;
							y += cy;
						};
						g.cubicCurveTo(px(m, x1, y1), py(m, x1, y1), px(m, x2, y2), py(m, x2, y2), px(m, x, y), py(m, x, y));
						lastCX = x2;
						lastCY = y2;
						cx = x;
						cy = y;
					};
				}
				else if (cmd == "S" || cmd == "s")
				{
					while (n + 3 < nums.length)
					{
						if (lastCmd == "C" || lastCmd == "c" || lastCmd == "S" || lastCmd == "s")
						{
							x1 = cx * 2 - lastCX;
							y1 = cy * 2 - lastCY;
						}
						else
						{
							x1 = cx;
							y1 = cy;
						};
						x2 = nums[n++];
						y2 = nums[n++];
						x = nums[n++];
						y = nums[n++];
						if (cmd == "s")
						{
							x2 += cx;
							y2 += cy;
							x += cx;
							y += cy;
						};
						g.cubicCurveTo(px(m, x1, y1), py(m, x1, y1), px(m, x2, y2), py(m, x2, y2), px(m, x, y), py(m, x, y));
						lastCX = x2;
						lastCY = y2;
						cx = x;
						cy = y;
					};
				}
				else if (cmd == "Q" || cmd == "q")
				{
					while (n + 3 < nums.length)
					{
						x1 = nums[n++];
						y1 = nums[n++];
						x = nums[n++];
						y = nums[n++];
						if (cmd == "q")
						{
							x1 += cx;
							y1 += cy;
							x += cx;
							y += cy;
						};
						g.curveTo(px(m, x1, y1), py(m, x1, y1), px(m, x, y), py(m, x, y));
						lastCX = x1;
						lastCY = y1;
						cx = x;
						cy = y;
					};
				}
				else if (cmd == "T" || cmd == "t")
				{
					while (n + 1 < nums.length)
					{
						if (lastCmd == "Q" || lastCmd == "q" || lastCmd == "T" || lastCmd == "t")
						{
							x1 = cx * 2 - lastCX;
							y1 = cy * 2 - lastCY;
						}
						else
						{
							x1 = cx;
							y1 = cy;
						};
						x = nums[n++];
						y = nums[n++];
						if (cmd == "t")
						{
							x += cx;
							y += cy;
						};
						g.curveTo(px(m, x1, y1), py(m, x1, y1), px(m, x, y), py(m, x, y));
						lastCX = x1;
						lastCY = y1;
						cx = x;
						cy = y;
					};
				}
				else if (cmd == "A" || cmd == "a")
				{
					while (n + 6 < nums.length)
					{
						rx = nums[n++];
						ry = nums[n++];
						rot = nums[n++];
						large = nums[n++];
						sweep = nums[n++];
						x = nums[n++];
						y = nums[n++];
						if (cmd == "a")
						{
							x += cx;
							y += cy;
						};
						drawArc(g, cx, cy, rx, ry, rot, large != 0, sweep != 0, x, y, m);
						cx = x;
						cy = y;
					};
				}
				else if (cmd == "Z" || cmd == "z")
				{
					cx = startX;
					cy = startY;
					g.lineTo(px(m, cx, cy), py(m, cx, cy));
				};
			};
		}

		private static function px(m:Matrix, x:Number, y:Number):Number
		{
			return m.a * x + m.c * y + m.tx;
		}

		private static function py(m:Matrix, x:Number, y:Number):Number
		{
			return m.b * x + m.d * y + m.ty;
		}

		/** Approximate SVG elliptical arc with cubic beziers (SVG impl notes). */
		private static function drawArc(g:Graphics, x1:Number, y1:Number, rx:Number, ry:Number, angleDeg:Number, large:Boolean, sweep:Boolean, x2:Number, y2:Number, m:Matrix):void
		{
			var phi:Number;
			var cosPhi:Number;
			var sinPhi:Number;
			var dx:Number;
			var dy:Number;
			var x1p:Number;
			var y1p:Number;
			var rxSq:Number;
			var rySq:Number;
			var x1pSq:Number;
			var y1pSq:Number;
			var radicand:Number;
			var cxp:Number;
			var cyp:Number;
			var cx:Number;
			var cy:Number;
			var startAngle:Number;
			var delta:Number;
			var segments:int;
			var i:int;
			var t1:Number;
			var t2:Number;
			var alpha:Number;
			var e1x:Number;
			var e1y:Number;
			var e2x:Number;
			var e2y:Number;
			var q1x:Number;
			var q1y:Number;
			var q2x:Number;
			var q2y:Number;
			var lam:Number;
			var lamRoot:Number;
			var sq:Number;
			var endX:Number;
			var endY:Number;
			if (rx == 0 || ry == 0)
			{
				g.lineTo(px(m, x2, y2), py(m, x2, y2));
				return;
			};
			rx = Math.abs(rx);
			ry = Math.abs(ry);
			phi = angleDeg * Math.PI / 180;
			cosPhi = Math.cos(phi);
			sinPhi = Math.sin(phi);
			dx = (x1 - x2) / 2;
			dy = (y1 - y2) / 2;
			x1p = cosPhi * dx + sinPhi * dy;
			y1p = -sinPhi * dx + cosPhi * dy;
			lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
			if (lam > 1)
			{
				lamRoot = Math.sqrt(lam);
				rx *= lamRoot;
				ry *= lamRoot;
			};
			rxSq = rx * rx;
			rySq = ry * ry;
			x1pSq = x1p * x1p;
			y1pSq = y1p * y1p;
			radicand = (rxSq * rySq - rxSq * y1pSq - rySq * x1pSq) / (rxSq * y1pSq + rySq * x1pSq);
			if (radicand < 0)
			{
				radicand = 0;
			};
			sq = Math.sqrt(radicand);
			if (large == sweep)
			{
				sq = -sq;
			};
			cxp = sq * (rx * y1p) / ry;
			cyp = sq * -(ry * x1p) / rx;
			cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
			cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;
			startAngle = vectorAngle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
			delta = vectorAngle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
			if (!sweep && delta > 0)
			{
				delta -= Math.PI * 2;
			};
			if (sweep && delta < 0)
			{
				delta += Math.PI * 2;
			};
			segments = Math.max(1, Math.ceil(Math.abs(delta) / (Math.PI / 2)));
			delta /= segments;
			alpha = (4 / 3) * Math.tan(delta / 4);
			i = 0;
			while (i < segments)
			{
				t1 = startAngle + i * delta;
				t2 = t1 + delta;
				e1x = Math.cos(t1);
				e1y = Math.sin(t1);
				e2x = Math.cos(t2);
				e2y = Math.sin(t2);
				q1x = cx + cosPhi * (rx * (e1x - alpha * e1y)) - sinPhi * (ry * (e1y + alpha * e1x));
				q1y = cy + sinPhi * (rx * (e1x - alpha * e1y)) + cosPhi * (ry * (e1y + alpha * e1x));
				q2x = cx + cosPhi * (rx * (e2x + alpha * e2y)) - sinPhi * (ry * (e2y - alpha * e2x));
				q2y = cy + sinPhi * (rx * (e2x + alpha * e2y)) + cosPhi * (ry * (e2y - alpha * e2x));
				endX = cx + cosPhi * rx * e2x - sinPhi * ry * e2y;
				endY = cy + sinPhi * rx * e2x + cosPhi * ry * e2y;
				g.cubicCurveTo(px(m, q1x, q1y), py(m, q1x, q1y), px(m, q2x, q2y), py(m, q2x, q2y), px(m, endX, endY), py(m, endX, endY));
				i++;
			};
		}

		private static function vectorAngle(ux:Number, uy:Number, vx:Number, vy:Number):Number
		{
			var sign:Number = (ux * vy - uy * vx < 0) ? -1 : 1;
			var dot:Number = ux * vx + uy * vy;
			var len:Number = Math.sqrt(ux * ux + uy * uy) * Math.sqrt(vx * vx + vy * vy);
			if (len == 0)
			{
				return 0;
			};
			dot = Math.max(-1, Math.min(1, dot / len));
			return sign * Math.acos(dot);
		}

		private static function tokenize(d:String):Array
		{
			var out:Array = [];
			var re:RegExp = /([MmLlHhVvCcSsQqTtAaZz])|([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/g;
			var match:Object;
			while ((match = re.exec(d)) != null)
			{
				if (match[1])
				{
					out.push(match[1]);
				}
				else if (match[2])
				{
					out.push(match[2]);
				};
			};
			return out;
		}

		private static function isCommand(tok:*):Boolean
		{
			var s:String = String(tok);
			return s.length == 1 && ("MmLlHhVvCcSsQqTtAaZz".indexOf(s) >= 0);
		}
	}
}
