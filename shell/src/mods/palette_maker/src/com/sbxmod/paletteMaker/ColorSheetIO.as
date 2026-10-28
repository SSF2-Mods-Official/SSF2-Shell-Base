package com.sbxmod.paletteMaker
{
	import com.adobe.images.PNGEncoder;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.events.Event;
	import flash.events.FileListEvent;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;

	import ssf2mm.shared.JsonFile;

	/**
	 * Color sheet PNG I/O (pixel-perfect).
	 *
	 * Layout top → bottom:
	 *   [ portrait LEFT | unique sprites packed in rows to the RIGHT ]
	 *   [ last row: 1×1 applied costume colors, left → right ]
	 *
	 * No MAGIC / reserved colors. Any PNG with a bottom palette row can be read.
	 * Sheet width = max(artWidth, paletteCount). Art is cropped before the palette row.
	 */
	public class ColorSheetIO
	{
		private static const MAX_RASTER_SIDE:int = 1024;

		private static var s_fileRef:FileReference;
		private static var s_onImport:Function;
		private static var s_loader:Loader;
		/** Multi-PNG import: onComplete(Array of { name:String, bitmapData:BitmapData }). */
		private static var s_onImportMulti:Function;
		private static var s_browseFile:File;
		private static var s_multiQueue:Array;
		private static var s_multiIndex:int;
		private static var s_multiResults:Array;

		/** Dedupe by RGB (first wins). Keeps full ARGB of the first occurrence. */
		public static function dedupeRgb(colors:Array):Array
		{
			var out:Array = [];
			var seen:Object = {};
			var i:int;
			var c:uint;
			var key:String;
			if (!colors)
			{
				return out;
			};
			i = 0;
			while (i < colors.length)
			{
				c = uint(colors[i]);
				key = String(c & 0x00FFFFFF);
				if (!seen[key])
				{
					seen[key] = true;
					if (((c >> 24) & 0xFF) == 0)
					{
						c = 0xFF000000 | (c & 0x00FFFFFF);
					};
					out.push(c);
				};
				i++;
			};
			return out;
		}

		/** Align replacements to RGB-deduped bases (first replacement wins per RGB). */
		public static function alignAppliedColors(bases:Array, replacements:Array):Array
		{
			var cleanBases:Array = dedupeRgb(bases);
			if (!bases || !replacements || bases.length != replacements.length)
			{
				return cleanBases.concat();
			};
			return alignReplacementsAfterDedupe(bases, replacements, cleanBases);
		}

		/** Crop transparent padding from a bitmap (returns clone; may be 1×1). */
		public static function cropOpaque(bd:BitmapData):BitmapData
		{
			var bounds:Rectangle;
			var out:BitmapData;
			if (!bd)
			{
				return new BitmapData(1, 1, true, 0);
			};
			bounds = bd.getColorBoundsRect(0xFF000000, 0x00000000, false);
			if (bounds.width < 1 || bounds.height < 1)
			{
				return new BitmapData(1, 1, true, 0);
			};
			out = new BitmapData(int(bounds.width), int(bounds.height), true, 0x00000000);
			out.copyPixels(bd, bounds, new Point(0, 0));
			return out;
		}

		/**
		 * Build sheet: cropped art + one bottom row of applied colors (1×1 each).
		 * @param appliedColors colors currently on the costume (replacements), stable order.
		 */
		public static function buildSheet(artBd:BitmapData, appliedColors:Array):BitmapData
		{
			var n:int;
			var i:int;
			var art:BitmapData;
			var artW:int;
			var artH:int;
			var sheetW:int;
			var sheetH:int;
			var out:BitmapData;
			var c:uint;
			var colors:Array;
			colors = [];
			i = 0;
			while (appliedColors && i < appliedColors.length)
			{
				c = uint(appliedColors[i]);
				if (((c >> 24) & 0xFF) == 0 && (c & 0x00FFFFFF) != 0)
				{
					c = 0xFF000000 | (c & 0x00FFFFFF);
				};
				colors.push(c);
				i++;
			};
			n = colors.length;
			if (n <= 0)
			{
				return null;
			};
			art = artBd ? cropOpaque(artBd) : new BitmapData(1, 1, true, 0);
			artW = art.width;
			artH = art.height;
			sheetW = Math.max(artW, n);
			sheetH = artH + 1;
			out = new BitmapData(sheetW, sheetH, true, 0x00000000);
			out.copyPixels(art, art.rect, new Point(0, 0));
			if (art != artBd)
			{
				art.dispose();
			};
			i = 0;
			while (i < n)
			{
				out.setPixel32(i, artH, uint(colors[i]));
				i++;
			};
			return out;
		}

		private static function alignReplacementsAfterDedupe(bases:Array, replacements:Array, cleanBases:Array):Array
		{
			var map:Object = {};
			var i:int;
			var out:Array = [];
			var c:uint;
			i = 0;
			while (i < bases.length && i < replacements.length)
			{
				c = uint(bases[i]);
				if (!map.hasOwnProperty(String(c & 0x00FFFFFF)))
				{
					map[String(c & 0x00FFFFFF)] = uint(replacements[i]);
				};
				i++;
			};
			i = 0;
			while (i < cleanBases.length)
			{
				c = uint(cleanBases[i]);
				out.push(map.hasOwnProperty(String(c & 0x00FFFFFF))
					? uint(map[String(c & 0x00FFFFFF)])
					: c);
				i++;
			};
			return out;
		}

		/**
		 * Read bottom palette row: opaque pixels left → right until first fully transparent.
		 * Returns { colors:Array } or null.
		 */
		public static function readPaletteStrip(bd:BitmapData):Object
		{
			var i:int;
			var y:int;
			var c:uint;
			var colors:Array;
			if (!bd || bd.height < 2 || bd.width < 1)
			{
				return null;
			};
			y = bd.height - 1;
			colors = [];
			i = 0;
			while (i < bd.width)
			{
				c = uint(bd.getPixel32(i, y));
				if (((c >> 24) & 0xFF) == 0)
				{
					break;
				};
				colors.push(c);
				i++;
			};
			if (colors.length == 0)
			{
				return null;
			};
			return { "colors": colors };
		}

		/**
		 * Portrait on the left; remaining parts packed in rows to the right.
		 * parts[0] = portrait (optional), parts[1..] = unique sprites.
		 * Keeps every unique the UI already selected (incl. large transform forms
		 * like Giga Bowser) — do not size-filter uniques here.
		 */
		public static function composePortraitUniqueLayout(parts:Array, gap:int = 4):BitmapData
		{
			var slices:Array;
			var portrait:BitmapData = null;
			var uniques:Array = [];
			var i:int;
			var slice:BitmapData;
			var packW:int;
			var packed:BitmapData;
			var out:BitmapData;
			var uniqueX:int;
			var sheetW:int;
			var sheetH:int;
			slices = rasterizeParts(parts);
			if (slices.length == 0)
			{
				return new BitmapData(1, 1, true, 0);
			};
			portrait = slices[0] as BitmapData;
			i = 1;
			while (i < slices.length)
			{
				slice = slices[i] as BitmapData;
				if (slice)
				{
					uniques.push(slice);
				};
				i++;
			};
			if (uniques.length == 0)
			{
				return portrait ? cropOpaque(portrait) : new BitmapData(1, 1, true, 0);
			};
			packW = Math.max(280, portrait ? portrait.width : 280);
			packed = packRows(uniques, packW, gap);
			if (!portrait)
			{
				return packed;
			};
			uniqueX = portrait.width + gap;
			sheetW = uniqueX + packed.width;
			sheetH = Math.max(portrait.height, packed.height);
			out = new BitmapData(sheetW, sheetH, true, 0x00000000);
			out.copyPixels(portrait, portrait.rect, new Point(0, 0));
			out.copyPixels(packed, packed.rect, new Point(uniqueX, 0));
			portrait.dispose();
			packed.dispose();
			return cropOpaque(out);
		}

		private static function rasterizeParts(parts:Array):Array
		{
			var i:int;
			var disp:DisplayObject;
			var bounds:Rectangle;
			var slices:Array = [];
			var cropped:BitmapData;
			var m:Matrix;
			var tmp:BitmapData;
			var tw:int;
			var th:int;
			var scale:Number;
			if (!parts)
			{
				return slices;
			};
			i = 0;
			while (i < parts.length)
			{
				disp = parts[i] as DisplayObject;
				if (!disp)
				{
					i++;
					continue;
				};
				bounds = disp.getBounds(disp);
				if (bounds.width < 1 || bounds.height < 1)
				{
					i++;
					continue;
				};
				tw = Math.ceil(bounds.width);
				th = Math.ceil(bounds.height);
				scale = 1;
				if (tw > MAX_RASTER_SIDE || th > MAX_RASTER_SIDE)
				{
					scale = Math.min(Number(MAX_RASTER_SIDE) / tw, Number(MAX_RASTER_SIDE) / th);
					tw = Math.max(1, Math.ceil(tw * scale));
					th = Math.max(1, Math.ceil(th * scale));
				};
				tmp = new BitmapData(tw, th, true, 0x00000000);
				m = new Matrix();
				m.translate(-bounds.x, -bounds.y);
				if (scale != 1)
				{
					m.scale(scale, scale);
				};
				tmp.draw(disp, m, null, null, null, false);
				cropped = cropOpaque(tmp);
				tmp.dispose();
				if (cropped.width > 1 || cropped.height > 1
					|| ((cropped.getPixel32(0, 0) >> 24) & 0xFF) != 0)
				{
					slices.push(cropped);
				}
				else
				{
					cropped.dispose();
				};
				i++;
			};
			return slices;
		}

		/** Pack bitmaps left→right, wrapping at maxRowW. Disposes input slices. */
		private static function packRows(slices:Array, maxRowW:int, gap:int):BitmapData
		{
			var i:int;
			var slice:BitmapData;
			var rows:Array = [];
			var row:Array = [];
			var rowW:int = 0;
			var need:int;
			var totalW:int = 1;
			var totalH:int = 0;
			var out:BitmapData;
			var x:int;
			var y:int;
			var rh:int;
			var r:int;
			var j:int;
			if (!slices || slices.length == 0)
			{
				return new BitmapData(1, 1, true, 0);
			};
			if (maxRowW < 1)
			{
				maxRowW = 1;
			};
			i = 0;
			while (i < slices.length)
			{
				slice = slices[i] as BitmapData;
				need = (row.length == 0) ? slice.width : (slice.width + gap);
				if (row.length > 0 && (rowW + need) > maxRowW)
				{
					rows.push(row);
					row = [slice];
					rowW = slice.width;
				}
				else
				{
					row.push(slice);
					rowW += need;
				};
				i++;
			};
			if (row.length > 0)
			{
				rows.push(row);
			};
			r = 0;
			while (r < rows.length)
			{
				row = rows[r] as Array;
				rowW = 0;
				rh = 0;
				j = 0;
				while (j < row.length)
				{
					slice = row[j] as BitmapData;
					rowW += slice.width + (j > 0 ? gap : 0);
					if (slice.height > rh)
					{
						rh = slice.height;
					};
					j++;
				};
				if (rowW > totalW)
				{
					totalW = rowW;
				};
				totalH += rh + (r < rows.length - 1 ? gap : 0);
				r++;
			};
			out = new BitmapData(totalW, Math.max(1, totalH), true, 0x00000000);
			y = 0;
			r = 0;
			while (r < rows.length)
			{
				row = rows[r] as Array;
				x = 0;
				rh = 0;
				j = 0;
				while (j < row.length)
				{
					slice = row[j] as BitmapData;
					if (slice.height > rh)
					{
						rh = slice.height;
					};
					j++;
				};
				j = 0;
				while (j < row.length)
				{
					slice = row[j] as BitmapData;
					out.copyPixels(slice, slice.rect, new Point(x, y));
					x += slice.width + gap;
					slice.dispose();
					j++;
				};
				y += rh + (r < rows.length - 1 ? gap : 0);
				r++;
			};
			return cropOpaque(out);
		}

		public static function exportPng(bd:BitmapData, defaultName:String):void
		{
			var bytes:ByteArray;
			if (!bd)
			{
				return;
			};
			bytes = PNGEncoder.encode(bd);
			clearFileRef();
			s_fileRef = new FileReference();
			s_fileRef.save(bytes, defaultName ? defaultName : "colorsheet.png");
		}

		/** Write PNG bytes directly to a File (batch regenerate). */
		public static function writePngFile(bd:BitmapData, file:File):Boolean
		{
			if (!bd || !file)
			{
				return false;
			};
			try
			{
				return JsonFile.writeBytes(file, PNGEncoder.encode(bd));
			}
			catch (err:Error)
			{
			};
			return false;
		}

		/**
		 * Browse for one or more PNGs (AIR multi-select).
		 * onComplete(items:Array) where each item is { name:String, bitmapData:BitmapData }.
		 * name is the file's name (with extension). Cancel / empty → callback not called.
		 */
		public static function importPngs(onComplete:Function):void
		{
			clearMultiImport();
			s_onImportMulti = onComplete;
			s_browseFile = new File();
			s_browseFile.addEventListener(FileListEvent.SELECT_MULTIPLE, onImportMultiSelected);
			s_browseFile.addEventListener(Event.CANCEL, onImportMultiCancel);
			try
			{
				Ssf2.MultiplayerManager.notify("Select color sheet PNG(s)…");
			}
			catch (ignore:Error)
			{
			};
			try
			{
				s_browseFile.browseForOpenMultiple("Select Color Sheet PNGs", [new FileFilter("Color Sheet PNG", "*.png")]);
			}
			catch (err:Error)
			{
				failMultiImport(err.message);
			};
		}

		/** Filename without path or extension (e.g. "Fire Mario.png" → "Fire Mario"). */
		public static function basenameNoExtension(filename:String):String
		{
			var name:String;
			var slash:int;
			var dot:int;
			if (!filename)
			{
				return "";
			};
			name = filename;
			slash = Math.max(name.lastIndexOf("/"), name.lastIndexOf("\\"));
			if (slash >= 0)
			{
				name = name.substring(slash + 1);
			};
			dot = name.lastIndexOf(".");
			if (dot > 0)
			{
				name = name.substring(0, dot);
			};
			name = name.replace(new RegExp("^\\s+|\\s+$", "g"), "");
			return name;
		}

		private static function onImportSelected(e:Event):void
		{
			s_fileRef.removeEventListener(Event.SELECT, onImportSelected);
			s_fileRef.addEventListener(Event.COMPLETE, onImportLoaded);
			s_fileRef.load();
		}

		private static function onImportLoaded(e:Event):void
		{
			var bytes:ByteArray;
			var ctx:LoaderContext;
			s_fileRef.removeEventListener(Event.COMPLETE, onImportLoaded);
			bytes = s_fileRef.data;
			if (!bytes || bytes.length == 0)
			{
				failImport("Empty file");
				return;
			};
			s_loader = new Loader();
			s_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onImportDecoded);
			s_loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onImportIoError);
			ctx = new LoaderContext();
			ctx.checkPolicyFile = false;
			s_loader.loadBytes(bytes, ctx);
		}

		private static function onImportDecoded(e:Event):void
		{
			var bmp:Bitmap;
			var bd:BitmapData;
			var cb:Function;
			try
			{
				s_loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onImportDecoded);
				bmp = s_loader.content as Bitmap;
				if (!bmp || !bmp.bitmapData)
				{
					failImport("Not a bitmap");
					return;
				};
				bd = bmp.bitmapData.clone();
				cb = s_onImport;
				s_onImport = null;
				if (cb != null)
				{
					cb(bd);
				};
			}
			catch (err:Error)
			{
				failImport(err.message);
			};
			s_loader = null;
		}

		private static function onImportCancel(e:Event):void
		{
			clearFileRef();
			s_onImport = null;
		}

		private static function onImportIoError(e:Event):void
		{
			failImport("IO error");
		}

		private static function onImportMultiSelected(e:FileListEvent):void
		{
			var files:Array;
			cleanupBrowseFile();
			files = e.files as Array;
			if (!files || files.length == 0)
			{
				try
				{
					Ssf2.MultiplayerManager.notify("No color sheets selected");
				}
				catch (ignore:Error)
				{
				};
				s_onImportMulti = null;
				return;
			};
			s_multiQueue = files.concat();
			s_multiIndex = 0;
			s_multiResults = [];
			decodeNextMultiFile();
		}

		private static function onImportMultiCancel(e:Event):void
		{
			clearMultiImport();
		}

		private static function decodeNextMultiFile():void
		{
			var file:File;
			var stream:FileStream;
			var bytes:ByteArray;
			var ctx:LoaderContext;
			if (!s_multiQueue || s_multiIndex >= s_multiQueue.length)
			{
				finishMultiImport();
				return;
			};
			file = s_multiQueue[s_multiIndex] as File;
			if (!file)
			{
				s_multiIndex++;
				decodeNextMultiFile();
				return;
			};
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				bytes = new ByteArray();
				stream.readBytes(bytes);
				stream.close();
			}
			catch (err:Error)
			{
				failMultiImport("Read failed: " + file.name);
				return;
			};
			if (!bytes || bytes.length == 0)
			{
				failMultiImport("Empty file: " + file.name);
				return;
			};
			s_loader = new Loader();
			s_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onMultiDecoded);
			s_loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onMultiDecodeIoError);
			ctx = new LoaderContext();
			ctx.checkPolicyFile = false;
			s_loader.loadBytes(bytes, ctx);
		}

		private static function onMultiDecoded(e:Event):void
		{
			var bmp:Bitmap;
			var bd:BitmapData;
			var file:File;
			var name:String;
			try
			{
				if (s_loader)
				{
					s_loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onMultiDecoded);
					s_loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onMultiDecodeIoError);
				};
				bmp = s_loader.content as Bitmap;
				file = s_multiQueue[s_multiIndex] as File;
				name = file ? file.name : ("sheet_" + s_multiIndex);
				if (!bmp || !bmp.bitmapData)
				{
					failMultiImport("Not a bitmap: " + name);
					return;
				};
				bd = bmp.bitmapData.clone();
				s_multiResults.push({ "name": name, "bitmapData": bd });
			}
			catch (err:Error)
			{
				failMultiImport(err.message);
				return;
			};
			s_loader = null;
			s_multiIndex++;
			decodeNextMultiFile();
		}

		private static function onMultiDecodeIoError(e:Event):void
		{
			var file:File = (s_multiQueue && s_multiIndex < s_multiQueue.length)
				? (s_multiQueue[s_multiIndex] as File) : null;
			failMultiImport("Decode failed" + (file ? (": " + file.name) : ""));
		}

		private static function finishMultiImport():void
		{
			var cb:Function = s_onImportMulti;
			var results:Array = s_multiResults;
			s_onImportMulti = null;
			s_multiQueue = null;
			s_multiResults = null;
			s_multiIndex = 0;
			s_loader = null;
			if (cb != null && results && results.length > 0)
			{
				cb(results);
			};
		}

		private static function failImport(msg:String):void
		{
			try
			{
				Ssf2.MultiplayerManager.notify("Color sheet import failed: " + msg);
			}
			catch (ignore:Error)
			{
			};
			s_onImport = null;
			clearFileRef();
		}

		private static function failMultiImport(msg:String):void
		{
			var item:Object;
			try
			{
				Ssf2.MultiplayerManager.notify("Color sheet import failed: " + msg);
			}
			catch (ignore:Error)
			{
			};
			if (s_multiResults)
			{
				for each (item in s_multiResults)
				{
					if (item && item.bitmapData is BitmapData)
					{
						try
						{
							(item.bitmapData as BitmapData).dispose();
						}
						catch (ignore2:Error)
						{
						};
					};
				};
			};
			clearMultiImport();
		}

		private static function clearFileRef():void
		{
			if (s_fileRef)
			{
				try
				{
					s_fileRef.removeEventListener(Event.SELECT, onImportSelected);
					s_fileRef.removeEventListener(Event.CANCEL, onImportCancel);
					s_fileRef.removeEventListener(IOErrorEvent.IO_ERROR, onImportIoError);
					s_fileRef.removeEventListener(Event.COMPLETE, onImportLoaded);
				}
				catch (ignore:Error)
				{
				};
			};
			s_fileRef = null;
		}

		private static function cleanupBrowseFile():void
		{
			if (s_browseFile)
			{
				try
				{
					s_browseFile.removeEventListener(FileListEvent.SELECT_MULTIPLE, onImportMultiSelected);
					s_browseFile.removeEventListener(Event.CANCEL, onImportMultiCancel);
				}
				catch (ignore:Error)
				{
				};
			};
			s_browseFile = null;
		}

		private static function clearMultiImport():void
		{
			cleanupBrowseFile();
			if (s_loader)
			{
				try
				{
					s_loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onMultiDecoded);
					s_loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onMultiDecodeIoError);
				}
				catch (ignore:Error)
				{
				};
			};
			s_loader = null;
			s_onImportMulti = null;
			s_multiQueue = null;
			s_multiResults = null;
			s_multiIndex = 0;
		}
	}
}
