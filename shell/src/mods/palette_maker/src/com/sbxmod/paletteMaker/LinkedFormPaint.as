package com.sbxmod.paletteMaker
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	/** Paints bitmaps that still contain another form's source colors. */
	public class LinkedFormPaint
	{
		/** Sealed portrait subclasses throw Error #1065 for a missing __cachedPalette. */
		private static var portraitPixelCache:Dictionary = new Dictionary(true);
		/** Giga opens from the stock grid but the match must spawn Bowser for the linked form. */
		public static function spawnStatsName(openedName:String):String
		{
			var opened:String;
			opened = openedName ? openedName.toLowerCase() : "";
			if (opened == "gigabowser" || opened == "giga_bowser")
			{
				return "bowser";
			};
			return openedName;
		}

		/** Zelda and Sheik studio spawn this form as player 2. Other forms stay a one-player match. */
		public static function studioMirrorPartner(openedName:String):String
		{
			var opened:String;
			opened = openedName ? openedName.toLowerCase() : "";
			if (opened == "zelda")
			{
				return "sheik";
			};
			if (opened == "sheik")
			{
				return "zelda";
			};
			return null;
		}

		/** Drops the other linked form. Giga Bowser keeps a Giga name only. An unprefixed prop stays on Zelda and Kirby. */
		public static function filterCoverToForm(cover:Array, formName:String):Array
		{
			var out:Array;
			var cand:Object;
			var link:String;
			var partner:String;
			out = [];
			if (!cover || !formName)
			{
				return cover ? cover.concat() : out;
			};
			partner = linkedFormPartner(formName);
			for each (cand in cover)
			{
				if (!cand)
				{
					continue;
				};
				link = cand.linkage ? String(cand.linkage) : "";
				if (!link)
				{
					continue;
				};
				if ((partner == "bowser") && !LinkedFormSprite.isGigaLinkage(link))
				{
					continue;
				};
				if (partner && LinkedFormSprite.matchesForm(link, partner))
				{
					continue;
				};
				out.push(cand);
			};
			return out;
		}

		/**
		 * One walk keeps a sprite that adds a color the portrait does not already
		 * have. A count over that short list then drops a sprite that has no color
		 * of its own, later sprites first so an earlier owner can keep the letter.
		 * Identical bitmaps are skipped in the forward walk.
		 */
		/** The first sprite that lists a color keeps it bright. Later sprites wash it. A portrait color stays washed. */
		public static function ownedColorsForStrip(cover:Array, paColors:Array = null):Array
		{
			var claimed:Object;
			var out:Array;
			var cand:Object;
			var color:uint;
			var seen:Object;
			var owned:Array;
			claimed = {};
			out = [];
			if (paColors)
			{
				for each (color in paColors)
				{
					claimed[uint(color)] = true;
				};
			};
			if (!cover)
			{
				return out;
			};
			for each (cand in cover)
			{
				owned = [];
				seen = {};
				if (cand && (cand.colors is Array))
				{
					for each (color in (cand.colors as Array))
					{
						if (seen[uint(color)] || claimed[uint(color)])
						{
							seen[uint(color)] = true;
							continue;
						};
						seen[uint(color)] = true;
						claimed[uint(color)] = true;
						owned.push(uint(color));
					};
				};
				out.push(owned);
			};
			return out;
		}

		/** Manhattan RGB distance. A near shade of an owned color still counts as that color on Ctrl+Q. */
		public static const OWNED_HIGHLIGHT_DISTANCE:int = 16;

		/** Other pixels move 1/32 of the way toward black or white so the owned color is the bright or dark part. */
		public static const OWNED_DARKEN_SHIFT:int = 5;

		/** Owned source colors plus the palette color each one was repainted to. */
		public static function withSwapReplacements(colors:Array, swap:Object):Array
		{
			var out:Array;
			var want:Object;
			var color:uint;
			var i:int;
			var key:uint;
			var keys:Array;
			var reps:Array;
			out = [];
			want = {};
			if (colors)
			{
				for each (color in colors)
				{
					out.push(uint(color));
					want[String(uint(color) & 0xFFFFFF)] = true;
				};
			};
			keys = (swap && swap.colors is Array) ? (swap.colors as Array) : null;
			reps = (swap && swap.replacements is Array) ? (swap.replacements as Array) : null;
			if (keys && reps)
			{
				i = 0;
				while (i < keys.length && i < reps.length)
				{
					key = uint(keys[i]) & 0xFFFFFF;
					if (want[String(key)])
					{
						out.push(uint(reps[i]));
					};
					i++;
				};
			};
			return out;
		}

		public static function hexLabel(color:uint):String
		{
			var s:String;
			s = (uint(color) & 0xFFFFFF).toString(16);
			while (s.length < 6)
			{
				s = "0" + s;
			};
			return "#" + s.toUpperCase();
		}

		public static function nearOwnedColor(rgb:uint, keep:Array):Boolean
		{
			var color:uint;
			var dr:int;
			var dg:int;
			var db:int;
			if (!keep)
			{
				return false;
			};
			rgb = rgb & 0xFFFFFF;
			for each (color in keep)
			{
				color = uint(color) & 0xFFFFFF;
				dr = ((rgb >> 16) & 0xFF) - ((color >> 16) & 0xFF);
				dg = ((rgb >> 8) & 0xFF) - ((color >> 8) & 0xFF);
				db = (rgb & 0xFF) - (color & 0xFF);
				if (dr < 0)
				{
					dr = -dr;
				};
				if (dg < 0)
				{
					dg = -dg;
				};
				if (db < 0)
				{
					db = -db;
				};
				if ((dr + dg + db) <= OWNED_HIGHLIGHT_DISTANCE)
				{
					return true;
				};
			};
			return false;
		}

		/** True when the owned color is dark, so the rest of the sprite should wash toward white. */
		public static function washOwnedTowardWhite(keep:Array):Boolean
		{
			var color:uint;
			var n:int;
			var sum:Number;
			var r:int;
			var g:int;
			var b:int;
			n = 0;
			sum = 0;
			if (!keep)
			{
				return false;
			};
			for each (color in keep)
			{
				r = (uint(color) >> 16) & 0xFF;
				g = (uint(color) >> 8) & 0xFF;
				b = uint(color) & 0xFF;
				sum += r * 299 + g * 587 + b * 114;
				n++;
			};
			return n > 0 && (sum / n) < 128000;
		}

		/** Darken or wash painted pixels whose source color is not near a color this sprite owns, then ring those pixels. */
		public static function darkenExceptColors(painted:BitmapData, source:BitmapData, keep:Array):void
		{
			var rect:Rectangle;
			var src:Vector.<uint>;
			var dst:Vector.<uint>;
			var i:int;
			var p:uint;
			var a:uint;
			var w:int;
			var x:int;
			var y:int;
			var minX:int;
			var minY:int;
			var maxX:int;
			var maxY:int;
			var towardWhite:Boolean;
			var cr:int;
			var cg:int;
			var cb:int;
			if (!painted || !source || painted.width != source.width || painted.height != source.height)
			{
				return;
			};
			rect = painted.rect;
			try
			{
				src = source.getVector(rect);
				dst = painted.getVector(rect);
			}
			catch (err:Error)
			{
				return;
			};
			if (!keep || keep.length == 0)
			{
				return;
			};
			towardWhite = washOwnedTowardWhite(keep);
			w = painted.width;
			minX = w;
			minY = painted.height;
			maxX = -1;
			maxY = -1;
			i = 0;
			while (i < dst.length && i < src.length)
			{
				p = src[i];
				if ((p >>> 24) > 0 && nearOwnedColor(p, keep))
				{
					x = i % w;
					y = int(i / w);
					if (x < minX)
					{
						minX = x;
					};
					if (y < minY)
					{
						minY = y;
					};
					if (x > maxX)
					{
						maxX = x;
					};
					if (y > maxY)
					{
						maxY = y;
					};
				}
				else if ((p >>> 24) > 0)
				{
					a = dst[i];
					cr = (a >> 16) & 0xFF;
					cg = (a >> 8) & 0xFF;
					cb = a & 0xFF;
					if (towardWhite)
					{
						cr = 255 - ((255 - cr) >> OWNED_DARKEN_SHIFT);
						cg = 255 - ((255 - cg) >> OWNED_DARKEN_SHIFT);
						cb = 255 - ((255 - cb) >> OWNED_DARKEN_SHIFT);
					}
					else
					{
						cr = cr >> OWNED_DARKEN_SHIFT;
						cg = cg >> OWNED_DARKEN_SHIFT;
						cb = cb >> OWNED_DARKEN_SHIFT;
					};
					dst[i] = (a & 0xFF000000) | (cr << 16) | (cg << 8) | cb;
				};
				i++;
			};
			try
			{
				painted.setVector(rect, dst);
			}
			catch (writeErr:Error)
			{
			};
			if (maxX >= 0)
			{
				drawOwnedRing(painted, minX, minY, maxX, maxY);
			};
		}

		/** True after the character is idle, nearly still, and that height has held. */
		public static function portraitHoldReady(idle:Boolean, ySpeed:Number, yDelta:Number, heldFrames:int):Boolean
		{
			return idle && Math.abs(ySpeed) <= 2 && Math.abs(yDelta) <= 2 && heldFrames >= 8;
		}

		/** Red ring a few pixels outside the kept pixels. It does not grow with the bitmap. */
		public static function drawOwnedRing(bd:BitmapData, minX:int, minY:int, maxX:int, maxY:int):void
		{
			var cx:Number;
			var cy:Number;
			var boxW:Number;
			var boxH:Number;
			var r:Number;
			var thick:int;
			var steps:int;
			var t:int;
			var k:int;
			var ang:Number;
			var x:int;
			var y:int;
			if (!bd || maxX < minX || maxY < minY)
			{
				return;
			};
			cx = (minX + maxX) * 0.5;
			cy = (minY + maxY) * 0.5;
			boxW = maxX - minX;
			boxH = maxY - minY;
			r = (boxW > boxH ? boxW : boxH) * 0.5 + 2;
			if (r < 3)
			{
				r = 3;
			};
			thick = 1;
			r += thick;
			steps = int(r * 8);
			if (steps < 32)
			{
				steps = 32;
			};
			t = 0;
			while (t < steps)
			{
				ang = (t / steps) * Math.PI * 2;
				k = -thick;
				while (k <= thick)
				{
					x = int(cx + Math.cos(ang) * (r + k));
					y = int(cy + Math.sin(ang) * (r + k));
					if (x >= 0 && y >= 0 && x < bd.width && y < bd.height)
					{
						bd.setPixel32(x, y, 0xFFFF0000);
					};
					k++;
				};
				t++;
			};
		}

		public static function selectUniqueStrip(candidates:Array, paColors:Array = null):Array
		{
			var chosen:Array;
			var selected:Array;
			var keptRev:Array;
			var seenFp:Object;
			var covered:Object;
			var counts:Object;
			var seenOnSprite:Object;
			var cand:Object;
			var color:uint;
			var fp:String;
			var haveFp:Boolean;
			var owns:Boolean;
			var i:int;
			chosen = [];
			selected = [];
			seenFp = {};
			covered = {};
			if (paColors)
			{
				for each (color in paColors)
				{
					covered[uint(color)] = true;
				};
			};
			if (!candidates)
			{
				return selected;
			};
			for each (cand in candidates)
			{
				if (!cand || cand.isPA)
				{
					continue;
				};
				fp = "";
				haveFp = false;
				if (cand.fingerprint)
				{
					fp = String(cand.fingerprint);
					haveFp = fp.length > 0;
				}
				else if (cand.bitmapData is BitmapData)
				{
					fp = bitmapFingerprint(cand.bitmapData as BitmapData);
					haveFp = true;
				};
				if (haveFp && seenFp[fp])
				{
					continue;
				};
				if (haveFp)
				{
					seenFp[fp] = true;
				};
				if (!spriteAddsColor(cand.colors as Array, covered))
				{
					continue;
				};
				chosen.push(cand);
				if (cand.colors is Array)
				{
					for each (color in (cand.colors as Array))
					{
						covered[uint(color)] = true;
					};
				};
			};
			counts = {};
			if (paColors)
			{
				for each (color in paColors)
				{
					counts[uint(color)] = 1;
				};
			};
			for each (cand in chosen)
			{
				if (!(cand.colors is Array))
				{
					continue;
				};
				seenOnSprite = {};
				for each (color in (cand.colors as Array))
				{
					if (seenOnSprite[uint(color)])
					{
						continue;
					};
					seenOnSprite[uint(color)] = true;
					counts[uint(color)] = int(counts[uint(color)]) + 1;
				};
			};
			keptRev = [];
			i = chosen.length - 1;
			while (i >= 0)
			{
				cand = chosen[i];
				i--;
				owns = false;
				if (cand.colors is Array)
				{
					for each (color in (cand.colors as Array))
					{
						if (int(counts[uint(color)]) == 1)
						{
							owns = true;
							break;
						};
					};
				};
				if (owns)
				{
					keptRev.push(cand);
					continue;
				};
				if (!(cand.colors is Array))
				{
					continue;
				};
				seenOnSprite = {};
				for each (color in (cand.colors as Array))
				{
					if (seenOnSprite[uint(color)])
					{
						continue;
					};
					seenOnSprite[uint(color)] = true;
					if (int(counts[uint(color)]) > 0)
					{
						counts[uint(color)] = int(counts[uint(color)]) - 1;
					};
				};
			};
			i = keptRev.length - 1;
			while (i >= 0)
			{
				selected.push(keptRev[i]);
				i--;
			};
			return selected;
		}

		/** LinkageID is not a property on character stats and throws Error #1065. */
		public static function safeLinkageIds(stats:*):Array
		{
			var ids:Array;
			var id:String;
			ids = [];
			id = readStatsString(stats, "LinkageID2");
			if (id)
			{
				ids.push(id);
			};
			id = readStatsString(stats, "LinkageIDSpecial");
			if (id)
			{
				ids.push(id);
			};
			return ids;
		}

		private static function readStatsString(stats:*, prop:String):String
		{
			var value:*;
			if (!stats || !prop)
			{
				return "";
			};
			try
			{
				value = stats[prop];
			}
			catch (err:*)
			{
				return "";
			};
			return value ? String(value) : "";
		}

		private static function linkedFormPartner(formName:String):String
		{
			var form:String;
			if (!formName)
			{
				return null;
			};
			form = formName.toLowerCase();
			if (form == "zelda")
			{
				return "sheik";
			};
			if (form == "sheik")
			{
				return "zelda";
			};
			if (form == "bowser")
			{
				return "gigabowser";
			};
			if (form == "gigabowser" || form == "giga_bowser")
			{
				return "bowser";
			};
			if (form == "wario")
			{
				return "Wario_Man";
			};
			if (form == "wario_man")
			{
				return "wario";
			};
			if (form == "sonic")
			{
				return "supersonic";
			};
			if (form == "supersonic")
			{
				return "sonic";
			};
			return null;
		}

		public static function bitmapFingerprint(bd:BitmapData):String
		{
			var hash:uint;
			var step:int;
			var x:int;
			var y:int;
			var p:uint;
			if (!bd || bd.width <= 0 || bd.height <= 0)
			{
				return "0x0:0";
			};
			hash = 2166136261;
			step = Math.max(1, int(Math.sqrt(bd.width * bd.height) / 24));
			y = 0;
			while (y < bd.height)
			{
				x = 0;
				while (x < bd.width)
				{
					p = bd.getPixel32(x, y);
					hash = (hash ^ p) * 16777619;
					x += step;
				};
				y += step;
			};
			return bd.width + "x" + bd.height + ":" + hash.toString(16);
		}

		/**
		 * CurrentStatsName is the form on screen. CharacterStats stays on the form you opened.
		 * A name that is neither form is ignored.
		 */
		public static function fighterForm(currentStatsName:String, characterStatsName:String, openedName:String, partnerName:String):String
		{
			var current:String;
			var character:String;
			var opened:String;
			var partner:String;
			current = currentStatsName ? currentStatsName.toLowerCase() : "";
			character = characterStatsName ? characterStatsName.toLowerCase() : "";
			opened = openedName ? openedName.toLowerCase() : "";
			partner = partnerName ? partnerName.toLowerCase() : "";
			if (current == opened || (partner && current == partner))
			{
				return current;
			};
			if (character == opened || (partner && character == partner))
			{
				return character;
			};
			return opened;
		}

		/**
		 * One group per form. Every selected color of that form stays in that one group.
		 * picks are { color:uint, alt:Boolean }. Returns { form:String, colors:Array }.
		 */
		public static function groupsForSelection(picks:Array, openedName:String, partnerName:String):Array
		{
			var opened:Array;
			var partner:Array;
			var out:Array;
			var pick:Object;
			var color:uint;
			opened = [];
			partner = [];
			out = [];
			if (!picks)
			{
				return out;
			};
			for each (pick in picks)
			{
				if (!pick)
				{
					continue;
				};
				color = uint(pick.color);
				if (pick.alt && partnerName)
				{
					if (partner.indexOf(color) == -1)
					{
						partner.push(color);
					};
				}
				else if (opened.indexOf(color) == -1)
				{
					opened.push(color);
				};
			};
			if (opened.length > 0)
			{
				out.push({ "form": openedName ? openedName : "", "colors": opened });
			};
			if (partner.length > 0)
			{
				out.push({ "form": partnerName, "colors": partner });
			};
			return out;
		}

		/**
		 * Bottom row, left to right. A transparent gap starts a new strip.
		 * The first strip is the opened form. The next is the partner.
		 */
		public static function paletteStripsFromBottomRow(bd:BitmapData):Array
		{
			var strips:Array;
			var run:Array;
			var y:int;
			var i:int;
			var color:uint;
			strips = [];
			if (!bd || bd.height < 2 || bd.width < 1)
			{
				return strips;
			};
			run = [];
			y = bd.height - 1;
			i = 0;
			while (i < bd.width)
			{
				color = uint(bd.getPixel32(i, y));
				if (((color >> 24) & 0xFF) == 0)
				{
					if (run.length > 0)
					{
						strips.push(run);
						run = [];
					};
				}
				else
				{
					run.push(color);
				};
				i++;
			};
			if (run.length > 0)
			{
				strips.push(run);
			};
			return strips;
		}

		/** Two color sheets in one PNG. A transparent column between them keeps each palette row separate. */
		public static function placeSheetsSideBySide(left:BitmapData, right:BitmapData, gap:int):BitmapData
		{
			var width:int;
			var height:int;
			var out:BitmapData;
			if (!left)
			{
				return right;
			};
			if (!right)
			{
				return left;
			};
			if (gap < 1)
			{
				gap = 1;
			};
			width = left.width + gap + right.width;
			height = left.height > right.height ? left.height : right.height;
			out = new BitmapData(width, height, true, 0x00000000);
			out.copyPixels(left, left.rect, new Point(0, height - left.height));
			out.copyPixels(right, right.rect, new Point(left.width + gap, height - right.height));
			return out;
		}

		/** The fighter highlight uses the partner row when that form is the one on screen. */
		public static function fighterUsesPartnerPalette(liveForm:String, partnerName:String):Boolean
		{
			if (!liveForm || !partnerName)
			{
				return false;
			};
			return liveForm.toLowerCase() == partnerName.toLowerCase();
		}

		/** The transformed form uses its own block. The opened form keeps the opened block. */
		public static function blockForLiveForm(liveIsPartner:Boolean, openedBlock:Object, partnerBlock:Object):Object
		{
			if (liveIsPartner && partnerBlock)
			{
				return (partnerBlock);
			};
			return (openedBlock);
		}

		/** True when any pair actually changes a color. An empty or identity block does not. */
		public static function blockHasRecolor(block:Object):Boolean
		{
			var colors:Array;
			var repls:Array;
			var i:int;
			if (!block || !(block.colors is Array) || !(block.replacements is Array))
			{
				return false;
			};
			colors = block.colors as Array;
			repls = block.replacements as Array;
			i = 0;
			while (i < colors.length && i < repls.length)
			{
				if (uint(colors[i]) != uint(repls[i]))
				{
					return true;
				};
				i++;
			};
			return false;
		}

		/**
		 * The opened form keeps its block. The partner form keeps its own block when that
		 * block has a recolor. An identity partner block returns null so the caller does
		 * not stamp the opened form's no-recolor palette onto the transform.
		 */
		public static function livePaintBlock(liveIsPartner:Boolean, openedBlock:Object, partnerBlock:Object):Object
		{
			if (!liveIsPartner)
			{
				return openedBlock;
			};
			if (blockHasRecolor(partnerBlock))
			{
				return partnerBlock;
			};
			return null;
		}

		/** BowserExt.currentCostume is getCostume() + 1. Default costume -1 is palette 0. */
		public static function gigaPaletteIndex(gameCostumeIndex:int):int
		{
			var index:int;
			index = gameCostumeIndex + 1;
			if (index < 0)
			{
				return 0;
			};
			return index;
		}

		/** Giga Bowser's match transform stays on activateFinalForm's reapplyCostume. */
		public static function matchUsesStockTransform(statsName:String):Boolean
		{
			return statsName == "bowser" || statsName == "gigabowser";
		}

		/**
		 * Restores the portrait's cached pixels, then applies the live paletteSwapPA.
		 * Bowser's script stores that block with setPaletteSwapData and does not paint the HUD.
		 * Returns how many bitmaps were painted.
		 */
		public static function paintLivePortrait(statsName:String, portrait:MovieClip, paletteSwapPA:Object):int
		{
			if (!matchUsesStockTransform(statsName) || !portrait || !paletteSwapPA)
			{
				return 0;
			};
			if (!(paletteSwapPA.colors is Array) || !(paletteSwapPA.replacements is Array))
			{
				return 0;
			};
			return paintPortrait(portrait, paletteSwapPA, 12);
		}

		/**
		 * Base colors stay in order. Alt colors are the ones the base list does not already have.
		 * Returns { base:Array, alt:Array }.
		 */
		/**
		 * Each form keeps its own list, including colors that are in both.
		 * Returns { base:Array, alt:Array }.
		 */
		/** Body keys first, then portrait keys the body block does not already have. */
		public static function mergePaintBlock(body:Object, portrait:Object):Object
		{
			var colors:Array;
			var replacements:Array;
			var seen:Object;
			colors = [];
			replacements = [];
			seen = {};
			appendPaintPairs(body, colors, replacements, seen);
			appendPaintPairs(portrait, colors, replacements, seen);
			if (colors.length == 0)
			{
				return body ? body : portrait;
			};
			return { "colors": colors, "replacements": replacements };
		}

		private static function appendPaintPairs(block:Object, colors:Array, replacements:Array, seen:Object):void
		{
			var src:Array;
			var repl:Array;
			var i:int;
			var color:uint;
			if (!block || !(block.colors is Array) || !(block.replacements is Array))
			{
				return;
			};
			src = block.colors as Array;
			repl = block.replacements as Array;
			i = 0;
			while (i < src.length)
			{
				color = uint(src[i]);
				if (!seen[color])
				{
					seen[color] = true;
					colors.push(color);
					replacements.push(i < repl.length ? uint(repl[i]) : color);
				};
				i++;
			};
		}

		public static function formSwatchLists(baseColors:Array, altColors:Array):Object
		{
			return {
				"base": uniqueColorList(baseColors),
				"alt": uniqueColorList(altColors)
			};
		}

		/**
		 * Discover stores the scan character first. The opened row is that character's own colors.
		 * Sheik's opened row is the scan alt list. Zelda's opened row is the scan base list.
		 */
		public static function swatchListsForOpened(openedIsScanCharacter:Boolean, scanBase:Array, scanAlt:Array):Object
		{
			if (openedIsScanCharacter)
			{
				return formSwatchLists(scanBase, scanAlt);
			};
			return formSwatchLists(scanAlt, scanBase);
		}

		/** A row inside the visible window can be sampled. A row above or below it cannot. */
		public static function uniqueRowIsVisible(row:int, scrollRow:int, visibleRows:int):Boolean
		{
			return row >= scrollRow && row < scrollRow + visibleRows;
		}

		private static function uniqueColorList(colors:Array):Array
		{
			var seen:Object = {};
			var out:Array = [];
			var color:uint;
			if (!colors)
			{
				return out;
			};
			for each (color in colors)
			{
				if (seen[uint(color)])
				{
					continue;
				};
				seen[uint(color)] = true;
				out.push(uint(color));
			};
			return out;
		}

		public static function splitFormColors(baseColors:Array, altColors:Array):Object
		{
			var seen:Object = {};
			var baseOut:Array = [];
			var altOut:Array = [];
			var color:uint;
			if (baseColors)
			{
				for each (color in baseColors)
				{
					if (seen[uint(color)])
					{
						continue;
					};
					seen[uint(color)] = true;
					baseOut.push(uint(color));
				};
			};
			if (altColors)
			{
				for each (color in altColors)
				{
					if (seen[uint(color)])
					{
						continue;
					};
					seen[uint(color)] = true;
					altOut.push(uint(color));
				};
			};
			return { "base": baseOut, "alt": altOut };
		}

		/** Numbered frames of a final stay separate. Other numbered names share one root. */
		public static function uniqueScanRoot(linkage:String):String
		{
			var low:String;
			var code:int;
			if (!linkage)
			{
				return "";
			};
			low = linkage.toLowerCase();
			if (low.indexOf("_final") != -1)
			{
				return low;
			};
			while (low.length > 0)
			{
				code = low.charCodeAt(low.length - 1);
				if (code < 48 || code > 57)
				{
					break;
				};
				low = low.substr(0, low.length - 1);
			};
			return low;
		}
		public static function linkageKeptForUniqueScan(linkage:String):Boolean
		{
			if (!linkage)
			{
				return false;
			};
			return linkage.toLowerCase().indexOf("old") == -1;
		}

		/** Tall strip art keeps the same on-screen height as the sprites around it. */
		public static function stripHeightScale(bitmapHeight:Number, baseScale:Number, rowHeight:Number):Number
		{
			if (bitmapHeight <= 0 || baseScale <= 0)
			{
				return baseScale;
			};
			if (bitmapHeight * baseScale > rowHeight && rowHeight > 0)
			{
				return rowHeight / bitmapHeight;
			};
			return baseScale;
		}

		/** Pixels of colors this sprite has that earlier sprites did not. */
		public static function newColorPixels(pixelCounts:Object, covered:Object):int
		{
			var key:String;
			var total:int = 0;
			if (!pixelCounts)
			{
				return 0;
			};
			for (key in pixelCounts)
			{
				if (!covered || !covered[uint(key)])
				{
					total += int(pixelCounts[key]);
				};
			};
			return total;
		}

		/** Pixels of colors that are still uncovered. A larger count is the sprite that shows that color. */
		public static function uncoveredPixelCount(pixelCounts:Object, remaining:Object):int
		{
			var key:String;
			var total:int = 0;
			if (!pixelCounts)
			{
				return 0;
			};
			for (key in pixelCounts)
			{
				if (!remaining || remaining[uint(key)])
				{
					total += int(pixelCounts[key]);
				};
			};
			return total;
		}

		/** A sprite is kept only when it still has a color the earlier sprites did not cover. */
		public static function spriteAddsColor(colors:Array, covered:Object):Boolean
		{
			var color:uint;
			if (!colors)
			{
				return false;
			};
			for each (color in colors)
			{
				if (!covered || !covered[uint(color)])
				{
					return true;
				};
			};
			return false;
		}

		private static function paintPortrait(mc:MovieClip, block:Object, depth:int):int
		{
			var i:int;
			var child:DisplayObject;
			var bitmap:Bitmap;
			var cache:Dictionary;
			var painted:int;
			if (!mc || depth < 0)
			{
				return 0;
			};
			painted = 0;
			i = 0;
			while (i < mc.numChildren)
			{
				child = mc.getChildAt(i);
				if (child is Bitmap)
				{
					bitmap = child as Bitmap;
					if (bitmap.bitmapData)
					{
						cache = portraitPixelCache[mc] as Dictionary;
						if (!cache)
						{
							cache = new Dictionary(true);
							portraitPixelCache[mc] = cache;
						};
						if (!cache[bitmap.bitmapData])
						{
							cache[bitmap.bitmapData] = bitmap.bitmapData.clone();
						}
						else
						{
							bitmap.bitmapData.draw(cache[bitmap.bitmapData] as BitmapData);
						};
						applyHelper(bitmap.bitmapData, block);
						bitmap.smoothing = true;
						painted++;
					};
				}
				else if ((child is MovieClip) && depth > 0)
				{
					painted += paintPortrait(child as MovieClip, block, depth - 1);
				};
				i++;
			};
			return painted;
		}

		public static function applyBlock(root:MovieClip, block:Object):int
		{
			if (!root || !block || !(block.colors is Array) || !(block.replacements is Array))
			{
				return 0;
			};
			return paintRemaining(root, block, 16);
		}

		private static function paintRemaining(mc:MovieClip, block:Object, depth:int):int
		{
			var i:int;
			var child:DisplayObject;
			var bitmap:Bitmap;
			var painted:int;
			if (!mc || depth < 0)
			{
				return 0;
			};
			painted = 0;
			i = 0;
			while (i < mc.numChildren)
			{
				child = mc.getChildAt(i);
				if (child is Bitmap)
				{
					bitmap = child as Bitmap;
					if (bitmap.bitmapData && bitmapStillHas(bitmap.bitmapData, block))
					{
						if (LinkedFormSprite.formForRemainingColors(false, true) == "partner")
						{
							applyHelper(bitmap.bitmapData, block);
							painted++;
						};
					};
				}
				else if (child is MovieClip)
				{
					painted += paintRemaining(child as MovieClip, block, depth - 1);
				};
				i++;
			};
			return painted;
		}

		private static function applyHelper(bitmapData:BitmapData, paletteData:Object):void
		{
			var rect:Rectangle;
			var i:int;
			var color:uint;
			var replacement:uint;
			rect = new Rectangle(0, 0, bitmapData.width, bitmapData.height);
			i = 0;
			while (i < paletteData.colors.length && i < paletteData.replacements.length)
			{
				color = uint(paletteData.colors[i]);
				replacement = uint(paletteData.replacements[i]);
				if (color != replacement)
				{
					bitmapData.threshold(bitmapData, rect, new flash.geom.Point(0, 0), "==", color, replacement, 0xFFFFFFFF, true);
				};
				i++;
			};
		}

		/** Middle value of the sprite sides. Empty input is 0. */
		public static function medianSide(sides:Array):Number
		{
			var copy:Array;
			var mid:int;
			if (!sides || sides.length == 0)
			{
				return 0;
			};
			copy = sides.concat();
			copy.sort(Array.NUMERIC);
			mid = int(copy.length / 2);
			if ((copy.length % 2) == 1)
			{
				return Number(copy[mid]);
			};
			return (Number(copy[mid - 1]) + Number(copy[mid])) / 2;
		}

		/** Width after the row height cap. A short bitmap is not scaled up. */
		public static function fittedStripWidth(bitmapWidth:Number, bitmapHeight:Number, rowHeight:Number):Number
		{
			if (bitmapWidth <= 0 || bitmapHeight <= 0)
			{
				return 0;
			};
			if (rowHeight > 0 && bitmapHeight > rowHeight)
			{
				return bitmapWidth * rowHeight / bitmapHeight;
			};
			return bitmapWidth;
		}

		/** Off the strip when the on-screen width is at least twice the typical sprite. */
		public static function spriteTooBigForStrip(shownWidth:Number, typicalWidth:Number):Boolean
		{
			return typicalWidth > 0 && shownWidth >= typicalWidth * 2;
		}

		/** Colors from a full pixel read and the stored list. */
		public static function unionUniqueSampleColors(colors:Array, bd:BitmapData, stored:Array):Array
		{
			var out:Array;
			var seen:Object;
			var sample:Object;
			var color:uint;
			out = colors ? colors.concat() : [];
			seen = {};
			for each (color in out)
			{
				seen[uint(color)] = true;
			};
			if (bd)
			{
				sample = sampleOpaqueColors(bd, 1);
				if (sample && sample.colors is Array)
				{
					for each (color in (sample.colors as Array))
					{
						if (!seen[uint(color)])
						{
							seen[uint(color)] = true;
							out.push(uint(color));
						};
					};
				};
			};
			if (stored)
			{
				for each (color in stored)
				{
					if (!seen[uint(color)])
					{
						seen[uint(color)] = true;
						out.push(uint(color));
					};
				};
			};
			return out;
		}
		public static function keepUniqueSampleColor(count:int, bucketCount:int, neutral:Boolean):Boolean
		{
			return count >= 1;
		}

		/** -1 when the pixel is chromatic. Otherwise the grey band 0–15. */
		public static function neutralBand(color:uint):int
		{
			var r:int;
			var g:int;
			var b:int;
			var maxc:int;
			var minc:int;
			r = (color >> 16) & 0xFF;
			g = (color >> 8) & 0xFF;
			b = color & 0xFF;
			maxc = r > g ? r : g;
			if (b > maxc)
			{
				maxc = b;
			};
			minc = r < g ? r : g;
			if (b < minc)
			{
				minc = b;
			};
			if (maxc <= 0)
			{
				return 0;
			};
			if ((maxc - minc) / Number(maxc) >= 0.15)
			{
				return -1;
			};
			return int(maxc / 16);
		}

		/**
		 * One read of the bitmap, stepping by stride. One pixel is enough to keep a color.
		 * Returns { colors:Array, counts:Object }.
		 */
		public static function sampleOpaqueColors(bd:BitmapData, stride:int = 4):Object
		{
			var counts:Object = {};
			var colors:Array = [];
			var vec:Vector.<uint>;
			var p:uint;
			var n:int;
			var j:int;
			var k:*;
			var drop:Array;
			var bands:Object;
			var band:int;
			if (stride < 1)
			{
				stride = 1;
			};
			if (!bd || bd.width <= 0 || bd.height <= 0)
			{
				return { "colors": colors, "counts": counts };
			};
			try
			{
				vec = bd.getVector(bd.rect);
			}
			catch (err:Error)
			{
				return { "colors": colors, "counts": counts };
			};
			n = vec.length;
			bands = {};
			j = 0;
			while (j < n)
			{
				p = vec[j];
				if (((p >> 24) & 0xFF) > 0)
				{
					if (counts[p])
					{
						counts[p] = int(counts[p]) + 1;
					}
					else
					{
						counts[p] = 1;
					};
					band = neutralBand(p);
					if (band >= 0)
					{
						if (bands[band])
						{
							bands[band] = int(bands[band]) + 1;
						}
						else
						{
							bands[band] = 1;
						};
					};
				};
				j += stride;
			};
			drop = [];
			for (k in counts)
			{
				band = neutralBand(uint(k));
				if (keepUniqueSampleColor(int(counts[k]), band >= 0 ? int(bands[band]) : 0, band >= 0))
				{
					colors.push(uint(k));
				}
				else
				{
					drop.push(k);
				};
			};
			for each (k in drop)
			{
				delete counts[k];
			};
			return { "colors": colors, "counts": counts };
		}

		private static function bitmapStillHas(bd:BitmapData, block:Object):Boolean
		{
			var colors:Array;
			var replacements:Array;
			var i:int;
			var color:uint;
			var rect:Rectangle;
			colors = block.colors as Array;
			replacements = block.replacements as Array;
			i = 0;
			while (i < colors.length && i < replacements.length)
			{
				color = uint(colors[i]);
				if (color != uint(replacements[i]))
				{
					rect = bd.getColorBoundsRect(0xFFFFFFFF, color, true);
					if (rect.width > 0 && rect.height > 0)
					{
						return true;
					};
				};
				i++;
			};
			return false;
		}
	}
}
