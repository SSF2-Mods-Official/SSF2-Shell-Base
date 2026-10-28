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
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.text.TextFieldAutoSize;
	import flash.ui.Keyboard;

	/**
	 * Overlay panel for Color Settings (CS) that sits over the slider column.
	 */
	public class ColorSettingsPopup extends PopupBase
	{
		public var onClose:Function = null;
		public var onTextFocusChange:Function = null;
		public var onPickSwatchColor:Function = null;
		public var onPickSwatchPreview:Function = null;
		public var onWheelOpen:Function = null;
		public var onWheelCancel:Function = null;
		public var onEyedropper:Function = null;
		public var onChangePrimary:Function = null;
		public var onCancelPrimaryPick:Function = null;
		public var onMatchAll:Function = null;
		public var onUndoMatchAll:Function = null;
		public var onDontUseSwatchKeep:Function = null;
		public var onDontUseSwatchUndo:Function = null;
		public var onRenameGroup:Function = null;
		public var onDeleteGroup:Function = null;
		public var onToggleLock:Function = null;
		public var onToggleEnabled:Function = null;

		private var swatchBtn:Sprite;
		private var swatchFill:Sprite;
		private var statusTxt:TextField;
		private var nameInput:TextField;
		private var matchAllBtn:Sprite;
		private var matchAllLabel:TextField;
		private var lockBtn:Sprite;
		private var lockLabel:TextField;
		private var enabledBtn:Sprite;
		private var enabledLabel:TextField;
		private var primaryPickBanner:Sprite;
		private var cancelPrimaryBtn:Sprite;
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
		private var currentSwatch:uint = 0xFF0000;
		private var hasSwatch:Boolean = false;
		private var memberCount:int = 0;
		private var matchAllActive:Boolean = false;
		private var useSwatchActive:Boolean = false;
		private var lockedActive:Boolean = false;
		private var enabledActive:Boolean = true;

		public function ColorSettingsPopup()
		{
			labelColor = 0xEEEEEE;
			buttonFill = 0x2E2E3A;
			buttonTextSize = 9;
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
			var nameLabel:TextField;
			var keepBtn:Sprite;
			var undoSwatchBtn:Sprite;
			var deleteBtn:Sprite;
			var closeBtn:Sprite;
			makePanel(210, 186, 0.96, 0x555566);

			title = makeLabel("Color Settings", 11, true);
			title.x = 8;
			title.y = 3;
			panel.addChild(title);

			statusTxt = makeLabel("", 9, false);
			statusTxt.x = 8;
			statusTxt.y = 18;
			statusTxt.width = 194;
			panel.addChild(statusTxt);

			nameLabel = makeLabel("Name", 9, false);
			nameLabel.x = 8;
			nameLabel.y = 34;
			panel.addChild(nameLabel);

			nameInput = new TextField();
			nameInput.type = TextFieldType.INPUT;
			nameInput.defaultTextFormat = new TextFormat("_sans", 10, 0xFFFFFF);
			nameInput.border = true;
			nameInput.borderColor = 0x666677;
			nameInput.background = true;
			nameInput.backgroundColor = 0x2A2A35;
			nameInput.width = 148;
			nameInput.height = 16;
			nameInput.x = 46;
			nameInput.y = 32;
			nameInput.addEventListener(Event.CHANGE, function(e:Event):void {
				if (onRenameGroup != null)
				{
					onRenameGroup(nameInput.text);
				};
			});
			nameInput.addEventListener(FocusEvent.FOCUS_IN, function(e:FocusEvent):void {
				if (onTextFocusChange != null)
				{
					onTextFocusChange(true);
				};
			});
			nameInput.addEventListener(FocusEvent.FOCUS_OUT, function(e:FocusEvent):void {
				if (onTextFocusChange != null)
				{
					onTextFocusChange(false);
				};
			});
			panel.addChild(nameInput);

			swatchBtn = makeButton("", 20);
			swatchBtn.x = 8;
			swatchBtn.y = 52;
			swatchBtn.graphics.clear();
			swatchBtn.graphics.lineStyle(1, 0xFFFFFF, 0.8);
			swatchBtn.graphics.beginFill(0x333333, 1);
			swatchBtn.graphics.drawRoundRect(0, 0, 20, 20, 4, 4);
			swatchBtn.graphics.endFill();
			swatchFill = new Sprite();
			swatchBtn.addChild(swatchFill);
			redrawSwatchFill();
			swatchBtn.addEventListener(MouseEvent.CLICK, onSwatchClick);
			panel.addChild(swatchBtn);

			btn = makeTextButton("Pick color", 78, 18);
			btn.x = 34;
			btn.y = 53;
			btn.addEventListener(MouseEvent.CLICK, onSwatchClick);
			panel.addChild(btn);

			btn = makeTextButton("Eyedropper", 84, 18);
			btn.x = 118;
			btn.y = 53;
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hideWheel();
				if (onEyedropper != null) onEyedropper();
			});
			panel.addChild(btn);

			btn = makeTextButton("Change primary", 194, 18);
			btn.x = 8;
			btn.y = 76;
			btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onChangePrimary != null) onChangePrimary();
			});
			panel.addChild(btn);

			matchAllBtn = makeTextButton("Make all match swatch", 194, 18);
			matchAllBtn.x = 8;
			matchAllBtn.y = 97;
			matchAllLabel = matchAllBtn.getChildAt(0) as TextField;
			matchAllBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (matchAllActive)
				{
					if (onUndoMatchAll != null) onUndoMatchAll();
				}
				else
				{
					if (onMatchAll != null) onMatchAll();
				};
			});
			panel.addChild(matchAllBtn);

			keepBtn = makeTextButton("Keep colors", 94, 18);
			keepBtn.x = 8;
			keepBtn.y = 118;
			keepBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onDontUseSwatchKeep != null) onDontUseSwatchKeep();
			});
			panel.addChild(keepBtn);

			undoSwatchBtn = makeTextButton("Undo swatch", 94, 18);
			undoSwatchBtn.x = 108;
			undoSwatchBtn.y = 118;
			undoSwatchBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onDontUseSwatchUndo != null) onDontUseSwatchUndo();
			});
			panel.addChild(undoSwatchBtn);

			lockBtn = makeTextButton("Lock group", 94, 18);
			lockBtn.x = 8;
			lockBtn.y = 139;
			lockLabel = lockBtn.getChildAt(0) as TextField;
			lockBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onToggleLock != null) onToggleLock();
			});
			panel.addChild(lockBtn);

			enabledBtn = makeTextButton("Disable group", 94, 18);
			enabledBtn.x = 108;
			enabledBtn.y = 139;
			enabledLabel = enabledBtn.getChildAt(0) as TextField;
			enabledBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onToggleEnabled != null) onToggleEnabled();
			});
			panel.addChild(enabledBtn);

			deleteBtn = makeTextButton("Delete", 94, 18);
			deleteBtn.x = 8;
			deleteBtn.y = 160;
			deleteBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				if (onDeleteGroup != null) onDeleteGroup();
			});
			panel.addChild(deleteBtn);

			closeBtn = makeTextButton("Close", 94, 18);
			closeBtn.x = 108;
			closeBtn.y = 160;
			closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hide();
				if (onClose != null) onClose();
			});
			panel.addChild(closeBtn);

			primaryPickBanner = new Sprite();
			primaryPickBanner.graphics.beginFill(0x2A3A55, 0.95);
			primaryPickBanner.graphics.drawRoundRect(0, 0, 194, 36, 4, 4);
			primaryPickBanner.graphics.endFill();
			primaryPickBanner.x = 8;
			primaryPickBanner.y = 76;
			primaryPickBanner.visible = false;
			var pickTxt:TextField = makeLabel("Click swatch / sprite / PA\nto set primary", 9, false);
			pickTxt.x = 6;
			pickTxt.y = 2;
			primaryPickBanner.addChild(pickTxt);
			cancelPrimaryBtn = makeTextButton("Cancel", 64, 16);
			cancelPrimaryBtn.x = 122;
			cancelPrimaryBtn.y = 17;
			cancelPrimaryBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				setPrimaryPickMode(false);
				if (onCancelPrimaryPick != null) onCancelPrimaryPick();
			});
			primaryPickBanner.addChild(cancelPrimaryBtn);
			panel.addChild(primaryPickBanner);
		}

		private function makeButton(label:String, h:Number):Sprite
		{
			var s:Sprite = new Sprite();
			s.buttonMode = true;
			s.useHandCursor = true;
			return s;
		}

		private function redrawSwatchFill():void
		{
			swatchFill.graphics.clear();
			swatchFill.graphics.beginFill(hasSwatch ? (currentSwatch & 0x00FFFFFF) : 0x444444, 1);
			swatchFill.graphics.drawRoundRect(2, 2, 16, 16, 3, 3);
			swatchFill.graphics.endFill();
		}

		private function refreshMatchAllButton():void
		{
			if (!matchAllLabel)
			{
				return;
			};
			matchAllLabel.text = matchAllActive ? "Undo make-all match" : "Make all match swatch";
		}

		private function refreshLockButton():void
		{
			if (!lockLabel)
			{
				return;
			};
			lockLabel.text = lockedActive ? "Unlock" : "Lock group";
		}

		private function refreshEnabledButton():void
		{
			if (!enabledLabel)
			{
				return;
			};
			enabledLabel.text = enabledActive ? "Disable" : "Enable";
		}

		public function showAt(px:Number, py:Number, members:int, primaryRepl:uint, swatch:uint, hasSw:Boolean, useSwatch:Boolean, matchAll:Boolean, groupName:String, locked:Boolean = false, groupOn:Boolean = true):void
		{
			x = px;
			y = py;
			memberCount = members;
			hasSwatch = hasSw;
			currentSwatch = swatch;
			useSwatchActive = useSwatch;
			matchAllActive = matchAll;
			lockedActive = locked;
			enabledActive = groupOn;
			redrawSwatchFill();
			nameInput.text = groupName || "Group";
			refreshMatchAllButton();
			refreshLockButton();
			refreshEnabledButton();
			updateHeader(members, useSwatch, matchAll);
			setPrimaryPickMode(false);
			hideWheel();
			setOpen(true);
			clampPanelToStage();
		}

		public function updateHeader(members:int, useSwatch:Boolean, matchAll:Boolean = false):void
		{
			memberCount = members;
			useSwatchActive = useSwatch;
			matchAllActive = matchAll;
			var mode:String = "Sliders on";
			if (useSwatch)
			{
				mode = matchAll ? "Match-all on" : "Swatch on";
			};
			statusTxt.text = members + " colors  |  " + mode
				+ (lockedActive ? "  |  Locked" : "")
				+ (enabledActive ? "" : "  |  Off");
			refreshMatchAllButton();
		}

		public function setLocked(locked:Boolean):void
		{
			lockedActive = locked;
			refreshLockButton();
			updateHeader(memberCount, useSwatchActive, matchAllActive);
		}

		public function setGroupEnabledState(on:Boolean):void
		{
			enabledActive = on;
			refreshEnabledButton();
			updateHeader(memberCount, useSwatchActive, matchAllActive);
		}

		public function hide():void
		{
			setPrimaryPickMode(false);
			hideWheel(false);
			setOpen(false);
		}

		public function setSwatchColor(color:uint, hasSw:Boolean = true):void
		{
			currentSwatch = color;
			hasSwatch = hasSw;
			redrawSwatchFill();
		}

		/** True when Color Settings is using a picked swatch (wheel / eyedropper). */
		public function get hasActiveSwatch():Boolean
		{
			return hasSwatch && useSwatchActive;
		}

		public function get activeSwatchColor():uint
		{
			return currentSwatch;
		}

		public function setPrimaryPickMode(active:Boolean):void
		{
			primaryPickBanner.visible = active;
		}

		private function onSwatchClick(e:MouseEvent):void
		{
			openWheel(hasSwatch ? currentSwatch : 0xFF0000);
		}

		private function openWheel(startColor:uint):void
		{
			var hsv:Object = HsvWheel.rgbToHsv(startColor);
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
			if (onWheelOpen != null)
			{
				onWheelOpen();
			};
			emitWheelPreview();
			if (stage)
			{
				stage.addEventListener(MouseEvent.MOUSE_UP, onWheelMouseUp);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, onWheelMouseMove);
			};
		}

		private function hideWheel(cancelPreview:Boolean = false):void
		{
			draggingHue = false;
			draggingSV = false;
			hexEditing = false;
			if (wheelOverlay)
			{
				wheelOverlay.visible = false;
			};
			if (stage)
			{
				stage.removeEventListener(MouseEvent.MOUSE_UP, onWheelMouseUp);
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onWheelMouseMove);
			};
			if (cancelPreview && onWheelCancel != null)
			{
				onWheelCancel();
			};
		}

		private function emitWheelPreview():void
		{
			var col:uint = HsvWheel.hsvToRgb(wheelHue, wheelSat, wheelVal, 0xFF);
			currentSwatch = col;
			hasSwatch = true;
			redrawSwatchFill();
			redrawPreview();
			if (onPickSwatchPreview != null)
			{
				onPickSwatchPreview(col);
			};
		}

		private function buildWheel():void
		{
			var okBtn:Sprite;
			var cancelBtn:Sprite;
			var dropperBtn:Sprite;
			var title:TextField;
			wheelOverlay = new Sprite();
			wheelOverlay.graphics.beginFill(0x000000, 0.55);
			wheelOverlay.graphics.drawRect(-20, -20, 260, 300);
			wheelOverlay.graphics.endFill();
			var box:Sprite = new Sprite();
			box.graphics.beginFill(0x222230, 0.98);
			box.graphics.lineStyle(1, 0x888899, 1);
			box.graphics.drawRoundRect(0, 0, 220, 262, 8, 8);
			box.graphics.endFill();
			box.x = 0;
			box.y = 0;
			wheelOverlay.addChild(box);
			title = makeLabel("Color Wheel", 12, true);
			title.x = 10;
			title.y = 6;
			box.addChild(title);

			hueStrip = new Bitmap(new BitmapData(18, 140, false, 0));
			hueHit = new Sprite();
			hueHit.x = 12;
			hueHit.y = 30;
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
			svHit.y = 30;
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
			previewBox.y = 178;
			box.addChild(previewBox);

			var hexLabel:TextField = makeLabel("Hex", 9, false);
			hexLabel.x = 58;
			hexLabel.y = 180;
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
			hexInput.y = 178;
			hexInput.addEventListener(Event.CHANGE, onHexInputChange);
			hexInput.addEventListener(FocusEvent.FOCUS_IN, onHexFocusIn);
			hexInput.addEventListener(FocusEvent.FOCUS_OUT, onHexFocusOut);
			hexInput.addEventListener(KeyboardEvent.KEY_DOWN, onHexKeyDown);
			box.addChild(hexInput);

			dropperBtn = makeTextButton("Eyedropper", 80, 20);
			dropperBtn.x = 12;
			dropperBtn.y = 230;
			dropperBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hideWheel(false);
				if (onEyedropper != null) onEyedropper();
			});
			box.addChild(dropperBtn);

			okBtn = makeTextButton("OK", 55, 20);
			okBtn.x = 100;
			okBtn.y = 230;
			okBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				applyHexFromField(true);
				var col:uint = HsvWheel.hsvToRgb(wheelHue, wheelSat, wheelVal, 0xFF);
				currentSwatch = col;
				hasSwatch = true;
				redrawSwatchFill();
				hideWheel(false);
				updateHeader(memberCount, true, matchAllActive);
				if (onPickSwatchColor != null)
				{
					onPickSwatchColor(col);
				};
			});
			box.addChild(okBtn);

			cancelBtn = makeTextButton("Cancel", 50, 20);
			cancelBtn.x = 162;
			cancelBtn.y = 230;
			cancelBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hideWheel(true);
			});
			box.addChild(cancelBtn);

			addChild(wheelOverlay);
			wheelOverlay.visible = false;
		}

		private function redrawHueStrip():void
		{
			HsvWheel.drawHueStrip(hueStrip.bitmapData);
		}

		private function redrawSVSquare():void
		{
			HsvWheel.drawSvSquare(svSquare.bitmapData, wheelHue);
		}

		private function redrawPreview():void
		{
			var c:uint = HsvWheel.hsvToRgb(wheelHue, wheelSat, wheelVal, 0xFF) & 0x00FFFFFF;
			previewBox.graphics.clear();
			previewBox.graphics.beginFill(c, 1);
			previewBox.graphics.drawRoundRect(0, 0, 40, 20, 3, 3);
			previewBox.graphics.endFill();
			if (hexInput && !hexEditing)
			{
				hexInput.text = HsvWheel.formatHex(c);
			};
		}

		private function onHexFocusIn(e:FocusEvent):void
		{
			hexEditing = true;
			if (onTextFocusChange != null)
			{
				onTextFocusChange(true);
			};
		}

		private function onHexFocusOut(e:FocusEvent):void
		{
			applyHexFromField(true);
			hexEditing = false;
			if (onTextFocusChange != null)
			{
				onTextFocusChange(false);
			};
		}

		private function onHexKeyDown(e:KeyboardEvent):void
		{
			if (e.keyCode == Keyboard.ENTER)
			{
				applyHexFromField(true);
				e.stopPropagation();
			};
		}

		private function onHexInputChange(e:Event):void
		{
			applyHexFromField(false);
		}

		/**
		 * Apply typed hex to the wheel. When requireComplete is false, only apply
		 * full 6-digit (or #RGB) values so partial typing does not thrash HSV.
		 */
		private function applyHexFromField(requireComplete:Boolean):Boolean
		{
			var parsed:int;
			var col:uint;
			var hsv:Object;
			var raw:String;
			if (!hexInput)
			{
				return false;
			};
			parsed = HsvWheel.parseHex(hexInput.text);
			if (parsed < 0)
			{
				if (requireComplete)
				{
					hexInput.text = HsvWheel.formatHex(HsvWheel.hsvToRgb(wheelHue, wheelSat, wheelVal, 0xFF));
				};
				return false;
			};
			col = uint(0xFF000000 | parsed);
			hsv = HsvWheel.rgbToHsv(col);
			wheelHue = hsv.h;
			wheelSat = hsv.s;
			wheelVal = hsv.v;
			currentSwatch = col;
			hasSwatch = true;
			redrawSwatchFill();
			redrawSVSquare();
			previewBox.graphics.clear();
			previewBox.graphics.beginFill(col & 0x00FFFFFF, 1);
			previewBox.graphics.drawRoundRect(0, 0, 40, 20, 3, 3);
			previewBox.graphics.endFill();
			raw = hexInput.text.replace(new RegExp("^#", ""), "");
			if (requireComplete || raw.length >= 6)
			{
				hexInput.text = HsvWheel.formatHex(col);
			};
			if (onPickSwatchPreview != null)
			{
				onPickSwatchPreview(col);
			};
			return true;
		}

		private function sampleHue(localY:Number):void
		{
			wheelHue = HsvWheel.hueAt(localY, 140);
			redrawSVSquare();
			emitWheelPreview();
		}

		private function sampleSV(localX:Number, localY:Number):void
		{
			wheelSat = HsvWheel.satAt(localX, 140);
			wheelVal = HsvWheel.valAt(localY, 140);
			emitWheelPreview();
		}

		private function onWheelMouseUp(e:MouseEvent):void
		{
			draggingHue = false;
			draggingSV = false;
		}

		private function onWheelMouseMove(e:MouseEvent):void
		{
			var gp:Point;
			if (draggingHue && hueHit)
			{
				gp = hueHit.globalToLocal(new Point(e.stageX, e.stageY));
				sampleHue(gp.y);
			};
			if (draggingSV && svHit)
			{
				gp = svHit.globalToLocal(new Point(e.stageX, e.stageY));
				sampleSV(gp.x, gp.y);
			};
		}
	}
}
