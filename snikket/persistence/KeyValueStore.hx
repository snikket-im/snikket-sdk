package snikket.persistence;

interface KeyValueStore {
	public function get(k: String, callback: (Null<String>)->Void): Void;
	public function set(k: String, v: Null<String>, callback: ()->Void): Void;
}
