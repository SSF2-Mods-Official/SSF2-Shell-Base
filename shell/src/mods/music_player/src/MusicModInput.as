package
{
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.ui.Keyboard;
	import flash.utils.getTimer;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Pad/keyboard entry points: F3 key hook, Taunt while paused, Taunt+Grab chord in menus.
	 */
	public class MusicModInput
	{
		private var mod:MusicPlayerMod;
		private var m_pauseTauntArmed:Boolean;
		private var m_tauntWasDown:Boolean;
		private var m_menuChordArmed:Boolean;
		private var m_menuChordWasBoth:Boolean;
		private var m_saveDataCls:Class;
		private var m_muteChordAt:int;

		public function MusicModInput(owner:MusicPlayerMod)
		{
			mod = owner;
			m_pauseTauntArmed = false;
			m_tauntWasDown = false;
			m_menuChordArmed = false;
			m_menuChordWasBoth = false;
			m_muteChordAt = -10000;
		}

		internal function onKeyEvent(ctx:Object):void
		{
			var e:KeyboardEvent;
			if (!ctx)
			{
				return;
			};
			e = (ctx.event as KeyboardEvent) || (ctx["e"] as KeyboardEvent);
			if (e && e.keyCode == Keyboard.M && e.ctrlKey && e.shiftKey)
			{
				if (getTimer() - m_muteChordAt < 400)
				{
					ctx.cancel = true;
					ctx.consume = true;
					return;
				};
				m_muteChordAt = getTimer();
				mod.toggleBgmMute();
				ctx.cancel = true;
				ctx.consume = true;
				return;
			};
			if (!e || e.keyCode != Keyboard.F3)
			{
				return;
			};
			if (mod.m_ui && mod.m_ui.isOpen())
			{
				mod.m_ui.close();
			}
			else
			{
				mod.openDeepLink(mod.m_match.isInMatch() ? mod.m_match.currentStageId() : null, mod.m_match.isInMatch(), false);
			};
			ctx.cancel = true;
			ctx.consume = true;
		}

		/** While the match is paused, Taunt opens My Jukebox (match pick). */
		internal function onMatchPause(ctx:Object):void
		{
			armPauseTaunt();
		}

		internal function onMatchResume(ctx:Object):void
		{
			disarmPauseTaunt();
		}

		private function armPauseTaunt():void
		{
			var MainCls:*;
			var root:*;
			if (m_pauseTauntArmed)
			{
				return;
			};
			m_tauntWasDown = tauntDown();
			try
			{
				MainCls = EngineRefs.ssf2("Main");
				root = MainCls ? MainCls["Root"] : null;
				if (!root)
				{
					return;
				};
				root.addEventListener(Event.ENTER_FRAME, onPauseTauntFrame, false, 0, true);
				m_pauseTauntArmed = true;
			}
			catch (err:*)
			{
			};
		}

		internal function disarmPauseTaunt():void
		{
			var MainCls:*;
			var root:*;
			if (!m_pauseTauntArmed)
			{
				return;
			};
			m_pauseTauntArmed = false;
			try
			{
				MainCls = EngineRefs.ssf2("Main");
				root = MainCls ? MainCls["Root"] : null;
				if (root)
				{
					root.removeEventListener(Event.ENTER_FRAME, onPauseTauntFrame);
				};
			}
			catch (err:*)
			{
			};
		}

		private function onPauseTauntFrame(e:Event):void
		{
			var down:Boolean;
			if (!matchIsPaused())
			{
				disarmPauseTaunt();
				return;
			};
			if (mod.m_ui && mod.m_ui.isOpen())
			{
				return;
			};
			down = tauntDown();
			if (down && !m_tauntWasDown)
			{
				mod.openDeepLink(mod.m_match.currentStageId(), true, false);
			};
			m_tauntWasDown = down;
		}

		private function matchIsPaused():Boolean
		{
			var sd:*;
			sd = liveStageData();
			try
			{
				return Boolean(sd && sd["Paused"]);
			}
			catch (err:*)
			{
			};
			return false;
		}

		private function liveStageData():*
		{
			var GC:*;
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				return GC ? GC["stageData"] : null;
			}
			catch (err:*)
			{
			};
			return null;
		}

		private function tauntDown():Boolean
		{
			var sd:*;
			var pid:int;
			var ctrl:*;
			sd = liveStageData();
			if (!sd)
			{
				return false;
			};
			try
			{
				pid = int(sd["PausedID"]);
				if (pid < 1)
				{
					pid = 1;
				};
				ctrl = sd["getControllerNum"](pid);
				if (!ctrl)
				{
					return false;
				};
				return Boolean(ctrl["IsDown"](ctrl["_TAUNT"] || "TAUNT"));
			}
			catch (err:*)
			{
			};
			return false;
		}

		/** Menus only: Taunt+Grab chord opens My Jukebox (same idea as in-player chords). */
		internal function armMenuJukeboxChord():void
		{
			var MainCls:*;
			var root:*;
			if (m_menuChordArmed)
			{
				return;
			};
			m_menuChordWasBoth = menuPadChordDown();
			try
			{
				MainCls = EngineRefs.ssf2("Main");
				root = MainCls ? MainCls["Root"] : null;
				if (!root)
				{
					return;
				};
				root.addEventListener(Event.ENTER_FRAME, onMenuJukeboxChordFrame, false, 0, true);
				m_menuChordArmed = true;
			}
			catch (err:*)
			{
			};
		}

		internal function disarmMenuJukeboxChord():void
		{
			var MainCls:*;
			var root:*;
			if (!m_menuChordArmed)
			{
				return;
			};
			m_menuChordArmed = false;
			try
			{
				MainCls = EngineRefs.ssf2("Main");
				root = MainCls ? MainCls["Root"] : null;
				if (root)
				{
					root.removeEventListener(Event.ENTER_FRAME, onMenuJukeboxChordFrame);
				};
			}
			catch (err:*)
			{
			};
		}

		private function onMenuJukeboxChordFrame(e:Event):void
		{
			var both:Boolean;
			if (mod.m_match.isInMatch())
			{
				m_menuChordWasBoth = false;
				return;
			};
			if ((mod.m_ui && mod.m_ui.isOpen()) || (mod.m_menu && mod.m_menu.isOpen()))
			{
				m_menuChordWasBoth = menuPadChordDown();
				return;
			};
			both = menuPadChordDown();
			if (both && !m_menuChordWasBoth)
			{
				mod.openDeepLink(null, false, false);
			};
			m_menuChordWasBoth = both;
		}

		private function menuPadChordDown():Boolean
		{
			return menuPadDown("TAUNT") && menuPadDown("GRAB");
		}

		private function menuPadDown(which:String):Boolean
		{
			var SD:Class;
			var list:*;
			var i:int;
			var c:*;
			try
			{
				if (!m_saveDataCls)
				{
					m_saveDataCls = EngineRefs.ssf2("util.SaveData") as Class;
				};
				SD = m_saveDataCls;
				list = SD ? SD["Controllers"] : null;
				if (!list)
				{
					return false;
				};
				i = 0;
				while (i < list.length)
				{
					c = list[i];
					i++;
					if (!c || !(c["IsDown"] is Function))
					{
						continue;
					};
					if (which == "TAUNT" && Boolean(c["IsDown"](c["_TAUNT"], true)))
					{
						return true;
					};
					if (which == "GRAB" && Boolean(c["IsDown"](c["_GRAB"], true)))
					{
						return true;
					};
				};
			}
			catch (err:*)
			{
			};
			return false;
		}

		internal function chordHas(chords:Array, name:String):Boolean
		{
			var i:int;
			if (!chords)
			{
				return (false);
			};
			i = 0;
			while (i < chords.length)
			{
				if (String(chords[i]).toUpperCase() == name)
				{
					return (true);
				};
				i++;
			};
			return (false);
		}
	}
}
