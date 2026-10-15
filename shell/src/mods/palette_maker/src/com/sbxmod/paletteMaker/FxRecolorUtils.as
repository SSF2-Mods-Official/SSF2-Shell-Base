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

	/** FX recolor math: adjust matrices, baked fighter FX, stance frames, FX groups and projectile alias maps. */
	public class FxRecolorUtils
	{
		private static const LUMINANCER:Number = 0.3086;

		private static const LUMINANCEG:Number = 0.6094;

		private static const LUMINANCEB:Number = 0.0820;

		private static const ADJUST_DELTA_INDEX:Array = [
			0, 0.01, 0.02, 0.04, 0.05, 0.06, 0.07, 0.08, 0.1, 0.11, 0.12, 0.14, 0.15, 0.16,
			0.17, 0.18, 0.2, 0.21, 0.22, 0.24, 0.25, 0.27, 0.28, 0.3, 0.32, 0.34, 0.36, 0.38,
			0.4, 0.42, 0.44, 0.46, 0.48, 0.5, 0.53, 0.56, 0.59, 0.62, 0.65, 0.68, 0.71, 0.74,
			0.77, 0.8, 0.83, 0.86, 0.89, 0.92, 0.95, 0.98, 1, 1.06, 1.12, 1.18, 1.24, 1.3,
			1.36, 1.42, 1.48, 1.54, 1.6, 1.66, 1.72, 1.78, 1.84, 1.9, 1.96, 2, 2.12, 2.25,
			2.37, 2.5, 2.62, 2.75, 2.87, 3, 3.2, 3.4, 3.6, 3.8, 4, 4.3, 4.7, 4.9, 5, 5.5,
			6, 6.5, 6.8, 7, 7.3, 7.5, 7.8, 8, 8.4, 8.7, 9, 9.4, 9.6, 9.8, 10
		];

		/** 4x4 row-major identity. */
		private static function mat4Identity():Array
		{
			return [
				1, 0, 0, 0,
				0, 1, 0, 0,
				0, 0, 1, 0,
				0, 0, 0, 1
			];
		}

		private static function mat4Mul(a:Array, b:Array):Array
		{
			var out:Array = new Array(16);
			var r:int;
			var c:int;
			var k:int;
			var s:Number;
			r = 0;
			while (r < 4)
			{
				c = 0;
				while (c < 4)
				{
					s = 0;
					k = 0;
					while (k < 4)
					{
						s += Number(a[r * 4 + k]) * Number(b[k * 4 + c]);
						k++;
					};
					out[r * 4 + c] = s;
					c++;
				};
				r++;
			};
			return out;
		}

		private static function brightnessMat4(value:Number):Array
		{
			var m:Array = mat4Identity();
			if (value != 0)
			{
				m[3] = value;
				m[7] = value;
				m[11] = value;
			};
			return m;
		}

		private static function contrastMat4(value:Number):Array
		{
			var x:Number;
			var scale:Number;
			var offset:Number;
			var m:Array;
			if (value == 0)
			{
				x = 127;
			}
			else if (value > 0)
			{
				x = Number(ADJUST_DELTA_INDEX[int(value)]) * 127 + 127;
			}
			else
			{
				x = value / 100 * 127 + 127;
			};
			scale = x / 127;
			offset = 0.5 * (127 - x);
			m = mat4Identity();
			m[0] = scale;
			m[5] = scale;
			m[10] = scale;
			m[3] = offset;
			m[7] = offset;
			m[11] = offset;
			return m;
		}

		private static function saturationMat4(value:Number):Array
		{
			var s:Number;
			var inv:Number;
			var m:Array;
			if (value == 0)
			{
				s = 1;
			}
			else if (value > 0)
			{
				s = 1 + 3 * value / 100;
			}
			else
			{
				s = value / 100 + 1;
			};
			inv = 1 - s;
			m = mat4Identity();
			m[0] = inv * LUMINANCER + s;
			m[1] = inv * LUMINANCEG;
			m[2] = inv * LUMINANCEB;
			m[4] = inv * LUMINANCER;
			m[5] = inv * LUMINANCEG + s;
			m[6] = inv * LUMINANCEB;
			m[8] = inv * LUMINANCER;
			m[9] = inv * LUMINANCEG;
			m[10] = inv * LUMINANCEB + s;
			return m;
		}

		private static function hueMat4(degrees:Number):Array
		{
			var rad:Number;
			var c:Number;
			var s:Number;
			var r:Number = 0.213;
			var g:Number = 0.715;
			var b:Number = 0.072;
			var m:Array;
			if (degrees == 0)
			{
				return mat4Identity();
			};
			rad = degrees * Math.PI / 180;
			c = Math.cos(rad);
			s = Math.sin(rad);
			m = mat4Identity();
			m[0] = r + c * (1 - r) + s * (-r);
			m[1] = g + c * (-g) + s * (-g);
			m[2] = b + c * (-b) + s * (1 - b);
			m[4] = r + c * (-r) + s * 0.143;
			m[5] = g + c * (1 - g) + s * 0.140;
			m[6] = b + c * (-b) + s * (-0.283);
			m[8] = r + c * (-r) + s * (-(1 - r));
			m[9] = g + c * (-g) + s * g;
			m[10] = b + c * (1 - b) + s * b;
			return m;
		}

		/** Match fl.motion.AdjustColor order: hue * sat * contrast * brightness. */
		public static function buildAdjustColorMat4(hue:Number, saturation:Number, brightness:Number, contrast:Number):Array
		{
			return mat4Mul(hueMat4(hue || 0),
				mat4Mul(saturationMat4(saturation || 0),
					mat4Mul(contrastMat4(contrast || 0), brightnessMat4(brightness || 0))));
		}

		/** Flash ColorMatrixFilter 20-value flat array (alpha passthrough). */
		public static function mat4ToColorMatrixFlat(m:Array):Array
		{
			return [
				m[0], m[1], m[2], 0, m[3],
				m[4], m[5], m[6], 0, m[7],
				m[8], m[9], m[10], 0, m[11],
				0, 0, 0, 1, 0
			];
		}

		/** Apply AdjustColor as ColorMatrixFilter on a display object (effects preview). */
		public static function applyAdjustColorFilters(target:DisplayObject, hue:Number, saturation:Number, brightness:Number, contrast:Number):void
		{
			var flat:Array;
			if (!target)
			{
				return;
			};
			if ((hue || 0) == 0 && (saturation || 0) == 0 && (brightness || 0) == 0 && (contrast || 0) == 0)
			{
				target.filters = null;
				return;
			};
			flat = mat4ToColorMatrixFlat(buildAdjustColorMat4(hue || 0, saturation || 0, brightness || 0, contrast || 0));
			target.filters = [new ColorMatrixFilter(flat)];
		}

		/**
		 * Bake FX group HSBC + solid tint into BitmapData (strip preview — reliable vs parent filters).
		 */
		public static function applyFxGroupToBitmapData(bd:BitmapData, group:Object):void
		{
			var hue:Number;
			var sat:Number;
			var bri:Number;
			var contrast:Number;
			var color:uint;
			var flat:Array;
			var filter:ColorMatrixFilter;
			var tmp:BitmapData;
			var amt:Number;
			var r:Number;
			var g:Number;
			var b:Number;
			var ct:ColorTransform;
			var m:Matrix;
			if (!bd || !group || !fxGroupHasAdjust(group))
			{
				return;
			};
			hue = isNaN(Number(group.hue)) ? 0 : Number(group.hue);
			sat = isNaN(Number(group.saturation)) ? 0 : Number(group.saturation);
			bri = isNaN(Number(group.brightness)) ? 0 : Number(group.brightness);
			contrast = isNaN(Number(group.contrast)) ? 0 : Number(group.contrast);
			if (hue != 0 || sat != 0 || bri != 0 || contrast != 0)
			{
				flat = mat4ToColorMatrixFlat(buildAdjustColorMat4(hue, sat, bri, contrast));
				filter = new ColorMatrixFilter(flat);
				try
				{
					bd.applyFilter(bd, bd.rect, new Point(0, 0), filter);
				}
				catch (filtErr:*)
				{
				};
			};
			color = PaletteMakerUtils.coerceColorValue(group.color);
			if (color == 0 || (color & 0x00FFFFFF) == 0)
			{
				return;
			};
			// Strong tint so strip preview is obvious (esp. after sat=-100).
			amt = (sat <= -50) ? 0.92 : 0.75;
			r = (color >> 16) & 0xFF;
			g = (color >> 8) & 0xFF;
			b = color & 0xFF;
			ct = new ColorTransform(
				1 - amt, 1 - amt, 1 - amt, 1,
				r * amt, g * amt, b * amt, 0);
			tmp = new BitmapData(bd.width, bd.height, true, 0x00000000);
			m = new Matrix();
			tmp.draw(bd, m, ct, null, null, false);
			bd.copyPixels(tmp, tmp.rect, new Point(0, 0));
			tmp.dispose();
		}

		/** Weak cache: BitmapData -> pristine clone before baked FX. */
		private static var s_bakedFxOriginal:Dictionary = new Dictionary(true);

		/** Weak cache: BitmapData -> last applied signature string. */
		private static var s_bakedFxDoneSig:Dictionary = new Dictionary(true);

		/** Weak cache: BitmapData -> fingerprint of last FX result (detect engine rewrites). */
		private static var s_bakedFxResultFp:Dictionary = new Dictionary(true);

		/** Last MC we applied whole-MC FX filters to (cleared when frame changes). */
		private static var s_bakedMcFiltered:DisplayObject = null;

		/** Last baked-mc pass stats (for match/studio debug). */
		public static var lastBakedMcName:String = "";

		/**
		 * Body-owned ARGB keys from paletteSwap + paletteSwapPA (colors and replacements).
		 * Live sheets usually show replacements; both sides must be excluded from FX.
		 */
		public static function buildBodyOwnedColorSet(costume:Object):Object
		{
			var owned:Object;
			var blocks:Array;
			var bi:int;
			var block:Object;
			var arr:Array;
			var i:int;
			var c:uint;
			owned = {};
			if (!costume)
			{
				return owned;
			};
			blocks = [costume.paletteSwap, costume.paletteSwapPA];
			bi = 0;
			while (bi < blocks.length)
			{
				block = blocks[bi];
				bi++;
				if (!block)
				{
					continue;
				};
				arr = (block.colors is Array) ? (block.colors as Array) : null;
				if (arr)
				{
					i = 0;
					while (i < arr.length)
					{
						c = PaletteMakerUtils.coerceColorValue(arr[i]);
						addBodyOwnedColorKey(owned, c);
						i++;
					};
				};
				arr = (block.replacements is Array) ? (block.replacements as Array) : null;
				if (arr)
				{
					i = 0;
					while (i < arr.length)
					{
						c = PaletteMakerUtils.coerceColorValue(arr[i]);
						addBodyOwnedColorKey(owned, c);
						i++;
					};
				};
			};
			return owned;
		}

		private static function addBodyOwnedColorKey(owned:Object, c:uint):void
		{
			var rgb:uint;
			if (!owned)
			{
				return;
			};
			rgb = c & 0x00FFFFFF;
			owned[String(c)] = true;
			owned[String(rgb)] = true;
			owned[String(0xFF000000 | rgb)] = true;
		}

		/** Prefer adjusting group with linkages; else first adjusting group. */
		public static function pickFxGroupForBakedExclude(costume:Object):Object
		{
			var groups:Array;
			var i:int;
			var g:Object;
			var links:Array;
			var fallback:Object;
			if (!costume)
			{
				return null;
			};
			groups = ensureFxGroups(costume);
			fallback = null;
			i = 0;
			while (i < groups.length)
			{
				g = groups[i];
				i++;
				if (!fxGroupHasAdjust(g))
				{
					continue;
				};
				links = (g.linkages is Array) ? (g.linkages as Array) : [];
				if (links && links.length > 0)
				{
					return g;
				};
				if (!fallback)
				{
					fallback = g;
				};
			};
			return fallback;
		}

		private static function fxGroupCacheSignature(group:Object):String
		{
			if (!group)
			{
				return "";
			};
			return String(group.id || "")
				+ "|" + String(Number(group.hue) || 0)
				+ "|" + String(Number(group.saturation) || 0)
				+ "|" + String(Number(group.brightness) || 0)
				+ "|" + String(Number(group.contrast) || 0)
				+ "|" + String(PaletteMakerUtils.coerceColorValue(group.color));
		}

		private static function bodyOwnedCacheSignature(owned:Object):String
		{
			var n:int;
			var mix:uint;
			var k:String;
			n = 0;
			mix = 0;
			if (owned)
			{
				for (k in owned)
				{
					n++;
					mix ^= uint(parseInt(k, 10));
				};
			};
			return String(n) + ":" + String(mix);
		}

		private static function bitmapContentFingerprint(bd:BitmapData):String
		{
			var w:int;
			var h:int;
			if (!bd)
			{
				return "";
			};
			w = bd.width;
			h = bd.height;
			if (w < 1 || h < 1)
			{
				return "0";
			};
			return String(w) + "x" + String(h)
				+ ":" + String(bd.getPixel32(0, 0))
				+ ":" + String(bd.getPixel32(w - 1, 0))
				+ ":" + String(bd.getPixel32(0, h - 1))
				+ ":" + String(bd.getPixel32(w >> 1, h >> 1));
		}

		private static function isBodyOwnedPixel(owned:Object, px:uint):Boolean
		{
			var rgb:uint;
			if (!owned)
			{
				return false;
			};
			rgb = px & 0x00FFFFFF;
			return owned[String(px)] || owned[String(rgb)] || owned[String(0xFF000000 | rgb)];
		}

		private static function isStanceChromeName(low:String):Boolean
		{
			if (!low)
			{
				return true;
			};
			return low == "stance"
				|| low.indexOf("groundref") >= 0
				|| low.indexOf("collison") >= 0
				|| low.indexOf("collision") >= 0
				|| low.indexOf("itembox") >= 0
				|| low.indexOf("itemplaceholder") >= 0
				|| low.indexOf("hitbox") >= 0
				|| low.indexOf("hurtbox") >= 0
				|| low.indexOf("attackbox") >= 0
				|| low == "attackbox"
				|| low == "aurabase"
				|| low.indexOf("aura") == 0;
		}

		/** Containers we never select but still walk into (stance wraps animation frames). */
		private static function isStanceDescendOnlyName(low:String):Boolean
		{
			return low == "stance"
				|| low == "aurabase"
				|| (low && low.indexOf("aura") == 0);
		}

		/**
		 * Named attack/special anim frames. No bare "attack" — that matches attackBox.
		 */
		public static function isAttackStanceFrameName(low:String):Boolean
		{
			if (!low || isStanceChromeName(low))
			{
				return false;
			};
			return low.indexOf("special") >= 0 || low.indexOf("smash") >= 0
				|| low.indexOf("tilt") >= 0
				|| low.indexOf("jab") >= 0 || low.indexOf("aerial") >= 0
				|| low.indexOf("fair") >= 0 || low.indexOf("bair") >= 0
				|| low.indexOf("dair") >= 0 || low.indexOf("uair") >= 0
				|| low.indexOf("nair") >= 0 || low.indexOf("throw") >= 0
				|| low.indexOf("attack_") >= 0 || low.indexOf("_attack") >= 0;
		}

		/** Score a stance-frame candidate by name/shape. Higher wins. Mirrors air_fx_smoke. */
		public static function scoreStanceFrameCandidate(low:String, isContainer:Boolean, hasSize:Boolean):int
		{
			var score:int;
			if (!low || isStanceChromeName(low))
			{
				return -999;
			};
			score = 1;
			if (low.indexOf("instance") == 0)
			{
				score -= 8;
			};
			if (isAttackStanceFrameName(low))
			{
				score += 25;
			}
			else if (low.indexOf("dash") >= 0 || low.indexOf("guard") >= 0
				|| low.indexOf("idle") >= 0 || low.indexOf("walk") >= 0
				|| low.indexOf("run") >= 0 || low.indexOf("jump") >= 0
				|| low.indexOf("fall") >= 0 || low.indexOf("land") >= 0)
			{
				score += 10;
			};
			if (isContainer)
			{
				score += 1;
			};
			if (hasSize)
			{
				score += 1;
			};
			return score;
		}

		private static var s_bakedFindTick:int = 0;

		private static var s_bakedFindCacheRoot:DisplayObject = null;

		private static var s_bakedFindCacheMc:DisplayObject = null;

		private static var s_bakedFindCacheName:String = "";

		private static var s_bakedFindCacheAt:int = -999;

		/** Why baked FX paint was skipped (for logs). */
		public static var lastFxSwapSkipReason:String = "";

		/**
		 * Active named animation frame under fighter root (depth-limited).
		 * Never returns stance/root chrome. Requires score >= 15, else null.
		 */
		public static function findActiveStanceFrameMc(root:DisplayObject):DisplayObject
		{
			var host:DisplayObjectContainer;
			var state:Object;
			var counter:Object;
			var best:DisplayObject;
			var bestScore:int;
			var low:String;
			var cachedOk:Boolean;
			lastFxSwapSkipReason = "";
			if (!(root is DisplayObjectContainer))
			{
				lastFxSwapSkipReason = "no-root";
				return null;
			};
			host = root as DisplayObjectContainer;
			s_bakedFindTick++;
			cachedOk = false;
			if (s_bakedFindCacheRoot === root
				&& s_bakedFindCacheMc != null
				&& (s_bakedFindTick - s_bakedFindCacheAt) < 4)
			{
				try
				{
					low = s_bakedFindCacheMc.name ? String(s_bakedFindCacheMc.name) : "";
					cachedOk = (low == s_bakedFindCacheName)
						&& s_bakedFindCacheMc.stage != null;
				}
				catch (cacheErr:*)
				{
					cachedOk = false;
				};
			};
			if (cachedOk)
			{
				return s_bakedFindCacheMc;
			};
			state = { "best": null, "score": -1 };
			counter = { "n": 0 };
			// Prefer in-tree *special* frames even if invisible (Kame stays listed during N-Special).
			walkStanceFrameCandidates(host, 0, 6, 250, counter, state, true);
			best = state.best as DisplayObject;
			bestScore = int(state.score);
			low = "";
			try { low = best && best.name ? String(best.name).toLowerCase() : ""; } catch (blErr:*) { low = ""; };
			if (!best || bestScore < 15 || !isAttackStanceFrameName(low))
			{
				lastFxSwapSkipReason = "no-attack-frame";
				s_bakedFindCacheRoot = root;
				s_bakedFindCacheMc = null;
				s_bakedFindCacheName = "";
				s_bakedFindCacheAt = s_bakedFindTick;
				return null;
			};
			try { low = best.name ? String(best.name) : ""; } catch (nErr:*) { low = ""; };
			s_bakedFindCacheRoot = root;
			s_bakedFindCacheMc = best;
			s_bakedFindCacheName = low;
			s_bakedFindCacheAt = s_bakedFindTick;
			return best;
		}

		/**
		 * @param includeInvisibleAttack when true, score attack-named frames even if invisible
		 *        (and still score other visible named frames). When false, visible-only.
		 */
		private static function walkStanceFrameCandidates(
			host:DisplayObjectContainer,
			depth:int,
			maxDepth:int,
			maxNodes:int,
			counter:Object,
			state:Object,
			includeInvisibleAttack:Boolean):void
		{
			var i:int;
			var n:int;
			var child:DisplayObject;
			var low:String;
			var vis:Boolean;
			var score:int;
			var hasSize:Boolean;
			var bestScore:int;
			var descendOnly:Boolean;
			var isAttack:Boolean;
			var canScore:Boolean;
			if (!host || depth > maxDepth)
			{
				return;
			};
			bestScore = int(state.score);
			try { n = host.numChildren; } catch (err:*) { return; };
			i = 0;
			while (i < n)
			{
				if (int(counter.n) >= maxNodes)
				{
					break;
				};
				try { child = host.getChildAt(i); } catch (e:*) { child = null; };
				i++;
				if (!child)
				{
					continue;
				};
				counter.n = int(counter.n) + 1;
				low = "";
				try { low = child.name ? String(child.name).toLowerCase() : ""; } catch (nErr:*) { low = ""; };
				descendOnly = isStanceDescendOnlyName(low);
				if (isStanceChromeName(low) && !descendOnly)
				{
					continue;
				};
				if (descendOnly)
				{
					if ((depth + 1) <= maxDepth && (child is DisplayObjectContainer))
					{
						walkStanceFrameCandidates(
							child as DisplayObjectContainer, depth + 1, maxDepth, maxNodes,
							counter, state, includeInvisibleAttack);
						bestScore = int(state.score);
					};
					continue;
				};
				vis = true;
				try { vis = child.visible && child.alpha > 0.01; } catch (vErr:*) { vis = true; };
				isAttack = isAttackStanceFrameName(low);
				canScore = vis || (includeInvisibleAttack && isAttack);
				if (canScore)
				{
					hasSize = false;
					try { hasSize = int(child.width * child.height) > 0; } catch (sErr:*) { hasSize = false; };
					score = scoreStanceFrameCandidate(low, child is DisplayObjectContainer, hasSize);
					if (score > bestScore)
					{
						bestScore = score;
						state.best = child;
						state.score = bestScore;
					};
				};
				if ((depth + 1) <= maxDepth && (child is DisplayObjectContainer))
				{
					walkStanceFrameCandidates(
						child as DisplayObjectContainer, depth + 1, maxDepth, maxNodes,
						counter, state, includeInvisibleAttack);
					bestScore = int(state.score);
				};
			};
		}

		/** Last FX palette-swap pass stats. */
		public static var lastFxSwapBitmaps:int = 0;

		public static var lastFxSwapVisitedBitmaps:int = 0;

		public static var lastFxSwapBlockColors:int = 0;

		public static var lastFxSwapName:String = "";

		/** One-line child class dump for last baked stance frame (Kame diagnostics). */
		public static var lastFxStanceChildDump:String = "";

		/** Bitmap -> { sig, source:BitmapData, painted:BitmapData } */
		private static var s_fxSwapPainted:Dictionary = new Dictionary(true);
		/** statsName -> projectile FX alias map */
		private static var s_fxAliasMapCache:Dictionary = new Dictionary();

		/**
		 * Build {colors, replacements} mapping non-body (or all) sample colors to FX group color.
		 * Approach #1 — exact ARGB swap like body paletteSwap.
		 */
		public static function buildFxPaletteBlockForSample(
			costume:Object,
			sampleBd:BitmapData,
			excludeBody:Boolean = true):Object
		{
			var group:Object;
			var target:uint;
			var owned:Object;
			var found:Array;
			var colors:Array;
			var repls:Array;
			var i:int;
			var c:uint;
			var a:uint;
			var rgb:uint;
			var pr:uint;
			var pg:uint;
			var pb:uint;
			var seen:Object;
			var existing:Object;
			if (!costume || !sampleBd)
			{
				return null;
			};
			group = pickFxGroupForBakedExclude(costume);
			if (!group || !fxGroupHasAdjust(group))
			{
				return null;
			};
			target = PaletteMakerUtils.coerceColorValue(group.color);
			if ((target & 0x00FFFFFF) == 0)
			{
				return null;
			};
			owned = excludeBody ? buildBodyOwnedColorSet(costume) : {};
			colors = [];
			repls = [];
			seen = {};
			// Prefer explicit paletteSwapFX sources when present.
			existing = costume.paletteSwapFX;
			if (existing && (existing.colors is Array))
			{
				i = 0;
				while (i < (existing.colors as Array).length)
				{
					c = PaletteMakerUtils.coerceColorValue(existing.colors[i]);
					i++;
					if (seen[String(c)])
					{
						continue;
					};
					if (excludeBody && isBodyOwnedPixel(owned, c))
					{
						continue;
					};
					seen[String(c)] = true;
					a = (c >> 24) & 0xFF;
					if (a < 8)
					{
						a = 0xFF;
					};
					colors.push(c);
					repls.push((a << 24) | (target & 0x00FFFFFF));
				};
			};
			found = PaletteColorAnalysis.collectOpaqueColorsInBitmapData(sampleBd, 1);
			i = 0;
			while (i < found.length)
			{
				c = PaletteMakerUtils.coerceColorValue(found[i]);
				i++;
				if (seen[String(c)])
				{
					continue;
				};
				a = (c >> 24) & 0xFF;
				if (a < 8)
				{
					continue;
				};
				rgb = c & 0x00FFFFFF;
				pr = (rgb >> 16) & 0xFF;
				pg = (rgb >> 8) & 0xFF;
				pb = rgb & 0xFF;
				if (pr < 16 && pg < 16 && pb < 16)
				{
					continue;
				};
				if (excludeBody && isBodyOwnedPixel(owned, c))
				{
					continue;
				};
				seen[String(c)] = true;
				colors.push(c);
				repls.push((a << 24) | (target & 0x00FFFFFF));
			};
			if (colors.length == 0)
			{
				return null;
			};
			return { "colors": colors, "replacements": repls };
		}

		/**
		 * Clone sample -> replacePaletteHelper -> rebind Bitmap to painted clone.
		 * Does not mutate the engine's live buffer (avoids flash race).
		 * @return 1 if painted this call, else 0
		 */
		public static function applyFxPaletteSwapToBitmap(
			bmp:Bitmap,
			costume:Object,
			excludeBody:Boolean = true):int
		{
			var bd:BitmapData;
			var block:Object;
			var group:Object;
			var sig:String;
			var entry:Object;
			var source:BitmapData;
			var painted:BitmapData;
			var fp:String;
			if (!bmp || !costume)
			{
				return 0;
			};
			try
			{
				bd = bmp.bitmapData;
			}
			catch (bdErr:*)
			{
				return 0;
			};
			if (!bd)
			{
				return 0;
			};
			group = pickFxGroupForBakedExclude(costume);
			if (!group)
			{
				return 0;
			};
			entry = s_fxSwapPainted[bmp];
			fp = bitmapContentFingerprint(bd);
			sig = fxGroupCacheSignature(group)
				+ "#" + bodyOwnedCacheSignature(excludeBody ? buildBodyOwnedColorSet(costume) : {})
				+ "#" + fp;
			if (entry && entry.sig == sig && bmp.bitmapData === entry.painted)
			{
				return 0;
			};
			try
			{
				if (entry && bmp.bitmapData === entry.painted && entry.source)
				{
					source = entry.source as BitmapData;
				}
				else
				{
					source = bd.clone();
				};
				block = buildFxPaletteBlockForSample(costume, source, excludeBody);
				if (!block)
				{
					return 0;
				};
				try
				{
					lastFxSwapBlockColors = (block.colors is Array) ? int((block.colors as Array).length) : 0;
				}
				catch (bcErr:*)
				{
					lastFxSwapBlockColors = 0;
				};
				painted = source.clone();
				PaletteDeep.replacePaletteHelper(painted, block, false);
				bmp.bitmapData = painted;
				s_fxSwapPainted[bmp] = {
					"sig": fxGroupCacheSignature(group)
						+ "#" + bodyOwnedCacheSignature(excludeBody ? buildBodyOwnedColorSet(costume) : {})
						+ "#" + bitmapContentFingerprint(source),
					"source": source,
					"painted": painted
				};
				return 1;
			}
			catch (paintErr:*)
			{
				return 0;
			};
		}

		/** Walk display tree; palette-swap every Bitmap. excludeBody for fighter sheets. */
		public static function applyFxPaletteSwapToDisplayObject(
			root:DisplayObject,
			costume:Object,
			excludeBody:Boolean = true,
			maxDepth:int = 10,
			maxNodes:int = 500,
			linkageTinted:Dictionary = null):int
		{
			var painted:int;
			var counter:Object;
			if (!root || !costume || !costumeHasFxAdjust(costume))
			{
				return 0;
			};
			lastFxSwapVisitedBitmaps = 0;
			painted = 0;
			if (root is Bitmap)
			{
				lastFxSwapVisitedBitmaps = 1;
				return applyFxPaletteSwapToBitmap(root as Bitmap, costume, excludeBody);
			};
			if (root is DisplayObjectContainer)
			{
				counter = { "n": 0, "painted": 0, "visited": 0 };
				painted = walkFxPaletteSwapBitmaps(
					root as DisplayObjectContainer, costume, excludeBody, linkageTinted,
					0, maxDepth, maxNodes, counter);
				lastFxSwapVisitedBitmaps = int(counter.visited);
			};
			return painted;
		}

		private static function walkFxPaletteSwapBitmaps(
			host:DisplayObjectContainer,
			costume:Object,
			excludeBody:Boolean,
			linkageTinted:Dictionary,
			depth:int,
			maxDepth:int,
			maxNodes:int,
			counter:Object):int
		{
			var i:int;
			var n:int;
			var child:DisplayObject;
			var lowName:String;
			if (!host || depth > maxDepth)
			{
				return int(counter.painted);
			};
			try { n = host.numChildren; } catch (err:*) { return int(counter.painted); };
			i = 0;
			while (i < n)
			{
				if (int(counter.n) >= maxNodes)
				{
					break;
				};
				try { child = host.getChildAt(i); } catch (childErr:*) { child = null; };
				i++;
				if (!child)
				{
					continue;
				};
				counter.n = int(counter.n) + 1;
				if (isUnderLinkageTinted(child, linkageTinted))
				{
					continue;
				};
				lowName = "";
				try { lowName = child.name ? String(child.name).toLowerCase() : ""; } catch (nameErr:*) { lowName = ""; };
				if (isStanceChromeName(lowName))
				{
					continue;
				};
				if (child is Bitmap)
				{
					counter.visited = int(counter.visited) + 1;
					if (applyFxPaletteSwapToBitmap(child as Bitmap, costume, excludeBody) > 0)
					{
						counter.painted = int(counter.painted) + 1;
					};
				}
				else if ((depth + 1) <= maxDepth && (child is DisplayObjectContainer))
				{
					walkFxPaletteSwapBitmaps(
						child as DisplayObjectContainer, costume, excludeBody, linkageTinted,
						depth + 1, maxDepth, maxNodes, counter);
				};
			};
			return int(counter.painted);
		}

		/**
		 * Universal FX path (#1): exact ARGB palette swap on active stance-frame bitmaps.
		 * Rebinds to painted clones — does not fight the engine live buffer.
		 */
		public static function applyFxGroupsToFighterBakedMc(
			root:DisplayObject,
			costume:Object,
			linkageTinted:Dictionary = null,
			maxDepth:int = 10,
			maxNodes:int = 500,
			statsName:String = null):int
		{
			var frameMc:DisplayObject;
			var painted:int;
			var low:String;
			lastFxSwapBitmaps = 0;
			lastFxSwapVisitedBitmaps = 0;
			lastFxSwapBlockColors = 0;
			lastFxSwapName = "";
			lastFxSwapSkipReason = "";
			lastFxStanceChildDump = "";
			lastBakedMcName = "";
			if (!root || !costume || !costumeHasFxAdjust(costume))
			{
				return 0;
			};
			if (s_bakedMcFiltered)
			{
				clearFxDisplayAdjust(s_bakedMcFiltered);
				s_bakedMcFiltered = null;
			};
			frameMc = findActiveStanceFrameMc(root);
			if (!frameMc)
			{
				lastFxSwapName = "";
				lastBakedMcName = "";
				if (!lastFxSwapSkipReason)
				{
					lastFxSwapSkipReason = "no-attack-frame";
				};
				return 0;
			};
			try { low = frameMc.name ? String(frameMc.name) : ""; } catch (nErr:*) { low = ""; };
			lastFxSwapName = low;
			lastBakedMcName = low;
			lastFxStanceChildDump = sampleStanceFrameChildTypes(frameMc, 24);
			painted = applyFxPaletteSwapToDisplayObject(
				frameMc, costume, true, maxDepth, maxNodes, linkageTinted);
			lastFxSwapBitmaps = painted;
			if (painted == 0 && lastFxSwapVisitedBitmaps == 0)
			{
				lastFxSwapSkipReason = "no-bitmaps";
			}
			else if (painted == 0 && lastFxSwapVisitedBitmaps > 0 && lastFxSwapBlockColors == 0)
			{
				lastFxSwapSkipReason = "blockColors=0";
			};
			return painted;
		}

		/** Compact child type list for Kame/baked FX diagnostics (e.g. Bitmap vs Shape). */
		public static function sampleStanceFrameChildTypes(frameMc:DisplayObject, maxKids:int = 24):String
		{
			var host:DisplayObjectContainer;
			var i:int;
			var n:int;
			var child:DisplayObject;
			var parts:Array;
			var cname:String;
			var nm:String;
			if (!frameMc)
			{
				return "";
			};
			parts = [];
			try
			{
				parts.push("self=" + getQualifiedClassName(frameMc));
			}
			catch (selfErr:*)
			{
				parts.push("self=?");
			};
			if (!(frameMc is DisplayObjectContainer))
			{
				return parts.join(",");
			};
			host = frameMc as DisplayObjectContainer;
			try { n = host.numChildren; } catch (nErr:*) { return parts.join(","); };
			parts.push("n=" + n);
			i = 0;
			while (i < n && i < maxKids)
			{
				try { child = host.getChildAt(i); } catch (cErr:*) { child = null; };
				i++;
				if (!child)
				{
					continue;
				};
				nm = "";
				try { nm = child.name ? String(child.name) : ""; } catch (nmErr:*) { nm = ""; };
				cname = "";
				try { cname = getQualifiedClassName(child); } catch (qErr:*) { cname = "?"; };
				if (cname.indexOf("::") >= 0)
				{
					cname = cname.substr(cname.lastIndexOf(":") + 1);
				};
				if (child is Bitmap)
				{
					cname = cname + "/Bitmap";
				};
				parts.push((nm || "?") + ":" + cname);
			};
			return parts.join(",");
		}

		private static function isUnderLinkageTinted(obj:DisplayObject, linkageTinted:Dictionary):Boolean
		{
			var p:DisplayObject;
			if (!obj || !linkageTinted)
			{
				return false;
			};
			p = obj;
			while (p)
			{
				if (linkageTinted[p])
				{
					return true;
				};
				try { p = p.parent; } catch (err:*) { break; };
			};
			return false;
		}

		/**
		 * Spawned/attach FX: apply HSBC/color filters first (visible tint proof for vector MCs).
		 * Then try palette-swap on Bitmaps when present (additive).
		 * @return { painted:int, fallbackFilters:int }
		 */
		public static function applyFxSwapOrFilters(
			target:DisplayObject,
			costume:Object,
			group:Object,
			maxDepth:int = 8,
			maxNodes:int = 200):Object
		{
			var painted:int;
			var usedFilters:int;
			if (!target || !costume || !group)
			{
				return { "painted": 0, "fallbackFilters": 0 };
			};
			usedFilters = 0;
			if (fxGroupHasAdjust(group))
			{
				applyFxGroupFilters(target, group);
				usedFilters = 1;
			};
			painted = applyFxPaletteSwapToDisplayObject(
				target, costume, false, maxDepth, maxNodes, null);
			return { "painted": painted, "fallbackFilters": usedFilters };
		}

		/** Clear FX filters and tint on a display object. */
		public static function clearFxDisplayAdjust(target:DisplayObject):void
		{
			if (!target)
			{
				return;
			};
			try
			{
				target.filters = null;
			}
			catch (err:*)
			{
			};
			try
			{
				target.transform.colorTransform = new ColorTransform();
			}
			catch (err2:*)
			{
			};
		}

		/**
		 * Apply one fxGroups entry: HSBC ColorMatrixFilter + optional solid color tint.
		 * color == 0 means no solid tint (HSBC only).
		 * Also tints direct Bitmap children (strip holders).
		 */
		public static function applyFxGroupFilters(target:DisplayObject, group:Object):void
		{
			var hue:Number;
			var sat:Number;
			var bri:Number;
			var contrast:Number;
			var color:uint;
			var amt:Number;
			var r:Number;
			var g:Number;
			var b:Number;
			var ct:ColorTransform;
			var holder:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			if (!target)
			{
				return;
			};
			if (!group || !fxGroupHasAdjust(group))
			{
				clearFxDisplayAdjust(target);
				if (target is DisplayObjectContainer)
				{
					holder = target as DisplayObjectContainer;
					i = 0;
					while (i < holder.numChildren)
					{
						child = holder.getChildAt(i);
						if (child is Bitmap)
						{
							clearFxDisplayAdjust(child);
						};
						i++;
					};
				};
				return;
			};
			hue = isNaN(Number(group.hue)) ? 0 : Number(group.hue);
			sat = isNaN(Number(group.saturation)) ? 0 : Number(group.saturation);
			bri = isNaN(Number(group.brightness)) ? 0 : Number(group.brightness);
			contrast = isNaN(Number(group.contrast)) ? 0 : Number(group.contrast);
			applyAdjustColorFilters(target, hue, sat, bri, contrast);
			if (target is DisplayObjectContainer)
			{
				holder = target as DisplayObjectContainer;
				i = 0;
				while (i < holder.numChildren)
				{
					child = holder.getChildAt(i);
					if (child is Bitmap)
					{
						applyAdjustColorFilters(child, hue, sat, bri, contrast);
					};
					i++;
				};
			};
			color = PaletteMakerUtils.coerceColorValue(group.color);
			if (color == 0 || (color & 0x00FFFFFF) == 0)
			{
				try
				{
					target.transform.colorTransform = new ColorTransform();
				}
				catch (ctClear:*)
				{
				};
				return;
			};
			amt = (sat <= -50) ? 0.92 : 0.75;
			r = (color >> 16) & 0xFF;
			g = (color >> 8) & 0xFF;
			b = color & 0xFF;
			ct = new ColorTransform(
				1 - amt, 1 - amt, 1 - amt, 1,
				r * amt, g * amt, b * amt, 0);
			try
			{
				target.transform.colorTransform = ct;
			}
			catch (ctErr:*)
			{
			};
			if (target is DisplayObjectContainer)
			{
				holder = target as DisplayObjectContainer;
				i = 0;
				while (i < holder.numChildren)
				{
					child = holder.getChildAt(i);
					if (child is Bitmap)
					{
						try
						{
							child.transform.colorTransform = ct;
						}
						catch (childCt:*)
						{
						};
					};
					i++;
				};
			};
		}

		public static function fxGroupHasAdjust(group:Object):Boolean
		{
			var color:uint;
			if (!group)
			{
				return false;
			};
			if ((Number(group.hue) || 0) != 0
				|| (Number(group.saturation) || 0) != 0
				|| (Number(group.brightness) || 0) != 0
				|| (Number(group.contrast) || 0) != 0)
			{
				return true;
			};
			color = PaletteMakerUtils.coerceColorValue(group.color);
			return color != 0 && (color & 0x00FFFFFF) != 0;
		}

		public static function costumeHasFxAdjust(costume:Object):Boolean
		{
			var groups:Array;
			var i:int;
			var g:Object;
			if (!costume)
			{
				return false;
			};
			ensureFxGroups(costume);
			groups = costume.fxGroups as Array;
			if (groups)
			{
				i = 0;
				while (i < groups.length)
				{
					g = groups[i];
					if (fxGroupHasAdjust(g))
					{
						return true;
					};
					i++;
				};
			};
			return (Number(costume.fxHue) || 0) != 0
				|| (Number(costume.fxSaturation) || 0) != 0
				|| (Number(costume.fxBrightness) || 0) != 0
				|| (Number(costume.fxContrast) || 0) != 0;
		}

		/** Ensure fxGroups exists; migrate legacy top-level fxHue* into one all-FX group. */
		public static function ensureFxGroups(costume:Object):Array
		{
			var groups:Array;
			var legacy:Object;
			var i:int;
			if (!costume)
			{
				return [];
			};
			groups = costume.fxGroups as Array;
			if (groups)
			{
				i = 0;
				while (i < groups.length)
				{
					groups[i] = coerceFxGroup(groups[i], i);
					i++;
				};
				costume.fxGroups = groups;
				return groups;
			};
			groups = [];
			if ((Number(costume.fxHue) || 0) != 0
				|| (Number(costume.fxSaturation) || 0) != 0
				|| (Number(costume.fxBrightness) || 0) != 0
				|| (Number(costume.fxContrast) || 0) != 0)
			{
				legacy = {
					id: "legacy",
					name: "All effects",
					linkages: [],
					color: 0,
					hue: Number(costume.fxHue) || 0,
					saturation: Number(costume.fxSaturation) || 0,
					brightness: Number(costume.fxBrightness) || 0,
					contrast: Number(costume.fxContrast) || 0
				};
				groups.push(coerceFxGroup(legacy, 0));
			};
			costume.fxGroups = groups;
			return groups;
		}

		public static function coerceFxGroup(raw:Object, index:int):Object
		{
			var g:Object;
			var links:Array;
			var i:int;
			var s:String;
			g = raw || {};
			if (!(g.id is String) || String(g.id).length == 0)
			{
				g.id = "fxg_" + index + "_" + getTimer();
			};
			if (!(g.name is String) || String(g.name).length == 0)
			{
				g.name = "FX group " + (index + 1);
			};
			links = [];
			if (g.linkages is Array)
			{
				i = 0;
				while (i < (g.linkages as Array).length)
				{
					s = String((g.linkages as Array)[i] || "").toLowerCase();
					if (s.length > 0 && links.indexOf(s) < 0)
					{
						links.push(s);
					};
					i++;
				};
			};
			g.linkages = links;
			g.color = PaletteMakerUtils.coerceColorValue(g.color);
			// Preserve negative HSBC (e.g. sat=-100); avoid `Number(x) || 0` which is fine for -100
			// but be explicit for NaN.
			g.hue = isNaN(Number(g.hue)) ? 0 : Number(g.hue);
			g.saturation = isNaN(Number(g.saturation)) ? 0 : Number(g.saturation);
			g.brightness = isNaN(Number(g.brightness)) ? 0 : Number(g.brightness);
			g.contrast = isNaN(Number(g.contrast)) ? 0 : Number(g.contrast);
			return g;
		}

		/**
		 * Find fx group for a linkage/effect id.
		 * Prefer a group that lists the linkage (or projectile alias); else empty-linkages fallback.
		 * aliasMap: optional lowercase key -> Array of lowercase aliases (from ProjectilesArray).
		 */
		public static function findFxGroupForLinkage(costume:Object, linkageOrId:String, aliasMap:Object = null):Object
		{
			var groups:Array;
			var i:int;
			var g:Object;
			var low:String;
			var fallback:Object;
			var links:Array;
			var j:int;
			var link:String;
			if (!costume)
			{
				return null;
			};
			groups = ensureFxGroups(costume);
			low = linkageOrId ? String(linkageOrId).toLowerCase() : "";
			fallback = null;
			i = 0;
			while (i < groups.length)
			{
				g = groups[i];
				links = (g && g.linkages is Array) ? (g.linkages as Array) : [];
				if (links.length == 0)
				{
					if (!fallback)
					{
						fallback = g;
					};
				}
				else if (low)
				{
					j = 0;
					while (j < links.length)
					{
						link = String(links[j] || "").toLowerCase();
						if (link && fxLinkagesMatch(link, low, aliasMap))
						{
							return g;
						};
						j++;
					};
				};
				i++;
			};
			return fallback;
		}

		/** True when two linkage ids are equal or share a projectile alias. */
		public static function fxLinkagesMatch(a:String, b:String, aliasMap:Object = null):Boolean
		{
			var la:String;
			var lb:String;
			var list:*;
			var i:int;
			var s:String;
			la = a ? String(a).toLowerCase() : "";
			lb = b ? String(b).toLowerCase() : "";
			if (!la || !lb)
			{
				return false;
			};
			if (la == lb)
			{
				return true;
			};
			if (!aliasMap)
			{
				return false;
			};
			list = aliasMap[la];
			if (list is Array)
			{
				i = 0;
				while (i < (list as Array).length)
				{
					s = String((list as Array)[i] || "").toLowerCase();
					if (s == lb)
					{
						return true;
					};
					i++;
				};
			};
			list = aliasMap[lb];
			if (list is Array)
			{
				i = 0;
				while (i < (list as Array).length)
				{
					s = String((list as Array)[i] || "").toLowerCase();
					if (s == la)
					{
						return true;
					};
					i++;
				};
			};
			return false;
		}

		/**
		 * Build lowercase alias map from ProjectilesArray: each stats key and LinkageID
		 * maps to the set of related ids (so goku_kame1 <-> b1).
		 */
		public static function buildProjectileFxAliasMap(statsName:String):Object
		{
			var map:Object;
			var st:*;
			var key:*;
			var proj:*;
			var lid:String;
			var k:String;
			var pair:Array;
			if (!statsName)
			{
				return {};
			};
			if (s_fxAliasMapCache[statsName] !== undefined)
			{
				return s_fxAliasMapCache[statsName];
			};
			map = {};
			s_fxAliasMapCache[statsName] = map;
			try
			{
				st = Ssf2.Stats.getStats(PaletteMakerUtils.getUniqueSpriteScanStatsName(statsName));
			}
			catch (stErr:*)
			{
				st = null;
			};
			if (!st)
			{
				try
				{
					st = Ssf2.Stats.getStats(statsName);
				}
				catch (stErr2:*)
				{
					st = null;
				};
			};
			if (st && st.Attacks && st.Attacks.ProjectilesArray)
			{
				for (key in st.Attacks.ProjectilesArray)
				{
					proj = st.Attacks.ProjectilesArray[key];
					k = key ? String(key).toLowerCase() : "";
					lid = "";
					if (proj && proj.LinkageID)
					{
						lid = String(proj.LinkageID).toLowerCase();
					}
					else if (proj && proj.linkage_id)
					{
						lid = String(proj.linkage_id).toLowerCase();
					};
					pair = [];
					if (k)
					{
						pair.push(k);
					};
					if (lid && pair.indexOf(lid) < 0)
					{
						pair.push(lid);
					};
					if (pair.length == 0)
					{
						continue;
					};
					addFxAliasEntries(map, pair);
				};
			};
			// Goku / Cloney beams are library MCs often missing from ProjectilesArray.
			addKnownBeamFxAliases(map, statsName);
			return map;
		}

		public static function clearProjectileFxAliasCache():void
		{
			s_fxAliasMapCache = new Dictionary();
		}

		/** Hardcoded beam aliases when pData omits kame / kiblast entries. */
		private static function addKnownBeamFxAliases(map:Object, statsName:String):void
		{
			var scan:String;
			if (!map)
			{
				return;
			};
			scan = statsName ? String(statsName).toLowerCase() : "";
			if (scan != "goku" && scan != "cloney" && scan.indexOf("goku") < 0)
			{
				return;
			};
			addFxAliasEntries(map, ["b1", "goku_kame1", "kame1", "goku_b1"]);
			addFxAliasEntries(map, ["b2", "goku_kame2", "kame2", "goku_b2"]);
			addFxAliasEntries(map, ["b3", "goku_kame3", "kame3"]);
			addFxAliasEntries(map, ["b4", "goku_kame4", "kame4"]);
			addFxAliasEntries(map, ["b25", "goku_kame25", "kame25"]);
			addFxAliasEntries(map, ["blast", "kiblast", "goku_blast", "goku_kiblast"]);
		}

		private static function addFxAliasEntries(map:Object, ids:Array):void
		{
			var i:int;
			var j:int;
			var a:String;
			var b:String;
			var list:Array;
			if (!map || !ids)
			{
				return;
			};
			i = 0;
			while (i < ids.length)
			{
				a = String(ids[i] || "").toLowerCase();
				i++;
				if (!a)
				{
					continue;
				};
				list = (map[a] is Array) ? (map[a] as Array) : [];
				j = 0;
				while (j < ids.length)
				{
					b = String(ids[j] || "").toLowerCase();
					j++;
					if (b && list.indexOf(b) < 0)
					{
						list.push(b);
					};
				};
				map[a] = list;
			};
		}

		/**
		 * Body/form/stance ids that must never receive fighter-tree FX filters
		 * (even if accidentally listed in fxGroups).
		 */
		public static function isUnsafeFighterFxTarget(linkage:String, statsName:String = null):Boolean
		{
			var low:String;
			var scan:String;
			if (!linkage)
			{
				return true;
			};
			low = String(linkage).toLowerCase();
			if (low == "stance" || low == "mc" || low == "main")
			{
				return true;
			};
			if (low.indexOf("instance") == 0)
			{
				return true;
			};
			if (isSharedStageEffectId(low))
			{
				return true;
			};
			if (statsName)
			{
				scan = String(statsName).toLowerCase();
				if (scan && (low == scan || low == scan + "_head" || low == scan + "_stock"))
				{
					return true;
				};
			};
			// Portrait / form / head shells that bled body when filtered.
			if (low == "p1" || low == "p2" || low == "p15"
				|| low == "khead" || low == "sshead"
				|| low == "kgoku" || low == "ssgoku"
				|| low == "dragon")
			{
				return true;
			};
			if (low.length >= 5 && low.substr(low.length - 5) == "_head")
			{
				return true;
			};
			if (low.length >= 6 && low.substr(low.length - 6) == "_stock")
			{
				return true;
			};
			// Locomotion / hurt sheets.
			if (low.indexOf("_idle") >= 0 || low.indexOf("_walk") >= 0
				|| low.indexOf("_run") >= 0 || low.indexOf("_jump") >= 0
				|| low.indexOf("_fall") >= 0 || low.indexOf("_hurt") >= 0
				|| low.indexOf("_land") >= 0 || low.indexOf("_crouch") >= 0
				|| low.indexOf("_guard") >= 0 || low.indexOf("_shield") >= 0
				|| low.indexOf("_dodge") >= 0 || low.indexOf("_roll") >= 0
				|| low.indexOf("_tumble") >= 0 || low.indexOf("_hitstun") >= 0)
			{
				return true;
			};
			if (low.indexOf("_gif_") >= 0 || low.indexOf("afterimage") >= 0)
			{
				return true;
			};
			return false;
		}

		/**
		 * Shallow walk of fighter display tree; tint only children whose linkage/name
		 * matches an fxGroups entry. Never filters the root itself. Caps depth/nodes.
		 * @param outLinkageTinted optional Dictionary filled with nodes that received linkage FX
		 * @return number of nodes tinted
		 */
		public static function applyFxGroupsToFighterDisplayTree(
			root:DisplayObject,
			costume:Object,
			aliases:Object = null,
			maxDepth:int = 8,
			maxNodes:int = 250,
			statsName:String = null,
			outLinkageTinted:Dictionary = null):int
		{
			var tinted:int;
			var counter:Object;
			if (!root || !costume || !costumeHasFxAdjust(costume))
			{
				return 0;
			};
			if (maxDepth < 1)
			{
				maxDepth = 1;
			};
			if (maxNodes < 8)
			{
				maxNodes = 8;
			};
			if (!statsName)
			{
				try
				{
					statsName = costume.statsName ? String(costume.statsName)
						: (costume.character ? String(costume.character) : null);
				}
				catch (snErr:*)
				{
					statsName = null;
				};
			};
			tinted = 0;
			counter = { "n": 0, "tintedNodes": outLinkageTinted };
			if (root is DisplayObjectContainer)
			{
				tinted = walkFighterFxChildren(
					root as DisplayObjectContainer, costume, aliases, statsName,
					0, maxDepth, maxNodes, counter);
			};
			return tinted;
		}

		private static function walkFighterFxChildren(
			host:DisplayObjectContainer,
			costume:Object,
			aliases:Object,
			statsName:String,
			depth:int,
			maxDepth:int,
			maxNodes:int,
			counter:Object):int
		{
			var tinted:int;
			var i:int;
			var n:int;
			var child:DisplayObject;
			var linkage:String;
			var group:Object;
			var lowName:String;
			var descend:Boolean;
			var tintedNodes:Dictionary;
			tinted = 0;
			tintedNodes = (counter && counter.tintedNodes is Dictionary)
				? (counter.tintedNodes as Dictionary) : null;
			if (!host || depth > maxDepth)
			{
				return 0;
			};
			try
			{
				n = host.numChildren;
			}
			catch (err:*)
			{
				return 0;
			};
			i = 0;
			while (i < n)
			{
				if (int(counter.n) >= maxNodes)
				{
					break;
				};
				try
				{
					child = host.getChildAt(i);
				}
				catch (childErr:*)
				{
					child = null;
				};
				i++;
				if (!child)
				{
					continue;
				};
				counter.n = int(counter.n) + 1;
				lowName = "";
				try
				{
					lowName = child.name ? String(child.name).toLowerCase() : "";
				}
				catch (nameErr:*)
				{
					lowName = "";
				};
				// Stance holds body art — never tint stance itself, but descend so
				// named FX children (e.g. Goku b1/b2 under timeline) can still match.
				if (lowName == "stance")
				{
					if ((depth + 1) <= maxDepth && (child is DisplayObjectContainer))
					{
						tinted += walkFighterFxChildren(
							child as DisplayObjectContainer, costume, aliases, statsName,
							depth + 1, maxDepth, maxNodes, counter);
					};
					continue;
				};
				linkage = resolveDisplayFxLinkage(child, null);
				if ((!linkage || linkage.length == 0) && lowName && lowName.indexOf("instance") != 0
					&& !isGenericDisplayClassName(lowName))
				{
					linkage = lowName;
				};
				if (linkage && !isUnsafeFighterFxTarget(linkage, statsName) && !isSharedStageEffectId(linkage))
				{
					group = findFxGroupForLinkage(costume, linkage, aliases);
					// Only apply when group explicitly lists this linkage (or alias).
					// Skip empty-linkages "all FX" fallback here — that would tint random children.
					if (group && fxGroupExplicitlyListsLinkage(group, linkage, aliases)
						&& fxGroupHasAdjust(group))
					{
						applyFxSwapOrFilters(child, costume, group, 6, 120);
						tinted++;
						if (tintedNodes)
						{
							tintedNodes[child] = true;
						};
					};
				};
				descend = (depth + 1) <= maxDepth && (child is DisplayObjectContainer);
				if (descend && lowName != "stance")
				{
					tinted += walkFighterFxChildren(
						child as DisplayObjectContainer, costume, aliases, statsName,
						depth + 1, maxDepth, maxNodes, counter);
				};
			};
			return tinted;
		}

		/** True when group.linkages explicitly contains linkage (or alias) — not empty fallback. */
		public static function fxGroupExplicitlyListsLinkage(group:Object, linkage:String, aliases:Object = null):Boolean
		{
			var links:Array;
			var i:int;
			var link:String;
			var low:String;
			if (!group || !linkage)
			{
				return false;
			};
			links = (group.linkages is Array) ? (group.linkages as Array) : [];
			if (!links || links.length == 0)
			{
				return false;
			};
			low = String(linkage).toLowerCase();
			i = 0;
			while (i < links.length)
			{
				link = String(links[i] || "").toLowerCase();
				if (link && fxLinkagesMatch(link, low, aliases))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		public static function getFxGroupById(costume:Object, id:String):Object
		{
			var groups:Array;
			var i:int;
			var g:Object;
			if (!costume || !id)
			{
				return null;
			};
			groups = ensureFxGroups(costume);
			i = 0;
			while (i < groups.length)
			{
				g = groups[i];
				if (g && String(g.id) == String(id))
				{
					return g;
				};
				i++;
			};
			return null;
		}

		public static function stripFxGroups(costume:Object):void
		{
			var groups:Array;
			var kept:Array;
			var i:int;
			var g:Object;
			var links:Array;
			if (!costume)
			{
				return;
			};
			groups = costume.fxGroups as Array;
			if (!groups)
			{
				return;
			};
			kept = [];
			i = 0;
			while (i < groups.length)
			{
				g = coerceFxGroup(groups[i], i);
				links = g.linkages as Array;
				if (!fxGroupHasAdjust(g) && (!links || links.length == 0))
				{
					i++;
					continue;
				};
				if (!fxGroupHasAdjust(g))
				{
					delete g.hue;
					delete g.saturation;
					delete g.brightness;
					delete g.contrast;
					delete g.color;
					g.hue = 0;
					g.saturation = 0;
					g.brightness = 0;
					g.contrast = 0;
					g.color = 0;
				};
				if ((Number(g.hue) || 0) == 0) delete g.hue;
				if ((Number(g.saturation) || 0) == 0) delete g.saturation;
				if ((Number(g.brightness) || 0) == 0) delete g.brightness;
				if ((Number(g.contrast) || 0) == 0) delete g.contrast;
				if ((PaletteMakerUtils.coerceColorValue(g.color) & 0x00FFFFFF) == 0) delete g.color;
				kept.push(g);
				i++;
			};
			if (kept.length == 0)
			{
				delete costume.fxGroups;
			}
			else
			{
				costume.fxGroups = kept;
			};
		}

		/** True for flash.display.* / unnamed timeline shells that are not library linkages. */
		public static function isGenericDisplayClassName(qn:String):Boolean
		{
			var low:String;
			if (!qn)
			{
				return true;
			};
			low = String(qn).toLowerCase();
			if (low.indexOf("::") != -1)
			{
				low = low.substring(low.lastIndexOf(":") + 1);
			};
			return low == "movieclip"
				|| low == "sprite"
				|| low == "bitmap"
				|| low == "bitmapdata"
				|| low == "shape"
				|| low == "morphshape"
				|| low == "simplebutton"
				|| low == "textfield"
				|| low == "video"
				|| low == "avm1movie"
				|| low == "loader"
				|| low == "displayobject"
				|| low == "displayobjectcontainer"
				|| low == "interactiveobject"
				|| low == "object";
		}

		/**
		 * Resolve FX linkage for a display node.
		 * Prefer library export class over instance name — Goku beams are often
		 * class b1/b2 with name instanceN or a non-matching timeline name.
		 */
		public static function resolveDisplayFxLinkage(obj:DisplayObject, fallbackId:* = null):String
		{
			var s:String;
			var classLink:String;
			var nameLink:String;
			var fallback:String;
			if (!obj && fallbackId == null)
			{
				return null;
			};
			if (obj)
			{
				try
				{
					if (obj["pmFxLinkage"])
					{
						s = String(obj["pmFxLinkage"]);
						if (s && s.length > 0)
						{
							return s.toLowerCase();
						};
					};
				}
				catch (err:*)
				{
				};
				classLink = null;
				try
				{
					s = effectIdToLower(obj);
					if (s && !isGenericDisplayClassName(s))
					{
						classLink = s;
					};
				}
				catch (classErr:*)
				{
					classLink = null;
				};
				nameLink = null;
				try
				{
					s = obj.name;
					if (s && s.length > 0 && s.indexOf("instance") != 0 && !isGenericDisplayClassName(s))
					{
						nameLink = s.toLowerCase();
					};
				}
				catch (err2:*)
				{
					nameLink = null;
				};
				// Library export class is authoritative for tint matching.
				if (classLink)
				{
					return classLink;
				};
				if (nameLink)
				{
					return nameLink;
				};
			};
			fallback = effectIdToLower(fallbackId);
			if (fallback && fallback.indexOf("instance") != 0 && !isGenericDisplayClassName(fallback))
			{
				return fallback;
			};
			return null;
		}

		/**
		 * Shared stage FX that must not inherit character fxHue
		 * (jump/land dust, bounce, etc.).
		 */
		public static function isSharedStageEffectId(id:*):Boolean
		{
			var low:String;
			low = effectIdToLower(id);
			if (!low)
			{
				return false;
			};
			return low == "dust"
				|| low == "ground_bounce"
				|| low == "effect_jump"
				|| low == "effect_doublejump"
				|| low == "effect_run"
				|| low == "effect_land"
				|| low.indexOf("ground_bounce") != -1
				|| low.indexOf("effect_jump") != -1
				|| low.indexOf("effect_doublejump") != -1
				|| low.indexOf("effect_run") != -1
				|| low.indexOf("effect_land") != -1;
		}

		/** True when linkage/name looks like character VFX (sparks, electric, bursts, etc.). */
		public static function isVfxRecolorLinkage(linkage:String):Boolean
		{
			var low:String;
			if (!linkage)
			{
				return false;
			};
			low = linkage.toLowerCase();
			return low.indexOf("sparkle") != -1
				|| low.indexOf("spark") != -1
				|| low.indexOf("electric") != -1
				|| low.indexOf("thunder") != -1
				|| low.indexOf("volt") != -1
				|| low.indexOf("jolt") != -1
				|| low.indexOf("glow") != -1
				|| low.indexOf("burst") != -1
				|| low.indexOf("fireball") != -1
				|| low.indexOf("missile_wind") != -1
				|| low.indexOf("explosion") != -1
				|| low.indexOf("koeffect") != -1
				|| low.indexOf("ko_effect") != -1
				|| low.indexOf("targetreticule") != -1
				|| low.indexOf("_fsbar") != -1
				|| low.indexOf("fs_cutin") != -1
				|| low.indexOf("_hud") != -1
				|| low.indexOf("hud_") != -1
				|| low.indexOf("nspecwave") != -1
				|| low == "sparkle"
				|| low == "mario_coin";
		}

		public static function effectIdToLower(id:*):String
		{
			var s:String;
			var qn:String;
			if (id == null)
			{
				return null;
			};
			if (id is String)
			{
				return String(id).toLowerCase();
			};
			try
			{
				s = String(id);
				// DisplayObjects stringify as "[object MovieClip]" — never treat as linkage.
				if (s && s != "[object Object]"
					&& s.indexOf("[class ") != 0
					&& s.indexOf("[object ") != 0)
				{
					return s.toLowerCase();
				};
			}
			catch (err:*)
			{
			};
			try
			{
				qn = getQualifiedClassName(id);
				if (qn)
				{
					if (qn.indexOf("::") != -1)
					{
						qn = qn.substring(qn.lastIndexOf(":") + 1);
					};
					return qn.toLowerCase();
				};
			}
			catch (err2:*)
			{
			};
			return null;
		}
	}
}
