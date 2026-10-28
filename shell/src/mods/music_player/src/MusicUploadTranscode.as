package
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.IOErrorEvent;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	/**
	 * Flash/AIR Sound only plays real MPEG Layer III.
	 * Many "mp3" downloads are actually M4A/MP4 (ftyp) — convert via ffmpeg when needed.
	 */
	public class MusicUploadTranscode
	{
		private static var s_ffmpeg:File;
		private static var s_ffmpegChecked:Boolean;

		public static function isFlashMp3(file:File):Boolean
		{
			var stream:FileStream;
			var buf:ByteArray;
			var b0:int;
			var b1:int;
			var i:int;
			var tag:String;
			if (!file || !file.exists)
			{
				return (false);
			};
			try
			{
				stream = new FileStream();
				stream.open(file, FileMode.READ);
				buf = new ByteArray();
				stream.readBytes(buf, 0, Math.min(64, stream.bytesAvailable));
				stream.close();
			}
			catch (err:*)
			{
				return (false);
			};
			if (buf.length < 4)
			{
				return (false);
			};
			// ID3v2
			if (buf[0] == 0x49 && buf[1] == 0x44 && buf[2] == 0x33)
			{
				return (true);
			};
			// MPEG frame sync
			b0 = buf[0] & 0xFF;
			b1 = buf[1] & 0xFF;
			if (b0 == 0xFF && (b1 & 0xE0) == 0xE0)
			{
				return (true);
			};
			// Skip ID3-less files that start with junk then frames — scan a bit
			i = 0;
			while (i + 1 < buf.length)
			{
				if ((buf[i] & 0xFF) == 0xFF && (buf[i + 1] & 0xE0) == 0xE0)
				{
					return (true);
				};
				i++;
			};
			// ftyp → MP4/M4A/DASH
			if (buf.length >= 8)
			{
				tag = String.fromCharCode(buf[4], buf[5], buf[6], buf[7]);
				if (tag == "ftyp")
				{
					return (false);
				};
			};
			return (false);
		}

		public static function ensureFlashMp3(src:File, destMp3:File, onDone:Function, onFail:Function):void
		{
			var ff:File;
			if (!src || !src.exists)
			{
				if (onFail != null)
				{
					onFail("missing source");
				};
				return;
			};
			if (isFlashMp3(src) && (!destMp3 || destMp3.nativePath == src.nativePath))
			{
				if (onDone != null)
				{
					onDone(src);
				};
				return;
			};
			if (isFlashMp3(src) && destMp3 && destMp3.nativePath != src.nativePath)
			{
				try
				{
					src.copyTo(destMp3, true);
					if (onDone != null)
					{
						onDone(destMp3);
					};
					return;
				}
				catch (copyErr:*)
				{
				};
			};
			ff = findFfmpeg();
			if (!ff)
			{
				if (onFail != null)
				{
					onFail("This file isn't a real MP3 (often M4A renamed .mp3). Install ffmpeg or convert it first.");
				};
				return;
			};
			runFfmpeg(ff, src, destMp3, onDone, onFail);
		}

		private static function findFfmpeg():File
		{
			var f:File;
			var home:String;
			var candidates:Array;
			var i:int;
			var p:String;
			if (s_ffmpegChecked)
			{
				return (s_ffmpeg && s_ffmpeg.exists ? s_ffmpeg : null);
			};
			s_ffmpegChecked = true;
			s_ffmpeg = null;
			if (!NativeProcess.isSupported)
			{
				return (null);
			};
			candidates = [];
			try
			{
				home = File.userDirectory.nativePath;
				candidates.push(home + "\\AppData\\Local\\Microsoft\\WinGet\\Links\\ffmpeg.exe");
			}
			catch (hErr:*)
			{
			};
			candidates.push("C:\\ffmpeg\\bin\\ffmpeg.exe");
			candidates.push("C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe");
			candidates.push("C:\\Program Files (x86)\\ffmpeg\\bin\\ffmpeg.exe");
			// WinGet Gyan package (versioned folder) — scan Links first, then one level under Packages
			try
			{
				f = File.userDirectory.resolvePath("AppData\\Local\\Microsoft\\WinGet\\Packages");
				if (f.exists)
				{
					scanWingetForFfmpeg(f, candidates);
				};
			}
			catch (wErr:*)
			{
			};
			i = 0;
			while (i < candidates.length)
			{
				p = String(candidates[i]);
				i++;
				try
				{
					f = new File(p);
					if (f.exists)
					{
						s_ffmpeg = f;
						trace("[music_player] ffmpeg=" + f.nativePath);
						return (s_ffmpeg);
					};
				}
				catch (e:*)
				{
				};
			};
			// Last resort: cmd where
			return (null);
		}

		private static function scanWingetForFfmpeg(packagesDir:File, out:Array):void
		{
			var kids:Array;
			var i:int;
			var kid:File;
			var bin:File;
			try
			{
				kids = packagesDir.getDirectoryListing();
			}
			catch (err:*)
			{
				return;
			};
			i = 0;
			while (kids && i < kids.length)
			{
				kid = kids[i] as File;
				i++;
				if (!kid || !kid.isDirectory)
				{
					continue;
				};
				if (String(kid.name).toLowerCase().indexOf("ffmpeg") < 0)
				{
					continue;
				};
				bin = kid.resolvePath("ffmpeg-8.0.1-full_build\\bin\\ffmpeg.exe");
				if (bin.exists)
				{
					out.push(bin.nativePath);
				};
				bin = kid.resolvePath("bin\\ffmpeg.exe");
				if (bin.exists)
				{
					out.push(bin.nativePath);
				};
				// Any nested */bin/ffmpeg.exe one level down
				try
				{
					var nested:Array = kid.getDirectoryListing();
					var j:int = 0;
					var n:File;
					while (nested && j < nested.length)
					{
						n = nested[j] as File;
						j++;
						if (n && n.isDirectory)
						{
							bin = n.resolvePath("bin\\ffmpeg.exe");
							if (bin.exists)
							{
								out.push(bin.nativePath);
							};
						};
					};
				}
				catch (nErr:*)
				{
				};
			};
		}

		private static function runFfmpeg(ff:File, src:File, dest:File, onDone:Function, onFail:Function):void
		{
			var info:NativeProcessStartupInfo;
			var args:Vector.<String>;
			var proc:NativeProcess;
			var tmp:File;
			var errBuf:String;
			tmp = new File(dest.nativePath + ".tmp.mp3");
			args = new Vector.<String>();
			args.push("-y");
			args.push("-i");
			args.push(src.nativePath);
			args.push("-vn");
			args.push("-codec:a");
			args.push("libmp3lame");
			args.push("-b:a");
			args.push("192k");
			args.push("-ar");
			args.push("44100");
			args.push("-ac");
			args.push("2");
			args.push(tmp.nativePath);
			info = new NativeProcessStartupInfo();
			info.executable = ff;
			info.arguments = args;
			proc = new NativeProcess();
			errBuf = "";
			proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, function (e:ProgressEvent):void
			{
				try
				{
					errBuf += proc.standardError.readUTFBytes(proc.standardError.bytesAvailable);
				}
				catch (rErr:*)
				{
				};
			});
			proc.addEventListener(NativeProcessExitEvent.EXIT, function (e:NativeProcessExitEvent):void
			{
				var ok:Boolean;
				ok = e.exitCode == 0 && tmp.exists && tmp.size > 1024;
				if (ok)
				{
					try
					{
						if (dest.exists)
						{
							dest.deleteFile();
						};
						tmp.moveTo(dest, true);
						if (src.nativePath != dest.nativePath && src.exists
							&& String(src.extension).toLowerCase() != "mp3")
						{
							// leave non-mp3 source; dest is the playable copy
						}
						else if (src.nativePath != dest.nativePath && src.exists)
						{
							try
							{
								src.deleteFile();
							}
							catch (delErr:*)
							{
							};
						};
						if (onDone != null)
						{
							onDone(dest);
						};
						return;
					}
					catch (mvErr:*)
					{
						ok = false;
						errBuf += " " + mvErr;
					};
				};
				try
				{
					if (tmp.exists)
					{
						tmp.deleteFile();
					};
				}
				catch (tErr:*)
				{
				};
				trace("[music_player] ffmpeg failed code=" + e.exitCode + " " + errBuf);
				if (onFail != null)
				{
					onFail("Could not convert audio to MP3 (ffmpeg exit " + e.exitCode + ").");
				};
			});
			proc.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, function (e:IOErrorEvent):void
			{
				if (onFail != null)
				{
					onFail("ffmpeg io error");
				};
			});
			try
			{
				proc.start(info);
			}
			catch (startErr:*)
			{
				trace("[music_player] ffmpeg start failed: " + startErr);
				if (onFail != null)
				{
					onFail(String(startErr));
				};
			};
		}
	}
}
