package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.InteractiveObject;
	import flash.display.Sprite;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	import ssf2mm.shared.EngineRefs;

	/**
	 * The in-menu edit chrome: the Edit / Sort / Add / Remove / Restore / Confirm bar, where it
	 * sits on the menu header, and which menu pieces hide while editing.
	 */
	public class CssEditChrome
	{
		private static const BTN_W:int = 108;
		private static const EDIT_H:int = 24;
		private static const EDIT_X:int = 151;
		private static const EDIT_Y:int = -168;

		private var mod:CssEditorMod;
		private var m_editSlot:Rectangle;
		private var m_hideSnap:Dictionary;
		private var m_handSnap:Dictionary;

		public function CssEditChrome(owner:CssEditorMod)
		{
			mod = owner;
			m_hideSnap = new Dictionary(true);
			m_handSnap = new Dictionary(true);
		}

		internal function isCssOnscreen():Boolean
		{
			var MC:Class;
			var menu:*;
			try
			{
				MC = EngineRefs.MenuController as Class;
				menu = MC["CurrentCharacterSelectMenu"];
				return (menu && menu.isOnscreen());
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function ensureEditChrome():void
		{
			var parent:DisplayObjectContainer;
			try
			{
				parent = chromeParent();
				if (!parent)
				{
					mod.cssLog("chrome no parent");
					return;
				};
				if (!mod.m_editBtn)
				{
					mod.m_editBtn = makeBarButton("Edit", mod.m_input.onEditClick, CssEditorMod.EDIT_W, EDIT_H);
					mod.m_sortBtn = makeBarButton("Sort", mod.m_input.onSortClick, BTN_W, CssEditorMod.BTN_H);
					mod.m_addBtn = makeBarButton("Add", mod.m_input.onAddClick, BTN_W, CssEditorMod.BTN_H);
					mod.m_removeBtn = makeBarButton("Remove", mod.m_input.onRemoveClick, BTN_W, CssEditorMod.BTN_H);
					mod.m_restoreBtn = makeBarButton("Restore", mod.m_input.onRestoreClick, BTN_W, CssEditorMod.BTN_H);
					mod.m_confirmBtn = makeBarButton("Confirm", mod.m_input.onConfirmClick, BTN_W, CssEditorMod.BTN_H);
					mod.m_removeAllBtn = makeBarButton("Remove All", mod.m_input.onRemoveAllClick, BTN_W, CssEditorMod.BTN_H);
				};
				attachBar(parent, mod.m_editBtn);
				attachBar(parent, mod.m_sortBtn);
				attachBar(parent, mod.m_addBtn);
				attachBar(parent, mod.m_removeBtn);
				attachBar(parent, mod.m_restoreBtn);
				attachBar(parent, mod.m_confirmBtn);
				attachBar(parent, mod.m_removeAllBtn);
				if (mod.m_addPopup)
				{
					mod.m_addPopup.name = "cssChrome";
					attachBar(parent, mod.m_addPopup);
				};
				layoutBar();
				raiseEditChrome();
			}
			catch (err:*)
			{
				mod.cssLog("chrome error " + err);
			};
		}

		internal function liveCssMenu():*
		{
			var sub:DisplayObjectContainer;
			sub = cssSubMenu();
			if (mod.m_menu && sub && sub.stage)
			{
				return (mod.m_menu);
			};
			return (null);
		}

		private function gameRoot():DisplayObjectContainer
		{
			var MainCls:*;
			var root:DisplayObjectContainer;
			try
			{
				MainCls = EngineRefs.Main;
				root = MainCls ? (MainCls["Root"] as DisplayObjectContainer) : null;
			}
			catch (err:*)
			{
				root = null;
			};
			return (root);
		}

		internal function chromeParent():DisplayObjectContainer
		{
			var root:DisplayObjectContainer;
			var sub:DisplayObjectContainer;
			sub = cssSubMenu();
			if (sub)
			{
				return (sub);
			};
			root = gameRoot();
			if (root)
			{
				return (root);
			};
			if (mod.m_host && mod.m_host.stage)
			{
				return (mod.m_host.stage);
			};
			return (null);
		}

		internal function chromeLocal(x:Number, y:Number):Point
		{
			var sub:DisplayObjectContainer;
			var parent:DisplayObjectContainer;
			var pt:Point;
			sub = cssSubMenu();
			parent = mod.m_editBtn ? (mod.m_editBtn.parent as DisplayObjectContainer) : chromeParent();
			pt = new Point(x, y);
			if (sub && parent && parent != sub)
			{
				try
				{
					return (parent.globalToLocal(sub.localToGlobal(pt)));
				}
				catch (err:*)
				{
				};
			};
			return (pt);
		}

		private function cssSubMenu():DisplayObjectContainer
		{
			var sub:*;
			if (!mod.m_menu)
			{
				return (null);
			};
			try
			{
				sub = mod.m_menu["SubMenu"] || mod.m_menu["m_subMenu"] || mod.m_menu["subMenu"];
			}
			catch (err:*)
			{
				sub = null;
			};
			return (sub as DisplayObjectContainer);
		}

		private function attachBar(parent:DisplayObjectContainer, btn:Sprite):void
		{
			if (btn && parent && btn.parent != parent)
			{
				parent.addChild(btn);
			};
			if (btn && parent && btn.parent == parent)
			{
				parent.setChildIndex(btn, parent.numChildren - 1);
			};
		}

		internal function raiseEditChrome():void
		{
			var parent:DisplayObjectContainer;
			parent = chromeParent();
			if (!parent)
			{
				return;
			};
			attachBar(parent, mod.m_sortBtn);
			attachBar(parent, mod.m_addBtn);
			attachBar(parent, mod.m_removeBtn);
			attachBar(parent, mod.m_restoreBtn);
			attachBar(parent, mod.m_confirmBtn);
			attachBar(parent, mod.m_removeAllBtn);
			attachBar(parent, mod.m_editBtn);
			if (mod.m_addPopup && mod.m_addPopup.visible)
			{
				attachBar(parent, mod.m_addPopup);
			};
		}

		internal function hideEditChrome():void
		{
			var btns:Array;
			var i:int;
			btns = [mod.m_editBtn, mod.m_sortBtn, mod.m_addBtn, mod.m_removeBtn, mod.m_restoreBtn, mod.m_confirmBtn, mod.m_removeAllBtn];
			i = 0;
			while (i < btns.length)
			{
				if (btns[i])
				{
					btns[i].visible = false;
				};
				i++;
			};
			mod.m_addUi.closeAddPopup();
		}

		internal function navPlace():String
		{
			var prev:DisplayObject;
			var next:DisplayObject;
			prev = mod.m_pageClips ? (mod.m_pageClips[CssEditorMod.PAGE_PREV] as DisplayObject) : null;
			next = mod.m_pageClips ? (mod.m_pageClips[CssEditorMod.PAGE_NEXT] as DisplayObject) : null;
			return ("prev=" + navSpot(prev) + " next=" + navSpot(next));
		}

		private function navSpot(clip:DisplayObject):String
		{
			var box:Rectangle;
			if (!clip || !clip.visible)
			{
				return ("hide");
			};
			box = clip.getBounds(clip);
			return (int(clip.x) + "," + int(clip.y) + " box=" + int(box.x) + "," + int(box.y) + "," + int(box.width) + "," + int(box.height));
		}

		internal function iconSpot():String
		{
			var i:int;
			var child:DisplayObject;
			if (!mod.m_icons)
			{
				return ("none");
			};
			i = 0;
			while (i < mod.m_icons.numChildren)
			{
				child = mod.m_icons.getChildAt(i);
				if (child && child.visible && child.x > -1000 && !mod.m_paging.isPageNav(child.name))
				{
					return (navSpot(child));
				};
				i++;
			};
			return ("none");
		}

		internal function layoutBar():void
		{
			var sub:DisplayObjectContainer;
			var size:Object;
			var left:Number;
			var bottom:Number;
			var y:Number;
			var x:Number;
			var removing:Boolean;
			var where:String;
			var anchor:Point;
			if (!mod.m_editBtn)
			{
				return;
			};
			sub = cssSubMenu();
			size = cssGameSize();
			anchor = headerAnchor(mod.m_editBtn.parent as DisplayObjectContainer);
			if (sub && mod.m_editBtn.parent == sub)
			{
				left = -size.w * 0.5 + 12;
				bottom = size.h * 0.5 - EDIT_H - 16;
				where = "submenu";
			}
			else if (mod.m_editBtn.parent == gameRoot() || (mod.m_host && mod.m_host.stage && mod.m_editBtn.parent == mod.m_host.stage))
			{
				left = 8;
				bottom = anchor ? (anchor.y + 40) : 64;
				if (bottom > size.h - EDIT_H - 48)
				{
					bottom = size.h - EDIT_H - 48;
				};
				if (bottom < 8)
				{
					bottom = 8;
				};
				where = (mod.m_editBtn.parent == gameRoot()) ? "root" : "stage";
			}
			else
			{
				return;
			};
			EditBar.setLabel(mod.m_editBtn, mod.m_editing ? "Done" : "Edit");
			if (where == "submenu")
			{
				placeBar(mod.m_editBtn, EDIT_X, EDIT_Y, true, 1);
			}
			else
			{
				placeBar(mod.m_editBtn, left, bottom, true, 1);
			};
			removing = mod.m_editing && mod.m_mode == CssEditorMod.MODE_REMOVE;
			y = bottom;
			x = left + CssEditorMod.EDIT_W + 6;
			placeBar(mod.m_sortBtn, x, y, mod.m_editing, mod.m_mode == CssEditorMod.MODE_SORT ? 1 : 0.45);
			x += BTN_W + 6;
			placeBar(mod.m_addBtn, x, y, mod.m_editing && !removing, mod.m_mode == CssEditorMod.MODE_ADD ? 1 : 0.85);
			if (mod.m_editing && !removing)
			{
				x += BTN_W + 6;
			};
			placeBar(mod.m_removeAllBtn, x, y, removing, 1);
			if (removing)
			{
				x += BTN_W + 6;
			};
			placeBar(mod.m_removeBtn, x, y, mod.m_editing, removing ? 1 : 0.45);
			x += BTN_W + 6;
			placeBar(mod.m_restoreBtn, x, y, mod.m_editing && !removing, 1);
			if (mod.m_editing && !removing)
			{
				x += BTN_W + 6;
			};
			placeBar(mod.m_confirmBtn, x, y, removing && mod.m_input.hasRemoveSelection(), 1);
		}

		internal function cssGameSize():Object
		{
			var MainCls:*;
			var gw:Number;
			var gh:Number;
			gw = 853;
			gh = 480;
			try
			{
				MainCls = EngineRefs.Main;
				if (MainCls && Number(MainCls["Width"]) > 0)
				{
					gw = Number(MainCls["Width"]);
					gh = Number(MainCls["Height"]);
				};
			}
			catch (err:*)
			{
			};
			return ({"w": gw, "h": gh});
		}

		private function headerAnchor(parent:DisplayObjectContainer):Point
		{
			var sub:DisplayObjectContainer;
			var controls:DisplayObject;
			var global:Point;
			if (!parent)
			{
				return (null);
			};
			sub = cssSubMenu();
			if (!sub)
			{
				return (null);
			};
			try
			{
				controls = sub["controls_btn"] as DisplayObject;
			}
			catch (err:*)
			{
				controls = null;
			};
			if (!controls)
			{
				return (null);
			};
			try
			{
				global = controls.localToGlobal(new Point(0, 0));
				return (parent.globalToLocal(global));
			}
			catch (convErr:*)
			{
				return (null);
			};
			return (null);
		}

		private function placeBar(btn:Sprite, x:Number, y:Number, show:Boolean, alpha:Number):void
		{
			if (!btn)
			{
				return;
			};
			btn.x = x;
			btn.y = y;
			btn.visible = show;
			btn.alpha = alpha;
		}

		internal function makeBarButton(label:String, click:Function, w:Number, h:Number):Sprite
		{
			var btn:Sprite;
			btn = EditBar.button(label, click, w, h, 0xE8A020, 0xFFFFFF, 1, 2, 12);
			btn.name = "cssChrome";
			btn.mouseChildren = false;
			return (btn);
		}

		internal function refreshEditSlot(menu:*):void
		{
			var slot:Rectangle;
			if (mod.m_editing && m_editSlot)
			{
				return;
			};
			slot = measureHeaderLocal(menu);
			if (slot)
			{
				m_editSlot = slot;
			};
		}

		private function measureHeaderLocal(menu:*):Rectangle
		{
			var sub:DisplayObjectContainer;
			var controls:DisplayObject;
			try
			{
				sub = menu.SubMenu as DisplayObjectContainer;
			}
			catch (err:*)
			{
				return (null);
			};
			if (!sub)
			{
				return (null);
			};
			try
			{
				controls = sub["controls_btn"] as DisplayObject;
			}
			catch (ctrlErr:*)
			{
				controls = null;
			};
			if (!controls)
			{
				return (null);
			};
			return (new Rectangle(controls.x - CssEditorMod.EDIT_W - 4, controls.y, CssEditorMod.EDIT_W, EDIT_H));
		}

		internal function applyEditVisibility(menu:*):void
		{
			var sub:DisplayObjectContainer;
			var icons:DisplayObjectContainer;
			var charSel:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			if (!mod.m_editing)
			{
				restoreEditVisibility();
				return;
			};
			try
			{
				sub = menu.SubMenu as DisplayObjectContainer;
				charSel = menu.CharSelectionMC as DisplayObjectContainer;
				icons = menu.CharSelectionIconsMC as DisplayObjectContainer;
			}
			catch (err:*)
			{
				return;
			};
			if (sub)
			{
				i = 0;
				while (i < sub.numChildren)
				{
					child = sub.getChildAt(i);
					if (child != charSel && !isCssChrome(child) && !isMenuBackground(child, sub))
					{
						hideKeep(child);
					};
					i++;
				};
			};
			if (charSel)
			{
				i = 0;
				while (i < charSel.numChildren)
				{
					child = charSel.getChildAt(i);
					if (child != icons)
					{
						hideKeep(child);
					};
					i++;
				};
			};
			if (icons)
			{
				i = 0;
				while (i < icons.numChildren)
				{
					child = icons.getChildAt(i);
					if (mod.m_hands.isPrimaryHand(menu, child) || isCssChrome(child))
					{
						child.visible = true;
					}
					else if (mod.m_hands.isLiveHand(menu, child) || mod.m_hands.isChipToken(menu, child))
					{
						hideCursorPiece(child);
					}
					else if (!mod.m_layout.readCharId(child))
					{
						hideKeep(child);
					};
					i++;
				};
			};
		}

		private function isCssChrome(child:DisplayObject):Boolean
		{
			return (child != null && child.name == "cssChrome");
		}

		private function isSelectArt(child:DisplayObject):Boolean
		{
			var name:String;
			if (!child)
			{
				return (false);
			};
			name = child.name || "";
			if (name.indexOf("_select") >= 0)
			{
				return (true);
			};
			try
			{
				return (child["characterID"] != null && String(child["characterID"]) != "");
			}
			catch (err:*)
			{
			};
			return (false);
		}

		private function isMenuBackground(child:DisplayObject, sub:DisplayObjectContainer):Boolean
		{
			var name:String;
			if (!child || !sub)
			{
				return (false);
			};
			name = child.name || "";
			if (name == "bg_top" || isSelectArt(child))
			{
				return (false);
			};
			if (sub.numChildren > 0 && child == sub.getChildAt(0))
			{
				return (true);
			};
			if (name == "background" || name == "menu_bg" || name == "bg" || name.indexOf("menubg") >= 0 || name.indexOf("MenuBg") >= 0)
			{
				return (true);
			};
			return (false);
		}

		private function hideKeep(child:DisplayObject):void
		{
			var rec:Object;
			var io:InteractiveObject;
			var box:DisplayObjectContainer;
			if (!child)
			{
				return;
			};
			io = child as InteractiveObject;
			box = child as DisplayObjectContainer;
			rec = m_hideSnap[child];
			if (!rec)
			{
				rec = {
					"v": child.visible,
					"me": io ? io.mouseEnabled : true,
					"mc": box ? box.mouseChildren : true,
					"y": child.y
				};
				m_hideSnap[child] = rec;
			};
			child.visible = false;
			if (io)
			{
				io.mouseEnabled = false;
			};
			if (box)
			{
				box.mouseChildren = false;
			};
			child.y = Number(rec.y) - 4000;
		}

		internal function restoreEditVisibility():void
		{
			var key:*;
			var rec:Object;
			var child:DisplayObject;
			var io:InteractiveObject;
			var box:DisplayObjectContainer;
			if (!m_hideSnap)
			{
				m_hideSnap = new Dictionary(true);
				return;
			};
			for (key in m_hideSnap)
			{
				rec = m_hideSnap[key];
				child = key as DisplayObject;
				if (child && rec)
				{
					io = child as InteractiveObject;
					box = child as DisplayObjectContainer;
					child.y = Number(rec.y);
					child.visible = Boolean(rec.v);
					if (io)
					{
						io.mouseEnabled = Boolean(rec.me);
					};
					if (box)
					{
						box.mouseChildren = Boolean(rec.mc);
					};
				};
			};
			m_hideSnap = new Dictionary(true);
			restoreCursorPieces();
		}

		internal function hideCursorPiece(child:DisplayObject):void
		{
			if (!child)
			{
				return;
			};
			if (m_handSnap[child] == undefined)
			{
				m_handSnap[child] = child.visible;
			};
			child.visible = false;
		}

		private function restoreCursorPieces():void
		{
			var key:*;
			var child:DisplayObject;
			if (!m_handSnap)
			{
				m_handSnap = new Dictionary(true);
				return;
			};
			for (key in m_handSnap)
			{
				child = key as DisplayObject;
				if (child)
				{
					child.visible = Boolean(m_handSnap[key]);
				};
			};
			m_handSnap = new Dictionary(true);
		}
	}
}
