package
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;

	/**
	 * Shared modal overlays: list/tile pickers, text prompt, modal row highlight and dismissal.
	 */
	public class MusicUiDialogs
	{
		private var ui:MusicPlayerUi;

		public function MusicUiDialogs(owner:MusicPlayerUi)
		{
			ui = owner;
		}

		internal function closeSettingsOverlay():void
		{
			if (ui.m_settingsOverlay && ui.m_settingsOverlay.parent)
			{
				ui.m_settingsOverlay.parent.removeChild(ui.m_settingsOverlay);
			};
			if (ui.m_blockingOverlay == ui.m_settingsOverlay)
			{
				ui.m_blockingOverlay = null;
			};
			ui.m_settingsOverlay = null;
			clearModalNav();
		}

		internal function clearModalNav():void
		{
			ui.m_modalKind = null;
			ui.m_modalItems = null;
			ui.m_modalIndex = 0;
			ui.m_modalOnConfirm = null;
			ui.m_modalOnBack = null;
			ui.m_modalRefresh = null;
		}

		internal function dismissBlockingOverlay():void
		{
			if (ui.m_blockingOverlay && ui.m_blockingOverlay.parent)
			{
				ui.m_blockingOverlay.parent.removeChild(ui.m_blockingOverlay);
			};
			ui.m_blockingOverlay = null;
			ui.m_settingsOverlay = null;
			clearModalNav();
		}

		internal function highlightModalRows(card:Sprite, y0:Number, pitch:Number,
			w:Number, h:Number):void
		{
			var i:int;
			var row:Sprite;
			var fill:uint;
			if (!card || !ui.m_modalItems)
			{
				return;
			};
			i = 0;
			while (i < card.numChildren)
			{
				row = card.getChildAt(i) as Sprite;
				if (row && row.buttonMode)
				{
					fill = (ui.m_modalIndex >= 0 && Math.abs(row.y - (y0 + ui.m_modalIndex * pitch)) < 2)
						? MusicTheme.select() : ((i == card.numChildren - 1) ? 0x2A2A34 : 0x1A1A22);
					row.graphics.clear();
					row.graphics.beginFill(fill == MusicTheme.select() ? 0x2A2418 : fill, 1);
					row.graphics.lineStyle(fill == MusicTheme.select() ? 1 : 0,
						MusicTheme.select(), fill == MusicTheme.select() ? 0.9 : 0);
					row.graphics.drawRoundRect(0, 0, w, h, 8, 8);
					row.graphics.endFill();
				};
				i++;
			};
		}

		internal function openFilterListPicker(title:String, keys:Array, labelFn:Function,
			decorateFn:Function, onPick:Function, onCancel:Function,
			onDefault:Function = null, onUpload:Function = null):void
		{
			new MusicFilterListPicker(ui, this, title, keys, labelFn, decorateFn, onPick, onCancel,
				onDefault, onUpload).open();
		}

		internal function openTilePicker(title:String, ids:Array, stageMode:Boolean,
			onPick:Function, onUpload:Function, onCancel:Function, onDefault:Function = null):void
		{
			new MusicTilePicker(ui, this, title, ids, stageMode, onPick, onUpload, onCancel, onDefault).open();
		}

		internal function openTextPrompt(title:String, value:String, onOk:Function, onCancel:Function = null):void
		{
			var box:Sprite;
			var input:TextField;
			var ok:Sprite;
			var cancel:Sprite;
			box = new Sprite();
			box.graphics.beginFill(0x000000, 0.55);
			box.graphics.drawRect(0, 0, ui.m_gw, ui.m_gh);
			box.graphics.endFill();
			box.graphics.beginFill(0x16161E, 1);
			box.graphics.lineStyle(2, MusicTheme.select(), 1);
			box.graphics.drawRoundRect(ui.m_gw * 0.5 - 200, ui.m_gh * 0.5 - 70, 400, 140, 10, 10);
			box.graphics.endFill();
			box.addChild(ui.makeText(title, ui.m_gw * 0.5 - 180, ui.m_gh * 0.5 - 58, 14, 0xFFFFFF, true));
			input = new TextField();
			input.type = TextFieldType.INPUT;
			input.border = true;
			input.borderColor = MusicTheme.select();
			input.background = true;
			input.backgroundColor = 0x111118;
			input.textColor = 0xFFFFFF;
			input.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF);
			input.text = value || "";
			input.x = ui.m_gw * 0.5 - 180;
			input.y = ui.m_gh * 0.5 - 28;
			input.width = 360;
			input.height = 24;
			box.addChild(input);
			ok = promptButton("Save · Attack", ui.m_gw * 0.5 - 180, ui.m_gh * 0.5 + 16, function ():void
			{
				if (box.parent)
				{
					box.parent.removeChild(box);
				};
				if (ui.m_blockingOverlay == box)
				{
					ui.m_blockingOverlay = null;
					clearModalNav();
				};
				if (onOk != null)
				{
					onOk(input.text);
				};
			});
			cancel = promptButton("Cancel · Special", ui.m_gw * 0.5 - 40, ui.m_gh * 0.5 + 16, function ():void
			{
				if (box.parent)
				{
					box.parent.removeChild(box);
				};
				if (ui.m_blockingOverlay == box)
				{
					ui.m_blockingOverlay = null;
					clearModalNav();
				};
				if (onCancel != null)
				{
					onCancel();
				};
			});
			box.addChild(ok);
			box.addChild(cancel);
			ui.m_blockingOverlay = box;
			ui.m_modalKind = "prompt";
			ui.m_modalItems = null;
			ui.m_modalOnConfirm = function ():void
			{
				if (box.parent)
				{
					box.parent.removeChild(box);
				};
				if (ui.m_blockingOverlay == box)
				{
					ui.m_blockingOverlay = null;
					clearModalNav();
				};
				if (onOk != null)
				{
					onOk(input.text);
				};
			};
			ui.m_modalOnBack = function ():void
			{
				if (box.parent)
				{
					box.parent.removeChild(box);
				};
				if (ui.m_blockingOverlay == box)
				{
					ui.m_blockingOverlay = null;
					clearModalNav();
				};
				if (onCancel != null)
				{
					onCancel();
				};
			};
			ui.addChild(box);
			ui.safeBringToFront(box);
			if (ui.stage)
			{
				ui.stage.focus = input;
			};
		}

		internal function promptButton(label:String, x:Number, y:Number, onClick:Function):Sprite
		{
			var btn:Sprite;
			var tf:TextField;
			btn = new Sprite();
			btn.x = x;
			btn.y = y;
			tf = ui.makeText(label, 8, 2, 12, 0x111118, true);
			btn.graphics.beginFill(MusicTheme.select(), 1);
			btn.graphics.drawRoundRect(0, 0, Math.max(72, tf.textWidth + 20), 22, 6, 6);
			btn.graphics.endFill();
			btn.addChild(tf);
			btn.buttonMode = true;
			btn.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				e.stopPropagation();
				if (onClick != null)
				{
					onClick();
				};
			});
			return (btn);
		}
	}
}
