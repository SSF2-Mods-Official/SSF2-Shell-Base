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

	/** Color math and analysis: matching, shade groups, adjacency, swatch order, opaque color collection. */
	public class PaletteColorAnalysis
	{
		public static function colorsMatch(a:uint, b:uint):Boolean
		{
			if (uint(a) == uint(b))
			{
				return true;
			};
			return ((a & 0x00FFFFFF) == (b & 0x00FFFFFF));
		}

		public static function darkenForIsolate(color:uint):uint
		{
			var a:uint = (color >> 24) & 0xFF;
			var r:uint = (color >> 16) & 0xFF;
			var g:uint = (color >> 8) & 0xFF;
			var b:uint = color & 0xFF;
			var floor:uint = 0x18;
			r = Math.max(floor, uint(r * 0.45));
			g = Math.max(floor, uint(g * 0.45));
			b = Math.max(floor, uint(b * 0.45));
			return (a << 24) | (r << 16) | (g << 8) | b;
		}

		public static function sampleDisplayPixel(root:DisplayObjectContainer, globalX:Number, globalY:Number, recursion:int = 2):Object
		{
			var i:int;
			var child:DisplayObject;
			var bitmap:Bitmap;
			var local:Point;
			var color:uint;
			var nested:Object;
			if (!root || !root.visible || !root.hitTestPoint(globalX, globalY, false))
			{
				return null;
			};
			i = root.numChildren - 1;
			while (i >= 0)
			{
				child = root.getChildAt(i);
				if (!child.visible)
				{
					i--;
					continue;
				};
				if (child is Bitmap)
				{
					bitmap = child as Bitmap;
					// Skip unchanged-highlight edge ring (white BD + ColorTransform tint).
					if (bitmap.name == "_unchangedOutline")
					{
						i--;
						continue;
					};
					if (bitmap.bitmapData)
					{
						local = bitmap.globalToLocal(new Point(globalX, globalY));
						if (local.x >= 0 && local.y >= 0 && local.x < bitmap.bitmapData.width && local.y < bitmap.bitmapData.height)
						{
							color = bitmap.bitmapData.getPixel32(int(local.x), int(local.y));
							if (((color >> 24) & 0xFF) > 0)
							{
								return {
									"color": color,
									"bitmap": bitmap,
									"localX": int(local.x),
									"localY": int(local.y)
								};
							};
						};
					};
				}
				else if ((child is DisplayObjectContainer) && recursion > 0)
				{
					nested = sampleDisplayPixel(child as DisplayObjectContainer, globalX, globalY, recursion - 1);
					if (nested)
					{
						return nested;
					};
				};
				i--;
			};
			return null;
		}

		public static function findBaseColorsForReplacement(paletteData:Object, replacement:uint, matchIsolatedDarkened:Boolean = false):Array
		{
			var bases:Array = [];
			var block:Object;
			var colors:Array;
			var replacements:Array;
			var i:int;
			var repl:uint;
			var base:uint;
			if (!paletteData)
			{
				return bases;
			};
			for each (block in [paletteData.paletteSwap, paletteData.paletteSwapPA])
			{
				if (!block || !block.colors || !block.replacements)
				{
					continue;
				};
				colors = block.colors as Array;
				replacements = block.replacements as Array;
				i = 0;
				while (i < replacements.length && i < colors.length)
				{
					repl = uint(replacements[i]);
					base = uint(colors[i]);
					// Match either the replacement (recolored pixel) or the original base color.
					if (colorsMatch(repl, replacement)
						|| colorsMatch(base, replacement)
						|| (matchIsolatedDarkened && (colorsMatch(darkenForIsolate(repl), replacement) || colorsMatch(darkenForIsolate(base), replacement))))
					{
						if (bases.indexOf(base) == -1)
						{
							bases.push(base);
						};
					};
					i++;
				};
			};
			return bases;
		}

		public static function rgbDistance(a:uint, b:uint):Number
		{
			var ar:Number = (a >> 16) & 0xFF;
			var ag:Number = (a >> 8) & 0xFF;
			var ab:Number = a & 0xFF;
			var br:Number = (b >> 16) & 0xFF;
			var bg:Number = (b >> 8) & 0xFF;
			var bb:Number = b & 0xFF;
			var dr:Number = ar - br;
			var dg:Number = ag - bg;
			var db:Number = ab - bb;
			return Math.sqrt(dr * dr + dg * dg + db * db);
		}

		public static function averageColors(colors:Array):uint
		{
			var i:int;
			var c:uint;
			var r:Number = 0;
			var g:Number = 0;
			var b:Number = 0;
			var n:int = 0;
			if (!colors || colors.length == 0)
			{
				return 0x888888;
			};
			i = 0;
			while (i < colors.length)
			{
				c = uint(colors[i]);
				r += (c >> 16) & 0xFF;
				g += (c >> 8) & 0xFF;
				b += c & 0xFF;
				n++;
				i++;
			};
			if (n == 0)
			{
				return 0x888888;
			};
			return (uint(r / n) << 16) | (uint(g / n) << 8) | uint(b / n);
		}

		/**
		 * Cluster by shade/display color, but return groups of base palette colors.
		 * items: Array of {base:uint, shade:uint}
		 * bitmaps: optional Bitmap / BitmapData list — adjacent similar shades get merged.
		 * Groups are sorted largest-first.
		 */
		public static function buildShadeGroupsFromItems(items:Array, bitmaps:Array = null):Array
		{
			var groups:Array = [];
			var shadeList:Array = [];
			var shadeToBases:Object = {};
			var shadeByBase:Object = {};
			var families:Array;
			var family:Array;
			var members:Array;
			var misc:Array = [];
			var shade:uint;
			var base:uint;
			var i:int;
			var j:int;
			var item:Object;
			var adjPairs:Array;

			if (!items || items.length == 0)
			{
				return groups;
			};
			i = 0;
			while (i < items.length)
			{
				item = items[i];
				if (!item)
				{
					i++;
					continue;
				};
				base = uint(item.base);
				shade = uint(item.shade);
				shadeByBase[base] = shade;
				if (!shadeToBases[shade])
				{
					shadeToBases[shade] = [];
					shadeList.push(shade);
				};
				if (shadeToBases[shade].indexOf(base) == -1)
				{
					shadeToBases[shade].push(base);
				};
				i++;
			};
			families = clusterShadeFamilies(shadeList);
			i = 0;
			while (i < families.length)
			{
				family = families[i] as Array;
				members = [];
				if (family)
				{
					j = 0;
					while (j < family.length)
					{
						shade = uint(family[j]);
						if (shadeToBases[shade])
						{
							members = members.concat(shadeToBases[shade]);
						};
						j++;
					};
				};
				members = uniqueColorList(members);
				if (members.length > 0)
				{
					groups.push(members);
				};
				i++;
			};
			if (bitmaps && bitmaps.length > 0 && groups.length > 1)
			{
				adjPairs = collectAdjacentBasePairs(bitmaps, shadeByBase);
				groups = mergeGroupsByAdjacentSimilarShades(groups, adjPairs, shadeByBase);
			};
			misc = [];
			i = groups.length - 1;
			while (i >= 0)
			{
				members = groups[i] as Array;
				if (!members || members.length == 0)
				{
					groups.splice(i, 1);
				}
				else if (members.length == 1)
				{
					misc.push(uint(members[0]));
					groups.splice(i, 1);
				};
				i--;
			};
			if (misc.length > 0)
			{
				groups.push(uniqueColorList(misc));
			};
			groups.sort(compareGroupSizeDescending);
			return groups;
		}

		private static function compareGroupSizeDescending(a:*, b:*):int
		{
			var la:int = (a is Array) ? (a as Array).length : 0;
			var lb:int = (b is Array) ? (b as Array).length : 0;
			if (la != lb)
			{
				return (lb > la) ? 1 : -1;
			};
			return 0;
		}

		private static function uniqueColorList(colors:Array):Array
		{
			var out:Array = [];
			var seen:Object = {};
			var i:int;
			var c:uint;
			if (!colors)
			{
				return out;
			};
			i = 0;
			while (i < colors.length)
			{
				c = uint(colors[i]);
				if (!seen[c])
				{
					seen[c] = true;
					out.push(c);
				};
				i++;
			};
			return out;
		}

		/**
		 * Scan bitmaps for palette colors whose opaque pixels share an edge;
		 * returns Array of {a:uint, b:uint} base-color pairs.
		 */
		public static function collectAdjacentBasePairs(bitmaps:Array, shadeByBase:Object):Array
		{
			var pairs:Object = {};
			var out:Array = [];
			var displayToBase:Object;
			var i:int;
			var bd:BitmapData;
			var bmp:Bitmap;
			var key:String;
			var entry:Object;

			if (!bitmaps || !shadeByBase)
			{
				return out;
			};
			displayToBase = buildDisplayRgbToBaseLookup(shadeByBase);
			i = 0;
			while (i < bitmaps.length)
			{
				bd = null;
				if (bitmaps[i] is BitmapData)
				{
					bd = bitmaps[i] as BitmapData;
				}
				else if (bitmaps[i] is Bitmap)
				{
					bmp = bitmaps[i] as Bitmap;
					bd = bmp ? bmp.bitmapData : null;
				};
				if (bd)
				{
					collectAdjacentBasePairsInBitmap(bd, displayToBase, pairs);
				};
				i++;
			};
			for (key in pairs)
			{
				entry = pairs[key];
				if (entry)
				{
					out.push(entry);
				};
			};
			return out;
		}

		private static function buildDisplayRgbToBaseLookup(shadeByBase:Object):Object
		{
			var lookup:Object = {};
			var base:*;
			var shade:uint;
			var rgb:uint;
			for (base in shadeByBase)
			{
				shade = uint(shadeByBase[base]);
				rgb = shade & 0x00FFFFFF;
				lookup[rgb] = uint(base);
				rgb = uint(base) & 0x00FFFFFF;
				if (lookup[rgb] == undefined)
				{
					lookup[rgb] = uint(base);
				};
			};
			return lookup;
		}

		private static function collectAdjacentBasePairsInBitmap(bd:BitmapData, displayToBase:Object, pairs:Object):void
		{
			var vec:Vector.<uint>;
			var w:int;
			var h:int;
			var x:int;
			var y:int;
			var idx:int;
			var p:uint;
			var n:uint;
			var baseA:uint;
			var baseB:uint;
			var key:String;
			if (!bd || bd.width <= 0 || bd.height <= 0)
			{
				return;
			};
			try
			{
				vec = bd.getVector(bd.rect);
			}
			catch (err:Error)
			{
				return;
			};
			w = bd.width;
			h = bd.height;
			y = 0;
			while (y < h)
			{
				x = 0;
				while (x < w)
				{
					idx = y * w + x;
					p = vec[idx];
					if (((p >> 24) & 0xFF) > 0 && displayToBase[p & 0x00FFFFFF] != undefined)
					{
						baseA = uint(displayToBase[p & 0x00FFFFFF]);
						if (x + 1 < w)
						{
							n = vec[idx + 1];
							if (((n >> 24) & 0xFF) > 0 && displayToBase[n & 0x00FFFFFF] != undefined)
							{
								baseB = uint(displayToBase[n & 0x00FFFFFF]);
								if (baseA != baseB)
								{
									key = (baseA < baseB)
										? (String(baseA) + ":" + String(baseB))
										: (String(baseB) + ":" + String(baseA));
									if (!pairs[key])
									{
										pairs[key] = { "a": (baseA < baseB) ? baseA : baseB, "b": (baseA < baseB) ? baseB : baseA };
									};
								};
							};
						};
						if (y + 1 < h)
						{
							n = vec[idx + w];
							if (((n >> 24) & 0xFF) > 0 && displayToBase[n & 0x00FFFFFF] != undefined)
							{
								baseB = uint(displayToBase[n & 0x00FFFFFF]);
								if (baseA != baseB)
								{
									key = (baseA < baseB)
										? (String(baseA) + ":" + String(baseB))
										: (String(baseB) + ":" + String(baseA));
									if (!pairs[key])
									{
										pairs[key] = { "a": (baseA < baseB) ? baseA : baseB, "b": (baseA < baseB) ? baseB : baseA };
									};
								};
							};
						};
					};
					x++;
				};
				y++;
			};
		}

		/**
		 * Union shade groups when a member of each shares an edge and those
		 * touching colors are similar shades (slightly looser than initial cluster).
		 */
		public static function mergeGroupsByAdjacentSimilarShades(groups:Array, adjacentBasePairs:Array, shadeByBase:Object,
			hueThreshold:Number = 30, valueThreshold:Number = 0.40, satThreshold:Number = 0.45):Array
		{
			var parent:Array;
			var baseToGroup:Object;
			var i:int;
			var j:int;
			var g:Array;
			var base:uint;
			var pair:Object;
			var ga:int;
			var gb:int;
			var shadeA:uint;
			var shadeB:uint;
			var merged:Object;
			var out:Array;
			var members:Array;
			var root:int;

			if (!groups || groups.length <= 1)
			{
				return groups || [];
			};
			parent = [];
			i = 0;
			while (i < groups.length)
			{
				parent[i] = i;
				i++;
			};
			function findRoot(idx:int):int
			{
				while (parent[idx] != idx)
				{
					parent[idx] = parent[parent[idx]];
					idx = parent[idx];
				};
				return idx;
			}
			function unionGroups(a:int, b:int):void
			{
				var ra:int = findRoot(a);
				var rb:int = findRoot(b);
				if (ra != rb)
				{
					parent[rb] = ra;
				};
			}
			baseToGroup = {};
			i = 0;
			while (i < groups.length)
			{
				g = groups[i] as Array;
				if (g)
				{
					j = 0;
					while (j < g.length)
					{
						base = uint(g[j]);
						if (baseToGroup[base] == undefined)
						{
							baseToGroup[base] = i;
						};
						j++;
					};
				};
				i++;
			};
			if (adjacentBasePairs)
			{
				i = 0;
				while (i < adjacentBasePairs.length)
				{
					pair = adjacentBasePairs[i];
					if (pair && baseToGroup[uint(pair.a)] != undefined && baseToGroup[uint(pair.b)] != undefined)
					{
						ga = int(baseToGroup[uint(pair.a)]);
						gb = int(baseToGroup[uint(pair.b)]);
						if (ga != gb)
						{
							shadeA = shadeByBase[uint(pair.a)] != undefined ? uint(shadeByBase[uint(pair.a)]) : uint(pair.a);
							shadeB = shadeByBase[uint(pair.b)] != undefined ? uint(shadeByBase[uint(pair.b)]) : uint(pair.b);
							if (shadesAreSimilar(shadeA, shadeB, hueThreshold, valueThreshold, satThreshold))
							{
								unionGroups(ga, gb);
							};
						};
					};
					i++;
				};
			};
			merged = {};
			i = 0;
			while (i < groups.length)
			{
				root = findRoot(i);
				if (!merged[root])
				{
					merged[root] = [];
				};
				g = groups[i] as Array;
				if (g)
				{
					merged[root] = (merged[root] as Array).concat(g);
				};
				i++;
			};
			out = [];
			for each (members in merged)
			{
				out.push(uniqueColorList(members as Array));
			};
			return out;
		}

		/** Pairwise shade-family check (uses first color as the family mean). */
		public static function shadesAreSimilar(a:uint, b:uint,
			hueThreshold:Number = 30, valueThreshold:Number = 0.40, satThreshold:Number = 0.45):Boolean
		{
			var hsv:Object = HsvWheel.rgbToHsv(a);
			return colorsSameShadeFamily(b, hsv.h, hsv.s, hsv.v, hueThreshold, valueThreshold, satThreshold);
		}

		/**
		 * Chromatic-only shade neighbor (neither color is neutral).
		 * Avoids the neutrals path in colorsSameShadeFamily that false-matched
		 * browns/grays to earlier groups when used as a paint gate.
		 */
		public static function isChromaticShadeNeighbor(a:uint, b:uint,
			hueThreshold:Number = 14, valueThreshold:Number = 0.22, satThreshold:Number = 0.28):Boolean
		{
			var ha:Object;
			var hb:Object;
			if (colorsMatch(a, b))
			{
				return false;
			};
			ha = HsvWheel.rgbToHsv(a);
			hb = HsvWheel.rgbToHsv(b);
			if (isNeutralHsv(ha.s, ha.v) || isNeutralHsv(hb.s, hb.v))
			{
				return false;
			};
			return colorsSameShadeFamily(b, ha.h, ha.s, ha.v, hueThreshold, valueThreshold, satThreshold);
		}

		/**
		 * Order swatches for the grid: chromatic by hue band → light-to-dark → sat,
		 * then neutrals light-to-dark.
		 * @param colors base palette keys (order returned uses these values)
		 * @param sortKeys optional parallel array: sort by these colors instead of bases
		 *                 (e.g. current replacements). Same length as colors when used.
		 */
		public static function sortPaletteColorsForDisplay(colors:Array, sortKeys:Array = null):Array
		{
			var chromatic:Array = [];
			var neutrals:Array = [];
			var item:Object;
			var base:uint;
			var key:uint;
			var hsv:Object;
			var i:int;
			var out:Array;
			if (!colors || colors.length == 0)
			{
				return [];
			};
			i = 0;
			while (i < colors.length)
			{
				base = PaletteMakerUtils.coerceColorValue(colors[i]);
				key = (sortKeys && i < sortKeys.length) ? PaletteMakerUtils.coerceColorValue(sortKeys[i]) : base;
				item = { "base": base, "key": key };
				hsv = HsvWheel.rgbToHsv(key);
				if (isNeutralHsv(hsv.s, hsv.v))
				{
					neutrals.push(item);
				}
				else
				{
					chromatic.push(item);
				};
				i++;
			};
			chromatic.sort(compareChromaticSwatchItemOrder);
			neutrals.sort(compareNeutralSwatchItemOrder);
			out = [];
			for each (item in chromatic)
			{
				out.push(uint(item.base));
			};
			for each (item in neutrals)
			{
				out.push(uint(item.base));
			};
			return out;
		}

		private static function compareChromaticSwatchItemOrder(a:*, b:*):int
		{
			var ka:uint = uint(a.key);
			var kb:uint = uint(b.key);
			var ha:Object = HsvWheel.rgbToHsv(ka);
			var hb:Object = HsvWheel.rgbToHsv(kb);
			var hueA:Number = ha.h;
			var hueB:Number = hb.h;
			var bandA:Number;
			var bandB:Number;
			var d:Number;
			// Keep reds together across the 0° wrap (put near-red high hues with low).
			if (hueA >= 330)
			{
				hueA -= 360;
			};
			if (hueB >= 330)
			{
				hueB -= 360;
			};
			// ~12° hue buckets so same-family shades can sort light → dark.
			bandA = Math.round(hueA / 12);
			bandB = Math.round(hueB / 12);
			d = bandA - bandB;
			if (Math.abs(d) > 0.01)
			{
				return (d < 0) ? -1 : 1;
			};
			// Light to dark within the hue band.
			d = hb.v - ha.v;
			if (Math.abs(d) > 0.001)
			{
				return (d < 0) ? -1 : 1;
			};
			d = hb.s - ha.s;
			if (Math.abs(d) > 0.001)
			{
				return (d < 0) ? -1 : 1;
			};
			return (uint(a.base) < uint(b.base)) ? -1 : ((uint(a.base) > uint(b.base)) ? 1 : 0);
		}

		private static function compareNeutralSwatchItemOrder(a:*, b:*):int
		{
			var ka:uint = uint(a.key);
			var kb:uint = uint(b.key);
			var va:Number = HsvWheel.rgbToHsv(ka).v;
			var vb:Number = HsvWheel.rgbToHsv(kb).v;
			if (Math.abs(va - vb) > 0.001)
			{
				// Light to dark.
				return (vb < va) ? -1 : 1;
			};
			return (uint(a.base) < uint(b.base)) ? -1 : ((uint(a.base) > uint(b.base)) ? 1 : 0);
		}

		public static function clusterShadeFamilies(paletteColors:Array, hueThreshold:Number = 18, valueThreshold:Number = 0.28, satThreshold:Number = 0.35):Array
		{
			var families:Array = [];
			var used:Object = {};
			var i:int;
			var j:int;
			var seed:uint;
			var candidate:uint;
			var family:Array;
			var meanH:Number;
			var meanS:Number;
			var meanV:Number;
			var hsv:Object;
			var absorbed:Boolean;
			var n:int;

			if (!paletteColors)
			{
				return families;
			};
			i = 0;
			while (i < paletteColors.length)
			{
				seed = uint(paletteColors[i]);
				if (used[seed])
				{
					i++;
					continue;
				};
				family = [seed];
				used[seed] = true;
				hsv = HsvWheel.rgbToHsv(seed);
				meanH = hsv.h;
				meanS = hsv.s;
				meanV = hsv.v;
				n = 1;
				do
				{
					absorbed = false;
					j = 0;
					while (j < paletteColors.length)
					{
						candidate = uint(paletteColors[j]);
						if (!used[candidate] && colorsSameShadeFamily(candidate, meanH, meanS, meanV, hueThreshold, valueThreshold, satThreshold))
						{
							family.push(candidate);
							used[candidate] = true;
							hsv = HsvWheel.rgbToHsv(candidate);
							if (!isNeutralHsv(meanS, meanV) && !isNeutralHsv(hsv.s, hsv.v))
							{
								meanH = circularHueMean(meanH, hsv.h, n);
							};
							meanS = ((meanS * n) + hsv.s) / (n + 1);
							meanV = ((meanV * n) + hsv.v) / (n + 1);
							n++;
							absorbed = true;
						};
						j++;
					};
				} while (absorbed);
				families.push(family);
				i++;
			};
			return families;
		}

		public static function complementaryColor(color:uint):uint
		{
			var hsv:Object = HsvWheel.rgbToHsv(color);
			var a:uint = (color >> 24) & 0xFF;
			if (a == 0)
			{
				a = 0xFF;
			};
			return HsvWheel.hsvToRgb((hsv.h + 180) % 360, hsv.s, hsv.v, a);
		}

		public static function blendColors(color1:uint, color2:uint, ratio:Number):uint
		{
			var t:Number = Math.max(0, Math.min(1, ratio));
			var a1:uint = (color1 >> 24) & 0xFF;
			var a2:uint = (color2 >> 24) & 0xFF;
			if (a1 == 0) a1 = 0xFF;
			if (a2 == 0) a2 = 0xFF;
			var r:uint = uint(((color1 >> 16) & 0xFF) + ((((color2 >> 16) & 0xFF) - ((color1 >> 16) & 0xFF)) * t));
			var g:uint = uint(((color1 >> 8) & 0xFF) + ((((color2 >> 8) & 0xFF) - ((color1 >> 8) & 0xFF)) * t));
			var b:uint = uint((color1 & 0xFF) + (((color2 & 0xFF) - (color1 & 0xFF)) * t));
			var a:uint = uint(a1 + ((a2 - a1) * t));
			return (a << 24) | (r << 16) | (g << 8) | b;
		}

		/**
		 * Recolor a group member as a shade of newPrimary while keeping relative S/V vs oldPrimary.
		 */
		public static function recolorGroupAsShades(oldPrimaryRepl:uint, newPrimaryRepl:uint, memberRepl:uint):uint
		{
			var oldHsv:Object = HsvWheel.rgbToHsv(oldPrimaryRepl);
			var newHsv:Object = HsvWheel.rgbToHsv(newPrimaryRepl);
			var memHsv:Object = HsvWheel.rgbToHsv(memberRepl);
			var a:uint = (memberRepl >> 24) & 0xFF;
			var sRatio:Number;
			var vRatio:Number;
			var newS:Number;
			var newV:Number;
			if (a == 0)
			{
				a = 0xFF;
			};
			sRatio = (oldHsv.s <= 0.0001) ? 1 : (memHsv.s / oldHsv.s);
			vRatio = (oldHsv.v <= 0.0001) ? 1 : (memHsv.v / oldHsv.v);
			newS = Math.max(0, Math.min(1, newHsv.s * sRatio));
			newV = Math.max(0, Math.min(1, newHsv.v * vRatio));
			return HsvWheel.hsvToRgb(newHsv.h, newS, newV, a);
		}

		private static function isNeutralHsv(s:Number, v:Number):Boolean
		{
			return (s < 0.15) || (v < 0.12);
		}

		private static function hueDistance(a:Number, b:Number):Number
		{
			var d:Number = Math.abs(a - b) % 360;
			if (d > 180)
			{
				d = 360 - d;
			};
			return d;
		}

		private static function circularHueMean(meanH:Number, newH:Number, n:int):Number
		{
			var x:Number = Math.cos(meanH * Math.PI / 180) * n + Math.cos(newH * Math.PI / 180);
			var y:Number = Math.sin(meanH * Math.PI / 180) * n + Math.sin(newH * Math.PI / 180);
			var ang:Number = Math.atan2(y, x) * 180 / Math.PI;
			if (ang < 0)
			{
				ang += 360;
			};
			return ang;
		}

		private static function colorsSameShadeFamily(color:uint, meanH:Number, meanS:Number, meanV:Number, hueThreshold:Number, valueThreshold:Number, satThreshold:Number):Boolean
		{
			var hsv:Object = HsvWheel.rgbToHsv(color);
			var seedNeutral:Boolean = isNeutralHsv(meanS, meanV);
			var colorNeutral:Boolean = isNeutralHsv(hsv.s, hsv.v);
			if (seedNeutral || colorNeutral)
			{
				return seedNeutral && colorNeutral && Math.abs(hsv.v - meanV) <= valueThreshold;
			};
			if (hueDistance(hsv.h, meanH) > hueThreshold)
			{
				return false;
			};
			if (Math.abs(hsv.v - meanV) > valueThreshold)
			{
				return false;
			};
			if (Math.abs(hsv.s - meanS) > satThreshold)
			{
				return false;
			};
			return true;
		}

		/**
		 * One read of the bitmap. Steps by stride so a 200x200 sheet is about 10,000 samples.
		 * Returns { colors:Array, counts:Object }. One pixel is enough to keep a color.
		 */
		public static function sampleOpaqueColors(bd:BitmapData, stride:int = 4):Object
		{
			return LinkedFormPaint.sampleOpaqueColors(bd, stride);
		}

		/**
		 * All opaque ARGB colors in a BitmapData with frequency >= minPixels.
		 * Preserves exact ARGB (including alpha) — replacePalette threshold needs
		 * a full 0xAARRGGBB match, so forcing 0xFF alpha would miss real pixels.
		 */
		public static function collectOpaqueColorsInBitmapData(bd:BitmapData, minPixels:int = -1, minAlpha:int = 0):Array
		{
			var counts:Object = {};
			var found:Array = [];
			var vec:Vector.<uint>;
			var p:uint;
			var n:int;
			var j:int;
			var k:*;
			if (minPixels < 0)
			{
				minPixels = SpriteCacheStore.DISCOVERED_COLOR_MIN_PIXELS;
			};
			if (!bd || bd.width <= 0 || bd.height <= 0)
			{
				return found;
			};
			// A full read of a giant frame is skipped. The stride sample still keeps its colors.
			if ((bd.width * bd.height) > 350000)
			{
				var sampled:Object = sampleOpaqueColors(bd, 4);
				return (sampled && sampled.colors is Array) ? (sampled.colors as Array) : found;
			};
			try
			{
				vec = bd.getVector(bd.rect);
			}
			catch (err:Error)
			{
				return found;
			};
			n = vec.length;
			j = 0;
			while (j < n)
			{
				p = vec[j];
				if (minAlpha > 0)
				{
					if (((p >> 24) & 0xFF) >= minAlpha)
					{
						if (counts[p])
						{
							counts[p] = int(counts[p]) + 1;
						}
						else
						{
							counts[p] = 1;
						};
					};
				}
				else if (((p >> 24) & 0xFF) > 0)
				{
					if (counts[p])
					{
						counts[p] = int(counts[p]) + 1;
					}
					else
					{
						counts[p] = 1;
					};
				};
				j++;
			};
			for (k in counts)
			{
				if (int(counts[k]) >= minPixels)
				{
					found.push(uint(k));
				};
			};
			return found;
		}

		/**
		 * Collect Bitmaps the same way Ssf2.Utils.replacePalette walks a tree:
		 * Bitmap children + nested MovieClips within recursion depth.
		 */
		public static function collectBitmapsLikeReplacePalette(mc:MovieClip, out:Array, recursion:int=2):void
		{
			var i:int;
			var child:DisplayObject;
			var bitmap:Bitmap;
			if (!mc || !out || recursion < 0)
			{
				return;
			};
			i = 0;
			while (i < mc.numChildren)
			{
				child = mc.getChildAt(i);
				if (child is Bitmap)
				{
					bitmap = child as Bitmap;
					if (bitmap.bitmapData)
					{
						out.push(bitmap);
					};
				}
				else if (((child is MovieClip) && (recursion > 0)))
				{
					collectBitmapsLikeReplacePalette(child as MovieClip, out, recursion - 1);
				};
				i++;
			};
		}

		/**
		 * Opaque colors under an MC at replacePalette depth.
		 * If walkAllFrames, seeks every frame of mc (and restores original frame).
		 * Frame scripts are stripped deeply first — character idle clips often crash
		 * when sought outside a live match (null refs in timeline code).
		 */
		public static function collectOpaqueColorsInMC(mc:MovieClip, recursion:int=2, minPixels:int=-1, walkAllFrames:Boolean=false):Array
		{
			var seen:Object = {};
			var found:Array = [];
			var bitmaps:Array;
			var bmp:Bitmap;
			var colors:Array;
			var color:uint;
			var frame:int;
			var total:int;
			var savedFrame:int;
			if (minPixels < 0)
			{
				minPixels = SpriteCacheStore.DISCOVERED_COLOR_MIN_PIXELS;
			};
			if (!mc)
			{
				return found;
			};
			try
			{
				Ssf2.Utils.removeActionScriptDeep(mc, 12);
			}
			catch (stripErr:*)
			{
			};
			savedFrame = mc.currentFrame;
			// Never seek frames here — nested timeline clips run frame scripts on
			// spawn and those errors bypass try/catch (see Chibi-Robo HeavyLand).
			walkAllFrames = false;
			total = 1;
			frame = 1;
			while (frame <= total)
			{
				try
				{
					if (walkAllFrames)
					{
						Ssf2.Utils.removeActionScriptDeep(mc, 12);
						mc.gotoAndStop(frame);
						// New timeline children may appear with their own scripts.
						Ssf2.Utils.removeActionScriptDeep(mc, 12);
					};
					bitmaps = [];
					collectBitmapsLikeReplacePalette(mc, bitmaps, recursion);
					for each (bmp in bitmaps)
					{
						if (!bmp || !bmp.bitmapData)
						{
							continue;
						};
						colors = collectOpaqueColorsInBitmapData(bmp.bitmapData, minPixels);
						for each (color in colors)
						{
							if (!seen[color])
							{
								seen[color] = true;
								found.push(color);
							};
						};
					};
				}
				catch (frameErr:*)
				{
					// Skip corrupt / scripted frames; keep scanning the rest.
				};
				frame++;
			};
			if (walkAllFrames)
			{
				try
				{
					Ssf2.Utils.removeActionScriptDeep(mc, 12);
					mc.gotoAndStop(savedFrame);
				}
				catch (restoreErr:*)
				{
				};
			};
			return found;
		}

		public static function getPaletteColorsInBitmapData(bd:BitmapData, paletteColors:Array, tolerance:int = 0, pixelCounts:Object = null):Array
		{
			var counts:Object = {};
			var found:Array = [];
			var key:*;
			var lookup:Object;
			var vec:Vector.<uint>;
			var p:uint;
			var rgb:uint;
			var matched:uint;
			var n:int;
			var j:int;
			var totalNeeded:int;
			var foundCount:int;
			var remainingFuzzy:Array;
			var fi:int;
			var want:uint;
			var wr:int;
			var wg:int;
			var wb:int;
			var pr:int;
			var pg:int;
			var pb:int;
			if (!bd || !paletteColors || paletteColors.length == 0 || bd.width <= 0 || bd.height <= 0)
			{
				return found;
			};
			lookup = buildPaletteLookup(paletteColors);
			totalNeeded = paletteColors.length;
			foundCount = 0;
			try
			{
				vec = bd.getVector(bd.rect);
			}
			catch (err:Error)
			{
				return found;
			};
			n = vec.length;
			j = 0;
			while (j < n)
			{
				p = vec[j];
				if (((p >> 24) & 0xFF) > 0)
				{
					rgb = p & 0x00FFFFFF;
					if (lookup.hasOwnProperty(rgb))
					{
						matched = uint(lookup[rgb]);
						if (pixelCounts)
						{
							pixelCounts[matched] = int(pixelCounts[matched]) + 1;
						};
						if (!counts[matched])
						{
							counts[matched] = 1;
							foundCount++;
							if (!pixelCounts && foundCount >= totalNeeded)
							{
								break;
							};
						};
					};
				};
				j++;
			};
			if (tolerance > 0 && foundCount < totalNeeded)
			{
				remainingFuzzy = [];
				j = 0;
				while (j < paletteColors.length)
				{
					want = uint(paletteColors[j]);
					if (!counts[want])
					{
						remainingFuzzy.push(want);
					};
					j++;
				};
				j = 0;
				while (j < n && remainingFuzzy.length > 0)
				{
					p = vec[j];
					if (((p >> 24) & 0xFF) > 0)
					{
						rgb = p & 0x00FFFFFF;
						pr = (rgb >> 16) & 0xFF;
						pg = (rgb >> 8) & 0xFF;
						pb = rgb & 0xFF;
						fi = remainingFuzzy.length - 1;
						while (fi >= 0)
						{
							want = uint(remainingFuzzy[fi]);
							wr = (want >> 16) & 0xFF;
							wg = (want >> 8) & 0xFF;
							wb = want & 0xFF;
							if (((Math.abs(pr - wr) + Math.abs(pg - wg)) + Math.abs(pb - wb)) <= tolerance)
							{
								counts[want] = 1;
								foundCount++;
								remainingFuzzy.splice(fi, 1);
							};
							fi--;
						};
					};
					j++;
				};
			};
			for (key in counts)
			{
				found.push(uint(key));
			};
			return found;
		}

		/** Deep-collect every Bitmap under a display object. Never seeks frames. */
		public static function collectBitmaps(root:DisplayObjectContainer, out:Array, recursion:int=8):void
		{
			var i:int;
			var child:DisplayObject;
			var bmp:Bitmap;
			if (!root || !out || recursion < 0)
			{
				return;
			};
			i = 0;
			while (i < root.numChildren)
			{
				child = root.getChildAt(i);
				if (child is Bitmap)
				{
					bmp = child as Bitmap;
					if (bmp.bitmapData)
					{
						out.push(bmp);
					};
				}
				else if (child is DisplayObjectContainer)
				{
					collectBitmaps(child as DisplayObjectContainer, out, recursion - 1);
				};
				i++;
			};
		}

		private static function buildPaletteLookup(paletteColors:Array):Object
		{
			var lookup:Object = {};
			var i:int = 0;
			while (i < paletteColors.length)
			{
				lookup[uint(paletteColors[i]) & 0x00FFFFFF] = uint(paletteColors[i]);
				i++;
			};
			return lookup;
		}
	}
}
