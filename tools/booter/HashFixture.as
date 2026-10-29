package
{
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	public class HashFixture extends Sprite
	{
		public function HashFixture()
		{
			var abc:ByteArray = new ByteArray();
			abc.writeUTFBytes("abc");
			var empty:ByteArray = new ByteArray();
			var line:String = Sha256.hex(abc) + "\n" + Sha256.hex(empty);
			var stream:FileStream = new FileStream();
			stream.open(File.applicationStorageDirectory.resolvePath("hash-fixture.txt"), FileMode.WRITE);
			stream.writeUTFBytes(line);
			stream.close();
			NativeApplication.nativeApplication.exit(0);
		}
	}
}
