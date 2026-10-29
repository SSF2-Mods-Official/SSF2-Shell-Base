package com.sbxmod.paletteMaker
{
	import ssf2mm.shared.HsvWheel;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;

	/**
	 * Overlay panel for tool Settings (ST).
	 */
	public class ToolSettingsPopup extends PopupBase
	{
		public var onClose:Function = null;
		public var onToggleAlwaysIsolate:Function = null;
		public var onHideUi:Function = null;
		public var onToggleHighlightUnchanged:Function = null;
		public var onToggleSortByOriginal:Function = null;
		public var onToggleDiscordCostumePreview:Function = null;
		public var onToggleSelectHighlight:Function = null;
		public var onSelectHighlightPrimaryChanged:Function = null;
		public var onSelectHighlightAltChanged:Function = null;
		public var onExportColorGroups:Function = null;
		public var onImportColorGroups:Function = null;
		public var onOpenShortcuts:Function = null;
		public var onOpenAchievements:Function = null;

		private var alwaysIsolateBtn:Sprite;
		private var alwaysIsolateLabel:TextField;
		private var highlightBtn:Sprite;
		private var highlightLabel:TextField;
		private var sortByOriginalBtn:Sprite;
		private var sortByOriginalLabel:TextField;
		private var discordPreviewBtn:Sprite;
		private var discordPreviewLabel:TextField;
		private var selectHighlightBtn:Sprite;
		private var selectHighlightLabel:TextField;
		private var primarySwatchBtn:Sprite;
		private var primarySwatchFill:Sprite;
		private var altSwatchBtn:Sprite;
		private var altSwatchFill:Sprite;
		private var achievementsBtn:Sprite;
		private var achievementsLabel:TextField;

		private var primaryColor:uint = 0xFFFF0000;
		private var altColor:uint = 0xFFFFFFFF;
		private var wheelTarget:String = "";
		private var wheelOverlay:Sprite;
		private var hueStrip:Bitmap;
		private var svSquare:Bitmap;
		private var hueHit:Sprite;
		private var svHit:Sprite;
		private var previewBox:Sprite;
		private var hexInput:TextField;
		private var hexEditing:Boolean = false;
		private var wheelHue:Number = 0;
		private var wheelSat:Number = 1;
		private var wheelVal:Number = 1;
		private var draggingHue:Boolean = false;
		private var draggingSV:Boolean = false;

		public function ToolSettingsPopup()
		{
			buttonTextSize = 10;
			buttonPadX = 6;
			mouseEnabled = false;
			mouseChildren = false;
			buildPanel();
			visible = false;
		}

		private function buildPanel():void
		{
			var title:TextField;
			var btn:Sprite;
			var rowY:Number;
			var wide:Number = 208;
			var half:Number = 100;
			makePanel(232, 248, 0.98, 0xC6A15A);

			title = makeLabel("Settings", 12, true, 0xF4E4B0);
			title.x = 12;
			title.y = 4;
			panel.addChild(title);

			rowY = 24;
			alwaysIsolateBtn = makeRow("Always isolate", 12, rowY, wide);
			alwaysIsolateLabel = alwaysIsolateBtn.getChildAt(0) as TextField;
			alwaysIsolateBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onToggleAlwaysIsolate != null) onToggleAlwaysIsolate();
			});
			panel.addChild(alwaysIsolateBtn);

			rowY = 44;
			highlightBtn = makeRow("Highlight unchanged", 12, rowY, wide);
			highlightLabel = highlightBtn.getChildAt(0) as TextField;
			highlightBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onToggleHighlightUnchanged != null) onToggleHighlightUnchanged();
			});
			panel.addChild(highlightBtn);

			rowY = 64;
			sortByOriginalBtn = makeRow("Sort by original", 12, rowY, wide);
			sortByOriginalLabel = sortByOriginalBtn.getChildAt(0) as TextField;
			sortByOriginalBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onToggleSortByOriginal != null) onToggleSortByOriginal();
			});
			panel.addChild(sortByOriginalBtn);

			rowY = 84;
			discordPreviewBtn = makeRow("Discord preview", 12, rowY, wide);
			discordPreviewLabel = discordPreviewBtn.getChildAt(0) as TextField;
			discordPreviewBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onToggleDiscordCostumePreview != null) onToggleDiscordCostumePreview();
			});
			panel.addChild(discordPreviewBtn);

			rowY = 104;
			selectHighlightBtn = makeRow("Select highlight", 12, rowY, 148);
			selectHighlightLabel = selectHighlightBtn.getChildAt(0) as TextField;
			selectHighlightBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onToggleSelectHighlight != null) onToggleSelectHighlight();
			});
			panel.addChild(selectHighlightBtn);

			primarySwatchBtn = makeSwatchButton();
			primarySwatchBtn.x = 168;
			primarySwatchBtn.y = rowY;
			primarySwatchFill = primarySwatchBtn.getChildAt(0) as Sprite;
			primarySwatchBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				openWheel("primary", primaryColor);
			});
			panel.addChild(primarySwatchBtn);

			altSwatchBtn = makeSwatchButton();
			altSwatchBtn.x = 194;
			altSwatchBtn.y = rowY;
			altSwatchFill = altSwatchBtn.getChildAt(0) as Sprite;
			altSwatchBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				openWheel("alt", altColor);
			});
			panel.addChild(altSwatchBtn);

			rowY = 124;
			btn = makeRow("Hide palette maker UI", 12, rowY, wide);
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onHideUi != null) onHideUi();
			});
			panel.addChild(btn);

			rowY = 144;
			btn = makeRow("Export color groups", 12, rowY, half);
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onExportColorGroups != null) onExportColorGroups();
			});
			panel.addChild(btn);

			btn = makeRow("Import color groups", 120, rowY, half);
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onImportColorGroups != null) onImportColorGroups();
			});
			panel.addChild(btn);

			rowY = 164;
			btn = makeRow("Keyboard Shortcuts", 12, rowY, wide);
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onOpenShortcuts != null) onOpenShortcuts();
			});
			panel.addChild(btn);

			rowY = 184;
			achievementsBtn = makeRow("Achievements (0 cookies)", 12, rowY, wide);
			achievementsLabel = achievementsBtn.getChildAt(0) as TextField;
			achievementsBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onOpenAchievements != null) onOpenAchievements();
			});
			panel.addChild(achievementsBtn);

			rowY = 204;
			btn = makeRow("Close", 12, rowY, wide);
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hide();
				if (onClose != null) onClose();
			});
			panel.addChild(btn);

			redrawSwatches();
		}

		private function makeSwatchButton():Sprite
		{
			var btn:Sprite = new Sprite();
			var fill:Sprite = new Sprite();
			btn.graphics.lineStyle(1, 0xFFFFFF, 0.85);
			btn.graphics.beginFill(0x333333, 1);
			btn.graphics.drawRoundRect(0, 0, 18, 16, 3, 3);
			btn.graphics.endFill();
			fill.graphics.beginFill(0xFF0000, 1);
			fill.graphics.drawRoundRect(2, 2, 14, 12, 2, 2);
			fill.graphics.endFill();
			btn.addChild(fill);
			btn.buttonMode = true;
			btn.useHandCursor = true;
			return btn;
		}

		private function makeRow(label:String, xPos:Number, yPos:Number, w:Number):Sprite
		{
			var row:Sprite = makeTextButton(label, w, 18);
			row.x = xPos;
			row.y = yPos;
			return row;
		}

		public function showAt(px:Number, py:Number, alwaysIsolate:Boolean, highlightUnchanged:Boolean,
			sortByOriginal:Boolean=false, unchangedVsOriginal:Boolean=false,
			discordCostumePreview:Boolean=true, cookieBalance:int=0,
			selectHighlight:Boolean=false, selectPrimary:uint=0xFFFF0000, selectAlt:uint=0xFFFFFFFF):void
		{
			x = px;
			y = py;
			setOpen(true);
			clampPanelToStage();
			primaryColor = selectPrimary | 0xFF000000;
			altColor = selectAlt | 0xFF000000;
			refreshToggles(alwaysIsolate, highlightUnchanged, sortByOriginal,
				unchangedVsOriginal, discordCostumePreview, cookieBalance, selectHighlight);
			redrawSwatches();
		}

		public function refreshToggles(alwaysIsolate:Boolean, highlightUnchanged:Boolean,
			sortByOriginal:Boolean=false, unchangedVsOriginal:Boolean=false,
			discordCostumePreview:Boolean=true, cookieBalance:int=0,
			selectHighlight:Boolean=false):void
		{
			var highlightLabelText:String;
			setToggleLabel(alwaysIsolateLabel, "Always isolate", alwaysIsolate);
			if (!highlightUnchanged)
			{
				highlightLabelText = "[OFF] Highlight";
			}
			else if (unchangedVsOriginal)
			{
				highlightLabelText = "[ON] Vs original";
			}
			else
			{
				highlightLabelText = "[ON] Vs loaded";
			};
			if (highlightLabel)
			{
				highlightLabel.text = highlightLabelText;
			};
			setToggleLabel(sortByOriginalLabel, "Sort by original", sortByOriginal);
			setToggleLabel(discordPreviewLabel, "Discord preview", discordCostumePreview);
			setToggleLabel(selectHighlightLabel, "Select highlight", selectHighlight);
			if (achievementsLabel)
			{
				achievementsLabel.text = "Achievements (" + cookieBalance + " cookies)";
			};
		}

		public function setSelectHighlightColors(primary:uint, alt:uint):void
		{
			primaryColor = primary | 0xFF000000;
			altColor = alt | 0xFF000000;
			redrawSwatches();
		}

		private function redrawSwatches():void
		{
			drawSwatchFill(primarySwatchFill, primaryColor);
			drawSwatchFill(altSwatchFill, altColor);
		}

		private function drawSwatchFill(fill:Sprite, color:uint):void
		{
			if (!fill)
			{
				return;
			};
			fill.graphics.clear();
			fill.graphics.beginFill(color & 0xFFFFFF, 1);
			fill.graphics.drawRoundRect(2, 2, 18, 14, 2, 2);
			fill.graphics.endFill();
		}

		private function setToggleLabel(tf:TextField, base:String, on:Boolean):void
		{
			if (!tf)
			{
				return;
			};
			tf.text = (on ? "[ON]  " : "[OFF] ") + base;
		}

		public function hide():void
		{
			hideWheel();
			setOpen(false);
		}

		private function openWheel(target:String, startColor:uint):void
		{
			var hsv:Object = HsvWheel.rgbToHsv(startColor);
			wheelTarget = target;
			wheelHue = hsv.h;
			wheelSat = hsv.s;
			wheelVal = hsv.v;
			if (!wheelOverlay)
			{
				buildWheel();
			};
			redrawHueStrip();
			redrawSVSquare();
			redrawPreview();
			wheelOverlay.visible = true;
			if (stage)
			{
				stage.addEventListener(MouseEvent.MOUSE_UP, onWheelMouseUp);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, onWheelMouseMove);
			};
		}

		private function hideWheel():void
		{
			draggingHue = false;
			draggingSV = false;
			hexEditing = false;
			wheelTarget = "";
			if (wheelOverlay)
			{
				wheelOverlay.visible = false;
			};
			if (stage)
			{
				stage.removeEventListener(MouseEvent.MOUSE_UP, onWheelMouseUp);
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onWheelMouseMove);
			};
		}

		private function buildWheel():void
		{
			var okBtn:Sprite;
			var cancelBtn:Sprite;
			var title:TextField;
			var box:Sprite;
			var hexLabel:TextField;
			wheelOverlay = new Sprite();
			wheelOverlay.graphics.beginFill(0x000000, 0.55);
			wheelOverlay.graphics.drawRect(-20, -20, 280, 320);
			wheelOverlay.graphics.endFill();
			box = new Sprite();
			box.graphics.beginFill(0x222230, 0.98);
			box.graphics.lineStyle(1, 0x888899, 1);
			box.graphics.drawRoundRect(0, 0, 220, 248, 8, 8);
			box.graphics.endFill();
			wheelOverlay.addChild(box);
			title = makeLabel("Select highlight color", 11, true);
			title.x = 10;
			title.y = 6;
			box.addChild(title);

			hueStrip = new Bitmap(new BitmapData(18, 140, false, 0));
			hueHit = new Sprite();
			hueHit.x = 12;
			hueHit.y = 28;
			hueHit.addChild(hueStrip);
			hueHit.graphics.beginFill(0x000000, 0);
			hueHit.graphics.drawRect(0, 0, 18, 140);
			hueHit.graphics.endFill();
			hueHit.buttonMode = true;
			box.addChild(hueHit);
			hueHit.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):void {
				draggingHue = true;
				sampleHue(e.localY);
			});

			svSquare = new Bitmap(new BitmapData(140, 140, false, 0));
			svHit = new Sprite();
			svHit.x = 40;
			svHit.y = 28;
			svHit.addChild(svSquare);
			svHit.graphics.beginFill(0x000000, 0);
			svHit.graphics.drawRect(0, 0, 140, 140);
			svHit.graphics.endFill();
			svHit.buttonMode = true;
			box.addChild(svHit);
			svHit.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):void {
				draggingSV = true;
				sampleSV(e.localX, e.localY);
			});

			previewBox = new Sprite();
			previewBox.x = 12;
			previewBox.y = 176;
			box.addChild(previewBox);

			hexLabel = makeLabel("Hex", 9, false);
			hexLabel.x = 58;
			hexLabel.y = 178;
			box.addChild(hexLabel);

			hexInput = new TextField();
			hexInput.type = TextFieldType.INPUT;
			hexInput.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF, true);
			hexInput.restrict = "#0-9A-Fa-f";
			hexInput.maxChars = 7;
			hexInput.border = true;
			hexInput.borderColor = 0x666677;
			hexInput.background = true;
			hexInput.backgroundColor = 0x2A2A35;
			hexInput.width = 78;
			hexInput.height = 18;
			hexInput.x = 86;
			hexInput.y = 176;
			hexInput.addEventListener(Event.CHANGE, onHexInputChange);
			hexInput.addEventListener(FocusEvent.FOCUS_IN, function(e:FocusEvent):void { hexEditing = true; });
			hexInput.addEventListener(FocusEvent.FOCUS_OUT, function(e:FocusEvent):void {
				hexEditing = false;
				applyHexFromField(false);
			});
			hexInput.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent):void {
				if (e.keyCode == Keyboard.ENTER)
				{
					applyHexFromField(true);
				};
			});
			box.addChild(hexInput);

			okBtn = makeTextButton("OK", 90, 20);
			okBtn.x = 12;
			okBtn.y = 210;
			okBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				applyHexFromField(true);
				commitWheelColor();
			});
			box.addChild(okBtn);

			cancelBtn = makeTextButton("Cancel", 90, 20);
			cancelBtn.x = 118;
			cancelBtn.y = 210;
			cancelBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hideWheel();
			});
			box.addChild(cancelBtn);

			addChild(wheelOverlay);
			wheelOverlay.visible = false;
		}

		private function commitWheelColor():void
		{
			var col:uint = HsvWheel.hsvToRgb(wheelHue, wheelSat, wheelVal, 0xFF);
			if (wheelTarget == "alt")
			{
				altColor = col;
				redrawSwatches();
				if (onSelectHighlightAltChanged != null)
				{
					onSelectHighlightAltChanged(col);
				};
			}
			else
			{
				primaryColor = col;
				redrawSwatches();
				if (onSelectHighlightPrimaryChanged != null)
				{
					onSelectHighlightPrimaryChanged(col);
				};
			};
			hideWheel();
		}

		private function sampleHue(localY:Number):void
		{
			wheelHue = HsvWheel.hueAt(localY, 140);
			redrawSVSquare();
			redrawPreview();
		}

		private function sampleSV(localX:Number, localY:Number):void
		{
			wheelSat = HsvWheel.satAt(localX, 139);
			wheelVal = HsvWheel.valAt(localY, 139);
			redrawPreview();
		}

		private function onWheelMouseUp(e:MouseEvent):void
		{
			draggingHue = false;
			draggingSV = false;
		}

		private function onWheelMouseMove(e:MouseEvent):void
		{
			if (draggingHue && hueHit)
			{
				sampleHue(hueHit.mouseY);
			};
			if (draggingSV && svHit)
			{
				sampleSV(svHit.mouseX, svHit.mouseY);
			};
		}

		private function redrawHueStrip():void
		{
			if (hueStrip)
			{
				HsvWheel.drawHueStrip(hueStrip.bitmapData);
			};
		}

		private function redrawSVSquare():void
		{
			if (svSquare)
			{
				HsvWheel.drawSvSquare(svSquare.bitmapData, wheelHue);
			};
		}

		private function redrawPreview():void
		{
			var c:uint = HsvWheel.hsvToRgb(wheelHue, wheelSat, wheelVal, 0xFF) & 0x00FFFFFF;
			if (!previewBox)
			{
				return;
			};
			previewBox.graphics.clear();
			previewBox.graphics.beginFill(c, 1);
			previewBox.graphics.drawRoundRect(0, 0, 40, 20, 3, 3);
			previewBox.graphics.endFill();
			if (hexInput && !hexEditing)
			{
				hexInput.text = HsvWheel.formatHex(c);
			};
		}

		private function onHexInputChange(e:Event):void
		{
			applyHexFromField(false);
		}

		private function applyHexFromField(force:Boolean):void
		{
			var parsed:int;
			if (!hexInput)
			{
				return;
			};
			parsed = HsvWheel.parseHex(hexInput.text);
			if (parsed < 0)
			{
				return;
			};
			var hsv:Object = HsvWheel.rgbToHsv(uint(parsed));
			wheelHue = hsv.h;
			wheelSat = hsv.s;
			wheelVal = hsv.v;
			redrawSVSquare();
			if (force || !hexEditing)
			{
				redrawPreview();
			}
			else
			{
				previewBox.graphics.clear();
				previewBox.graphics.beginFill(uint(parsed), 1);
				previewBox.graphics.drawRoundRect(0, 0, 40, 20, 3, 3);
				previewBox.graphics.endFill();
			};
		}

	}
}
