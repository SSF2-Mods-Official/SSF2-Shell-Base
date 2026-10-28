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

		private static const LIST_Y:Number = 48;
		private static const LIST_VIEW_H:Number = 228;
		private static const ROW_H:Number = 16;

		private var listHolder:Sprite;
		private var scrollTrack:Sprite;
		private var scrollThumb:Sprite;
		private var listHeight:Number = 0;
		private var scrollY:Number = 0;
		private var thumbDrag:Boolean = false;
		private var thumbDragOffset:Number = 0;

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
			var listMask:Sprite;
			var maxScroll:Number;

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
			listHolder.y = LIST_Y;
			panel.addChild(listHolder);
			listMask = new Sprite();
			listMask.graphics.beginFill(0x000000, 1);
			listMask.graphics.drawRect(0, 0, PANEL_W - 36, LIST_VIEW_H);
			listMask.graphics.endFill();
			listMask.x = 12;
			listMask.y = LIST_Y;
			panel.addChild(listMask);
			listHolder.mask = listMask;

			bindings = PaletteMakerShortcuts.getBindings();
			rowY = 0;
			i = 0;
			while (i < bindings.length)
			{
				entry = bindings[i];
				row = new Sprite();
				row.graphics.beginFill((i % 2 == 0) ? 0x22222C : 0x1E1E28, 1);
				row.graphics.drawRoundRect(0, 0, PANEL_W - 40, 15, 2, 2);
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
				rowY += ROW_H;
				i++;
			};
			listHeight = rowY;
			maxScroll = listHeight - LIST_VIEW_H;
			if (maxScroll < 0)
			{
				maxScroll = 0;
			};
			scrollTrack = new Sprite();
			scrollTrack.x = PANEL_W - 18;
			scrollTrack.y = LIST_Y;
			scrollTrack.graphics.beginFill(0x22222C, 1);
			scrollTrack.graphics.drawRoundRect(0, 0, 8, LIST_VIEW_H, 3, 3);
			scrollTrack.graphics.endFill();
			scrollTrack.buttonMode = true;
			scrollTrack.visible = maxScroll > 0;
			scrollTrack.addEventListener(MouseEvent.MOUSE_DOWN, onTrackDown);
			panel.addChild(scrollTrack);
			scrollThumb = new Sprite();
			scrollThumb.x = 1;
			scrollThumb.buttonMode = true;
			scrollThumb.addEventListener(MouseEvent.MOUSE_DOWN, onThumbDown);
			scrollTrack.addChild(scrollThumb);
			layoutThumb();
			panel.addEventListener(MouseEvent.MOUSE_WHEEL, onListWheel);

			closeBtn = makeTextButton("Close", PANEL_W - 24, 24);
			closeBtn.x = 12;
			closeBtn.y = PANEL_H - 34;
			closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hide();
				if (onClose != null) onClose();
			});
			panel.addChild(closeBtn);
		}

		private function maxScroll():Number
		{
			var span:Number;
			span = listHeight - LIST_VIEW_H;
			return span > 0 ? span : 0;
		}

		private function layoutThumb():void
		{
			var span:Number;
			var thumbH:Number;
			var travel:Number;
			span = maxScroll();
			if (!scrollThumb)
			{
				return;
			};
			thumbH = LIST_VIEW_H;
			if (listHeight > LIST_VIEW_H)
			{
				thumbH = LIST_VIEW_H * LIST_VIEW_H / listHeight;
			};
			if (thumbH < 16)
			{
				thumbH = 16;
			};
			scrollThumb.graphics.clear();
			scrollThumb.graphics.beginFill(0x88AACC, 1);
			scrollThumb.graphics.drawRoundRect(0, 0, 6, thumbH, 2, 2);
			scrollThumb.graphics.endFill();
			travel = LIST_VIEW_H - thumbH;
			scrollThumb.y = span > 0 ? (scrollY / span) * travel : 0;
		}

		private function setScroll(next:Number):void
		{
			var span:Number;
			span = maxScroll();
			scrollY = next;
			if (scrollY < 0)
			{
				scrollY = 0;
			};
			if (scrollY > span)
			{
				scrollY = span;
			};
			listHolder.y = LIST_Y - scrollY;
			layoutThumb();
		}

		private function onListWheel(e:MouseEvent):void
		{
			if (maxScroll() <= 0)
			{
				return;
			};
			setScroll(scrollY - e.delta * ROW_H);
		}

		private function onThumbDown(e:MouseEvent):void
		{
			thumbDrag = true;
			thumbDragOffset = scrollThumb.mouseY;
			scrollThumb.stage.addEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
			scrollThumb.stage.addEventListener(MouseEvent.MOUSE_UP, onThumbUp);
			e.stopPropagation();
		}

		private function onThumbMove(e:MouseEvent):void
		{
			var thumbH:Number;
			var travel:Number;
			var localY:Number;
			if (!thumbDrag)
			{
				return;
			};
			thumbH = scrollThumb.height;
			travel = LIST_VIEW_H - thumbH;
			localY = scrollTrack.mouseY - thumbDragOffset;
			if (travel <= 0)
			{
				setScroll(0);
				return;
			};
			setScroll((localY / travel) * maxScroll());
		}

		private function onThumbUp(e:MouseEvent):void
		{
			thumbDrag = false;
			if (scrollThumb && scrollThumb.stage)
			{
				scrollThumb.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onThumbMove);
				scrollThumb.stage.removeEventListener(MouseEvent.MOUSE_UP, onThumbUp);
			};
		}

		private function onTrackDown(e:MouseEvent):void
		{
			var thumbH:Number;
			var travel:Number;
			if (e.target == scrollThumb)
			{
				return;
			};
			thumbH = scrollThumb.height;
			travel = LIST_VIEW_H - thumbH;
			if (travel <= 0)
			{
				return;
			};
			setScroll(((scrollTrack.mouseY - thumbH * 0.5) / travel) * maxScroll());
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
