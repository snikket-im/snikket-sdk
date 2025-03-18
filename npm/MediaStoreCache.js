// This example MediaStore is written in JavaScript
// so that SDK users can easily see how to write their own

export default (cacheName) => {
	var cache = null;
	caches.open(cacheName).then((c) => cache = c);

	function mkNiUrl(hashAlgorithm, hashBytes) {
		const b64url = btoa(Array.from(new Uint8Array(hashBytes), (x) => String.fromCodePoint(x)).join("")).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
		return "/.well-known/ni/" + hashAlgorithm + "/" + b64url;
	}

	return {
		setKV(kv) {
			this.kv = kv;
		},

		storeMedia(mime, buffer, callback) {
			(async () => {
				const sha256 = await crypto.subtle.digest("SHA-256", buffer);
				const sha1 = await crypto.subtle.digest("SHA-1", buffer);
				const sha256NiUrl = mkNiUrl("sha-256", sha256);
				await cache.put(sha256NiUrl, new Response(buffer, { headers: { "Content-Type": mime } }));
				if (this.kv) await new Promise((resolve) => this.kv.set(mkNiUrl("sha-1", sha1), sha256NiUrl, resolve));
			})().then(callback);
		},

		removeMedia(hashAlgorithm, hash) {
			(async () => {
				let niUrl;
				if (hashAlgorithm === "sha-256") {
					niUrl = mkNiUrl(hashAlgorithm, hash);
				} else {
					niUrl = this.kv && await new Promise((resolve) => this.kv.get(mkNiUrl(hashAlgorithm, hash), resolve));
					if (!niUrl) return;
				}

				return await cache.delete(niUrl);
			})();
		},

		routeHashPathSW() {
			const waitForMedia = async (uri) => {
				const r = await this.getMediaResponse(uri);
				if (r) return r;
				await new Promise(resolve => setTimeout(resolve, 5000));
				return await waitForMedia(uri);
			};

			addEventListener("fetch", (event) => {
				const url = new URL(event.request.url);
				if (url.pathname.startsWith("/.well-known/ni/")) {
					event.respondWith(waitForMedia(url.pathname));
				}
			});
		},

		async getMediaResponse(uri) {
			uri = uri.replace(/^ni:\/\/\//, "/.well-known/ni/").replace(/;/, "/");
			var niUrl;
			if (uri.split("/")[3] === "sha-256") {
				niUrl = uri;
			} else {
				niUrl = this.kv && await new Promise((resolve) => this.kv.get(uri, resolve));
				if (!niUrl) {
					return null;
				}
			}

			return await cache.match(niUrl);
		},

		hasMedia(hashAlgorithm, hash, callback) {
			(async () => {
				const response = await this.getMediaResponse(mkNiUrl(hashAlgorithm, hash));
				return !!response;
			})().then(callback);
		}
	};
};
