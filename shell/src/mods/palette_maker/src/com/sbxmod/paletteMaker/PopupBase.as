package com.sbxmod.paletteMaker
{
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	/**
	 * Shared overlay plumbing for the palette maker popups: backdrop, panel that
	 * swallows mouse presses, open/closed input state, stage key listener, and the
	 * label / text button look.
	 */
	public class PopupBase extends Sprite
	{
		protected var backdrop:Sprite;
		protected var panel:Sprite;

		/** makeLabel color when the caller passes none. */
		protected var labelColor:uint = 0xFFFFFF;
		protected var buttonFill:uint = 0x2A2A35;
		protected var buttonTextSize:Number = 8;
		protected var buttonPadX:Number = 4;

		private var m_keyStage:Stage;

		/** Visible and takes mouse input when open; hidden and inert when closed. */
		protected function setOpen(open:Boolean):void
		{
			visible = open;
			mouseEnabled = open;
			mouseChildren = open;
		}

		/** Dimmed rect behind the panel; onHit(e) runs on eventType. Added as a child. */
		protected function makeBackdrop(bx:Number, by:Number, bw:Number, bh:Number, onHit:Function,
			eventType:String = "click", handCursor:Boolean = true):Sprite
		{
			backdrop = new Sprite();
			backdrop.graphics.beginFill(0x000000, 0.55);
			backdrop.graphics.drawRect(bx, by, bw, bh);
			backdrop.graphics.endFill();
			if (handCursor)
			{
				backdrop.buttonMode = true;
				backdrop.useHandCursor = true;
			};
			backdrop.addEventListener(eventType, onHit);
			addChild(backdrop);
			return backdrop;
		}

		/** Rounded panel that stops MOUSE_DOWN (and CLICK when swallowClick) from reaching what is under it. */
		protected function makePanel(pw:Number, ph:Number, fillAlpha:Number, lineColor:uint, swallowClick:Boolean = false):Sprite
		{
			panel = new Sprite();
			panel.graphics.beginFill(0x1A1A22, fillAlpha);
			panel.graphics.lineStyle(1, lineColor, 1);
			panel.graphics.drawRoundRect(0, 0, pw, ph, 8, 8);
			panel.graphics.endFill();
			panel.mouseEnabled = true;
			panel.addEventListener(MouseEvent.MOUSE_DOWN, stopEvent);
			if (swallowClick)
			{
				panel.addEventListener(MouseEvent.CLICK, stopEvent);
			};
			addChild(panel);
			return panel;
		}

		/** Routes stage KEY_DOWN to onPopupKey while on. The stage is remembered so off still detaches after removal. */
		protected function listenKeys(on:Boolean):void
		{
			if (m_keyStage)
			{
				m_keyStage.removeEventListener(KeyboardEvent.KEY_DOWN, onStageKey);
				m_keyStage = null;
			};
			if (on && stage)
			{
				m_keyStage = stage;
				m_keyStage.addEventListener(KeyboardEvent.KEY_DOWN, onStageKey);
			};
		}

		protected function onPopupKey(e:KeyboardEvent):void
		{
		}

		protected function makeLabel(text:String, size:Number, bold:Boolean, color:int = -1):TextField
		{
			var tf:TextField = new TextField();
			tf.defaultTextFormat = new TextFormat("_sans", size, color < 0 ? labelColor : uint(color), bold);
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.text = text;
			return tf;
		}

		protected function makeTextButton(label:String, w:Number, h:Number):Sprite
		{
			var btn:Sprite = new Sprite();
			var tf:TextField;
			btn.graphics.beginFill(buttonFill, 1);
			btn.graphics.lineStyle(1, 0x666677, 1);
			btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
			btn.graphics.endFill();
			tf = makeLabel(label, buttonTextSize, false);
			tf.x = buttonPadX;
			tf.y = (h - tf.height) * 0.5;
			btn.addChild(tf);
			btn.buttonMode = true;
			btn.useHandCursor = true;
			return btn;
		}

		private function onStageKey(e:KeyboardEvent):void
		{
			onPopupKey(e);
		}

		private static function stopEvent(e:MouseEvent):void
		{
			e.stopPropagation();
		}
	}
}
