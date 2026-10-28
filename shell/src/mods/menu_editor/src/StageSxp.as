package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.getQualifiedClassName;

	import ssf2mm.shared.EngineRefs;

	/**
	 * The sxp page button on Stage Select: finds and unwraps the engine clip, places it by the
	 * grid, and cycles the live page from mouse, keyboard, or gamepad select.
	 */
	public class StageSxp
	{
		private static const SXP_X:Number = 268;
		private static const SXP_Y:Number = -152;

		private var mod:StageEditorMod;
		private var m_sxpHooked:Boolean;
		private var m_sxpInputHooked:Boolean;
		private var m_sxpHandQN:String;
		private var m_sxpPads:Array;

		public function StageSxp(owner:StageEditorMod)
		{
			mod = owner;
			m_sxpHooked = false;
			m_sxpInputHooked = false;
			m_sxpHandQN = null;
			m_sxpPads = [];
		}

		internal function resolveSxpClip(menu:*):MovieClip
		{
			var host:DisplayObjectContainer;
			var clip:DisplayObject;
			var sxp:MovieClip;
			sxp = null;
			try
			{
				if (menu && menu.SubMenu)
				{
					sxp = menu.SubMenu.sxp as MovieClip;
				};
			}
			catch (err:*)
			{
				sxp = null;
			};
			if (sxp)
			{
				return (sxp);
			};
			if (mod.m_sxpClip && mod.m_sxpClip.parent)
			{
				return (mod.m_sxpClip);
			};
			host = mod.m_layout.resolveSubMenu(menu) as DisplayObjectContainer;
			clip = findNamedClip(host, "sxp");
			return (clip as MovieClip);
		}

		internal function findNamedClip(host:DisplayObjectContainer, nm:String):DisplayObject
		{
			var i:int;
			var child:DisplayObject;
			var nested:DisplayObject;
			if (!host || !nm)
			{
				return (null);
			};
			child = host.getChildByName(nm);
			if (child)
			{
				return (child);
			};
			i = 0;
			while (i < host.numChildren)
			{
				child = host.getChildAt(i);
				if (child is DisplayObjectContainer)
				{
					nested = findNamedClip(child as DisplayObjectContainer, nm);
					if (nested)
					{
						return (nested);
					};
				};
				i++;
			};
			return (null);
		}

		private function unwrapSxp(host:MovieClip, sxp:MovieClip):void
		{
			if (!sxp)
			{
				return;
			};
			if (mod.m_sxpWrap && sxp.parent == mod.m_sxpWrap)
			{
				sxp.x += mod.m_sxpWrap.x;
				sxp.y += mod.m_sxpWrap.y;
				if (host)
				{
					host.addChild(sxp);
				};
			};
			if (mod.m_sxpWrap)
			{
				if (mod.m_sxpWrap.parent)
				{
					mod.m_sxpWrap.parent.removeChild(mod.m_sxpWrap);
				};
				mod.m_sxpWrap = null;
			};
		}

		internal function showSxp(menu:*, sxp:MovieClip, pos:Object, size:Object, maxCols:int):void
		{
			var host:MovieClip;
			var art:MovieClip;
			host = mod.m_layout.resolveSubMenu(menu) as MovieClip;
			if (!sxp)
			{
				sxp = resolveSxpClip(menu);
			};
			if (!host)
			{
				return;
			};
			if (sxp)
			{
				unwrapSxp(host, sxp);
				mod.m_sxpClip = sxp;
				sxp.visible = true;
				sxp.alpha = 1;
				sxp.mouseEnabled = true;
				sxp.mouseChildren = false;
				sxp.x = SXP_X;
				sxp.y = sxpTopY(host);
				host.addChild(sxp);
				if (mod.m_xpBtn)
				{
					mod.m_xpBtn.visible = false;
				};
				mod.m_layout.hookSssHandClip(sxp);
				if (!m_sxpHooked)
				{
					hookSxp(sxp);
				};
				hookSxpInput();
				return;
			};
			if (!mod.m_xpBtn)
			{
				mod.m_xpBtn = mod.m_bar.makeMiniButton("XP", 48, onSxpClick);
				mod.m_xpBtn.name = "sxpBtn";
				art = EditorEngine.libraryMC("xpstage_stage_select");
				if (art)
				{
					try
					{
						art.gotoAndStop(1);
					}
					catch (artErr:*)
					{
					};
					art.x = 24;
					art.y = 14;
					art.mouseEnabled = false;
					art.mouseChildren = false;
					mod.m_xpBtn.addChild(art);
				};
			};
			mod.m_xpBtn.x = SXP_X;
			mod.m_xpBtn.y = sxpTopY(host);
			mod.m_xpBtn.visible = true;
			mod.m_xpBtn.alpha = 1;
			if (mod.m_xpBtn.parent != host)
			{
				host.addChild(mod.m_xpBtn);
			};
			mod.m_layout.hookSssHandClip(mod.m_xpBtn);
			hookSxpInput();
		}

		private function sxpTopY(host:MovieClip):Number
		{
			var bar:MovieClip;
			var y:Number;
			try
			{
				bar = host["bg_top"] as MovieClip;
			}
			catch (err:*)
			{
				bar = null;
			};
			if (bar)
			{
				y = bar.y + 8;
				if (y < -40)
				{
					return (y);
				};
			};
			return (SXP_Y);
		}

		private function hookSxp(target:Sprite):void
		{
			if (!target)
			{
				return;
			};
			if (m_sxpHooked)
			{
				return;
			};
			m_sxpHooked = true;
			target.addEventListener(MouseEvent.MOUSE_DOWN, onSxpMouseDown, true, 50);
			target.addEventListener(MouseEvent.CLICK, onSxpClick, true, 50);
		}

		internal function unhookSxp():void
		{
			var target:DisplayObject;
			target = mod.m_sxpClip;
			if (!target)
			{
				target = mod.m_sxpWrap;
			};
			if (target && m_sxpHooked)
			{
				try
				{
					target.removeEventListener(MouseEvent.MOUSE_DOWN, onSxpMouseDown, true);
					target.removeEventListener(MouseEvent.MOUSE_DOWN, onSxpMouseDown, false);
					target.removeEventListener(MouseEvent.MOUSE_UP, onSxpMouseDown, true);
					target.removeEventListener(MouseEvent.CLICK, onSxpClick, true);
					target.removeEventListener(MouseEvent.CLICK, onSxpClick, false);
				}
				catch (err:*)
				{
				};
			};
			if (mod.m_sxpWrap && mod.m_sxpWrap != target && m_sxpHooked)
			{
				try
				{
					mod.m_sxpWrap.removeEventListener(MouseEvent.MOUSE_DOWN, onSxpMouseDown, true);
					mod.m_sxpWrap.removeEventListener(MouseEvent.MOUSE_DOWN, onSxpMouseDown, false);
					mod.m_sxpWrap.removeEventListener(MouseEvent.MOUSE_UP, onSxpMouseDown, true);
					mod.m_sxpWrap.removeEventListener(MouseEvent.CLICK, onSxpClick, true);
					mod.m_sxpWrap.removeEventListener(MouseEvent.CLICK, onSxpClick, false);
				}
				catch (err2:*)
				{
				};
			};
			m_sxpHooked = false;
		}

		private function onSxpMouseDown(e:MouseEvent):void
		{
			e.stopImmediatePropagation();
		}

		private function onSxpClick(e:MouseEvent):void
		{
			e.stopImmediatePropagation();
			mod.m_book.cycleLivePage();
		}

		private function hookSxpInput():void
		{
			var st:Stage;
			if (m_sxpInputHooked || !mod.m_host)
			{
				return;
			};
			st = mod.m_host.stage as Stage;
			if (!st)
			{
				return;
			};
			m_sxpInputHooked = true;
			st.addEventListener(KeyboardEvent.KEY_DOWN, onSxpKeyDown, true, 50);
			hookSxpGamepads();
		}

		internal function unhookSxpInput():void
		{
			var st:Stage;
			var i:int;
			var pad:*;
			var GE:Class;
			if (!m_sxpInputHooked)
			{
				return;
			};
			m_sxpInputHooked = false;
			try
			{
				st = mod.m_host ? (mod.m_host.stage as Stage) : null;
				if (st)
				{
					st.removeEventListener(KeyboardEvent.KEY_DOWN, onSxpKeyDown, true);
				};
			}
			catch (err:*)
			{
			};
			try
			{
				GE = EngineRefs.ssf2("events.GamepadEvent") as Class;
			}
			catch (geErr:*)
			{
				GE = null;
			};
			i = 0;
			while (m_sxpPads && i < m_sxpPads.length)
			{
				pad = m_sxpPads[i];
				try
				{
					if (pad && GE)
					{
						pad.removeEventListener(GE["BUTTON_DOWN"], onSxpPadDown, false);
					};
				}
				catch (padErr:*)
				{
				};
				i++;
			};
			m_sxpPads = [];
		}

		private function hookSxpGamepads():void
		{
			var SD:Class;
			var GE:Class;
			var list:*;
			var i:int;
			var c:*;
			var pad:*;
			try
			{
				SD = EngineRefs.SaveData as Class;
				GE = EngineRefs.ssf2("events.GamepadEvent") as Class;
				list = SD["Controllers"];
			}
			catch (err:*)
			{
				return;
			};
			if (!list || !GE)
			{
				return;
			};
			m_sxpPads = [];
			i = 0;
			while (i < list["length"])
			{
				c = list[i];
				try
				{
					pad = c ? c["GamepadInstance"] : null;
				}
				catch (cErr:*)
				{
					pad = null;
				};
				if (pad)
				{
					try
					{
						pad.addEventListener(GE["BUTTON_DOWN"], onSxpPadDown, false, 50);
						m_sxpPads.push(pad);
					}
					catch (addErr:*)
					{
					};
				};
				i++;
			};
		}

		private function onSxpKeyDown(e:KeyboardEvent):void
		{
			if (!isSxpHovered())
			{
				return;
			};
			if (e.keyCode == 32 || sxpSelectHeld())
			{
				e.stopImmediatePropagation();
				if (mod.m_sxpSelectLetGo)
				{
					mod.m_sxpSelectLetGo = false;
					mod.m_book.cycleLivePage();
				};
			};
		}

		private function onSxpPadDown(e:Event):void
		{
			if (!isSxpHovered() || !sxpSelectHeld())
			{
				return;
			};
			e.stopImmediatePropagation();
			if (mod.m_sxpSelectLetGo)
			{
				mod.m_sxpSelectLetGo = false;
				mod.m_book.cycleLivePage();
			};
		}

		private function isSxpHovered():Boolean
		{
			var host:DisplayObjectContainer;
			var hand:DisplayObject;
			var rect:Rectangle;
			var clip:DisplayObject;
			clip = mod.m_sxpClip;
			if (!clip || !clip.visible)
			{
				clip = mod.m_xpBtn;
			};
			if (!clip || !clip.parent || !clip.visible)
			{
				mod.m_sxpSelectLetGo = true;
				return (false);
			};
			host = clip.parent;
			hand = mod.m_handClip;
			if (!hand || hand.parent != host)
			{
				hand = findSelectHand(host);
			};
			if (!hand)
			{
				hand = mod.m_layout.scanHandClip(host);
			};
			if (!hand || !hand.visible)
			{
				mod.m_sxpSelectLetGo = true;
				return (false);
			};
			rect = clip.getBounds(host);
			if (!rect.containsPoint(new Point(hand.x, hand.y)))
			{
				mod.m_sxpSelectLetGo = true;
				return (false);
			};
			return (true);
		}

		internal function findSelectHand(host:DisplayObjectContainer):DisplayObject
		{
			var probe:MovieClip;
			var i:int;
			var child:DisplayObject;
			if (!host)
			{
				return (null);
			};
			if (!m_sxpHandQN)
			{
				probe = EditorEngine.libraryMC("stageselect_hand");
				if (probe)
				{
					m_sxpHandQN = getQualifiedClassName(probe);
				};
			};
			if (!m_sxpHandQN)
			{
				return (null);
			};
			i = 0;
			while (i < host.numChildren)
			{
				child = host.getChildAt(i);
				if (getQualifiedClassName(child) == m_sxpHandQN)
				{
					return (child);
				};
				i++;
			};
			return (null);
		}

		internal function sxpSelectHeld():Boolean
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			try
			{
				SD = EngineRefs.SaveData as Class;
				list = SD["Controllers"];
			}
			catch (err:*)
			{
				return (false);
			};
			if (!list)
			{
				return (false);
			};
			i = 0;
			while (i < list["length"])
			{
				c = list[i];
				try
				{
					if (c && (c.IsDown(c._BUTTON2) || c.IsDown(c._START)))
					{
						return (true);
					};
				}
				catch (cErr:*)
				{
				};
				i++;
			};
			return (false);
		}
	}
}
