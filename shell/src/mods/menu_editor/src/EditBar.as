package
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.Dictionary;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Edit-toolbar buttons for the select-screen editors: a rounded box with a centered
	 * "label" TextField that plays menu_hover on click. The editors own placement.
	 */
	public class EditBar
	{
		private static var s_width:Dictionary = new Dictionary(true);
		private static var s_labelY:Dictionary = new Dictionary(true);

		/**
		 * fill/line/lineW style the box. labelY < 0 centers the label vertically.
		 * click may be null when the caller adds its own listener.
		 */
		public static function button(label:String, click:Function, w:Number, h:Number, fill:uint, line:uint, lineAlpha:Number, lineW:Number, size:int, labelY:Number = -1):Sprite
		{
			var btn:Sprite;
			var tf:TextField;
			btn = new Sprite();
			btn.graphics.beginFill(fill, 1);
			btn.graphics.lineStyle(lineW, line, lineAlpha);
			btn.graphics.drawRoundRect(0, 0, w, h, 6, 6);
			btn.graphics.endFill();
			s_width[btn] = w;
			s_labelY[btn] = labelY;
			tf = new TextField();
			tf.name = "label";
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", size, 0xF2F2F2, true);
			tf.text = label;
			btn.addChild(tf);
			centerLabel(btn, h);
			btn.buttonMode = true;
			btn.useHandCursor = true;
			btn.addEventListener(MouseEvent.CLICK, onSfx);
			if (click != null)
			{
				btn.addEventListener(MouseEvent.CLICK, click);
			};
			return (btn);
		}

		/** Sets the label and re-centers it; no-op when the text already matches. */
		public static function setLabel(btn:Sprite, label:String):void
		{
			var tf:TextField;
			tf = btn ? (btn.getChildByName("label") as TextField) : null;
			if (!tf || tf.text == label)
			{
				return;
			};
			tf.text = label;
			centerLabel(btn, NaN);
		}

		public static function playSfx(id:String):void
		{
			var SQ:*;
			SQ = EngineRefs.SoundQueue;
			try
			{
				if (SQ && SQ.instance)
				{
					SQ.instance.playSoundEffect(id);
				};
			}
			catch (err:*)
			{
			};
		}

		private static function onSfx(e:MouseEvent):void
		{
			playSfx("menu_hover");
		}

		private static function centerLabel(btn:Sprite, h:Number):void
		{
			var tf:TextField;
			var labelY:Number;
			tf = btn.getChildByName("label") as TextField;
			if (!tf)
			{
				return;
			};
			tf.x = int((Number(s_width[btn]) - tf.width) * 0.5);
			labelY = s_labelY[btn] is Number ? Number(s_labelY[btn]) : -1;
			if (labelY >= 0)
			{
				tf.y = labelY;
			}
			else if (!isNaN(h))
			{
				tf.y = int((h - tf.height) * 0.5);
			};
		}
	}
}
