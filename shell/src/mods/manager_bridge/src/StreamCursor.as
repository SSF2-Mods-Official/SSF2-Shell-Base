package
{
	import flash.display.SimpleButton;
	import flash.display.Stage;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import flash.filesystem.File;
	import flash.filesystem.FileStream;
	import flash.utils.getTimer;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.JsonFile;

	/**
	 * cursor.json / pointer.json / stage.json: hand cursor and pointer reporting.
	 */
	internal class StreamCursor
	{
		private var core:Ssf2StreamMod;
		private var m_cursorHand:Boolean;
		private var m_cursorFrame:int;
		private var m_cursorStage:Stage;
		private var m_pointer:Object;
		private var m_pointerStamp:Number;
		private var m_cursorStageArmed:Boolean;
		private var m_hitPoint:Point;
		private var m_pointerCheckAt:int;
		private var m_moveX:Number;
		private var m_moveY:Number;

		public function StreamCursor(owner:Ssf2StreamMod)
		{
			core = owner;
			m_cursorHand = false;
			m_cursorFrame = 0;
			m_pointerStamp = -1;
			m_cursorStageArmed = false;
			m_hitPoint = new Point();
			m_pointerCheckAt = -100000;
			m_moveX = -100000;
			m_moveY = -100000;
		}

		internal function onMatchStartCursor(ctx:Object):void
		{
			disarmCursorReporting();
		}

		internal function onMatchEndCursor(ctx:Object):void
		{
			armCursorReporting();
		}

		/** Report Flash hand-cursor targets to expansions/state/cursor.json for the Stream panel. */
		internal function armCursorReporting():void
		{
			var st:Stage;
			var MainCls:Class;
			var root:*;
			if (m_cursorStageArmed)
			{
				return;
			};
			try
			{
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? MainCls["Root"] : null;
				st = root && root.stage ? root.stage as Stage : (core.stage as Stage);
				if (!st)
				{
					log("cursor reporting not armed root=" + Boolean(root));
					return;
				};
				st.addEventListener(Event.ENTER_FRAME, onCursorEnterFrame, false, 0, true);
				st.addEventListener(MouseEvent.MOUSE_MOVE, onStageCursorMove, false, 0, true);
				m_cursorStage = st;
				m_cursorStageArmed = true;
				writeStageJson();
				writeCursorJson(false);
				log("cursor reporting armed");
			}
			catch (err:*)
			{
				core.logStepError("armCursorReporting", err, true);
			};
		}

		internal function disarmCursorReporting():void
		{
			if (m_cursorStage)
			{
				m_cursorStage.removeEventListener(Event.ENTER_FRAME, onCursorEnterFrame);
				m_cursorStage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageCursorMove);
			};
			m_cursorStage = null;
			m_cursorStageArmed = false;
		}

		private function writeStageJson():void
		{
			var file:File;
			var stream:FileStream;
			var MainCls:Class;
			var w:Number;
			var h:Number;
			var st:Stage;
			try
			{
				w = 853;
				h = 480;
				try
				{
					MainCls = EngineRefs.Main as Class;
					if (MainCls && MainCls["Width"])
					{
						w = Number(MainCls["Width"]) || w;
					};
					if (MainCls && MainCls["Height"])
					{
						h = Number(MainCls["Height"]) || h;
					};
					st = MainCls && MainCls["Root"] && MainCls["Root"].stage
						? MainCls["Root"].stage as Stage : null;
					if (st && st.stageWidth > 0 && st.stageHeight > 0)
					{
						w = st.stageWidth;
						h = st.stageHeight;
					};
				}
				catch (szErr:*)
				{
				};
				file = core.bridgeFile("stage.json");
				if (!file)
				{
					return;
				};
				JsonFile.write(file, { width: int(w), height: int(h) });
			}
			catch (err:*)
			{
				core.logStepError("writeStageJson", err);
			};
		}

		private function wantsHandCursor(obj:*):Boolean
		{
			var cur:*;
			var depth:int;
			cur = obj;
			depth = 0;
			while (cur && depth < 24)
			{
				if (cur is SimpleButton)
				{
					return (true);
				};
				try
				{
					if (cur.buttonMode && cur.useHandCursor && cur.mouseEnabled)
					{
						return (true);
					};
				}
				catch (bmErr:*)
				{
				};
				try
				{
					if (cur is TextField && cur.htmlText
						&& String(cur.htmlText).toLowerCase().indexOf("<a ") >= 0)
					{
						return (true);
					};
				}
				catch (tfErr:*)
				{
				};
				try
				{
					cur = cur.parent;
				}
				catch (pErr:*)
				{
					break;
				};
				depth++;
			};
			return (false);
		}

		private function handUnderStagePoint(st:Stage, sx:Number, sy:Number):Boolean
		{
			var list:Array;
			var i:int;
			var obj:*;
			if (!st)
			{
				return (false);
			};
			try
			{
				if (Mouse.cursor == MouseCursor.BUTTON || String(Mouse.cursor) == "hand"
					|| String(Mouse.cursor) == "button")
				{
					return (true);
				};
			}
			catch (mcErr:*)
			{
			};
			try
			{
				m_hitPoint.x = sx;
				m_hitPoint.y = sy;
				list = st.getObjectsUnderPoint(m_hitPoint);
				if (list)
				{
					for (i = list.length - 1; i >= 0; i--)
					{
						obj = list[i];
						if (wantsHandCursor(obj))
						{
							return (true);
						};
					};
				};
			}
			catch (gopErr:*)
			{
			};
			return (false);
		}

		private function readPointerNorm():Object
		{
			var file:File;
			var stream:FileStream;
			var text:String;
			var data:Object;
			var stamp:Number;
			var now:int;
			now = getTimer();
			if (now - m_pointerCheckAt < 500)
			{
				return (m_pointer);
			};
			m_pointerCheckAt = now;
			try
			{
				file = core.bridgeFile("pointer.json");
				if (!file || !file.exists)
				{
					m_pointerStamp = -1;
					m_pointer = null;
					return (null);
				};
				stamp = file.modificationDate ? file.modificationDate.getTime() : 0;
				if (stamp == m_pointerStamp)
				{
					return (m_pointer);
				};
				m_pointerStamp = stamp;
				m_pointer = null;
				data = JsonFile.read(file);
				m_pointer = data;
				return (data);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		private function onCursorEnterFrame(e:Event):void
		{
			var st:Stage;
			var hand:Boolean;
			var now:int;
			var ptr:Object;
			var sx:Number;
			var sy:Number;
			if (++m_cursorFrame % 3 != 0)
			{
				return;
			};
			try
			{
				st = e && e.target is Stage ? e.target as Stage : null;
				if (!st)
				{
					return;
				};
				hand = false;
				try
				{
					if (Mouse.cursor == MouseCursor.BUTTON || String(Mouse.cursor) == "hand"
						|| String(Mouse.cursor) == "button")
					{
						hand = true;
					};
				}
				catch (mcErr:*)
				{
				};
				if (!hand)
				{
					hand = handUnderStagePoint(st, st.mouseX, st.mouseY);
				};
				if (!hand)
				{
					ptr = readPointerNorm();
					if (ptr && ptr.nx != null && ptr.ny != null)
					{
						sx = Number(ptr.nx) * st.stageWidth;
						sy = Number(ptr.ny) * st.stageHeight;
						hand = handUnderStagePoint(st, sx, sy);
					};
				};
				if (hand == m_cursorHand)
				{
					return;
				};
				m_cursorHand = hand;
				writeCursorJson(hand);
			}
			catch (err:*)
			{
			};
		}

		private function onStageCursorMove(e:MouseEvent):void
		{
			var hand:Boolean;
			var dx:Number;
			var dy:Number;
			if (e)
			{
				dx = e.stageX - m_moveX;
				dy = e.stageY - m_moveY;
				if (dx * dx + dy * dy <= 16)
				{
					return;
				};
				m_moveX = e.stageX;
				m_moveY = e.stageY;
			};
			try
			{
				hand = wantsHandCursor(e ? e.target : null);
				if (!hand && e && e.currentTarget is Stage)
				{
					hand = handUnderStagePoint(e.currentTarget as Stage, e.stageX, e.stageY);
				};
			}
			catch (err:*)
			{
				hand = false;
			};
			if (hand == m_cursorHand)
			{
				return;
			};
			m_cursorHand = hand;
			writeCursorJson(hand);
		}

		private function writeCursorJson(hand:Boolean):void
		{
			var file:File;
			var stream:FileStream;
			var payload:Object;
			try
			{
				file = core.bridgeFile("cursor.json");
				if (!file)
				{
					return;
				};
				payload = { hand: hand, utc: new Date().toUTCString() };
				JsonFile.write(file, payload);
			}
			catch (err:*)
			{
				core.logStepError("writeCursorJson", err, true);
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
