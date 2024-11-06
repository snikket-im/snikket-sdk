package snikket;

import snikket.Util;

@:expose
class Version {
	@:keep public static var HUMAN(default, never):String = getGitVersion();
}
