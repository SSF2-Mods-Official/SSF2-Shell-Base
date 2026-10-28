package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	/**
	 * Player hands and cursor tokens on Character Select: lifts human hands over the edit
	 * chrome, seats them back home, and scales or raises cursors with the grid.
	 */
	public class CssHands
	{
		private var mod:CssEditorMod;
		private var m_cursorLogged:int;
		private var m_handHome:DisplayObjectContainer;
		private var m_handParked:DisplayObject;
		private var m_handHomeX:Number;
		private var m_handHomeY:Number;
		private var m_handSeat:Dictionary;
		private var m_editHover:Boolean;

		public function CssHands(owner:CssEditorMod)
		{
			mod = owner;
			m_cursorLogged = -1;
			m_handSeat = new Dictionary();
		}

		private function humanHand(menu:*):DisplayObject
		{
			var chips:*;
			var i:int;
			var hand:DisplayObject;
			var fallback:DisplayObject;
			if (!menu)
			{
				return (null);
			};
			try
			{
				chips = menu.PlayerChips;
			}
			catch (err:*)
			{
				return (null);
			};
			if (!chips)
			{
				return (null);
			};
			fallback = null;
			i = 0;
			while (i < chips.length)
			{
				hand = null;
				try
				{
					hand = chips[i].HandMC as DisplayObject;
				}
				catch (handErr:*)
				{
					hand = null;
				};
				if (hand && slotIsHuman(menu, i))
				{
					if (hand.visible)
					{
						return (hand);
					};
					if (!fallback)
					{
						fallback = hand;
					};
				};
				i++;
			};
			return (fallback);
		}

		private function pointerOnEdit():Boolean
		{
			var st:Stage;
			var box:Rectangle;
			var handPt:Point;
			var mousePt:Point;
			var on:Boolean;
			if (!mod.m_editBtn || !mod.m_editBtn.visible || !mod.m_editBtn.stage)
			{
				m_editHover = false;
				return (false);
			};
			st = mod.m_editBtn.stage;
			try
			{
				box = mod.m_editBtn.getBounds(st);
			}
			catch (err:*)
			{
				m_editHover = false;
				return (false);
			};
			if (m_editHover)
			{
				box = box.clone();
				box.inflate(12, 12);
			};
			handPt = mod.m_input.handStagePoint();
			mousePt = new Point(st.mouseX, st.mouseY);
			on = false;
			if (handPt && box.containsPoint(handPt))
			{
				on = true;
			}
			else if (box.containsPoint(mousePt) && (!handPt || Point.distance(handPt, mousePt) < 64))
			{
				on = true;
			};
			m_editHover = on;
			return (on);
		}

		internal function restoreParkedHand():void
		{
			var hand:DisplayObject;
			seatAllHands();
			if (!m_handParked || !m_handHome)
			{
				m_handParked = null;
				return;
			};
			hand = m_handParked;
			m_handParked = null;
			if (hand.parent != m_handHome)
			{
				m_handHome.addChild(hand);
			};
			hand.x = m_handHomeX;
			hand.y = m_handHomeY;
		}

		private function onHandSeat(e:Event):void
		{
			seatHand(e.currentTarget as DisplayObject, false);
		}

		private function handFrame(hand:DisplayObject):String
		{
			var mc:MovieClip;
			mc = hand as MovieClip;
			if (!mc)
			{
				return ("");
			};
			try
			{
				return (mc.currentLabel ? String(mc.currentLabel) : "");
			}
			catch (err:*)
			{
				return ("");
			};
			return ("");
		}

		private function restoreHandFrame(hand:DisplayObject, label:String):void
		{
			var mc:MovieClip;
			if (!label)
			{
				return;
			};
			mc = hand as MovieClip;
			if (!mc)
			{
				return;
			};
			try
			{
				if (mc.currentLabel != label)
				{
					mc.gotoAndStop(label);
				};
			}
			catch (err:*)
			{
			};
		}

		private function seatHand(hand:DisplayObject, restoreMouse:Boolean = true):void
		{
			var rec:Object;
			var home:DisplayObjectContainer;
			var label:String;
			if (!hand || !m_handSeat)
			{
				return;
			};
			rec = m_handSeat[hand];
			if (!rec || !rec.lifted)
			{
				return;
			};
			home = rec.home as DisplayObjectContainer;
			label = handFrame(hand);
			if (home && hand.parent != home)
			{
				home.addChild(hand);
				restoreHandFrame(hand, label);
			};
			hand.x = Number(rec.x);
			hand.y = Number(rec.y);
			if (restoreMouse)
			{
				try
				{
					hand["mouseEnabled"] = rec.me;
					hand["mouseChildren"] = rec.mc;
				}
				catch (mouseErr:*)
				{
				};
			};
			rec.lifted = false;
		}

		internal function seatAllHands():void
		{
			var rec:Object;
			if (!m_handSeat)
			{
				return;
			};
			for each (rec in m_handSeat)
			{
				if (rec)
				{
					seatHand(rec.hand as DisplayObject);
				};
			};
		}

		internal function unhookHands():void
		{
			var rec:Object;
			var clip:DisplayObject;
			if (!m_handSeat)
			{
				return;
			};
			for each (rec in m_handSeat)
			{
				clip = rec ? (rec.hand as DisplayObject) : null;
				if (clip && rec.hooked)
				{
					clip.removeEventListener(Event.ENTER_FRAME, onHandSeat);
					rec.hooked = false;
				};
			};
		}

		private function rememberHand(hand:DisplayObject):Object
		{
			var rec:Object;
			rec = m_handSeat[hand];
			if (!rec)
			{
				rec = {hand:hand, home:null, x:0, y:0, lifted:false, me:true, mc:true, meSaved:false, hooked:false};
				m_handSeat[hand] = rec;
			};
			if (!rec.hooked)
			{
				hand.addEventListener(Event.ENTER_FRAME, onHandSeat, false, 1);
				rec.hooked = true;
			};
			return (rec);
		}

		internal function liftHandsOverChrome(menu:*):void
		{
			var parent:DisplayObjectContainer;
			var chips:*;
			var i:int;
			var hand:DisplayObject;
			var hover:DisplayObject;
			parent = mod.m_chrome.chromeParent();
			if (!parent || !menu)
			{
				seatAllHands();
				return;
			};
			try
			{
				chips = menu.PlayerChips;
			}
			catch (err:*)
			{
				return;
			};
			if (!chips)
			{
				return;
			};
			hover = pointerOnEdit() ? humanHand(menu) : null;
			i = 0;
			while (i < chips.length)
			{
				hand = null;
				try
				{
					hand = chips[i].HandMC as DisplayObject;
				}
				catch (handErr:*)
				{
					hand = null;
				};
				if (!hand || !hand.parent)
				{
					i++;
					continue;
				};
				if (!hand.visible || (mod.m_editing ? i != 0 : !slotIsHuman(menu, i)))
				{
					seatHand(hand);
					i++;
					continue;
				};
				liftHand(parent, hand, hover);
				i++;
			};
			if (hover && hover.parent == parent)
			{
				try
				{
					parent.setChildIndex(hover, parent.numChildren - 1);
				}
				catch (hoverIdx:*)
				{
				};
			};
		}

		/** Moves one player hand onto the chrome layer at the same screen spot (the Edit button when hover). */
		private function liftHand(parent:DisplayObjectContainer, hand:DisplayObject, hover:DisplayObject):void
		{
			var rec:Object;
			var g:Point;
			var local:Point;
			var label:String;
			rec = rememberHand(hand);
			if (!rec.lifted)
			{
				rec.home = hand.parent;
				rec.x = hand.x;
				rec.y = hand.y;
				if (!rec.meSaved)
				{
					try
					{
						rec.me = hand["mouseEnabled"];
						rec.mc = hand["mouseChildren"];
					}
					catch (mouseErr:*)
					{
					};
					rec.meSaved = true;
				};
			};
			if (hand == hover && mod.m_editBtn)
			{
				g = new Point(CssEditorMod.EDIT_W * 0.45, 0);
				try
				{
					g = mod.m_editBtn.localToGlobal(g);
				}
				catch (editErr:*)
				{
					g = hand.localToGlobal(new Point(0, 0));
				};
			}
			else
			{
				g = hand.localToGlobal(new Point(0, 0));
			};
			try
			{
				local = parent.globalToLocal(g);
			}
			catch (gErr:*)
			{
				return;
			};
			label = handFrame(hand);
			if (hand.parent != parent)
			{
				parent.addChild(hand);
				restoreHandFrame(hand, label);
			};
			hand.x = local.x;
			hand.y = local.y;
			try
			{
				hand["mouseEnabled"] = false;
				hand["mouseChildren"] = false;
			}
			catch (mouseOff:*)
			{
			};
			try
			{
				parent.setChildIndex(hand, parent.numChildren - 1);
			}
			catch (idxErr:*)
			{
			};
			rec.lifted = true;
		}

		internal function raisePrimaryHand(menu:*):void
		{
			var chips:*;
			var hand:DisplayObject;
			var i:int;
			if (!menu || !mod.m_editing)
			{
				return;
			};
			try
			{
				chips = menu.PlayerChips;
			}
			catch (err:*)
			{
				return;
			};
			if (!chips)
			{
				return;
			};
			i = 0;
			while (i < chips.length)
			{
				hand = null;
				try
				{
					hand = chips[i].HandMC as DisplayObject;
					if (chips[i].MC)
					{
						mod.m_chrome.hideCursorPiece(chips[i].MC as DisplayObject);
					};
				}
				catch (handErr:*)
				{
					hand = null;
				};
				if (i == 0 && hand)
				{
					hand.visible = true;
					if (hand.parent)
					{
						try
						{
							hand.parent.setChildIndex(hand, hand.parent.numChildren - 1);
						}
						catch (idxErr:*)
						{
						};
					};
				}
				else if (hand)
				{
					mod.m_chrome.hideCursorPiece(hand);
				};
				i++;
			};
		}

		internal function isPrimaryHand(menu:*, child:DisplayObject):Boolean
		{
			var chips:*;
			if (!menu || !child)
			{
				return (false);
			};
			try
			{
				chips = menu.PlayerChips;
				return (chips && chips.length > 0 && chips[0].HandMC == child);
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function isChipToken(menu:*, child:DisplayObject):Boolean
		{
			var chips:*;
			var i:int;
			if (!menu || !child)
			{
				return (false);
			};
			try
			{
				chips = menu.PlayerChips;
			}
			catch (err:*)
			{
				return (false);
			};
			if (!chips)
			{
				return (false);
			};
			i = 0;
			while (i < chips.length)
			{
				try
				{
					if (chips[i].MC == child)
					{
						return (true);
					};
				}
				catch (chipErr:*)
				{
				};
				i++;
			};
			return (false);
		}

		private function slotIsHuman(menu:*, index:int):Boolean
		{
			var settings:*;
			var clip:MovieClip;
			try
			{
				settings = menu.GameObj.PlayerSettings;
				if (settings && index >= 0 && index < settings.length && settings[index])
				{
					return (Boolean(settings[index].human));
				};
			}
			catch (err:*)
			{
			};
			try
			{
				clip = menu.PlayerChips[index].MC as MovieClip;
				if (clip && clip.currentLabel)
				{
					return (String(clip.currentLabel).indexOf("human") == 0);
				};
			}
			catch (labelErr:*)
			{
			};
			return (false);
		}

		internal function scalePlayerCursors(menu:*, scale:Number):void
		{
			var chips:*;
			var i:int;
			var token:DisplayObject;
			var hand:DisplayObject;
			var token0:DisplayObject;
			var hand0:DisplayObject;
			var mark:int;
			if (!menu || !(scale > 0))
			{
				return;
			};
			if (scale < 0.5)
			{
				scale = 0.5;
			};
			if (scale > 2)
			{
				scale = 2;
			};
			try
			{
				chips = menu.PlayerChips;
			}
			catch (err:*)
			{
				return;
			};
			if (!chips)
			{
				return;
			};
			token0 = null;
			hand0 = null;
			i = 0;
			while (i < chips.length)
			{
				token = null;
				hand = null;
				try
				{
					token = chips[i].MC as DisplayObject;
					hand = chips[i].HandMC as DisplayObject;
				}
				catch (pieceErr:*)
				{
					token = null;
					hand = null;
				};
				if (token)
				{
					if (token.scaleX != scale)
					{
						token.scaleX = scale;
					};
					if (token.scaleY != scale)
					{
						token.scaleY = scale;
					};
				};
				if (hand)
				{
					if (hand.scaleX != scale)
					{
						hand.scaleX = scale;
					};
					if (hand.scaleY != scale)
					{
						hand.scaleY = scale;
					};
					if (!mod.m_editing)
					{
						hand.visible = slotIsHuman(menu, i) && token != null && token.visible;
					};
				};
				if (i == 0)
				{
					token0 = token;
					hand0 = hand;
				};
				i++;
			};
			mark = int(scale * 100);
			if (mark != m_cursorLogged)
			{
				m_cursorLogged = mark;
				mod.cssLog("cursor page=" + mod.m_page + " scale=" + mark + " handSx=" + (hand0 ? hand0.scaleX : 0) + " handVis=" + ((hand0 && hand0.visible) ? 1 : 0) + " chipSx=" + (token0 ? token0.scaleX : 0) + " chipVis=" + ((token0 && token0.visible) ? 1 : 0));
			};
		}

		internal function raiseHands(menu:*):void
		{
			var chips:*;
			var i:int;
			var hand:DisplayObject;
			var token:DisplayObject;
			if (!menu)
			{
				return;
			};
			try
			{
				chips = menu.PlayerChips;
			}
			catch (err:*)
			{
				return;
			};
			if (!chips)
			{
				return;
			};
			i = 0;
			while (i < chips.length)
			{
				token = null;
				hand = null;
				try
				{
					token = chips[i].MC as DisplayObject;
					hand = chips[i].HandMC as DisplayObject;
				}
				catch (handErr:*)
				{
					token = null;
					hand = null;
				};
				if (token && token.parent)
				{
					try
					{
						token.parent.setChildIndex(token, token.parent.numChildren - 1);
					}
					catch (chipIdxErr:*)
					{
					};
				};
				if (hand && hand.parent)
				{
					try
					{
						hand.parent.setChildIndex(hand, hand.parent.numChildren - 1);
					}
					catch (idxErr:*)
					{
					};
				};
				i++;
			};
		}

		internal function isLiveHand(menu:*, child:DisplayObject):Boolean
		{
			var chips:*;
			var i:int;
			if (!menu || !child)
			{
				return (false);
			};
			try
			{
				chips = menu.PlayerChips;
			}
			catch (err:*)
			{
				return (false);
			};
			if (!chips)
			{
				return (false);
			};
			i = 0;
			while (i < chips.length)
			{
				try
				{
					if (chips[i].HandMC == child)
					{
						return (true);
					};
				}
				catch (handErr:*)
				{
				};
				i++;
			};
			return (false);
		}
	}
}
