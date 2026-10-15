package com.sbxmod.paletteMaker
{
    import flash.display.Sprite;
    import flash.display.DisplayObject;
    import flash.display.Stage;
    import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFieldAutoSize;

	public class ColorSquare extends Sprite 
    {
		public static var selectedBoxes:Array = [];
		public static var onSelectionChanged:Function = null;
		/** Swatch hover: (box) on enter, (null) on leave. Does not change selection. */
		public static var onHoverChanged:Function = null;
		/** Optional gate: return false to ignore swatch click/drag selection. */
		public static var canInteract:Function = null;
		public static var primaryPickMode:Boolean = false;
		public static var canPrimaryPick:Function = null;
		public static var onPrimaryPick:Function = null;
		public static var onPrimaryPickCancel:Function = null;
		
		private static var bulkClearing:Boolean = false;
		private static var isDragging:Boolean = false;
		/** True only after the pointer moves past the click slop — avoids wiping multi-select on a click. */
		private static var dragPaintActive:Boolean = false;
		private static var dragActionSelect:Boolean = true;
		private static var dragStartX:Number = 0;
		private static var dragStartY:Number = 0;
		private static const DRAG_SLOP:Number = 4;
		private static var stageUpListening:Boolean = false;

		public var colorValue:*;
		private var faceSprite:Sprite;
		private var triangle:Sprite;
		private var borderSprite:Sprite;
		private var unchangedHighlight:Sprite;
		private var magHoverHighlight:Sprite;
		private var primaryBadge:TextField;
		private var ownerBadge:TextField;
		private var priorityBang:TextField;
		private var hitPlate:Sprite;
		private var index:int;
		private var m_boxSize:Number;
		private var m_isSelected:Boolean = false;
		private var m_unchangedHighlight:Boolean = false;
		private var m_magHoverHighlight:Boolean = false;
		private var m_paletteHoverHighlight:Boolean = false;
		private var m_priorityBang:Boolean = false;
		
		private var cornerRadius:Number = 5;

		public function ColorSquare(color:uint, boxSize:Number, index:int) 
		{
			colorValue = color;
			m_boxSize = boxSize;
			this.index = index;
			// Opaque invisible hit target — fully transparent fills are not mouse-hittable in Flash.
			hitPlate = new Sprite();
			hitPlate.graphics.beginFill(0xFFFFFF, 1);
			hitPlate.graphics.drawRoundRect(0, 0, boxSize, boxSize, cornerRadius, cornerRadius);
			hitPlate.graphics.endFill();
			hitPlate.alpha = 0;
			hitPlate.mouseEnabled = true;
			addChild(hitPlate);
			hitArea = hitPlate;
			faceSprite = new Sprite();
			faceSprite.mouseEnabled = false;
			faceSprite.mouseChildren = false;
			addChild(faceSprite);
			drawFace(uint(color));
			buttonMode = true;
			useHandCursor = true;
			mouseChildren = true;
			borderSprite = new Sprite();
			borderSprite.mouseEnabled = false;
			addChild(borderSprite);
			unchangedHighlight = new Sprite();
			unchangedHighlight.mouseEnabled = false;
			addChild(unchangedHighlight);
			magHoverHighlight = new Sprite();
			magHoverHighlight.mouseEnabled = false;
			addChild(magHoverHighlight);
			triangle = new Sprite();
			triangle.mouseEnabled = false;
			addChild(triangle);
			primaryBadge = new TextField();
			primaryBadge.defaultTextFormat = new TextFormat("_sans", 8, 0xFFFFFF, true, null, null, null, null, "center");
			primaryBadge.autoSize = TextFieldAutoSize.CENTER;
			primaryBadge.text = "P";
			primaryBadge.mouseEnabled = false;
			primaryBadge.selectable = false;
			primaryBadge.visible = false;
			primaryBadge.x = (boxSize - primaryBadge.width) * 0.5;
			primaryBadge.y = -1;
			addChild(primaryBadge);
			ownerBadge = new TextField();
			ownerBadge.defaultTextFormat = new TextFormat("_sans", 7, 0xFFFFFF, true, null, null, null, null, "left");
			ownerBadge.autoSize = TextFieldAutoSize.LEFT;
			ownerBadge.text = "";
			ownerBadge.mouseEnabled = false;
			ownerBadge.selectable = false;
			ownerBadge.visible = false;
			ownerBadge.x = 1;
			ownerBadge.y = boxSize - 11;
			addChild(ownerBadge);
			priorityBang = new TextField();
			priorityBang.defaultTextFormat = new TextFormat("_sans", 9, 0xFF3333, true, null, null, null, null, "center");
			priorityBang.autoSize = TextFieldAutoSize.CENTER;
			priorityBang.text = "!";
			priorityBang.mouseEnabled = false;
			priorityBang.selectable = false;
			priorityBang.visible = false;
			priorityBang.x = boxSize - priorityBang.width - 1;
			priorityBang.y = -2;
			addChild(priorityBang);
			makeEvents();
		}

		/** Base swatch face: checker under alpha colors so transparent keys stay visible + clickable. */
		private function drawFace(color:uint):void
		{
			var aByte:uint;
			var a:Number;
			var cell:Number;
			var x:int;
			var y:int;
			var light:Boolean;
			if (!faceSprite)
			{
				return;
			};
			faceSprite.graphics.clear();
			aByte = (color >>> 24) & 0xFF;
			a = aByte / 255.0;
			// Solid backing so empty/transparent isn't a dead click zone visually either.
			faceSprite.graphics.beginFill(0x2A2A33, 1);
			faceSprite.graphics.drawRoundRect(0, 0, m_boxSize, m_boxSize, cornerRadius, cornerRadius);
			faceSprite.graphics.endFill();
			if (aByte < 255)
			{
				cell = Math.max(3, m_boxSize / 4);
				y = 0;
				while (y < m_boxSize)
				{
					x = 0;
					while (x < m_boxSize)
					{
						light = (((int(x / cell) + int(y / cell)) & 1) == 0);
						faceSprite.graphics.beginFill(light ? 0xC8C8D0 : 0x787888, 1);
						faceSprite.graphics.drawRect(x, y, Math.min(cell, m_boxSize - x), Math.min(cell, m_boxSize - y));
						faceSprite.graphics.endFill();
						x += cell;
					};
					y += cell;
				};
			};
			faceSprite.graphics.beginFill(color & 0x00FFFFFF, a);
			faceSprite.graphics.drawRoundRect(0, 0, m_boxSize, m_boxSize, cornerRadius, cornerRadius);
			faceSprite.graphics.endFill();
		}
	
		public function selectBox_DOWN(e:MouseEvent):void
		{
			if (primaryPickMode)
			{
				if (canPrimaryPick != null && !canPrimaryPick(this))
				{
					if (onPrimaryPickCancel != null)
					{
						onPrimaryPickCancel();
					};
					return;
				};
				if (onPrimaryPick != null)
				{
					onPrimaryPick(this);
				};
				return;
			};
			if (canInteract != null && !canInteract())
			{
				return;
			};
			dragActionSelect = !m_isSelected;
			setSelected(dragActionSelect);
			isDragging = true;
			dragPaintActive = false;
			dragStartX = e.stageX;
			dragStartY = e.stageY;
			listenStageMouseUp(this.stage);
		}

		public function setPrimaryBadge(visible:Boolean):void
		{
			if (!primaryBadge)
			{
				return;
			};
			primaryBadge.visible = visible;
			if (visible)
			{
				setChildIndex(primaryBadge, numChildren - 1);
			};
		}

		/** Owner group short name (e.g. GA/GB); empty hides. */
		public function setOwnerBadge(label:String):void
		{
			if (!ownerBadge)
			{
				return;
			};
			if (label && label.length > 0)
			{
				ownerBadge.text = label;
				ownerBadge.visible = true;
				ownerBadge.x = 1;
				ownerBadge.y = m_boxSize - 11;
				setChildIndex(ownerBadge, numChildren - 1);
			}
			else
			{
				ownerBadge.text = "";
				ownerBadge.visible = false;
			};
		}

		private function selectBox_OVER(e:MouseEvent):void 
		{
			if (!isDragging)
			{
				notifyHoverChanged(this);
				return;
			};
			if (canInteract != null && !canInteract())
			{
				endDragSelect();
				return;
			};
			if (!dragPaintActive)
			{
				if (Math.abs(e.stageX - dragStartX) < DRAG_SLOP
					&& Math.abs(e.stageY - dragStartY) < DRAG_SLOP)
				{
					return;
				};
				dragPaintActive = true;
			};
			setSelected(dragActionSelect);
		}

		private function selectBox_UP(e:MouseEvent):void 
		{
			endDragSelect();
		}

		private function selectBox_OUT(e:MouseEvent):void
		{
			var rel:DisplayObject;
			if (isDragging)
			{
				return;
			};
			rel = e.relatedObject as DisplayObject;
			while (rel)
			{
				if (rel is ColorSquare)
				{
					return;
				};
				rel = rel.parent;
			};
			notifyHoverChanged(null);
		}

		private static function notifyHoverChanged(box:ColorSquare):void
		{
			if (onHoverChanged != null)
			{
				onHoverChanged(box);
			};
		}

		private static var dragStage:Stage = null;

		private static function listenStageMouseUp(st:Stage):void
		{
			if (stageUpListening)
			{
				return;
			};
			if (!st)
			{
				return;
			};
			dragStage = st;
			stageUpListening = true;
			st.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp, true, 0, true);
			st.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp, false, 0, true);
		}

		private static function onStageMouseUp(e:MouseEvent):void
		{
			endDragSelect();
		}

		private static function endDragSelect():void
		{
			isDragging = false;
			dragPaintActive = false;
			if (!stageUpListening)
			{
				return;
			};
			stageUpListening = false;
			if (dragStage)
			{
				dragStage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp, true);
				dragStage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp, false);
				dragStage = null;
			};
		}
	
		private function makeEvents():void
		{
			addEventListener(MouseEvent.MOUSE_DOWN, selectBox_DOWN);
			addEventListener(MouseEvent.MOUSE_OVER, selectBox_OVER);
			addEventListener(MouseEvent.MOUSE_OUT, selectBox_OUT);
			addEventListener(MouseEvent.MOUSE_UP, selectBox_UP);
		}
	
		public function killEvents():void
		{
			removeEventListener(MouseEvent.MOUSE_DOWN, selectBox_DOWN);
			removeEventListener(MouseEvent.MOUSE_OVER, selectBox_OVER);
			removeEventListener(MouseEvent.MOUSE_OUT, selectBox_OUT);
			removeEventListener(MouseEvent.MOUSE_UP, selectBox_UP);
		}

		public function setSelected(e:Boolean):void
		{
			m_isSelected = e;
			drawSelectionBorder();
			// Always keep selectedBoxes in sync — bulk mode only suppresses the notify.
			syncSelectionMembership();
			if (!bulkClearing)
			{
				notifySelectionChanged();
			};
		}
	
		public function updateIndicator(newColor:uint):void
		{
			drawTriangle(newColor);
		}

		public static function deselectAll():void 
		{
			var snapshot:Array;
			var box:ColorSquare;
			// Copy first — setSelected(false) mutates selectedBoxes while iterating.
			snapshot = selectedBoxes.concat();
			bulkClearing = true;
			for each (box in snapshot)
			{
				if (box)
				{
					box.setSelected(false);
				};
			};
			bulkClearing = false;
			selectedBoxes.length = 0;
			notifySelectionChanged();
		}

		public static function get isDragSelecting():Boolean
		{
			return isDragging;
		}

		public static function beginBulkUpdate():void
		{
			bulkClearing = true;
		}

		public static function endBulkUpdate():void
		{
			bulkClearing = false;
			notifySelectionChanged();
		}

		public function get isSelected():Boolean
		{
			return m_isSelected;
		}

		private function syncSelectionMembership():void
		{
			var i:int;
			if (m_isSelected)
			{
				if (selectedBoxes.indexOf(this) == -1)
				{
					selectedBoxes.push(this);
				};
			}
			else
			{
				i = selectedBoxes.indexOf(this);
				if (i != -1)
				{
					selectedBoxes.splice(i, 1);
				};
			};
		}

		private static function notifySelectionChanged():void
		{
			if (onSelectionChanged != null)
			{
				onSelectionChanged();
			};
		}
	
		public function setUnchangedHighlight(on:Boolean):void
		{
			if (m_unchangedHighlight == on)
			{
				return;
			};
			m_unchangedHighlight = on;
			drawUnchangedHighlight();
		}


		/** Magnifier hover: cyan ring matching the probed palette color. */
		public function setMagHoverHighlight(on:Boolean):void
		{
			if (m_magHoverHighlight == on)
			{
				return;
			};
			m_magHoverHighlight = on;
			drawMagHoverHighlight();
		}

		/** Palette-swatch hover: orange ring (cyan wins if magnifier is also on). */
		public function setPaletteHoverHighlight(on:Boolean):void
		{
			if (m_paletteHoverHighlight == on)
			{
				return;
			};
			m_paletteHoverHighlight = on;
			drawMagHoverHighlight();
		}

		/** Red ! when active group claims a base owned by an earlier enabled group. */
		public function setPriorityBang(on:Boolean):void
		{
			if (m_priorityBang == on)
			{
				return;
			};
			m_priorityBang = on;
			if (priorityBang)
			{
				priorityBang.visible = m_priorityBang;
				if (m_priorityBang)
				{
					setChildIndex(priorityBang, numChildren - 1);
				};
			};
		}

		private function drawUnchangedHighlight():void
		{
			if (!unchangedHighlight)
			{
				return;
			};
			unchangedHighlight.graphics.clear();
			if (m_unchangedHighlight)
			{
				unchangedHighlight.graphics.lineStyle(1, 0xFFDD00, 1);
				unchangedHighlight.graphics.drawRoundRect(-0.5, -0.5, m_boxSize + 1, m_boxSize + 1, cornerRadius, cornerRadius);
			};
			restackOverlays();
		}


		private function drawMagHoverHighlight():void
		{
			if (!magHoverHighlight)
			{
				return;
			};
			magHoverHighlight.graphics.clear();
			if (m_magHoverHighlight)
			{
				magHoverHighlight.graphics.lineStyle(2, 0x00E5FF, 1);
				magHoverHighlight.graphics.drawRoundRect(-1.5, -1.5, m_boxSize + 3, m_boxSize + 3, cornerRadius, cornerRadius);
			}
			else if (m_paletteHoverHighlight)
			{
				magHoverHighlight.graphics.lineStyle(2, 0xFFAA00, 1);
				magHoverHighlight.graphics.drawRoundRect(-1.5, -1.5, m_boxSize + 3, m_boxSize + 3, cornerRadius, cornerRadius);
			};
			restackOverlays();
		}

		private function restackOverlays():void
		{
			if (unchangedHighlight)
			{
				setChildIndex(unchangedHighlight, numChildren - 1);
			};
			if (magHoverHighlight)
			{
				setChildIndex(magHoverHighlight, numChildren - 1);
			};
			if (borderSprite)
			{
				setChildIndex(borderSprite, numChildren - 1);
			};
			if (ownerBadge && ownerBadge.visible)
			{
				setChildIndex(ownerBadge, numChildren - 1);
			};
			if (primaryBadge && primaryBadge.visible)
			{
				setChildIndex(primaryBadge, numChildren - 1);
			};
			if (priorityBang && priorityBang.visible)
			{
				setChildIndex(priorityBang, numChildren - 1);
			};
		}

		private function drawSelectionBorder():void
		{
			borderSprite.graphics.clear();
			if (m_isSelected)
			{
				borderSprite.graphics.lineStyle(1.5, 0xFFFFFF, 0.9);
				borderSprite.graphics.drawRoundRect(0, 0, m_boxSize, m_boxSize, cornerRadius, cornerRadius);
			};
			setChildIndex(borderSprite, numChildren - 1);
			if (unchangedHighlight)
			{
				setChildIndex(unchangedHighlight, numChildren - 1);
			};
			if (primaryBadge && primaryBadge.visible)
			{
				setChildIndex(primaryBadge, numChildren - 1);
			};
		}
	
		public function drawTriangle(color:*):void 
		{
			var c:uint;
			var aByte:uint;
			var a:Number;
			var halfHeight:Number;
			c = uint(color);
			aByte = (c >>> 24) & 0xFF;
			a = aByte / 255.0;
			triangle.graphics.clear();
			halfHeight = m_boxSize / 2;
			if (aByte < 255)
			{
				// Checker on the replacement half so transparent replacements stay readable.
				triangle.graphics.beginFill(0xC8C8D0, 1);
				triangle.graphics.drawRect(0, halfHeight, m_boxSize * 0.5, halfHeight * 0.5);
				triangle.graphics.beginFill(0x787888, 1);
				triangle.graphics.drawRect(m_boxSize * 0.5, halfHeight, m_boxSize * 0.5, halfHeight * 0.5);
				triangle.graphics.beginFill(0x787888, 1);
				triangle.graphics.drawRect(0, halfHeight + halfHeight * 0.5, m_boxSize * 0.5, halfHeight * 0.5);
				triangle.graphics.beginFill(0xC8C8D0, 1);
				triangle.graphics.drawRect(m_boxSize * 0.5, halfHeight + halfHeight * 0.5, m_boxSize * 0.5, halfHeight * 0.5);
			};
			triangle.graphics.beginFill(c & 0x00FFFFFF, a);
			triangle.graphics.drawRoundRect(0, halfHeight, m_boxSize, halfHeight, cornerRadius, cornerRadius);
			triangle.graphics.endFill();
			try
			{
				setChildIndex(triangle, Math.max(0, numChildren - 2));
			}
			catch (err:Error)
			{
			};
		}
	}

}
