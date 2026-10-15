package com.sbxmod.paletteMaker
{
	import flash.display.Sprite;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;

	/** Multiline paste fallback when clipboard is empty for Import Code. */
	public class ImportCodePastePopup extends PopupBase
	{
		public var onSubmit:Function = null;
		public var onCancel:Function = null;

		private var input:TextField;

		public function ImportCodePastePopup()
		{
			mouseEnabled = true;
			mouseChildren = true;
			build();
			visible = false;
		}

		private function build():void
		{
			var title:TextField;
			var okBtn:Sprite;
			var cancelBtn:Sprite;
			makeBackdrop(-400, -300, 1600, 1200, function(e:MouseEvent):void {
				hide();
				if (onCancel != null) onCancel();
			}, MouseEvent.MOUSE_DOWN, false);

			makePanel(420, 280, 0.98, 0x666677);
			panel.x = 40;
			panel.y = 40;

			title = new TextField();
			title.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true);
			title.text = "Paste costume JSON";
			title.width = 400;
			title.height = 22;
			title.x = 10;
			title.y = 8;
			title.selectable = false;
			panel.addChild(title);

			input = new TextField();
			input.defaultTextFormat = new TextFormat("_sans", 10, 0xEEEEEE);
			input.border = true;
			input.borderColor = 0x555566;
			input.background = true;
			input.backgroundColor = 0x101018;
			input.type = TextFieldType.INPUT;
			input.multiline = true;
			input.wordWrap = true;
			input.width = 400;
			input.height = 190;
			input.x = 10;
			input.y = 32;
			panel.addChild(input);

			okBtn = makeBtn("Import", 120);
			okBtn.x = 170;
			okBtn.y = 236;
			okBtn.addEventListener(MouseEvent.CLICK, onOk_CLICK);
			panel.addChild(okBtn);

			cancelBtn = makeBtn("Cancel", 120);
			cancelBtn.x = 300;
			cancelBtn.y = 236;
			cancelBtn.addEventListener(MouseEvent.CLICK, onCancel_CLICK);
			panel.addChild(cancelBtn);
		}

		private function makeBtn(label:String, w:Number):Sprite
		{
			var btn:Sprite = new Sprite();
			var tf:TextField = new TextField();
			btn.graphics.beginFill(0x333344, 1);
			btn.graphics.lineStyle(1, 0x888899, 1);
			btn.graphics.drawRoundRect(0, 0, w, 22, 4, 4);
			btn.graphics.endFill();
			tf.defaultTextFormat = new TextFormat("_sans", 10, 0xFFFFFF);
			tf.text = label;
			tf.width = w;
			tf.height = 22;
			tf.y = 3;
			tf.selectable = false;
			btn.addChild(tf);
			btn.buttonMode = true;
			btn.useHandCursor = true;
			return btn;
		}

		public function show(initialText:String=""):void
		{
			input.text = initialText ? initialText : "";
			visible = true;
			if (stage)
			{
				stage.focus = input;
			};
			listenKeys(true);
		}

		public function hide():void
		{
			visible = false;
			listenKeys(false);
		}

		override protected function onPopupKey(e:KeyboardEvent):void
		{
			if (e.keyCode == Keyboard.ESCAPE)
			{
				hide();
				if (onCancel != null) onCancel();
			};
		}

		private function onOk_CLICK(e:MouseEvent):void
		{
			var text:String = input.text;
			hide();
			if (onSubmit != null)
			{
				onSubmit(text);
			};
		}

		private function onCancel_CLICK(e:MouseEvent):void
		{
			hide();
			if (onCancel != null) onCancel();
		}
	}
}
