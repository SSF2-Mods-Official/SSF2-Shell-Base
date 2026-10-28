package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import ssf2mm.shared.JsonFile;
	import ssf2mm.shared.MusicOverrideCodec;

	/**
	 * MusicOverrideCodec: plain tracks pass through, "track|bg=id" splits, and the music and
	 * camera mods can write their part in either order without losing the other.
	 */
	public class MusicOverrideCodecFixture extends Sprite
	{
		private var m_lines:Array = [];
		private var m_failed:Boolean = false;

		public function MusicOverrideCodecFixture()
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
			JsonFile.writeText(File.applicationStorageDirectory.resolvePath("music-override-fixture.txt"), m_lines.join("\n"));
			NativeApplication.nativeApplication.exit(m_failed ? 1 : 0);
		}

		private function check():void
		{
			var d:Object;
			var a:String;
			var b:String;

			d = MusicOverrideCodec.decode("bgm_fd");
			expect("plain track", d.track == "bgm_fd" && d.bg == "", JSON.stringify(d));

			d = MusicOverrideCodec.decode("bgm_fd|bg=finaldestination");
			expect("track and bg", d.track == "bgm_fd" && d.bg == "finaldestination", JSON.stringify(d));

			d = MusicOverrideCodec.decode("|bg=finaldestination");
			expect("bg only", d.track == "" && d.bg == "finaldestination", JSON.stringify(d));

			d = MusicOverrideCodec.decode(null);
			expect("null", d.track == "" && d.bg == "", JSON.stringify(d));
			d = MusicOverrideCodec.decode("null");
			expect("string null", d.track == "" && d.bg == "", JSON.stringify(d));

			d = MusicOverrideCodec.decode("bgm_x|bg=a=b");
			expect("bg with =", d.bg == "a=b", JSON.stringify(d));

			expect("encode plain", MusicOverrideCodec.encode("bgm_x", "") == "bgm_x", String(MusicOverrideCodec.encode("bgm_x", "")));
			expect("encode empty", MusicOverrideCodec.encode("", null) == null, String(MusicOverrideCodec.encode("", null)));

			a = MusicOverrideCodec.withBg(MusicOverrideCodec.withTrack(null, "bgm_x"), "bf");
			b = MusicOverrideCodec.withTrack(MusicOverrideCodec.withBg(null, "bf"), "bgm_x");
			expect("track then bg", a == "bgm_x|bg=bf", a);
			expect("bg then track", b == "bgm_x|bg=bf", b);

			a = MusicOverrideCodec.withBg("bgm_x|bg=bf", "");
			expect("clear bg", a == "bgm_x", String(a));
		}

		private function expect(name:String, ok:Boolean, why:String):void
		{
			if (ok)
			{
				m_lines.push("OK " + name);
			}
			else
			{
				fail(name, why);
			};
		}

		private function fail(name:String, why:String):void
		{
			m_failed = true;
			m_lines.push("FAIL " + name + ": " + why);
		}
	}
}
