package com.sbxmod.paletteMaker
{
	import com.adobe.images.PNGEncoder;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;

	/**
	 * Recolors in-game portrait art and uploads a temporary HTTPS image so Discord
	 * Rich Presence can show costumes (external URL as largeImage).
	 */
	public class DiscordCostumePresence
	{
		public static var enabled:Boolean = true;

		private static const MIN_INTERVAL_MS:int = 60000;
		private static const TARGET_SIZE:int = 256;

		private static var lastUploadMs:int = 0;
		private static var uploadInFlight:Boolean = false;
		private static var pendingBd:BitmapData = null;
		private static var pendingKey:String = null;
		private static var pendingLargeText:String = null;
		private static var cachedUrlByKey:Object = {};
		private static var lastActivity:Object = null;
		private static var pmDirty:Boolean = false;

		public static function setEnabled(on:Boolean):void
		{
			enabled = on;
			if (!on)
			{
				pmDirty = false;
			};
		}

		public static function markPaletteMakerDirty():void
		{
			if (enabled)
			{
				pmDirty = true;
			};
		}

		/** Call ~once/sec from PM update loop; flushes at most once per minute. */
		public static function tickPaletteMaker(portrait:DisplayObject, largeText:String):void
		{
			var bd:BitmapData;
			var key:String;
			if (!enabled || !pmDirty || !portrait)
			{
				return;
			};
			if ((getTimer() - lastUploadMs) < MIN_INTERVAL_MS && lastUploadMs > 0)
			{
				return;
			};
			bd = captureDisplay(portrait);
			if (!bd)
			{
				return;
			};
			key = "pm:" + (largeText ? largeText : "edit");
			pmDirty = false;
			queueUpload(bd, key, largeText ? largeText : "Palette Maker");
		}

		/**
		 * Resolve largeImage for presence. Returns cached costume URL when available,
		 * otherwise the stock character key, and may kick off an async costume capture.
		 */
		public static function resolveLargeImage(characterKey:String, largeText:String, playerSettings:Object = null):String
		{
			var cacheKey:String;
			var costume:*;
			var url:String;
			if (!enabled || !characterKey)
			{
				return characterKey;
			};
			costume = playerSettings ? playerSettings.costume : null;
			cacheKey = String(characterKey) + ":" + String(costume);
			url = cachedUrlByKey[cacheKey] as String;
			if (url && url.length > 0)
			{
				return url;
			};
			maybeCaptureMatchPortrait(characterKey, cacheKey, largeText, playerSettings);
			return characterKey;
		}

		public static function rememberLastActivity(activity:Object):void
		{
			lastActivity = activity;
		}

		private static function maybeCaptureMatchPortrait(characterKey:String, cacheKey:String, largeText:String, playerSettings:Object):void
		{
			var now:int;
			var mc:MovieClip;
			var costumeData:Object;
			var bd:BitmapData;
			var costumeIdx:int;
			if (uploadInFlight)
			{
				return;
			};
			now = getTimer();
			if (lastUploadMs > 0 && (now - lastUploadMs) < MIN_INTERVAL_MS)
			{
				return;
			};
			try
			{
				costumeIdx = playerSettings ? int(playerSettings.costume) : -1;
				costumeData = Ssf2.ResourceManager.getCostume(characterKey, null, costumeIdx);
				mc = Ssf2.ResourceManager.getExpansionPortraitMC(characterKey, Ssf2.ResourceManager.ALIGN_BOTTOM);
				if (!mc)
				{
					mc = Ssf2.ResourceManager.getLibraryMC(characterKey + "_classic_trophy") as MovieClip;
				};
				if (!mc)
				{
					return;
				};
				try
				{
					if (mc.hasOwnProperty("stop"))
					{
						mc.stop();
					};
					if (mc.hasOwnProperty("gotoAndStop"))
					{
						mc.gotoAndStop(1);
					};
				}
				catch (stopErr:Error)
				{
				};
				if (costumeData)
				{
					try
					{
						Ssf2.Utils.setColorFilter(mc, costumeData);
					}
					catch (paintErr:Error)
					{
					};
				};
				bd = captureDisplay(mc);
				if (!bd)
				{
					return;
				};
				queueUpload(bd, cacheKey, largeText ? largeText : characterKey);
			}
			catch (err:Error)
			{
				trace("[DiscordCostumePresence] capture failed:", err.message);
			};
		}

		private static function captureDisplay(target:DisplayObject):BitmapData
		{
			var bounds:Rectangle;
			var bd:BitmapData;
			var m:Matrix;
			var scale:Number;
			if (!target)
			{
				return null;
			};
			try
			{
				bounds = target.getBounds(target);
				if (!bounds || bounds.width < 1 || bounds.height < 1)
				{
					return null;
				};
				scale = Math.min(TARGET_SIZE / bounds.width, TARGET_SIZE / bounds.height);
				if (scale > 4)
				{
					scale = 4;
				};
				if (scale < 0.1)
				{
					scale = 0.1;
				};
				bd = new BitmapData(Math.max(1, int(bounds.width * scale)), Math.max(1, int(bounds.height * scale)), true, 0);
				m = new Matrix();
				m.translate(-bounds.x, -bounds.y);
				m.scale(scale, scale);
				bd.draw(target, m, null, null, null, true);
				return bd;
			}
			catch (err:Error)
			{
				return null;
			};
			return null;
		}

		private static function queueUpload(bd:BitmapData, cacheKey:String, largeText:String):void
		{
			if (uploadInFlight)
			{
				if (pendingBd)
				{
					pendingBd.dispose();
				};
				pendingBd = bd;
				pendingKey = cacheKey;
				pendingLargeText = largeText;
				return;
			};
			startUpload(bd, cacheKey, largeText);
		}

		private static function startUpload(bd:BitmapData, cacheKey:String, largeText:String):void
		{
			var bytes:ByteArray;
			var boundary:String;
			var body:ByteArray;
			var req:URLRequest;
			var loader:URLLoader;
			var header:String;
			uploadInFlight = true;
			lastUploadMs = getTimer();
			try
			{
				bytes = PNGEncoder.encode(bd);
				bd.dispose();
			}
			catch (encErr:Error)
			{
				uploadInFlight = false;
				try { bd.dispose(); } catch (dErr:Error) {}
				flushPending();
				return;
			};
			boundary = "----SSF2Discord" + getTimer();
			body = new ByteArray();
			header = "--" + boundary + "\r\n";
			header += "Content-Disposition: form-data; name=\"reqtype\"\r\n\r\n";
			header += "fileupload\r\n";
			header += "--" + boundary + "\r\n";
			header += "Content-Disposition: form-data; name=\"time\"\r\n\r\n";
			header += "1h\r\n";
			header += "--" + boundary + "\r\n";
			header += "Content-Disposition: form-data; name=\"fileToUpload\"; filename=\"discord_preview.png\"\r\n";
			header += "Content-Type: image/png\r\n\r\n";
			body.writeUTFBytes(header);
			body.writeBytes(bytes);
			body.writeUTFBytes("\r\n--" + boundary + "--\r\n");
			req = new URLRequest("https://litterbox.catbox.moe/resources/internals/api.php");
			req.method = URLRequestMethod.POST;
			req.contentType = "multipart/form-data; boundary=" + boundary;
			req.data = body;
			loader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, function(e:Event):void
			{
				var url:String = String(loader.data || "").replace(/^\s+|\s+$/g, "");
				uploadInFlight = false;
				if (url.indexOf("https://") == 0 || url.indexOf("http://") == 0)
				{
					cachedUrlByKey[cacheKey] = url;
					pushPresenceWithUrl(url, largeText);
				};
				flushPending();
			});
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void
			{
				uploadInFlight = false;
				trace("[DiscordCostumePresence] upload IO error");
				flushPending();
			});
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(e:SecurityErrorEvent):void
			{
				uploadInFlight = false;
				trace("[DiscordCostumePresence] upload security error");
				flushPending();
			});
			try
			{
				loader.load(req);
			}
			catch (loadErr:Error)
			{
				uploadInFlight = false;
				flushPending();
			};
		}

		private static function flushPending():void
		{
			var bd:BitmapData;
			var key:String;
			var text:String;
			if (!pendingBd)
			{
				return;
			};
			bd = pendingBd;
			key = pendingKey;
			text = pendingLargeText;
			pendingBd = null;
			pendingKey = null;
			pendingLargeText = null;
			if ((getTimer() - lastUploadMs) >= MIN_INTERVAL_MS)
			{
				startUpload(bd, key, text);
			}
			else
			{
				bd.dispose();
			};
		}

		private static function pushPresenceWithUrl(url:String, largeText:String):void
		{
			var activity:Object;
			var k:String;
			if (!Ssf2.Main.m_sdk || !Ssf2.Config.rich_presence)
			{
				return;
			};
			if (lastActivity)
			{
				activity = {};
				for (k in lastActivity)
				{
					activity[k] = lastActivity[k];
				};
				activity["largeImage"] = url;
				if (largeText)
				{
					activity["largeText"] = largeText;
				};
				try
				{
					Ssf2.Main.m_sdk.updateActivity(activity);
				}
				catch (err:Error)
				{
				};
			};
		}
	}
}
