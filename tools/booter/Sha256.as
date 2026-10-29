package
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	/** SHA-256 of a byte buffer, returned as lowercase hex. Does not change the input. */
	public class Sha256
	{
		private static const K:Array = [
			0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
			0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
			0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
			0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
			0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
			0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
			0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
			0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
		];

		public static function hex(src:ByteArray):String
		{
			var copy:ByteArray = new ByteArray();
			var saved:uint = src.position;
			src.position = 0;
			src.readBytes(copy, 0, src.length);
			src.position = saved;
			var dig:ByteArray = digest(copy);
			var out:String = "";
			var i:int = 0;
			while (i < dig.length)
			{
				out += ("0" + dig[i].toString(16)).substr(-2);
				i++;
			}
			return out;
		}

		private static function digest(data:ByteArray):ByteArray
		{
			data.endian = Endian.BIG_ENDIAN;
			var bitHi:uint = 0;
			var bitLo:uint = data.length;
			bitHi = (bitLo / 0x20000000);
			bitLo = bitLo * 8;
			data.position = data.length;
			data.writeByte(0x80);
			while ((data.length % 64) != 56)
			{
				data.writeByte(0);
			}
			data.writeUnsignedInt(bitHi);
			data.writeUnsignedInt(bitLo);
			var h0:uint = 0x6a09e667;
			var h1:uint = 0xbb67ae85;
			var h2:uint = 0x3c6ef372;
			var h3:uint = 0xa54ff53a;
			var h4:uint = 0x510e527f;
			var h5:uint = 0x9b05688c;
			var h6:uint = 0x1f83d9ab;
			var h7:uint = 0x5be0cd19;
			var w:Array = new Array(64);
			var off:int = 0;
			while (off < data.length)
			{
				var t:int = 0;
				while (t < 16)
				{
					w[t] = ((data[off] << 24) | (data[off + 1] << 16) | (data[off + 2] << 8) | data[off + 3]) >>> 0;
					off += 4;
					t++;
				}
				t = 16;
				while (t < 64)
				{
					var s0:uint = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
					var s1:uint = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
					w[t] = w[t - 16] + s0 + w[t - 7] + s1;
					t++;
				}
				var a:uint = h0;
				var b:uint = h1;
				var c:uint = h2;
				var d:uint = h3;
				var e:uint = h4;
				var f:uint = h5;
				var g:uint = h6;
				var h:uint = h7;
				t = 0;
				while (t < 64)
				{
					s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
					var ch:uint = (e & f) ^ ((~e) & g);
					var temp1:uint = h + s1 + ch + K[t] + w[t];
					s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
					var maj:uint = (a & b) ^ (a & c) ^ (b & c);
					var temp2:uint = s0 + maj;
					h = g;
					g = f;
					f = e;
					e = d + temp1;
					d = c;
					c = b;
					b = a;
					a = temp1 + temp2;
					t++;
				}
				h0 += a;
				h1 += b;
				h2 += c;
				h3 += d;
				h4 += e;
				h5 += f;
				h6 += g;
				h7 += h;
			}
			var out:ByteArray = new ByteArray();
			out.endian = Endian.BIG_ENDIAN;
			out.writeUnsignedInt(h0);
			out.writeUnsignedInt(h1);
			out.writeUnsignedInt(h2);
			out.writeUnsignedInt(h3);
			out.writeUnsignedInt(h4);
			out.writeUnsignedInt(h5);
			out.writeUnsignedInt(h6);
			out.writeUnsignedInt(h7);
			out.position = 0;
			return out;
		}

		private static function rotr(x:uint, n:int):uint
		{
			return (x >>> n) | (x << (32 - n));
		}
	}
}
