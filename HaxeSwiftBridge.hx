#if (haxe_ver < 4.0) #error "Haxe 4.0 required" #end

#if macro

	// fast path for when code gen isn't required
	// disable this to get auto-complete when editing this file
	#if (display || display_details || !sys || cppia)

class HaxeSwiftBridge {
	public static function expose(?namespace: String)
		return haxe.macro.Context.getBuildFields();
	@:noCompletion
	static macro function runUserMain()
		return macro null;
}

	#else

import HaxeCBridge.CodeTools.*;
import haxe.ds.ReadOnlyArray;
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.PositionTools;
import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import haxe.macro.TypedExprTools;
import sys.FileSystem;
import sys.io.File;

using Lambda;
using StringTools;

class HaxeSwiftBridge {

	static final noOutput = Sys.args().has('--no-output');
	static final printer = new Printer();
	
	static var firstRun = true;

	static var libName: Null<String> = getLibNameFromHaxeArgs(); // null if no libName determined from args

	static final compilerOutputDir = Compiler.getOutput();
	// paths relative to the compiler output directory
	static final implementationPath = Path.join([hx.strings.Strings.toUpperCamel(libName) + '.swift']);
	
	static final queuedClasses = new Array<{
		cls: Ref<ClassType>,
		namespace: String,
		fields: Array<Field>
	}>();

	static final knownEnums: Map<String,String> = [];

	static public function expose(?namespace: String) {
		var clsRef = Context.getLocalClass(); 
		var cls = clsRef.get();
		var fields = Context.getBuildFields();

		if (libName == null) {
			// if we cannot determine a libName from --main or -D, we use the first exposed class
			libName = if (namespace != null) {
				namespace;
			} else {
				cls.name;
			}
		}

		queuedClasses.push({
			cls: clsRef,
			namespace: namespace,
			fields: fields
		});

		// add @:keep
		cls.meta.add(':keep', [], Context.currentPos());

		if (firstRun) {
			var HaxeSwiftBridgeType = Context.resolveType(macro :HaxeSwiftBridge, Context.currentPos());
			switch HaxeSwiftBridgeType {
				case TInst(_.get().meta => meta, params):
					if (!meta.has(':buildXml')) {
						meta.add(':buildXml', [
							macro $v{code('
								<!-- HaxeSwiftBridge -->
								<files id="haxe">
									<depend name="$implementationPath"/>
								</files>
							')}
						], Context.currentPos());
					}
				default: throw 'Internal error';
			}

			Context.onAfterTyping(_ -> {
				var implementation = generateImplementation();

				function saveFile(path: String, content: String) {
					var directory = Path.directory(path);
					if (!FileSystem.exists(directory)) {
						FileSystem.createDirectory(directory);
					}
					// only save if there's a difference (save C++ compilation by not changing the file if not needed)
					if (FileSystem.exists(path)) {
						if (content == sys.io.File.getContent(path)) {
							return;
						}
					}
					sys.io.File.saveContent(path, content);	
				}

				if (!noOutput) {
					saveFile(Path.join([compilerOutputDir, implementationPath]), implementation);
				}
			});

			firstRun = false;
		}

		return fields;
	}

	static function getHxcppNativeName(t: BaseType) {
		var nativeMeta = t.meta.extract(':native')[0];
		var nativeMetaValue = nativeMeta != null ? ExprTools.getValue(nativeMeta.params[0]) : null;
		var nativeName = (nativeMetaValue != null ? nativeMetaValue : t.pack.concat([t.name]).join('.'));
		return nativeName;
	}

	static function getSwiftType(type, arg = false) {
		return switch type {
		case TInst(_.get().name => "String", params):
			return "String";
		case TInst(_.get().name => "Array", [param]):
			return "Array<" + getSwiftType(param, arg) + ">";
		case TInst(_.get() => t, params):
			return t.name;
		case TAbstract(_.get().name => "Null", [param]):
			return getSwiftType(param) + "?";
		case TAbstract(_.get().name => "Int", []):
			return "Int32";
		case TAbstract(_.get() => t, []):
			final isPublicEnumAbstract = t.meta.has(':enum') && !t.isPrivate;
			final isIntEnumAbstract = if (isPublicEnumAbstract) {
				final underlyingRootType = TypeTools.followWithAbstracts(t.type, false);
				Context.unify(underlyingRootType, Context.resolveType(macro :Int, Context.currentPos()));
			} else false;
			if (isIntEnumAbstract) {
				knownEnums[t.name] = hx.strings.Strings.toLowerUnderscore(safeIdent(TypeTools.toString(type)));
			}
			return t.name;
		case TAbstract(_.get() => t, params):
			return getSwiftType(TypeTools.followWithAbstracts(type, false), arg);
		case TFun(args, ret):
			final builder = new hx.strings.StringBuilder(arg ? "@Sendable @escaping (" : "@Sendable (");
			for (i => arg in args) {
				if (i > 0) builder.add(", ");
				builder.add(getSwiftType(arg.t));
			}
			builder.add(")->");
			builder.add(getSwiftType(ret));

			return builder.toString();
		case TType(_.get() => t, params):
			return getSwiftType(TypeTools.follow(type, true), arg);
		default:
			Context.fatalError("No implemented Swift type conversion for: " + type, Context.currentPos());
		}
	}

	static function convertArgs(builder: hx.strings.StringBuilder, args: Array<{ name: String, opt: Bool, t: haxe.macro.Type }>, ?kind: FieldType) {
		for (i => arg in args) {
			if (i > 0) builder.add(", ");
			builder.add(arg.name);
			builder.add(": ");
			builder.add(getSwiftType(arg.t, true));
			if (arg.opt) {
				switch (kind) {
				case FFun(func):
					final expr = func.args.find(fa -> fa.name == arg.name)?.value?.expr;
					switch (expr) {
					case EConst(CIdent("null")):
						builder.add(" = nil");
					case EConst(CIdent("true")):
						builder.add(" = true");
					case EConst(CIdent("false")):
						builder.add(" = false");
					case EConst(CInt(i, null)):
						builder.add(" = ");
						builder.add(Std.string(i));
					case null:
						builder.add(" = nil");
					default:
						Context.fatalError("Unknown default value expression: " + expr, Context.currentPos());
					}
				default:
					builder.add(" = nil");
				}
			}
		}
	}

	static function castToSwift(item: String, type: haxe.macro.Type, canNull = false, isRet = false) {
		return switch type {
		case TInst(_.get().name => "String", params):
			return "useString(" + item + ")" + (canNull ? "" : "!");
		case TInst(_.get().name => "Array", [param]):
			final ptrType = switch getSwiftType(param) {
				case "String": "UnsafePointer<CChar>?";
				case "Int16": "Int16";
				default: "UnsafeMutableRawPointer?";
			}
			if (isRet) {
				return
					"{" +
					"var __ret: UnsafeMutablePointer<" + ptrType + ">? = nil;" +
					"let __ret_length = " + ~/\)$/.replace(item, ", &__ret);") +
					"return " + castToSwift("__ret", type, canNull, false) + ";" +
					"}()";
			} else {
				return
					"{" +
					"let __r = UnsafeMutableBufferPointer<" + ptrType + ">(start: " + item + ", count: " + item + "_length).map({" +
					castToSwift("$0", param) +
					"});" +
					"c_" + libName + "." + libName + "_release(" + item + ");" +
					"return __r;" +
					"}()";
			}
		case TInst(_.get() => t, params):
			final wrapper = t.isInterface ? 'Any${t.name}' : t.name;
			if (canNull) {
				return "(" + item + ").map({ " + wrapper + "($0) })";
			} else {
				return wrapper + "(" + item + "!)";
			}
		case TAbstract(_.get().name => "Null", [param]):
			return castToSwift(item, param, true);
		case TAbstract(_.get() => t, []):
			return item;
		case TAbstract(_.get() => t, params):
			return castToSwift(item, TypeTools.followWithAbstracts(type, false), canNull, isRet);
		case TType(_.get() => t, params):
			return castToSwift(item, TypeTools.follow(type, true), canNull);
		default:
			Context.fatalError("No implemented Swift cast for: " + type, Context.currentPos());
		}
	}

	static function castToC(item: String, type: haxe.macro.Type, canNull = false) {
		return switch type {
		case TInst(_.get().name => "String", params):
			return item;
		case TInst(_.get().name => "Array", [param = TInst(_)]):
			return item + ".map { " + castToC("$0", param, canNull) + " }";
		case TInst(_.get().name => "Array", [param]):
			return item;
		case TInst(_.get() => t, []):
			return item + (canNull ? "?" : "") + ".o";
		case TAbstract(_.get().name => "Null", [param]):
			return castToC(item, param, true);
		case TAbstract(_.get() => t, []):
			return item;
		case TType(_.get() => t, params):
			return castToC(item, TypeTools.follow(type, true));
		default:
			Context.fatalError("No implemented C cast for: " + type, Context.currentPos());
		}
	}

	static function metaIsSwiftExpose(e: ExprDef) {
		return switch (e) {
			case ECall(call, args):
			switch (call.expr) {
			case EField(l, r):
				switch (l.expr) {
				case EConst(CIdent("HaxeSwiftBridge")):
					r == "expose";
				default: false;
				}
			default: false;
			}
		default: false;
		}
	}

	static function convertQueuedClass(clsRef: Ref<ClassType>, namespace: String, fields: Array<Field>) {
		var cls = clsRef.get();

		// validate
		if (cls.isExtern) Context.error('Cannot expose extern directly to Swift', cls.pos);

		var classPrefix = cls.pack.concat([namespace == null ? cls.name : namespace]);
		var cNameMeta = getCNameMeta(cls.meta);

		var functionPrefix =
			if (cNameMeta != null)
				[cNameMeta];
			else 
				[false ? libName : ""] // NOTE: probably want this if we get packages with differnt name?
				.concat(safeIdent(classPrefix.join('.')) != libName ? classPrefix : [])
				.filter(s -> s != '');

		final builder = new hx.strings.StringBuilder(cls.isInterface ? "public protocol " : "public class ");
		builder.add(cls.name);
		final superClass = if (cls.superClass == null) {
			null;
		} else {
			final buildMeta = cls.superClass.t.get().meta.extract(":build");
			if (buildMeta.exists(meta -> metaIsSwiftExpose(meta.params[0]?.expr))) {
				cls.superClass.t.get();
			} else {
				null;
			}
		}
		if (superClass == null) {
			builder.add(": SDKObject");
		} else {
			builder.add(": ");
			builder.add(superClass.name);
		}
		for (iface in cls.interfaces) {
			builder.add(", ");
			builder.add(iface.t.get().name);
		}
		if (!cls.isInterface) {
			builder.add(", @unchecked Sendable");
		}

		builder.add(" {\n");
		if (!cls.isInterface && superClass == null) {
			// We don't want this to be public, but it needs to be for the protocol, hmm
			builder.add("\tpublic let o: UnsafeMutableRawPointer\n\n\tinternal init(_ ptr: UnsafeMutableRawPointer) {\n\t\to = ptr\n\t}\n\n");
		}

		function convertVar(f: ClassField, read: VarAccess, write: VarAccess, isStatic: Bool = false) {
			final noemit = f.meta.extract("HaxeCBridge.noemit")[0];
			var isConvertibleMethod = f.isPublic && !f.isExtern && (noemit == null || (noemit.params != null && noemit.params.length > 0));
			if (!isConvertibleMethod) return;
			if (cls.isInterface) return;
			if (read != AccNormal && read != AccCall) return; // Swift doesn't allow write-only

			final cNameMeta = getCNameMeta(f.meta);

			final cFuncNameGet = hx.strings.Strings.toLowerUnderscore(functionPrefix.concat([f.name]).join('_'));
			final cFuncNameSet = hx.strings.Strings.toLowerUnderscore(functionPrefix.concat(["set", f.name]).join('_'));

			final cleanDoc = f.doc != null ? StringTools.trim(removeIndentation(f.doc)) : null;
			if (cleanDoc != null) builder.add('\t/**\n${cleanDoc.split('\n').map(l -> '\t ' + l).join('\n')}\n\t */\n');

			builder.add("\tpublic var ");
			builder.add(f.name);
			builder.add(": ");
			builder.add(getSwiftType(f.type));
			builder.add(" {\n");
			if (read == AccNormal || read == AccCall) {
				builder.add("\t\tget {\n\t\t\t");
				builder.add(castToSwift('c_${libName}.${cFuncNameGet}(${isStatic ? '' : 'o'})', f.type, false, true));
				builder.add("\n\t\t}\n");
			}
			if (write == AccNormal || write == AccCall) {
				builder.add("\t\tset {\n\t\t\tc_");
				builder.add(libName);
				builder.add(".");
				builder.add(cFuncNameSet);
				builder.add("(" + (isStatic ? "" : "o, "));
				builder.add(castToC("newValue", f.type));
				switch TypeTools.followWithAbstracts(Context.resolveType(Context.toComplexType(f.type), Context.currentPos()), false) {
				case TInst(_.get().name => "Array", [param]):
					builder.add(", ");
					builder.add("newValue.count");
				default:
				}
				builder.add(")\n\t\t}\n");
			}
			builder.add("\t}\n\n");
		}

		function mkSwiftAsync(ibuilder: hx.strings.StringBuilder, ret: haxe.macro.Type) {
			ibuilder.add("{ (");
			ibuilder.add("a");
			switch (ret) {
			case TInst(_.get().name => "Array", params):
				ibuilder.add(", a_length");
			default:
			}
			ibuilder.add(", ctx");
			ibuilder.add(") in\n\t\t\t\tlet cont = Unmanaged<AnyObject>.fromOpaque(ctx!).takeRetainedValue() as! UnsafeContinuation<");
			ibuilder.add(getSwiftType(ret));
			ibuilder.add(", Never>\n\t\t\t\t");
			final cbuilder = new hx.strings.StringBuilder("cont.resume");
			cbuilder.add("(returning: ");
			cbuilder.add(castToSwift("a", ret));
			cbuilder.add(")");
			ibuilder.add(cbuilder.toString());
			ibuilder.add("\n\t\t\t},\n\t\t\t__");
			ibuilder.add("cont_ptr");
		}

		function convertFunction(f: ClassField, kind: SwiftFunctionInfoKind, ?fld: Field) {
			final noemit = f.meta.extract("HaxeCBridge.noemit")[0];
			var isConvertibleMethod = f.isPublic && !f.isExtern && !f.meta.has("HaxeCBridge.wrapper") && (noemit == null || (noemit.params != null && noemit.params.length > 0));
			if (!isConvertibleMethod) return;
			if (cls.isInterface) return;
			switch f.type {
				case TFun(targs, tret):
					final cNameMeta = getCNameMeta(f.meta);
					var finalTret = tret;

					var cFuncName: String =
						if (cNameMeta != null)
							cNameMeta;
						else if (f.meta.has("HaxeCBridge.wrapper"))
							functionPrefix.concat([f.name.substring(0, f.name.length - 7)]).join('_');
						else
							functionPrefix.concat([f.name]).join('_');

					var funcName: String =
						if (f.meta.has("HaxeCBridge.wrapper"))
							f.name.substring(0, f.name.length - 7);
						else
							f.name;

					cFuncName = hx.strings.Strings.toLowerUnderscore(cFuncName);

					var cleanDoc = f.doc != null ? StringTools.trim(removeIndentation(f.doc)) : null;
					if (cleanDoc != null) {
							switch tret {
							case TType(_.get().name => "Promise", params):
								cleanDoc = ~/@returns Promise resolving to/.replace(cleanDoc, "@returns");
							default:
						}
					}

					if (cleanDoc != null) builder.add('\t/**\n${cleanDoc.split('\n').map(l -> '\t ' + l).join('\n')}\n\t */\n');
					switch kind {
						case Constructor:
							builder.add("\tpublic init(");
							convertArgs(builder, targs);
							builder.add(") {\n\t\to = c_");
							builder.add(libName);
							builder.add(".");
							builder.add(cFuncName);
							builder.add("(");
							for (i => arg in targs) {
								if (i > 0) builder.add(", ");
								builder.add(castToC(arg.name, arg.t));
							}
							builder.add(")\n\t}\n\n");
						case Member:
							builder.add("\tpublic func ");
							builder.add(funcName);
							builder.add("(");
							convertArgs(builder, targs, fld?.kind);
							builder.add(") ");
							switch tret {
								case TType(_.get().name => "Promise", params):
									builder.add("async ");
								default:
							}
							builder.add("-> ");
							switch tret {
								case TType(_.get().name => "Promise", params):
									builder.add(getSwiftType(params[0]));
								default:
									builder.add(getSwiftType(tret));
							}
							builder.add(" {\n\t\t");
							switch tret {
								case TType(_.get().name => "Promise", params):
								builder.add("return await withUnsafeContinuation { cont in\n\t\t");
								builder.add("let __cont_ptr = UnsafeMutableRawPointer(Unmanaged.passRetained(cont as AnyObject).toOpaque())\n\t\t");
								default:
							}
							for (arg in targs) {
								switch (arg.t) {
								case TFun(fargs, fret):
									builder.add("let __");
									builder.add(arg.name);
									builder.add("_ptr = UnsafeMutableRawPointer(Unmanaged.passRetained(");
									builder.add(arg.name);
									builder.add(" as AnyObject).toOpaque())\n\t\t");
								default:
								}
							}
							for (arg in targs) {
								final allowNull = switch arg.t {
								case TAbstract(_.get().name => "Null", [param]): true;
								default: false;
								};
								switch TypeTools.followWithAbstracts(Context.resolveType(Context.toComplexType(arg.t), Context.currentPos()), false) {
								case TInst(_.get().name => "Array", [TInst(_.get().name => "String", _)]):
								builder.add("with" + (allowNull ? "Optional" : "") + "ArrayOfCStrings(" + arg.name + ") { __" + arg.name + " in ");
								default:
								}
							}
							final ibuilder = new hx.strings.StringBuilder("c_");
							ibuilder.add(libName);
							ibuilder.add(".");
							ibuilder.add(cFuncName);
							ibuilder.add("(\n\t\t\tself.o");
							for (arg in targs) {
								ibuilder.add(",\n\t\t\t");
								final allowNull = switch arg.t {
								case TAbstract(_.get().name => "Null", [param]): true;
								default: false;
								};
								switch TypeTools.followWithAbstracts(Context.resolveType(Context.toComplexType(arg.t), Context.currentPos()), false) {
								case TFun(fargs, fret):
									ibuilder.add("{ (");
									for (i => farg in fargs) {
										if (i > 0) ibuilder.add(", ");
										ibuilder.add("a" + i);
										switch (farg.t) {
										case TInst(_.get().name => "Array", params):
											ibuilder.add(", a" + i + "_length");
										default:
										}
									}
									if (fargs.length > 0) ibuilder.add(", ");
									ibuilder.add("ctx");
									// TODO unretained vs retained
									ibuilder.add(") in\n\t\t\t\tlet ");
									ibuilder.add(arg.name);
									ibuilder.add(" = Unmanaged<AnyObject>.fromOpaque(ctx!).takeUnretainedValue() as! ");
									ibuilder.add(getSwiftType(arg.t));
									ibuilder.add("\n\t\t\t\t");
									final cbuilder = new hx.strings.StringBuilder("return " + arg.name);
									cbuilder.add("(");
									for (i => farg in fargs) {
										if (i > 0) cbuilder.add(", ");
										cbuilder.add(castToSwift("a" + i, farg.t));
									}
									cbuilder.add(")");
									ibuilder.add(castToSwift(cbuilder.toString(), fret, false, true));
									ibuilder.add("\n\t\t\t},\n\t\t\t__");
									ibuilder.add(arg.name);
									ibuilder.add("_ptr");
								case TInst(_.get().name => "Array", [TInst(_.get().name => "String", _)]):
									ibuilder.add("__");
									ibuilder.add(arg.name);
									ibuilder.add(", ");
									ibuilder.add(arg.name + (allowNull ? "?" : "") + ".count" + (allowNull ? " ?? 0" : ""));
								case TInst(_.get().name => "Array", [param]):
									ibuilder.add(castToC(arg.name, arg.t));
									ibuilder.add(", ");
									ibuilder.add(arg.name + (allowNull ? "?" : "") + ".count" + (allowNull ? " ?? 0" : ""));
								default:
									ibuilder.add(castToC(arg.name, arg.t));
								}
							}
							switch tret {
								case TType(_.get().name => "Promise", params):
									if (targs.length > 0) ibuilder.add(",\n\t\t\t");
									mkSwiftAsync(ibuilder, params[0]);
									finalTret = Context.resolveType(TPath({name: "Void", pack: []}), Context.currentPos());
								default:
							}
							ibuilder.add("\n\t\t)");
							builder.add(castToSwift(ibuilder.toString(), finalTret, false, true));
							for (arg in targs) {
								switch TypeTools.followWithAbstracts(Context.resolveType(Context.toComplexType(arg.t), Context.currentPos()), false) {
								case TInst(_.get().name => "Array", [TInst(_.get().name => "String", _)]):
								builder.add("}");
								default:
								}
							}
							switch tret {
								case TType(_.get().name => "Promise", params):
								builder.add("\n\t\t}");
								default:
							}
							builder.add("\n\t}\n\n");
						case Static:
							builder.add("\tpublic static func ");
							builder.add(funcName);
							builder.add("(");
							convertArgs(builder, targs);
							builder.add(") -> ");
							builder.add(getSwiftType(tret));
							builder.add(" {\n\t\t");
							for (arg in targs) {
								switch (arg.t) {
								case TFun(fargs, fret):
									builder.add("let __");
									builder.add(arg.name);
									builder.add("_ptr = UnsafeMutableRawPointer(Unmanaged.passRetained(");
									builder.add(arg.name);
									builder.add(" as AnyObject).toOpaque())\n\t\t");
								default:
								}
							}
							final ibuilder = new hx.strings.StringBuilder("c_");
							ibuilder.add(libName);
							ibuilder.add(".");
							ibuilder.add(cFuncName);
							ibuilder.add("(");
							var isFirst = true;
							for (arg in targs) {
								if (!isFirst) ibuilder.add(",");
								isFirst = false;
								ibuilder.add("\n\t\t\t");
								switch (arg.t) {
								case TFun(fargs, fret):
									ibuilder.add("{ (");
									for (i => farg in fargs) {
										if (i > 0) ibuilder.add(", ");
										ibuilder.add("a" + i);
										switch (farg.t) {
										case TInst(_.get().name => "Array", params):
											ibuilder.add(", a" + i + "_length");
										default:
										}
									}
									if (fargs.length > 0) ibuilder.add(", ");
									ibuilder.add("ctx");
									// TODO unretained vs retained
									ibuilder.add(") in\n\t\t\t\tlet ");
									ibuilder.add(arg.name);
									ibuilder.add(" = Unmanaged<AnyObject>.fromOpaque(ctx!).takeUnretainedValue() as! ");
									ibuilder.add(getSwiftType(arg.t));
									ibuilder.add("\n\t\t\t\t");
									final cbuilder = new hx.strings.StringBuilder(arg.name);
									cbuilder.add("(");
									for (i => farg in fargs) {
										if (i > 0) cbuilder.add(", ");
										cbuilder.add(castToSwift("a" + i, farg.t));
									}
									cbuilder.add(")");
									ibuilder.add(castToSwift(cbuilder.toString(), fret, false, true));
									ibuilder.add("\n\t\t\t},\n\t\t\t__");
									ibuilder.add(arg.name);
									ibuilder.add("_ptr");
								case TInst(_.get().name => "Array", [param]):
									ibuilder.add(castToC(arg.name, arg.t));
									ibuilder.add(", ");
									ibuilder.add(arg.name + ".count");
								default:
									ibuilder.add(castToC(arg.name, arg.t));
								}
							}
							ibuilder.add("\n\t\t)");
							builder.add(castToSwift(ibuilder.toString(), tret, false, true));
							builder.add("\n\t}\n\n");

					}

				default: Context.fatalError('Internal error: Expected function expression for ${f.name} got: ' + f.type, f.pos);
			}
		}

		if (cls.constructor != null) {
			convertFunction(cls.constructor.get(), Constructor);
		}

		for (f in cls.statics.get()) {
			// TODO: this also includes everything on an abstract?
			switch (f.kind) {
			case FMethod(MethMacro):
			case FMethod(_): convertFunction(f, Static);
			case FVar(read, write): convertVar(f, read, write, true);
			}
		}

		for (f in cls.fields.get()) {
			switch (f.kind) {
			case FMethod(MethMacro):
			case FMethod(_): convertFunction(f, Member, fields.find(fld -> f.name == fld.name));
			case FVar(read, write): convertVar(f, read, write);
			}
		}

		if (!cls.isInterface && superClass == null) {
			builder.add("\tdeinit {\n\t\tc_");
			builder.add(libName);
			builder.add(".");
			builder.add(libName);
			builder.add("_release(o)\n\t}\n");
		}

		builder.add("}\n");

		if (cls.isInterface) {
			// TODO: extension with defaults for all exposed methods
			builder.add("\npublic class Any");
			builder.add(cls.name);
			builder.add(": ");
			builder.add(cls.name);
			builder.add(" {\n");
			builder.add("\tpublic let o: UnsafeMutableRawPointer\n\n\tinternal init(_ ptr: UnsafeMutableRawPointer) {\n\t\to = ptr\n\t}\n\n");
			builder.add("\tdeinit {\n\t\tc_");
			builder.add(libName);
			builder.add(".");
			builder.add(libName);
			builder.add("_release(o)\n\t}\n");
			builder.add("\n}\n");
		}

		return builder.toString();
	}

	static macro function runUserMain() {
		var mainClassPath = getMainFromHaxeArgs(Sys.args());
		if (mainClassPath == null) {
			return macro null;
		} else {
			return Context.parse('$mainClassPath.main()', Context.currentPos());
		}
	}

	static function isLibraryBuild() {
		return Context.defined('dll_link') || Context.defined('static_link');
	}

	static function isDynamicLink() {
		return Context.defined('dll_link');
	}

	static function getCNameMeta(meta: MetaAccess): Null<String> {
		var cNameMeta = meta.extract('HaxeCBridge.name')[0];
		return if (cNameMeta != null) {
			switch cNameMeta.params {
				case [{expr: EConst(CString(name))}]:
					safeIdent(name);
				default:
					Context.error('Incorrect usage, syntax is @${cNameMeta.name}(name: String)', cNameMeta.pos);
			}
		} else null;
	}

	static function generateImplementation() {
		return code('
			import c_' + libName + '

			public func setup(_ handler: @convention(c) @escaping (UnsafePointer<CChar>?)->Void) {
				c_' + libName + '.' + libName + '_setup(handler)
			}

			public func stop(_ wait: Bool) {
				c_' + libName + '.' + libName + '_stop(wait)
			}

			public protocol SDKObject {
				var o: UnsafeMutableRawPointer {get}
			}

			internal func useString(_ mptr: UnsafePointer<CChar>?) -> String? {
				if let ptr = mptr {
					let r = String(cString: ptr)
					c_' + libName + '.' + libName + '_release(ptr)
					return r
				} else {
					return nil
				}
			}

			internal func useString(_ mptr: UnsafeMutableRawPointer?) -> String? {
				return useString(UnsafePointer(mptr?.assumingMemoryBound(to: CChar.self)))
			}

			// From https://github.com/swiftlang/swift/blob/dfc3933a05264c0c19f7cd43ea0dca351f53ed48/stdlib/private/SwiftPrivate/SwiftPrivate.swift
			public func scan<
				S : Sequence, U
			>(_ seq: S, _ initial: U, _ combine: (U, S.Iterator.Element) -> U) -> [U] {
				var result: [U] = []
				result.reserveCapacity(seq.underestimatedCount)
				var runningResult = initial
				for element in seq {
					runningResult = combine(runningResult, element)
					result.append(runningResult)
				}
				return result
			}

			// From https://github.com/swiftlang/swift/blob/dfc3933a05264c0c19f7cd43ea0dca351f53ed48/stdlib/private/SwiftPrivate/SwiftPrivate.swift
			internal func withArrayOfCStrings<R>(
				_ args: [String], _ body: ([UnsafePointer<CChar>?]) -> R
			) -> R {
				let argsCounts = Array(args.map { $0.utf8.count + 1 })
				let argsOffsets = [ 0 ] + scan(argsCounts, 0, +)
				let argsBufferSize = argsOffsets.last!

				var argsBuffer: [UInt8] = []
				argsBuffer.reserveCapacity(argsBufferSize)
				for arg in args {
					argsBuffer.append(contentsOf: arg.utf8)
					argsBuffer.append(0)
				}

				return argsBuffer.withUnsafeMutableBufferPointer {
					(argsBuffer) in
					let ptr = UnsafeRawPointer(argsBuffer.baseAddress!).bindMemory(
						to: CChar.self, capacity: argsBuffer.count)
					var cStrings: [UnsafePointer<CChar>?] = argsOffsets.dropLast().map { ptr + $0 }
					return body(cStrings)
				}
			}

			internal func withOptionalArrayOfCStrings<R>(
				_ args: [String]?, _ body: ([UnsafePointer<CChar>?]?) -> R
			) -> R {
				if let args = args {
					return withArrayOfCStrings(args, body)
				} else {
					return body(nil)
				}
			}

		')
		+ queuedClasses.map(c -> convertQueuedClass(c.cls, c.namespace, c.fields)).join("\n") + "\n"
		+ { iterator: () -> knownEnums.keyValueIterator() }.map(e -> "public typealias " + e.key + " = " + e.value + "\n").join("\n")
		;
	}

	/**
		We determine a project name to be the `--main` startup class

		The user can override this with `-D HaxeCBridge.name=ExampleName`

		This isn't rigorously defined but hopefully will produced nicely namespaced and unsurprising function names
	**/
	static function getLibNameFromHaxeArgs(): Null<String> {
		var overrideName = Context.definedValue('HaxeCBridge.name');
		if (overrideName != null && overrideName != '') {
			return safeIdent(overrideName);
		}

		var args = Sys.args();
		
		var mainClassPath = getMainFromHaxeArgs(args);
		if (mainClassPath != null) {
			return safeIdent(mainClassPath);
		}

		// no lib name indicator found in args
		return null;
	}

	static function getMainFromHaxeArgs(args: Array<String>): Null<String> {
		for (i in 0...args.length) {
			var arg = args[i];
			switch arg {
				case '-m', '-main', '--main':
					var classPath = args[i + 1];
					return classPath;
				default:
			}
		}
		return null;
	}

	static function safeIdent(str: String) {
		// replace non a-z0-9_ with _
		str = ~/[^\w]/gi.replace(str, '_');
		// replace leading number with _
		str = ~/^[^a-z_]/i.replace(str, '_');
		// replace empty string with _
		str = str == '' ? '_' : str;
		return str;
	}

}

enum SwiftFunctionInfoKind {
	Constructor;
	Member;
	Static;
}

	#end // (display || display_details || target.name != cpp)

#elseif (cpp && !cppia)
// runtime HaxeSwiftBridge

class HaxeSwiftBridge {}

#end
