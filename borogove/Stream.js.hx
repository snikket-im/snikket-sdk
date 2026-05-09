package borogove;

#if test
	import borogove.streams.TestStream;
	typedef Stream = borogove.streams.TestStream;
#else
	import borogove.streams.XmppJsStream;
	typedef Stream = borogove.streams.XmppJsStream;
#end
