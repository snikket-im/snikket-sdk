package test;

import utest.Runner;
import utest.ui.Report;

class TestAll {
	public static function main() {
		utest.UTest.run([
			new TestSessionDescription(),
			new TestChatMessageBuilder(),
			new TestStanza(),
			new TestCaps(),
			new TestXEP0393(),
		]);
	}
}
