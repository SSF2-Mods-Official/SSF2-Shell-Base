package
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.text.TextField;

	/**
	 * Per-player nametag dropdown: build, paint, scroll, and choose rows.
	 */
	public class ProfileList
	{
		private static const LIST_W:Number = 135;
		private static const ROW_H:Number = 26;
		private static const ROW_STEP:Number = 28;
		private static const LIST_MARK:String = "__ssf2mm_profiles_list";

		internal var mod:ControllerProfilesMod;

		public function ProfileList(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		internal function openList(pid:int, anchor:*):void
		{
			var names:Array;
			var s:Object;
			// Only close this player's UI — other players keep their dropdowns.
			closeListFor(pid);
			mod.m_manage.closeManageFor(pid);
			if (mod.m_editPid == pid)
			{
				mod.m_nameEdit.endLiveNameEdit(false);
			};
			names = mod.m_tags.userTagNames();
			mod.m_data["names"] = names;
			s = mod.sessionOf(pid);
			s["listIndex"] = indexOfCurrentTag(pid, names);
			s["listScroll"] = 0;
			s["outsideArmed"] = false;
			s["prevOk"] = true;
			s["prevCancel"] = true;
			if (!anchor)
			{
				anchor = ProfileCssHooks.findNameButton(mod.m_cssMenu, pid) || mod.m_profileBar;
			};
			if (!anchor)
			{
				log("openList no anchor pid=" + pid);
				mod.m_nameEdit.startAdd(pid);
				return;
			};
			log("openList pid=" + pid + " names=" + names.length);
			s["list"] = buildList(pid, names, anchor);
			mod.m_ui.uiParentAdd(s["list"], anchor);
			paintList(pid);
			ensureListScroll(pid);
			if (mod.m_controls && mod.m_profileBar && (anchor == mod.m_profileBar || mod.m_ui.resolveUiParent(anchor) == mod.m_controls["SubMenu"]))
			{
				mod.m_bar.setControlsHandEnabled(false);
			};
		}

		private function buildList(pid:int, names:Array, anchor:*):Sprite
		{
			var box:Sprite;
			var content:Sprite;
			var maskSp:Sprite;
			var bg:Sprite;
			var pt:Point;
			var i:int;
			var labels:Array;
			var gw:Number;
			var gh:Number;
			var vis:int;
			var viewH:Number;
			var track:Sprite;
			var thumb:Sprite;
			var s:Object;
			var rows:Array;
			var parent:*;
			s = mod.sessionOf(pid);
			box = new Sprite();
			box.name = LIST_MARK;
			mod.m_pidByUi[box] = pid;
			rows = [];
			labels = [ControllerProfilesMod.DEFAULT_TAG];
			i = 0;
			while (i < names.length)
			{
				if (String(names[i]) != ControllerProfilesMod.DEFAULT_TAG)
				{
					labels.push(String(names[i]));
				};
				i++;
			};
			labels.push("Add new");
			labels.push("Manage tags");
			vis = labels.length < ControllerProfilesMod.MAX_VISIBLE ? labels.length : ControllerProfilesMod.MAX_VISIBLE;
			if (vis < 1)
			{
				vis = 1;
			};
			viewH = vis * ROW_STEP - 2;
			s["listViewH"] = viewH;
			s["listContentH"] = labels.length * ROW_STEP;
			bg = new Sprite();
			bg.graphics.beginFill(0x0A0A12, 0.96);
			bg.graphics.drawRoundRect(0, -viewH, LIST_W, viewH, 6, 6);
			bg.graphics.endFill();
			box.addChild(bg);
			content = new Sprite();
			s["listContent"] = content;
			mod.m_pidByUi[content] = pid;
			i = 0;
			while (i < labels.length)
			{
				rows.push(addRow(pid, content, String(labels[i]), i * ROW_STEP, i));
				i++;
			};
			s["rows"] = rows;
			maskSp = new Sprite();
			maskSp.graphics.beginFill(0xFFFFFF, 1);
			maskSp.graphics.drawRect(0, -viewH, LIST_W - (labels.length > ControllerProfilesMod.MAX_VISIBLE ? 10 : 0), viewH);
			maskSp.graphics.endFill();
			s["listMask"] = maskSp;
			content.mask = maskSp;
			box.addChild(content);
			box.addChild(maskSp);
			if (labels.length > ControllerProfilesMod.MAX_VISIBLE)
			{
				track = new Sprite();
				track.graphics.beginFill(0x333344, 0.9);
				track.graphics.drawRoundRect(LIST_W - 9, -viewH + 2, 7, viewH - 4, 4, 4);
				track.graphics.endFill();
				box.addChild(track);
				thumb = new Sprite();
				thumb.name = "__scrollThumb";
				box.addChild(thumb);
			};
			content.y = -viewH;
			gw = ProfileUi.gameWidth();
			gh = ProfileUi.gameHeight();
			parent = mod.m_ui.resolveUiParent(anchor);
			if (anchor)
			{
				try
				{
					pt = ProfileUi.toParentLocal(parent, anchor.localToGlobal(new Point(0, 0)));
				}
				catch (ptErr:*)
				{
					pt = new Point(8, 40);
				};
			}
			else
			{
				pt = new Point(8, 40);
			};
			if (pt.x < 8)
			{
				pt.x = 8;
			};
			if (pt.x > gw - LIST_W - 8)
			{
				pt.x = gw - LIST_W - 8;
			};
			if (pt.y - viewH < 8)
			{
				pt.y = 8 + viewH;
			};
			if (pt.y > gh - 8)
			{
				pt.y = gh - 8;
			};
			box.x = pt.x;
			box.y = pt.y;
			return (box);
		}

		private function addRow(pid:int, box:Sprite, label:String, y:Number, index:int):Sprite
		{
			var row:Sprite;
			var tf:TextField;
			var rowW:Number;
			var s:Object;
			s = mod.sessionOf(pid);
			rowW = LIST_W - (s["listContentH"] > ControllerProfilesMod.MAX_VISIBLE * ROW_STEP ? 12 : 4);
			row = new Sprite();
			row.graphics.beginFill(0x111111, 0.92);
			row.graphics.drawRoundRect(2, 0, rowW, ROW_H, 6, 6);
			row.graphics.endFill();
			row.y = y;
			row.buttonMode = true;
			row.mouseChildren = false;
			row.name = String(index);
			mod.m_pidByUi[row] = pid;
			tf = ProfileUi.menuText(label, 14, 0xFFFFFF);
			tf.x = 8;
			tf.y = 3;
			tf.width = rowW - 12;
			row.addChild(tf);
			row.addEventListener(MouseEvent.MOUSE_DOWN, onRowClick);
			row.addEventListener(MouseEvent.ROLL_OVER, onRowOver);
			box.addChild(row);
			return (row);
		}

		private function onRowClick(e:MouseEvent):void
		{
			var pid:int;
			var s:Object;
			e.stopImmediatePropagation();
			e.stopPropagation();
			pid = mod.pidFromUi(e.currentTarget);
			if (pid < 1)
			{
				return;
			};
			s = mod.sessionOf(pid);
			s["listIndex"] = int(e.currentTarget.name);
			chooseList(pid);
		}

		private function onRowOver(e:MouseEvent):void
		{
			var pid:int;
			var s:Object;
			pid = mod.pidFromUi(e.currentTarget);
			if (pid < 1)
			{
				return;
			};
			s = mod.sessionOf(pid);
			s["listIndex"] = int(e.currentTarget.name);
			paintList(pid);
			ensureListScroll(pid);
		}

		private function paintList(pid:int):void
		{
			var i:int;
			var row:Sprite;
			var idx:int;
			var rowW:Number;
			var s:Object;
			var rows:Array;
			s = mod.m_sessions[String(pid)];
			if (!s)
			{
				return;
			};
			rows = s["rows"] as Array;
			if (!rows)
			{
				return;
			};
			rowW = LIST_W - (s["listContentH"] > ControllerProfilesMod.MAX_VISIBLE * ROW_STEP ? 12 : 4);
			i = 0;
			while (i < rows.length)
			{
				row = rows[i];
				idx = int(row.name);
				row.graphics.clear();
				row.graphics.beginFill(idx == s["listIndex"] ? 0x6A3FA0 : 0x111111, 0.94);
				row.graphics.drawRoundRect(2, 0, rowW, ROW_H, 6, 6);
				row.graphics.endFill();
				i++;
			};
			paintListThumb(pid);
		}

		private function paintListThumb(pid:int):void
		{
			var thumb:Sprite;
			var maxScroll:Number;
			var ratio:Number;
			var thumbH:Number;
			var thumbY:Number;
			var s:Object;
			s = mod.m_sessions[String(pid)];
			if (!s || !s["list"] || s["listContentH"] <= s["listViewH"])
			{
				return;
			};
			thumb = s["list"].getChildByName("__scrollThumb") as Sprite;
			if (!thumb)
			{
				return;
			};
			maxScroll = s["listContentH"] - s["listViewH"];
			ratio = maxScroll > 0 ? s["listScroll"] / maxScroll : 0;
			thumbH = Math.max(16, s["listViewH"] * (s["listViewH"] / s["listContentH"]));
			thumbY = -s["listViewH"] + 2 + ratio * (s["listViewH"] - 4 - thumbH);
			thumb.graphics.clear();
			thumb.graphics.beginFill(0xAAAAAA, 0.95);
			thumb.graphics.drawRoundRect(LIST_W - 9, thumbY, 7, thumbH, 4, 4);
			thumb.graphics.endFill();
		}

		private function ensureListScroll(pid:int):void
		{
			var maxScroll:Number;
			var rowTop:Number;
			var rowBot:Number;
			var s:Object;
			s = mod.m_sessions[String(pid)];
			if (!s || !s["listContent"])
			{
				return;
			};
			maxScroll = Math.max(0, s["listContentH"] - s["listViewH"]);
			rowTop = s["listIndex"] * ROW_STEP;
			rowBot = rowTop + ROW_STEP;
			if (rowTop < s["listScroll"])
			{
				s["listScroll"] = rowTop;
			};
			if (rowBot > s["listScroll"] + s["listViewH"])
			{
				s["listScroll"] = rowBot - s["listViewH"];
			};
			if (s["listScroll"] < 0)
			{
				s["listScroll"] = 0;
			};
			if (s["listScroll"] > maxScroll)
			{
				s["listScroll"] = maxScroll;
			};
			s["listContent"].y = -s["listViewH"] - s["listScroll"];
			paintListThumb(pid);
		}

		internal function onListWheel(e:MouseEvent):void
		{
			var maxScroll:Number;
			var pid:int;
			var s:Object;
			pid = 1;
			while (pid <= 4)
			{
				s = mod.m_sessions[String(pid)];
				if (mod.sessionManageOpen(s) && s["manageContent"] && ProfileUi.hitSprite(s["manage"], e.stageX, e.stageY))
				{
					maxScroll = Math.max(0, s["manageContentH"] - s["manageViewH"]);
					s["manageScroll"] -= e.delta * 14;
					if (s["manageScroll"] < 0)
					{
						s["manageScroll"] = 0;
					};
					if (s["manageScroll"] > maxScroll)
					{
						s["manageScroll"] = maxScroll;
					};
					s["manageContent"].y = 36 - s["manageScroll"];
					mod.m_manage.paintManageThumb(pid);
					e.stopPropagation();
					return;
				};
				pid++;
			};
			pid = 1;
			while (pid <= 4)
			{
				s = mod.m_sessions[String(pid)];
				if (mod.sessionListOpen(s) && s["listContent"] && ProfileUi.hitSprite(s["list"], e.stageX, e.stageY))
				{
					maxScroll = Math.max(0, s["listContentH"] - s["listViewH"]);
					s["listScroll"] -= e.delta * 14;
					if (s["listScroll"] < 0)
					{
						s["listScroll"] = 0;
					};
					if (s["listScroll"] > maxScroll)
					{
						s["listScroll"] = maxScroll;
					};
					s["listContent"].y = -s["listViewH"] - s["listScroll"];
					paintListThumb(pid);
					e.stopPropagation();
					return;
				};
				pid++;
			};
		}

		internal function moveList(pid:int, dir:int):void
		{
			var n:int;
			var s:Object;
			var rows:Array;
			s = mod.m_sessions[String(pid)];
			if (!s)
			{
				return;
			};
			rows = s["rows"] as Array;
			n = rows ? rows.length : 0;
			if (n < 1)
			{
				return;
			};
			s["listIndex"] = (int(s["listIndex"]) + dir + n) % n;
			paintList(pid);
			ensureListScroll(pid);
		}

		internal function chooseList(pid:int):void
		{
			var names:Array;
			var label:String;
			var addIdx:int;
			var manageIdx:int;
			var s:Object;
			var idx:int;
			names = mod.m_tags.userTagNames();
			addIdx = names.length + 1;
			manageIdx = names.length + 2;
			s = mod.m_sessions[String(pid)];
			idx = s ? int(s["listIndex"]) : 0;
			// Close first so UI can't linger if select/add throws or re-enters.
			closeListFor(pid);
			mod.armChipHoldoff(pid);
			if (idx == 0)
			{
				log("choose Default pid=" + pid);
				mod.m_tags.selectName(pid, ControllerProfilesMod.DEFAULT_TAG);
				return;
			};
			if (idx == addIdx)
			{
				log("choose Add new pid=" + pid + " controls=" + Boolean(mod.m_controls));
				mod.m_nameEdit.startAdd(pid);
				return;
			};
			if (idx == manageIdx)
			{
				mod.m_manage.openManage(pid);
				return;
			};
			label = String(names[idx - 1]);
			log("choose profile \"" + label + "\" pid=" + pid);
			mod.m_tags.selectName(pid, label);
		}

		private function indexOfCurrentTag(pid:int, names:Array):int
		{
			var cur:String;
			var i:int;
			cur = String(mod.m_data["last"][String(pid)] || "");
			if (cur.length < 1 || cur == ControllerProfilesMod.DEFAULT_TAG)
			{
				return (0);
			};
			i = 0;
			while (i < names.length)
			{
				if (String(names[i]) == cur)
				{
					return (i + 1);
				};
				i++;
			};
			return (0);
		}

		internal function closeListFor(pid:int):void
		{
			var s:Object;
			var play:int;
			s = mod.m_sessions[String(pid)];
			if (!s)
			{
				return;
			};
			if (s["list"] && s["list"].parent)
			{
				try
				{
					s["list"].parent.removeChild(s["list"]);
				}
				catch (rmErr:*)
				{
					log("closeListFor failed: " + rmErr);
				};
			};
			if (s["list"])
			{
				delete mod.m_pidByUi[s["list"]];
			};
			if (s["listContent"])
			{
				delete mod.m_pidByUi[s["listContent"]];
			};
			s["list"] = null;
			s["listContent"] = null;
			s["listMask"] = null;
			s["rows"] = [];
			s["outsideArmed"] = false;
			if (mod.m_controls && !mod.m_bar.controlsUiOpen() && !mod.sessionManageOpen(s))
			{
				// Don't re-arm SelectHand while B is still held or it backs out of Controls.
				play = int(mod.m_controls["playNum"] || pid || 1);
				if (mod.specialDown(play))
				{
					mod.m_controlsHandHoldoff = true;
				}
				else
				{
					mod.m_controlsHandHoldoff = false;
					mod.m_bar.setControlsHandEnabled(true);
				};
			};
		}
	}
}
