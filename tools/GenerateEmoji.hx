package tools;

using StringTools;

class GenerateEmoji {
	static public function main():Void {
		final source = haxe.Http.requestUrl("https://unicode.org/Public/emoji/latest/emoji-test.txt");
		final map: Map<String, Array<String>> = [];
		for (line in source.split("\n")) {
			if (line != "" && !line.startsWith("#")) {
				final points = line.split(";")[0].trim().split(" ").map(point ->
					"\\u{" + point + "}"
				);
				final exist = map.get(points[0]) ?? [];
				exist.push(points.join(""));
				exist.sort((x,y) -> y.length - x.length);
				map.set(points[0], exist);
			}
		}
		Sys.println("package snikket;");
		Sys.println("class EmoijData {");
		Sys.println("\tpublic static final emoji = [");
		for (key => value in map) {
			Sys.print("\t\t\"");
			Sys.print(key);
			Sys.print("\" => [\"");
			Sys.print(value.join("\",\""));
			Sys.println("\"],");
		}
		Sys.println("\t];");
		Sys.println("}");
	}
}
