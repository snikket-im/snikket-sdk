package borogove;

@:expose
enum abstract AttachmentUploadErrorCode(String) from String to String {
	var NoService = "no-service";
	var InvalidSlot = "invalid-slot";
	var HttpFailure = "http-failure";
	var NetworkFailure = "network-failure";
	var AllServicesFailed = "all-services-failed";
}
