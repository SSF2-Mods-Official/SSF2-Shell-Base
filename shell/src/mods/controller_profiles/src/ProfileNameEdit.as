package
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.ui.Keyboard;

	/**
	 * New-nametag entry: live nameDisplay editing and the fallback add popup.
	 */
	public class ProfileNameEdit
	{
		private static const NAME_MAX:int = 15;
		private static const POPUP_MARK:String = "__ssf2mm_profiles_popup";

		internal var mod:ControllerProfilesMod;
		private var m_liveNameWasType:String;
		private var m_liveNameWasSelectable:Boolean;

		public function ProfileNameEdit(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		/** Abort Add new / live typing and restore Default (P1–P4 display). */
		internal function cancelNameEditToDefault():void
		{
			var pid:int;
			pid = mod.m_editPid > 0 ? mod.m_editPid : 1;
			if (mod.m_liveNameTxt)
			{
				endLiveNameEdit(false);
				return;
			};
			if (mod.m_addPopup && mod.m_addPopup.parent)
			{
				closeAddPopup();
				mod.m_tags.selectName(pid, ControllerProfilesMod.DEFAULT_TAG);
			};
		}

		/** Controls → popup on Controls. CSS → type into the existing P# nameTxt. Never stock keypad. */
		internal function startAdd(pid:int):void
		{
			mod.m_editPid = pid;
			hideStockKeypad(pid);
			if (mod.m_controls && mod.m_controls["isOnscreen"] && mod.m_controls["isOnscreen"]())
			{
				log("startAdd controls popup pid=" + pid);
				openAddPopup(pid);
				return;
			};
			log("startAdd live nameTxt pid=" + pid);
			startLiveNameEdit(pid);
		}

		internal function hideStockKeypad(pid:int):void
		{
			var display:*;
			var pad:*;
			display = ProfileCssHooks.findNameDisplay(mod.m_cssMenu, pid);
			try
			{
				pad = display ? display["nameKeyPad"] : null;
				if (pad)
				{
					pad.visible = false;
				};
			}
			catch (err:*)
			{
			};
		}

		private function startLiveNameEdit(pid:int):void
		{
			var display:*;
			var tf:TextField;
			var stage:*;
			endLiveNameEdit(false);
			mod.m_editPid = pid;
			display = ProfileCssHooks.findNameDisplay(mod.m_cssMenu, pid);
			tf = display ? display["nameTxt"] as TextField : null;
			if (!tf)
			{
				log("live nameTxt missing pid=" + pid + " — fallback popup");
				openAddPopup(pid);
				return;
			};
			hideStockKeypad(pid);
			mod.m_liveNameTxt = tf;
			m_liveNameWasType = tf.type;
			m_liveNameWasSelectable = tf.selectable;
			tf.type = TextFieldType.INPUT;
			tf.selectable = true;
			tf.maxChars = NAME_MAX;
			tf.text = "";
			tf.addEventListener(KeyboardEvent.KEY_DOWN, onLiveNameKey, false, 99);
			tf.addEventListener(Event.CHANGE, onLiveNameChange, false, 0);
			tf.addEventListener(FocusEvent.FOCUS_OUT, onLiveNameFocusOut, false, 0);
			mod.m_nameEditArmed = false;
			stage = ProfileUi.gameStage();
			if (stage)
			{
				stage.addEventListener(KeyboardEvent.KEY_DOWN, onLiveNameStageKey, true, 200);
				stage.addEventListener(KeyboardEvent.KEY_UP, onLiveNameStageKey, true, 200);
			};
			ProfileUi.focusField(tf);
			log("live nameTxt editing pid=" + pid);
		}

		private function onLiveNameFocusOut(e:Event):void
		{
			// Clicked away / lost focus without Enter → cancel to Default.
			if (!mod.m_liveNameTxt || !mod.m_nameEditArmed)
			{
				return;
			};
			cancelNameEditToDefault();
		}

		private function onLiveNameChange(e:Event):void
		{
			var tf:TextField;
			tf = mod.m_liveNameTxt;
			if (tf && tf.text && tf.text.length > NAME_MAX)
			{
				tf.text = tf.text.substr(0, NAME_MAX);
			};
			// nameTxt already updates live; keep stock keypad hidden while typing
			hideStockKeypad(mod.m_editPid);
		}

		private function onLiveNameStageKey(e:KeyboardEvent):void
		{
			if (!mod.m_liveNameTxt && !(mod.m_addPopup && mod.m_addPopup.parent))
			{
				return;
			};
			// Swallow before CSS/menu listeners; focused TextField already gets the character.
			if (e.keyCode == Keyboard.ENTER)
			{
				e.stopImmediatePropagation();
				e.stopPropagation();
				e.preventDefault();
				if (mod.m_liveNameTxt)
				{
					endLiveNameEdit(true);
				}
				else
				{
					onPopupOk(null);
				};
				return;
			};
			if (e.keyCode == Keyboard.ESCAPE)
			{
				e.stopImmediatePropagation();
				e.stopPropagation();
				e.preventDefault();
				if (mod.m_liveNameTxt)
				{
					endLiveNameEdit(false);
				}
				else
				{
					closeAddPopup();
					mod.m_tags.selectName(mod.m_editPid, ControllerProfilesMod.DEFAULT_TAG);
				};
				return;
			};
			e.stopPropagation();
		}

		private function onLiveNameKey(e:KeyboardEvent):void
		{
			e.stopPropagation();
			if (e.keyCode == Keyboard.ENTER)
			{
				e.stopImmediatePropagation();
				endLiveNameEdit(true);
			}
			else if (e.keyCode == Keyboard.ESCAPE)
			{
				e.stopImmediatePropagation();
				endLiveNameEdit(false);
			};
		}

		internal function endLiveNameEdit(commit:Boolean):void
		{
			var typed:String;
			var tf:TextField;
			var stage:*;
			var pid:int;
			tf = mod.m_liveNameTxt;
			if (!tf)
			{
				return;
			};
			pid = mod.m_editPid;
			tf.removeEventListener(KeyboardEvent.KEY_DOWN, onLiveNameKey);
			tf.removeEventListener(Event.CHANGE, onLiveNameChange);
			tf.removeEventListener(FocusEvent.FOCUS_OUT, onLiveNameFocusOut);
			stage = ProfileUi.gameStage();
			if (stage)
			{
				stage.removeEventListener(KeyboardEvent.KEY_DOWN, onLiveNameStageKey, true);
				stage.removeEventListener(KeyboardEvent.KEY_UP, onLiveNameStageKey, true);
			};
			typed = String(tf.text || "");
			typed = clampName(trimStr(typed));
			try
			{
				tf.type = m_liveNameWasType || TextFieldType.DYNAMIC;
				tf.selectable = m_liveNameWasSelectable;
			}
			catch (restErr:*)
			{
				log("endLiveNameEdit failed: " + restErr);
			};
			mod.m_liveNameTxt = null;
			mod.m_nameEditArmed = false;
			if (commit && typed.length > 0)
			{
				log("live name commit \"" + typed + "\" pid=" + pid);
				mod.m_tags.addName(typed, pid);
				mod.m_tags.selectName(pid, typed);
			}
			else
			{
				// Escape, or Enter with empty text → Default (P1/P2/P3/P4 display).
				log("live name default pid=" + pid + " commit=" + commit);
				mod.m_tags.selectName(pid, ControllerProfilesMod.DEFAULT_TAG);
			};
			mod.m_editPid = 0;
		}

		private function openAddPopup(pid:int):void
		{
			var box:Sprite;
			var ok:Sprite;
			var tf:TextField;
			var gw:Number;
			var gh:Number;
			var stage:*;
			closeAddPopup();
			mod.m_editPid = pid;
			box = new Sprite();
			box.name = POPUP_MARK;
			box.graphics.beginFill(0x111122, 0.96);
			box.graphics.drawRoundRect(0, 0, 280, 90, 8, 8);
			box.graphics.endFill();
			tf = ProfileUi.menuText("New nametag", 16, 0xFFFFFF);
			tf.x = 12;
			tf.y = 8;
			box.addChild(tf);
			mod.m_addField = new TextField();
			mod.m_addField.type = TextFieldType.INPUT;
			mod.m_addField.border = true;
			mod.m_addField.background = true;
			mod.m_addField.backgroundColor = 0xFFFFFF;
			mod.m_addField.textColor = 0x000000;
			mod.m_addField.maxChars = NAME_MAX;
			mod.m_addField.width = 180;
			mod.m_addField.height = 22;
			mod.m_addField.x = 12;
			mod.m_addField.y = 36;
			mod.m_addField.addEventListener(KeyboardEvent.KEY_DOWN, onPopupKey, false, 99);
			box.addChild(mod.m_addField);
			ok = new Sprite();
			ok.graphics.beginFill(0x6A3FA0, 1);
			ok.graphics.drawRoundRect(0, 0, 64, 24, 4, 4);
			ok.graphics.endFill();
			ok.x = 200;
			ok.y = 36;
			ok.buttonMode = true;
			tf = ProfileUi.menuText("OK", 14, 0xFFFFFF);
			tf.x = 18;
			tf.y = 3;
			ok.addChild(tf);
			ok.addEventListener(MouseEvent.CLICK, onPopupOk);
			box.addChild(ok);
			gw = ProfileUi.gameWidth();
			gh = ProfileUi.gameHeight();
			box.x = (gw - 280) * 0.5;
			box.y = (gh - 90) * 0.5;
			mod.m_addPopup = box;
			ProfileUi.rootAdd(box);
			mod.m_nameEditArmed = false;
			stage = ProfileUi.gameStage();
			if (stage)
			{
				stage.addEventListener(KeyboardEvent.KEY_DOWN, onLiveNameStageKey, true, 200);
				stage.addEventListener(KeyboardEvent.KEY_UP, onLiveNameStageKey, true, 200);
			};
			ProfileUi.focusField(mod.m_addField);
			log("add popup centered pid=" + pid + " at " + int(box.x) + "," + int(box.y)
				+ " game=" + int(gw) + "x" + int(gh));
		}

		private function onPopupKey(e:KeyboardEvent):void
		{
			e.stopPropagation();
			if (e.keyCode == Keyboard.ENTER)
			{
				e.stopImmediatePropagation();
				onPopupOk(null);
			}
			else if (e.keyCode == Keyboard.ESCAPE)
			{
				e.stopImmediatePropagation();
				closeAddPopup();
				mod.m_tags.selectName(mod.m_editPid, ControllerProfilesMod.DEFAULT_TAG);
			};
		}

		private function onPopupOk(e:MouseEvent):void
		{
			var typed:String;
			typed = mod.m_addField ? String(mod.m_addField.text || "") : "";
			typed = clampName(trimStr(typed));
			closeAddPopup();
			if (typed.length < 1)
			{
				return;
			};
			log("popup ok \"" + typed + "\" pid=" + mod.m_editPid);
			mod.m_tags.addName(typed, mod.m_editPid);
			mod.m_tags.selectName(mod.m_editPid, typed);
		}

		internal function closeAddPopup():void
		{
			var stage:*;
			if (mod.m_addField)
			{
				mod.m_addField.removeEventListener(KeyboardEvent.KEY_DOWN, onPopupKey);
			};
			if (mod.m_addPopup && mod.m_addPopup.parent)
			{
				mod.m_addPopup.parent.removeChild(mod.m_addPopup);
			};
			mod.m_addPopup = null;
			mod.m_addField = null;
			if (!mod.m_liveNameTxt)
			{
				stage = ProfileUi.gameStage();
				if (stage)
				{
					stage.removeEventListener(KeyboardEvent.KEY_DOWN, onLiveNameStageKey, true);
					stage.removeEventListener(KeyboardEvent.KEY_UP, onLiveNameStageKey, true);
				};
			};
		}

		internal static function trimStr(s:String):String
		{
			if (!s)
			{
				return ("");
			};
			return (s.replace(/^\s+|\s+$/g, ""));
		}

		internal static function clampName(s:String):String
		{
			if (!s)
			{
				return ("");
			};
			if (s.length > NAME_MAX)
			{
				return (s.substr(0, NAME_MAX));
			};
			return (s);
		}
	}
}
