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
				try
				{
					seriesClip = MovieClip(screen.series);
					if (seriesClip)
					{
						PaletteMakerUtils.removeAllChildrenMC(seriesClip);
						seriesClip.addChild(PaletteMakerUtils.getSeriesIcon(statsName));
					};
				}
				catch (seriesErr:Error)
				{
				};
				try
				{
					screen.gotoAndPlay(1);
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
				try
				{
					screen.gotoAndPlay(34);
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
		 * Studio is up — drop the cover so the entrance is visible.
		 * If still mid-intro, wait until outro frame 34 then dismiss (no black outro hold).
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
			if (int(screen.currentFrame) >= LOADING_SCREEN_OUTRO_FRAME)
			{
				dismissPaletteMakerLoadingScreen();
				return;
			};
			cancelLoadingScreenEarlyDismiss();
			if (!Ssf2.Main.Root)
			{
				dismissPaletteMakerLoadingScreen();
				return;
			};
			loadingScreenDismissAtOutroOnly = true;
			Ssf2.Main.Root.addEventListener(Event.ENTER_FRAME, onLoadingScreenEarlyDismiss, false, 0, true);
		}

		private static function onLoadingScreenEarlyDismiss(e:Event):void
		{
			var screen:MovieClip;
			var cutoff:int;
			screen = getPaletteMakerLoadingScreen();
			if (!screen || !screen.parent)
			{
				cancelLoadingScreenEarlyDismiss();
				return;
			};
			if (loadingScreenDismissAtOutroOnly)
			{
				cutoff = LOADING_SCREEN_OUTRO_FRAME;
			}
			else
			{
				cutoff = int(Math.ceil(screen.totalFrames * LOADING_SCREEN_DISMISS_RATIO));
				if (cutoff < 1)
				{
					cutoff = 1;
				};
			};
			if (int(screen.currentFrame) >= cutoff || int(screen.currentFrame) >= int(screen.totalFrames))
			{
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
