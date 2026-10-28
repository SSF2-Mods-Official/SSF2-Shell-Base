package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;

	import ssf2mm.shared.HsvWheel;

	/**
	 * Palette-maker-style HSV color wheel (hue strip + SV square + hex).
	 */
	public class MusicColorPicker extends Sprite
	{
		private var m_gw:int;
		private var m_gh:int;
		private var m_onOk:Function;
		private var m_onCancel:Function;
		private var m_hue:Number;
		private var m_sat:Number;
		private var m_val:Number;
		private var m_hueBmp:Bitmap;
		private var m_svBmp:Bitmap;
		private var m_hueHit:Sprite;
		private var m_svHit:Sprite;
		private var m_preview:Sprite;
		private var m_hex:TextField;
		private var m_hexEditing:Boolean;
		private var m_dragHue:Boolean;
		private var m_dragSv:Boolean;
		private var m_showGlow:Boolean;
		private var m_glowEnabled:Boolean;
		private var m_glowBox:Sprite;
		private var m_glowMark:Sprite;

		public function MusicColorPicker(gw:int, gh:int, startColor:uint,
			onOk:Function, onCancel:Function, showGlow:Boolean = false, glowStart:Boolean = false)
		{
			var hsv:Object;
			super();
			m_gw = gw;
			m_gh = gh;
			m_onOk = onOk;
			m_onCancel = onCancel;
			hsv = HsvWheel.rgbToHsv(startColor);
			m_hue = Number(hsv.h);
			m_sat = Number(hsv.s);
			m_val = Number(hsv.v);
			m_hexEditing = false;
			m_dragHue = false;
			m_dragSv = false;
			m_showGlow = showGlow;
			m_glowEnabled = glowStart;
			build();
			redrawAll();
			addEventListener(Event.ADDED_TO_STAGE, onAdded);
			addEventListener(Event.REMOVED_FROM_STAGE, onRemoved);
		}

		public function get glowEnabled():Boolean
		{
			return (m_glowEnabled);
		}

		private function onAdded(e:Event):void
		{
			if (stage)
			{
				stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			};
		}

		private function onRemoved(e:Event):void
		{
			if (stage)
			{
				stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			};
		}

		private function build():void
		{
			var box:Sprite;
			var title:TextField;
			var hexLabel:TextField;
			var okBtn:Sprite;
			var cancelBtn:Sprite;
			graphics.beginFill(0x000000, 0.62);
			graphics.drawRect(0, 0, m_gw, m_gh);
			graphics.endFill();
			box = new Sprite();
			box.x = int(m_gw * 0.5 - 120);
			box.y = Math.max(20, int(m_gh * 0.5 - 150));
			box.graphics.beginFill(0x222230, 0.98);
			box.graphics.lineStyle(1, MusicTheme.ui(), 0.35);
			box.graphics.drawRoundRect(0, 0, 240, m_showGlow ? 330 : 300, 10, 10);
			box.graphics.endFill();
			addChild(box);
			title = makeLabel("Color", 12, 8, 13, true);
			box.addChild(title);
			m_hueBmp = new Bitmap(new BitmapData(18, 150, false, 0));
			m_hueHit = new Sprite();
			m_hueHit.x = 16;
			m_hueHit.y = 34;
			m_hueHit.addChild(m_hueBmp);
			m_hueHit.graphics.beginFill(0, 0);
			m_hueHit.graphics.drawRect(0, 0, 18, 150);
			m_hueHit.graphics.endFill();
			m_hueHit.buttonMode = true;
			m_hueHit.addEventListener(MouseEvent.MOUSE_DOWN, function (e:MouseEvent):void
			{
				m_dragHue = true;
				sampleHue(e.localY);
			});
			box.addChild(m_hueHit);
			m_svBmp = new Bitmap(new BitmapData(150, 150, false, 0));
			m_svHit = new Sprite();
			m_svHit.x = 48;
			m_svHit.y = 34;
			m_svHit.addChild(m_svBmp);
			m_svHit.graphics.beginFill(0, 0);
			m_svHit.graphics.drawRect(0, 0, 150, 150);
			m_svHit.graphics.endFill();
			m_svHit.buttonMode = true;
			m_svHit.addEventListener(MouseEvent.MOUSE_DOWN, function (e:MouseEvent):void
			{
				m_dragSv = true;
				sampleSv(e.localX, e.localY);
			});
			box.addChild(m_svHit);
			m_preview = new Sprite();
			m_preview.x = 16;
			m_preview.y = 196;
			box.addChild(m_preview);
			hexLabel = makeLabel("Hex", 58, 198, 10, false);
			box.addChild(hexLabel);
			m_hex = new TextField();
			m_hex.type = TextFieldType.INPUT;
			m_hex.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true);
			m_hex.restrict = "#0-9A-Fa-f";
			m_hex.maxChars = 7;
			m_hex.border = true;
			m_hex.borderColor = 0x666677;
			m_hex.background = true;
			m_hex.backgroundColor = 0x2A2A35;
			m_hex.width = 86;
			m_hex.height = 20;
			m_hex.x = 88;
			m_hex.y = 196;
			m_hex.addEventListener(Event.CHANGE, onHexChange);
			m_hex.addEventListener(FocusEvent.FOCUS_IN, function (e:FocusEvent):void
			{
				m_hexEditing = true;
			});
			m_hex.addEventListener(FocusEvent.FOCUS_OUT, function (e:FocusEvent):void
			{
				m_hexEditing = false;
				applyHex(true);
			});
			m_hex.addEventListener(KeyboardEvent.KEY_DOWN, function (e:KeyboardEvent):void
			{
				if (e.keyCode == Keyboard.ENTER)
				{
					applyHex(true);
				};
			});
			box.addChild(m_hex);
			if (m_showGlow)
			{
				m_glowBox = new Sprite();
				m_glowBox.x = 16;
				m_glowBox.y = 226;
				m_glowBox.buttonMode = true;
				m_glowBox.mouseChildren = false;
				m_glowBox.graphics.beginFill(0x2A2A35, 1);
				m_glowBox.graphics.lineStyle(1, 0x666677, 1);
				m_glowBox.graphics.drawRoundRect(0, 0, 18, 18, 4, 4);
				m_glowBox.graphics.endFill();
				m_glowMark = new Sprite();
				m_glowMark.graphics.beginFill(MusicTheme.ui(), 1);
				m_glowMark.graphics.drawRect(4, 4, 10, 10);
				m_glowMark.graphics.endFill();
				m_glowMark.visible = m_glowEnabled;
				m_glowBox.addChild(m_glowMark);
				m_glowBox.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
				{
					e.stopPropagation();
					m_glowEnabled = !m_glowEnabled;
					if (m_glowMark)
					{
						m_glowMark.visible = m_glowEnabled;
					};
				});
				box.addChild(m_glowBox);
				box.addChild(makeLabel("Glow behind symbol", 40, 228, 11, false));
				okBtn = textButton("OK · Attack", 100, 28);
				okBtn.x = 16;
				okBtn.y = 268;
				cancelBtn = textButton("Cancel · Special", 110, 28);
				cancelBtn.x = 124;
				cancelBtn.y = 268;
			}
			else
			{
				okBtn = textButton("OK · Attack", 100, 28);
				okBtn.x = 16;
				okBtn.y = 248;
				cancelBtn = textButton("Cancel · Special", 110, 28);
				cancelBtn.x = 124;
				cancelBtn.y = 248;
			};
			okBtn.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				e.stopPropagation();
				confirm();
			});
			box.addChild(okBtn);
			cancelBtn.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				e.stopPropagation();
				cancel();
			});
			box.addChild(cancelBtn);
			addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				if (e.target == this)
				{
					cancel();
				};
			});
		}

		public function confirm():void
		{
			if (m_onOk != null)
			{
				m_onOk(currentColor());
			};
		}

		public function cancel():void
		{
			if (m_onCancel != null)
			{
				m_onCancel();
			};
		}

		public function currentColor():uint
		{
			return HsvWheel.hsvToRgb(m_hue, m_sat, m_val, 0);
		}

		private function sampleHue(localY:Number):void
		{
			m_hue = HsvWheel.hueAt(localY, 150);
			redrawAll();
		}

		private function sampleSv(localX:Number, localY:Number):void
		{
			m_sat = HsvWheel.satAt(localX, 150);
			m_val = HsvWheel.valAt(localY, 150);
			redrawAll();
		}

		private function onMouseUp(e:MouseEvent):void
		{
			m_dragHue = false;
			m_dragSv = false;
		}

		private function onMouseMove(e:MouseEvent):void
		{
			if (m_dragHue && m_hueHit)
			{
				sampleHue(m_hueHit.mouseY);
			};
			if (m_dragSv && m_svHit)
			{
				sampleSv(m_svHit.mouseX, m_svHit.mouseY);
			};
		}

		private function onHexChange(e:Event):void
		{
			applyHex(false);
		}

		private function applyHex(requireComplete:Boolean):void
		{
			var raw:String;
			var parsed:int;
			var hsv:Object;
			if (!m_hex)
			{
				return;
			};
			raw = String(m_hex.text).replace(/^#/, "");
			if (requireComplete)
			{
				if (raw.length != 6 && raw.length != 3)
				{
					m_hex.text = HsvWheel.formatHex(currentColor());
					return;
				};
			}
			else if (raw.length != 6 && raw.length != 3)
			{
				return;
			};
			parsed = HsvWheel.parseHex(raw);
			if (parsed < 0)
			{
				return;
			};
			hsv = HsvWheel.rgbToHsv(uint(parsed));
			m_hue = Number(hsv.h);
			m_sat = Number(hsv.s);
			m_val = Number(hsv.v);
			redrawAll(false);
		}

		private function redrawAll(syncHex:Boolean = true):void
		{
			var c:uint;
			HsvWheel.drawHueStrip(m_hueBmp.bitmapData);
			HsvWheel.drawSvSquare(m_svBmp.bitmapData, m_hue);
			c = currentColor();
			m_preview.graphics.clear();
			m_preview.graphics.beginFill(c, 1);
			m_preview.graphics.lineStyle(1, 0xFFFFFF, 0.45);
			m_preview.graphics.drawRoundRect(0, 0, 36, 24, 4, 4);
			m_preview.graphics.endFill();
			if (syncHex && m_hex && !m_hexEditing)
			{
				m_hex.text = HsvWheel.formatHex(c);
			};
		}

		private function makeLabel(text:String, x:Number, y:Number, size:int, bold:Boolean):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.x = x;
			tf.y = y;
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", size, MusicTheme.ui(), bold);
			tf.text = text;
			return tf;
		}

		private function textButton(text:String, w:Number, h:Number):Sprite
		{
			var s:Sprite;
			var tf:TextField;
			s = new Sprite();
			s.graphics.beginFill(0x3A3A4A, 1);
			s.graphics.lineStyle(1, MusicTheme.ui(), 0.35);
			s.graphics.drawRoundRect(0, 0, w, h, 6, 6);
			s.graphics.endFill();
			s.buttonMode = true;
			s.useHandCursor = true;
			tf = new TextField();
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", 11, MusicTheme.ui(), true);
			tf.text = text;
			tf.x = (w - tf.textWidth) * 0.5 - 1;
			tf.y = (h - tf.textHeight) * 0.5 - 1;
			s.addChild(tf);
			return s;
		}
	}
}
