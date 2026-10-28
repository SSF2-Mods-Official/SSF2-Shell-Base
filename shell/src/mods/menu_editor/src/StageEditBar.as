package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;

	/**
	 * The Stage Select edit bar: the Edit and BG buttons on the menu, the bottom Sort / Remove /
	 * Add / Page / Restore / Confirm row, and the edit mode those buttons switch.
	 */
	public class StageEditBar
	{
		private static const BTN_H:int = 28;

		private var mod:StageEditorMod;

		public function StageEditBar(owner:StageEditorMod)
		{
			mod = owner;
		}

		internal function attachEditButton(menu:*):void
		{
			var sub:*;
			detachEditButton();
			sub = mod.m_layout.resolveSubMenu(menu);
			if (!sub)
			{
				return;
			};
			mod.m_pageBtn = makeBarButton("New Page", onPageButtonClick);
			mod.m_addBtn = makeBarButton("Add", onAddButtonClick);
			mod.m_restoreBtn = makeBarButton("Restore", onRestoreClick);
			mod.m_sortBtn = makeBarButton("Sort", onSortButtonClick);
			mod.m_removeBtn = makeBarButton("Remove", onRemoveButtonClick);
			mod.m_confirmBtn = makeBarButton("Confirm", onConfirmClick);
			mod.m_removeAllBtn = makeBarButton("Remove All", onRemoveAllClick);
			mod.m_editBtn = makeBarButton("Edit Stages", onEditButtonClick);
			mod.m_bgBtn = makeBarButton("Set Stage BG", onBgButtonClick);
			mod.m_spaceBtn = makeBarButton("Space BG", onSpaceButtonClick);
			try
			{
				sub.addChild(mod.m_pageBtn);
				sub.addChild(mod.m_addBtn);
				sub.addChild(mod.m_restoreBtn);
				sub.addChild(mod.m_sortBtn);
				sub.addChild(mod.m_removeBtn);
				sub.addChild(mod.m_confirmBtn);
				sub.addChild(mod.m_removeAllBtn);
				sub.addChild(mod.m_editBtn);
				sub.addChild(mod.m_bgBtn);
				sub.addChild(mod.m_spaceBtn);
			}
			catch (addErr:*)
			{
				detachEditButton();
				return;
			};
			layoutBottomButtons();
			mod.m_layout.hookSssHandClip(mod.m_pageBtn);
			mod.m_layout.hookSssHandClip(mod.m_addBtn);
			mod.m_layout.hookSssHandClip(mod.m_restoreBtn);
			mod.m_layout.hookSssHandClip(mod.m_sortBtn);
			mod.m_layout.hookSssHandClip(mod.m_removeBtn);
			mod.m_layout.hookSssHandClip(mod.m_confirmBtn);
			mod.m_layout.hookSssHandClip(mod.m_removeAllBtn);
			mod.m_layout.hookSssHandClip(mod.m_editBtn);
			mod.m_layout.hookSssHandClip(mod.m_bgBtn);
		}

		internal function makeBarButton(label:String, click:Function):Sprite
		{
			return (hoverable(EditBar.button(label, click, StageEditorMod.BTN_W, BTN_H, 0x3A3A48, 0xE8A020, 0.9, 1, 12, 5)));
		}

		internal function makeMiniButton(label:String, w:int, click:Function):Sprite
		{
			return (hoverable(EditBar.button(label, click, w, BTN_H, 0x3A3A48, 0xE8A020, 0.9, 1, 14, 3)));
		}

		private function hoverable(btn:Sprite):Sprite
		{
			btn.addEventListener(MouseEvent.MOUSE_OVER, onBarButtonOver);
			btn.addEventListener(MouseEvent.MOUSE_OUT, onBarButtonOut);
			return (btn);
		}

		private function bottomSlotX(fromRight:int):Number
		{
			var size:Object;
			size = mod.m_layout.gameSize();
			return (size.w * 0.5 - 18 - (fromRight + 1) * StageEditorMod.BTN_W - fromRight * 8);
		}

		internal function layoutBottomButtons():void
		{
			var y:Number;
			y = mod.m_layout.gameSize().h * 0.5 - 36;
			if (mod.m_editBtn)
			{
				mod.m_editBtn.x = bottomSlotX(1);
				mod.m_editBtn.y = y;
				mod.m_editBtn.visible = !mod.m_editing || mod.m_mode != StageEditorMod.MODE_REMOVE;
				mod.m_editBtn.alpha = 1;
			};
			if (mod.m_bgBtn)
			{
				mod.m_bgBtn.x = bottomSlotX(2);
				mod.m_bgBtn.y = y;
				mod.m_bgBtn.visible = !mod.m_editing;
				mod.m_bgBtn.alpha = mod.m_bgPicking ? 1 : 0.9;
				EditBar.setLabel(mod.m_bgBtn, mod.m_bgPicking ? "Cancel BG" : "Set Stage BG");
			};
			if (mod.m_spaceBtn)
			{
				mod.m_spaceBtn.x = bottomSlotX(3);
				mod.m_spaceBtn.y = y;
				mod.m_spaceBtn.visible = !mod.m_editing;
				mod.m_spaceBtn.alpha = 0.9;
			};
			if (mod.m_sortBtn)
			{
				mod.m_sortBtn.x = bottomSlotX(2);
				mod.m_sortBtn.y = y;
				mod.m_sortBtn.visible = mod.m_editing;
				mod.m_sortBtn.alpha = mod.m_mode == StageEditorMod.MODE_SORT ? 1 : 0.4;
			};
			if (mod.m_removeBtn)
			{
				mod.m_removeBtn.x = bottomSlotX(3);
				mod.m_removeBtn.y = y;
				mod.m_removeBtn.visible = mod.m_editing;
				mod.m_removeBtn.alpha = mod.m_mode == StageEditorMod.MODE_REMOVE ? 1 : 0.4;
			};
			if (mod.m_restoreBtn)
			{
				mod.m_restoreBtn.x = bottomSlotX(4);
				mod.m_restoreBtn.y = y;
				mod.m_restoreBtn.visible = mod.m_editing && mod.m_mode != StageEditorMod.MODE_REMOVE;
				mod.m_restoreBtn.alpha = 1;
			};
			if (mod.m_removeAllBtn)
			{
				mod.m_removeAllBtn.x = bottomSlotX(4);
				mod.m_removeAllBtn.y = y;
				mod.m_removeAllBtn.visible = mod.m_editing && mod.m_mode == StageEditorMod.MODE_REMOVE;
				mod.m_removeAllBtn.alpha = 1;
			};
			if (mod.m_addBtn)
			{
				mod.m_addBtn.x = bottomSlotX(0);
				mod.m_addBtn.y = y;
				mod.m_addBtn.visible = mod.m_editing && mod.m_mode != StageEditorMod.MODE_REMOVE;
				mod.m_addBtn.alpha = mod.m_mode == StageEditorMod.MODE_ADD ? 1 : 0.85;
			};
			if (mod.m_pageBtn)
			{
				mod.m_pageBtn.x = bottomSlotX(5);
				mod.m_pageBtn.y = y;
				mod.m_pageBtn.visible = mod.m_editing;
			};
			if (mod.m_confirmBtn)
			{
				mod.m_confirmBtn.x = bottomSlotX(0);
				mod.m_confirmBtn.y = y;
				mod.m_confirmBtn.visible = mod.m_editing && mod.m_mode == StageEditorMod.MODE_REMOVE;
				mod.m_confirmBtn.alpha = mod.m_book.hasRemoveSelection() ? 1 : 0.4;
			};
			syncJukeboxVisible();
		}

		private function syncJukeboxVisible():void
		{
			var sub:DisplayObjectContainer;
			var i:int;
			var child:DisplayObject;
			sub = mod.m_layout.resolveSubMenu(mod.m_cachedSss) as DisplayObjectContainer;
			if (!sub)
			{
				return;
			};
			i = 0;
			while (i < sub.numChildren)
			{
				child = sub.getChildAt(i);
				if (isJukeboxButton(child))
				{
					child.visible = !mod.m_editing;
					try
					{
						child["mouseEnabled"] = !mod.m_editing;
						child["mouseChildren"] = !mod.m_editing;
					}
					catch (mouseErr:*)
					{
					};
				};
				i++;
			};
		}

		private function isJukeboxButton(mc:DisplayObject):Boolean
		{
			var host:DisplayObjectContainer;
			var i:int;
			var ch:DisplayObject;
			var tf:TextField;
			if (!mc || mc == mod.m_editBtn || mc == mod.m_bgBtn || mc == mod.m_sortBtn || mc == mod.m_removeBtn || mc == mod.m_restoreBtn || mc == mod.m_addBtn || mc == mod.m_pageBtn || mc == mod.m_confirmBtn || mc == mod.m_removeAllBtn)
			{
				return (false);
			};
			host = mc as DisplayObjectContainer;
			if (!host)
			{
				return (false);
			};
			i = 0;
			while (i < host.numChildren)
			{
				ch = host.getChildAt(i);
				tf = ch as TextField;
				if (tf && tf.text == "My Jukebox")
				{
					return (true);
				};
				i++;
			};
			return (false);
		}

		internal function detachBarButton(btn:Sprite, click:Function):void
		{
			if (!btn)
			{
				return;
			};
			try
			{
				mod.m_layout.unhookSssHandClip(btn);
				btn.removeEventListener(MouseEvent.CLICK, click);
				btn.removeEventListener(MouseEvent.MOUSE_OVER, onBarButtonOver);
				btn.removeEventListener(MouseEvent.MOUSE_OUT, onBarButtonOut);
				if (btn.parent)
				{
					btn.parent.removeChild(btn);
				};
			}
			catch (err:*)
			{
			};
		}

		internal function detachEditButton():void
		{
			mod.m_addUi.closeAddPopup();
			detachBarButton(mod.m_editBtn, onEditButtonClick);
			detachBarButton(mod.m_bgBtn, onBgButtonClick);
			detachBarButton(mod.m_spaceBtn, onSpaceButtonClick);
			detachBarButton(mod.m_sortBtn, onSortButtonClick);
			detachBarButton(mod.m_removeBtn, onRemoveButtonClick);
			detachBarButton(mod.m_restoreBtn, onRestoreClick);
			detachBarButton(mod.m_addBtn, onAddButtonClick);
			detachBarButton(mod.m_pageBtn, onPageButtonClick);
			detachBarButton(mod.m_confirmBtn, onConfirmClick);
			detachBarButton(mod.m_removeAllBtn, onRemoveAllClick);
			mod.m_editBtn = null;
			mod.m_bgBtn = null;
			mod.m_spaceBtn = null;
			mod.m_sortBtn = null;
			mod.m_removeBtn = null;
			mod.m_restoreBtn = null;
			mod.m_addBtn = null;
			mod.m_pageBtn = null;
			mod.m_confirmBtn = null;
			mod.m_removeAllBtn = null;
		}

		private function onEditButtonClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (mod.m_editing)
			{
				mod.exitLiveEdit(false);
			}
			else
			{
				cancelBgPick();
				mod.enterLiveEdit();
			};
		}

		private function onSpaceButtonClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (mod.m_editing)
			{
				return;
			};
			cancelBgPick();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.emit("camera_background.useSpace");
					mod.m_host.notify("BG: Space. Pick the match stage.");
				};
			}
			catch (emitErr:*)
			{
			};
		}

		private function onBgButtonClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (mod.m_editing)
			{
				return;
			};
			if (mod.m_bgPicking)
			{
				cancelBgPick();
				try
				{
					if (mod.m_host)
					{
						mod.m_host.notify("Stage background pick cancelled.");
					};
				}
				catch (noteErr:*)
				{
				};
				return;
			};
			mod.m_bgPicking = true;
			layoutBottomButtons();
			try
			{
				if (mod.m_host)
				{
					mod.m_host.emit("camera_background.beginPick");
				};
			}
			catch (emitErr:*)
			{
			};
		}

		internal function cancelBgPick():void
		{
			if (!mod.m_bgPicking)
			{
				return;
			};
			mod.m_bgPicking = false;
			try
			{
				if (mod.m_host)
				{
					mod.m_host.emit("camera_background.cancelPick");
				};
			}
			catch (err:*)
			{
			};
			layoutBottomButtons();
		}

		internal function onBarButtonOver(e:MouseEvent):void
		{
			var btn:Sprite;
			btn = e.currentTarget as Sprite;
			if (!btn || btn.alpha < 0.6)
			{
				return;
			};
			btn.alpha = 0.85;
		}

		internal function onBarButtonOut(e:MouseEvent):void
		{
			layoutBottomButtons();
			mod.m_addUi.syncAddPageControls();
		}

		private function onSortButtonClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!mod.m_editing)
			{
				return;
			};
			setEditMode(StageEditorMod.MODE_SORT);
		}

		private function onRemoveButtonClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!mod.m_editing)
			{
				return;
			};
			setEditMode(StageEditorMod.MODE_REMOVE);
		}

		private function onAddButtonClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!mod.m_editing)
			{
				return;
			};
			setEditMode(mod.m_mode == StageEditorMod.MODE_ADD ? StageEditorMod.MODE_SORT : StageEditorMod.MODE_ADD);
		}

		private function onPageButtonClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_book.addNewPage();
		}

		private function onConfirmClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_book.confirmRemove();
		}

		internal function setEditMode(mode:int):void
		{
			if (mode < StageEditorMod.MODE_SORT || mode > StageEditorMod.MODE_REMOVE)
			{
				mode = StageEditorMod.MODE_SORT;
			};
			if (mod.m_mode == StageEditorMod.MODE_ADD && mode != StageEditorMod.MODE_ADD)
			{
				mod.m_addUi.closeAddPopup();
			};
			if (mode != StageEditorMod.MODE_REMOVE)
			{
				mod.m_removeIds = {};
			};
			if (mode != StageEditorMod.MODE_SORT)
			{
				mod.m_sortPickId = "";
				mod.m_input.endDrag(true);
			};
			mod.m_mode = mode;
			updateModeLabel();
			layoutBottomButtons();
			if (mode == StageEditorMod.MODE_ADD)
			{
				mod.m_addUi.openAddPopup();
			};
			try
			{
				if (mod.m_host)
				{
					if (mode == StageEditorMod.MODE_ADD)
					{
						mod.m_host.notify("Add: pick unused stages.");
					}
					else if (mode == StageEditorMod.MODE_REMOVE)
					{
						mod.m_host.notify("Remove: select one or more stages, then Confirm.");
					}
					else
					{
						mod.m_host.notify("Sort: pick a stage, then pick its new slot.");
					};
				};
			}
			catch (err:*)
			{
			};
		}

		internal function updateModeLabel():void
		{
		}

		private function onRemoveAllClick(e:MouseEvent):void
		{
			e.stopPropagation();
			if (!mod.m_editing || mod.m_mode != StageEditorMod.MODE_REMOVE)
			{
				return;
			};
			mod.m_book.removeAllOnPage();
		}

		internal function updateEditButtonLabel():void
		{
			EditBar.setLabel(mod.m_editBtn, mod.m_editing ? "Done" : "Edit Stages");
		}

		private function onRestoreClick(e:MouseEvent):void
		{
			e.stopPropagation();
			mod.m_store.onRestore();
		}
	}
}
