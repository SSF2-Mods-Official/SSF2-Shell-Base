package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

	/**
	 * MusicCacheFilter.keep: stock tracks stay; a cached pack song with no audio (the old list.json
	 * extras) drops; pack and upload tracks whose file exists stay; a deleted pack file drops.
	 */
	public class CacheFilterFixture extends Sprite
	{
		private var m_lines:Array = [];
		private var m_failed:Boolean = false;

		public function CacheFilterFixture()
		{
			addEventListener(Event.ADDED_TO_STAGE, onStage);
		}

		private function onStage(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onStage);
			try
			{
				check();
			}
			catch (err:*)
			{
				fail("threw", String(err));
			};
			m_lines.push(m_failed ? "FAIL" : "OK");
			write("cache-filter-fixture.txt", m_lines.join("\n"));
			NativeApplication.nativeApplication.exit(m_failed ? 1 : 0);
		}

		private function check():void
		{
			var audio:File = write("pack/bgm_packsong.mp3", "x");
			var gone:String = File.applicationStorageDirectory.resolvePath("pack/bgm_removed.mp3").nativePath;
			var stale:Object = {"title": "Final Destination (Tales of Symphonia) Remix", "stage": "towerofsalvation", "swf": "", "file": ""};
			expect("stock track stays", MusicCacheFilter.keep({"title": "Mute City"}, true));
			expect("cached pack song without audio drops", !MusicCacheFilter.keep(stale, false));
			expect("pack song with audio stays", MusicCacheFilter.keep({"swf": audio.nativePath}, false));
			expect("upload with file stays", MusicCacheFilter.keep({"file": audio.nativePath}, false));
			expect("deleted pack file drops", !MusicCacheFilter.keep({"swf": gone}, false));
			expect("null meta drops", !MusicCacheFilter.keep(null, false));
			expect("removed song drops", !MusicCacheFilter.listed(false, false, false));
			expect("song file stays", MusicCacheFilter.listed(true, false, false));
			expect("loaded library sound stays", MusicCacheFilter.listed(false, true, false));
			expect("stock menu stays on the pinned track", MenuReplay.keepId("", "menumusic2", null) == "menumusic2");
			expect("stock menu stays on the live track", MenuReplay.keepId("meleemenu2", "", null) == "meleemenu2");
			expect("first stock menu pick is open", MenuReplay.keepId("", "", null) == "");
			expect("playlist stays on the pinned song", MenuReplay.keepId("bgm_b", "bgm_a", ["bgm_a", "bgm_b"]) == "bgm_a");
			expect("playlist keeps the song already up", MenuReplay.keepId("bgm_b", "", ["bgm_a", "bgm_b"]) == "bgm_b");
			expect("playlist ignores a stock pin", MenuReplay.keepId("", "menumusic1", ["bgm_a"]) == "");
		}

		private function write(rel:String, text:String):File
		{
			var file:File = File.applicationStorageDirectory.resolvePath(rel);
			var fs:FileStream = new FileStream();
			file.parent.createDirectory();
			fs.open(file, FileMode.WRITE);
			fs.writeUTFBytes(text);
			fs.close();
			return (file);
		}

		private function expect(name:String, ok:Boolean):void
		{
			if (ok)
			{
				m_lines.push("OK " + name);
			}
			else
			{
				fail(name, "wrong result");
			};
		}

		private function fail(name:String, why:String):void
		{
			m_failed = true;
			m_lines.push("FAIL " + name + ": " + why);
		}
	}
}
