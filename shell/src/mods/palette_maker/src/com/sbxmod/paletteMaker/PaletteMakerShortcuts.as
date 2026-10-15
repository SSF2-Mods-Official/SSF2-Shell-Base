package com.sbxmod.paletteMaker
{
	import flash.events.KeyboardEvent;
	import flash.ui.Keyboard;

	/**
	 * Ctrl(+Shift) bindings for Palette Maker tools / save.
	 * Bare keys are never used so playtest controls stay free.
	 */
	public class PaletteMakerShortcuts
	{
		/** Each entry: { keys:String, toolId:String, action:String, label:String } */
		private static var s_bindings:Array = null;

		public static function getBindings():Array
		{
			ensureBuilt();
			return s_bindings;
		}

		/**
		 * Resolve a KEY_DOWN event to an action.
		 * Returns { toolId:String } or { save:true } or null.
		 */
		public static function resolve(e:KeyboardEvent):Object
		{
			var code:uint;
			var shift:Boolean;
			if (!e || !e.ctrlKey)
			{
				return null;
			};
			code = e.keyCode;
			shift = e.shiftKey;
			if (code == Keyboard.Z && !shift)
			{
				return { "toolId": "UD" };
			};
			if (code == Keyboard.Y && !shift)
			{
				return { "toolId": "RD" };
			};
			// keyCode S, or charCode for layout quirks / numpad-less boards
			if (!shift && (code == Keyboard.S || code == 83
				|| e.charCode == 83 || e.charCode == 115))
			{
				return { "save": true };
			};
			if (code == Keyboard.COMMA && !shift)
			{
				return { "toolId": "ST" };
			};
			if (code == Keyboard.I)
			{
				return shift ? { "toolId": "IC" } : { "toolId": "IS" };
			};
			if (code == Keyboard.E && shift)
			{
				return { "toolId": "EC" };
			};
			if (shift)
			{
				return null;
			};
			if (code == Keyboard.L)
			{
				return { "toolId": "DI" };
			};
			if (code == Keyboard.F)
			{
				return { "toolId": "FZ" };
			};
			if (code == Keyboard.A)
			{
				return { "toolId": "SA" };
			};
			if (code == Keyboard.D)
			{
				return { "toolId": "DA" };
			};
			if (code == Keyboard.R)
			{
				return { "toolId": "RA" };
			};
			if (code == Keyboard.B)
			{
				return { "toolId": "RB" };
			};
			if (code == Keyboard.O)
			{
				return { "toolId": "RO" };
			};
			if (code == Keyboard.G)
			{
				return { "toolId": "NG" };
			};
			if (code == Keyboard.K)
			{
				return { "toolId": "CS" };
			};
			return null;
		}

		private static function ensureBuilt():void
		{
			if (s_bindings)
			{
				return;
			};
			s_bindings = [
				{ "keys": "Ctrl+Z", "toolId": "UD", "action": "tool", "label": "Undo" },
				{ "keys": "Ctrl+Y", "toolId": "RD", "action": "tool", "label": "Redo" },
				{ "keys": "Ctrl+I", "toolId": "IS", "action": "tool", "label": "Invert Selection" },
				{ "keys": "Ctrl+L", "toolId": "DI", "action": "tool", "label": "Isolate Mode" },
				{ "keys": "Ctrl+F", "toolId": "FZ", "action": "tool", "label": "Freeze Character" },
				{ "keys": "Ctrl+A", "toolId": "SA", "action": "tool", "label": "Select All" },
				{ "keys": "Ctrl+D", "toolId": "DA", "action": "tool", "label": "Deselect All" },
				{ "keys": "Ctrl+R", "toolId": "RA", "action": "tool", "label": "Reset Active" },
				{ "keys": "Ctrl+B", "toolId": "RB", "action": "tool", "label": "Recolor to Base" },
				{ "keys": "Ctrl+O", "toolId": "RO", "action": "tool", "label": "Recolor to OG" },
				{ "keys": "Ctrl+G", "toolId": "NG", "action": "tool", "label": "New Group" },
				{ "keys": "Ctrl+K", "toolId": "CS", "action": "tool", "label": "Color Settings" },
				{ "keys": "Ctrl+,", "toolId": "ST", "action": "tool", "label": "Settings" },
				{ "keys": "Ctrl+Shift+I", "toolId": "IC", "action": "tool", "label": "Import Color Sheet(s)" },
				{ "keys": "Ctrl+Shift+E", "toolId": "EC", "action": "tool", "label": "Export Color Sheet" },
				{ "keys": "Ctrl+S", "toolId": "", "action": "save", "label": "Save costume" }
			];
		}
	}
}
