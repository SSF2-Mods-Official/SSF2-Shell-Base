package com.sbxmod.paletteMaker
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;

	/**
	 * Full-screen keyboard shortcuts overlay (click backdrop to close).
	 */
	public class ShortcutsPopup extends PopupBase
	{
		public var onClose:Function = null;

		private static const STAGE_W:Number = 640;
		private static const STAGE_H:Number = 360;
		private static const PANEL_W:Number = 420;
		private static const PANEL_H:Number = 320;

		private var listHolder:Sprite;

		public function ShortcutsPopup()
		{
			buttonTextSize = 9;
			mouseEnabled = false;
			mouseChildren = false;
			buildPanel();
			visible = false;
		}

		private function buildPanel():void
		{
			var title:TextField;
			var note:TextField;
			var closeBtn:Sprite;
			var bindings:Array;
			var i:int;
			var row:Sprite;
			var keysTf:TextField;
			var labelTf:TextField;
			var entry:Object;
			var rowY:Number;

			makeBackdrop(0, 0, STAGE_W, STAGE_H, onBackdropClick);
			makePanel(PANEL_W, PANEL_H, 0.98, 0x555566, true);
			panel.x = (STAGE_W - PANEL_W) * 0.5;
			panel.y = (STAGE_H - PANEL_H) * 0.5;

			title = makeLabel("Keyboard Shortcuts", 13, true);
			title.x = 12;
			title.y = 6;
			panel.addChild(title);

			note = makeLabel("All shortcuts use Ctrl so playtest keys stay free. Click outside to close.", 8, false, 0xAAAAAA);
			note.x = 12;
			note.y = 26;
			panel.addChild(note);

			listHolder = new Sprite();
			listHolder.x = 12;
			listHolder.y = 48;
			panel.addChild(listHolder);

			bindings = PaletteMakerShortcuts.getBindings();
			rowY = 0;
			i = 0;
			while (i < bindings.length)
			{
				entry = bindings[i];
				row = new Sprite();
				row.graphics.beginFill((i % 2 == 0) ? 0x22222C : 0x1E1E28, 1);
				row.graphics.drawRoundRect(0, 0, PANEL_W - 24, 15, 2, 2);
				row.graphics.endFill();
				row.y = rowY;
				keysTf = makeLabel(String(entry.keys), 9, true, 0x88CCFF);
				keysTf.x = 6;
				keysTf.y = 0;
				row.addChild(keysTf);
				labelTf = makeLabel(String(entry.label), 9, false, 0xEEEEEE);
				labelTf.x = 140;
				labelTf.y = 0;
				row.addChild(labelTf);
				listHolder.addChild(row);
				rowY += 16;
				i++;
			};

			closeBtn = makeTextButton("Close", PANEL_W - 24, 24);
			closeBtn.x = 12;
			closeBtn.y = PANEL_H - 34;
			closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hide();
				if (onClose != null) onClose();
			});
			panel.addChild(closeBtn);
		}

		private function onBackdropClick(e:MouseEvent):void
		{
			hide();
			if (onClose != null) onClose();
		}

		public function showAt(px:Number = 0, py:Number = 0):void
		{
			x = 0;
			y = 0;
			setOpen(true);
		}

		public function hide():void
		{
			setOpen(false);
		}
	}
}
