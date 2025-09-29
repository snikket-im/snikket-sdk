package borogove;

import borogove.Util;

@:expose
class Version {
	@:keep public static var HUMAN(default, never):String = getGitVersion();
}
