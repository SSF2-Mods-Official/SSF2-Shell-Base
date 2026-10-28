package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;

	import ssf2mm.shared.EngineRefs;
	import ssf2mm.shared.StageBackgroundCatalog;
	import ssf2mm.shared.StageBackgroundGif;

	/** Draws the uploaded file behind the match and hides the stage's camera backgrounds. */
	public class StageBackgroundPlayer
	{
		private static var s_path:String = "";
		private static var s_layer:Sprite;
		private static var s_stream:NetStream;
		private static var s_conn:NetConnection;
		private static var s_frames:Array;
		private static var s_frame:int;
		private static var s_wait:int;
		private static var s_root:*;
		private static var s_w:Number = 640;
	private static var s_h:Number = 360;
	private static var s_armed:Boolean;

		public static function remember(path:String):void
		{
			s_path = path || "";
			var host:* = EngineRefs.ModHost;
			try
			{
				if (host)
				{
					host.setSessionFlag(StageBackgroundCatalog.FLAG, s_path.length > 0 ? s_path : null);
				};
			}
			catch (err:*)
			{
			};
		}

		public static function arm(stageData:*):void
		{
			var path:String = currentPath();
			if (!path)
			{
				return;
			};
			s_wait = 0;
			s_root = EngineRefs.Main ? EngineRefs.Main["Root"] : null;
			if (!s_root)
			{
				return;
			};
			if (!s_armed)
			{
				s_root.addEventListener(Event.ENTER_FRAME, onFrame);
				s_armed = true;
			};
		}

		public static function clear():void
		{
			disarm();
			if (s_stream)
			{
				try
				{
					s_stream.removeEventListener(NetStatusEvent.NET_STATUS, onNet);
					s_stream.close();
				}
				catch (err:*)
				{
				};
			};
			s_stream = null;
			if (s_conn)
			{
				try
				{
					s_conn.close();
				}
				catch (err:*)
				{
				};
			};
			s_conn = null;
			s_frames = null;
			if (s_layer && s_layer.parent)
			{
				s_layer.parent.removeChild(s_layer);
			};
			s_layer = null;
			remember("");
		}

		private static function onFrame(e:Event):void
		{
			var GC:*;
			var sd:*;
			var bgs:*;
			s_wait++;
			GC = EngineRefs.ssf2("controllers.GameController");
			sd = GC ? GC["stageData"] : null;
			bgs = backgrounds(sd);
			if (!bgs || bgs.length < 1)
			{
				if (s_wait > 180)
				{
					disarm();
				};
				return;
			};
			disarm();
			hideBackgrounds(bgs);
			show(currentPath(), bgs[0]);
		}

		private static function show(path:String, bg:*):void
		{
			var parent:Sprite;
			var ext:String;
			var file:File;
			if (!path || !bg || !bg.sprite)
			{
				return;
			};
			parent = bg.sprite.parent as Sprite;
			if (!parent)
			{
				return;
			};
			s_layer = new Sprite();
			s_layer.mouseEnabled = false;
			s_layer.mouseChildren = false;
			s_layer.x = bg.sprite.x;
			s_layer.y = bg.sprite.y;
			s_w = bg.sprite.width > 8 ? bg.sprite.width : 640;
			s_h = bg.sprite.height > 8 ? bg.sprite.height : 360;
			parent.addChildAt(s_layer, 0);
			file = new File(path);
			ext = extension(file.name);
			if (ext == "mp4")
			{
				playVideo(file);
			}
			else if (ext == "gif")
			{
				playGif(file);
			}
			else
			{
				playStill(file);
			};
		}

		private static function playStill(file:File):void
		{
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (e:Event):void
			{
				fit(loader);
			});
			loader.load(new URLRequest(file.url));
			s_layer.addChild(loader);
		}

		private static function playGif(file:File):void
		{
			var stream:FileStream = new FileStream();
			var bytes:ByteArray = new ByteArray();
			var bitmap:Bitmap;
			stream.open(file, FileMode.READ);
			stream.readBytes(bytes);
			stream.close();
			s_frames = StageBackgroundGif.frames(bytes);
			s_frame = 0;
			s_wait = 0;
			if (!s_frames || s_frames.length == 0)
			{
				playStill(file);
				return;
			};
			bitmap = new Bitmap(s_frames[0].image as BitmapData);
			bitmap.smoothing = true;
			s_layer.addChild(bitmap);
			fit(bitmap);
			if (s_frames.length > 1 && s_root)
			{
				s_root.addEventListener(Event.ENTER_FRAME, onGif);
			};
		}

		private static function onGif(e:Event):void
		{
			var item:Object;
			var delay:int;
			var bitmap:Bitmap;
			if (!s_layer || !s_frames || s_frames.length < 2)
			{
				return;
			};
			item = s_frames[s_frame];
			delay = item && item.delay ? int(item.delay) : 100;
			s_wait += 1000 / 60;
			if (s_wait < delay)
			{
				return;
			};
			s_wait = 0;
			s_frame = (s_frame + 1) % s_frames.length;
			bitmap = s_layer.getChildAt(0) as Bitmap;
			if (bitmap && s_frames[s_frame])
			{
				bitmap.bitmapData = s_frames[s_frame].image as BitmapData;
			};
		}

		private static function playVideo(file:File):void
		{
			var video:Video = new Video(640, 360);
			s_conn = new NetConnection();
			s_conn.connect(null);
			s_stream = new NetStream(s_conn);
			s_stream.soundTransform = new SoundTransform(0);
			s_stream.client = {"onMetaData": function (info:Object):void { }, "onCuePoint": function (info:Object):void { }};
			s_stream.addEventListener(NetStatusEvent.NET_STATUS, onNet);
			s_stream.play(file.url);
			video.attachNetStream(s_stream);
			s_layer.addChild(video);
			fit(video);
		}

		private static function onNet(e:NetStatusEvent):void
		{
			if (e.info && e.info.code == "NetStream.Play.Stop" && s_stream)
			{
				try
				{
					s_stream.seek(0);
					s_stream.resume();
				}
				catch (err:*)
				{
				};
			};
		}

		private static function fit(child:DisplayObject):void
		{
			if (!child)
			{
				return;
			};
			child.width = s_w;
			child.height = s_h;
			child.x = -s_w * 0.5;
			child.y = -s_h * 0.5;
			var line:String = "[stage_background] play x=" + child.x + " y=" + child.y + " w=" + child.width + " h=" + child.height + " layer=" + (s_layer ? s_layer.x + "," + s_layer.y : "");
			trace(line);
			try
			{
				var GL:* = EngineRefs.GameLog;
				if (GL && GL.write is Function)
				{
					GL.write(line);
				};
			}
			catch (logErr:*)
			{
			};
		}

		private static function backgrounds(sd:*):Array
		{
			var out:Array = [];
			var bgs:*;
			var i:int;
			try
			{
				bgs = sd && sd["CamRef"] ? sd["CamRef"]["BGs"] : null;
			}
			catch (err:*)
			{
				return (out);
			};
			i = 0;
			while (bgs && i < bgs.length)
			{
				if (bgs[i] && bgs[i].sprite)
				{
					out.push(bgs[i]);
				};
				i++;
			};
			return (out);
		}

		private static function hideBackgrounds(bgs:Array):void
		{
			var i:int = 0;
			while (i < bgs.length)
			{
				try
				{
					bgs[i].sprite.visible = false;
				}
				catch (err:*)
				{
				};
				i++;
			};
		}

		private static function currentPath():String
		{
			var host:*;
			var flagged:*;
			if (s_path && s_path.length > 0)
			{
				return (s_path);
			};
			host = EngineRefs.ModHost;
			try
			{
				flagged = host ? host.getSessionFlag(StageBackgroundCatalog.FLAG, null) : null;
				if (flagged != null && String(flagged).length > 0 && String(flagged) != "null")
				{
					s_path = String(flagged);
				};
			}
			catch (err:*)
			{
			};
			return (s_path);
		}

		private static function disarm():void
		{
			if (s_armed && s_root)
			{
				s_root.removeEventListener(Event.ENTER_FRAME, onFrame);
			};
			s_armed = false;
			if (s_root)
			{
				s_root.removeEventListener(Event.ENTER_FRAME, onGif);
			};
		}

		private static function extension(name:String):String
		{
			var dot:int = name ? name.lastIndexOf(".") : -1;
			return (dot < 0 ? "" : name.substr(dot + 1).toLowerCase());
		}
	}
}
