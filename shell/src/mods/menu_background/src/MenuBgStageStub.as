package
{
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.system.ApplicationDomain;

	import ssf2mm.shared.EngineRefs;

	/**
	 * PSB MenuStageStub — hosts a stage class (initialize/update) against menu camera BG clips
	 * so scripted layers (e.g. TWTNW hearts/clouds) render on the menu backdrop.
	 */
	public class MenuBgStageStub
	{
		private var m_frames:int;
		private var m_cameraBackgrounds:Array;
		private var m_metadata:Object;
		private var m_stageInstance:*;
		private var m_stageMC:MovieClip;
		private var m_background:MovieClip;
		private var m_foreground:MovieClip;
		private var m_midground:MovieClip;
		private var m_weatherMC:MovieClip;
		private var m_aflexAPIClass:Class;
		private var m_apiProxy:MenuBgApiProxy;
		private var m_armed:Boolean;

		public function MenuBgStageStub()
		{
			super();
			m_frames = 0;
			m_cameraBackgrounds = [];
			m_metadata = {};
			m_stageInstance = null;
			m_stageMC = null;
			m_background = null;
			m_foreground = null;
			m_midground = null;
			m_weatherMC = new MovieClip();
			m_aflexAPIClass = null;
			m_apiProxy = null;
			m_armed = false;
			armFrame();
		}

		private function armFrame():void
		{
			var MainCls:*;
			var root:*;
			if (m_armed)
			{
				return;
			};
			try
			{
				MainCls = EngineRefs.Main;
				root = MainCls ? MainCls["Root"] : null;
				if (root)
				{
					root.addEventListener(Event.ENTER_FRAME, onFrame, false, 0, true);
					m_armed = true;
				};
			}
			catch (err:*)
			{
			};
		}

		private function disarmFrame():void
		{
			var MainCls:*;
			var root:*;
			if (!m_armed)
			{
				return;
			};
			try
			{
				MainCls = EngineRefs.Main;
				root = MainCls ? MainCls["Root"] : null;
				if (root)
				{
					root.removeEventListener(Event.ENTER_FRAME, onFrame);
				};
			}
			catch (err:*)
			{
			};
			m_armed = false;
		}

		private function onFrame(e:Event):void
		{
			m_frames++;
			if (m_stageInstance && ("update" in m_stageInstance))
			{
				try
				{
					m_stageInstance.update();
				}
				catch (err:*)
				{
				};
			};
		}

		public function get frames():int
		{
			return m_frames;
		}

		public function get metadata():Object
		{
			return m_metadata;
		}

		public function setCameraBackgrounds(list:Array):void
		{
			m_cameraBackgrounds = list || [];
			padCameraBackgrounds();
		}

		/**
		 * Instantiate stage class with this stub as owner (PSB initStageClass).
		 * Camera BG list must already be set to the menu-visible clips — do not replace
		 * them with stageMC.background (that would draw off the menu container).
		 */
		public function initStageClass(stageClass:Class, stageId:String = null, matchSafe:Boolean = false):void
		{
			var RM:*;
			var SSF2API:*;
			var initResult:*;
			var stageResource:*;
			var stageDomain:ApplicationDomain;
			if (!stageClass)
			{
				return;
			};
			try
			{
				RM = EngineRefs.ResourceManager;
			}
			catch (rmErr:*)
			{
				RM = null;
			};
			try
			{
				SSF2API = EngineRefs.ssf2("api.SSF2API");
			}
			catch (apiErr:*)
			{
				SSF2API = null;
			};
			// Never enableMenuPreview during a live match — that steals SSF2API from StageData.
			if (!matchSafe && SSF2API && SSF2API.enableMenuPreview)
			{
				try
				{
					SSF2API.enableMenuPreview(null);
				}
				catch (enErr:*)
				{
				};
			};
			if (stageId && RM)
			{
				try
				{
					m_stageMC = RM.getLibraryMC("stage_" + stageId) as MovieClip;
					if (m_stageMC)
					{
						m_background = m_stageMC["background"] as MovieClip;
						m_foreground = m_stageMC["foreground"] as MovieClip;
						m_midground = m_stageMC["terrain"] as MovieClip;
						if (m_foreground)
						{
							m_foreground.visible = false;
						};
						if (m_midground)
						{
							m_midground.visible = false;
						};
						// Keep off display list — camera BGs live on the menu container.
						m_stageMC.visible = false;
						m_stageMC.mouseEnabled = false;
						m_stageMC.mouseChildren = false;
					};
				}
				catch (mcErr:*)
				{
					trace("[menu_background] stage MC: " + mcErr);
				};
			};
			if (!m_background)
			{
				m_background = new MovieClip();
			};
			if (!m_foreground)
			{
				m_foreground = new MovieClip();
			};
			if (!m_midground)
			{
				m_midground = new MovieClip();
			};
			// FD initialize reads getForeground().fd_ambient — ensure the property exists.
			ensureFdAmbient(m_foreground);
			m_apiProxy = new MenuBgApiProxy(SSF2API);
			m_apiProxy.setStageStub(this);
			try
			{
				if (m_stageMC && ("initAPI" in m_stageMC))
				{
					initResult = (m_stageMC["initAPI"] as Function).call(m_stageMC, m_apiProxy);
					m_aflexAPIClass = initResult as Class;
				}
				else if (RM && stageId)
				{
					stageResource = RM.getResourceByID(stageId);
					stageDomain = null;
					if (stageResource && stageResource.MC)
					{
						try
						{
							stageDomain = stageResource.MC.loaderInfo.applicationDomain as ApplicationDomain;
						}
						catch (domErr:*)
						{
						};
					};
					if (stageDomain && stageDomain.hasDefinition("SSF2API"))
					{
						m_aflexAPIClass = stageDomain.getDefinition("SSF2API") as Class;
					}
					else if (RM.getLibraryClass)
					{
						m_aflexAPIClass = RM.getLibraryClass("SSF2API") as Class;
					};
					if (m_aflexAPIClass)
					{
						if ("deinit" in m_aflexAPIClass)
						{
							m_aflexAPIClass["deinit"]();
						};
						if ("init" in m_aflexAPIClass)
						{
							m_aflexAPIClass["init"](m_apiProxy);
						};
					};
				};
			}
			catch (initApiErr:*)
			{
				trace("[menu_background] initAPI: " + initApiErr);
			};
			try
			{
				m_stageInstance = new stageClass(this);
			}
			catch (ctorErr:*)
			{
				trace("[menu_background] stage ctor: " + ctorErr);
				m_stageInstance = null;
			};
			// Timeline: SSF2API.getStage().startPhase3 / frames — aflex m_api.getStage().
			if (m_apiProxy)
			{
				m_apiProxy.setStageScript(m_stageInstance);
			};
			// Engine fallback when IsMenuPreview / catch path uses _menuPreview.stage.
			if (!matchSafe && SSF2API && SSF2API.enableMenuPreview && m_stageInstance)
			{
				try
				{
					SSF2API.enableMenuPreview({"stage":m_stageInstance});
				}
				catch (prevErr:*)
				{
				};
			};
			if (m_stageInstance && ("initialize" in m_stageInstance))
			{
				try
				{
					padCameraBackgrounds();
					m_stageInstance.initialize();
				}
				catch (initErr:*)
				{
					trace("[menu_background] stage initialize: " + initErr);
				};
			};
		}

		/** Final Destination: SSF2StageQuality.init(..., [getForeground().fd_ambient]). */
		private function ensureFdAmbient(fg:MovieClip):void
		{
			var amb:MovieClip;
			if (!fg)
			{
				return;
			};
			try
			{
				if (fg["fd_ambient"] != null)
				{
					return;
				};
			}
			catch (checkErr:*)
			{
			};
			try
			{
				amb = new MovieClip();
				amb.name = "fd_ambient";
				fg.addChild(amb);
				fg["fd_ambient"] = amb;
			}
			catch (addErr:*)
			{
				trace("[menu_background] fd_ambient stub: " + addErr);
			};
		}

		public function dispose(matchSafe:Boolean = false):void
		{
			var Utils:*;
			var i:int;
			var entry:Object;
			var SSF2API:*;
			disarmFrame();
			if (m_apiProxy)
			{
				try
				{
					m_apiProxy.setStageScript(null);
					m_apiProxy.setStageStub(null);
				}
				catch (proxyErr:*)
				{
				};
				m_apiProxy = null;
			};
			if (m_stageInstance)
			{
				try
				{
					if ("dispose" in m_stageInstance)
					{
						m_stageInstance.dispose();
					};
					if ("__dispose" in m_stageInstance)
					{
						m_stageInstance.__dispose();
					};
				}
				catch (dispErr:*)
				{
				};
				m_stageInstance = null;
			};
			try
			{
				Utils = EngineRefs.Utils;
			}
			catch (uErr:*)
			{
				Utils = null;
			};
			i = 0;
			while (m_cameraBackgrounds && i < m_cameraBackgrounds.length)
			{
				entry = m_cameraBackgrounds[i];
				i++;
				if (entry && entry.mc && Utils)
				{
					try
					{
						Utils.recursiveMovieClipPlay(entry.mc as MovieClip, false, false);
					}
					catch (stopErr:*)
					{
					};
				};
			};
			if (m_stageMC)
			{
				try
				{
					if (Utils)
					{
						Utils.recursiveMovieClipPlay(m_stageMC, false, false);
					};
					if (m_stageMC.parent)
					{
						m_stageMC.parent.removeChild(m_stageMC);
					};
				}
				catch (mcErr:*)
				{
				};
			};
			if (m_weatherMC && Utils)
			{
				try
				{
					Utils.recursiveMovieClipPlay(m_weatherMC, false, false);
				}
				catch (wErr:*)
				{
				};
			};
			if (m_aflexAPIClass && ("deinit" in m_aflexAPIClass))
			{
				try
				{
					m_aflexAPIClass["deinit"]();
				}
				catch (deErr:*)
				{
				};
			};
			if (!matchSafe)
			{
				try
				{
					SSF2API = EngineRefs.ssf2("api.SSF2API");
					if (SSF2API && SSF2API.disableMenuPreview)
					{
						SSF2API.disableMenuPreview();
					};
				}
				catch (apiErr:*)
				{
				};
			};
			m_aflexAPIClass = null;
			m_frames = 0;
			m_cameraBackgrounds = [];
			m_stageMC = null;
			m_background = null;
			m_foreground = null;
			m_midground = null;
			m_weatherMC = null;
		}

		public function getCameraBackgrounds():Array
		{
			padCameraBackgrounds();
			return m_cameraBackgrounds;
		}

		/**
		 * Stage scripts index [0] and [1] (Jungle Island). Overlay may only have
		 * one visible clip — pad so initialize reaches character listeners.
		 */
		private function padCameraBackgrounds():void
		{
			var i:int;
			var entry:Object;
			var mc:MovieClip;
			if (!m_cameraBackgrounds)
			{
				m_cameraBackgrounds = [];
			};
			i = 0;
			while (i < m_cameraBackgrounds.length)
			{
				entry = m_cameraBackgrounds[i] as Object;
				if (!entry)
				{
					entry = {};
					m_cameraBackgrounds[i] = entry;
				};
				if (!entry.mc)
				{
					mc = new MovieClip();
					entry.mc = mc;
				};
				i++;
			};
			while (m_cameraBackgrounds.length < 2)
			{
				mc = new MovieClip();
				m_cameraBackgrounds.push({"mc": mc});
			};
		}

		public function getWeatherMC():MovieClip
		{
			return m_weatherMC;
		}

		public function getWeatherMaskMC():MovieClip
		{
			return new MovieClip();
		}

		public function getShadowMC():MovieClip
		{
			return new MovieClip();
		}

		public function getShadowMaskMC():MovieClip
		{
			return new MovieClip();
		}

		public function getBackground():MovieClip
		{
			return m_background;
		}

		public function getForeground():MovieClip
		{
			return m_foreground;
		}

		public function getMidground():MovieClip
		{
			return m_midground;
		}

		public function getHUDBackgroundMC():MovieClip
		{
			return new MovieClip();
		}

		public function getHUDForegroundMC():MovieClip
		{
			return new MovieClip();
		}

		public function getLightSourceMC():MovieClip
		{
			return new MovieClip();
		}

		public function getCameraBounds():MovieClip
		{
			return new MovieClip();
		}

		public function getDeathBounds():MovieClip
		{
			return new MovieClip();
		}

		public function getSmashBallBounds():MovieClip
		{
			return new MovieClip();
		}

		public function getStartingPositionMCs():Array
		{
			return [];
		}

		public function getSpawnPositionMCs():Array
		{
			return [];
		}

		public function getLedges():Array
		{
			return [];
		}

		public function getItemSpawnBoundsList():Array
		{
			return [];
		}

		public function getStarKOEnabled():Boolean
		{
			return true;
		}

		public function getScreenKOEnabled():Boolean
		{
			return true;
		}

		public function isCeilingDeathEnabled():Boolean
		{
			return true;
		}

		public function isFallDeathEnabled():Boolean
		{
			return true;
		}

		public function enableCeilingDeath(v:Boolean = true):void
		{
		}

		public function enableFallDeath(v:Boolean = true):void
		{
		}

		public function setStarKOEnabled(v:Boolean):void
		{
		}

		public function setScreenKOEnabled(v:Boolean):void
		{
		}

		public function setBackgroundOverride(mc:MovieClip):void
		{
		}

		public function setForegroundOverride(mc:MovieClip):void
		{
		}

		public function setMidgroundOverride(mc:MovieClip):void
		{
		}

		public function createTimer(a:int, b:int, c:Function, d:Object = null):void
		{
		}

		public function destroyTimer(fn:Function):void
		{
		}
	}
}
