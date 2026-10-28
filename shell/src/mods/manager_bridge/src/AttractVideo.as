package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Timer;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.VideoOverlay;

	/**
	 * Video and logo segments: How to Play FLV, random intro watch, demo logo.
	 */
	internal class AttractVideo
	{
		private var core:AttractMode;
		private var m_logo:MovieClip;
		private var m_introWatch:Timer;

		public function AttractVideo(owner:AttractMode)
		{
			core = owner;
			m_logo = null;
			m_introWatch = null;
		}

		internal function startHowToPlay():void
		{
			var file:File;
			var st:*;
			var MainCls:Class;
			var w:Number;
			var h:Number;
			var overlay:VideoOverlay;
			var storage:File;
			var localCopy:File;

			if (core.m_busy)
			{
				return;
			};
			core.hardStopAttractMedia();
			try
			{
				file = File.applicationDirectory.resolvePath("data/video/how_to_play.flv");
				if (!file.exists)
				{
					log("how_to_play.flv missing — skip");
					core.finishSegment();
					return;
				};
				MainCls = EngineRefs.Main as Class;
				st = MainCls ? MainCls["Root"].stage : null;
				w = MainCls ? Number(MainCls["Width"]) : 853;
				h = MainCls ? Number(MainCls["Height"]) : 480;
				if (!st)
				{
					core.finishSegment();
					return;
				};
				storage = File.applicationStorageDirectory.resolvePath("ssf2_stream");
				if (!storage.exists)
				{
					storage.createDirectory();
				};
				localCopy = storage.resolvePath("attract_howto.flv");
				file.copyTo(localCopy, true);
				core.setAttractMedia(true);
				core.m_busy = true;
				core.m_kind = "howto";
				core.m_onTitle = false;
				core.armSkipSoon();
				try
				{
					var MC:Class = EngineRefs.MenuController as Class;
					if (MC && MC["disposeAllMenus"])
					{
						MC["disposeAllMenus"]();
					};
				}
				catch (menuErr:*)
				{
				};
				overlay = new VideoOverlay(log);
				core.m_howto = overlay;
				if (!overlay.play(st as Stage, localCopy, w, h, onHowToDone, {"onInput": onHowToInput}))
				{
					throw new Error("video overlay play failed");
				};
				log("how to play start");
			}
			catch (err:*)
			{
				log("howto fail: " + err);
				stopVideo();
				core.m_busy = false;
				core.m_kind = "";
				core.finishSegment();
			};
		}

		private function onHowToDone(reason:String):void
		{
			stopVideo();
			if (core.m_kind != "howto" && reason != "complete")
			{
				return;
			};
			if (reason.indexOf("fatal:") == 0)
			{
				log("howto net " + reason.substr(6));
			};
			core.showTitle();
			core.finishSegment();
		}

		private function onHowToInput():Boolean
		{
			return (core.trySkipAttract());
		}

		internal function stopVideo():void
		{
			var overlay:VideoOverlay = core.m_howto;
			core.m_howto = null;
			core.m_skipArmed = false;
			if (overlay)
			{
				overlay.dispose();
			};
		}

		internal function startRandomIntro():void
		{
			var picked:Boolean;
			if (core.m_busy)
			{
				return;
			};
			core.hardStopAttractMedia();
			core.setAttractMedia(true);
			core.m_busy = true;
			core.m_kind = "intro";
			core.m_onTitle = false;
			core.armSkipSoon();
			picked = false;
			ResourceMem.snap("attract:intro:start");
			try
			{
				if (core.m_pickIntro != null)
				{
					picked = Boolean(core.m_pickIntro());
				};
			}
			catch (err:*)
			{
				log("intro pick: " + err);
			};
			if (!picked)
			{
				log("no intro — skip");
				core.m_busy = false;
				core.m_kind = "";
				core.m_skipArmed = false;
				core.finishSegment();
				return;
			};
			stopIntroWatch();
			m_introWatch = new Timer(120000, 1);
			m_introWatch.addEventListener(TimerEvent.TIMER, onIntroWatchTimeout);
			m_introWatch.start();
			log("random intro started");
		}

		private function onIntroWatchTimeout(e:TimerEvent):void
		{
			stopIntroWatch();
			if (core.m_busy && core.m_kind == "intro")
			{
				log("intro watchdog");
				core.showTitle();
				core.finishSegment();
			};
		}

		internal function stopIntroWatch():void
		{
			var t:Timer;
			t = m_introWatch;
			m_introWatch = null;
			if (!t)
			{
				return;
			};
			try
			{
				t.stop();
				t.removeEventListener(TimerEvent.TIMER, onIntroWatchTimeout);
			}
			catch (err:*)
			{
			};
		}

		internal function showLogo():void
		{
			var RM:Class;
			var MainCls:Class;
			var root:*;
			var w:Number;
			var h:Number;
			var clip:MovieClip;
			var logoClass:Class;
			hideLogo();
			try
			{
				RM = EngineRefs.ResourceManager as Class;
				MainCls = EngineRefs.Main as Class;
				root = MainCls ? MainCls["Root"] : null;
				w = MainCls ? Number(MainCls["Width"]) : 853;
				h = MainCls ? Number(MainCls["Height"]) : 480;
				if (!RM || !root)
				{
					return;
				};
				clip = null;
				// Full export name from menu_main.swf symbolClass (not bare SuperSmashFlash2Logo_16).
				try
				{
					clip = RM["getLibraryMC"]("menu_main_fla.SuperSmashFlash2Logo_16") as MovieClip;
				}
				catch (e1:*)
				{
				};
				if (!clip)
				{
					try
					{
						logoClass = RM["getLibraryClass"]("menu_main_fla.SuperSmashFlash2Logo_16") as Class;
						if (logoClass)
						{
							clip = new logoClass() as MovieClip;
						};
					}
					catch (e2:*)
					{
					};
				};
				if (!clip)
				{
					try
					{
						logoClass = EngineRefs.cls("menu_main_fla.SuperSmashFlash2Logo_16") as Class;
						if (logoClass)
						{
							clip = new logoClass() as MovieClip;
						};
					}
					catch (e3:*)
					{
					};
				};
				if (!clip)
				{
					log("logo missing menu_main_fla.SuperSmashFlash2Logo_16");
					return;
				};
				core.m_logoLayer = new Sprite();
				core.m_logoLayer.mouseEnabled = false;
				core.m_logoLayer.mouseChildren = false;
				m_logo = clip;
				// ~75% smaller than prior 0.42 scale.
				m_logo.scaleX = 0.105;
				m_logo.scaleY = 0.105;
				// Top-center (logo timeline is typically center-registered).
				m_logo.x = w * 0.5;
				m_logo.y = 48;
				try
				{
					m_logo.gotoAndPlay(1);
				}
				catch (playErr:*)
				{
				};
				core.m_logoLayer.addChild(m_logo);
				root.addChild(core.m_logoLayer);
				try
				{
					root.setChildIndex(core.m_logoLayer, root.numChildren - 1);
				}
				catch (zErr:*)
				{
				};
			}
			catch (err:*)
			{
				log("logo: " + err);
			};
		}

		internal function hideLogo():void
		{
			if (core.m_logoLayer && core.m_logoLayer.parent)
			{
				try
				{
					core.m_logoLayer.parent.removeChild(core.m_logoLayer);
				}
				catch (err:*)
				{
				};
			};
			core.m_logoLayer = null;
			m_logo = null;
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
