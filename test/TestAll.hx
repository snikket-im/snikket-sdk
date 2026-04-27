package test;

import utest.Runner;
import utest.ui.Report;

class TestAll {
	public static function main() {
		utest.UTest.run([
			new TestPresence(),
			new TestCapsRepo(),
			new TestChatMessage(),
			new TestSessionDescription(),
			new TestChatMessageBuilder(),
			new TestStanza(),
			new TestCaps(),
			new TestClient(),
			new TestXEP0393(),
			new TestEmojiUtil(),
			new TestJID(),
			new TestStringUtil(),
			new TestUtil(),
			new TestReaction(),
			new TestSortId(),
			new TestHtml(),
			new TestChat(),
			new TestStatus(),
			new TestParticipant(),
		]);
	}
}
