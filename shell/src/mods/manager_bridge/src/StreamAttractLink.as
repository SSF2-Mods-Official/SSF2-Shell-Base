package
{
	import flash.media.SoundMixer;
	import flash.utils.setTimeout;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Wires AttractMode to the boot intro: arm on title, pick a random intro,
	 * abort intro playback.
	 */
	internal class StreamAttractLink
	{
		private var core:Ssf2StreamMod;

		public function StreamAttractLink(owner:Ssf2StreamMod)
		{
			core = owner;
		}

		/** Attract on title whenever enabled — also after deep-link boots once the user opens title. */
		internal function armAttractIfNeeded():void
		{
			if (core.m_attract)
			{
				try
				{
					core.m_attract.detach();
				}
				catch (e0:*)
				{
				};
				core.m_attract = null;
			};
			if (!core.m_attractEnabled || core.cssCtl.wantImmediateMatch())
			{
				log("attract off (enabled=" + core.m_attractEnabled
					+ " match=" + core.cssCtl.wantImmediateMatch()
					+ " screen=" + (core.m_screen || "home") + ")");
				return;
			};
			try
			{
				core.m_attract = new AttractMode(log, attractPickAndPlayIntro, attractAbortIntro);
				core.m_attract.setEnabled(true);
				core.m_attract.attach(core.m_host);
				log("attract armed (screen=" + (core.m_screen || "home") + " deep=" + core.introCtl.wantDeepLinkBoot() + ")");
			}
			catch (err:*)
			{
				log("attract arm fail: " + err);
				core.m_attract = null;
			};
		}

		/** Attract playlist: pick a random boot intro and play it. */
		private function attractPickAndPlayIntro():Boolean
		{
			var savedIntro:String;
			var savedPath:String;
			var pick:String;
			savedIntro = core.m_bootIntro;
			savedPath = core.m_bootIntroPath;
			try
			{
				if (!core.m_randomPool || core.m_randomPool.length < 1)
				{
					core.m_randomPool = buildRandomPoolFromBootData(null);
				};
				core.m_bootIntro = "random";
				core.m_bootIntroPath = "";
				core.introCtl.pickRandomBootIntroIfNeeded();
				pick = String(core.m_bootIntro || "").toLowerCase();
				// Attract: "default" means stock beta intro (boot "default" is disclaimer chain).
				if (pick == "default")
				{
					pick = "intro3";
					core.m_bootIntro = "intro3";
				};
				if (pick == "skip" || pick == "none" || pick.length < 1)
				{
					log("attract intro skip (no pick)");
				}
				else if (core.introCtl.startBootIntroPlayback(pick, false))
				{
					core.m_bootIntro = savedIntro;
					core.m_bootIntroPath = savedPath;
					return (true);
				}
				else
				{
					log("attract intro failed pick=" + pick);
				};
			}
			catch (err:*)
			{
				log("attract intro: " + err);
			};
			core.m_bootIntro = savedIntro;
			core.m_bootIntroPath = savedPath;
			return (false);
		}

		/**
		 * Build [{bootIntro, bootIntroPath?}] from boot.json randomPoolKeys + customs,
		 * falling back to stock intro1/2/3 + all customs.
		 */
		internal function buildRandomPoolFromBootData(data:Object):Array
		{
			var out:Array;
			var keys:Array;
			var customs:Array;
			var byId:Object;
			var i:int;
			var key:String;
			var id:String;
			var c:Object;
			var path:String;
			var entry:Object;
			out = [];
			byId = {};
			customs = [];
			keys = null;
			try
			{
				if (data && data.customs is Array)
				{
					customs = data.customs as Array;
				};
			}
			catch (cErr:*)
			{
			};
			i = 0;
			while (i < customs.length)
			{
				c = customs[i] as Object;
				i++;
				if (!c || !c.id)
				{
					continue;
				};
				byId[String(c.id).toLowerCase()] = c;
			};
			try
			{
				if (data && data.randomPoolKeys is Array)
				{
					keys = data.randomPoolKeys as Array;
				};
			}
			catch (kErr:*)
			{
			};
			if (!keys || keys.length < 1)
			{
				keys = ["default", "intro1", "intro2", "intro3"];
				for (id in byId)
				{
					keys.push("custom:" + id);
				};
			}
			else
			{
				// Attract should rotate stock intros too even if the Configure
				// random-pool UI only checked customs.
				keys = keys.concat(["intro1", "intro2", "intro3"]);
			};
			// Deduplicate keys while preserving order.
			var seen:Object = {};
			var deduped:Array = [];
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i] || "").toLowerCase();
				i++;
				if (!key || seen[key])
				{
					continue;
				};
				seen[key] = true;
				deduped.push(key);
			};
			keys = deduped;
			i = 0;
			while (i < keys.length)
			{
				key = String(keys[i] || "").toLowerCase();
				i++;
				if (!key || key == "random" || key == "skip" || key == "none")
				{
					continue;
				};
				if (key == "default" || key == "intro1" || key == "v8"
					|| key == "intro2" || key == "v9"
					|| key == "intro3" || key == "beta")
				{
					out.push({"bootIntro": key == "default" ? "intro3"
						: (key == "v8" ? "intro1" : (key == "v9" ? "intro2" : (key == "beta" ? "intro3" : key)))});
					continue;
				};
				if (key.indexOf("custom:") != 0)
				{
					continue;
				};
				id = key.substring(7);
				c = byId[id];
				path = c && c.path ? String(c.path) : "";
				if (path.length < 1)
				{
					continue;
				};
				entry = {"bootIntro": "custom:" + id, "bootIntroPath": path};
				if (c && c.label)
				{
					entry.bootIntroLabel = String(c.label);
				};
				out.push(entry);
			};
			return (out);
		}

		/** Attract cancel during intro — tear down custom NetStream / stock intro menus. */
		private function attractAbortIntro():void
		{
			// Always force-stop Intro3 timeline + mixer (no early-out on active flags).
			try
			{
				core.introCtl.stopActiveIntroPlayback();
			}
			catch (stopErr:*)
			{
				log("attractAbortIntro stopActive: " + stopErr);
			};
			try
			{
				SoundMixer.stopAll();
			}
			catch (mixErr:*)
			{
			};
			// Intro3 can restart timeline channels a frame later — second kill.
			try
			{
				setTimeout(function ():void
				{
					try
					{
						SoundMixer.stopAll();
					}
					catch (e2:*)
					{
					};
					try
					{
						var SQ:* = EngineRefs.SoundQueue;
						if (SQ && SQ["instance"] && SQ["instance"]["stopAllSounds"] is Function)
						{
							SQ["instance"]["stopAllSounds"]();
						};
					}
					catch (e3:*)
					{
					};
				}, 120);
			}
			catch (delayErr:*)
			{
			};
			if (core.m_customIntroActive || core.m_introOverlay)
			{
				// Media only — AttractMode.showTitle owns the destination.
				core.m_customIntroActive = false;
				core.introCtl.finishCustomBootIntro();
				return;
			};
		}

		private function log(msg:String):void
		{
			core.log(msg);
		}
	}
}
