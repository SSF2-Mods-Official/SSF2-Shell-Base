package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	/**
	 * Fullscreen now-playing: jewel case (frozen space BG + desaturated SSF2 logo),
	 * half-visible spinning disc with series symbol + rim spectrum, song info on the right.
	 */
	public class MusicExpandedPlayer extends Sprite
	{
		private var m_w:int;
		private var m_h:int;
		private var m_bg:Sprite;
		private var m_disc:Sprite;
		private var m_discArt:Sprite;
		private var m_spinHost:Sprite;
		private var m_case:Sprite;
		private var m_logoHost:Sprite;
		private var m_infoHost:Sprite;
		private var m_titleTf:TextField;
		private var m_artistTf:TextField;
		private var m_seriesTf:TextField;
		private var m_edgeViz:DiscEdgeVisualizer;
		private var m_spinAngle:Number;
		private var m_paused:Boolean;
		private var m_stageId:String;
		private var m_caseSize:Number;
		private var m_discR:Number;
		private var m_trackTitle:String;
		private var m_trackArtist:String;
		private var m_seriesName:String;
		private var m_pendingSpin:DisplayObject;

		public function MusicExpandedPlayer()
		{
			super();
			m_spinAngle = 0;
			m_paused = true;
			m_caseSize = 260;
			m_discR = 120;
			m_trackTitle = "—";
			m_trackArtist = "";
			m_seriesName = "";
			m_pendingSpin = null;
			mouseEnabled = false;
			mouseChildren = false;
		}

		public function layout(w:int, h:int):void
		{
			m_w = w;
			m_h = h;
			rebuild();
		}

		public function setTrack(title:String, artist:String, stageName:String = "",
			seriesName:String = ""):void
		{
			m_trackTitle = title && title.length > 0 ? title : "—";
			m_trackArtist = artist || "";
			m_seriesName = seriesName || "";
			refreshInfoText();
		}

		public function setSpinIcon(icon:DisplayObject):void
		{
			m_pendingSpin = icon;
			if (!m_spinHost)
			{
				return;
			};
			while (m_spinHost.numChildren > 0)
			{
				m_spinHost.removeChildAt(0);
			};
			if (!icon)
			{
				return;
			};
			MusicStageVisuals.mountCenteredIcon(m_spinHost, icon, m_caseSize * 0.42);
		}

		public function setDiscStage(stageId:String):void
		{
			var art:DisplayObject;
			var mask:Sprite;
			var tryId:String;
			var dimOverlay:Sprite;
			var size:Number;
			m_stageId = stageId;
			if (!m_discArt)
			{
				return;
			};
			while (m_discArt.numChildren > 0)
			{
				m_discArt.removeChildAt(0);
			};
			m_discArt.mask = null;
			tryId = stageId;
			if (!tryId || tryId == MusicStageVisuals.OTHER_STAGE_ID)
			{
				tryId = MusicStageVisuals.WAITING_ROOM_ID;
			};
			size = m_discR * 2.1;
			art = MusicStageVisuals.attachPreviewBitmap(m_discArt, tryId, size, size);
			if (!art && tryId != MusicStageVisuals.WAITING_ROOM_ID)
			{
				while (m_discArt.numChildren > 0)
				{
					m_discArt.removeChildAt(0);
				};
				art = MusicStageVisuals.attachPreviewBitmap(m_discArt, MusicStageVisuals.WAITING_ROOM_ID,
					size, size);
			};
			if (!art)
			{
				while (m_discArt.numChildren > 0)
				{
					m_discArt.removeChildAt(0);
				};
				art = MusicStageVisuals.attachTileArt(m_discArt, tryId, size, size);
				if (art)
				{
					art.x -= size * 0.5;
					art.y -= size * 0.5;
				};
			};
			mask = new Sprite();
			mask.graphics.beginFill(0xFFFFFF, 1);
			mask.graphics.drawCircle(0, 0, m_discR);
			mask.graphics.endFill();
			m_discArt.addChild(mask);
			m_discArt.mask = mask;
			dimOverlay = new Sprite();
			dimOverlay.graphics.beginFill(0x050508, 0.22);
			dimOverlay.graphics.drawCircle(0, 0, m_discR);
			dimOverlay.graphics.endFill();
			m_discArt.addChild(dimOverlay);
		}

		public function tick(paused:Boolean):void
		{
			m_paused = paused;
			if (!m_paused && m_disc)
			{
				m_spinAngle += 1.35;
				m_disc.rotation = m_spinAngle;
			};
			if (m_edgeViz)
			{
				if (m_paused)
				{
					m_edgeViz.stop();
				}
				else
				{
					m_edgeViz.start();
					m_edgeViz.tick();
				};
			};
		}

		private function rebuild():void
		{
			var caseX:Number;
			var caseY:Number;
			var savedSpin:DisplayObject;
			var savedStage:String;
			savedSpin = m_pendingSpin;
			savedStage = m_stageId;
			while (numChildren > 0)
			{
				removeChildAt(0);
			};
			// 10% larger album so the disc reads as fitting the cover.
			m_caseSize = Math.min(300, Math.max(220, Math.min(m_w * 0.33, m_h * 0.64))) * 1.10;
			m_discR = m_caseSize * 0.48;
			caseX = m_w * 0.22;
			caseY = m_h * 0.48;
			buildBackground();
			// Disc center on the case's right edge → exactly half visible (hole readable).
			buildDisc(caseX + m_caseSize * 0.5, caseY, m_discR);
			buildCase(caseX, caseY);
			buildInfoPanel(caseX + m_caseSize * 0.5 + m_discR + 22, caseY);
			refreshInfoText();
			if (savedStage)
			{
				setDiscStage(savedStage);
			};
			if (savedSpin)
			{
				setSpinIcon(savedSpin);
			};
			if (m_disc)
			{
				m_disc.rotation = m_spinAngle;
			};
		}

		private function buildBackground():void
		{
			var i:int;
			var x:Number;
			var y:Number;
			var a:Number;
			m_bg = new Sprite();
			m_bg.graphics.beginFill(0x05050C, 1);
			m_bg.graphics.drawRect(0, 0, m_w, m_h);
			m_bg.graphics.endFill();
			m_bg.graphics.beginFill(0x0E0C16, 1);
			m_bg.graphics.drawCircle(m_w * 0.28, m_h * 0.45, Math.max(m_w, m_h) * 0.38);
			m_bg.graphics.endFill();
			i = 0;
			while (i < 70)
			{
				x = (i * 97 + 41) % Math.max(1, m_w);
				y = (i * 53 + 17) % Math.max(1, m_h);
				a = 0.15 + (i % 5) * 0.08;
				m_bg.graphics.beginFill(0xFFFFFF, a);
				m_bg.graphics.drawCircle(x, y, (i % 3 == 0) ? 1.4 : 0.8);
				m_bg.graphics.endFill();
				i++;
			};
			addChild(m_bg);
		}

		private function buildDisc(cx:Number, cy:Number, r:Number):void
		{
			var clip:Sprite;
			var ring:Sprite;
			var hole:Sprite;
			var gloss:Sprite;
			m_disc = new Sprite();
			m_disc.x = cx;
			m_disc.y = cy;
			clip = new Sprite();
			clip.graphics.beginFill(0xFFFFFF, 1);
			clip.graphics.drawCircle(0, 0, r);
			clip.graphics.endFill();
			m_disc.addChild(clip);
			m_discArt = new Sprite();
			m_disc.addChild(m_discArt);
			m_disc.mask = clip;
			// Inner grooves only — outer rim is the wave visualizer.
			ring = new Sprite();
			ring.graphics.lineStyle(1, 0xFFFFFF, 0.18);
			ring.graphics.drawCircle(0, 0, r * 0.72);
			ring.graphics.drawCircle(0, 0, r * 0.45);
			m_disc.addChild(ring);
			gloss = new Sprite();
			gloss.graphics.beginFill(0xFFFFFF, 0.08);
			gloss.graphics.drawCircle(-r * 0.25, -r * 0.25, r * 0.35);
			gloss.graphics.endFill();
			m_disc.addChild(gloss);
			m_spinHost = new Sprite();
			m_disc.addChild(m_spinHost);
			hole = new Sprite();
			hole.graphics.beginFill(0x0A0A10, 1);
			hole.graphics.drawCircle(0, 0, r * 0.12);
			hole.graphics.endFill();
			hole.graphics.lineStyle(2, 0xFFFFFF, 0.9);
			hole.graphics.drawCircle(0, 0, r * 0.12);
			m_disc.addChild(hole);
			// Wave sits under the disc so it reads as a glowing rim, not a separate stroke.
			m_edgeViz = new DiscEdgeVisualizer(r);
			m_edgeViz.x = cx;
			m_edgeViz.y = cy;
			addChild(m_edgeViz);
			addChild(m_disc);
			if (!m_paused)
			{
				m_edgeViz.start();
			};
		}

		private function buildCase(cx:Number, cy:Number):void
		{
			var half:Number;
			var plastic:Sprite;
			var face:Sprite;
			var faceMask:Sprite;
			var spaceHost:Sprite;
			var dimOverlay:Sprite;
			var credit:TextField;
			var logo:MovieClip;
			var spaceMc:MovieClip;
			half = m_caseSize * 0.5;
			m_case = new Sprite();
			m_case.x = cx;
			m_case.y = cy;
			plastic = new Sprite();
			plastic.graphics.beginFill(0xD8DEE8, 0.22);
			plastic.graphics.drawRoundRect(-half - 6, -half - 6, m_caseSize + 12, m_caseSize + 12, 10, 10);
			plastic.graphics.endFill();
			plastic.graphics.lineStyle(1.5, 0xFFFFFF, 0.35);
			plastic.graphics.drawRoundRect(-half - 6, -half - 6, m_caseSize + 12, m_caseSize + 12, 10, 10);
			m_case.addChild(plastic);
			face = new Sprite();
			face.graphics.beginFill(0x080810, 1);
			face.graphics.drawRoundRect(-half, -half, m_caseSize, m_caseSize, 6, 6);
			face.graphics.endFill();
			m_case.addChild(face);
			faceMask = new Sprite();
			faceMask.graphics.beginFill(0xFFFFFF, 1);
			faceMask.graphics.drawRoundRect(-half, -half, m_caseSize, m_caseSize, 6, 6);
			faceMask.graphics.endFill();
			m_case.addChild(faceMask);
			spaceHost = new Sprite();
			spaceHost.mask = faceMask;
			m_case.addChild(spaceHost);
			spaceMc = MusicStageVisuals.attachMenuBg(spaceHost, MusicStageVisuals.SPACE_BG_ID,
				m_caseSize, m_caseSize);
			freezeClipTree(spaceMc);
			freezeClipTree(spaceHost);
			desaturateContrast(spaceHost);
			spaceHost.x = -half;
			spaceHost.y = -half;
			dimOverlay = new Sprite();
			dimOverlay.graphics.beginFill(0x050508, 0.22);
			dimOverlay.graphics.drawRoundRect(-half, -half, m_caseSize, m_caseSize, 6, 6);
			dimOverlay.graphics.endFill();
			dimOverlay.graphics.lineStyle(1, 0xFFFFFF, 0.14);
			dimOverlay.graphics.drawRoundRect(-half + 1, -half + 1, m_caseSize - 2, m_caseSize - 2, 5, 5);
			m_case.addChild(dimOverlay);
			m_logoHost = new Sprite();
			m_logoHost.y = -half * 0.10;
			m_case.addChild(m_logoHost);
			logo = MusicBrandArt.createSsf2Logo();
			if (logo)
			{
				// Prior ~1.24 case fit, then -20%.
				fitLogo(logo, m_caseSize * 1.24 * 0.80);
				desaturate(logo);
				freezeClipTree(logo);
				m_logoHost.addChild(logo);
			}
			else
			{
				drawLogoFallback(m_logoHost, m_caseSize * 0.7);
			};
			credit = makeText("mcleodgaming", 0, half * 0.58, 13, 0xE8E8F0, false, "center");
			credit.width = m_caseSize - 24;
			credit.x = -(m_caseSize - 24) * 0.5;
			m_case.addChild(credit);
			addChild(m_case);
		}

		private function buildInfoPanel(x0:Number, cy:Number):void
		{
			var maxW:Number;
			maxW = Math.max(220, m_w - x0 - 28);
			m_infoHost = new Sprite();
			m_infoHost.x = x0;
			m_infoHost.y = cy - 56;
			m_titleTf = makeText("—", 0, 0, 20, MusicTheme.ui(), true, "left");
			m_titleTf.width = maxW;
			m_titleTf.height = 56;
			m_titleTf.wordWrap = true;
			m_titleTf.multiline = true;
			m_infoHost.addChild(m_titleTf);
			m_artistTf = makeText(" ", 0, 56, 13, MusicTheme.uiSoft(), false, "left");
			m_artistTf.width = maxW;
			m_artistTf.height = 20;
			m_infoHost.addChild(m_artistTf);
			m_seriesTf = makeText(" ", 0, 76, 13, MusicTheme.uiSoft(), false, "left");
			m_seriesTf.width = maxW;
			m_seriesTf.height = 20;
			m_infoHost.addChild(m_seriesTf);
			addChild(m_infoHost);
		}

		private function refreshInfoText():void
		{
			var maxW:Number;
			if (!m_titleTf)
			{
				return;
			};
			maxW = m_titleTf.width;
			m_titleTf.text = m_trackTitle;
			fitTitleTwoLines(m_titleTf, maxW, 20);
			m_artistTf.y = m_titleTf.y + m_titleTf.height + 4;
			m_artistTf.text = m_trackArtist.length > 0 ? ("Artist: " + m_trackArtist) : " ";
			fitLabel(m_artistTf, maxW, 13, "left");
			m_seriesTf.y = m_artistTf.y + 20;
			m_seriesTf.text = m_seriesName.length > 0 ? ("Series: " + m_seriesName) : " ";
			fitLabel(m_seriesTf, maxW, 13, "left");
		}

		/** Shrink font until the title fits in at most two wrapped lines. */
		private function fitTitleTwoLines(tf:TextField, maxW:Number, startSize:int):void
		{
			var fmt:TextFormat;
			var s:int;
			var lineH:Number;
			if (!tf)
			{
				return;
			};
			tf.width = maxW;
			tf.wordWrap = true;
			tf.multiline = true;
			s = startSize;
			while (s >= 14)
			{
				fmt = new TextFormat("_sans", s, MusicTheme.ui(), true, null, null, null, null, "left");
				tf.defaultTextFormat = fmt;
				tf.setTextFormat(fmt);
				lineH = s + 8;
				tf.height = lineH * 2 + 4;
				if (tf.numLines <= 2 && tf.textHeight <= lineH * 2 + 2)
				{
					break;
				};
				s--;
			};
			tf.height = Math.min(tf.textHeight + 8, (s + 8) * 2 + 4);
		}

		private function freezeClipTree(obj:DisplayObject):void
		{
			var mc:MovieClip;
			var c:DisplayObjectContainer;
			var i:int;
			if (!obj)
			{
				return;
			};
			if (obj is MovieClip)
			{
				mc = MovieClip(obj);
				try
				{
					mc.stop();
					mc.gotoAndStop(mc.totalFrames > 1 ? mc.totalFrames : 1);
				}
				catch (stopErr:*)
				{
				};
			};
			if (!(obj is DisplayObjectContainer))
			{
				return;
			};
			c = DisplayObjectContainer(obj);
			i = 0;
			while (i < c.numChildren)
			{
				freezeClipTree(c.getChildAt(i));
				i++;
			};
		}

		private function desaturate(obj:DisplayObject):void
		{
			var m:Array;
			if (!obj)
			{
				return;
			};
			m = [
				0.35, 0.45, 0.15, 0, 0,
				0.35, 0.45, 0.15, 0, 0,
				0.35, 0.45, 0.15, 0, 0,
				0, 0, 0, 1, 0
			];
			try
			{
				obj.filters = [new ColorMatrixFilter(m)];
			}
			catch (filtErr:*)
			{
			};
		}

		/** Grayscale space BG with raised contrast for the album face. */
		private function desaturateContrast(obj:DisplayObject):void
		{
			var lr:Number;
			var lg:Number;
			var lb:Number;
			var c:Number;
			var o:Number;
			var m:Array;
			if (!obj)
			{
				return;
			};
			lr = 0.2126;
			lg = 0.7152;
			lb = 0.0722;
			c = 1.55;
			o = 128 * (1 - c);
			m = [
				lr * c, lg * c, lb * c, 0, o,
				lr * c, lg * c, lb * c, 0, o,
				lr * c, lg * c, lb * c, 0, o,
				0, 0, 0, 1, 0
			];
			try
			{
				obj.filters = [new ColorMatrixFilter(m)];
			}
			catch (filtErr:*)
			{
			};
		}

		private function fitLogo(logo:DisplayObject, maxSize:Number):void
		{
			var b:Rectangle;
			var s:Number;
			var wrap:Sprite;
			logo.scaleX = 1;
			logo.scaleY = 1;
			wrap = new Sprite();
			wrap.addChild(logo);
			b = logo.getBounds(wrap);
			if (b.width < 1 || b.height < 1)
			{
				logo.scaleX = 0.18;
				logo.scaleY = 0.18;
				logo.x = 0;
				logo.y = 0;
				return;
			};
			s = maxSize / Math.max(b.width, b.height);
			logo.scaleX = s;
			logo.scaleY = s;
			b = logo.getBounds(wrap);
			logo.x = -(b.left + b.right) * 0.5;
			logo.y = -(b.top + b.bottom) * 0.5;
			if (logo.parent == wrap)
			{
				wrap.removeChild(logo);
			};
		}

		private function drawLogoFallback(host:Sprite, size:Number):void
		{
			var tf:TextField;
			host.graphics.lineStyle(2, 0xAAAAAA, 0.9);
			host.graphics.drawCircle(0, 0, size * 0.35);
			tf = makeText("SSF2", -50, -12, 20, 0xCCCCCC, true, "center");
			tf.width = 100;
			tf.x = -50;
			host.addChild(tf);
		}

		private function makeText(text:String, x:Number, y:Number, size:int, color:uint,
			bold:Boolean, align:String):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.x = x;
			tf.y = y;
			tf.autoSize = TextFieldAutoSize.NONE;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.wordWrap = false;
			tf.multiline = false;
			tf.defaultTextFormat = new TextFormat("_sans", size, color, bold, null, null, null, null, align);
			tf.text = text;
			tf.height = size + 10;
			return (tf);
		}

		private function fitLabel(tf:TextField, maxW:Number, size:int, align:String):void
		{
			var fmt:TextFormat;
			var probe:TextField;
			var s:int;
			if (!tf)
			{
				return;
			};
			tf.width = maxW;
			s = size;
			while (s >= 11)
			{
				fmt = new TextFormat("_sans", s, tf.defaultTextFormat.color, tf.defaultTextFormat.bold,
					null, null, null, null, align);
				tf.defaultTextFormat = fmt;
				tf.setTextFormat(fmt);
				probe = new TextField();
				probe.autoSize = TextFieldAutoSize.LEFT;
				probe.defaultTextFormat = fmt;
				probe.text = tf.text;
				if (probe.textWidth <= maxW - 4)
				{
					break;
				};
				s--;
			};
			tf.height = s + 10;
		}
	}
}
