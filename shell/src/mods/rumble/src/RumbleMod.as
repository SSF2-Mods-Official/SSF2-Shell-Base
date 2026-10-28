package
{
	import flash.display.Sprite;

	import ssf2mm.shared.EngineRefs;

	public class RumbleMod extends Sprite
	{
		private var m_host:*;

		public function RumbleMod()
		{
			super();
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			}
			host.addHook("RUMBLE", onRumble);
			trace("[rumble] boot");
		}

		public function onBootEnd():void
		{
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("RUMBLE", onRumble);
				}
				catch (err:*)
				{
				}
			}
			m_host = null;
		}

		private function onRumble(ctx:*):void
		{
			var kind:String = ctx && ctx.kind ? String(ctx.kind) : "";
			var Gamepad:Class = EngineRefs.ssf2("input.Gamepad") as Class;
			var SaveData:Class = EngineRefs.SaveData as Class;
			if (!Gamepad || !SaveData)
			{
				return;
			}
			if (kind == "menuStop")
			{
				stopAll(SaveData);
				return;
			}
			if (kind == "title")
			{
				rumbleTitle(Gamepad, SaveData, int(ctx.controllerIndex));
				return;
			}
			if (kind == "menu")
			{
				pulseMenu(Gamepad, SaveData, int(ctx.controllerIndex));
				return;
			}
			if (kind == "stopPlayer")
			{
				Gamepad["rumbleForPlayer"](int(ctx.playerId), 0, 0, 0);
				return;
			}
			if (kind == "direct")
			{
				Gamepad["rumbleForPlayer"](int(ctx.playerId), Number(ctx.left), Number(ctx.right), int(ctx.ms));
				return;
			}
			playCue(Gamepad, kind, int(ctx.playerId), Number(ctx.damage), Number(ctx.power), Number(ctx.fallSpeed));
		}

		private function pulseMenu(Gamepad:Class, SaveData:Class, controllerIndex:int):void
		{
			var gamepad:*;
			if (!Gamepad["getGlobalRumbleEnabled"]())
			{
				return;
			}
			if (!SaveData["getRumbleEnabled"](controllerIndex + 1))
			{
				return;
			}
			if (!SaveData["Controllers"] || controllerIndex < 0 || controllerIndex >= SaveData["Controllers"].length)
			{
				return;
			}
			gamepad = SaveData["Controllers"][controllerIndex].GamepadInstance;
			if (gamepad)
			{
				gamepad.setRumble(0.4, 0.4, 100);
			}
		}

		private function rumbleTitle(Gamepad:Class, SaveData:Class, controllerIndex:int):void
		{
			var i:int;
			if (controllerIndex < 0)
			{
				if (!SaveData["Controllers"])
				{
					return;
				}
				i = 0;
				while (i < SaveData["Controllers"].length)
				{
					pulseMenu(Gamepad, SaveData, i);
					i++;
				}
				return;
			}
			pulseMenu(Gamepad, SaveData, controllerIndex);
		}

		private function stopAll(SaveData:Class):void
		{
			var i:int;
			var gamepad:*;
			if (!SaveData["Controllers"])
			{
				return;
			}
			i = 0;
			while (i < SaveData["Controllers"].length)
			{
				if (SaveData["Controllers"][i] && SaveData["Controllers"][i].GamepadInstance)
				{
					gamepad = SaveData["Controllers"][i].GamepadInstance;
					gamepad.setRumble(0, 0, 1);
				}
				i++;
			}
		}

		private function playCue(Gamepad:Class, kind:String, playerId:int, damage:Number, power:Number, fallSpeed:Number):void
		{
			var intensity:Number;
			var duration:int;
			if (kind == "hit")
			{
				intensity = Math.min(0.8, Math.max(0.2, damage / 25));
				duration = Math.min(150, Math.max(50, int(power * 2)));
				Gamepad["rumbleForPlayer"](playerId, intensity * 0.8, intensity, duration);
			}
			else if (kind == "damage")
			{
				intensity = Math.min(1, Math.max(0.3, damage / 20));
				duration = Math.min(200, Math.max(80, int(power * 5)));
				Gamepad["rumbleForPlayer"](playerId, intensity, intensity * 0.6, duration);
			}
			else if (kind == "land")
			{
				if (fallSpeed < 5)
				{
					return;
				}
				intensity = Math.min(0.4, Math.max(0.1, fallSpeed / 60));
				duration = Math.min(80, Math.max(30, int(fallSpeed * 2)));
				Gamepad["rumbleForPlayer"](playerId, intensity, intensity * 0.5, duration);
			}
			else if (kind == "ko")
			{
				Gamepad["rumbleForPlayer"](playerId, 1, 0.8, 200);
			}
			else if (kind == "shieldHit")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.1, 0.2, 40);
			}
			else if (kind == "shieldBreak")
			{
				Gamepad["rumbleForPlayer"](playerId, 1, 1, 300);
			}
			else if (kind == "tech")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.2, 0.4, 50);
			}
			else if (kind == "ledgeGrab")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.15, 0.3, 40);
			}
			else if (kind == "grab")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.3, 0.5, 60);
			}
			else if (kind == "grabbed")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.4, 0.2, 80);
			}
			else if (kind == "starKO")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.6, 0.4, 150);
			}
			else if (kind == "finalSmash")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.8, 1, 300);
			}
			else if (kind == "meteor")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.7, 0.9, 120);
			}
			else if (kind == "itemPickup")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.3, 0.3, 150);
			}
			else if (kind == "attack")
			{
				Gamepad["rumbleForPlayer"](playerId, 0.6, 0.5, 150);
			}
		}
	}
}
