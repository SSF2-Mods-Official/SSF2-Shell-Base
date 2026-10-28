package com.sbxmod.paletteMaker
{
	import ssf2mm.shared.JsonFile;
	import ssf2mm.shared.HsvWheel;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.display.DisplayObjectContainer;
	import flash.utils.Dictionary;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.media.SoundMixer;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.display.BitmapData;
	import flash.utils.getTimer;
	import flash.utils.getQualifiedClassName;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import flash.net.SharedObject;
	import flash.filters.ColorMatrixFilter;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

	/** Palette Maker loading-screen overlay: show, front, early dismiss. */
	public class PaletteLoadingScreen
	{
		/** Lazy — eager static init ran before vcontent loaded and stayed null forever. */
		private static var paletteMakerLoadingScreen:MovieClip = null;

		private static var loadingScreenNullTraced:Boolean = false;

		/** Drop cover once timeline reaches this fraction (safety if studio start is delayed). */
		private static const LOADING_SCREEN_DISMISS_RATIO:Number = 0.8;

		private static const LOADING_SCREEN_OUTRO_FRAME:int = 34;

		/** When true, dismiss as soon as outro frame is reached (studio-ready path). */
		private static var loadingScreenDismissAtOutroOnly:Boolean = false;

		/** getTimer() when the intro started. */
		private static var loadingScreenShownAt:int = 0;

		/** getTimer() when the closing animation (frame 34) started. 0 until then. */
		private static var loadingScreenOutroAt:int = 0;

		private static var loadingScreenOutroStarted:Boolean = false;

		/** Series logo, then the closing animation. */
		private static const LOADING_SCREEN_LOGO_MS:int = 700;

		/** Drop the cover if the closing animation does not reach its last frame. */
		private static const LOADING_SCREEN_OUTRO_CAP_MS:int = 1000;

		private static function getPaletteMakerLoadingScreen():MovieClip
		{
			var mc:MovieClip;
			if (paletteMakerLoadingScreen && !(paletteMakerLoadingScreen is MovieClip))
			{
				paletteMakerLoadingScreen = null;
			};
			if (!paletteMakerLoadingScreen)
			{
				mc = Ssf2.ResourceManager.getLibraryMC("paletteMakerLoadingScreen");
				if (mc && mc is MovieClip)
				{
					paletteMakerLoadingScreen = mc;
				};
			};
			return paletteMakerLoadingScreen;
		}

		/**
		 * AIR/ADL: Ssf2.Main.Root.parent is often a Loader (cannot addChild). Prefer stage.
		 */
		private static function resolveLoadingScreenHost():DisplayObjectContainer
		{
			var node:DisplayObject;
			var st:Stage;
			if (!Ssf2.Main.Root)
			{
				return (null);
			};
			st = Ssf2.Main.Root.stage;
			if (st)
			{
				return (st);
			};
			node = Ssf2.Main.Root;
			while (node)
			{
				if (node is DisplayObjectContainer && !(node is Loader))
				{
					return (node as DisplayObjectContainer);
				};
				node = node.parent;
			};
			return (Ssf2.Main.Root);
		}

		private static function parentLoadingScreenFront(screen:MovieClip, host:DisplayObjectContainer):void
		{
			if (!screen || !host)
			{
				return;
			};
			try
			{
				if (screen.parent != host)
				{
					host.addChild(screen);
				}
				else if (host.getChildIndex(screen) != (host.numChildren - 1))
				{
					host.setChildIndex(screen, host.numChildren - 1);
				};
			}
			catch (hostErr:Error)
			{
				paletteMakerLoadingScreen = null;
				trace("[PaletteMakerUtils] loading screen host failed: " + hostErr.message);
			};
		}

		/** Re-parent loading screen above menus (stage when Root.parent is Loader). */
		public static function ensurePaletteMakerLoadingScreenFront():void
		{
			var screen:MovieClip;
			var host:DisplayObjectContainer;
			screen = getPaletteMakerLoadingScreen();
			host = resolveLoadingScreenHost();
			if (!screen || !host)
			{
				return;
			};
			parentLoadingScreenFront(screen, host);
		}

		public static function showPaletteMakerLoadingScreen(statsName:String, show:Boolean):void
		{
			var screen:MovieClip;
			var seriesClip:MovieClip;
			var seriesIcon:MovieClip;
			var host:DisplayObjectContainer;
			screen = getPaletteMakerLoadingScreen();
			if (!screen)
			{
				if (!loadingScreenNullTraced)
				{
					loadingScreenNullTraced = true;
					trace("[PaletteMakerUtils] paletteMakerLoadingScreen unavailable (vcontent not loaded?)");
				};
				return;
			};
			if (statsName && show)
			{
				cancelLoadingScreenEarlyDismiss();
				host = resolveLoadingScreenHost();
				if (!host)
				{
					return;
				};
				parentLoadingScreenFront(screen, host);
				screen.visible = true;
				screen.alpha = 1;
				loadingScreenShownAt = getTimer();
				loadingScreenOutroAt = 0;
				loadingScreenOutroStarted = false;
				try
				{
					screen.gotoAndStop(1);
				}
				catch (restartErr:Error)
				{
					paletteMakerLoadingScreen = null;
					trace("[PaletteMakerUtils] loading screen intro play failed: " + restartErr.message);
					return;
				};
				try
				{
					seriesClip = MovieClip(screen.series);
					if (seriesClip)
					{
						PaletteMakerUtils.removeAllChildrenMC(seriesClip);
						seriesIcon = PaletteMakerUtils.getSeriesIcon(statsName);
						if (seriesIcon)
						{
							seriesClip.addChild(seriesIcon);
							seriesIcon.gotoAndPlay(1);
						};
						trace("[PaletteMakerUtils] loading screen series " + statsName);
					};
				}
				catch (seriesErr:Error)
				{
				};
				try
				{
					screen.play();
				}
				catch (playErr:Error)
				{
					paletteMakerLoadingScreen = null;
					trace("[PaletteMakerUtils] loading screen intro play failed: " + playErr.message);
				};
			}
			else if (!show)
			{
				ensurePaletteMakerLoadingScreenFront();
				if (loadingScreenShownAt == 0)
				{
					loadingScreenShownAt = getTimer();
				};
				try
				{
					if (int(screen.currentFrame) < 1)
					{
						screen.gotoAndPlay(1);
					}
					else if (!screen.isPlaying)
					{
						screen.play();
					};
				}
				catch (playErr:Error)
				{
					paletteMakerLoadingScreen = null;
					trace("[PaletteMakerUtils] loading screen outro play failed: " + playErr.message);
					return;
				};
				beginLoadingScreenEarlyDismiss();
			};
		}

		private static function beginLoadingScreenEarlyDismiss():void
		{
			cancelLoadingScreenEarlyDismiss();
			if (!Ssf2.Main.Root || !getPaletteMakerLoadingScreen())
			{
				return;
			};
			loadingScreenDismissAtOutroOnly = false;
			Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, onLoadingScreenEarlyDismiss, false, 0, true);
		}

		/**
		 * Studio is up. The cover stays through the series logo, then the closing animation.
		 */
		public static function revealStudioFromLoadingScreen():void
		{
			var screen:MovieClip;
			screen = getPaletteMakerLoadingScreen();
			if (!screen || !screen.parent)
			{
				cancelLoadingScreenEarlyDismiss();
				return;
			};
			if (closingAnimationDone(screen))
			{
				dismissPaletteMakerLoadingScreen();
				return;
			};
			beginLoadingScreenEarlyDismiss();
		}

		/** Start frame 34 once the logo has been up, then wait until that animation ends. */
		private static function closingAnimationDone(screen:MovieClip):Boolean
		{
			var now:int;
			var frame:int;
			var total:int;
			now = getTimer();
			frame = int(screen.currentFrame);
			total = int(screen.totalFrames);
			if (!loadingScreenOutroStarted)
			{
				if (loadingScreenShownAt == 0)
				{
					loadingScreenShownAt = now;
				};
				if (now - loadingScreenShownAt < LOADING_SCREEN_LOGO_MS && frame < LOADING_SCREEN_OUTRO_FRAME)
				{
					return (false);
				};
				loadingScreenOutroStarted = true;
				loadingScreenOutroAt = now;
				try
				{
					screen.gotoAndPlay(LOADING_SCREEN_OUTRO_FRAME);
				}
				catch (outroErr:Error)
				{
					trace("[PaletteMakerUtils] loading screen outro play failed: " + outroErr.message);
				};
				return (false);
			};
			frame = int(screen.currentFrame);
			total = int(screen.totalFrames);
			if (total > LOADING_SCREEN_OUTRO_FRAME && frame >= total - 1)
			{
				return (true);
			};
			if (!screen.isPlaying && frame >= LOADING_SCREEN_OUTRO_FRAME && now - loadingScreenOutroAt > 50)
			{
				return (true);
			};
			return (loadingScreenOutroAt > 0 && now - loadingScreenOutroAt >= LOADING_SCREEN_OUTRO_CAP_MS);
		}

		private static function onLoadingScreenEarlyDismiss(e:Event):void
		{
			var screen:MovieClip;
			screen = getPaletteMakerLoadingScreen();
			if (!screen || !screen.parent)
			{
				cancelLoadingScreenEarlyDismiss();
				return;
			};
			if (closingAnimationDone(screen))
			{
				trace("[PaletteMakerUtils] loading screen outro frame=" + int(screen.currentFrame) + " ms=" + (getTimer() - loadingScreenShownAt));
				dismissPaletteMakerLoadingScreen();
			};
		}

		public static function dismissPaletteMakerLoadingScreen():void
		{
			var screen:MovieClip;
			cancelLoadingScreenEarlyDismiss();
			screen = getPaletteMakerLoadingScreen();
			if (!screen)
			{
				return;
			};
			try
			{
				screen.stop();
			}
			catch (stopErr:Error)
			{
			};
			if (screen.parent)
			{
				screen.parent.removeChild(screen);
			};
		}

		private static var rootScanLabel:TextField;

		/** Shown on the game root and the loading screen while the unique-sprite walk is running. */
		public static function setUniqueScanStatus(message:String, announce:Boolean = false):void
		{
			var screen:MovieClip;
			var label:TextField;
			var fmt:TextFormat;
			if (announce && message)
			{
				try
				{
					Ssf2.MultiplayerManager.notify(message);
				}
				catch (noteErr:Error)
				{
				};
			};
			showRootScanStatus(message);
			screen = getPaletteMakerLoadingScreen();
			if (!screen)
			{
				return;
			};
			label = screen.getChildByName("uniqueScanStatus") as TextField;
			if (!message)
			{
				if (label && label.parent)
				{
					label.parent.removeChild(label);
				};
				return;
			};
			if (!label)
			{
				label = new TextField();
				label.name = "uniqueScanStatus";
				label.selectable = false;
				label.mouseEnabled = false;
				label.width = 480;
				label.height = 28;
				fmt = new TextFormat("_sans", 16, 0xFFFFFF, true, false, false, null, null, TextFormatAlign.CENTER);
				label.defaultTextFormat = fmt;
				label.x = 80;
				label.y = 36;
				screen.addChild(label);
			};
			label.text = message;
		}

		/** The loading screen is often already gone, so the same line sits on the game root. */
		private static function showRootScanStatus(message:String):void
		{
			var fmt:TextFormat;
			var root:DisplayObjectContainer;
			if (!Ssf2.Main || !Ssf2.Main.Root)
			{
				return;
			};
			root = Ssf2.Main.Root;
			if (!message)
			{
				if (rootScanLabel && rootScanLabel.parent)
				{
					rootScanLabel.parent.removeChild(rootScanLabel);
				};
				rootScanLabel = null;
				return;
			};
			if (!rootScanLabel)
			{
				rootScanLabel = new TextField();
				rootScanLabel.name = "uniqueScanStatus";
				rootScanLabel.selectable = false;
				rootScanLabel.mouseEnabled = false;
				rootScanLabel.background = true;
				rootScanLabel.backgroundColor = 0x000000;
				rootScanLabel.width = 520;
				rootScanLabel.height = 28;
				fmt = new TextFormat("_sans", 16, 0xFFFFFF, true, false, false, null, null, TextFormatAlign.CENTER);
				rootScanLabel.defaultTextFormat = fmt;
				rootScanLabel.y = 8;
			};
			rootScanLabel.text = message;
			rootScanLabel.x = (Ssf2.Main.Width - rootScanLabel.width) / 2;
			if (rootScanLabel.parent != root)
			{
				root.addChild(rootScanLabel);
			}
			else
			{
				root.setChildIndex(rootScanLabel, root.numChildren - 1);
			};
		}

		internal static function cancelLoadingScreenEarlyDismiss():void
		{
			loadingScreenDismissAtOutroOnly = false;
			if (Ssf2.Main.Root)
			{
				Ssf2.Main.Root.removeEventListener(Event.ENTER_FRAME, onLoadingScreenEarlyDismiss);
			};
		}
	}
}
