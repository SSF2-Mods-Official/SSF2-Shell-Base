package
{
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	/**
	 * Replaces bitmap tags in a stage file. The character id is the number in the tag, not a linkage name.
	 */
	public class StageAssetSwap
	{
		public static function swap(fileBytes:ByteArray, images:Object, sizes:Object):ByteArray
		{
			var swf:ByteArray = plain(fileBytes);
			var header:int;
			var pos:int;
			var out:ByteArray;
			var codeLen:int;
			var code:int;
			var len:int;
			var head:int;
			var id:int;
			var image:BitmapData;
			var size:Object;
			if (!swf || swf.length < 8 || swf[0] != 0x46)
			{
				return (fileBytes);
			};
			header = headerLength(swf);
			out = new ByteArray();
			out.endian = Endian.LITTLE_ENDIAN;
			out.writeBytes(swf, 0, header);
			pos = header;
			while (pos + 2 <= swf.length)
			{
				codeLen = swf[pos] | (swf[pos + 1] << 8);
				code = codeLen >> 6;
				len = codeLen & 0x3F;
				head = 2;
				if (len == 0x3F)
				{
					if (pos + 6 > swf.length)
					{
						break;
					};
					len = swf[pos + 2] | (swf[pos + 3] << 8) | (swf[pos + 4] << 16) | (swf[pos + 5] << 24);
					head = 6;
				};
				if (code == 0)
				{
					writeTag(out, 0, new ByteArray());
					break;
				};
				if (len < 0 || pos + head + len > swf.length)
				{
					break;
				};
				id = -1;
				if (len >= 2)
				{
					id = swf[pos + head] | (swf[pos + head + 1] << 8);
				};
				image = images ? images[String(id)] as BitmapData : null;
				size = sizes ? sizes[String(id)] : null;
				if ((code == 6 || code == 20 || code == 21 || code == 35 || code == 36)
					&& image && size
					&& image.width == int(size.width)
					&& image.height == int(size.height))
				{
					writeTag(out, 36, lossless(id, image));
				}
				else
				{
					out.writeBytes(swf, pos, head + len);
				};
				pos += head + len;
			};
			out[4] = out.length & 0xFF;
			out[5] = (out.length >> 8) & 0xFF;
			out[6] = (out.length >> 16) & 0xFF;
			out[7] = (out.length >> 24) & 0xFF;
			return (out);
		}

		private static function headerLength(swf:ByteArray):int
		{
			var nbits:int = swf.length > 8 ? (swf[8] >> 3) : 0;
			return (8 + int((5 + nbits * 4 + 7) / 8) + 4);
		}

		private static function lossless(id:int, image:BitmapData):ByteArray
		{
			var pixels:ByteArray = image.getPixels(image.rect);
			var body:ByteArray = new ByteArray();
			pixels.position = 0;
			pixels.compress();
			body.endian = Endian.LITTLE_ENDIAN;
			body.writeShort(id);
			body.writeByte(5);
			body.writeShort(image.width);
			body.writeShort(image.height);
			body.writeBytes(pixels, 0, pixels.length);
			return (body);
		}

		private static function writeTag(output:ByteArray, code:int, body:ByteArray):void
		{
			var len:int = body ? body.length : 0;
			var codeLen:int;
			output.endian = Endian.LITTLE_ENDIAN;
			if (len < 63)
			{
				codeLen = (code << 6) | len;
				output.writeShort(codeLen);
			}
			else
			{
				codeLen = (code << 6) | 0x3F;
				output.writeShort(codeLen);
				output.writeUnsignedInt(len);
			};
			if (len > 0)
			{
				output.writeBytes(body, 0, len);
			};
		}

		private static function plain(raw:ByteArray):ByteArray
		{
			var body:ByteArray;
			var swf:ByteArray;
			var length:int;
			var skip:int;
			var start:int;
			if (!raw || raw.length < 8)
			{
				return (raw);
			};
			if (raw[0] == 0x46 && raw[1] == 0x57 && raw[2] == 0x53)
			{
				return (raw);
			};
			if (raw[0] == 0x43 && raw[1] == 0x57 && raw[2] == 0x53)
			{
				body = new ByteArray();
				body.writeBytes(raw, 8);
				body.position = 0;
				body.uncompress();
				swf = new ByteArray();
				swf.endian = Endian.LITTLE_ENDIAN;
				swf.writeByte(0x46);
				swf.writeByte(0x57);
				swf.writeByte(0x53);
				swf.writeByte(raw[3]);
				swf.writeUnsignedInt(8 + body.length);
				swf.writeBytes(body);
				return (swf);
			};
			try
			{
				body = new ByteArray();
				body.writeBytes(raw);
				body.position = 0;
				body.endian = Endian.BIG_ENDIAN;
				body.uncompress();
				if (body.length < 8)
				{
					return (raw);
				};
				body.position = 0;
				length = body.readInt();
				skip = body.readInt();
				start = 8 + skip * 4;
				if (length < 8 || start + length > body.length)
				{
					return (raw);
				};
				swf = new ByteArray();
				swf.writeBytes(body, start, length);
				return (plain(swf));
			}
			catch (err:*)
			{
			};
			return (raw);
		}
	}
}
