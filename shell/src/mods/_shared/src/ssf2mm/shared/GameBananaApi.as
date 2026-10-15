package ssf2mm.shared
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.filesystem.File;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.utils.ByteArray;

	/**
	 * Reads one GameBanana category (apiv11) and installs a chosen submission
	 * into a pack folder under the game install. Each mod subclasses this with
	 * its category, user agent, pack folder, pack type and log prefix.
	 */
	public class GameBananaApi
	{
		public static const API:String = "https://gamebanana.com/apiv11";
		private static const PAGE_SIZE:int = 30;

		private var m_categoryId:int;
		private var m_userAgent:String;
		private var m_packDir:String;
		private var m_packType:String;
		private var m_tracePrefix:String;
		private var m_log:Function;
		private var m_lastFolder:String;

		/**
		 * packDir is relative to the app folder ("expansions/events").
		 * packType is the info.json "type" written for a pack with no info.json.
		 * log(msg) gets "gb: ..." lines; with no log they are traced after tracePrefix.
		 */
		public function GameBananaApi(categoryId:int, userAgent:String, packDir:String, packType:String, log:Function = null, tracePrefix:String = "[gamebanana]")
		{
			m_categoryId = categoryId;
			m_userAgent = userAgent;
			m_packDir = packDir;
			m_packType = packType;
			m_log = log;
			m_tracePrefix = tracePrefix;
		}

		/**
		 * onResult(records:Array) where each record is
		 * { modId:int, name:String, creator:String, profileUrl:String, dateAdded:Number }.
		 */
		public function fetchEventList(onResult:Function, onError:Function):void
		{
			var url:String = API + "/Mod/Index?_nPage=1&_nPerpage=" + PAGE_SIZE
				+ "&_aFilters%5BGeneric_Category%5D=" + m_categoryId;
			dbg("fetchEventList " + url);
			getText(url, function (text:String):void
			{
				var parsed:Object;
				var records:Array;
				var out:Array = [];
				var rec:Object;
				var i:int;
				parsed = parseIndex(text);
				if (!parsed)
				{
					dbg("fetchEventList bad json head=" + (text ? text.substr(0, 80) : ""));
					onError("GameBanana reply could not be read");
					return;
				};
				records = parsed._aRecords as Array;
				if (!records)
				{
					dbg("fetchEventList no _aRecords");
					onError("No results");
					return;
				};
				i = 0;
				while (i < records.length)
				{
					rec = records[i] as Object;
					i++;
					if (!rec || String(rec._sModelName) != "Mod")
					{
						continue;
					};
					out.push({
						"modId": int(rec._idRow),
						"name": rec._sName != null ? String(rec._sName) : ("Mod " + rec._idRow),
						"creator": (rec._aSubmitter && rec._aSubmitter._sName) ? String(rec._aSubmitter._sName) : "",
						"profileUrl": rec._sProfileUrl != null ? String(rec._sProfileUrl) : "",
						"dateAdded": Number(rec._tsDateAdded)
					});
				};
				dbg("fetchEventList got " + out.length + " records");
				onResult(out);
			}, onError);
		}

		/**
		 * Download the submission's first usable file and unpack it into the pack folder.
		 * onStatus(message:String, done:Boolean, ok:Boolean) reports progress.
		 */
		public function installMod(modId:int, modName:String, onStatus:Function):void
		{
			var url:String = API + "/Mod/" + modId + "?_csvProperties=_aFiles";
			dbg("installMod " + modId + " files " + url);
			onStatus("Looking up files...", false, false);
			getText(url, function (text:String):void
			{
				var parsed:Object = JsonFile.parse(text);
				var pick:Object;
				if (!parsed)
				{
					dbg("installMod bad json head=" + (text ? text.substr(0, 80) : ""));
					onStatus("Bad file list from GameBanana", true, false);
					return;
				};
				pick = pickFile(parsed._aFiles as Array);
				if (!pick)
				{
					dbg("installMod no usable file for " + modId);
					onStatus("No .zip or .swf attached - open on GameBanana", true, false);
					return;
				};
				dbg("installMod picked " + pick._sFile + " (" + pick._nFilesize + " bytes)");
				downloadAndUnpack(String(pick._sDownloadUrl), String(pick._sFile), modName, modId, int(pick._idRow), Number(pick._nFilesize), onStatus);
			}, function (msg:String):void
			{
				onStatus(msg, true, false);
			});
		}

		/** Installed packs that recorded a GameBanana file id. */
		public function installedPacks():Array
		{
			var root:File = writableRoot();
			var listing:Array;
			var out:Array = [];
			var i:int;
			var dir:File;
			var info:Object;
			if (!root.exists)
			{
				return out;
			};
			listing = root.getDirectoryListing();
			i = 0;
			while (i < listing.length)
			{
				dir = listing[i] as File;
				i++;
				if (!dir || !dir.isDirectory || dir.name.charAt(0) == "_" || dir.name.charAt(0) == ".")
				{
					continue;
				};
				info = JsonFile.read(dir.resolvePath("info.json"));
				if (!info || int(info.gbModId) <= 0)
				{
					continue;
				};
				out.push({
					"folder": dir.name,
					"modId": int(info.gbModId),
					"fileId": int(info.gbFileId),
					"name": info.name != null ? String(info.name) : dir.name
				});
			};
			return out;
		}

		public function fetchLatestFile(modId:int, onOk:Function, onError:Function):void
		{
			var url:String = API + "/Mod/" + modId + "?_csvProperties=_aFiles";
			getText(url, function (text:String):void
			{
				var parsed:Object = JsonFile.parse(text);
				var pick:Object;
				if (!parsed)
				{
					onError("Bad file list");
					return;
				};
				pick = pickFile(parsed._aFiles as Array);
				if (!pick)
				{
					onError("No file");
					return;
				};
				onOk({
					"modId": modId,
					"fileId": int(pick._idRow),
					"fileSize": Number(pick._nFilesize),
					"name": String(pick._sFile)
				});
			}, onError);
		}

		// --------------------------------------------------------------- http

		/** GET as text; a leading BOM is stripped. onOk(text:String), onError(message:String). */
		public function getText(url:String, onOk:Function, onError:Function):void
		{
			request(url, URLLoaderDataFormat.TEXT, function (loader:URLLoader):void
			{
				onOk(loaderText(loader.data));
			}, onError);
		}

		/** GET as bytes. onOk(bytes:ByteArray), onError(message:String). */
		public function getBytes(url:String, onOk:Function, onError:Function):void
		{
			request(url, URLLoaderDataFormat.BINARY, function (loader:URLLoader):void
			{
				onOk(loader.data as ByteArray);
			}, onError);
		}

		private function request(url:String, format:String, onOk:Function, onError:Function):void
		{
			var loader:URLLoader = new URLLoader();
			var req:URLRequest = new URLRequest(url);
			try
			{
				req.requestHeaders.push(new URLRequestHeader("User-Agent", m_userAgent));
			}
			catch (headerErr:*)
			{
				dbg("User-Agent header rejected: " + headerErr);
			};
			var release:Function;
			var onComplete:Function;
			var onIo:Function;
			var onSecurity:Function;
			loader.dataFormat = format;
			release = function ():void
			{
				loader.removeEventListener(Event.COMPLETE, onComplete);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, onIo);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurity);
			};
			onComplete = function (e:Event):void
			{
				release();
				try
				{
					onOk(loader);
				}
				catch (err:*)
				{
					dbg("response handler failed: " + err);
					onError("Failed: " + err);
				};
				loader.data = null;
			};
			onIo = function (e:IOErrorEvent):void
			{
				release();
				dbg("IO error " + url + ": " + e.text);
				onError("Network error - are you online?");
			};
			onSecurity = function (e:SecurityErrorEvent):void
			{
				release();
				dbg("security error " + url + ": " + e.text);
				onError("Blocked by security policy");
			};
			loader.addEventListener(Event.COMPLETE, onComplete);
			loader.addEventListener(IOErrorEvent.IO_ERROR, onIo);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurity);
			try
			{
				loader.load(req);
			}
			catch (err:*)
			{
				release();
				dbg("load threw " + url + ": " + err);
				onError("Request failed: " + err);
			};
		}

		private static function loaderText(data:*):String
		{
			var bytes:ByteArray;
			var text:String;
			if (data is ByteArray)
			{
				bytes = data as ByteArray;
				bytes.position = 0;
				text = bytes.readUTFBytes(bytes.length);
			}
			else
			{
				text = data != null ? String(data) : "";
			};
			if (text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			{
				text = text.substr(1);
			};
			return text;
		}

		/** Mod/Index reply. An empty category that does not parse still reads as zero records. */
		private static function parseIndex(text:String):Object
		{
			var parsed:Object = JsonFile.parse(text);
			if (parsed)
			{
				return parsed;
			};
			if (text && (text.indexOf("\"_nRecordCount\": 0") >= 0 || text.indexOf("\"_nRecordCount\":0") >= 0))
			{
				return {"_aRecords": []};
			};
			return null;
		}

		// ------------------------------------------------------------ install

		/** Prefer .zip (we can unpack it), then a bare .swf. Skip .rar/.7z — no decoder. */
		private function pickFile(files:Array):Object
		{
			var i:int;
			var f:Object;
			var name:String;
			var swf:Object = null;
			if (!files)
			{
				return null;
			};
			i = 0;
			while (i < files.length)
			{
				f = files[i] as Object;
				i++;
				if (!f || !f._sDownloadUrl)
				{
					continue;
				};
				name = String(f._sFile).toLowerCase();
				if (endsWith(name, ".zip"))
				{
					return f;
				};
				if (!swf && endsWith(name, ".swf"))
				{
					swf = f;
				};
			};
			return swf;
		}

		private function downloadAndUnpack(downloadUrl:String, fileName:String, modName:String, modId:int, fileId:int, fileSize:Number, onStatus:Function):void
		{
			dbg("download " + downloadUrl);
			onStatus("Downloading...", false, false);
			getBytes(downloadUrl, function (bytes:ByteArray):void
			{
				var root:File;
				var target:File;
				try
				{
					root = writableRoot();
					if (endsWith(fileName.toLowerCase(), ".swf"))
					{
						target = root.resolvePath(safeName(modName) + "/" + safeName(fileName, true));
						writeFile(target, bytes);
						dbg("installed swf -> " + target.nativePath);
						onStatus("Download complete", true, true);
						return;
					};
					onStatus("Unpacking...", false, false);
					if (unzipInto(bytes, root, safeName(modName)))
					{
						stampPack(root, m_lastFolder, modId, fileId, fileSize);
						onStatus("Download complete", true, true);
					}
					else
					{
						onStatus("Archive had no event files", true, false);
					};
				}
				catch (err:*)
				{
					dbg("install failed: " + err);
					onStatus("Install failed: " + err, true, false);
				};
			}, function (msg:String):void
			{
				onStatus(msg, true, false);
			});
		}

		/** Writes every usable zip entry under root. Returns true if at least one file was written. */
		private function unzipInto(zip:ByteArray, root:File, fallbackFolder:String):Boolean
		{
			var entries:Array = ZipReader.entries(zip, dbg);
			var entry:Object;
			var prefix:String;
			var written:int = 0;
			var path:String;
			var data:ByteArray;
			var i:int;
			m_lastFolder = fallbackFolder;
			if (!entries || entries.length == 0)
			{
				return false;
			};

			// A pack zip normally has its own top-level folder; keep it, otherwise invent one.
			prefix = ZipReader.commonTopFolder(entries);
			i = 0;
			while (i < entries.length)
			{
				entry = entries[i];
				i++;
				path = String(entry.name);
				if (endsWith(path, "/") || endsWith(path, "\\"))
				{
					continue;
				};
				if (isDevOnlyPath(path))
				{
					continue;
				};
				if (!prefix)
				{
					path = fallbackFolder + "/" + path;
				};
				data = ZipReader.read(zip, entry, dbg);
				if (!data)
				{
					continue;
				};
				if (path.indexOf("/") > 0)
				{
					m_lastFolder = path.substring(0, path.indexOf("/"));
				};
				writeFile(root.resolvePath(path), data);
				written++;
			};
			dbg("unzip: wrote " + written + " files");
			return written > 0;
		}

		/**
		 * AIR throws SecurityError: fileWriteResource on File.applicationDirectory
		 * handles. A File built from the native path is writable when the install
		 * folder itself is user-writable (dev / sideload layout).
		 */
		private function writableRoot():File
		{
			var rel:File = File.applicationDirectory.resolvePath(m_packDir);
			return new File(rel.nativePath);
		}

		private function stampPack(root:File, folder:String, modId:int, fileId:int, fileSize:Number):void
		{
			var dir:File;
			var info:Object;
			if (!folder)
			{
				return;
			};
			dir = new File(root.resolvePath(folder).nativePath);
			info = JsonFile.read(dir.resolvePath("info.json"));
			if (!info)
			{
				info = {"name": folder, "type": m_packType, "enabled": true};
			};
			info.gbModId = modId;
			info.gbFileId = fileId;
			info.gbFileSize = fileSize;
			if (!JsonFile.write(dir.resolvePath("info.json"), info))
			{
				throw new Error("could not write " + folder + "/info.json");
			};
			dbg("stamped " + folder + " gbFileId=" + fileId);
		}

		/** Throws when the file cannot be written, so the install reports the failure. */
		private function writeFile(target:File, data:ByteArray):void
		{
			if (!JsonFile.writeBytes(new File(target.nativePath), data))
			{
				throw new Error("could not write " + target.nativePath);
			};
		}

		/** Source and build scripts stay off public packs. build.bat can contain a local path. */
		private static function isDevOnlyPath(path:String):Boolean
		{
			var lower:String = path.toLowerCase().split("\\").join("/");
			var name:String = lower;
			var slash:int = lower.lastIndexOf("/");
			if (lower.indexOf("/src/") >= 0 || lower.indexOf("src/") == 0)
			{
				return true;
			};
			if (slash >= 0)
			{
				name = lower.substring(slash + 1);
			};
			return name == "build.bat";
		}

		private static function safeName(value:String, keepDot:Boolean = false):String
		{
			var out:String = value != null ? value : "";
			out = out.split("\\").join("_").split("/").join("_").split(":").join("_");
			out = out.split("*").join("_").split("?").join("_").split("\"").join("_");
			out = out.split("<").join("_").split(">").join("_").split("|").join("_");
			if (!keepDot)
			{
				out = out.split(".").join("_");
			};
			out = out.replace(/^\s+|\s+$/g, "");
			return out.length > 0 ? out : "downloaded_event";
		}

		private static function endsWith(value:String, suffix:String):Boolean
		{
			return Boolean(value) && value.length >= suffix.length
				&& value.lastIndexOf(suffix) == value.length - suffix.length;
		}

		private function dbg(msg:String):void
		{
			if (m_log != null)
			{
				m_log("gb: " + msg);
			}
			else
			{
				trace(m_tracePrefix + " gb: " + msg);
			};
		}
	}
}
