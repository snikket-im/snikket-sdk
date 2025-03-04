package snikket;

class Date {
	public static function format(d: std.Date):String {
		return Std.string(d.getUTCFullYear()) + "-" +
			StringTools.lpad(Std.string(d.getUTCMonth() + 1), "0", 2) + "-" +
			StringTools.lpad(Std.string(d.getUTCDate()), "0", 2) + "T" +
			StringTools.lpad(Std.string(d.getUTCHours()), "0", 2) + ":" +
			StringTools.lpad(Std.string(d.getUTCMinutes()), "0", 2) + ":" +
			StringTools.lpad(Std.string(d.getUTCSeconds()), "0", 2) + ".000Z";
	}
}
