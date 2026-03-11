package borogove;

class AttachmentSource {
	public final type: String = "";
	public final name: String = "";
	public final size: Int = 0;

	public function tinkSource() {
		return tink.io.Source.ofError(null);
	}
}
