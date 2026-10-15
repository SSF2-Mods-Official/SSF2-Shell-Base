package
{
	import flash.display.MovieClip;
	import flash.events.Event;
	import ssf2mm.shared.EngineRefs;

	/**
	 * After the engine's overlayBG, waits for the background stage SWF and its visible camera
	 * BGs, then boots the menu_background stage stub on those clips so scripted layers
	 * (hearts, clouds) move in the match. Rain is moved onto the match WEATHER layer.
	 */
	public class CameraBgOverlay
	{
		/** Frames to wait for the BG SWF / overlay before giving up. */
		private static const MAX_WAIT:int = 180;

		internal var mod:CameraBackgroundMod;
		private var m_stub:MenuBgStageStub;
		private var m_armed:Boolean;
		private var m_pendingStageData:*;
		private var m_tries:int;

		public function CameraBgOverlay(owner:CameraBackgroundMod)
		{
			mod = owner;
		}

		/** Boot the stub on a later frame, once Vcam.BGs already include the overlay sprites. */
		internal function arm(sd:*):void
		{
			var root:*;
			m_pendingStageData = sd;
			if (m_armed)
			{
				return;
			};
			m_tries = 0;
			root = EngineRefs.Main ? EngineRefs.Main["Root"] : null;
			if (root)
			{
				root.addEventListener(Event.ENTER_FRAME, onFrame, false, 0, true);
				m_armed = true;
			};
		}

		internal function disarm():void
		{
			var root:*;
			if (m_armed)
			{
				root = EngineRefs.Main ? EngineRefs.Main["Root"] : null;
				if (root)
				{
					root.removeEventListener(Event.ENTER_FRAME, onFrame);
				};
			};
			m_armed = false;
			m_tries = 0;
			m_pendingStageData = null;
		}

		internal function dispose():void
		{
			disarm();
			if (!m_stub)
			{
				return;
			};
			try
			{
				m_stub.dispose(true);
			}
			catch (err:*)
			{
				trace("[camera_background] stub dispose failed: " + err);
			};
			m_stub = null;
		}

		private function onFrame(e:Event):void
		{
			var bgId:String = mod.resolveBgStageId();
			var sd:* = m_pendingStageData;
			if (!bgId || !sd)
			{
				disarm();
				return;
			};
			m_tries++;
			// Wait for BG SWF + StageData.overlayBG (deferred on replay) before stubbing.
			if (!stageResourceLoaded(bgId))
			{
				if (m_tries > MAX_WAIT)
				{
					trace("[camera_background] stub wait timed out (SWF) " + bgId);
					disarm();
				};
				return;
			};
			if (visibleCamBgs(sd).length < 1)
			{
				if (m_tries > MAX_WAIT)
				{
					trace("[camera_background] stub wait timed out (overlay) " + bgId);
					disarm();
				};
				return;
			};
			disarm();
			boot(sd, bgId);
		}

		private static function stageResourceLoaded(stageId:String):Boolean
		{
			var res:*;
			try
			{
				res = EngineRefs.ResourceManager.getResourceByID(stageId);
				return (Boolean(res && res.Loaded));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		/** Original stage BGs are hidden by overlayBG; the overlay sprites stay visible. */
		private static function visibleCamBgs(sd:*):Array
		{
			var out:Array = [];
			var bgs:*;
			var entry:*;
			var i:int;
			try
			{
				bgs = sd["CamRef"] ? sd["CamRef"]["BGs"] : null;
			}
			catch (camErr:*)
			{
				return (out);
			};
			for (i = 0; bgs && i < bgs.length; i++)
			{
				entry = bgs[i];
				if (entry && entry.sprite && entry.sprite.visible)
				{
					out.push({"mc": entry.sprite as MovieClip});
				};
			};
			return (out);
		}

		private function boot(sd:*, bgStageId:String):void
		{
			var bgList:Array;
			var res:*;
			var stageClass:Class;
			dispose();
			bgList = visibleCamBgs(sd);
			if (bgList.length < 1)
			{
				trace("[camera_background] no visible overlay BGs for stub");
				return;
			};
			try
			{
				res = EngineRefs.ResourceManager.getResourceByID(bgStageId, true);
				stageClass = res ? res.getProp("stage") as Class : null;
			}
			catch (resErr:*)
			{
				stageClass = null;
			};
			if (!stageClass)
			{
				return;
			};
			try
			{
				m_stub = new MenuBgStageStub();
				m_stub.setCameraBackgrounds(bgList);
				m_stub.initStageClass(stageClass, bgStageId, true);
				attachWeather(sd, m_stub);
				mod.m_lastOverlayId = bgStageId;
				trace("[camera_background] overlay stage stub booted for " + bgStageId + " clips=" + bgList.length);
			}
			catch (stubErr:*)
			{
				trace("[camera_background] stub failed: " + stubErr);
				dispose();
			};
		}

		/** Rain/weather is parented to the stub — attach it to the live match WEATHER layer. */
		private static function attachWeather(sd:*, stub:MenuBgStageStub):void
		{
			var weather:MovieClip = stub.getWeatherMC();
			var host:*;
			if (!weather)
			{
				return;
			};
			try
			{
				host = sd["WeatherRef"];
			}
			catch (wErr:*)
			{
				host = null;
			};
			if (!host)
			{
				try
				{
					host = sd["WEATHER"];
				}
				catch (w2:*)
				{
					host = null;
				};
			};
			if (!host || !("addChild" in host))
			{
				trace("[camera_background] no WeatherRef to attach rain");
				return;
			};
			try
			{
				if (weather.parent)
				{
					weather.parent.removeChild(weather);
				};
				host.addChild(weather);
				weather.x = 0;
				weather.y = 0;
				weather.visible = true;
				trace("[camera_background] weather attached to match layer");
			}
			catch (addErr:*)
			{
				trace("[camera_background] weather attach: " + addErr);
			};
		}
	}
}
