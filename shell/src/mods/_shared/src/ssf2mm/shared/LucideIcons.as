package ssf2mm.shared
{
	import flash.display.Graphics;
	import flash.geom.Matrix;
	import flash.utils.ByteArray;

	/**
	 * Lucide SVG icons (ISC License — see icons/LICENSE-lucide.txt) drawn with Flash Graphics.
	 * The SVGs under icons/ are the source; each constant is one embedded file.
	 */
	public class LucideIcons
	{
		[Embed(source="icons/arrow-left.svg", mimeType="application/octet-stream")]
		public static const ARROW_LEFT:Class;
		[Embed(source="icons/chevron-down.svg", mimeType="application/octet-stream")]
		public static const CHEVRON_DOWN:Class;
		[Embed(source="icons/chevron-up.svg", mimeType="application/octet-stream")]
		public static const CHEVRON_UP:Class;
		[Embed(source="icons/contrast.svg", mimeType="application/octet-stream")]
		public static const CONTRAST:Class;
		[Embed(source="icons/eraser.svg", mimeType="application/octet-stream")]
		public static const ERASER:Class;
		[Embed(source="icons/eye-off.svg", mimeType="application/octet-stream")]
		public static const EYE_OFF:Class;
		[Embed(source="icons/file-down.svg", mimeType="application/octet-stream")]
		public static const FILE_DOWN:Class;
		[Embed(source="icons/file-up.svg", mimeType="application/octet-stream")]
		public static const FILE_UP:Class;
		[Embed(source="icons/flip-horizontal-2.svg", mimeType="application/octet-stream")]
		public static const FLIP_H2:Class;
		[Embed(source="icons/folder-plus.svg", mimeType="application/octet-stream")]
		public static const FOLDER_PLUS:Class;
		[Embed(source="icons/palette.svg", mimeType="application/octet-stream")]
		public static const PALETTE:Class;
		[Embed(source="icons/pencil.svg", mimeType="application/octet-stream")]
		public static const PENCIL:Class;
		[Embed(source="icons/pipette.svg", mimeType="application/octet-stream")]
		public static const PIPETTE:Class;
		[Embed(source="icons/redo-2.svg", mimeType="application/octet-stream")]
		public static const REDO_2:Class;
		[Embed(source="icons/repeat.svg", mimeType="application/octet-stream")]
		public static const REPEAT:Class;
		[Embed(source="icons/repeat-1.svg", mimeType="application/octet-stream")]
		public static const REPEAT_1:Class;
		[Embed(source="icons/rotate-ccw.svg", mimeType="application/octet-stream")]
		public static const ROTATE_CCW:Class;
		[Embed(source="icons/settings.svg", mimeType="application/octet-stream")]
		public static const SETTINGS:Class;
		[Embed(source="icons/shapes.svg", mimeType="application/octet-stream")]
		public static const SHAPES:Class;
		[Embed(source="icons/shuffle.svg", mimeType="application/octet-stream")]
		public static const SHUFFLE:Class;
		[Embed(source="icons/sliders-horizontal.svg", mimeType="application/octet-stream")]
		public static const SLIDERS:Class;
		[Embed(source="icons/square.svg", mimeType="application/octet-stream")]
		public static const SQUARE:Class;
		[Embed(source="icons/square-check.svg", mimeType="application/octet-stream")]
		public static const SQUARE_CHECK:Class;
		[Embed(source="icons/square-x.svg", mimeType="application/octet-stream")]
		public static const SQUARE_X:Class;
		[Embed(source="icons/type.svg", mimeType="application/octet-stream")]
		public static const TYPE:Class;
		[Embed(source="icons/undo-2.svg", mimeType="application/octet-stream")]
		public static const UNDO_2:Class;

		/** Lucide icons use a 24x24 viewBox. */
		private static const VIEW:Number = 24;

		public static function draw(g:Graphics, svgClass:Class, boxSize:Number, color:uint = 0xFFFFFF, pad:Number = 4):void
		{
			drawEmbeddedSvg(g, svgClass, boxSize, color, pad);
		}

		/** Clears g and strokes the icon into a boxSize square, pad pixels in from each edge. */
		public static function drawEmbeddedSvg(g:Graphics, svgClass:Class, boxSize:Number, color:uint = 0xFFFFFF, pad:Number = 2):void
		{
			var xml:XML;
			var bytes:ByteArray;
			var scale:Number;
			var m:Matrix;
			var node:XML;
			if (!g || !svgClass)
			{
				return;
			};
			bytes = new svgClass() as ByteArray;
			if (!bytes || bytes.length == 0)
			{
				return;
			};
			bytes.position = 0;
			try
			{
				xml = new XML(bytes.readUTFBytes(bytes.length));
			}
			catch (err:Error)
			{
				return;
			};
			scale = (boxSize - pad * 2) / VIEW;
			m = new Matrix(scale, 0, 0, scale, pad, pad);
			g.clear();
			g.lineStyle(Math.max(1, 2 * scale), color, 1, false, "normal", "round", "round");
			for each (node in xml..*::path)
			{
				SvgPath.draw(g, String(node.@d), m);
			};
			for each (node in xml..*::circle)
			{
				drawCircleEl(g, node, scale, pad, pad, color);
			};
			for each (node in xml..*::rect)
			{
				drawRectEl(g, node, scale, pad, pad);
			};
		}

		private static function drawCircleEl(g:Graphics, node:XML, scale:Number, ox:Number, oy:Number, color:uint):void
		{
			var cx:Number = Number(node.@cx) * scale + ox;
			var cy:Number = Number(node.@cy) * scale + oy;
			var r:Number = Number(node.@r) * scale;
			var fillAttr:String = String(node.@fill);
			if (fillAttr && fillAttr != "none" && fillAttr != "")
			{
				g.beginFill(color, 1);
				g.drawCircle(cx, cy, Math.max(0.5, r));
				g.endFill();
			}
			else
			{
				g.drawCircle(cx, cy, Math.max(0.5, r));
			};
		}

		private static function drawRectEl(g:Graphics, node:XML, scale:Number, ox:Number, oy:Number):void
		{
			var x:Number = Number(node.@x) * scale + ox;
			var y:Number = Number(node.@y) * scale + oy;
			var w:Number = Number(node.@width) * scale;
			var h:Number = Number(node.@height) * scale;
			var rx:Number = node.hasOwnProperty("@rx") ? Number(node.@rx) * scale : 0;
			if (rx > 0)
			{
				g.drawRoundRect(x, y, w, h, rx * 2, rx * 2);
			}
			else
			{
				g.drawRect(x, y, w, h);
			};
		}
	}
}
