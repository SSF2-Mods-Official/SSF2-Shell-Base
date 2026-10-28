package
{
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.TimerEvent;
	import flash.media.Sound;
	import flash.utils.Timer;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Now-playing publish, ssf2_stream BGM hold flag, and the in-game song HUD.
	 */
	public class MusicModNowPlaying
	{
		private var mod:MusicPlayerMod;
		/** Tell ssf2_stream menu music to stand down while jukebox owns BGM (incl. local Sound). */
		private static const FLAG_BGM_HOLD:String = "music_player.bgm_hold";

		public function MusicModNowPlaying(owner:MusicPlayerMod)
		{
			mod = owner;
		}

		internal function publishNowPlaying():void
		{
			try
			{
				if (mod.m_host && mod.m_host.setSessionFlag is Function)
				{
					mod.m_host.setSessionFlag("music_player.now_playing", mod.m_currentTitle || "");
					mod.m_host.setSessionFlag("music_player.now_id", mod.m_currentMusicId || "");
				};
			}
			catch (err:*)
			{
			};
			setBgmHold(Boolean(mod.m_currentMusicId) && !mod.m_paused);
		}

		/** Menu BGM (ssf2_stream) must not layer over jukebox local/SoundQueue playback. */
		internal function setBgmHold(on:Boolean):void
		{
			try
			{
				if (mod.m_host && mod.m_host.setSessionFlag is Function)
				{
					mod.m_host.setSessionFlag(FLAG_BGM_HOLD, on ? true : null);
				};
			}
			catch (err:*)
			{
			};
		}

		/** Same music_info clip HudMenu uses in-match (and stream uses for previews). */
		internal function announceSongHud(songName:String):void
		{
			var GC:*;
			var MainCls:*;
			var RM:*;
			var root:*;
			var musicInfo:MovieClip;
			var hudMC:MovieClip;
			var wrap:Sprite;
			var t:Timer;
			if (!songName || songName.length < 1)
			{
				return;
			};
			try
			{
				GC = EngineRefs.ssf2("controllers.GameController");
				if (GC && GC["hud"] && GC["hud"]["displayMusicInfo"])
				{
					GC["hud"]["displayMusicInfo"](songName);
					return;
				};
			}
			catch (hudErr:*)
			{
			};
			try
			{
				MainCls = EngineRefs.ssf2("Main");
				RM = EngineRefs.ssf2("util.ResourceManager");
				root = MainCls ? MainCls["Root"] : null;
				if (!root || !RM)
				{
					return;
				};
				try
				{
					wrap = root.getChildByName("music_player_music_hud") as Sprite;
					if (wrap && wrap.parent)
					{
						wrap.parent.removeChild(wrap);
					};
				}
				catch (rmErr:*)
				{
				};
				hudMC = RM["getLibraryMC"]("menu_hud") as MovieClip;
				if (!hudMC || !hudMC["music_info"])
				{
					return;
				};
				musicInfo = hudMC["music_info"] as MovieClip;
				if (!musicInfo)
				{
					return;
				};
				try
				{
					if (musicInfo.parent)
					{
						musicInfo.parent.removeChild(musicInfo);
					};
				}
				catch (detachErr:*)
				{
				};
				wrap = new Sprite();
				wrap.name = "music_player_music_hud";
				wrap.mouseEnabled = false;
				wrap.mouseChildren = false;
				musicInfo.mouseEnabled = false;
				musicInfo.mouseChildren = false;
				try
				{
					musicInfo["music_info_bar"]["music_info_txt"].text = songName;
				}
				catch (txtErr:*)
				{
				};
				musicInfo.visible = true;
				musicInfo.gotoAndPlay(2);
				wrap.addChild(musicInfo);
				root.addChild(wrap);
				t = new Timer(4000, 1);
				t.addEventListener(TimerEvent.TIMER, function (e:TimerEvent):void
				{
					try
					{
						if (wrap && wrap.parent)
						{
							wrap.parent.removeChild(wrap);
						};
					}
					catch (gone:*)
					{
					};
				});
				t.start();
			}
			catch (menuHudErr:*)
			{
			};
		}
	}
}
