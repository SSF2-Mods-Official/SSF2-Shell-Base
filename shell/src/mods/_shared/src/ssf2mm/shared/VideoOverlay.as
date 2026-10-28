package ssf2mm.shared
{
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.Timer;

	/**
	 * Full-stage black layer with a letterboxed NetStream video on top of the stage.
	 * Ends once: onDone(reason) after the overlay has already removed itself.
	 * Reasons: "complete", "stop", "watchdog", "skip", "fatal:<NetStatus code>".
	 * dispose() removes every listener, the timer, the layer and the stream without calling onDone.
	 *
	 * opts:
	 *   copyName:String           copy the file to app-storage:/ssf2_stream/<copyName> and play that url
	 *                             (paths outside the AIR app dir often StreamNotFound)
	 *   pillarWidth/pillarHeight  game size; draws 55px black bars at both edges of that width
	 *   watchdogMs:int            end with "watchdog" when no Play.Start arrives in time (0 = off)
	 *   stopRequiresStart:Boolean ignore Play.Stop before the stream started (time <= 0.15s)
	 *   onInput:Function():Boolean  key or mouse press; return true to swallow the key
	 *   onStatus:Function(code:String, info:Object, kind:String)  kind "net" or "play"
	 *   onStart:Function(code:String)  first Play.Start / Buffer.Full / Buffer.Flush
	 */
	public class VideoOverlay
	{
		private var m_log:Function;
		private var m_layer:Sprite;
		private var m_stage:Stage;
		private var m_video:Video;
		private var m_nc:NetConnection;
		private var m_ns:NetStream;
		private var m_watchdog:Timer;
		private var m_localCopy:File;
		private var m_onDone:Function;
		private var m_opts:Object;
		private var m_w:Number = 0;
		private var m_h:Number = 0;
		private var m_active:Boolean;
		private var m_started:Boolean;

		public function VideoOverlay(log:Function = null)
		{
			m_log = log;
		}

		public function get active():Boolean
		{
			return m_active;
		}

		public function get started():Boolean
		{
			return m_started;
		}

		public function get layer():Sprite
		{
			return m_layer;
		}

		public function get netStream():NetStream
		{
			return m_ns;
		}

		public function get video():Video
		{
			return m_video;
		}

		public function get localCopy():File
		{
			return m_localCopy;
		}

		/** False when setup threw; the overlay is already disposed then. */
		public function play(st:Stage, file:File, w:Number, h:Number, onDone:Function, opts:Object = null):Boolean
		{
			var storage:File;
			var url:String;
			var pw:Number;
			var ph:Number;
			var bars:Sprite;
			dispose();
			m_opts = opts || {};
			m_onDone = onDone;
			m_w = w;
			m_h = h;
			try
			{
				if (m_opts.copyName)
				{
					storage = File.applicationStorageDirectory.resolvePath("ssf2_stream");
					if (!storage.exists)
					{
						storage.createDirectory();
					};
					m_localCopy = storage.resolvePath(String(m_opts.copyName));
					file.copyTo(m_localCopy, true);
				}
				else
				{
					m_localCopy = file;
				};
				url = m_localCopy.url;
				m_layer = new Sprite();
				m_layer.graphics.beginFill(0, 1);
				m_layer.graphics.drawRect(0, 0, w, h);
				m_layer.graphics.endFill();
				pw = Number(m_opts.pillarWidth) || 0;
				ph = Number(m_opts.pillarHeight) || h;
				if (pw > 0)
				{
					bars = new Sprite();
					bars.graphics.beginFill(0, 1);
					bars.graphics.drawRect(-10, -10, 65, ph + 20);
					bars.graphics.drawRect(pw - 55, -10, 65, ph + 20);
					bars.graphics.endFill();
					m_layer.addChild(bars);
				};
				m_layer.buttonMode = true;
				m_layer.useHandCursor = true;
				m_layer.mouseChildren = false;
				m_layer.tabEnabled = false;
				m_nc = new NetConnection();
				m_nc.connect(null);
				m_ns = new NetStream(m_nc);
				m_ns.bufferTime = 0.5;
				m_ns.client = {"onMetaData": onMetaData, "onPlayStatus": onPlayStatus};
				m_ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
				m_video = new Video(int(w), int(h));
				m_video.smoothing = true;
				m_video.attachNetStream(m_ns);
				m_layer.addChild(m_video);
				m_layer.addEventListener(MouseEvent.MOUSE_DOWN, onMouse, false, 99, true);
				m_layer.addEventListener(KeyboardEvent.KEY_DOWN, onKey, false, 99, true);
				m_stage = st;
				st.addChild(m_layer);
				st.addEventListener(KeyboardEvent.KEY_DOWN, onKey, true, 99, true);
				try
				{
					st.focus = m_layer;
				}
				catch (focusErr:*)
				{
				};
				m_active = true;
				m_started = false;
				m_ns.play(url);
				if (int(m_opts.watchdogMs) > 0)
				{
					m_watchdog = new Timer(int(m_opts.watchdogMs), 1);
					m_watchdog.addEventListener(TimerEvent.TIMER, onWatchdog);
					m_watchdog.start();
				};
				return true;
			}
			catch (err:*)
			{
				log("video overlay fail: " + err);
				dispose();
			};
			return false;
		}

		/** End now with reason "skip". */
		public function skip():void
		{
			finish("skip");
		}

		public function dispose():void
		{
			var layer:Sprite = m_layer;
			var ns:NetStream = m_ns;
			var nc:NetConnection = m_nc;
			var video:Video = m_video;
			var st:Stage = m_stage;
			m_active = false;
			m_started = false;
			m_layer = null;
			m_ns = null;
			m_nc = null;
			m_video = null;
			m_stage = null;
			stopWatchdog();
			if (st)
			{
				try
				{
					st.removeEventListener(KeyboardEvent.KEY_DOWN, onKey, true);
				}
				catch (stErr:*)
				{
				};
			};
			if (layer)
			{
				try
				{
					layer.removeEventListener(MouseEvent.MOUSE_DOWN, onMouse);
					layer.removeEventListener(KeyboardEvent.KEY_DOWN, onKey);
					if (layer.parent)
					{
						layer.parent.removeChild(layer);
					};
				}
				catch (layerErr:*)
				{
				};
			};
			if (ns)
			{
				try
				{
					ns.removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
					ns.close();
				}
				catch (nsErr:*)
				{
				};
			};
			if (video)
			{
				try
				{
					video.attachNetStream(null);
					video.clear();
				}
				catch (videoErr:*)
				{
				};
			};
			if (nc)
			{
				try
				{
					nc.close();
				}
				catch (ncErr:*)
				{
				};
			};
		}

		private function finish(reason:String):void
		{
			var done:Function;
			if (!m_active && !m_layer)
			{
				return;
			};
			done = m_onDone;
			m_onDone = null;
			dispose();
			if (done != null)
			{
				done(reason);
			};
		}

		private function onMetaData(info:Object):void
		{
			var vw:Number;
			var vh:Number;
			var sc:Number;
			if (!m_video || !info)
			{
				return;
			};
			vw = Number(info.width) || 0;
			vh = Number(info.height) || 0;
			if (vw < 1 || vh < 1)
			{
				return;
			};
			sc = Math.min(m_w / vw, m_h / vh);
			m_video.width = vw * sc;
			m_video.height = vh * sc;
			m_video.x = (m_w - m_video.width) * 0.5;
			m_video.y = (m_h - m_video.height) * 0.5;
		}

		private function onPlayStatus(info:Object):void
		{
			var code:String;
			if (!info || !m_active)
			{
				return;
			};
			code = String(info.code || "");
			status(code, info, "play");
			if (code.indexOf("Complete") >= 0)
			{
				finish("complete");
			};
		}

		private function onNetStatus(e:NetStatusEvent):void
		{
			var code:String;
			if (!e || !e.info || !m_active)
			{
				return;
			};
			code = String(e.info.code || "");
			status(code, e.info, "net");
			if (code == "NetStream.Play.Start" || code == "NetStream.Buffer.Full" || code == "NetStream.Buffer.Flush")
			{
				if (!m_started)
				{
					m_started = true;
					stopWatchdog();
					if (m_opts.onStart is Function)
					{
						m_opts.onStart(code);
					};
				};
				return;
			};
			if (code.indexOf("Stop") >= 0 || code.indexOf("Complete") >= 0)
			{
				if (!m_opts.stopRequiresStart || m_started || (m_ns && m_ns.time > 0.15))
				{
					finish(code.indexOf("Complete") >= 0 ? "complete" : "stop");
				};
				return;
			};
			if (code.indexOf("Failed") >= 0 || code.indexOf("StreamNotFound") >= 0
				|| code.indexOf("FileStructureInvalid") >= 0 || code.indexOf("NoSupportedTrackFound") >= 0)
			{
				finish("fatal:" + code);
			};
		}

		private function status(code:String, info:Object, kind:String):void
		{
			if (!(m_opts.onStatus is Function))
			{
				return;
			};
			try
			{
				m_opts.onStatus(code, info, kind);
			}
			catch (err:*)
			{
			};
		}

		private function onMouse(e:MouseEvent):void
		{
			input();
		}

		private function onKey(e:KeyboardEvent):void
		{
			if (input() && e)
			{
				e.stopImmediatePropagation();
			};
		}

		private function input():Boolean
		{
			if (!m_active || !(m_opts.onInput is Function))
			{
				return false;
			};
			return Boolean(m_opts.onInput());
		}

		private function onWatchdog(e:TimerEvent):void
		{
			stopWatchdog();
			if (m_active && !m_started)
			{
				finish("watchdog");
			};
		}

		private function stopWatchdog():void
		{
			var t:Timer = m_watchdog;
			m_watchdog = null;
			if (!t)
			{
				return;
			};
			try
			{
				t.stop();
				t.removeEventListener(TimerEvent.TIMER, onWatchdog);
			}
			catch (err:*)
			{
			};
		}

		private function log(line:String):void
		{
			if (m_log != null)
			{
				try
				{
					m_log(line);
				}
				catch (err:*)
				{
				};
			};
		}
	}
}
