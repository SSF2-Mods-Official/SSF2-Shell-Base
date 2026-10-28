package com.sbxmod.paletteMaker
{
	import mx.core.ByteArrayAsset;

	/**
	 * zlib-compressed JSON pack of developer color sheets.
	 * Shape: { "packVersion":7, "no_recolor": { "mario": "<base64 png>", ... }, "base_recolor": { ... } }
	 * Built by tools/generate_color_sheets.py (--from-docs after Vault Ctrl+Shift+C).
	 */
	[Embed(source = "../../../color_sheets_pack.bin", mimeType = "application/octet-stream")]
	public class ColorSheetsPackData extends ByteArrayAsset
	{
	}
}
