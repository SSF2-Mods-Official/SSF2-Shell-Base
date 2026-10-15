package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.filesystem.File;
	import ssf2mm.shared.JsonFile;

	/**
	 * ProfileStore: nothing on disk reads as empty lists; the old pack profiles.json migrates into
	 * expansions/user/controller_profiles.json; once that file exists it wins over old copies.
	 */
	public class ProfileStoreFixture extends Sprite
	{
		private var m_lines:Array = [];
		private var m_failed:Boolean = false;

		public function ProfileStoreFixture()
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
			JsonFile.writeText(File.applicationStorageDirectory.resolvePath("profile-store-fixture.txt"), m_lines.join("\n"));
			NativeApplication.nativeApplication.exit(m_failed ? 1 : 0);
		}

		private function check():void
		{
			var root:File = File.applicationStorageDirectory.resolvePath("work");
			var app:File = root.resolvePath("app");
			var store:File = root.resolvePath("store");
			var got:Object;
			if (root.exists)
			{
				root.deleteDirectory(true);
			};
			app.createDirectory();
			store.createDirectory();

			got = ProfileStore.load(app, store);
			expect("empty reads as empty lists", got.from == null && got.data.names.length == 0 && got.data.last != null && got.data.profiles != null, JSON.stringify(got.data));

			JsonFile.write(app.resolvePath("expansions/mods/controller_profiles/profiles.json"), {"names": ["Weeviee"], "profiles": {"Weeviee": {"pads": {}}}});
			got = ProfileStore.load(app, store);
			expect("old pack file is read", got.from != null && File(got.from).nativePath.indexOf("expansions") >= 0 && got.data.names[0] == "Weeviee", JSON.stringify(got.data));
			expect("missing last filled", got.data.last != null, "last missing");

			expect("save writes state file", ProfileStore.save(app, got.data) && ProfileStore.stateFile(app).exists, "no state file");

			JsonFile.write(app.resolvePath("expansions/mods/controller_profiles/profiles.json"), {"names": ["Stale"]});
			got = ProfileStore.load(app, store);
			expect("state file wins", got.from != null && File(got.from).nativePath == ProfileStore.stateFile(app).nativePath && got.data.names[0] == "Weeviee", JSON.stringify(got.data));
			expect("state file is under expansions/user", ProfileStore.stateFile(app).nativePath.replace(/\\/g, "/").indexOf("expansions/user/controller_profiles.json") >= 0, ProfileStore.stateFile(app).nativePath);

			app = root.resolvePath("app2");
			JsonFile.write(app.resolvePath("data/ssf2mm/state/controller_profiles.json"), {"names": ["Older"]});
			JsonFile.write(app.resolvePath("expansions/mods/controller_profiles/profiles.json"), {"names": ["Oldest"]});
			got = ProfileStore.load(app, store);
			expect("data/ssf2mm/state copy is read before the pack file", got.data.names[0] == "Older", JSON.stringify(got.data));
			expect("save moves it to expansions/user", ProfileStore.save(app, got.data) && ProfileStore.stateFile(app).exists, "no user file");
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
