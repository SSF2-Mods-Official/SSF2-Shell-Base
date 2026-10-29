package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import ssf2mm.shared.EngineRefs;

	/** Stage preview (stagePreviewer) and logo library lookups. */
	public class MusicStageVisuals
	{
		public static const OTHER_STAGE_ID:String = "__other__";
		/** Preview frame used for the Other bucket (not listed as a stage). */
		public static const OTHER_PREVIEW_ID:String = "traininggrid";
		public static const TRAINING_GRID_ID:String = "traininggrid";
		public static const SPACE_BG_ID:String = "space";
		/** Fallback stage preview when art is missing. */
		public static const WAITING_ROOM_ID:String = "waitingroom";

		/** Rasterized stagePreviewer frames (hi-res disc art). Cap growth. */
		private static var s_previewBmp:Object = {};
		private static var s_previewBmpOrder:Array = [];
		private static const PREVIEW_BMP_CAP:int = 24;

		public static function clearPreviewBitmaps():void
		{
			var id:String;
			var bd:BitmapData;
			for (id in s_previewBmp)
			{
				bd = s_previewBmp[id] as BitmapData;
				if (bd)
				{
					try
					{
						bd.dispose();
					}
					catch (err:*)
					{
					};
				};
			};
			s_previewBmp = {};
			s_previewBmpOrder = [];
		}

		/** Stage Select shows this stage (icon and/or previewer frame). */
		public static function stageAppearsOnSelect(stageId:String):Boolean
		{
			if (!stageId || stageId == OTHER_STAGE_ID)
			{
				return (false);
			};
			if (hasStageSelectIcon(stageId))
			{
				return (true);
			};
			return (hasStagePreview(stageId));
		}

		public static function hasStageSelectIcon(stageId:String):Boolean
		{
			if (!stageId || stageId == OTHER_STAGE_ID)
			{
				return (false);
			};
			return (getLibraryMC(stageId + "_stage_select") != null);
		}

		public static function hasStagePreview(stageId:String):Boolean
		{
			var mc:MovieClip;
			var Utils:*;
			if (!stageId || stageId == OTHER_STAGE_ID)
			{
				return (true);
			};
			mc = getLibraryMC("stagePreviewer");
			if (!mc)
			{
				return (false);
			};
			try
			{
				Utils = EngineRefs.ssf2("util.Utils");
				if (Utils && Utils["hasLabel"] is Function)
				{
					return Boolean(Utils["hasLabel"](mc, stageId, false));
				};
			}
			catch (err:*)
			{
			};
			return (false);
		}

		/**
		 * Lightweight backdrop for song-list browsing: cached bitmap if present,
		 * otherwise stage_select icon. Never clones stagePreviewer (that leaked RAM).
		 */
		public static function attachStageBackdrop(parent:Sprite, stageId:String,
			viewW:Number, viewH:Number):DisplayObject
		{
			var frameId:String;
			var bd:BitmapData;
			var bmp:Bitmap;
			var host:Sprite;
			var icon:MovieClip;
			var scale:Number;
			if (!parent)
			{
				return (null);
			};
			frameId = stageId == OTHER_STAGE_ID ? OTHER_PREVIEW_ID : stageId;
			if (!frameId)
			{
				return (null);
			};
			bd = s_previewBmp[frameId] as BitmapData;
			if (bd)
			{
				host = new Sprite();
				bmp = new Bitmap(bd, "auto", true);
				host.addChild(bmp);
				scale = Math.max(viewW / bd.width, viewH / bd.height) * 1.28;
				bmp.scaleX = scale;
				bmp.scaleY = scale;
				bmp.x = (viewW - bd.width * scale) * 0.5;
				bmp.y = (viewH - bd.height * scale) * 0.5;
				parent.addChild(host);
				return (host);
			};
			icon = getLibraryMC(frameId + "_stage_select");
			if (!icon)
			{
				return (null);
			};
			try
			{
				icon = icon.clone() as MovieClip;
			}
			catch (cloneErr:*)
			{
			};
			if (!icon)
			{
				return (null);
			};
			fitPreview(icon, viewW, viewH);
			parent.addChild(icon);
			return (icon);
		}

		/**
		 * Prefer split art from stagePreviewer: hide logo on the bg frame, place a
		 * live logo clip (library or reparented from a second frame clone) at BR.
		 * Strips DropShadow/Glow filters from previewer art.
		 * Returns { preview:DisplayObject, logo:DisplayObject }.
		 */
		public static function attachStageArt(bgParent:Sprite, logoParent:Sprite, stageId:String,
			viewW:Number, viewH:Number, logoMaxH:Number):Object
		{
			var frameId:String;
			var bd:BitmapData;
			var bmp:Bitmap;
			var host:Sprite;
			var libLogo:MovieClip;
			var logoLive:DisplayObject;
			var out:Object;
			var scale:Number;
			out = {"preview": null, "logo": null};
			if (!bgParent)
			{
				return (out);
			};
			frameId = stageId == OTHER_STAGE_ID ? OTHER_PREVIEW_ID : stageId;
			if (!frameId || (stageId && String(stageId).indexOf("playlist:") == 0))
			{
				return (out);
			};
			// Bitmap cache only — never keep live stagePreviewer clones on the display list.
			bd = getOrCapturePreviewBitmap(frameId);
			if (bd)
			{
				host = new Sprite();
				bmp = new Bitmap(bd, "auto", true);
				host.addChild(bmp);
				scale = Math.max(viewW / bd.width, viewH / bd.height) * 1.28;
				bmp.scaleX = scale;
				bmp.scaleY = scale;
				bmp.x = (viewW - bd.width * scale) * 0.5;
				bmp.y = (viewH - bd.height * scale) * 0.5;
				bgParent.addChild(host);
				out.preview = host;
			}
			else
			{
				// Lightweight fallback: stage-select icon (no previewer clone).
				libLogo = getLibraryMC(frameId + "_stage_select");
				if (libLogo)
				{
					try
					{
						libLogo = libLogo.clone() as MovieClip;
					}
					catch (cloneIcon:*)
					{
					};
					if (libLogo)
					{
						fitPreview(libLogo, viewW, viewH);
						bgParent.addChild(libLogo);
						out.preview = libLogo;
					};
				};
			};
			if (!logoParent)
			{
				return (out);
			};
			logoLive = null;
			if (stageId != OTHER_STAGE_ID)
			{
				logoLive = resolveLibraryLogo(stageId);
			};
			if (logoLive)
			{
				stripFiltersDeep(logoLive);
				scaleToMaxH(logoLive, logoMaxH);
				placeBottomRight(logoLive, viewW, viewH, 28);
				logoParent.addChild(logoLive);
				out.logo = logoLive;
			};
			return (out);
		}

		/** Second previewer clone → reparent logo child (keeps vectors crisp). */
		public static function extractLiveLogo(frameId:String):DisplayObject
		{
			var frame:MovieClip;
			var host:DisplayObjectContainer;
			var logo:DisplayObject;
			var id:String;
			id = frameId == OTHER_STAGE_ID ? OTHER_PREVIEW_ID : frameId;
			frame = previewerFrame(id);
			if (!frame)
			{
				trace("[music_player] extractLiveLogo id=" + id + " step=frame");
				return (null);
			};
			host = deepestContentHost(frame);
			if (!host)
			{
				trace("[music_player] extractLiveLogo id=" + id + " step=host");
				return (null);
			};
			logo = findLogoChild(host);
			if (!logo || !logo.parent)
			{
				trace("[music_player] extractLiveLogo id=" + id + " step=child n=" + host.numChildren);
				return (null);
			};
			if (!logoLooksLikeMark(logo, host) && !isLogoName(logo.name || ""))
			{
				trace("[music_player] extractLiveLogo id=" + id + " step=reject");
				return (null);
			};
			try
			{
				logo.parent.removeChild(logo);
			}
			catch (err:*)
			{
				trace("[music_player] extractLiveLogo id=" + id + " step=child");
				return (null);
			};
			stripFiltersDeep(logo);
			return (logo);
		}

		/** Reject full-frame plates that tint into a white rectangle on album tiles. */
		private static function logoLooksLikeMark(logo:DisplayObject, host:DisplayObjectContainer):Boolean
		{
			var hb:Rectangle;
			var lb:Rectangle;
			var hostArea:Number;
			var logoArea:Number;
			if (!logo || !host)
			{
				return (false);
			};
			hb = host.getBounds(host);
			lb = logo.getBounds(host);
			hostArea = Math.max(1, hb.width * hb.height);
			logoArea = Math.max(0, lb.width * lb.height);
			if (logoArea < 64)
			{
				return (false);
			};
			// Preview plates fill most of the frame; real logos stay clearly smaller.
			if (logoArea > hostArea * 0.5)
			{
				return (false);
			};
			return (true);
		}

		/**
		 * Peel a logo child from `{stageId}_stage_select` when the previewer peel misses.
		 * Used for stages with no franchise SymbolSSS (Smashville, Steel Diver).
		 */
		public static function extractSelectLogo(stageId:String):DisplayObject
		{
			var icon:MovieClip;
			var host:DisplayObjectContainer;
			var logo:DisplayObject;
			if (!stageId || stageId == OTHER_STAGE_ID)
			{
				return (null);
			};
			icon = getLibraryMC(stageId + "_stage_select");
			if (!icon)
			{
				return (null);
			};
			try
			{
				icon = icon.clone() as MovieClip;
			}
			catch (cloneErr:*)
			{
			};
			if (!icon)
			{
				return (null);
			};
			host = deepestContentHost(icon);
			logo = findLogoChild(host);
			if (!logo || !logo.parent)
			{
				return (null);
			};
			if (!logoLooksLikeMark(logo, host) && !isLogoName(logo.name || ""))
			{
				return (null);
			};
			try
			{
				logo.parent.removeChild(logo);
			}
			catch (err:*)
			{
				return (null);
			};
			stripFiltersDeep(logo);
			return (logo);
		}

		/** @private kept for attachStageArt — recursive so nested shadow clips are hidden. */
		private static function hideShadowDecor(host:DisplayObjectContainer):void
		{
			var i:int;
			var child:DisplayObject;
			var n:String;
			if (!host)
			{
				return;
			};
			i = 0;
			while (i < host.numChildren)
			{
				child = host.getChildAt(i);
				i++;
				if (!child)
				{
					continue;
				};
				n = (child.name || "").toLowerCase();
				if (n.indexOf("shadow") >= 0 || n.indexOf("drop") >= 0 || n.indexOf("glow") >= 0
					|| n.indexOf("shade") >= 0 || n.indexOf("vignette") >= 0)
				{
					child.visible = false;
				};
				if (child is DisplayObjectContainer)
				{
					hideShadowDecor(DisplayObjectContainer(child));
				};
			};
		}

		/** Clear DropShadow / Glow / etc. on the clip tree (previewer FLA shadows). */
		private static function stripFiltersDeep(obj:DisplayObject):void
		{
			var c:DisplayObjectContainer;
			var i:int;
			if (!obj)
			{
				return;
			};
			try
			{
				obj.filters = null;
			}
			catch (filtErr:*)
			{
			};
			if (!(obj is DisplayObjectContainer))
			{
				return;
			};
			c = DisplayObjectContainer(obj);
			i = 0;
			while (i < c.numChildren)
			{
				stripFiltersDeep(c.getChildAt(i));
				i++;
			};
		}

		/**
		 * Default menu backdrop: library linkage menu_bg_<id> (e.g. menu_bg_space).
		 * Placed like engine menus: centered on the viewport at native scale,
		 * then scaled up only if it does not yet cover the screen.
		 */
		public static function attachMenuBg(parent:Sprite, bgId:String, viewW:Number, viewH:Number):MovieClip
		{
			var mc:MovieClip;
			var id:String;
			var b:Rectangle;
			var s:Number;
			if (!parent)
			{
				return (null);
			};
			id = bgId && bgId.length > 0 ? bgId : SPACE_BG_ID;
			mc = getLibraryMC("menu_bg_" + id);
			if (!mc)
			{
				mc = getLibraryMC("menu_bg_space");
			};
			if (!mc)
			{
				return (null);
			};
			try
			{
				mc = mc.clone() as MovieClip;
			}
			catch (cloneErr:*)
			{
			};
			if (!mc)
			{
				return (null);
			};
			parent.addChild(mc);
			// Menus parent this under a container at screen center — same here.
			mc.x = viewW * 0.5;
			mc.y = viewH * 0.5;
			b = mc.getBounds(parent);
			if (b.width > 1 && b.height > 1)
			{
				s = Math.max(viewW / b.width, viewH / b.height);
				if (s > 1)
				{
					mc.scaleX = s;
					mc.scaleY = s;
					mc.x = viewW * 0.5;
					mc.y = viewH * 0.5;
				};
			};
			return (mc);
		}

		/**
		 * Hi-res disc / expand art: rasterize stagePreviewer (or its original
		 * embedded BitmapData) once per stage, then reuse a smoothed Bitmap.
		 * Falls back to null when the previewer has no frame for this stage.
		 */
		public static function attachPreviewBitmap(parent:Sprite, stageId:String,
			viewW:Number, viewH:Number):Bitmap
		{
			var bd:BitmapData;
			var bmp:Bitmap;
			var s:Number;
			var id:String;
			if (!parent || viewW < 1 || viewH < 1)
			{
				return (null);
			};
			id = stageId == OTHER_STAGE_ID ? OTHER_PREVIEW_ID : stageId;
			if (!id || String(id).indexOf("playlist:") == 0)
			{
				return (null);
			};
			bd = getOrCapturePreviewBitmap(id);
			if (!bd)
			{
				return (null);
			};
			bmp = new Bitmap(bd, "auto", true);
			s = Math.max(viewW / bd.width, viewH / bd.height);
			bmp.scaleX = s;
			bmp.scaleY = s;
			bmp.x = -bd.width * s * 0.5;
			bmp.y = -bd.height * s * 0.5;
			parent.addChild(bmp);
			return (bmp);
		}

		private static function getOrCapturePreviewBitmap(stageId:String):BitmapData
		{
			var cached:BitmapData;
			var frame:MovieClip;
			var host:DisplayObjectContainer;
			var logo:DisplayObject;
			var srcBd:BitmapData;
			var b:Rectangle;
			var scale:Number;
			var target:Number;
			var bd:BitmapData;
			var m:Matrix;
			if (!stageId)
			{
				return (null);
			};
			cached = s_previewBmp[stageId] as BitmapData;
			if (cached)
			{
				return (cached);
			};
			frame = previewerFrame(stageId);
			if (!frame)
			{
				return (null);
			};
			host = deepestContentHost(frame);
			logo = findLogoChild(host);
			if (logo)
			{
				logo.visible = false;
			};
			hideShadowDecor(host);
			stripFiltersDeep(frame);
			srcBd = findLargestOriginalBitmap(host, frame);
			if (srcBd && srcBd.width > 8 && srcBd.height > 8)
			{
				try
				{
					bd = srcBd.clone();
				}
				catch (cloneBd:*)
				{
					bd = null;
				};
				if (bd)
				{
					rememberPreviewBitmap(stageId, bd);
					return (bd);
				};
			};
			try
			{
				b = frame.getBounds(frame);
				if (b.width < 1 || b.height < 1)
				{
					return (null);
				};
				// Upsample so disc art stays sharp when scaled into the jewel case.
				target = 512;
				scale = Math.min(target / b.width, target / b.height);
				if (scale < 1)
				{
					scale = 1;
				};
				if (scale > 3)
				{
					scale = 3;
				};
				bd = new BitmapData(Math.max(1, Math.ceil(b.width * scale)),
					Math.max(1, Math.ceil(b.height * scale)), true, 0);
				m = new Matrix();
				m.translate(-b.x, -b.y);
				m.scale(scale, scale);
				bd.draw(frame, m, null, null, null, true);
				rememberPreviewBitmap(stageId, bd);
				return (bd);
			}
			catch (drawErr:*)
			{
				trace("[music_player] preview bitmap capture failed " + stageId + ": " + drawErr);
			};
			return (null);
		}

		/** Same art as the in-jukebox disc/album preview (cached). Do not dispose. */
		public static function previewBitmapData(stageId:String):BitmapData
		{
			var id:String;
			if (!stageId)
			{
				return (null);
			};
			id = stageId == OTHER_STAGE_ID ? OTHER_PREVIEW_ID : stageId;
			if (!id || String(id).indexOf("playlist:") == 0)
			{
				return (null);
			};
			return (getOrCapturePreviewBitmap(id));
		}

		private static function rememberPreviewBitmap(stageId:String, bd:BitmapData):void
		{
			var oldId:String;
			var oldBd:BitmapData;
			if (!stageId || !bd)
			{
				return;
			};
			if (s_previewBmp[stageId])
			{
				s_previewBmp[stageId] = bd;
				return;
			};
			s_previewBmp[stageId] = bd;
			s_previewBmpOrder.push(stageId);
			while (s_previewBmpOrder.length > PREVIEW_BMP_CAP)
			{
				oldId = String(s_previewBmpOrder.shift());
				oldBd = s_previewBmp[oldId] as BitmapData;
				delete s_previewBmp[oldId];
				if (oldBd)
				{
					try
					{
						oldBd.dispose();
					}
					catch (err:*)
					{
					};
				};
			};
		}

		/** Prefer the largest Bitmap in the previewer tree; use palette originals when present. */
		private static function findLargestOriginalBitmap(host:DisplayObjectContainer,
			deepRoot:DisplayObject):BitmapData
		{
			var best:BitmapData;
			var bestArea:Number;
			var stack:Array;
			var node:DisplayObject;
			var bmp:Bitmap;
			var bd:BitmapData;
			var orig:BitmapData;
			var Utils:*;
			var c:DisplayObjectContainer;
			var i:int;
			var area:Number;
			best = null;
			bestArea = 0;
			if (!host)
			{
				return (null);
			};
			try
			{
				Utils = EngineRefs.ssf2("util.Utils");
			}
			catch (uErr:*)
			{
				Utils = null;
			};
			stack = [host];
			while (stack.length > 0)
			{
				node = stack.pop() as DisplayObject;
				if (!node)
				{
					continue;
				};
				if (node is Bitmap)
				{
					bmp = Bitmap(node);
					bd = bmp.bitmapData;
					orig = null;
					if (Utils && Utils["getCachedOriginalBitmapData"] is Function)
					{
						try
						{
							orig = Utils["getCachedOriginalBitmapData"](bmp, deepRoot) as BitmapData;
						}
						catch (origErr:*)
						{
							orig = null;
						};
					};
					if (orig)
					{
						bd = orig;
					};
					if (bd)
					{
						area = bd.width * bd.height;
						if (area > bestArea)
						{
							bestArea = area;
							best = bd;
						};
					};
					continue;
				};
				if (node is DisplayObjectContainer)
				{
					c = DisplayObjectContainer(node);
					i = c.numChildren - 1;
					while (i >= 0)
					{
						stack.push(c.getChildAt(i));
						i--;
					};
				};
			};
			return (best);
		}

		/**
		 * Grid tile art: lightweight stage-select icons only.
		 * Never clone stagePreviewer here — each clone copies the entire multi-frame
		 * previewer library asset into RAM (~tens of MB × visible tiles → GB spikes).
		 * Full previewer is reserved for expand / disc via attachStageArt / attachPreviewBitmap.
		 */
		public static function attachTileArt(parent:Sprite, stageId:String, viewW:Number, viewH:Number):MovieClip
		{
			var icon:MovieClip;
			var host:Sprite;
			if (!parent)
			{
				return (null);
			};
			if (!stageId || stageId == OTHER_STAGE_ID)
			{
				return (null);
			};
			icon = getLibraryMC(stageId + "_stage_select");
			if (!icon)
			{
				return (null);
			};
			try
			{
				icon = icon.clone() as MovieClip;
			}
			catch (cloneErr:*)
			{
			};
			if (!icon)
			{
				return (null);
			};
			host = new Sprite();
			host.graphics.beginFill(0x101018, 1);
			host.graphics.drawRect(0, 0, viewW, viewH);
			host.graphics.endFill();
			parent.addChild(host);
			host.addChild(icon);
			fitPreview(icon, viewW, viewH);
			return (icon);
		}

		/** Stage album icon: library logo, then the stage-select icon. */
		public static function albumMark(stageId:String):DisplayObject
		{
			var mc:MovieClip;
			if (!stageId)
			{
				return (null);
			};
			mc = resolveLibraryLogo(stageId);
			if (!mc)
			{
				mc = getLibraryMC(stageId + "_stage_select");
				if (mc)
				{
					try
					{
						mc = mc.clone() as MovieClip;
					}
					catch (cloneErr:*)
					{
					};
				};
			};
			return (mc);
		}

		private static function resolveLibraryLogo(stageId:String):MovieClip
		{
			var mc:MovieClip;
			var link:String;
			mc = getLibraryMC(stageId + "_logo");
			if (!mc)
			{
				mc = getLibraryMC("logo_" + stageId);
			};
			if (!mc)
			{
				mc = getLibraryMC(stageId + "_stage_logo");
			};
			if (!mc)
			{
				link = readStageProp(stageId, "logo");
				if (!link)
				{
					link = readStageProp(stageId, "stageLogo");
				};
				if (link)
				{
					mc = getLibraryMC(String(link));
				};
			};
			if (!mc)
			{
				mc = sheetLogo("stage_logos", stageId);
			};
			if (!mc)
			{
				mc = sheetLogo("stageLogos", stageId);
			};
			if (mc)
			{
				try
				{
					mc = mc.clone() as MovieClip;
				}
				catch (cloneErr:*)
				{
				};
			};
			return (mc);
		}

		/**
		 * Clone stagePreviewer stopped on the stage's frame.
		 * Returns null when the label is missing (avoids default training-grid art).
		 */
		public static function previewerFrame(stageId:String):MovieClip
		{
			var mc:MovieClip;
			var Utils:*;
			var ok:Boolean;
			mc = getLibraryMC("stagePreviewer");
			if (!mc || !stageId)
			{
				return (null);
			};
			try
			{
				mc = mc.clone() as MovieClip;
			}
			catch (cloneErr:*)
			{
			};
			if (!mc)
			{
				return (null);
			};
			ok = false;
			try
			{
				Utils = EngineRefs.ssf2("util.Utils");
				if (Utils && Utils["safeGotoAndStop"] is Function)
				{
					ok = Boolean(Utils["safeGotoAndStop"](mc, stageId, false));
				}
				else if (Utils && Utils["tryToGotoAndStop"] is Function && Utils["hasLabel"] is Function)
				{
					if (Boolean(Utils["hasLabel"](mc, stageId, false)))
					{
						Utils["tryToGotoAndStop"](mc, stageId);
						ok = true;
					};
				};
			}
			catch (gotoErr:*)
			{
				ok = false;
			};
			if (!ok)
			{
				return (null);
			};
			return (mc);
		}

		/** Unwrap single-child shells until the host that holds preview + logo. */
		private static function deepestContentHost(frame:MovieClip):DisplayObjectContainer
		{
			var host:DisplayObjectContainer;
			var child:DisplayObject;
			var next:DisplayObjectContainer;
			var guard:int;
			if (!frame)
			{
				return (null);
			};
			host = frame;
			guard = 0;
			while (host && host.numChildren == 1 && guard < 8)
			{
				child = host.getChildAt(0);
				guard++;
				if (!(child is DisplayObjectContainer))
				{
					break;
				};
				next = DisplayObjectContainer(child);
				if (next.numChildren < 1)
				{
					break;
				};
				if (next.numChildren > 1)
				{
					return (next);
				};
				host = next;
			};
			return (host);
		}

		private static function isLogoName(n:String):Boolean
		{
			if (!n)
			{
				return (false);
			};
			n = n.toLowerCase();
			return (n.indexOf("logo") >= 0 || n.indexOf("title") >= 0 || n.indexOf("emblem") >= 0
				|| n.indexOf("mark") >= 0 || n == "name" || n.indexOf("wordmark") >= 0
				|| n.indexOf("stagename") >= 0 || n.indexOf("stage_name") >= 0
				|| n.indexOf("label") >= 0);
		}

		/**
		 * Logo on a previewer frame: named child first (incl. nested),
		 * else the smallest sibling that is clearly not the preview plate.
		 * A single wrapper with several kids is searched inside.
		 */
		private static function findLogoChild(host:DisplayObjectContainer):DisplayObject
		{
			var i:int;
			var child:DisplayObject;
			var named:DisplayObject;
			var nested:DisplayObject;
			var small:DisplayObject;
			var largest:DisplayObject;
			var only:DisplayObjectContainer;
			var area:Number;
			var smallArea:Number;
			var largeArea:Number;
			var hostArea:Number;
			var b:Rectangle;
			var hb:Rectangle;
			var visible:int;
			if (!host || host.numChildren < 1)
			{
				return (null);
			};
			hb = host.getBounds(host);
			hostArea = Math.max(1, hb.width * hb.height);
			named = null;
			small = null;
			largest = null;
			only = null;
			smallArea = Number.MAX_VALUE;
			largeArea = 0;
			visible = 0;
			i = 0;
			while (i < host.numChildren)
			{
				child = host.getChildAt(i);
				i++;
				if (!child || !child.visible)
				{
					continue;
				};
				visible++;
				if (isLogoName(child.name || ""))
				{
					named = child;
					break;
				};
				if (child is DisplayObjectContainer && DisplayObjectContainer(child).numChildren > 0)
				{
					nested = findNamedLogoDeep(DisplayObjectContainer(child), 3);
					if (nested)
					{
						named = nested;
						break;
					};
					only = DisplayObjectContainer(child);
				};
				b = child.getBounds(host);
				area = b.width * b.height;
				if (area <= 64)
				{
					continue;
				};
				if (area > largeArea)
				{
					largeArea = area;
					largest = child;
				};
				if (area < smallArea)
				{
					smallArea = area;
					small = child;
				};
			};
			if (named)
			{
				return (named);
			};
			// One visible wrapper holding preview + logo — peel inside it.
			if (visible == 1 && only && only.numChildren >= 2)
			{
				return (findLogoChild(only));
			};
			// Must be clearly smaller than the preview plate (avoids white-rectangle tints).
			if (visible >= 2 && small && largest && small != largest
				&& smallArea < largeArea * 0.55 && smallArea < hostArea * 0.5)
			{
				return (small);
			};
			return (null);
		}

		private static function findNamedLogoDeep(host:DisplayObjectContainer, depth:int):DisplayObject
		{
			var i:int;
			var child:DisplayObject;
			var hit:DisplayObject;
			if (!host || depth < 0)
			{
				return (null);
			};
			i = 0;
			while (i < host.numChildren)
			{
				child = host.getChildAt(i);
				i++;
				if (!child || !child.visible)
				{
					continue;
				};
				if (isLogoName(child.name || ""))
				{
					return (child);
				};
				if (depth > 0 && child is DisplayObjectContainer)
				{
					hit = findNamedLogoDeep(DisplayObjectContainer(child), depth - 1);
					if (hit)
					{
						return (hit);
					};
				};
			};
			return (null);
		}

		/** Wrap icon in a Sprite on host, fit to maxSize, and center it on host's origin (disc spin pivot). */
		public static function mountCenteredIcon(host:DisplayObjectContainer, icon:DisplayObject, maxSize:Number):void
		{
			var wrap:Sprite;
			var b:Rectangle;
			var s:Number;
			wrap = new Sprite();
			host.addChild(wrap);
			icon.x = 0;
			icon.y = 0;
			icon.scaleX = 1;
			icon.scaleY = 1;
			wrap.addChild(icon);
			b = icon.getBounds(wrap);
			if (b.width > 0 && b.height > 0 && maxSize > 0)
			{
				s = maxSize / Math.max(b.width, b.height);
				if (s > 0 && s < 40)
				{
					icon.scaleX = s;
					icon.scaleY = s;
				};
				b = icon.getBounds(wrap);
				icon.x = -(b.left + b.right) * 0.5;
				icon.y = -(b.top + b.bottom) * 0.5;
			};
			b = wrap.getBounds(host);
			wrap.x = -(b.left + b.right) * 0.5;
			wrap.y = -(b.top + b.bottom) * 0.5;
		}

		private static function scaleToMaxH(obj:DisplayObject, maxH:Number):void
		{
			var s:Number;
			if (!obj || maxH <= 0 || obj.height <= 0)
			{
				return;
			};
			s = maxH / obj.height;
			if (s > 0 && s < 12)
			{
				obj.scaleX = s;
				obj.scaleY = s;
			};
		}

		private static function placeBottomRight(obj:DisplayObject, viewW:Number, viewH:Number, pad:Number):void
		{
			var b:Rectangle;
			if (!obj)
			{
				return;
			};
			b = obj.getBounds(obj);
			obj.x = viewW - pad - (b.x + b.width) * obj.scaleX;
			obj.y = viewH - pad - (b.y + b.height) * obj.scaleY;
		}

		private static function fitPreview(mc:MovieClip, tw:Number, th:Number):void
		{
			var b:Rectangle;
			var w:Number;
			var h:Number;
			var scale:Number;
			if (!mc || tw <= 0 || th <= 0)
			{
				return;
			};
			b = mc.getBounds(mc);
			w = b.width > 0 ? b.width : mc.width;
			h = b.height > 0 ? b.height : mc.height;
			if (w <= 0 || h <= 0)
			{
				return;
			};
			scale = Math.max(tw / w, th / h) * 1.28;
			mc.scaleX = scale;
			mc.scaleY = scale;
			mc.x = (tw * 0.5) - ((b.x + w * 0.5) * scale);
			mc.y = (th * 0.5) - ((b.y + h * 0.5) * scale);
		}

		private static function sheetLogo(sheetName:String, stageId:String):MovieClip
		{
			var sheet:MovieClip;
			var out:MovieClip;
			var Utils:*;
			sheet = getLibraryMC(sheetName);
			if (!sheet)
			{
				return (null);
			};
			try
			{
				out = sheet.clone() as MovieClip;
			}
			catch (err:*)
			{
				out = sheet;
			};
			try
			{
				Utils = EngineRefs.ssf2("util.Utils");
				if (Utils && Utils["safeGotoAndStop"] is Function && Utils["safeGotoAndStop"](out, stageId, false))
				{
					return (out);
				};
			}
			catch (gotoErr:*)
			{
			};
			return (null);
		}

		private static function readStageProp(stageId:String, key:String):*
		{
			var RM:*;
			var res:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				res = RM.getResourceByID(stageId, true);
				if (res)
				{
					return (res.getProp(key));
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}

		public static function getLibraryMC(name:String):MovieClip
		{
			var RM:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				return RM.getLibraryMC(name) as MovieClip;
			}
			catch (err:*)
			{
			};
			return (null);
		}

		public static function stageDisplayName(stageId:String):String
		{
			var RM:*;
			var mappings:*;
			var meta:Object;
			var stageMap:Object;
			if (stageId == OTHER_STAGE_ID)
			{
				return ("Other");
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				mappings = RM.getResourceByID("mappings");
				meta = mappings && mappings.getProp("metadata") ? mappings.getProp("metadata") : null;
				stageMap = meta && meta.stage ? meta.stage : null;
				if (stageMap && stageMap[stageId] && stageMap[stageId].name)
				{
					return String(stageMap[stageId].name);
				};
			}
			catch (err:*)
			{
			};
			return (stageId);
		}
	}
}
