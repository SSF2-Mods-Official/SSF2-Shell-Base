package
{
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import ssf2mm.shared.LucideIcons;
	import ssf2mm.shared.EngineRefs;

	/**
	 * YouTube-style now-playing strip. Expanded mode is a fullscreen CD showcase
	 * (jewel case + spinning disc + side spectrum) with a centered mini bar.
	 */
	public class MusicNowPlayingBar extends Sprite
	{
		public static const BAR_H:int = 72;
		private static const VIZ_BARS:int = 48;
		/** Extra nudge so controls sit slightly lower in the bar. */
		private static const Y_PAD:int = 12;

		private var m_gw:int;
		private var m_gh:int;
		private var m_expanded:Boolean;
		private var m_bar:Sprite;
		private var m_previewLayer:Sprite;
		private var m_previewMask:Sprite;
		private var m_expandedStage:MusicExpandedPlayer;
		private var m_progress:Sprite;
		private var m_viz:Sprite;
		private var m_btnPrev:Sprite;
		private var m_btnPlay:Sprite;
		private var m_btnNext:Sprite;
		private var m_btnRepeat:Sprite;
		private var m_timeTf:TextField;
		private var m_titleTf:TextField;
		private var m_metaTf:TextField;
		private var m_stageHit:Sprite;
		private var m_seriesHit:Sprite;
		private var m_btnExpand:Sprite;
		private var m_btnSettings:Sprite;
		private var m_btnVolume:Sprite;
		private var m_volPopup:Sprite;
		private var m_volTrack:Sprite;
		private var m_volKnob:Sprite;
		private var m_volDragging:Boolean;
		private var m_cdDisc:Sprite;
		private var m_cdArtHost:Sprite;
		private var m_spinHost:Sprite;
		private var m_spinIcon:DisplayObject;
		private var m_spinAngle:Number;
		private var m_vizPhase:Number;
		private var m_onPrev:Function;
		private var m_onPlay:Function;
		private var m_onNext:Function;
		private var m_onToggleExpand:Function;
		private var m_onSettings:Function;
		private var m_onVolume:Function;
		private var m_onSeek:Function;
		private var m_onRepeat:Function;
		private var m_onStageClick:Function;
		private var m_onSeriesClick:Function;
		private var m_onTitleClick:Function;
		private var m_titleHit:Sprite;
		private var m_titleScroll:Number;
		private var m_metaScroll:Number;
		private var m_titlePause:int;
		private var m_titleDir:int;
		private var m_metaDir:int;
		private var m_metaPause:int;
		private var m_paused:Boolean;
		private var m_repeatOne:Boolean;
		private var m_shuffle:Boolean;
		private var m_posMs:Number;
		private var m_durMs:Number;
		private var m_trackTitle:String;
		private var m_trackArtist:String;
		private var m_stageName:String;
		private var m_seriesName:String;
		private var m_cdStageId:String;
		private var m_pendingSpin:DisplayObject;

		public function MusicNowPlayingBar()
		{
			super();
			m_expanded = false;
			m_spinAngle = 0;
			m_vizPhase = 0;
			m_paused = true;
			m_repeatOne = true;
			m_posMs = 0;
			m_durMs = 0;
			m_stageName = "";
			m_seriesName = "";
			m_trackTitle = "—";
			m_trackArtist = "";
			m_cdStageId = null;
			m_titleScroll = 0;
			m_metaScroll = 0;
			m_titlePause = 0;
			m_metaPause = 0;
			mouseEnabled = true;
			mouseChildren = true;
		}

		public function get expanded():Boolean
		{
			return (m_expanded);
		}

		public function setCallbacks(onPrev:Function, onPlay:Function, onNext:Function, onToggle:Function):void
		{
			m_onPrev = onPrev;
			m_onPlay = onPlay;
			m_onNext = onNext;
			m_onToggleExpand = onToggle;
		}

		public function setSettingsCallback(fn:Function):void
		{
			m_onSettings = fn;
		}

		public function setVolumeCallback(fn:Function):void
		{
			m_onVolume = fn;
		}

		public function setSeekCallback(fn:Function):void
		{
			m_onSeek = fn;
		}

		public function setRepeatCallback(fn:Function):void
		{
			m_onRepeat = fn;
		}


		public function setMetaNavigateCallbacks(onStage:Function, onSeries:Function):void
		{
			m_onStageClick = onStage;
			m_onSeriesClick = onSeries;
		}

		public function setTitleNavigateCallback(onTitle:Function):void
		{
			m_onTitleClick = onTitle;
		}

		public function layout(gw:int, gh:int):void
		{
			m_gw = gw;
			m_gh = gh;
			rebuild();
		}

		public function setExpanded(on:Boolean):void
		{
			m_expanded = on;
			rebuild();
		}

		public function setPlayback(paused:Boolean, posMs:Number, durMs:Number):void
		{
			m_paused = paused;
			m_posMs = posMs;
			m_durMs = durMs;
			paintPlayIcon();
			if (m_timeTf)
			{
				m_timeTf.text = formatTime(m_posMs) + " / " + formatTime(m_durMs);
			};
			paintVisualizer();
		}

		public function setRepeatOne(on:Boolean):void
		{
			m_repeatOne = on;
			paintRepeatIcon();
		}

		public function setShuffle(on:Boolean):void
		{
			m_shuffle = on;
			paintRepeatIcon();
		}

		public function setTrack(title:String, artist:String, stageName:String, seriesName:String):void
		{
			var meta:String;
			var titleChanged:Boolean;
			var metaChanged:Boolean;
			m_trackTitle = title && title.length > 0 ? title : "—";
			m_trackArtist = artist || "";
			titleChanged = !(m_titleTf && m_titleTf.text == m_trackTitle);
			m_stageName = stageName || "";
			m_seriesName = seriesName || "";
			if (m_titleTf && titleChanged)
			{
				m_titleTf.text = m_trackTitle;
				m_titleTf.scrollH = 0;
				m_titleScroll = 0;
				m_titleDir = 1;
				m_titlePause = 35;
			};
			meta = "";
			if (m_trackArtist)
			{
				meta = m_trackArtist;
			};
			if (m_stageName)
			{
				meta = meta.length > 0 ? (meta + " · " + m_stageName) : m_stageName;
			};
			if (m_seriesName)
			{
				meta = meta.length > 0 ? (meta + " · " + m_seriesName) : m_seriesName;
			};
			metaChanged = !(m_metaTf && m_metaTf.text == (meta.length > 0 ? meta : " "));
			if (m_metaTf && metaChanged)
			{
				m_metaTf.text = meta.length > 0 ? meta : " ";
				m_metaTf.scrollH = 0;
				m_metaScroll = 0;
				m_metaDir = 1;
				m_metaPause = 35;
			};
			if (metaChanged)
			{
				layoutMetaHits();
			};
			if (titleChanged)
			{
				layoutTitleHit();
			};
			if (m_expandedStage)
			{
				m_expandedStage.setTrack(m_trackTitle, m_trackArtist, m_stageName, m_seriesName);
			};
		}

		public function tickMarquee():void
		{
			var maxW:Number;
			if (m_expanded || !m_titleTf)
			{
				return;
			};
			maxW = Math.max(40, m_gw - 520);
			stepMarquee(m_metaTf, maxW, false);
		}

		private function stepMarquee(tf:TextField, maxW:Number, isTitle:Boolean):void
		{
			var scroll:Number;
			var pause:int;
			var maxH:int;
			var dir:int;
			if (!tf)
			{
				return;
			};
			tf.autoSize = TextFieldAutoSize.NONE;
			tf.wordWrap = false;
			tf.multiline = false;
			tf.width = maxW;
			maxH = tf.maxScrollH;
			if (maxH <= 0)
			{
				tf.scrollH = 0;
				return;
			};
			scroll = isTitle ? m_titleScroll : m_metaScroll;
			pause = isTitle ? m_titlePause : m_metaPause;
			dir = isTitle ? m_titleDir : m_metaDir;
			if (dir == 0)
			{
				dir = 1;
			};
			if (pause > 0)
			{
				pause--;
			}
			else
			{
				scroll += 0.55 * dir;
				if (scroll >= maxH)
				{
					scroll = maxH;
					dir = -1;
					pause = 36;
				}
				else if (scroll <= 0)
				{
					scroll = 0;
					dir = 1;
					pause = 36;
				};
			};
			tf.scrollH = int(scroll);
			if (isTitle)
			{
				m_titleScroll = scroll;
				m_titlePause = pause;
				m_titleDir = dir;
			}
			else
			{
				m_metaScroll = scroll;
				m_metaPause = pause;
				m_metaDir = dir;
			};
		}

		public function setSpinIcon(icon:DisplayObject):void
		{
			m_pendingSpin = icon;
			if (m_expandedStage)
			{
				m_expandedStage.setSpinIcon(icon);
			};
			while (m_spinHost && m_spinHost.numChildren > 0)
			{
				m_spinHost.removeChildAt(0);
			};
			m_spinIcon = icon;
			if (!m_spinHost || !icon || m_expanded)
			{
				return;
			};
			MusicStageVisuals.mountCenteredIcon(m_spinHost, icon, 26);
		}

		/** Stage preview clipped to the CD disc (behind the series symbol). */
		public function setCdStageArt(stageId:String):void
		{
			var art:DisplayObject;
			var mask:Sprite;
			var dim:Sprite;
			var tryId:String;
			m_cdStageId = stageId;
			if (m_expandedStage)
			{
				m_expandedStage.setDiscStage(stageId);
			};
			if (!m_cdArtHost || m_expanded)
			{
				return;
			};
			while (m_cdArtHost.numChildren > 0)
			{
				m_cdArtHost.removeChildAt(0);
			};
			m_cdArtHost.mask = null;
			tryId = stageId;
			if (!tryId || tryId == MusicStageVisuals.OTHER_STAGE_ID)
			{
				tryId = MusicStageVisuals.WAITING_ROOM_ID;
			};
			art = MusicStageVisuals.attachPreviewBitmap(m_cdArtHost, tryId, 52, 52);
			if (!art && tryId != MusicStageVisuals.WAITING_ROOM_ID)
			{
				while (m_cdArtHost.numChildren > 0)
				{
					m_cdArtHost.removeChildAt(0);
				};
				art = MusicStageVisuals.attachPreviewBitmap(m_cdArtHost, MusicStageVisuals.WAITING_ROOM_ID, 52, 52);
				m_cdStageId = MusicStageVisuals.WAITING_ROOM_ID;
			};
			if (!art)
			{
				while (m_cdArtHost.numChildren > 0)
				{
					m_cdArtHost.removeChildAt(0);
				};
				art = MusicStageVisuals.attachTileArt(m_cdArtHost, tryId, 52, 52);
				if (art)
				{
					art.x -= 26;
					art.y -= 26;
				};
			};
			mask = new Sprite();
			mask.graphics.beginFill(0xFFFFFF, 1);
			mask.graphics.drawCircle(0, 0, 24);
			mask.graphics.endFill();
			m_cdArtHost.addChild(mask);
			m_cdArtHost.mask = mask;
			dim = new Sprite();
			dim.graphics.beginFill(0x050508, 0.25);
			dim.graphics.drawCircle(0, 0, 24);
			dim.graphics.endFill();
			m_cdArtHost.addChild(dim);
		}

		public function clearFullscreenPreview():void
		{
			if (m_expandedStage)
			{
				if (m_expandedStage.parent)
				{
					m_expandedStage.parent.removeChild(m_expandedStage);
				};
				m_expandedStage = null;
			};
			if (!m_previewLayer)
			{
				return;
			};
			while (m_previewLayer.numChildren > 0)
			{
				m_previewLayer.removeChildAt(0);
			};
			m_previewLayer.graphics.clear();
			// Keep mask assigned — clearing it makes the white mask sprite paint as a full-screen fill.
			if (m_previewMask)
			{
				m_previewLayer.mask = m_previewMask;
			};
			m_previewLayer.visible = m_expanded;
		}

		/**
		 * Spin/viz tick. Pass livePaused from playback state so expand rebuild /
		 * stale setPlayback cannot freeze the disc forever.
		 */
		public function tickSpin(livePaused:Boolean = true):void
		{
			var wasPaused:Boolean = m_paused;
			m_paused = livePaused;
			if (!m_paused)
			{
				m_vizPhase += 0.18;
				if (m_cdDisc && !m_expanded)
				{
					m_spinAngle += 1.5;
					m_cdDisc.rotation = m_spinAngle;
				};
			};
			// Paused bars are static; setPlayback repaints on seek / state change.
			if (!m_paused || !wasPaused)
			{
				paintVisualizer();
			};
			if (m_expandedStage)
			{
				m_expandedStage.tick(m_paused);
			};
		}

		private function rebuild():void
		{
			var y0:int;
			var savedTitle:String;
			var savedMeta:String;
			var savedSpin:DisplayObject;
			var savedStage:String;
			var ctrlX:int;
			savedTitle = m_trackTitle || (m_titleTf ? m_titleTf.text : "—");
			savedMeta = m_metaTf ? m_metaTf.text : " ";
			savedSpin = m_pendingSpin || m_spinIcon;
			savedStage = m_cdStageId;
			while (numChildren > 0)
			{
				removeChildAt(0);
			};
			m_expandedStage = null;
			m_previewLayer = new Sprite();
			m_previewMask = new Sprite();
			m_previewMask.graphics.beginFill(0xFFFFFF, 1);
			m_previewMask.graphics.drawRect(0, 0, m_gw, Math.max(1, m_gh - BAR_H));
			m_previewMask.graphics.endFill();
			addChild(m_previewLayer);
			addChild(m_previewMask);
			m_previewLayer.mask = m_previewMask;
			m_bar = new Sprite();
			y0 = m_gh - BAR_H;
			m_bar.y = y0;
			m_bar.graphics.beginFill(0x0A0A10, 0.96);
			m_bar.graphics.drawRect(0, 0, m_gw, BAR_H);
			m_bar.graphics.endFill();
			addChild(m_bar);
			m_progress = new Sprite();
			m_bar.addChild(m_progress);
			m_viz = new Sprite();
			m_bar.addChild(m_viz);
			paintVisualizer();
			m_progress.buttonMode = true;
			m_progress.addEventListener(MouseEvent.CLICK, onProgressClick);
			m_viz.mouseEnabled = false;
			if (m_expanded)
			{
				ctrlX = int(m_gw * 0.5 - 82);
				m_btnPrev = hitSprite(ctrlX, 12 + Y_PAD, 28, 28, onPrev);
				paintPrevIcon();
				m_btnPlay = hitSprite(ctrlX + 32, 5 + Y_PAD, 42, 42, onPlay);
				paintPlayIcon();
				m_btnNext = hitSprite(ctrlX + 80, 12 + Y_PAD, 28, 28, onNext);
				paintNextIcon();
				m_btnRepeat = hitSprite(ctrlX + 116, 12 + Y_PAD, 28, 28, onRepeat);
				paintRepeatIcon();
				m_timeTf = label(formatTime(m_posMs) + " / " + formatTime(m_durMs),
					ctrlX + 152, 20 + Y_PAD, 12, MusicTheme.uiSoft());
				m_titleTf = null;
				m_metaTf = null;
				m_stageHit = null;
				m_seriesHit = null;
				m_titleHit = null;
				m_cdDisc = null;
				m_cdArtHost = null;
				m_spinHost = null;
			}
			else
			{
				m_btnPrev = hitSprite(14, 12 + Y_PAD, 28, 28, onPrev);
				paintPrevIcon();
				m_btnPlay = hitSprite(44, 5 + Y_PAD, 42, 42, onPlay);
				paintPlayIcon();
				m_btnNext = hitSprite(92, 12 + Y_PAD, 28, 28, onNext);
				paintNextIcon();
				m_btnRepeat = hitSprite(128, 12 + Y_PAD, 28, 28, onRepeat);
				paintRepeatIcon();
				m_timeTf = label(formatTime(m_posMs) + " / " + formatTime(m_durMs), 164, 20 + Y_PAD, 12, MusicTheme.uiSoft());
				buildCd();
				if (savedStage)
				{
					setCdStageArt(savedStage);
				};
				if (savedSpin)
				{
					setSpinIcon(savedSpin);
				};
				if (m_cdDisc)
				{
					m_cdDisc.rotation = m_spinAngle;
					m_cdDisc.visible = true;
				};
				m_titleTf = label(savedTitle, 300, 10 + Y_PAD, 10, MusicTheme.ui());
				m_titleTf.autoSize = TextFieldAutoSize.NONE;
				m_titleTf.wordWrap = false;
				m_titleTf.multiline = false;
				m_titleTf.width = Math.max(80, m_gw - 430);
				m_titleTf.width = Math.max(40, m_gw - 520);
				m_titleTf.height = 16;
				m_metaTf = label(savedMeta, 300, 28 + Y_PAD, 10, MusicTheme.uiSoft());
				m_metaTf.autoSize = TextFieldAutoSize.NONE;
				m_metaTf.wordWrap = false;
				m_metaTf.multiline = false;
				m_metaTf.width = Math.max(40, m_gw - 520);
				m_stageHit = new Sprite();
				m_seriesHit = new Sprite();
				m_titleHit = new Sprite();
				m_bar.addChild(m_stageHit);
				m_bar.addChild(m_seriesHit);
				m_bar.addChild(m_titleHit);
				layoutMetaHits();
				layoutTitleHit();
			};
			m_btnSettings = hitSprite(m_gw - 88, 8 + Y_PAD, 36, 36, onSettingsClick);
			m_btnVolume = hitSprite(m_gw - 128, 8 + Y_PAD, 36, 36, onVolumeClick);
			paintVolumeIcon();
			buildVolumePopup();
			paintSettingsIcon();
			m_btnExpand = hitSprite(m_gw - 48, 8 + Y_PAD, 40, 40, onToggle);
			paintExpandIcon();
			m_previewLayer.visible = m_expanded;
			if (m_expanded)
			{
				m_previewLayer.graphics.clear();
				m_previewLayer.graphics.beginFill(0x05050C, 1);
				m_previewLayer.graphics.drawRect(0, 0, m_gw, Math.max(1, m_gh - BAR_H));
				m_previewLayer.graphics.endFill();
				m_expandedStage = new MusicExpandedPlayer();
				m_expandedStage.layout(m_gw, Math.max(1, m_gh - BAR_H));
				m_expandedStage.setTrack(m_trackTitle, m_trackArtist, m_stageName, m_seriesName);
				if (savedStage)
				{
					m_expandedStage.setDiscStage(savedStage);
				};
				if (savedSpin)
				{
					m_expandedStage.setSpinIcon(savedSpin);
				};
				m_previewLayer.addChild(m_expandedStage);
			};
		}

		private function layoutMetaHits():void
		{
			var base:String;
			var stageStart:int;
			var seriesStart:int;
			var fmt:TextFormat;
			var probe:TextField;
			var x0:Number;
			var y0:Number;
			var wStage:Number;
			var wSeries:Number;
			if (!m_metaTf || !m_stageHit || !m_seriesHit)
			{
				return;
			};
			while (m_stageHit.numChildren > 0)
			{
				m_stageHit.removeChildAt(0);
			};
			while (m_seriesHit.numChildren > 0)
			{
				m_seriesHit.removeChildAt(0);
			};
			m_stageHit.graphics.clear();
			m_seriesHit.graphics.clear();
			m_stageHit.buttonMode = false;
			m_seriesHit.buttonMode = false;
			m_stageHit.mouseEnabled = false;
			m_seriesHit.mouseEnabled = false;
			if (!m_stageName && !m_seriesName)
			{
				return;
			};
			base = m_metaTf.text || "";
			stageStart = m_stageName ? base.lastIndexOf(m_stageName) : -1;
			seriesStart = m_seriesName ? base.lastIndexOf(m_seriesName) : -1;
			fmt = m_metaTf.defaultTextFormat;
			probe = new TextField();
			probe.autoSize = TextFieldAutoSize.LEFT;
			probe.defaultTextFormat = fmt;
			x0 = m_metaTf.x;
			y0 = m_metaTf.y;
			if (stageStart >= 0 && m_stageName)
			{
				probe.text = base.substring(0, stageStart);
				wStage = probe.textWidth;
				probe.text = m_stageName;
				m_stageHit.x = x0 + wStage;
				m_stageHit.y = y0;
				m_stageHit.graphics.beginFill(0xFFFFFF, 0.001);
				m_stageHit.graphics.drawRect(0, 0, Math.max(12, probe.textWidth + 4), 16);
				m_stageHit.graphics.endFill();
				m_stageHit.buttonMode = true;
				m_stageHit.useHandCursor = true;
				m_stageHit.mouseEnabled = true;
				m_stageHit.addEventListener(MouseEvent.CLICK, onStageHit);
			};
			if (seriesStart >= 0 && m_seriesName)
			{
				probe.text = base.substring(0, seriesStart);
				wSeries = probe.textWidth;
				probe.text = m_seriesName;
				m_seriesHit.x = x0 + wSeries;
				m_seriesHit.y = y0;
				m_seriesHit.graphics.beginFill(0xFFFFFF, 0.001);
				m_seriesHit.graphics.drawRect(0, 0, Math.max(12, probe.textWidth + 4), 16);
				m_seriesHit.graphics.endFill();
				m_seriesHit.buttonMode = true;
				m_seriesHit.useHandCursor = true;
				m_seriesHit.mouseEnabled = true;
				m_seriesHit.addEventListener(MouseEvent.CLICK, onSeriesHit);
			};
		}

		private function layoutTitleHit():void
		{
			var w:Number;
			if (!m_titleHit || !m_titleTf)
			{
				return;
			};
			while (m_titleHit.numChildren > 0)
			{
				m_titleHit.removeChildAt(0);
			};
			m_titleHit.graphics.clear();
			w = Math.max(80, m_gw - 380);
			m_titleHit.x = m_titleTf.x;
			m_titleHit.y = m_titleTf.y;
			m_titleHit.graphics.beginFill(0xFFFFFF, 0.001);
			m_titleHit.graphics.drawRect(0, 0, w, 18);
			m_titleHit.graphics.endFill();
			m_titleHit.buttonMode = m_onTitleClick != null;
			m_titleHit.useHandCursor = m_onTitleClick != null;
			m_titleHit.mouseEnabled = m_onTitleClick != null;
			if (m_onTitleClick != null)
			{
				m_titleHit.addEventListener(MouseEvent.CLICK, onTitleHit);
			};
		}

		private function onTitleHit(e:MouseEvent):void
		{
			e.stopPropagation();
			if (m_onTitleClick != null)
			{
				m_onTitleClick();
			};
		}

		private function onStageHit(e:MouseEvent):void
		{
			e.stopPropagation();
			if (m_onStageClick != null)
			{
				m_onStageClick();
			};
		}

		private function onSeriesHit(e:MouseEvent):void
		{
			e.stopPropagation();
			if (m_onSeriesClick != null)
			{
				m_onSeriesClick();
			};
		}

		private function buildCd():void
		{
			var ring:Sprite;
			var hole:Sprite;
			var clip:Sprite;
			m_cdDisc = new Sprite();
			m_cdDisc.x = 270;
			m_cdDisc.y = 28 + Y_PAD;
			clip = new Sprite();
			clip.graphics.beginFill(0xFFFFFF, 1);
			clip.graphics.drawCircle(0, 0, 26);
			clip.graphics.endFill();
			m_cdDisc.addChild(clip);
			m_cdArtHost = new Sprite();
			m_cdDisc.addChild(m_cdArtHost);
			m_cdDisc.mask = clip;
			ring = new Sprite();
			ring.graphics.lineStyle(2, MusicTheme.ui(), 0.95);
			ring.graphics.drawCircle(0, 0, 25);
			m_cdDisc.addChild(ring);
			m_spinHost = new Sprite();
			m_cdDisc.addChild(m_spinHost);
			hole = new Sprite();
			hole.graphics.beginFill(0x0A0A10, 1);
			hole.graphics.drawCircle(0, 0, 4.5);
			hole.graphics.endFill();
			hole.graphics.lineStyle(1.5, MusicTheme.ui(), 0.95);
			hole.graphics.drawCircle(0, 0, 4.5);
			m_cdDisc.addChild(hole);
			m_bar.addChild(m_cdDisc);
		}

		private function paintPrevIcon():void
		{
			var g:*;
			if (!m_btnPrev)
			{
				return;
			};
			while (m_btnPrev.numChildren > 0)
			{
				m_btnPrev.removeChildAt(0);
			};
			g = m_btnPrev.graphics;
			g.clear();
			g.beginFill(0xFFFFFF, 0.001);
			g.drawRect(0, 0, 28, 28);
			g.endFill();
			g.beginFill(MusicTheme.ui(), 1);
			// Skip-back: left-pointing triangle + leading bar
			g.drawRect(5, 7, 3, 14);
			g.moveTo(22, 7);
			g.lineTo(10, 14);
			g.lineTo(22, 21);
			g.lineTo(22, 7);
			g.endFill();
		}

		private function paintPlayIcon():void
		{
			var g:*;
			if (!m_btnPlay)
			{
				return;
			};
			while (m_btnPlay.numChildren > 0)
			{
				m_btnPlay.removeChildAt(0);
			};
			g = m_btnPlay.graphics;
			g.clear();
			g.beginFill(0xFFFFFF, 0.001);
			g.drawRect(0, 0, 42, 42);
			g.endFill();
			g.beginFill(MusicTheme.ui(), 1);
			if (m_paused)
			{
				g.moveTo(14, 10);
				g.lineTo(32, 21);
				g.lineTo(14, 32);
				g.lineTo(14, 10);
			}
			else
			{
				g.drawRoundRect(13, 10, 5, 22, 2, 2);
				g.drawRoundRect(24, 10, 5, 22, 2, 2);
			};
			g.endFill();
		}

		private function paintNextIcon():void
		{
			var g:*;
			if (!m_btnNext)
			{
				return;
			};
			while (m_btnNext.numChildren > 0)
			{
				m_btnNext.removeChildAt(0);
			};
			g = m_btnNext.graphics;
			g.clear();
			g.beginFill(0xFFFFFF, 0.001);
			g.drawRect(0, 0, 28, 28);
			g.endFill();
			g.beginFill(MusicTheme.ui(), 1);
			g.moveTo(6, 7);
			g.lineTo(18, 14);
			g.lineTo(6, 21);
			g.lineTo(6, 7);
			g.drawRect(20, 7, 3, 14);
			g.endFill();
		}

		private function paintRepeatIcon():void
		{
			var icon:Sprite;
			var col:uint;
			var which:Class;
			if (!m_btnRepeat)
			{
				return;
			};
			if (m_shuffle && !m_repeatOne)
			{
				which = LucideIcons.SHUFFLE;
				col = MusicTheme.ui();
			}
			else if (m_repeatOne)
			{
				which = LucideIcons.REPEAT_1;
				col = MusicTheme.ui();
			}
			else
			{
				which = LucideIcons.REPEAT;
				col = 0x888899;
			};
			while (m_btnRepeat.numChildren > 0)
			{
				m_btnRepeat.removeChildAt(0);
			};
			m_btnRepeat.graphics.clear();
			m_btnRepeat.graphics.beginFill(0xFFFFFF, 0.001);
			m_btnRepeat.graphics.drawRect(0, 0, 28, 28);
			m_btnRepeat.graphics.endFill();
			icon = new Sprite();
			icon.mouseEnabled = false;
			LucideIcons.draw(icon.graphics, which, 28, col, 4);
			m_btnRepeat.addChild(icon);
		}

		private function paintExpandIcon():void
		{
			var icon:Sprite;
			if (!m_btnExpand)
			{
				return;
			};
			while (m_btnExpand.numChildren > 0)
			{
				m_btnExpand.removeChildAt(0);
			};
			m_btnExpand.graphics.clear();
			m_btnExpand.graphics.beginFill(0xFFFFFF, 0.001);
			m_btnExpand.graphics.drawRect(0, 0, 40, 40);
			m_btnExpand.graphics.endFill();
			icon = new Sprite();
			icon.mouseEnabled = false;
			LucideIcons.draw(icon.graphics,
				m_expanded ? LucideIcons.CHEVRON_DOWN : LucideIcons.CHEVRON_UP,
				40, MusicTheme.ui(), 8);
			m_btnExpand.addChild(icon);
		}

		private function paintSettingsIcon():void
		{
			var icon:Sprite;
			if (!m_btnSettings)
			{
				return;
			};
			while (m_btnSettings.numChildren > 0)
			{
				m_btnSettings.removeChildAt(0);
			};
			m_btnSettings.graphics.clear();
			m_btnSettings.graphics.beginFill(0xFFFFFF, 0.001);
			m_btnSettings.graphics.drawRect(0, 0, 36, 36);
			m_btnSettings.graphics.endFill();
			icon = new Sprite();
			icon.mouseEnabled = false;
			LucideIcons.draw(icon.graphics, LucideIcons.SETTINGS, 36, MusicTheme.ui(), 6);
			m_btnSettings.addChild(icon);
		}

		private function onSettingsClick():void
		{
			if (m_onSettings != null)
			{
				m_onSettings();
			};
		}

		/** Android-style pulsing equalizer strip doubles as a progress meter. */
		private function paintVolumeIcon():void
		{
			var icon:Sprite;
			var g:Graphics;
			if (!m_btnVolume)
			{
				return;
			};
			while (m_btnVolume.numChildren > 0)
			{
				m_btnVolume.removeChildAt(0);
			};
			m_btnVolume.graphics.clear();
			m_btnVolume.graphics.beginFill(0xFFFFFF, 0.001);
			m_btnVolume.graphics.drawRect(0, 0, 36, 36);
			m_btnVolume.graphics.endFill();
			icon = new Sprite();
			icon.mouseEnabled = false;
			g = icon.graphics;
			g.lineStyle(2, MusicTheme.ui(), 1);
			g.beginFill(MusicTheme.ui(), 1);
			g.moveTo(8, 14);
			g.lineTo(13, 14);
			g.lineTo(20, 8);
			g.lineTo(20, 28);
			g.lineTo(13, 22);
			g.lineTo(8, 22);
			g.lineTo(8, 14);
			g.endFill();
			g.moveTo(24, 13);
			g.curveTo(29, 18, 24, 23);
			g.moveTo(27, 10);
			g.curveTo(34, 18, 27, 26);
			m_btnVolume.addChild(icon);
		}

		private function buildVolumePopup():void
		{
			var bg:Sprite;
			m_volPopup = new Sprite();
			m_volPopup.x = m_gw - 196;
			m_volPopup.y = -46;
			bg = new Sprite();
			bg.graphics.beginFill(0x16161F, 0.98);
			bg.graphics.drawRoundRect(0, 0, 176, 40, 8, 8);
			bg.graphics.endFill();
			m_volPopup.addChild(bg);
			m_volTrack = new Sprite();
			m_volTrack.x = 16;
			m_volTrack.y = 12;
			m_volTrack.graphics.beginFill(0x3A3A48, 1);
			m_volTrack.graphics.drawRoundRect(0, 6, 144, 4, 2, 2);
			m_volTrack.graphics.endFill();
			m_volTrack.graphics.beginFill(0xFFFFFF, 0.001);
			m_volTrack.graphics.drawRect(0, 0, 144, 20);
			m_volTrack.graphics.endFill();
			m_volTrack.buttonMode = true;
			m_volTrack.addEventListener(MouseEvent.MOUSE_DOWN, onVolumeDown);
			m_volKnob = new Sprite();
			m_volKnob.mouseEnabled = false;
			m_volKnob.graphics.beginFill(0xFFFFFF, 1);
			m_volKnob.graphics.drawCircle(0, 8, 6);
			m_volKnob.graphics.endFill();
			m_volTrack.addChild(m_volKnob);
			m_volPopup.addChild(m_volTrack);
			m_volPopup.visible = false;
			m_bar.addChild(m_volPopup);
		}

		private function onVolumeClick():void
		{
			if (!m_volPopup)
			{
				return;
			};
			m_volPopup.visible = !m_volPopup.visible;
			if (parent)
			{
				parent.setChildIndex(this, parent.numChildren - 1);
			};
			if (m_volPopup.visible)
			{
				placeVolumeKnob(readBgmVolume());
				m_bar.setChildIndex(m_volPopup, m_bar.numChildren - 1);
			};
		}

		private function readBgmVolume():Number
		{
			var vol:Number;
			var SD:*;
			vol = 1;
			try
			{
				SD = EngineRefs.ssf2("util.SaveData");
				if (SD && SD["BGVolumeLevel"] != null)
				{
					vol = Number(SD["BGVolumeLevel"]);
				};
			}
			catch (err:*)
			{
			};
			if (!(vol >= 0))
			{
				vol = 0;
			};
			if (vol > 1)
			{
				vol = 1;
			};
			return (vol);
		}

		private function placeVolumeKnob(vol:Number):void
		{
			if (m_volKnob)
			{
				m_volKnob.x = vol * 144;
			};
		}

		private function onVolumeDown(e:MouseEvent):void
		{
			m_volDragging = true;
			e.stopPropagation();
			applyVolumeFromPointer(false);
			if (m_volTrack.stage)
			{
				m_volTrack.stage.addEventListener(MouseEvent.MOUSE_MOVE, onVolumeMove);
				m_volTrack.stage.addEventListener(MouseEvent.MOUSE_UP, onVolumeUp);
			};
		}

		private function onVolumeMove(e:MouseEvent):void
		{
			if (!m_volDragging)
			{
				return;
			};
			applyVolumeFromPointer(false);
		}

		private function onVolumeUp(e:MouseEvent):void
		{
			if (m_volTrack && m_volTrack.stage)
			{
				m_volTrack.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onVolumeMove);
				m_volTrack.stage.removeEventListener(MouseEvent.MOUSE_UP, onVolumeUp);
			};
			if (m_volDragging)
			{
				applyVolumeFromPointer(true);
			};
			m_volDragging = false;
		}

		private function applyVolumeFromPointer(save:Boolean):void
		{
			var local:Number;
			var vol:Number;
			if (!m_volTrack)
			{
				return;
			};
			local = m_volTrack.mouseX;
			if (local < 0)
			{
				local = 0;
			};
			if (local > 144)
			{
				local = 144;
			};
			vol = local / 144;
			placeVolumeKnob(vol);
			if (m_onVolume != null)
			{
				m_onVolume(vol, save);
			};
		}

		private function paintVisualizer():void
		{
			var i:int;
			var n:int;
			var ratio:Number;
			var bw:Number;
			var gap:Number;
			var x:Number;
			var h:Number;
			var mid:Number;
			var live:Number;
			var filled:Boolean;
			if (!m_viz || !m_progress)
			{
				return;
			};
			m_progress.graphics.clear();
			m_viz.graphics.clear();
			m_progress.graphics.beginFill(0x1A1A22, 1);
			m_progress.graphics.drawRect(0, 0, m_gw, 10);
			m_progress.graphics.endFill();
			n = VIZ_BARS;
			bw = Math.max(2, (m_gw - 8) / n - 1.5);
			gap = 1.5;
			ratio = (m_durMs > 0) ? Math.max(0, Math.min(1, m_posMs / m_durMs)) : 0;
			i = 0;
			while (i < n)
			{
				x = 4 + i * (bw + gap);
				mid = 0.35 + 0.55 * Math.abs(Math.sin(i * 0.55 + m_vizPhase));
				if (m_paused)
				{
					live = 0.22 + 0.08 * ((i % 3) / 2);
				}
				else
				{
					live = mid;
				};
				h = Math.max(2, 8 * live);
				filled = (i / n) <= ratio;
				m_viz.graphics.beginFill(filled ? MusicTheme.ui() : MusicTheme.mix(MusicTheme.ui(), 0x3A3A48, 0.65),
					filled ? 1 : 0.7);
				m_viz.graphics.drawRect(x, 5 - h * 0.5, bw, h);
				m_viz.graphics.endFill();
				i++;
			};
		}

		private function onProgressClick(e:MouseEvent):void
		{
			var ratio:Number;
			if (m_onSeek == null || m_gw < 1)
			{
				return;
			};
			ratio = Math.max(0, Math.min(1, e.localX / m_gw));
			m_onSeek(ratio);
		}

		private function hitSprite(x:int, y:int, w:int, h:int, fn:Function):Sprite
		{
			var s:Sprite;
			s = new Sprite();
			s.x = x;
			s.y = y;
			s.buttonMode = true;
			s.useHandCursor = true;
			s.addEventListener(MouseEvent.CLICK, function (e:MouseEvent):void
			{
				e.stopPropagation();
				if (fn != null)
				{
					fn();
				};
			});
			m_bar.addChild(s);
			return (s);
		}

		private function label(text:String, x:int, y:int, size:int, color:uint):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.x = x;
			tf.y = y;
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("_sans", size, color, false);
			tf.text = text;
			m_bar.addChild(tf);
			return (tf);
		}

		private function onPrev():void
		{
			if (m_onPrev != null)
			{
				m_onPrev();
			};
		}

		private function onPlay():void
		{
			if (m_onPlay != null)
			{
				m_onPlay();
			};
		}

		private function onNext():void
		{
			if (m_onNext != null)
			{
				m_onNext();
			};
		}

		private function onRepeat():void
		{
			if (m_onRepeat != null)
			{
				m_onRepeat();
			};
		}

		private function onToggle():void
		{
			if (m_onToggleExpand != null)
			{
				m_onToggleExpand();
			};
		}

		private static function formatTime(ms:Number):String
		{
			var sec:int;
			var m:int;
			var s:int;
			if (ms < 0 || isNaN(ms))
			{
				ms = 0;
			};
			sec = int(ms / 1000);
			m = int(sec / 60);
			s = sec % 60;
			return (String(m) + ":" + (s < 10 ? "0" : "") + String(s));
		}
	}
}
