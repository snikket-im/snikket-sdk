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
			new TestPresence(),
			new TestClient(),
			new TestMember(),
			new TestMemberUpdate(),
			new TestChat(),
			new TestSortId(),
			new TestXEP0393(),
			new TestEmojiUtil(),
			new TestJID(),
			new TestStringUtil(),
			new TestUtil(),
			new TestReaction(),
			new TestHtml(),
			new TestStatus(),
#if eval
			new TestCaps(),
#else
			new TestSqlite(),
#end
		]);
	}
}
