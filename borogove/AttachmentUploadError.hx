package borogove;

/**
	Describes a failure while obtaining or using an HTTP Upload slot.

	When `code` is `all-services-failed`, `failures` contains the per-service
	errors in discovery order. A `no-service` error has an empty `failures`
	array because no upload service was discovered.
**/
@:expose
class AttachmentUploadError extends haxe.Exception {
	public final code: AttachmentUploadErrorCode;
	public final serviceId: Null<String>;
	public final statusCode: Null<Int>;
	public final cause: Dynamic;
	public final failures: Array<AttachmentUploadError>;

	public function new(code: AttachmentUploadErrorCode, message: String, ?serviceId: String, ?statusCode: Int, ?cause: Dynamic, ?failures: Array<AttachmentUploadError>) {
		super(message);
		this.code = code;
		this.serviceId = serviceId;
		this.statusCode = statusCode;
		this.cause = cause;
		this.failures = failures ?? [];
	}
}
