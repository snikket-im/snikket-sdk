package borogove;

#if test
	import borogove.streams.TestStream;
	typedef Stream = borogove.streams.TestStream;
#else
	import borogove.streams.XmppStropheStream;
	typedef Stream = borogove.streams.XmppStropheStream;
#end
