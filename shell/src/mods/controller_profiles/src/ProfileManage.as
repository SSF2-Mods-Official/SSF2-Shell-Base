package
{
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.text.TextField;

	/**
	 * Per-player Manage panel: list user tags, scroll, and delete.
	 */
	public class ProfileManage
	{
		private static const MANAGE_MARK:String = "__ssf2mm_profiles_manage";
		private static const MANAGE_W:Number = 260;

		internal var mod:ControllerProfilesMod;

		public function ProfileManage(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		internal function openManage(pid:int):void
		{
			var box:Sprite;
			var title:TextField;
			var closeBtn:Sprite;
			var names:Array;
			var i:int;
			var gw:Number;
			var gh:Number;
			var row:Sprite;
			var del:Sprite;
			var tf:TextField;
			var content:Sprite;
			var maskSp:Sprite;
			var bg:Sprite;
			var vis:int;
			var viewH:Number;
			var track:Sprite;
			var thumb:Sprite;
			var headerH:Number;
			var s:Object;
			closeManageFor(pid);
			names = mod.m_tags.userTagNames();
			mod.m_data["names"] = names;
			s = mod.sessionOf(pid);
			s["manageRows"] = [];
			s["manageIndex"] = 0;
			s["manageScroll"] = 0;
			s["outsideArmed"] = false;
			s["prevOk"] = true;
			s["prevCancel"] = true;
			headerH = 36;
			vis = names.length < 1 ? 1 : (names.length < ControllerProfilesMod.MAX_VISIBLE ? names.length : ControllerProfilesMod.MAX_VISIBLE);
			viewH = vis * 30;
			s["manageViewH"] = viewH;
			s["manageContentH"] = Math.max(1, names.length) * 30;
			box = new Sprite();
			box.name = MANAGE_MARK;
			mod.m_pidByUi[box] = pid;
			box.graphics.beginFill(0x111122, 0.97);
			box.graphics.drawRoundRect(0, 0, MANAGE_W, headerH + viewH + 12, 8, 8);
			box.graphics.endFill();
			title = ProfileUi.menuText("Manage tags", 16, 0xFFFFFF);
			title.x = 12;
			title.y = 8;
			box.addChild(title);
			closeBtn = makeButton("Close", 64, 22);
			closeBtn.x = MANAGE_W - 76;
			closeBtn.y = 8;
			mod.m_pidByUi[closeBtn] = pid;
			closeBtn.addEventListener(MouseEvent.CLICK, onManageCloseClick);
			box.addChild(closeBtn);
			bg = new Sprite();
			bg.graphics.beginFill(0x0A0A12, 0.5);
			bg.graphics.drawRect(8, headerH, MANAGE_W - 16, viewH);
			bg.graphics.endFill();
			box.addChild(bg);
			content = new Sprite();
			content.y = headerH;
			s["manageContent"] = content;
			mod.m_pidByUi[content] = pid;
			if (names.length < 1)
			{
				tf = ProfileUi.menuText("No tags yet", 13, 0xAAAAAA);
				tf.x = 12;
				tf.y = 4;
				content.addChild(tf);
			}
			else
			{
				i = 0;
				while (i < names.length)
				{
					row = new Sprite();
					row.y = i * 30;
					row.name = String(i);
					mod.m_pidByUi[row] = pid;
					row.graphics.beginFill(0x1A1A28, 0.95);
					row.graphics.drawRoundRect(8, 0, MANAGE_W - 24 - (names.length > ControllerProfilesMod.MAX_VISIBLE ? 10 : 0), 26, 4, 4);
					row.graphics.endFill();
					tf = ProfileUi.menuText(String(names[i]), 13, 0xFFFFFF);
					tf.x = 14;
					tf.y = 3;
					tf.width = 150;
					row.addChild(tf);
					del = makeButton("Delete", 64, 20);
					del.x = MANAGE_W - 88 - (names.length > ControllerProfilesMod.MAX_VISIBLE ? 10 : 0);
					del.y = 3;
					del.name = String(i);
					mod.m_pidByUi[del] = pid;
					del.addEventListener(MouseEvent.CLICK, onManageDeleteClick);
					row.addChild(del);
					row.addEventListener(MouseEvent.ROLL_OVER, onManageOver);
					content.addChild(row);
					(s["manageRows"] as Array).push(row);
					i++;
				};
			};
			maskSp = new Sprite();
			maskSp.graphics.beginFill(0xFFFFFF, 1);
			maskSp.graphics.drawRect(8, headerH, MANAGE_W - 16, viewH);
			maskSp.graphics.endFill();
			s["manageMask"] = maskSp;
			content.mask = maskSp;
			box.addChild(content);
			box.addChild(maskSp);
			if (names.length > ControllerProfilesMod.MAX_VISIBLE)
			{
				track = new Sprite();
				track.graphics.beginFill(0x333344, 0.9);
				track.graphics.drawRoundRect(MANAGE_W - 14, headerH + 2, 7, viewH - 4, 4, 4);
				track.graphics.endFill();
				box.addChild(track);
				thumb = new Sprite();
				thumb.name = "__manageThumb";
				box.addChild(thumb);
			};
			gw = ProfileUi.gameWidth();
			gh = ProfileUi.gameHeight();
			// Offset stacked manage panels so concurrent ones don't fully overlap.
			box.x = (gw - MANAGE_W) * 0.5 + (pid - 1) * 18;
			box.y = (gh - (headerH + viewH + 12)) * 0.5 + (pid - 1) * 18;
			s["manage"] = box;
			ProfileUi.rootAdd(box);
			paintManage(pid);
			ensureManageScroll(pid);
			if (mod.m_controls)
			{
				mod.m_bar.setControlsHandEnabled(false);
			};
		}

		private static function makeButton(label:String, w:Number, h:Number):Sprite
		{
			var btn:Sprite;
			var tf:TextField;
			btn = new Sprite();
			btn.graphics.beginFill(0x6A3FA0, 1);
			btn.graphics.drawRoundRect(0, 0, w, h, 4, 4);
			btn.graphics.endFill();
			btn.buttonMode = true;
			btn.mouseChildren = false;
			tf = ProfileUi.menuText(label, 12, 0xFFFFFF);
			tf.x = 8;
			tf.y = 2;
			btn.addChild(tf);
			return (btn);
		}

		private function onManageCloseClick(e:MouseEvent):void
		{
			var pid:int;
			pid = mod.pidFromUi(e.currentTarget);
			if (pid < 1)
			{
				pid = 1;
			};
			closeManageFor(pid);
		}

		private function onManageOver(e:MouseEvent):void
		{
			var pid:int;
			var s:Object;
			pid = mod.pidFromUi(e.currentTarget);
			if (pid < 1)
			{
				return;
			};
			s = mod.sessionOf(pid);
			s["manageIndex"] = int(e.currentTarget.name);
			paintManage(pid);
			ensureManageScroll(pid);
		}

		private function onManageDeleteClick(e:MouseEvent):void
		{
			var pid:int;
			var s:Object;
			e.stopPropagation();
			pid = mod.pidFromUi(e.currentTarget);
			if (pid < 1)
			{
				return;
			};
			s = mod.sessionOf(pid);
			s["manageIndex"] = int(e.currentTarget.name);
			deleteTagAt(pid, int(s["manageIndex"]));
		}

		private function paintManage(pid:int):void
		{
			var i:int;
			var row:Sprite;
			var rowW:Number;
			var names:Array;
			var s:Object;
			var rows:Array;
			s = mod.m_sessions[String(pid)];
			if (!s)
			{
				return;
			};
			rows = s["manageRows"] as Array;
			if (!rows)
			{
				return;
			};
			names = mod.m_tags.userTagNames();
			rowW = MANAGE_W - 24 - (names.length > ControllerProfilesMod.MAX_VISIBLE ? 10 : 0);
			i = 0;
			while (i < rows.length)
			{
				row = rows[i];
				row.graphics.clear();
				row.graphics.beginFill(i == s["manageIndex"] ? 0x3A2A55 : 0x1A1A28, 0.95);
				row.graphics.drawRoundRect(8, 0, rowW, 26, 4, 4);
				row.graphics.endFill();
				i++;
			};
			paintManageThumb(pid);
		}

		internal function paintManageThumb(pid:int):void
		{
			var thumb:Sprite;
			var maxScroll:Number;
			var ratio:Number;
			var thumbH:Number;
			var thumbY:Number;
			var headerH:Number;
			var s:Object;
			s = mod.m_sessions[String(pid)];
			if (!s || !s["manage"] || s["manageContentH"] <= s["manageViewH"])
			{
				return;
			};
			thumb = s["manage"].getChildByName("__manageThumb") as Sprite;
			if (!thumb)
			{
				return;
			};
			headerH = 36;
			maxScroll = s["manageContentH"] - s["manageViewH"];
			ratio = maxScroll > 0 ? s["manageScroll"] / maxScroll : 0;
			thumbH = Math.max(16, s["manageViewH"] * (s["manageViewH"] / s["manageContentH"]));
			thumbY = headerH + 2 + ratio * (s["manageViewH"] - 4 - thumbH);
			thumb.graphics.clear();
			thumb.graphics.beginFill(0xAAAAAA, 0.95);
			thumb.graphics.drawRoundRect(MANAGE_W - 14, thumbY, 7, thumbH, 4, 4);
			thumb.graphics.endFill();
		}

		private function ensureManageScroll(pid:int):void
		{
			var maxScroll:Number;
			var rowTop:Number;
			var rowBot:Number;
			var s:Object;
			s = mod.m_sessions[String(pid)];
			if (!s || !s["manageContent"])
			{
				return;
			};
			maxScroll = Math.max(0, s["manageContentH"] - s["manageViewH"]);
			rowTop = s["manageIndex"] * 30;
			rowBot = rowTop + 30;
			if (rowTop < s["manageScroll"])
			{
				s["manageScroll"] = rowTop;
			};
			if (rowBot > s["manageScroll"] + s["manageViewH"])
			{
				s["manageScroll"] = rowBot - s["manageViewH"];
			};
			if (s["manageScroll"] < 0)
			{
				s["manageScroll"] = 0;
			};
			if (s["manageScroll"] > maxScroll)
			{
				s["manageScroll"] = maxScroll;
			};
			s["manageContent"].y = 36 - s["manageScroll"];
			paintManageThumb(pid);
		}

		internal function moveManage(pid:int, dir:int):void
		{
			var n:int;
			var s:Object;
			var rows:Array;
			s = mod.m_sessions[String(pid)];
			if (!s)
			{
				return;
			};
			rows = s["manageRows"] as Array;
			n = rows ? rows.length : 0;
			if (n < 1)
			{
				return;
			};
			s["manageIndex"] = (int(s["manageIndex"]) + dir + n) % n;
			paintManage(pid);
			ensureManageScroll(pid);
		}

		internal function chooseManage(pid:int):void
		{
			var s:Object;
			s = mod.m_sessions[String(pid)];
			if (!s)
			{
				return;
			};
			deleteTagAt(pid, int(s["manageIndex"]));
		}

		private function deleteTagAt(pid:int, index:int):void
		{
			var names:Array;
			var name:String;
			var key:String;
			names = mod.m_tags.userTagNames();
			if (!names || index < 0 || index >= names.length)
			{
				return;
			};
			name = String(names[index]);
			names.splice(index, 1);
			mod.m_data["names"] = names;
			try
			{
				delete mod.m_data["profiles"][name];
			}
			catch (pErr:*)
			{
				log("deleteTagAt failed: " + pErr);
			};
			for (key in mod.m_data["last"])
			{
				if (String(mod.m_data["last"][key]) == name)
				{
					mod.m_data["last"][key] = ControllerProfilesMod.DEFAULT_TAG;
				};
			};
			mod.saveData();
			log("deleted tag \"" + name + "\"");
			if (mod.m_controls)
			{
				mod.m_bar.refreshProfileBar();
			};
			openManage(pid);
		}

		internal function closeManageFor(pid:int):void
		{
			var s:Object;
			s = mod.m_sessions[String(pid)];
			if (!s)
			{
				return;
			};
			if (s["manage"] && s["manage"].parent)
			{
				try
				{
					s["manage"].parent.removeChild(s["manage"]);
				}
				catch (rmErr:*)
				{
					log("closeManageFor failed: " + rmErr);
				};
			};
			if (s["manage"])
			{
				delete mod.m_pidByUi[s["manage"]];
			};
			if (s["manageContent"])
			{
				delete mod.m_pidByUi[s["manageContent"]];
			};
			s["manage"] = null;
			s["manageContent"] = null;
			s["manageMask"] = null;
			s["manageRows"] = [];
			s["outsideArmed"] = false;
			if (mod.m_controls && !mod.m_bar.controlsUiOpen())
			{
				mod.m_bar.setControlsHandEnabled(true);
			};
		}
	}
}
