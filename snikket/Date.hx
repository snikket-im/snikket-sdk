package snikket;

class Date {
	public static function format(d: std.Date):String {
		var str = DateTools.format(d, "%Y-%m-%dT%H:%M:%S");
		var tzHour = Std.int(d.getTimezoneOffset()/60);
		var tzMinute = Std.int(Math.abs(d.getTimezoneOffset())%60);
		return
			str + (tzHour < 0 ? "+" : "-") +
			StringTools.lpad(Std.string(Math.abs(tzHour)), "0", 2) + ":" +
			StringTools.lpad(Std.string(tzMinute), "0", 2);
	}
}
