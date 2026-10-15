package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.getQualifiedClassName;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Jukebox entry buttons on Options > Sounds and Stage Select (plus the SSS hand cursor save/restore).
	 */
	public class MusicModButtons
	{
		private var mod:MusicPlayerMod;
		private var m_soundsBtn:Sprite;
		private var m_sssBtn:Sprite;
		private var m_sssHandX:Number;
		private var m_sssHandY:Number;

		public function MusicModButtons(owner:MusicPlayerMod)
		{
			mod = owner;
			m_soundsBtn = null;
			m_sssBtn = null;
			m_sssHandX = 0;
			m_sssHandY = 0;
		}

		/** Temporary entry on Sounds (Options > Sounds) bottom-left. */
		internal function attachSoundsButton(menu:*):void
		{
			var sub:*;
			var size:Object;
			detachSoundsButton();
			mod.m_soundsMenu = menu;
			sub = resolveSubMenu(menu);
			if (!sub)
			{
				return;
			};
			size = gameSize();
			m_soundsBtn = makeJukeboxButton();
			m_soundsBtn.x = -size.w * 0.5 + 18;
			m_soundsBtn.y = size.h * 0.5 - 36;
			m_soundsBtn.addEventListener(MouseEvent.CLICK, onSoundsJukeboxClick);
			try
			{
				sub.addChild(m_soundsBtn);
			}
			catch (addErr:*)
			{
				m_soundsBtn = null;
			};
		}

		internal function detachSoundsButton():void
		{
			if (m_soundsBtn)
			{
				try
				{
					m_soundsBtn.removeEventListener(MouseEvent.CLICK, onSoundsJukeboxClick);
					if (m_soundsBtn.parent)
					{
						m_soundsBtn.parent.removeChild(m_soundsBtn);
					};
				}
				catch (err:*)
				{
				};
			};
			m_soundsBtn = null;
			mod.m_soundsMenu = null;
		}

		private function onSoundsJukeboxClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.openDeepLink(null, false, true);
		}

		/** Stage Select bottom-right — opens jukebox in match-pick mode (picked song plays in match). */
		internal function attachSssButton(menu:*):void
		{
			var sub:*;
			var size:Object;
			detachSssButton();
			mod.m_sssMenu = menu;
			sub = resolveSubMenu(menu);
			if (!sub)
			{
				return;
			};
			size = gameSize();
			m_sssBtn = makeJukeboxButton();
			m_sssBtn.x = size.w * 0.5 - 118 - 18;
			m_sssBtn.y = size.h * 0.5 - 36;
			m_sssBtn.addEventListener(MouseEvent.CLICK, onSssJukeboxClick);
			m_sssBtn.addEventListener(MouseEvent.MOUSE_OVER, onSssJukeboxOver);
			m_sssBtn.addEventListener(MouseEvent.MOUSE_OUT, onSssJukeboxOut);
			try
			{
				sub.addChild(m_sssBtn);
			}
			catch (addErr:*)
			{
				m_sssBtn = null;
			};
			hookSssHandButton();
		}

		internal function detachSssButton():void
		{
			if (m_sssBtn)
			{
				try
				{
					unhookSssHandButton();
					m_sssBtn.removeEventListener(MouseEvent.CLICK, onSssJukeboxClick);
					m_sssBtn.removeEventListener(MouseEvent.MOUSE_OVER, onSssJukeboxOver);
					m_sssBtn.removeEventListener(MouseEvent.MOUSE_OUT, onSssJukeboxOut);
					if (m_sssBtn.parent)
					{
						m_sssBtn.parent.removeChild(m_sssBtn);
					};
				}
				catch (err:*)
				{
				};
			};
			m_sssBtn = null;
			mod.m_sssMenu = null;
		}

		private function onSssJukeboxClick(e:MouseEvent):void
		{
			e.stopPropagation();
			saveStageSelectHand();
			mod.openDeepLink(mod.m_match.currentStageId(), true, false);
		}

		private function onSssJukeboxOver(e:MouseEvent):void
		{
			if (m_sssBtn)
			{
				m_sssBtn.alpha = 0.85;
			};
		}

		private function onSssJukeboxOut(e:MouseEvent):void
		{
			if (m_sssBtn)
			{
				m_sssBtn.alpha = 1;
			};
		}

		private function hookSssHandButton():void
		{
			var hand:*;
			if (!m_sssBtn || !mod.m_sssMenu)
			{
				return;
			};
			try
			{
				hand = mod.m_sssMenu["selectHand"];
				if (hand && hand["addClickEventClipCheckBounds"])
				{
					hand["addClickEventClipCheckBounds"](m_sssBtn);
				};
			}
			catch (err:*)
			{
			};
		}

		private function unhookSssHandButton():void
		{
			var hand:*;
			if (!m_sssBtn || !mod.m_sssMenu)
			{
				return;
			};
			try
			{
				hand = mod.m_sssMenu["selectHand"];
				if (hand && hand["removeClickEventClipCheckBounds"])
				{
					hand["removeClickEventClipCheckBounds"](m_sssBtn);
				};
			}
			catch (err:*)
			{
			};
		}

		internal function saveStageSelectHand():void
		{
			var hand:MovieClip;
			mod.m_sssHandSaved = false;
			hand = findStageSelectHand();
			if (!hand)
			{
				return;
			};
			m_sssHandX = hand.x;
			m_sssHandY = hand.y;
			mod.m_sssHandSaved = true;
		}

		internal function restoreStageSelectHand():void
		{
			var hand:MovieClip;
			if (!mod.m_sssHandSaved)
			{
				return;
			};
			hand = findStageSelectHand();
			if (!hand)
			{
				return;
			};
			hand.x = m_sssHandX;
			hand.y = m_sssHandY;
			hand.visible = true;
		}

		private function findStageSelectHand():MovieClip
		{
			var MC:*;
			var menu:*;
			var sh:*;
			var sub:*;
			var i:int;
			var c:DisplayObject;
			var qn:String;
			try
			{
				MC = EngineRefs.ssf2("controllers.MenuController");
				menu = MC ? MC["stageSelectMenu"] : null;
				if (!menu)
				{
					return (null);
				};
				sh = menu["selectHand"];
				if (sh && sh["Hand"])
				{
					return (sh["Hand"] as MovieClip);
				};
				sub = resolveSubMenu(menu) as DisplayObjectContainer;
				if (!sub)
				{
					return (null);
				};
				i = 0;
				while (i < sub.numChildren)
				{
					c = sub.getChildAt(i);
					i++;
					if (!(c is MovieClip))
					{
						continue;
					};
					qn = getQualifiedClassName(c).toLowerCase();
					if (qn.indexOf("stageselect_hand") >= 0
						|| (qn.indexOf("hand") >= 0 && qn.indexOf("stage") >= 0))
					{
						return (c as MovieClip);
					};
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private function makeJukeboxButton():Sprite
		{
			var btn:Sprite;
			var tf:TextField;
			btn = new Sprite();
			btn.graphics.beginFill(0xE8A020, 1);
			btn.graphics.drawRoundRect(0, 0, 118, 28, 6, 6);
			btn.graphics.endFill();
			tf = new TextField();
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", 12, 0x111118, true);
			tf.text = "My Jukebox";
			tf.x = 14;
			tf.y = 5;
			btn.addChild(tf);
			btn.buttonMode = true;
			btn.useHandCursor = true;
			return (btn);
		}

		private function resolveSubMenu(menu:*):*
		{
			var sub:*;
			try
			{
				sub = menu["SubMenu"] || menu["m_subMenu"] || menu["subMenu"];
			}
			catch (err:*)
			{
				sub = null;
			};
			return (sub);
		}

		private function gameSize():Object
		{
			var MainCls:*;
			var gw:Number;
			var gh:Number;
			gw = 853;
			gh = 480;
			try
			{
				MainCls = EngineRefs.ssf2("Main");
				if (MainCls)
				{
					gw = Number(MainCls["Width"] || gw);
					gh = Number(MainCls["Height"] || gh);
				};
			}
			catch (mainErr:*)
			{
			};
			return ({"w": gw, "h": gh});
		}
	}
}
