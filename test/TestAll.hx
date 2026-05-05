package test;

import thenshim.Promise;

import utest.Runner;
import utest.ui.Report;

class TestAll {
	public static function main() {
		#if (!js && target.threaded)
		final mainLoop = sys.thread.Thread.current().events;
		var promiseFactory = cast(Promise.factory, thenshim.fallback.FallbackPromiseFactory);
		promiseFactory.scheduler.addNext = mainLoop.run;
		#end

		utest.UTest.run([
			new TestCapsRepo(),
			new TestChatMessage(),
			new TestSessionDescription(),
			new TestChatMessageBuilder(),
			new TestStanza(),
#if eval
			new TestCaps(),
			new TestPresence(),
			new TestClient(),
			new TestSortId(),
			new TestParticipant(),
			new TestChat(),
#end
			new TestXEP0393(),
			new TestEmojiUtil(),
			new TestJID(),
			new TestStringUtil(),
			new TestUtil(),
			new TestReaction(),
			new TestHtml(),
			new TestStatus(),
#if !eval
			new TestSqlite(),
#end
		]);
	}
}
