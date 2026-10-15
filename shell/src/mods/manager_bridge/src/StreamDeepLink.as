package
{
	import flash.events.Event;

	/**
	 * Deep-link state machine: wait for home, open CSS, fix up, start the match.
	 * Driven by ENTER_FRAME on the coordinator sprite.
	 */
	internal class StreamDeepLink
	{
		private var core:Ssf2StreamMod;

		public function StreamDeepLink(owner:Ssf2StreamMod)
		{
			core = owner;
		}

		internal function beginDeepLink():void
		{
			core.m_phase = "wait_home";
			core.m_tries = 0;
			core.m_homeReady = false;
			core.m_homeStable = 0;
			core.m_cssMenu = null;
			core.m_fixupTries = 0;
			core.m_matchArmTries = 0;
			core.m_didCssReset = false;
			core.m_didCssShow = false;
			core.m_didMatch = false;
			core.m_matchQueued = false;
			armTick();
		}

		internal function armTick():void
		{
			if (core.hasEventListener(Event.ENTER_FRAME))
			{
				return;
			};
			core.addEventListener(Event.ENTER_FRAME, onTick);
		}

		internal function stopTick():void
		{
			try
			{
				core.removeEventListener(Event.ENTER_FRAME, onTick);
			}
			catch (err:*)
			{
			};
		}

		private function onTick(e:Event):void
		{
			core.m_tries++;
			if (core.m_phase == "idle" || core.m_phase == "done")
			{
				stopTick();
				return;
			};
			if (core.m_tries > 480)
			{
				log("gave up after " + core.m_tries + " frames phase=" + core.m_phase);
				finish();
				return;
			};
			if (core.m_phase == "wait_home")
			{
				tickWaitHome();
			}
			else if (core.m_phase == "open_css")
			{
				tickOpenCss();
			}
			else if (core.m_phase == "fixup")
			{
				tickFixup();
			}
			else if (core.m_phase == "match")
			{
				tickMatch();
			}
			else if (core.m_phase == "open_other")
			{
				if (core.introCtl.wantVaultCostumesBoot())
				{
					if (core.introCtl.openPaletteMaker(core.m_vaultPaletteChar))
					{
						finish();
					};
				}
				else if (core.m_screen == "events")
				{
					if (core.eventsCtl.startEventMatch(core.m_eventId))
					{
						finish();
					};
				}
				else if (core.m_screen == "jukebox")
				{
					// JukeboxMenu is not a MenuController menu. Opening "jukebox"
					// never succeeds and leaves a black stage after the deep link
					// skips the title. Put the title up; the music player covers it.
					// Hold attract until that overlay has opened and closed.
					if (core.m_attract)
					{
						core.m_attract.holdForDeepLink();
					};
					if (core.cssCtl.tryOpenMenuSoft("home"))
					{
						log("jukebox deep link — title up for playlist");
						finish();
					};
				}
				else if (core.cssCtl.tryOpenMenuSoft(LaunchScreen.menuKey(core.m_screen)))
				{
					notifyStageEdit();
					finish();
				};
			};
		}

		private function tickWaitHome():void
		{
			if (!core.m_homeReady)
			{
				if (core.cssCtl.pollAnyNonCssMenuVisible())
				{
					core.m_homeReady = true;
					log("polled home/other menu visible");
				}
				else if (core.m_tries > 120)
				{
					// Fail-open: proceed anyway so launch still attempts CSS.
					core.m_homeReady = true;
					log("home wait timeout — proceeding");
				}
				else
				{
					return;
				};
			};
			core.m_homeStable++;
			if (core.m_homeStable < 10)
			{
				return;
			};
			if (core.cssCtl.isCssScreen(core.m_screen) || core.cssCtl.wantImmediateMatch())
			{
				core.m_phase = "open_css";
				log("home settled — opening CSS/mode select");
			}
			else
			{
				core.m_phase = "open_other";
				log("home settled — opening " + core.m_screen);
			};
		}

		private function tickOpenCss():void
		{
			var menu:*;
			menu = core.cssCtl.showCssMenu(core.cssCtl.cssScreenKey());
			if (!menu)
			{
				return;
			};
			core.m_cssMenu = menu;
			core.m_phase = "fixup";
			core.m_fixupTries = 0;
			log("CSS open ok — fixup");
			core.musicCtl.ensureMenuMusicPlaying();
		}

		private function tickFixup():void
		{
			var menu:*;
			menu = core.m_cssMenu;
			if (!menu)
			{
				menu = core.cssCtl.showCssMenu(core.cssCtl.cssScreenKey());
				core.m_cssMenu = menu;
			};
			if (!menu)
			{
				return;
			};
			core.m_fixupTries++;
			// TrainingMode.updateDisplay() always setPlayerRandom(2) — do not spam it.
			if (!core.cssCtl.menuHasGame(menu))
			{
				core.cssCtl.callUpdateDisplay(menu);
			};
			if (core.cssCtl.isCssReady(menu))
			{
				core.rosterCtl.applyRosterFromMatch(menu);
				log("CSS ready GameObj+boxes after " + core.m_fixupTries + " fixup frames"
					+ " immediate=" + core.cssCtl.wantImmediateMatch());
				if (core.cssCtl.wantImmediateMatch())
				{
					core.m_phase = "match";
					core.m_matchArmTries = 0;
				}
				else
				{
					notifyCssEdit();
					finish();
				};
				return;
			};
			// Re-show once mid-way if still empty.
			if (core.m_fixupTries == 25)
			{
				log("CSS not ready — re-show");
				core.m_didCssShow = false;
				core.m_didCssReset = false;
				core.m_cssMenu = core.cssCtl.showCssMenu(core.cssCtl.cssScreenKey());
			};
			if (core.m_fixupTries > 90)
			{
				log("CSS fixup timeout — leaving incomplete menu");
				core.rosterCtl.applyRosterFromMatch(menu);
				if (core.cssCtl.wantImmediateMatch())
				{
					core.m_phase = "match";
					core.m_matchArmTries = 0;
				}
				else
				{
					notifyCssEdit();
					finish();
				};
			};
		}

		/** Stage select is up for a Manage Stage Select launch. */
		private function notifyStageEdit():void
		{
			if (String(core.m_screen || "").toLowerCase() != "sssedit")
			{
				return;
			};
			log("sssedit menu ready");
			try
			{
				if (core.m_host)
				{
					core.m_host.emit("stage_editor.open", {});
				};
			}
			catch (err:*)
			{
				log("sssedit emit " + err);
			};
		}

		/** Versus grid is up for a Manage Character Select launch. */
		private function notifyCssEdit():void
		{
			if (String(core.m_screen || "").toLowerCase() != "cssedit")
			{
				return;
			};
			log("cssedit menu ready");
			try
			{
				if (core.m_host)
				{
					core.m_host.emit("css_editor.open", {});
				};
			}
			catch (err:*)
			{
				log("cssedit emit " + err);
			};
		}

		private function tickMatch():void
		{
			var key:String;
			core.m_matchArmTries++;
			if (core.m_didMatch || core.m_matchQueued)
			{
				if (core.m_didMatch)
				{
					finish();
				};
				return;
			};
			key = String(core.m_screen || core.cssCtl.cssScreenKey() || "").toLowerCase();
			if (core.cssCtl.isSoloModeScreen(key))
			{
				if (core.matchCtl.tryStartSoloMatchFromCss())
				{
					return;
				};
			}
			else if (core.matchCtl.tryStartMatchFromCss())
			{
				return;
			};
			if (core.m_matchArmTries == 40 && !core.cssCtl.isSoloModeScreen(key))
			{
				log("CSS GameObj match failed — falling back to new Game()");
			};
			if (core.m_matchArmTries >= 40 && !core.cssCtl.isSoloModeScreen(key))
			{
				if (core.matchCtl.tryStartMatchFallback())
				{
					return;
				};
			};
			if (core.m_matchArmTries > 120)
			{
				log("instant match gave up");
				finish();
			};
		}

		internal function finish():void
		{
			core.m_phase = "done";
			core.m_screen = "";
			stopTick();
			if (core.m_bootDeepLink)
			{
				core.m_bootDeepLink = false;
				if (core.m_pendingApply)
				{
					log("dropping deferred apply — boot deep-link finished");
					core.m_pendingApply = null;
				};
				return;
			};
			flushPendingApply();
		}

		private function flushPendingApply():void
		{
			var data:Object;
			if (!core.m_pendingApply)
			{
				return;
			};
			data = core.m_pendingApply;
			core.m_pendingApply = null;
			log("applying deferred launch");
			core.cmdCtl.applyLaunchCmd(data);
		}

		internal function isDeepLinkBusy():Boolean
		{
			return (core.m_phase == "wait_home" || core.m_phase == "open_css" || core.m_phase == "fixup"
				|| core.m_phase == "match" || core.m_phase == "open_other" || core.m_phase == "soft_settle");
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
