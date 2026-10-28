package com.sbxmod.paletteMaker
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;

	public class PaletteToolSquare extends Sprite
	{
		public var toolId:String;

		private var m_boxSize:Number;
		private var m_onClick:Function;
		private var m_onHover:Function;
		private var m_onHoverOut:Function;
		private var m_icon:Sprite;

		public function PaletteToolSquare(toolId:String, boxSize:Number, onClick:Function, onHover:Function = null, onHoverOut:Function = null)
		{
			this.toolId = toolId;
			m_boxSize = boxSize;
			m_onClick = onClick;
			m_onHover = onHover;
			m_onHoverOut = onHoverOut;
			graphics.clear();
			graphics.beginFill(0x000000, 1);
			graphics.drawRoundRect(0, 0, boxSize, boxSize, 5, 5);
			graphics.endFill();
			m_icon = new Sprite();
			m_icon.mouseEnabled = false;
			m_icon.mouseChildren = false;
			addChild(m_icon);
			drawToolIcon();
			buttonMode = true;
			useHandCursor = true;
			addEventListener(MouseEvent.CLICK, handleClick);
			addEventListener(MouseEvent.MOUSE_OVER, handleOver);
			addEventListener(MouseEvent.MOUSE_OUT, handleOut);
		}

		private function drawToolIcon():void
		{
			LucideIconRenderer.drawToolIcon(m_icon.graphics, toolId, m_boxSize, 0xFFFFFF);
		}

		private function handleClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (m_onClick != null)
			{
				m_onClick(toolId);
			};
		}

		private function handleOver(e:MouseEvent):void
		{
			if (m_onHover != null)
			{
				m_onHover(toolId);
			};
		}

		private function handleOut(e:MouseEvent):void
		{
			if (m_onHoverOut != null)
			{
				m_onHoverOut(toolId);
			};
		}

		public function setActive(on:Boolean):void
		{
			graphics.clear();
			graphics.beginFill(on ? 0x3A5A8C : 0x000000, 1);
			graphics.drawRoundRect(0, 0, m_boxSize, m_boxSize, 5, 5);
			graphics.endFill();
		}

		public function killEvents():void
		{
			removeEventListener(MouseEvent.CLICK, handleClick);
			removeEventListener(MouseEvent.MOUSE_OVER, handleOver);
			removeEventListener(MouseEvent.MOUSE_OUT, handleOut);
		}
	}
}
