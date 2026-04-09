import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

typedef DoccAbstractFragment = {
	var text:String;
}

typedef DoccReference = {
	@:optional var fragments:Array<Dynamic>;
	var title:String;
	var url:String;
}

typedef DoccTopicSection = {
	var identifiers:Array<String>;
	var title:String;
}

typedef DoccDocument = {
	@:optional var references:Dynamic<DoccReference>;
	@:optional var topicSections:Array<DoccTopicSection>;
}

class Docc2Mkdocs {
	static function main():Void {
		var args = Sys.args();
		var inputRoot = "doc/data/documentation";
		var outputRoot = "doc/data/documentation-makedoc";
		var index = 0;

		while (index < args.length) {
			switch (args[index]) {
				case "--input":
					index++;
					ensureHasValue(args, index, "--input");
					inputRoot = args[index];
				case "--output":
					index++;
					ensureHasValue(args, index, "--output");
					outputRoot = args[index];
				case "--help", "-h":
					printUsage();
					return;
				case other:
					Sys.println("Unknown argument: " + other);
					printUsage();
					Sys.exit(1);
			}

			index++;
		}

		inputRoot = Path.normalize(inputRoot);
		outputRoot = Path.normalize(outputRoot);

		if (!FileSystem.exists(inputRoot) || !FileSystem.isDirectory(inputRoot)) {
			fail("Input directory does not exist: " + inputRoot);
		}

		resetDirectory(outputRoot);
		processDirectory(inputRoot, outputRoot, inputRoot);
	}

	static function processDirectory(inputDir:String, outputDir:String, docRoot:String):Void {
		ensureDirectory(outputDir);

		var entries = FileSystem.readDirectory(inputDir);
		entries.sort(Reflect.compare);

		for (entry in entries) {
			var sourcePath = Path.join([inputDir, entry]);
			var destPath = Path.join([outputDir, entry]);

			if (FileSystem.isDirectory(sourcePath)) {
				processDirectory(sourcePath, destPath, docRoot);
				continue;
			}

			if (!StringTools.endsWith(entry, ".md")) {
				continue;
			}

			var original = File.getContent(sourcePath);
			var relPath = Path.normalize(sourcePath.substr(docRoot.length + 1));
			var rendered = augmentMarkdown(original, sourcePath, relPath, docRoot);
			File.saveContent(destPath, rendered);
		}
	}

	static function augmentMarkdown(original:String, sourceMdPath:String, relPath:String, docRoot:String):String {
		var jsonPath = sourceMdPath.substr(0, sourceMdPath.length - 3) + ".json";
		if (!FileSystem.exists(jsonPath)) {
			return original;
		}

		var parsed:DoccDocument = cast Json.parse(File.getContent(jsonPath));
		if (parsed.topicSections == null || parsed.topicSections.length == 0 || parsed.references == null) {
			return original;
		}

		var generatedSections = renderTopicSections(parsed, relPath);
		if (generatedSections.length == 0) {
			return original;
		}

		var trimmed = StringTools.rtrim(original);
		return trimmed + "\n\n" + generatedSections.join("\n\n") + "\n";
	}

	static function renderTopicSections(parsed:DoccDocument, currentRelPath:String):Array<String> {
		var sections = new Array<String>();

		for (topicSection in parsed.topicSections) {
			if (topicSection.identifiers == null || topicSection.identifiers.length == 0) {
				continue;
			}

			var lines = ['## ' + topicSection.title, ""];
			var addedCount = 0;

			for (identifier in topicSection.identifiers) {
				var reference:DoccReference = Reflect.field(parsed.references, identifier);
				if (reference == null || reference.url == null || reference.title == null) {
					continue;
				}

				var bullet = renderReferenceBullet(reference, currentRelPath);
				if (bullet == null) {
					continue;
				}

				lines.push(bullet);
				addedCount++;
			}

			if (addedCount > 0) {
				sections.push(lines.join("\n"));
			}
		}

		return sections;
	}

	static function renderReferenceBullet(reference:DoccReference, currentRelPath:String):Null<String> {
		var targetRelPath = relativeDocPathFromUrl(reference.url, currentRelPath);
		if (targetRelPath == null) {
			return null;
		}

		var parts = ['- [' + reference.title + '](' + targetRelPath + ')'];
		var summary = renderAbstractFirstLine(cast Reflect.field(reference, "abstract"));
		if (summary != null) {
			parts.push(summary);
		}

		return parts.join(" ");
	}

	static function relativeDocPathFromUrl(url:String, currentRelPath:String):Null<String> {
		var normalizedUrl = StringTools.trim(url);
		if (!StringTools.startsWith(normalizedUrl, "/documentation/")) {
			return null;
		}

		var docRelPath = normalizedUrl.substr("/documentation/".length) + ".md";
		var currentDir = Path.directory(currentRelPath);
		return makeRelativePath(docRelPath, currentDir);
	}

	static function makeRelativePath(target:String, fromDir:String):String {
		var targetParts = normalizedParts(target);
		var fromParts = normalizedParts(fromDir);
		var shared = 0;
		var maxShared = targetParts.length < fromParts.length ? targetParts.length : fromParts.length;

		while (shared < maxShared && targetParts[shared] == fromParts[shared]) {
			shared++;
		}

		var relativeParts = new Array<String>();
		for (_ in shared...fromParts.length) {
			relativeParts.push("..");
		}
		for (index in shared...targetParts.length) {
			relativeParts.push(targetParts[index]);
		}

		return relativeParts.length == 0 ? "." : relativeParts.join("/");
	}

	static function normalizedParts(path:String):Array<String> {
		var normalized = Path.normalize(path);
		var rawParts = normalized.split("/");
		var parts = new Array<String>();

		for (part in rawParts) {
			if (part == "" || part == ".") {
				continue;
			}
			parts.push(part);
		}

		return parts;
	}

	static function renderAbstractFirstLine(fragments:Array<DoccAbstractFragment>):Null<String> {
		if (fragments == null || fragments.length == 0) {
			return null;
		}

		var buffer = new StringBuf();
		for (fragment in fragments) {
			if (fragment != null && fragment.text != null) {
				buffer.add(fragment.text);
			}
		}

		var summary = firstLine(buffer.toString());
		return summary == "" ? null : summary;
	}

	static function firstLine(value:String):String {
		var trimmed = StringTools.trim(value);
		if (trimmed == "") {
			return "";
		}

		var newlineIndex = trimmed.indexOf("\n");
		if (newlineIndex >= 0) {
			trimmed = trimmed.substr(0, newlineIndex);
		}

		return ~/[\t ]+/.replace(StringTools.trim(trimmed), " ");
	}

	static function resetDirectory(path:String):Void {
		if (FileSystem.exists(path)) {
			deleteRecursively(path);
		}
		ensureDirectory(path);
	}

	static function deleteRecursively(path:String):Void {
		if (FileSystem.isDirectory(path)) {
			for (entry in FileSystem.readDirectory(path)) {
				deleteRecursively(Path.join([path, entry]));
			}
			FileSystem.deleteDirectory(path);
			return;
		}

		FileSystem.deleteFile(path);
	}

	static function ensureDirectory(path:String):Void {
		if (path == "" || path == ".") {
			return;
		}

		if (FileSystem.exists(path)) {
			return;
		}

		var parent = Path.directory(path);
		if (parent != path) {
			ensureDirectory(parent);
		}
		FileSystem.createDirectory(path);
	}

	static function ensureHasValue(args:Array<String>, index:Int, flag:String):Void {
		if (index >= args.length) {
			fail("Missing value for " + flag);
		}
	}

	static function printUsage():Void {
		Sys.println("Usage: haxe --run Docc2Mkdocs [--input <dir>] [--output <dir>]");
	}

	static function fail(message:String):Void {
		Sys.println(message);
		Sys.exit(1);
	}
}
