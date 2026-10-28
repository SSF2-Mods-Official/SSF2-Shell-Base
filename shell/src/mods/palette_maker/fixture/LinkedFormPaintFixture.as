package
{
	import com.sbxmod.paletteMaker.GigaStockPalettes;
	import com.sbxmod.paletteMaker.HoverDim;
	import com.sbxmod.paletteMaker.SkinDraft;
	import com.sbxmod.paletteMaker.LinkedFormPaint;
	import com.sbxmod.paletteMaker.LinkedFormSprite;
	import com.sbxmod.paletteMaker.StudioHomeStages;
	import flash.desktop.NativeApplication;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import ssf2mm.shared.JsonFile;

	/**
	 * Down special paints the active form first. Pixels that still hold the other form's
	 * source color then take that form's costume. Zelda's already-replaced pixels stay.
	 */
	public class LinkedFormPaintFixture extends Sprite
	{
		private var m_lines:Array = [];
		private var m_failed:Boolean = false;

		public function LinkedFormPaintFixture()
		{
			addEventListener(Event.ADDED_TO_STAGE, onStage);
		}

		private function onStage(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onStage);
			try
			{
				check();
			}
			catch (err:*)
			{
				fail("threw", String(err));
			};
			m_lines.push(m_failed ? "FAIL" : "OK");
			JsonFile.writeText(File.applicationStorageDirectory.resolvePath("linked-form-paint-fixture.txt"), m_lines.join("\n"));
			NativeApplication.nativeApplication.exit(m_failed ? 1 : 0);
		}

		private function check():void
		{
			var root:MovieClip;
			var zeldaBd:BitmapData;
			var sheikBd:BitmapData;
			var stance:MovieClip;
			var sheikBlock:Object;
			var painted:int;
			zeldaBd = new BitmapData(2, 2, true, 0xFF00AACC);
			sheikBd = new BitmapData(2, 2, true, 0xFFCC8833);
			root = new MovieClip();
			stance = new MovieClip();
			root.addChild(stance);
			stance.addChild(new Bitmap(zeldaBd));
			stance.addChild(new Bitmap(sheikBd));
			sheikBlock = {
				colors: [0xFFCC8833, 0xFF2244AA],
				replacements: [0xFF11EE22, 0xFF11EE22]
			};
			painted = LinkedFormPaint.applyBlock(root, sheikBlock);
			expect("sheik bitmap painted", painted == 1, String(painted));
			expect("sheik pixel", sheikBd.getPixel32(0, 0) == 0xFF11EE22, sheikBd.getPixel32(0, 0).toString(16));
			expect("zelda pixel stays", zeldaBd.getPixel32(0, 0) == 0xFF00AACC, zeldaBd.getPixel32(0, 0).toString(16));
			expect("identity partner paints nothing", LinkedFormPaint.applyBlock(root, { colors: [0xFFCC8833], replacements: [0xFFCC8833] }) == 0, "");
			var colors:Array = [0xFF112233];
			var replacements:Array = [0xFF112233];
			expect("partner key updates", LinkedFormSprite.writeReplacementIfPresent(colors, replacements, 0xFF112233, 0xFF00FF00) && uint(replacements[0]) == 0xFF00FF00, String(replacements[0]));
			expect("missing partner key stays out", LinkedFormSprite.writeReplacementIfPresent(colors, replacements, 0xFFABCDEF, 0xFF00FF00) == false && colors.length == 1, String(colors.length));
			var openedBlock:Object = {"id": "bowser"};
			var gigaBlock:Object = {"id": "giga"};
			expect("giga paints its own palette", LinkedFormPaint.blockForLiveForm(true, openedBlock, gigaBlock) == gigaBlock, "");
			expect("bowser paints the opened palette", LinkedFormPaint.blockForLiveForm(false, openedBlock, gigaBlock) == openedBlock, "");
			expect("giga match stays stock", LinkedFormPaint.matchUsesStockTransform("bowser") && LinkedFormPaint.matchUsesStockTransform("gigabowser") && LinkedFormPaint.matchUsesStockTransform("zelda") == false, "");
			var identityBlock:Object = { colors: [0xFF112233], replacements: [0xFF112233] };
			var partnerRecolor:Object = { colors: [0xFF112233], replacements: [0xFF00FF00] };
			expect("partner transform keeps its recolor", LinkedFormPaint.livePaintBlock(true, identityBlock, partnerRecolor) == partnerRecolor, "");
			expect("identity partner is not replaced by the opened block", LinkedFormPaint.livePaintBlock(true, identityBlock, identityBlock) == null, "");
			expect("opened form keeps its block", LinkedFormPaint.livePaintBlock(false, identityBlock, partnerRecolor) == identityBlock, "");
			var linkIds:Array = LinkedFormPaint.safeLinkageIds(new LinkageIdProbe());
			expect("linkage ids skip the missing property", linkIds.length == 2 && linkIds[0] == "sonic_2" && linkIds[1] == "sonic_s", linkIds.join(","));
			var portrait:MovieClip = new MovieClip();
			var portraitPx:BitmapData = new BitmapData(1, 1, true, 0xFF00FF00);
			var bowserPa:Object = { colors: [0xFF00FF00], replacements: [0xFFFF0000] };
			var gigaPa:Object = { colors: [0xFF00FF00], replacements: [0xFF8B4513] };
			portrait.addChild(new Bitmap(portraitPx));
			expect("bowser portrait paints", LinkedFormPaint.paintLivePortrait("bowser", portrait, bowserPa) == 1, "");
			expect("bowser portrait pixel", portraitPx.getPixel32(0, 0) == 0xFFFF0000, portraitPx.getPixel32(0, 0).toString(16));
			expect("giga portrait paints", LinkedFormPaint.paintLivePortrait("gigabowser", portrait, gigaPa) == 1, "");
			expect("giga portrait uses the source pixel", portraitPx.getPixel32(0, 0) == 0xFF8B4513, portraitPx.getPixel32(0, 0).toString(16));
			expect("giga linkage is not bowser", LinkedFormSprite.matchesForm("giga_bowser_idle0", "bowser") == false && LinkedFormSprite.matchesForm("giga_bowser_idle0", "gigabowser") == true, "");
			expect("gbow is giga", LinkedFormSprite.matchesForm("gbow_fair3", "gigabowser") == true && LinkedFormSprite.matchesForm("gbow_fair3", "bowser") == false, "");
			expect("bowser extra does not steal bowser", LinkedFormSprite.matchesForm("bowser_flying1", "gigabowser", ["bowser"]) == false && LinkedFormSprite.matchesForm("bowser_flying1", "bowser") == true, "");
			expect("sdairland is sheik", LinkedFormSprite.matchesForm("sdairland_4", "sheik") == true && LinkedFormSprite.matchesForm("sdairland_4", "zelda") == false, "");
			expect("zelda extra does not steal zelda", LinkedFormSprite.matchesForm("zelda_fair3", "sheik", ["zelda"]) == false && LinkedFormSprite.matchesForm("sheik_jab31", "sheik") == true, "");
			expect("sheik transform id still matches", LinkedFormSprite.matchesForm("SheikTransform", "sheik", ["SheikTransform"]) == true, "");
			expect("partner portrait uses the partner swatch", LinkedFormSprite.hitUsesPartnerSwatch(true, null, "sheik") == true, "");
			expect("opened portrait stays on the opened swatch", LinkedFormSprite.hitUsesPartnerSwatch(false, null, "sheik") == false, "");
			expect("zelda sprite uses the partner swatch when sheik is open", LinkedFormSprite.hitUsesPartnerSwatch(false, "zelda_fair3", "zelda") == true, "");
			expect("sheik sprite stays on sheik's swatch", LinkedFormSprite.hitUsesPartnerSwatch(false, "sheik_jab31", "zelda") == false && LinkedFormSprite.hitUsesPartnerSwatch(false, "sheik_jab31", "sheik") == true, "");
			var sheikLists:Object = LinkedFormPaint.swatchListsForOpened(false, [0xFF111111], [0xFF222222]);
			expect("sheik's row is the scan alt list", uint((sheikLists.base as Array)[0]) == 0xFF222222 && uint((sheikLists.alt as Array)[0]) == 0xFF111111, "");
			var zeldaLists:Object = LinkedFormPaint.swatchListsForOpened(true, [0xFF111111], [0xFF222222]);
			expect("zelda's row is the scan base list", uint((zeldaLists.base as Array)[0]) == 0xFF111111 && uint((zeldaLists.alt as Array)[0]) == 0xFF222222, "");
			expect("hidden unique row is not sampled", LinkedFormPaint.uniqueRowIsVisible(2, 0, 2) == false && LinkedFormPaint.uniqueRowIsVisible(1, 0, 2) == true && LinkedFormPaint.uniqueRowIsVisible(2, 2, 2) == true, "");
			expect("current form beats the opened stats", LinkedFormPaint.fighterForm("zelda", "sheik", "sheik", "zelda") == "zelda", "");
			expect("opened stats stay when current is empty", LinkedFormPaint.fighterForm("", "sheik", "sheik", "zelda") == "sheik", "");
			expect("fighter hover uses the partner row", LinkedFormPaint.fighterUsesPartnerPalette("zelda", "zelda") == true && LinkedFormPaint.fighterUsesPartnerPalette("sheik", "zelda") == false, "");
			var groupPicks:Array = [
				{ "color": 0xFF111111, "alt": false },
				{ "color": 0xFF222222, "alt": false },
				{ "color": 0xFF333333, "alt": true },
				{ "color": 0xFF444444, "alt": true }
			];
			var groupSplits:Array = LinkedFormPaint.groupsForSelection(groupPicks, "zelda", "sheik");
			var zeldaGroup:Object = groupSplits[0];
			var sheikGroup:Object = groupSplits[1];
			expect("one group per form", groupSplits.length == 2 && String(zeldaGroup.form) == "zelda" && (zeldaGroup.colors as Array).length == 2 && String(sheikGroup.form) == "sheik" && (sheikGroup.colors as Array).length == 2, "");
			var sheetLeft:BitmapData = new BitmapData(2, 2, true, 0xFFFF0000);
			var sheetRight:BitmapData = new BitmapData(3, 2, true, 0xFF00FF00);
			var sheetSide:BitmapData = LinkedFormPaint.placeSheetsSideBySide(sheetLeft, sheetRight, 2);
			expect("sheets sit side by side", sheetSide.width == 7 && sheetSide.getPixel32(0, 1) == 0xFFFF0000 && ((sheetSide.getPixel32(2, 1) >> 24) & 0xFF) == 0 && sheetSide.getPixel32(4, 1) == 0xFF00FF00, sheetSide.width.toString());
			var importStrips:Array = LinkedFormPaint.paletteStripsFromBottomRow(sheetSide);
			expect("import reads both palette rows", importStrips.length == 2 && (importStrips[0] as Array).length == 2 && (importStrips[1] as Array).length == 3, String(importStrips.length));
			sheetLeft.dispose();
			sheetRight.dispose();
			sheetSide.dispose();
			var merged:Object = LinkedFormPaint.mergePaintBlock(
				{ "colors": [0xFF111111], "replacements": [0xFF222222] },
				{ "colors": [0xFF333333], "replacements": [0xFF444444] });
			expect("sprite paint keeps a portrait-only key", (merged.colors as Array).length == 2 && uint((merged.replacements as Array)[1]) == 0xFF444444, "");
			expect("default costume is giga palette 0", LinkedFormPaint.gigaPaletteIndex(-1) == 0 && LinkedFormPaint.gigaPaletteIndex(0) == 1, "");
			var gigaStock:Object = GigaStockPalettes.costume(0);
			var gigaColors:Array = gigaStock.paletteSwap.colors as Array;
			var gigaSaw:Boolean = false;
			var gigaI:int = 0;
			while (gigaI < gigaColors.length)
			{
				if (uint(gigaColors[gigaI]) == 4293704826)
				{
					gigaSaw = true;
				};
				gigaI++;
			};
			expect("giga stock recolors the source", uint(gigaStock.paletteSwap.colors[0]) != uint(gigaStock.paletteSwap.replacements[0]) && gigaSaw, "");
			expect("draft offers this character", SkinDraft.shouldOffer({ "character": "bowser", "palette": { "paletteSwap": {} } }, "bowser") == true, "");
			expect("draft skips another character", SkinDraft.shouldOffer({ "character": "mario", "palette": { "paletteSwap": {} } }, "bowser") == false, "");
			expect("bowser linkage stays bowser", LinkedFormSprite.matchesForm("bowser_idle0", "bowser") == true && LinkedFormSprite.matchesForm("bowser_idle0", "gigabowser") == false, "");
			expect("giga cover set is its own", LinkedFormSprite.coverSetId("giga_bowser_atk", "gigabowser") == "gigabowser" && LinkedFormSprite.coverSetId("bowser_atk", "gigabowser") == "base", "");
			var both:Object = LinkedFormPaint.formSwatchLists([0xFF112233, 0xFF445566], [0xFF445566, 0xFF778899]);
			expect("both forms keep the shared color", (both.base as Array).length == 2 && (both.alt as Array).length == 2 && uint((both.alt as Array)[0]) == 0xFF445566, "");
			expect("other forms leave the portrait", LinkedFormPaint.paintLivePortrait("zelda", portrait, bowserPa) == 0 && portraitPx.getPixel32(0, 0) == 0xFF8B4513, portraitPx.getPixel32(0, 0).toString(16));
			var split:Object = LinkedFormPaint.splitFormColors([0xFF112233, 0xFF445566], [0xFF445566, 0xFF778899, 0xFF112233]);
			expect("base list keeps order", split.base.length == 2 && uint(split.base[0]) == 0xFF112233 && uint(split.base[1]) == 0xFF445566, String(split.base.length));
			expect("alt omits base colors", split.alt.length == 1 && uint(split.alt[0]) == 0xFF778899, String(split.alt.length));
			var covered:Object = {};
			covered[uint(0xFF112233)] = true;
			expect("sprite with a new color stays", LinkedFormPaint.spriteAddsColor([0xFF112233, 0xFF778899], covered) == true, "");
			expect("sprite with only covered colors drops", LinkedFormPaint.spriteAddsColor([0xFF112233], covered) == false, "");
			var remain:Object = {};
			remain[uint(0xFF112233)] = true;
			expect("larger unique color wins", LinkedFormPaint.uncoveredPixelCount({0xFF112233: 40}, remain) > LinkedFormPaint.uncoveredPixelCount({0xFF112233: 2}, remain), "");
			expect("old linkage stays out", LinkedFormPaint.linkageKeptForUniqueScan("Kirby_OldIdle") == false && LinkedFormPaint.linkageKeptForUniqueScan("kirby_idle") == true, "");
			expect("tall sprite matches row height", Math.abs(LinkedFormPaint.stripHeightScale(200, 1, 48) - 0.24) < 0.001 && LinkedFormPaint.stripHeightScale(20, 1, 48) == 1, "");
			var seenColors:Object = {};
			seenColors[uint(0xFF112233)] = true;
			expect("new linkage color counts", LinkedFormPaint.newColorPixels({0xFF112233: 8, 0xFF778899: 20}, seenColors) == 20, "");
			var sheet:BitmapData = new BitmapData(4, 4, true, 0xFFFF0000);
			sheet.setPixel32(1, 0, 0xFF00FF00);
			var sampled:Object = LinkedFormPaint.sampleOpaqueColors(sheet, 4);
			var kept:Array = sampled.colors as Array;
			var speckKept:Boolean = false;
			var solidKept:Boolean = false;
			var sampleColor:uint;
			for each (sampleColor in kept)
			{
				if (uint(sampleColor) == 0xFFFF0000)
				{
					solidKept = true;
				};
				if (uint(sampleColor) == 0xFF00FF00)
				{
					speckKept = true;
				};
			};
			expect("stride keeps the solid color", solidKept && int(sampled.counts[uint(0xFFFF0000)]) >= 2, String(kept.length));
			expect("stride drops the speck", speckKept == false, "");
			sheet.dispose();
			var full:BitmapData = new BitmapData(8, 1, true, 0x00000000);
			full.setPixel32(1, 0, 0xFFD70000);
			full.setPixel32(2, 0, 0xFFD70000);
			var fullSample:Object = LinkedFormPaint.sampleOpaqueColors(full, 1);
			var fullKept:Array = fullSample.colors as Array;
			var lipstickKept:Boolean = false;
			for each (sampleColor in fullKept)
			{
				if (uint(sampleColor) == 0xFFD70000)
				{
					lipstickKept = true;
				};
			};
			expect("full read keeps a two pixel mark", lipstickKept && int(fullSample.counts[uint(0xFFD70000)]) == 2, String(fullKept.length));
			full.dispose();
			var onePx:BitmapData = new BitmapData(1, 1, true, 0xFF00649F);
			var oneSample:Object = LinkedFormPaint.sampleOpaqueColors(onePx, 1);
			var oneKept:Array = oneSample.colors as Array;
			var tearKept:Boolean = false;
			for each (sampleColor in oneKept)
			{
				if (uint(sampleColor) == 0xFF00649F)
				{
					tearKept = true;
				};
			};
			expect("one pixel stays", tearKept && int(oneSample.counts[uint(0xFF00649F)]) == 1, String(oneKept.length));
			onePx.dispose();
			expect("twice as wide stays off the strip", LinkedFormPaint.spriteTooBigForStrip(201, 74) == true && LinkedFormPaint.spriteTooBigForStrip(71, 74) == false, "");
			expect("median side", LinkedFormPaint.medianSide([10, 40, 20]) == 20, "");
			expect("grey band stays", LinkedFormPaint.neutralBand(0xFF888888) >= 0 && LinkedFormPaint.neutralBand(0xFFFF0000) == -1 && LinkedFormPaint.keepUniqueSampleColor(1, 1, false) == true && LinkedFormPaint.keepUniqueSampleColor(0, 1, false) == false, "");
			expect("final frames stay apart", LinkedFormPaint.uniqueScanRoot("luffy_final15") == "luffy_final15" && LinkedFormPaint.uniqueScanRoot("luffy_final0") == "luffy_final0", "");
			expect("numbered prop still folds", LinkedFormPaint.uniqueScanRoot("lloyd_sword2") == "lloyd_sword" && LinkedFormPaint.uniqueScanRoot("lloyd_sword3") == "lloyd_sword", "");
			expect("bowser home is final destination", StudioHomeStages.homeStageFor("bowser") == "finaldestination" && StudioHomeStages.homeSongFor("bowser") == "bgm_bowserscastle", StudioHomeStages.homeStageFor("bowser"));
			expect("giga spawns as bowser", LinkedFormPaint.spawnStatsName("gigabowser") == "bowser", LinkedFormPaint.spawnStatsName("gigabowser"));
			expect("giga home matches bowser", StudioHomeStages.homeStageFor("gigabowser") == "finaldestination" && StudioHomeStages.homeSongFor("gigabowser") == "bgm_bowserscastle", StudioHomeStages.homeStageFor("gigabowser"));
			var formCover:Array = LinkedFormPaint.filterCoverToForm([
				{ "linkage": "bowser_idle" },
				{ "linkage": "gbow_idle" },
				{ "linkage": "giga_bowser_punch" },
				{ "linkage": "flame" }
			], "gigabowser");
			expect("unique strip is one form", formCover.length == 2 && !coverHasLinkage(formCover, "bowser_idle") && !coverHasLinkage(formCover, "flame"), String(formCover.length));
			var zeldaCover:Array = LinkedFormPaint.filterCoverToForm([
				{ "linkage": "zelda_idle" },
				{ "linkage": "sheik_idle" },
				{ "linkage": "hammer" }
			], "zelda");
			expect("unprefixed prop stays on the opened form", zeldaCover.length == 2 && coverHasLinkage(zeldaCover, "hammer") && !coverHasLinkage(zeldaCover, "sheik_idle"), String(zeldaCover.length));
			var kirbyCover:Array = LinkedFormPaint.filterCoverToForm([
				{ "linkage": "hammer" },
				{ "linkage": "kirby_idle" }
			], "kirby");
			expect("kirby keeps an unprefixed prop", kirbyCover.length == 2, String(kirbyCover.length));
			var strip:Array = LinkedFormPaint.selectUniqueStrip([
				{ "linkage": "kirby_hammer", "colors": [0xFFFF0000], "fingerprint": "hammer" },
				{ "linkage": "star", "colors": [0xFFFF0000], "fingerprint": "star" },
				{ "linkage": "spark", "colors": [0xFFFF0000], "fingerprint": "spark" },
				{ "linkage": "kirby_gem", "colors": [0xFFFF0000, 0xFF00FF00], "fingerprint": "gem" },
				{ "linkage": "kirby_gem2", "colors": [0xFF00FF00], "fingerprint": "gem" }
			]);
			expect("one sprite represents a repeated color", strip.length == 1 && coverHasLinkage(strip, "kirby_gem") && !coverHasLinkage(strip, "kirby_hammer") && !coverHasLinkage(strip, "star") && !coverHasLinkage(strip, "spark"), String(strip.length));
			var reps:Array = LinkedFormPaint.selectUniqueStrip([
				{ "linkage": "body", "colors": [0xFFFF0000], "fingerprint": "body" },
				{ "linkage": "spark", "colors": [0xFFFF0000], "fingerprint": "spark" },
				{ "linkage": "gem", "colors": [0xFF00FF00], "fingerprint": "gem" }
			]);
			expect("each new color gets one representative", reps.length == 2 && coverHasLinkage(reps, "body") && coverHasLinkage(reps, "gem") && !coverHasLinkage(reps, "spark"), String(reps.length));
			var rock:Array = LinkedFormPaint.selectUniqueStrip([
				{ "linkage": "kirby_rock1", "colors": [0xFF000001, 0xFF000002], "fingerprint": "rock1" },
				{ "linkage": "kirby_rock4", "colors": [0xFF000001, 0xFF000002, 0xFF000003], "fingerprint": "rock4" }
			]);
			expect("later sprite replaces the earlier subset", rock.length == 1 && coverHasLinkage(rock, "kirby_rock4"), String(rock.length));
			var spread:Array = LinkedFormPaint.selectUniqueStrip([
				{ "linkage": "a", "colors": [0xFF000001, 0xFF000002], "fingerprint": "a" },
				{ "linkage": "b", "colors": [0xFF000001, 0xFF000003], "fingerprint": "b" },
				{ "linkage": "c", "colors": [0xFF000002, 0xFF000004], "fingerprint": "c" }
			]);
			expect("spread colors drop the sprite with none of its own", spread.length == 2 && coverHasLinkage(spread, "b") && coverHasLinkage(spread, "c") && !coverHasLinkage(spread, "a"), String(spread.length));
			var paStrip:Array = LinkedFormPaint.selectUniqueStrip([
				{ "linkage": "only_pa", "colors": [0xFFFF0000], "fingerprint": "only-pa" },
				{ "linkage": "extra", "colors": [0xFFFF0000, 0xFF00FF00], "fingerprint": "extra" }
			], [0xFFFF0000]);
			expect("portrait color does not earn a sprite", paStrip.length == 1 && coverHasLinkage(paStrip, "extra") && !coverHasLinkage(paStrip, "only_pa"), String(paStrip.length));
			var letters:Array = LinkedFormPaint.selectUniqueStrip([
				{ "linkage": "a", "colors": [0xFF00000A, 0xFF00000B, 0xFF00000C, 0xFF00000D, 0xFF00000E], "fingerprint": "a" },
				{ "linkage": "b", "colors": [0xFF00000A, 0xFF00000B, 0xFF00000D, 0xFF00000C, 0xFF00000E, 0xFF000015, 0xFF000016, 0xFF000017], "fingerprint": "b" },
				{ "linkage": "c", "colors": [0xFF000006, 0xFF000007, 0xFF000010, 0xFF000011, 0xFF000012, 0xFF000015, 0xFF000016, 0xFF000017, 0xFF000018], "fingerprint": "c" }
			]);
			expect("sprite with no letter of its own drops", letters.length == 2 && coverHasLinkage(letters, "a") && coverHasLinkage(letters, "c") && !coverHasLinkage(letters, "b"), String(letters.length));
			var owned:Array = LinkedFormPaint.ownedColorsForStrip([
				{ "colors": [0xFF00000A, 0xFF00000B, 0xFF00000C] },
				{ "colors": [0xFF00000A, 0xFF00000D] },
				{ "colors": [0xFF00000B, 0xFF00000E] }
			]);
			expect("first sprite keeps a shared color", owned.length == 3 && (owned[0] as Array).length == 3 && uint((owned[0] as Array)[0]) == 0xFF00000A && (owned[1] as Array).length == 1 && uint((owned[1] as Array)[0]) == 0xFF00000D && (owned[2] as Array).length == 1 && uint((owned[2] as Array)[0]) == 0xFF00000E, String((owned[0] as Array).length));
			var plantOwned:Array = LinkedFormPaint.ownedColorsForStrip([
				{ "colors": [0xFFFF5353, 0xFFFF90B0] },
				{ "colors": [0xFFFF5353, 0xFF75B957] },
				{ "colors": [0xFFFF5353, 0xFF0B0705] }
			]);
			var plantHasRed:Boolean = false;
			var laterHasRed:Boolean = false;
			var plantColor:uint;
			for each (plantColor in (plantOwned[0] as Array))
			{
				if (uint(plantColor) == 0xFFFF5353)
				{
					plantHasRed = true;
				};
			};
			for each (plantColor in (plantOwned[1] as Array))
			{
				if (uint(plantColor) == 0xFFFF5353)
				{
					laterHasRed = true;
				};
			};
			for each (plantColor in (plantOwned[2] as Array))
			{
				if (uint(plantColor) == 0xFFFF5353)
				{
					laterHasRed = true;
				};
			};
			expect("shared red stays on the first sprite", plantHasRed && laterHasRed == false && (plantOwned[1] as Array).length == 1 && (plantOwned[2] as Array).length == 1, "");
			var paPink:Array = LinkedFormPaint.selectUniqueStrip([
				{ "linkage": "dress", "colors": [0xFFFF99BF], "fingerprint": "pink" },
				{ "linkage": "extra", "colors": [0xFFFF99BF, 0xFF102030], "fingerprint": "extra-pink" }
			], [0xFFFF99BF]);
			var ownedPink:Array = LinkedFormPaint.ownedColorsForStrip(paPink, [0xFFFF99BF]);
			expect("portrait pink does not keep a sprite", paPink.length == 1 && coverHasLinkage(paPink, "extra") && !coverHasLinkage(paPink, "dress"), String(paPink.length));
			expect("portrait pink is not the owned color", ownedPink.length == 1 && (ownedPink[0] as Array).length == 1 && uint((ownedPink[0] as Array)[0]) == 0xFF102030, String((ownedPink[0] as Array).length));
			var ownedRed:Array = LinkedFormPaint.ownedColorsForStrip([
				{ "colors": [0xFFEA2123, 0xFF000001] },
				{ "colors": [0xFF000002] }
			], []);
			expect("swatch red stays owned", ownedRed.length == 2 && (ownedRed[0] as Array).length == 2 && uint((ownedRed[0] as Array)[0]) == 0xFFEA2123, String((ownedRed[0] as Array).length));
			var redBd:BitmapData = new BitmapData(2, 1, true, 0xFFEA2123);
			var redShown:BitmapData;
			redBd.setPixel32(1, 0, 0xFF112233);
			redShown = redBd.clone();
			LinkedFormPaint.darkenExceptColors(redShown, redBd, [0xFFEA2123]);
			expect("ctrl q keeps EA2123", redShown.getPixel32(0, 0) == 0xFFEA2123, redShown.getPixel32(0, 0).toString(16));
			var blankBd:BitmapData = new BitmapData(1, 1, true, 0xFF00FF00);
			var blankShown:BitmapData = blankBd.clone();
			LinkedFormPaint.darkenExceptColors(blankShown, blankBd, []);
			expect("empty owned list does not darken", blankShown.getPixel32(0, 0) == 0xFF00FF00, blankShown.getPixel32(0, 0).toString(16));
			redBd.dispose();
			redShown.dispose();
			blankBd.dispose();
			blankShown.dispose();
			var hi:BitmapData = new BitmapData(2, 1, true, 0xFFFF0000);
			hi.setPixel32(1, 0, 0xFF00FF00);
			var shown:BitmapData = hi.clone();
			LinkedFormPaint.darkenExceptColors(shown, hi, [0xFFFF0000]);
			expect("ctrl q keeps the owned pixel", shown.getPixel32(0, 0) == 0xFFFF0000 && ((shown.getPixel32(1, 0) >> 8) & 0xFF) >= 240, shown.getPixel32(1, 0).toString(16));
			hi.dispose();
			shown.dispose();
			var near:BitmapData = new BitmapData(2, 1, true, 0xFFFF0000);
			near.setPixel32(1, 0, 0xFFFE0000);
			var nearShown:BitmapData = near.clone();
			LinkedFormPaint.darkenExceptColors(nearShown, near, [0xFFFF0000]);
			expect("ctrl q keeps a shade next to the owned color", nearShown.getPixel32(0, 0) == 0xFFFF0000 && nearShown.getPixel32(1, 0) == 0xFFFE0000, nearShown.getPixel32(1, 0).toString(16));
			near.dispose();
			nearShown.dispose();
			expect("hover hex is six digits", LinkedFormPaint.hexLabel(0xFF00000C) == "#00000C", LinkedFormPaint.hexLabel(0xFF00000C));
			var ringBd:BitmapData = new BitmapData(48, 48, true, 0xFF0000FF);
			var ringSrc:BitmapData;
			ringBd.setPixel32(24, 24, 0xFFFF0000);
			ringSrc = ringBd.clone();
			LinkedFormPaint.darkenExceptColors(ringBd, ringSrc, [0xFFFF0000]);
			var ringReds:int = 0;
			var rx:int = 0;
			var ry:int = 0;
			var rp:uint;
			while (ry < 48)
			{
				rx = 0;
				while (rx < 48)
				{
					rp = ringBd.getPixel32(rx, ry);
					if (rp == 0xFFFF0000 && !(rx == 24 && ry == 24))
					{
						ringReds++;
					};
					rx++;
				};
				ry++;
			};
			expect("ctrl q draws a red ring", ringBd.getPixel32(24, 24) == 0xFFFF0000 && ringReds > 8 && ringBd.getPixel32(24, 12) != 0xFFFF0000 && (ringBd.getPixel32(0, 0) & 0xFF) >= 240, String(ringReds));
			expect("portrait waits for idle", LinkedFormPaint.portraitHoldReady(false, 0, 0, 8) == false && LinkedFormPaint.portraitHoldReady(true, 0, 0, 7) == false && LinkedFormPaint.portraitHoldReady(true, 0, 0, 8) == true, "");
			var lightBd:BitmapData = new BitmapData(2, 1, true, 0xFFFFFFFF);
			var lightShown:BitmapData;
			lightBd.setPixel32(1, 0, 0xFF00FF00);
			lightShown = lightBd.clone();
			LinkedFormPaint.darkenExceptColors(lightShown, lightBd, [0xFFFFFFFF]);
			expect("light owned color darkens the rest", lightShown.getPixel32(0, 0) == 0xFFFFFFFF && ((lightShown.getPixel32(1, 0) >> 8) & 0xFF) <= 8, lightShown.getPixel32(1, 0).toString(16));
			expect("dark owned color washes toward white", LinkedFormPaint.washOwnedTowardWhite([0xFFFF0000]) && !LinkedFormPaint.washOwnedTowardWhite([0xFFFFFFFF]), "");
			var hoverBright:BitmapData = new BitmapData(2, 1, true, 0xFFFF0000);
			var hoverDest:BitmapData = new BitmapData(2, 1, true, 0);
			var hoverGreen:uint;
			hoverBright.setPixel32(1, 0, 0xFF00FF00);
			HoverDim.paint(hoverDest, hoverBright, 0xFF0000, 0xFF0000, true);
			hoverGreen = hoverDest.getPixel32(1, 0);
			expect("hover keeps the swatch", hoverDest.getPixel32(0, 0) == 0xFFFF0000, hoverDest.getPixel32(0, 0).toString(16));
			expect("hover dims the other color", (hoverGreen & 0xFF00) > 0 && (hoverGreen & 0xFF00) < 0x4000 && (hoverGreen >>> 24) == 0xFF, hoverGreen.toString(16));
			hoverBright.dispose();
			hoverDest.dispose();
			lightBd.dispose();
			lightShown.dispose();
			ringSrc.dispose();
			ringBd.dispose();
		}

		private function coverHasLinkage(cover:Array, linkage:String):Boolean
		{
			var cand:Object;
			if (!cover)
			{
				return false;
			};
			for each (cand in cover)
			{
				if (cand && String(cand.linkage) == linkage)
				{
					return true;
				};
			};
			return false;
		}

		private function expect(name:String, ok:Boolean, why:String):void
		{
			if (ok)
			{
				m_lines.push("OK " + name);
			}
			else
			{
				fail(name, why);
			};
		}

		private function fail(name:String, why:String):void
		{
			m_failed = true;
			m_lines.push("FAIL " + name + ": " + why);
		}
	}
}

class LinkageIdProbe
{
	public function get LinkageID():String
	{
		throw new Error("1065");
	}

	public function get LinkageID2():String
	{
		return "sonic_2";
	}

	public function get LinkageIDSpecial():String
	{
		return "sonic_s";
	}
}
