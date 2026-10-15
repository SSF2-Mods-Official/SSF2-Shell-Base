package
{
	import flash.filesystem.File;
	import flash.system.System;
	import ssf2mm.shared.EngineRefs;

	/**
	 * Music resource registration (uploads, folders, legacy) and load/unload bookkeeping.
	 */
	public class MusicModTrackLoader
	{
		private var mod:MusicPlayerMod;

		public function MusicModTrackLoader(owner:MusicPlayerMod)
		{
			mod = owner;
		}

		internal function registerKnownUploads():void
		{
			var ids:Array;
			var i:int;
			var tid:String;
			if (!mod.m_catalog)
			{
				return;
			};
			ids = mod.m_catalog.uploadTrackIds();
			i = 0;
			while (i < ids.length)
			{
				tid = String(ids[i]);
				i++;
				registerUploadResource(tid);
			};
		}

		internal function registerKnownFolders():void
		{
			MusicPacks.sync(mod.m_catalog);
			registerKnownUploads();
			registerKnownLegacy();
		}

		internal function registerUploadResource(trackId:String):void
		{
			var RM:*;
			var Res:Class;
			var res:*;
			var path:String;
			var fileName:String;
			if (!trackId)
			{
				return;
			};
			path = mod.m_local.localFileFor(trackId);
			if (!path)
			{
				return;
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				Res = EngineRefs.ssf2("util.Resource") as Class;
				if (RM.getResourceByID(trackId))
				{
					return;
				};
				fileName = path.split("\\").pop().split("/").pop();
				res = new Res(trackId, MusicSongLibrary.UPLOADED_REL + "/" + fileName, null, "", Res["MUSIC"]);
				res.Loaded = true;
				res.SoftFail = true;
				RM.addResource(res);
				trace("[music_player] registered upload " + trackId);
			}
			catch (err:*)
			{
				trace("[music_player] register upload failed: " + err);
			};
		}

		internal function registerKnownLegacy():void
		{
			var ids:Array;
			var i:int;
			var tid:String;
			var swf:File;
			var RM:*;
			var Res:Class;
			var res:*;
			if (!mod.m_catalog)
			{
				return;
			};
			ids = mod.m_catalog.legacyTrackIds();
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				Res = EngineRefs.ssf2("util.Resource") as Class;
			}
			catch (err:*)
			{
				return;
			};
			i = 0;
			while (i < ids.length)
			{
				tid = String(ids[i]);
				i++;
				swf = null;
				if (mod.m_catalog.songMeta[tid] && mod.m_catalog.songMeta[tid].swf)
				{
					swf = new File(String(mod.m_catalog.songMeta[tid].swf));
					if (!swf.exists)
					{
						swf = null;
					};
				};
				if (!swf)
				{
					swf = MusicSongLibrary.swfFileFor(tid);
				};
				if (!swf)
				{
					continue;
				};
				try
				{
					res = RM.getResourceByID(tid);
					if (res)
					{
						res.UrlOverride = swf.url;
						continue;
					};
					res = new Res(tid, MusicSongLibrary.UNPACKED_REL + "/" + tid + ".swf", null, "", Res["MUSIC"]);
					res.UrlOverride = swf.url;
					res.SoftFail = true;
					RM.addResource(res);
				}
				catch (addErr:*)
				{
					trace("[music_player] register legacy failed: " + addErr);
				};
			};
		}

		internal function forgetLoadedMusic(trackId:String):void
		{
			var ix:int;
			if (!trackId || !mod.m_loadedMusicIds)
			{
				return;
			};
			ix = mod.m_loadedMusicIds.indexOf(trackId);
			if (ix >= 0)
			{
				mod.m_loadedMusicIds.splice(ix, 1);
			};
		}

		internal function rememberLoadedMusic(trackId:String):void
		{
			if (!trackId)
			{
				return;
			};
			if (!mod.m_loadedMusicIds)
			{
				mod.m_loadedMusicIds = [];
			};
			if (mod.m_loadedMusicIds.indexOf(trackId) >= 0)
			{
				mod.m_loadedMusicIds.splice(mod.m_loadedMusicIds.indexOf(trackId), 1);
			};
			mod.m_loadedMusicIds.push(trackId);
		}

		/** Keep only the current stock BGM loaded; unload everything else immediately. */
		internal function releaseStaleMusic(prevId:String, keepId:String):void
		{
			var keep:Object;
			var i:int;
			var id:String;
			var drop:Array;
			keep = {};
			if (keepId)
			{
				keep[keepId] = true;
			};
			if (!mod.m_loadedMusicIds)
			{
				mod.m_loadedMusicIds = [];
			};
			drop = [];
			i = 0;
			while (i < mod.m_loadedMusicIds.length)
			{
				id = String(mod.m_loadedMusicIds[i]);
				i++;
				if (!keep[id])
				{
					drop.push(id);
				};
			};
			i = 0;
			while (i < drop.length)
			{
				id = String(drop[i]);
				i++;
				unloadMusicResource(id);
				if (mod.m_loadedMusicIds.indexOf(id) >= 0)
				{
					mod.m_loadedMusicIds.splice(mod.m_loadedMusicIds.indexOf(id), 1);
				};
			};
			try
			{
				System.gc();
			}
			catch (gcErr:*)
			{
			};
			MusicMem.snap("releaseStale", "keep=" + (keepId || "-")
				+ " dropped=" + drop.length + " retained=" + mod.m_loadedMusicIds.length);
		}

		internal function unloadMusicResource(trackId:String, force:Boolean = false):void
		{
			var RM:*;
			var res:*;
			if (!trackId || trackId.indexOf("bgm_upload_") == 0)
			{
				return;
			};
			if (!force && trackId == mod.m_currentMusicId)
			{
				return;
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				if (!RM)
				{
					return;
				};
				res = null;
				if (RM["resourcesHash"] && RM["resourcesHash"][trackId])
				{
					res = RM["resourcesHash"][trackId];
				};
				if (!res && RM["getResourceByID"] is Function)
				{
					res = RM["getResourceByID"](trackId, true);
				};
				if (!res && RM["getResourceByID"] is Function)
				{
					res = RM["getResourceByID"](trackId, false);
				};
				if (!res && RM["getResource"] is Function)
				{
					res = RM["getResource"](trackId);
				};
				if (res && RM["unloadResource"] is Function)
				{
					RM["unloadResource"](res);
				}
				else
				{
					MusicMem.snap("unloadMusic", "id=" + trackId + " ok=0 missing=" + (!res));
				};
				if (RM["unloadOldResources"] is Function)
				{
					RM["unloadOldResources"]();
				};
			}
			catch (err:*)
			{
				MusicMem.snap("unloadMusic", "id=" + trackId + " err=" + err);
			};
		}

		internal function resolveDurationMs(linkage:String):Number
		{
			var RM:*;
			var snd:*;
			if (!linkage)
			{
				return (0);
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				snd = RM.getLibrarySound(linkage);
				if (snd && snd.length > 0)
				{
					return (Number(snd.length));
				};
			}
			catch (err:*)
			{
			};
			return (0);
		}

		internal function resolveMusicLinkage(trackId:String):String
		{
			var RM:*;
			var trackRes:*;
			var m2:*;
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				trackRes = RM.getResourceByID(trackId, true);
				if (!trackRes)
				{
					return null;
				};
				m2 = trackRes.getProp("music");
				if (m2 is String)
				{
					return String(m2);
				};
			}
			catch (err:*)
			{
			};
			return null;
		}

		internal function resolveMusicLoop(trackId:String):Number
		{
			var RM:*;
			var trackRes:*;
			var ov:Number;
			if (mod.m_catalog)
			{
				ov = mod.m_catalog.loopMs(trackId);
				if (ov > 0)
				{
					return (ov);
				};
				ov = mod.m_catalog.effectiveLoopMs(trackId);
				if (ov > 0)
				{
					return (ov);
				};
			};
			try
			{
				RM = EngineRefs.ssf2("util.ResourceManager");
				trackRes = RM.getResourceByID(trackId, true);
				if (trackRes)
				{
					return Number(trackRes.getProp("musicLoop") || 0);
				};
			}
			catch (err:*)
			{
			};
			return (0);
		}
	}
}
