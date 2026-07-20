// This example MediaStore is written in JavaScript
// so that SDK users can easily see how to write their own

import { borogove_Hash } from "./borogove.js";

export default (cacheName, { routeHashPath } = { routeHashPath: null }) => {
	let cache = null; // Allow the definitions to be sync

	function mkNiUrl(hashAlgorithm, hashBytes) {
		const b64url = btoa(Array.from(new Uint8Array(hashBytes), (x) => String.fromCodePoint(x)).join("")).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
		return "/.well-known/ni/" + hashAlgorithm + "/" + b64url;
	}

	const o = {
		setKV(kv) {
			this.kv = kv;
		},

		async storeMedia(mime, source) {
			const sha256 = borogove_Hash.sha256incr();
			const sha1 = borogove_Hash.sha1incr();
			const tmpPath = "/tmp/" + crypto.randomUUID();
			await cache.put(
				tmpPath,
				new Response(source.pipeThrough(new TransformStream({
					start(controller) {},
					flush(controller) {},
					transform(chunk, controller) {
						sha256.update(chunk);
						sha1.update(chunk);
						controller.enqueue(chunk);
					}
				})), { headers: { "Content-Type": mime } })
			);
			const sha256NiUrl = mkNiUrl("sha-256", sha256.digest().hash);
			if (this.kv) await this.kv.set(mkNiUrl("sha-1", sha1.digest().hash), sha256NiUrl);
			// Copy then delete because move is not supported
			const written = await cache.match(tmpPath);
			await cache.put(sha256NiUrl, written);
			await cache.delete(tmpPath);
			return sha256NiUrl;
		},

		async removeMedia(hashAlgorithm, hash) {
			let niUrl;
			if (hashAlgorithm === "sha-256") {
				niUrl = mkNiUrl(hashAlgorithm, hash);
			} else {
				niUrl = this.kv && await this.kv.get(mkNiUrl(hashAlgorithm, hash));
				if (!niUrl) return;
			}

			await cache.delete(niUrl);
			return true;
		},

		async getMediaResponse(uri) {
			uri = uri.replace(/^ni:\/\/\//, "/.well-known/ni/").replace(/;/, "/");
			var niUrl;
			if (uri.split("/")[3] === "sha-256") {
				niUrl = uri;
			} else {
				niUrl = this.kv && await this.kv.get(uri);
				if (!niUrl) {
					return null;
				}
			}

			return await cache.match(niUrl);
		},

		async hasMedia(hash) {
			const niUrl = mkNiUrl(hash.algorithm, hash.hash);
			const response = await this.getMediaResponse(niUrl);
			if (!response) return null;

			return niUrl;
		}
	};

	if (routeHashPath) {
		const waitForMedia = async (uri) => {
			if (cache) {
				const r = await o.getMediaResponse(uri);
				if (r) return r;
			}
			await new Promise(resolve => setTimeout(resolve, 5000));
			return await waitForMedia(uri);
		};

		self.addEventListener("fetch", (event) => {
			const url = new URL(event.request.url);
			if (url.origin === self.location.origin && url.pathname.startsWith("/.well-known/ni/")) {
				event.respondWith(waitForMedia(url.pathname));
			}
		});
	}

	return caches.open(cacheName).then(c => {
		cache = c;
		return o;
	});
};
