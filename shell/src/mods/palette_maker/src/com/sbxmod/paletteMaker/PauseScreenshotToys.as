package com.sbxmod.paletteMaker
{
	import ssf2mm.shared.HsvWheel;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.filters.DropShadowFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;

	/**
	 * Pause-screen screenshot helpers: costume/author name overlay + freehand draw layer.
	 * Toolbar controls are not captured; captureLayer is.
	 */
	public class PauseScreenshotToys extends Sprite
	{
		public static const CORNER_BR:int = 0;
		public static const CORNER_BL:int = 1;
		public static const CORNER_TL:int = 2;
		public static const CORNER_TR:int = 3;

		private static const FONT_CYCLE:Array = [
			"Impact",
			"Showcard Gothic",
			"Stencil",
			"Chiller",
			"Segoe Script",
			"Brush Script MT",
			"Comic Sans MS",
			"Papyrus",
			"Viner Hand ITC",
			"Arial Black",
			"_sans"
		];
		/** Name overlay sizes; index 0 is default (smallest). */
		private static const FONT_SIZES:Array = [22, 31, 40, 52];

		private static const BTN:Number = 28;
		private static const GAP:Number = 8;
		private static const PICK_NAME:String = "name";
		private static const PICK_DRAW:String = "draw";

		/** Called when hide-portrait toggle changes. Args: (hidden:Boolean) */
		public var onToggleHideArt:Function = null;

		/** Controls strip — hide during camera snapshot. */
		public var toolbar:Sprite;
		/** Name + draw art — keep visible for camera. */
		public var captureLayer:Sprite;

		private var nameBtn:Sprite;
		private var drawBtn:Sprite;
		private var hideArtBtn:Sprite;
		private var fontBtn:Sprite;
		private var sizeBtn:Sprite;
		private var cornerBtn:Sprite;
		private var nameColorBtn:Sprite;
		private var nameColorFill:Sprite;
		private var nameEyedropBtn:Sprite;
		private var drawColorBtn:Sprite;
		private var drawColorFill:Sprite;
		private var drawEyedropBtn:Sprite;
		private var eraseBtn:Sprite;

		private var nameTools:Sprite;
		private var drawTools:Sprite;

		private var nameField:TextField;
		private var drawHost:Sprite;
		private var drawBitmap:Bitmap;
		private var drawData:BitmapData;

		private var picker:Sprite;
		private var pickerTarget:String = PICK_NAME;
		private var hueStrip:Bitmap;
		private var svSquare:Bitmap;
		private var hueHit:Sprite;
		private var svHit:Sprite;
		private var previewBox:Sprite;
		private var wheelHue:Number = 0;
		private var wheelSat:Number = 1;
		private var wheelVal:Number = 1;
		private var draggingHue:Boolean = false;
		private var draggingSV:Boolean = false;

		private var nameVisible:Boolean = false;
		private var drawMode:Boolean = false;
		private var drawListenersWired:Boolean = false;
		private var eraseMode:Boolean = false;
		private var eyedropMode:Boolean = false;
		private var eyedropTarget:String = PICK_NAME;
		private var eyedropListenersWired:Boolean = false;
		private var artHidden:Boolean = false;
		private var fontIndex:int = 0;
		private var fontSizeIndex:int = 0;
		private var corner:int = CORNER_BR;
		private var nameColor:uint = 0xFFFFFF;
		private var drawColor:uint = 0xFF3333;
		private var drawing:Boolean = false;
		private var lastDrawX:Number = 0;
		private var lastDrawY:Number = 0;
		private var stageW:Number = 640;
		private var stageH:Number = 360;
		private var costumeName:String = "";
		private var authorName:String = "";
		private var toolHint:TextField = null;

		/** HUD camera borrowed onto this layer while toys are visible so draw mode can't steal clicks. */
		private var camChrome:Sprite;
		private var borrowedCam:DisplayObject;
		private var borrowedCamParent:DisplayObjectContainer;
		private var borrowedCamIndex:int = -1;
		private var borrowedCamX:Number = 0;
		private var borrowedCamY:Number = 0;

		public function PauseScreenshotToys(width:Number, height:Number)
		{
			stageW = width;
			stageH = height;
			mouseEnabled = false;
			mouseChildren = true;
			build();
			visible = false;
		}

		private function build():void
		{
			captureLayer = new Sprite();
			captureLayer.mouseEnabled = false;
			captureLayer.mouseChildren = false;
			addChild(captureLayer);

			camChrome = new Sprite();
			camChrome.mouseEnabled = false;
			camChrome.mouseChildren = true;
			addChild(camChrome);

			nameField = new TextField();
			nameField.autoSize = TextFieldAutoSize.LEFT;
			nameField.selectable = false;
			nameField.mouseEnabled = false;
			nameField.multiline = true;
			nameField.filters = [new DropShadowFilter(2, 45, 0x000000, 0.9, 4, 4, 2, 2)];
			captureLayer.addChild(nameField);

			drawHost = new Sprite();
			drawHost.mouseEnabled = false;
			drawHost.mouseChildren = false;
			captureLayer.addChild(drawHost);

			toolbar = new Sprite();
			addChild(toolbar);

			toolHint = new TextField();
			toolHint.defaultTextFormat = new TextFormat("_sans", 11, 0xDDDDDD, false);
			toolHint.autoSize = TextFieldAutoSize.LEFT;
			toolHint.selectable = false;
			toolHint.mouseEnabled = false;
			toolHint.text = "";
			toolHint.filters = [new DropShadowFilter(1, 45, 0x000000, 0.9, 2, 2, 1, 2)];
			addChild(toolHint);

			nameBtn = makeIconBtn(drawAaIcon, "Name tag");
			nameBtn.addEventListener(MouseEvent.CLICK, onToggleName);
			toolbar.addChild(nameBtn);

			drawBtn = makeIconBtn(drawPencilIcon, "Draw");
			drawBtn.addEventListener(MouseEvent.CLICK, onToggleDraw);
			toolbar.addChild(drawBtn);

			hideArtBtn = makeIconBtn(drawHideArtIcon, "Hide PA");
			hideArtBtn.addEventListener(MouseEvent.CLICK, onToggleHideArtClick);
			toolbar.addChild(hideArtBtn);

			nameTools = new Sprite();
			toolbar.addChild(nameTools);

			fontBtn = makeIconBtn(drawFontIcon, "Font");
			fontBtn.addEventListener(MouseEvent.CLICK, onCycleFont);
			nameTools.addChild(fontBtn);

			sizeBtn = makeIconBtn(drawSizeIcon, "Size");
			sizeBtn.addEventListener(MouseEvent.CLICK, onCycleFontSize);
			nameTools.addChild(sizeBtn);

			cornerBtn = makeIconBtn(drawCornerIcon, "Corner");
			cornerBtn.addEventListener(MouseEvent.CLICK, onCycleCorner);
			nameTools.addChild(cornerBtn);

			nameColorBtn = makeSwatchBtn("Name color");
			nameColorBtn.addEventListener(MouseEvent.CLICK, onOpenNameColorPicker);
			nameColorFill = nameColorBtn.getChildByName("fill") as Sprite;
			nameTools.addChild(nameColorBtn);

			nameEyedropBtn = makeIconBtn(drawEyedropIcon, "Eyedropper");
			nameEyedropBtn.addEventListener(MouseEvent.CLICK, onNameEyedrop);
			nameTools.addChild(nameEyedropBtn);

			drawTools = new Sprite();
			toolbar.addChild(drawTools);

			drawColorBtn = makeSwatchBtn("Draw color");
			drawColorBtn.addEventListener(MouseEvent.CLICK, onOpenDrawColorPicker);
			drawColorFill = drawColorBtn.getChildByName("fill") as Sprite;
			drawTools.addChild(drawColorBtn);

			drawEyedropBtn = makeIconBtn(drawEyedropIcon, "Eyedropper");
			drawEyedropBtn.addEventListener(MouseEvent.CLICK, onDrawEyedrop);
			drawTools.addChild(drawEyedropBtn);

			eraseBtn = makeIconBtn(drawEraserIcon, "Eraser");
			eraseBtn.addEventListener(MouseEvent.CLICK, onToggleErase);
			drawTools.addChild(eraseBtn);

			layoutToolbar();
			refreshToolbarState();
			refreshNameField();
		}

		private function makeSwatchBtn(tip:String = "Color"):Sprite
		{
			var s:Sprite = new Sprite();
			var fill:Sprite = new Sprite();
			fill.name = "fill";
			s.graphics.beginFill(0x1A1A22, 0.95);
			s.graphics.lineStyle(1, 0x888899, 1);
			s.graphics.drawRoundRect(0, 0, BTN, BTN, 6, 6);
			s.graphics.endFill();
			s.addChild(fill);
			s.buttonMode = true;
			s.useHandCursor = true;
			s.name = tip;
			s.addEventListener(MouseEvent.MOUSE_OVER, onToolTipOver);
			s.addEventListener(MouseEvent.MOUSE_OUT, onToolTipOut);
			return s;
		}

		private function makeIconBtn(iconDrawer:Function, tip:String):Sprite
		{
			var s:Sprite = new Sprite();
			var bg:Sprite = new Sprite();
			var icon:Sprite = new Sprite();
			bg.name = "bg";
			icon.name = "icon";
			icon.mouseEnabled = false;
			s.addChild(bg);
			s.addChild(icon);
			drawBtnBg(bg, false);
			iconDrawer(icon);
			s.buttonMode = true;
			s.useHandCursor = true;
			s.name = tip;
			s.addEventListener(MouseEvent.MOUSE_OVER, onToolTipOver);
			s.addEventListener(MouseEvent.MOUSE_OUT, onToolTipOut);
			return s;
		}

		private function onToolTipOver(e:MouseEvent):void
		{
			var tip:String;
			if (!toolHint || !e || !e.currentTarget)
			{
				return;
			};
			tip = String(Sprite(e.currentTarget).name);
			toolHint.text = tip ? tip : "";
			layoutToolHint();
		}

		private function onToolTipOut(e:MouseEvent):void
		{
			if (toolHint)
			{
				toolHint.text = "";
			};
		}

		private function layoutToolHint():void
		{
			if (!toolHint || !toolbar)
			{
				return;
			};
			toolHint.x = toolbar.x;
			toolHint.y = toolbar.y - 18;
		}

		private function drawBtnBg(bg:Sprite, on:Boolean):void
		{
			bg.graphics.clear();
			bg.graphics.beginFill(on ? 0x3A4A6A : 0x1A1A22, 0.95);
			bg.graphics.lineStyle(1, on ? 0xAACCFF : 0x888899, 1);
			bg.graphics.drawRoundRect(0, 0, BTN, BTN, 6, 6);
			bg.graphics.endFill();
		}

		private function drawAaIcon(g:Sprite):void
		{
			LucideIconRenderer.drawEmbeddedSvg(g.graphics, LucideIconRenderer.PAUSE_TYPE, BTN, 0xFFFFFF, 4);
		}

		private function drawFontIcon(g:Sprite):void
		{
			// Fancy "F" label — clearer for font-cycle than the Lucide baseline glyph at 28px.
			var tf:TextField = new TextField();
			tf.defaultTextFormat = new TextFormat("Impact", 16, 0xFFFFFF, false, null, null, null, null, TextFormatAlign.CENTER);
			tf.width = BTN;
			tf.height = 22;
			tf.y = 3;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.text = "F";
			g.addChild(tf);
		}

		private function drawSizeIcon(g:Sprite):void
		{
			var tf:TextField = new TextField();
			tf.name = "label";
			tf.defaultTextFormat = new TextFormat("_sans", 9, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER);
			tf.width = BTN;
			tf.height = 20;
			tf.y = 6;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.text = "S";
			g.addChild(tf);
		}

		private function refreshSizeIcon():void
		{
			var icon:Sprite;
			var tf:TextField;
			var labels:Array = ["S", "M", "L", "XL"];
			if (!sizeBtn)
			{
				return;
			};
			icon = sizeBtn.getChildByName("icon") as Sprite;
			if (!icon)
			{
				return;
			};
			tf = icon.getChildByName("label") as TextField;
			if (tf)
			{
				tf.text = String(labels[fontSizeIndex % labels.length]);
			};
		}

		private function drawCornerIcon(g:Sprite):void
		{
			redrawCornerOn(g);
		}

		private function redrawCornerIcon():void
		{
			var icon:Sprite;
			if (!cornerBtn)
			{
				return;
			};
			icon = cornerBtn.getChildByName("icon") as Sprite;
			if (!icon)
			{
				return;
			};
			redrawCornerOn(icon);
		}

		/** Lucide square outline + filled corner marker (dynamic state). */
		private function redrawCornerOn(icon:Sprite):void
		{
			var mark:Number = 6;
			var inset:Number = 7;
			if (!icon)
			{
				return;
			};
			icon.graphics.clear();
			while (icon.numChildren > 0)
			{
				icon.removeChildAt(0);
			};
			LucideIconRenderer.drawEmbeddedSvg(icon.graphics, LucideIconRenderer.PAUSE_SQUARE, BTN, 0xFFFFFF, 4);
			icon.graphics.lineStyle(0, 0, 0);
			icon.graphics.beginFill(0xFFFFFF, 1);
			if (corner == CORNER_TL)
			{
				icon.graphics.drawRect(inset, inset, mark, mark);
			}
			else if (corner == CORNER_TR)
			{
				icon.graphics.drawRect(BTN - inset - mark, inset, mark, mark);
			}
			else if (corner == CORNER_BL)
			{
				icon.graphics.drawRect(inset, BTN - inset - mark, mark, mark);
			}
			else
			{
				icon.graphics.drawRect(BTN - inset - mark, BTN - inset - mark, mark, mark);
			};
			icon.graphics.endFill();
		}

		private function drawPencilIcon(g:Sprite):void
		{
			LucideIconRenderer.drawEmbeddedSvg(g.graphics, LucideIconRenderer.PAUSE_PENCIL, BTN, 0xFFFFFF, 4);
		}

		private function drawEraserIcon(g:Sprite):void
		{
			LucideIconRenderer.drawEmbeddedSvg(g.graphics, LucideIconRenderer.PAUSE_ERASER, BTN, 0xFFFFFF, 4);
		}

		private function drawHideArtIcon(g:Sprite):void
		{
			LucideIconRenderer.drawEmbeddedSvg(g.graphics, LucideIconRenderer.PAUSE_EYE_OFF, BTN, 0xFFFFFF, 4);
		}

		private function drawEyedropIcon(g:Sprite):void
		{
			LucideIconRenderer.drawEmbeddedSvg(g.graphics, LucideIconRenderer.PAUSE_PIPETTE, BTN, 0xFFFFFF, 4);
		}

		private function layoutToolbar():void
		{
			var xPos:Number = 0;
			nameBtn.x = xPos;
			nameBtn.y = 0;
			xPos += BTN + GAP;

			drawBtn.x = xPos;
			drawBtn.y = 0;
			xPos += BTN + GAP;

			hideArtBtn.x = xPos;
			hideArtBtn.y = 0;
			xPos += BTN + GAP;

			nameTools.visible = nameVisible;
			nameTools.x = xPos;
			nameTools.y = 0;
			if (nameVisible)
			{
				fontBtn.x = 0;
				sizeBtn.x = BTN + GAP;
				cornerBtn.x = (BTN + GAP) * 2;
				nameColorBtn.x = (BTN + GAP) * 3;
				nameEyedropBtn.x = (BTN + GAP) * 4;
				xPos += (BTN + GAP) * 5;
			};

			drawTools.visible = drawMode;
			drawTools.x = xPos;
			drawTools.y = 0;
			if (drawMode)
			{
				drawColorBtn.x = 0;
				drawEyedropBtn.x = BTN + GAP;
				eraseBtn.x = (BTN + GAP) * 2;
				xPos += (BTN + GAP) * 3;
			};

			toolbar.x = 12;
			toolbar.y = stageH - BTN - 14;
			layoutToolHint();
		}

		private function redrawSwatch(fill:Sprite, color:uint):void
		{
			if (!fill)
			{
				return;
			};
			fill.graphics.clear();
			fill.graphics.beginFill(color & 0x00FFFFFF, 1);
			fill.graphics.drawRoundRect(4, 4, 20, 20, 4, 4);
			fill.graphics.endFill();
		}

		private function redrawColorFills():void
		{
			redrawSwatch(nameColorFill, nameColor);
			redrawSwatch(drawColorFill, drawColor);
		}

		public function setNames(costume:String, author:String):void
		{
			costumeName = costume || "";
			authorName = author || "";
			refreshNameField();
		}

		public function showToys():void
		{
			visible = true;
			toolbar.visible = true;
			artHidden = false;
			layoutToolbar();
			refreshToolbarState();
			refreshNameField();
			borrowHudCamera();
			ensureHudCamClickable();
		}

		public function hideToys():void
		{
			hidePicker();
			cancelEyedrop();
			setDrawMode(false);
			eraseMode = false;
			restoreHudCamera();
			if (artHidden)
			{
				artHidden = false;
				if (onToggleHideArt != null)
				{
					onToggleHideArt(false);
				};
			};
			visible = false;
		}

		/** Hide chrome for camera; keep captureLayer. Keep draw mode armed after restore. */
		public function prepareForSnapshot():void
		{
			hidePicker();
			cancelEyedrop();
			toolbar.visible = false;
			if (camChrome)
			{
				camChrome.visible = false;
			};
			unwireDrawListeners();
			drawing = false;
		}

		public function restoreAfterSnapshot():void
		{
			toolbar.visible = true;
			if (camChrome)
			{
				camChrome.visible = true;
			};
			borrowHudCamera();
			if (drawMode)
			{
				wireDrawListeners();
			};
			ensureHudCamClickable();
			refreshToolbarState();
			layoutToolbar();
		}

		private function onToggleName(e:MouseEvent):void
		{
			e.stopPropagation();
			nameVisible = !nameVisible;
			if (!nameVisible && pickerTarget == PICK_NAME)
			{
				hidePicker();
			};
			refreshNameField();
			refreshToolbarState();
			layoutToolbar();
		}

		private function onCycleFont(e:MouseEvent):void
		{
			e.stopPropagation();
			fontIndex = (fontIndex + 1) % FONT_CYCLE.length;
			refreshNameField();
		}

		private function onCycleFontSize(e:MouseEvent):void
		{
			e.stopPropagation();
			fontSizeIndex = (fontSizeIndex + 1) % FONT_SIZES.length;
			refreshSizeIcon();
			refreshNameField();
		}

		private function onCycleCorner(e:MouseEvent):void
		{
			e.stopPropagation();
			corner = (corner + 1) % 4;
			redrawCornerIcon();
			layoutName();
		}

		private function onOpenNameColorPicker(e:MouseEvent):void
		{
			e.stopPropagation();
			cancelEyedrop();
			togglePicker(PICK_NAME, nameColor);
		}

		private function onOpenDrawColorPicker(e:MouseEvent):void
		{
			e.stopPropagation();
			cancelEyedrop();
			togglePicker(PICK_DRAW, drawColor);
		}

		private function onNameEyedrop(e:MouseEvent):void
		{
			e.stopPropagation();
			hidePicker();
			toggleEyedrop(PICK_NAME);
		}

		private function onDrawEyedrop(e:MouseEvent):void
		{
			e.stopPropagation();
			hidePicker();
			toggleEyedrop(PICK_DRAW);
		}

		private function toggleEyedrop(target:String):void
		{
			if (eyedropMode && eyedropTarget == target)
			{
				cancelEyedrop();
				return;
			};
			eyedropMode = true;
			eyedropTarget = target;
			wireEyedropListeners();
			refreshToolbarState();
		}

		private function cancelEyedrop():void
		{
			eyedropMode = false;
			unwireEyedropListeners();
			refreshToolbarState();
		}

		private function wireEyedropListeners():void
		{
			if (eyedropListenersWired || !stage)
			{
				return;
			};
			stage.addEventListener(MouseEvent.CLICK, onEyedropClick, true, 50, false);
			eyedropListenersWired = true;
		}

		private function unwireEyedropListeners():void
		{
			if (!eyedropListenersWired || !stage)
			{
				eyedropListenersWired = false;
				return;
			};
			stage.removeEventListener(MouseEvent.CLICK, onEyedropClick, true);
			eyedropListenersWired = false;
		}

		private function onEyedropClick(e:MouseEvent):void
		{
			var d:DisplayObject;
			var col:uint;
			if (!eyedropMode)
			{
				return;
			};
			d = e.target as DisplayObject;
			while (d)
			{
				if (d == toolbar || d == picker || d == nameEyedropBtn || d == drawEyedropBtn)
				{
					return;
				};
				d = d.parent;
			};
			e.stopImmediatePropagation();
			col = sampleScreenColor(e.stageX, e.stageY);
			if (((col >> 24) & 0xFF) > 0)
			{
				pickerTarget = eyedropTarget;
				applyPickedColor(col);
			};
			cancelEyedrop();
		}

		/** Sample a single stage pixel (hides our chrome so UI buttons don't tint the pick). */
		private function sampleScreenColor(stageX:Number, stageY:Number):uint
		{
			var bd:BitmapData;
			var m:Matrix;
			var col:uint;
			var toolbarWas:Boolean;
			var pickerWas:Boolean;
			var camWas:Boolean;
			toolbarWas = toolbar ? toolbar.visible : false;
			pickerWas = picker ? picker.visible : false;
			camWas = camChrome ? camChrome.visible : false;
			if (toolbar) toolbar.visible = false;
			if (picker) picker.visible = false;
			if (camChrome) camChrome.visible = false;
			bd = new BitmapData(1, 1, true, 0);
			m = new Matrix();
			m.translate(-Math.round(stageX), -Math.round(stageY));
			try
			{
				bd.draw(Ssf2.Main.Root, m, null, null, new Rectangle(0, 0, 1, 1));
				col = bd.getPixel32(0, 0);
			}
			catch (err:Error)
			{
				col = 0;
			};
			bd.dispose();
			if (toolbar) toolbar.visible = toolbarWas;
			if (picker) picker.visible = pickerWas;
			if (camChrome) camChrome.visible = camWas;
			return col;
		}

		private function togglePicker(target:String, startColor:uint):void
		{
			if (picker && picker.visible && pickerTarget == target)
			{
				hidePicker();
				return;
			};
			pickerTarget = target;
			openPicker(startColor);
		}

		private function onToggleDraw(e:MouseEvent):void
		{
			e.stopPropagation();
			setDrawMode(!drawMode);
			layoutToolbar();
		}

		private function onToggleErase(e:MouseEvent):void
		{
			e.stopPropagation();
			eraseMode = !eraseMode;
			refreshToolbarState();
		}

		private function onToggleHideArtClick(e:MouseEvent):void
		{
			e.stopPropagation();
			artHidden = !artHidden;
			refreshToolbarState();
			if (onToggleHideArt != null)
			{
				onToggleHideArt(artHidden);
			};
		}

		private function setDrawMode(active:Boolean):void
		{
			drawMode = active;
			if (!drawMode)
			{
				eraseMode = false;
				drawing = false;
				if (eyedropMode && eyedropTarget == PICK_DRAW)
				{
					cancelEyedrop();
				};
				if (pickerTarget == PICK_DRAW)
				{
					hidePicker();
				};
				unwireDrawListeners();
			}
			else
			{
				ensureDrawSurface();
				borrowHudCamera();
				ensureHudCamClickable();
				wireDrawListeners();
			};
			refreshToolbarState();
			layoutToolbar();
		}

		private function wireDrawListeners():void
		{
			if (drawListenersWired || !stage)
			{
				return;
			};
			// Bubble phase, low priority so HUD/camera handlers run first on the target.
			stage.addEventListener(MouseEvent.MOUSE_DOWN, onDrawDown, false, -100, false);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onDrawMove, false, -100, false);
			stage.addEventListener(MouseEvent.MOUSE_UP, onDrawUp, false, -100, false);
			drawListenersWired = true;
			ensureHudCamClickable();
		}

		private function unwireDrawListeners():void
		{
			if (!drawListenersWired || !stage)
			{
				drawListenersWired = false;
				return;
			};
			stage.removeEventListener(MouseEvent.MOUSE_DOWN, onDrawDown);
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDrawMove);
			stage.removeEventListener(MouseEvent.MOUSE_UP, onDrawUp);
			drawListenersWired = false;
		}

		private function ensureDrawSurface():void
		{
			if (!drawData)
			{
				drawData = new BitmapData(int(stageW), int(stageH), true, 0x00000000);
				drawBitmap = new Bitmap(drawData);
				drawHost.addChild(drawBitmap);
			};
		}

		/** Keep HUD camera listeners alive if FreezeKeys previously killed them. */
		private function ensureHudCamClickable():void
		{
			try
			{
				if (Ssf2.GameController.stageData && Ssf2.GameController.stageData.FreezeKeys)
				{
					Ssf2.GameController.stageData.FreezeKeys = false;
					if (Ssf2.GameController.hud)
					{
						Ssf2.GameController.hud.makeEvents();
					};
				};
			}
			catch (err:Error)
			{
			};
		}

		/** Lift camIcon onto our chrome so it sits above draw interaction and stays clickable. */
		private function borrowHudCamera():void
		{
			var cam:DisplayObject;
			var g:Point;
			var l:Point;
			if (borrowedCam || !camChrome)
			{
				return;
			};
			try
			{
				if (!Ssf2.GameController.hud || !Ssf2.GameController.hud.SubMenu || !Ssf2.GameController.hud.SubMenu.camIcon)
				{
					return;
				};
				cam = Ssf2.GameController.hud.SubMenu.camIcon as DisplayObject;
				if (!cam || !cam.parent)
				{
					return;
				};
				borrowedCam = cam;
				borrowedCamParent = cam.parent as DisplayObjectContainer;
				borrowedCamIndex = borrowedCamParent.getChildIndex(cam);
				borrowedCamX = cam.x;
				borrowedCamY = cam.y;
				g = cam.localToGlobal(new Point(0, 0));
				camChrome.addChild(cam);
				l = camChrome.globalToLocal(g);
				cam.x = l.x;
				cam.y = l.y;
				cam.visible = true;
				if (camChrome.parent)
				{
					camChrome.parent.setChildIndex(camChrome, camChrome.parent.numChildren - 1);
				};
			}
			catch (err:Error)
			{
				borrowedCam = null;
				borrowedCamParent = null;
				borrowedCamIndex = -1;
			};
		}

		private function restoreHudCamera():void
		{
			var idx:int;
			if (!borrowedCam || !borrowedCamParent)
			{
				borrowedCam = null;
				borrowedCamParent = null;
				borrowedCamIndex = -1;
				return;
			};
			try
			{
				idx = borrowedCamIndex;
				if (idx < 0)
				{
					idx = borrowedCamParent.numChildren;
				};
				if (idx > borrowedCamParent.numChildren)
				{
					idx = borrowedCamParent.numChildren;
				};
				borrowedCamParent.addChildAt(borrowedCam, idx);
				borrowedCam.x = borrowedCamX;
				borrowedCam.y = borrowedCamY;
			}
			catch (err:Error)
			{
			};
			borrowedCam = null;
			borrowedCamParent = null;
			borrowedCamIndex = -1;
		}

		private function isOverBorrowedCam(stageX:Number, stageY:Number, target:Object):Boolean
		{
			var d:DisplayObject = target as DisplayObject;
			var cam:DisplayObject = borrowedCam;
			if (!cam && Ssf2.GameController.hud && Ssf2.GameController.hud.SubMenu)
			{
				cam = Ssf2.GameController.hud.SubMenu.camIcon as DisplayObject;
			};
			if (!cam)
			{
				return false;
			};
			while (d)
			{
				if (d == cam || d == camChrome)
				{
					return true;
				};
				if (d.name == "camIcon")
				{
					return true;
				};
				d = d.parent;
			};
			// Bounding-box hit (shapeFlag false) — cam artwork often has transparent pixels.
			try
			{
				if (cam.visible && cam.hitTestPoint(stageX, stageY, false))
				{
					return true;
				};
			}
			catch (err:Error)
			{
			};
			return false;
		}

		/** Skip drawing when pointer is on camera / HUD chrome / our toolbar. */
		private function isPointerOnUiChrome(stageX:Number, stageY:Number, target:Object):Boolean
		{
			var d:DisplayObject = target as DisplayObject;
			var hudMenu:*;
			var hudContainer:DisplayObject;
			if (isOverBorrowedCam(stageX, stageY, target))
			{
				return true;
			};
			while (d)
			{
				if (d == toolbar || d == picker || d == camChrome)
				{
					return true;
				};
				if (d.name == "camIcon" || d.name == "pause_menu")
				{
					return true;
				};
				d = d.parent;
			};
			if (toolbar && toolbar.hitTestPoint(stageX, stageY, true))
			{
				return true;
			};
			if (picker && picker.visible && picker.hitTestPoint(stageX, stageY, true))
			{
				return true;
			};
			try
			{
				hudMenu = Ssf2.GameController.hud;
				if (hudMenu)
				{
					hudContainer = hudMenu.Container as DisplayObject;
					d = target as DisplayObject;
					while (d)
					{
						if (hudContainer && d == hudContainer)
						{
							return true;
						};
						d = d.parent;
					};
					if (hudMenu.SubMenu)
					{
						if (hudMenu.SubMenu.camIcon && hudMenu.SubMenu.camIcon.visible
							&& hudMenu.SubMenu.camIcon.hitTestPoint(stageX, stageY, false))
						{
							return true;
						};
						if (hudMenu.SubMenu.pause_menu && hudMenu.SubMenu.pause_menu.visible
							&& hudMenu.SubMenu.pause_menu.hitTestPoint(stageX, stageY, false))
						{
							return true;
						};
					};
				};
			}
			catch (err:Error)
			{
			};
			return false;
		}

		private function onDrawDown(e:MouseEvent):void
		{
			if (!drawMode || !drawListenersWired || eyedropMode)
			{
				return;
			};
			if (isPointerOnUiChrome(e.stageX, e.stageY, e.target))
			{
				drawing = false;
				return;
			};
			ensureDrawSurface();
			drawing = true;
			lastDrawX = e.stageX;
			lastDrawY = e.stageY;
			stampDot(lastDrawX, lastDrawY);
		}

		private function onDrawMove(e:MouseEvent):void
		{
			if (!drawing || !drawData)
			{
				return;
			};
			strokeLine(lastDrawX, lastDrawY, e.stageX, e.stageY);
			lastDrawX = e.stageX;
			lastDrawY = e.stageY;
		}

		private function onDrawUp(e:MouseEvent):void
		{
			drawing = false;
		}

		private function stampDot(x:Number, y:Number):void
		{
			var ix:int = int(x);
			var iy:int = int(y);
			var r:int = eraseMode ? 6 : 1;
			var dx:int;
			var dy:int;
			var c:uint = eraseMode ? 0x00000000 : (0xFF000000 | (drawColor & 0x00FFFFFF));
			dx = -r;
			while (dx <= r)
			{
				dy = -r;
				while (dy <= r)
				{
					if ((dx * dx + dy * dy) <= (r * r + r))
					{
						if (ix + dx >= 0 && iy + dy >= 0 && ix + dx < drawData.width && iy + dy < drawData.height)
						{
							drawData.setPixel32(ix + dx, iy + dy, c);
						};
					};
					dy++;
				};
				dx++;
			};
		}

		private function strokeLine(x0:Number, y0:Number, x1:Number, y1:Number):void
		{
			var dx:Number = x1 - x0;
			var dy:Number = y1 - y0;
			var steps:int = int(Math.max(Math.abs(dx), Math.abs(dy)));
			var i:int;
			var t:Number;
			if (steps < 1)
			{
				stampDot(x1, y1);
				return;
			};
			i = 0;
			while (i <= steps)
			{
				t = i / steps;
				stampDot(x0 + dx * t, y0 + dy * t);
				i++;
			};
		}

		private function refreshNameField():void
		{
			var lines:Array = [];
			var fontName:String;
			var fmt:TextFormat;
			if (!nameVisible)
			{
				nameField.visible = false;
				return;
			};
			if (costumeName && costumeName.length > 0)
			{
				lines.push(costumeName);
			};
			if (authorName && authorName.length > 0)
			{
				lines.push("by " + authorName);
			};
			if (lines.length == 0)
			{
				lines.push("Custom Costume");
			};
			fontName = String(FONT_CYCLE[fontIndex]);
			fmt = new TextFormat(fontName, int(FONT_SIZES[fontSizeIndex]), nameColor & 0x00FFFFFF, true);
			nameField.defaultTextFormat = fmt;
			nameField.embedFonts = false;
			nameField.text = lines.join("\n");
			nameField.setTextFormat(fmt);
			nameField.visible = true;
			layoutName();
		}

		private function layoutName():void
		{
			var pad:Number = 14;
			if (!nameField.visible)
			{
				return;
			};
			if (corner == CORNER_BR)
			{
				nameField.x = stageW - nameField.width - pad;
				nameField.y = stageH - nameField.height - pad;
			}
			else if (corner == CORNER_BL)
			{
				nameField.x = pad;
				nameField.y = stageH - nameField.height - pad;
			}
			else if (corner == CORNER_TL)
			{
				nameField.x = pad;
				nameField.y = pad;
			}
			else
			{
				nameField.x = stageW - nameField.width - pad;
				nameField.y = pad;
			};
		}

		private function refreshToolbarState():void
		{
			tintBtn(nameBtn, nameVisible);
			tintBtn(drawBtn, drawMode);
			tintBtn(eraseBtn, eraseMode);
			tintBtn(hideArtBtn, artHidden);
			tintBtn(nameEyedropBtn, eyedropMode && eyedropTarget == PICK_NAME);
			tintBtn(drawEyedropBtn, eyedropMode && eyedropTarget == PICK_DRAW);
			redrawCornerIcon();
			refreshSizeIcon();
			redrawColorFills();
		}

		private function tintBtn(btn:Sprite, on:Boolean):void
		{
			var bg:Sprite;
			if (!btn)
			{
				return;
			};
			bg = btn.getChildByName("bg") as Sprite;
			if (bg)
			{
				drawBtnBg(bg, on);
			};
			btn.alpha = on ? 1 : 0.85;
		}

		private function openPicker(startColor:uint):void
		{
			var hsv:Object = HsvWheel.rgbToHsv(startColor);
			wheelHue = hsv.h;
			wheelSat = hsv.s;
			wheelVal = hsv.v;
			if (!picker)
			{
				buildPicker();
			};
			redrawHueStrip();
			redrawSVSquare();
			redrawPreview();
			picker.visible = true;
			picker.x = 12;
			picker.y = Math.max(8, toolbar.y - 210);
			if (stage)
			{
				stage.addEventListener(MouseEvent.MOUSE_UP, onPickerMouseUp);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, onPickerMouseMove);
			};
		}

		private function hidePicker():void
		{
			draggingHue = false;
			draggingSV = false;
			if (picker)
			{
				picker.visible = false;
			};
			if (stage)
			{
				stage.removeEventListener(MouseEvent.MOUSE_UP, onPickerMouseUp);
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onPickerMouseMove);
			};
		}

		private function buildPicker():void
		{
			var box:Sprite;
			var title:TextField;
			var okBtn:Sprite;
			var cancelBtn:Sprite;
			picker = new Sprite();
			box = new Sprite();
			box.graphics.beginFill(0x1A1A22, 0.97);
			box.graphics.lineStyle(1, 0x888899, 1);
			box.graphics.drawRoundRect(0, 0, 200, 200, 8, 8);
			box.graphics.endFill();
			picker.addChild(box);

			title = new TextField();
			title.defaultTextFormat = new TextFormat("_sans", 11, 0xFFFFFF, true);
			title.autoSize = TextFieldAutoSize.LEFT;
			title.selectable = false;
			title.mouseEnabled = false;
			title.text = "Pick color";
			title.x = 10;
			title.y = 6;
			box.addChild(title);

			hueStrip = new Bitmap(new BitmapData(16, 120, false, 0));
			hueHit = new Sprite();
			hueHit.x = 12;
			hueHit.y = 28;
			hueHit.addChild(hueStrip);
			hueHit.graphics.beginFill(0, 0);
			hueHit.graphics.drawRect(0, 0, 16, 120);
			hueHit.graphics.endFill();
			hueHit.buttonMode = true;
			box.addChild(hueHit);
			hueHit.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):void {
				draggingHue = true;
				sampleHue(e.localY);
			});

			svSquare = new Bitmap(new BitmapData(120, 120, false, 0));
			svHit = new Sprite();
			svHit.x = 36;
			svHit.y = 28;
			svHit.addChild(svSquare);
			svHit.graphics.beginFill(0, 0);
			svHit.graphics.drawRect(0, 0, 120, 120);
			svHit.graphics.endFill();
			svHit.buttonMode = true;
			box.addChild(svHit);
			svHit.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):void {
				draggingSV = true;
				sampleSV(e.localX, e.localY);
			});

			previewBox = new Sprite();
			previewBox.x = 12;
			previewBox.y = 156;
			box.addChild(previewBox);

			okBtn = makeTextChip("OK", 50, 20);
			okBtn.x = 90;
			okBtn.y = 168;
			okBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				applyPickedColor(HsvWheel.hsvToRgb(wheelHue, wheelSat, wheelVal, 0xFF));
				hidePicker();
			});
			box.addChild(okBtn);

			cancelBtn = makeTextChip("Cancel", 50, 20);
			cancelBtn.x = 144;
			cancelBtn.y = 168;
			cancelBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
				hidePicker();
			});
			box.addChild(cancelBtn);

			picker.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):void {
				e.stopPropagation();
			});
			addChild(picker);
			picker.visible = false;
		}

		private function makeTextChip(label:String, w:Number, h:Number):Sprite
		{
			var s:Sprite = new Sprite();
			var tf:TextField;
			s.graphics.beginFill(0x2A2A35, 1);
			s.graphics.lineStyle(1, 0x666677, 1);
			s.graphics.drawRoundRect(0, 0, w, h, 4, 4);
			s.graphics.endFill();
			tf = new TextField();
			tf.defaultTextFormat = new TextFormat("_sans", 10, 0xFFFFFF);
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.text = label;
			tf.x = 10;
			tf.y = 2;
			s.addChild(tf);
			s.buttonMode = true;
			s.useHandCursor = true;
			return s;
		}

		private function applyPickedColor(col:uint):void
		{
			if (pickerTarget == PICK_DRAW)
			{
				drawColor = col;
			}
			else
			{
				nameColor = col;
				refreshNameField();
			};
			redrawColorFills();
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
			previewBox.graphics.drawRoundRect(0, 0, 36, 18, 3, 3);
			previewBox.graphics.endFill();
		}

		private function sampleHue(localY:Number):void
		{
			wheelHue = HsvWheel.hueAt(localY, 120);
			redrawSVSquare();
			redrawPreview();
		}

		private function sampleSV(localX:Number, localY:Number):void
		{
			wheelSat = HsvWheel.satAt(localX, 120);
			wheelVal = HsvWheel.valAt(localY, 120);
			redrawPreview();
		}

		private function onPickerMouseUp(e:MouseEvent):void
		{
			draggingHue = false;
			draggingSV = false;
		}

		private function onPickerMouseMove(e:MouseEvent):void
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

		public function destroy():void
		{
			hidePicker();
			cancelEyedrop();
			unwireDrawListeners();
			drawMode = false;
			restoreHudCamera();
			if (artHidden && onToggleHideArt != null)
			{
				onToggleHideArt(false);
			};
			artHidden = false;
			if (drawData)
			{
				drawData.dispose();
				drawData = null;
			};
		}
	}
}
