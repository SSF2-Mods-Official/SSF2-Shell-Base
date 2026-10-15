package com.sbxmod.paletteMaker
{
    import ssf2mm.shared.HsvWheel;
    import flash.events.MouseEvent;
    import flash.events.Event;
	import flash.utils.getTimer;
    import flash.display.MovieClip;
    import flash.text.TextField;
    import flash.events.FocusEvent;
    import flash.geom.Rectangle;
    import flash.geom.Point;
    import flash.geom.ColorTransform;
    import flash.display.DisplayObject;
    import flash.display.Sprite;
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.LoaderInfo;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getQualifiedSuperclassName;
	import flash.utils.getDefinitionByName;
	import flash.net.SharedObject;
	import flash.system.ApplicationDomain;
	import flash.display.DisplayObjectContainer;
	import flash.events.UncaughtErrorEvent;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.utils.Dictionary;
	import flash.filesystem.File;
	import flash.net.FileFilter;
	import flash.events.KeyboardEvent;
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import com.mcleodgaming.ssf2.util.PaletteDeep;

    /** Color selection, slider apply, undo/redo history. Part of the PaletteMakerMenu chain. */
    public class PaletteMakerMenuSelection extends PaletteMakerMenuSwatches
    {
        public function PaletteMakerMenuSelection()
        {
            super();
        }

		protected var hoverBaseActive:Boolean = false;

		protected var paletteHoverBox:ColorSquare = null;

		protected var undoStack:Array = [];

		protected var redoStack:Array = [];

		protected var suppressHistory:Boolean = false;

		protected var selectionEntryReplacements:Object = {};

		protected var hueSliderTouched:Boolean = false;

		protected const UNDO_LIMIT:int = 1000;

		/** Cached base-color keys whose current replacement still matches the selected baseline. */
		protected var unchangedColorLookup:Object = {};

		protected var colorArrow:MovieClip;

		protected var colorBounds:MovieClip;

		protected var brightnessArrow:MovieClip;

		protected var brightnessBounds:MovieClip;

		protected var saturationArrow:MovieClip;

		protected var saturationBounds:MovieClip;

		protected var alphaArrow:MovieClip;

		protected var alphaBounds:MovieClip;

		/** Apply swatch RGB while preserving the current alpha slider value. */
		protected function applySwatchRgbKeepingAlpha(swatchColor:uint):uint
		{
			return adjustAlpha(uint(swatchColor) & 0x00FFFFFF, getCurrentAlphaLevel());
		}

		protected function clearPaletteHoverIsolate():void
		{
			if (paletteHoverBox)
			{
				paletteHoverBox.setPaletteHoverHighlight(false);
			};
			paletteHoverBox = null;
			hoverBaseActive = false;
		}

		protected function captureSelectedColorSet():Object
		{
			var result:Object = {};
			var box:ColorSquare;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (box && !(box is PaletteGroupSquare))
				{
					result[uint(box.colorValue)] = true;
				};
			};
			return result;
		}

		protected function colorIsCurrentlySelected(baseColor:uint):Boolean
		{
			var box:ColorSquare;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (box && !(box is PaletteGroupSquare) && PaletteColorAnalysis.colorsMatch(uint(box.colorValue), baseColor))
				{
					return true;
				};
			};
			return false;
		}

		/** True when selection-set object (from captureSelectedColorSet) contains baseColor. */
		protected function colorInSelectionSet(colorSet:Object, baseColor:uint):Boolean
		{
			var key:String;
			if (!colorSet)
			{
				return false;
			};
			if (colorSet[baseColor] || colorSet[String(baseColor)])
			{
				return true;
			};
			for (key in colorSet)
			{
				if (PaletteColorAnalysis.colorsMatch(uint(key), baseColor))
				{
					return true;
				};
			};
			return false;
		}

		protected function countKeys(obj:Object):int
		{
			var n:int = 0;
			var key:String;
			if (!obj)
			{
				return 0;
			};
			for (key in obj)
			{
				n++;
			};
			return n;
		}

		protected function clearSelectionEntryReplacements():void
		{
			selectionEntryReplacements = {};
		}

		protected function clearSelectionEntriesFor(colorSet:Object):void
		{
			var key:String;
			if (!colorSet)
			{
				return;
			};
			for (key in colorSet)
			{
				delete selectionEntryReplacements[String(uint(key))];
			};
		}

		protected function hasAnyKey(obj:Object):Boolean
		{
			var key:String;
			if (!obj)
			{
				return false;
			};
			for (key in obj)
			{
				return true;
			};
			return false;
		}

		protected function resetSlidersToDefault():void
		{
			hueSliderTouched = false;
			if (brightnessArrow && brightnessBounds)
			{
				brightnessArrow.x = brightnessBounds.x + (brightnessBounds.width * 0.5);
			};
			if (saturationArrow && saturationBounds)
			{
				saturationArrow.x = saturationBounds.x + (saturationBounds.width * 0.5);
			};
			if (alphaArrow && alphaBounds)
			{
				alphaArrow.x = alphaBounds.x + alphaBounds.width;
			};
			try
			{
				TextField(m_subMenu.brightness.lvl_txt).text = "1.00";
				TextField(m_subMenu.saturation.lvl_txt).text = "1.00";
				TextField(m_subMenu._alpha.lvl_txt).text = "1.00";
			}
			catch (err:Error)
			{
			};
		}

		protected function getCurrentHueFactor():Number
		{
			var relativeX:Number = colorArrow.x - colorBounds.x;
			var colorRatio:Number = relativeX / colorBounds.width;
			return getColorAtRatio(colorRatio);
		}

		protected function getCurrentBrightnessLevel():Number
		{
			var relativeX:Number = brightnessArrow.x - brightnessBounds.x;
			var percent:Number = relativeX / brightnessBounds.width;
			return Math.max(0, Math.min(2, percent * 2));
		}

		protected function getCurrentSaturationLevel():Number
		{
			var relativeX:Number = saturationArrow.x - saturationBounds.x;
			var percent:Number = relativeX / saturationBounds.width;
			return Math.max(0, Math.min(2, percent * 2));
		}

		protected function getCurrentAlphaLevel():Number
		{
			var relativeX:Number = alphaArrow.x - alphaBounds.x;
			var percent:Number = relativeX / alphaBounds.width;
			return Math.max(0, Math.min(1, percent));
		}

		protected function clearHistory():void
		{
			undoStack = [];
			redoStack = [];
		}

		protected function captureSnapshot():Object
		{
			var selectedColors:Array = [];
			var box:ColorSquare;
			for each (box in ColorSquare.selectedBoxes)
			{
				if (box)
				{
					selectedColors.push(uint(box.colorValue));
				};
			};
			return {
				"paletteSwap": Ssf2.Utils.cloneObject(currentPaletteData.paletteSwap),
				"paletteSwapPA": Ssf2.Utils.cloneObject(currentPaletteData.paletteSwapPA),
				"selectedColors": selectedColors
			};
		}

		protected function pushUndoSnapshot():void
		{
			if (suppressHistory || !currentPaletteData)
			{
				return;
			};
			undoStack.push(captureSnapshot());
			if (undoStack.length > UNDO_LIMIT)
			{
				undoStack.shift();
			};
			redoStack.length = 0;
		}

		/**
		 * True when the color's current replacement matches its baseline.
		 * settingUnchangedVsOriginal: compare against the original palette color;
		 * otherwise compare against the loaded costume's replacement.
		 */
		protected function isReplacementUnchanged(baseColor:uint):Boolean
		{
			return unchangedColorLookup && unchangedColorLookup[String(baseColor)];
		}
    }
}
