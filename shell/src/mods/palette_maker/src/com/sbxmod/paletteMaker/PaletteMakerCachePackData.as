package com.sbxmod.paletteMaker
{
	import mx.core.ByteArrayAsset;

	/** zlib-compressed JSON pack of stock discover/unique caches (see tools/build_palette_maker_cache_pack.py). */
	[Embed(source = "../../../palette_maker_cache_pack.bin", mimeType = "application/octet-stream")]
	public class PaletteMakerCachePackData extends ByteArrayAsset
	{
	}
}
