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
			new TestChat(),
			new TestChatMessage(),
			new TestChatMessageBuilder(),
			new TestClient(),
			new TestEmojiUtil(),
			new TestHtml(),
			new TestImport(),
			new TestJID(),
			new TestMember(),
			new TestMemberUpdate(),
			new TestPresence(),
			new TestReaction(),
			new TestSessionDescription(),
			new TestSortId(),
			new TestStanza(),
			new TestStatus(),
			new TestStringUtil(),
			new TestUtil(),
			new TestXEP0393(),
#if eval
			new TestCaps(),
#else
			new TestSqlite(),
#end
		]);
	}
}
