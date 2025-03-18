// This example MediaStore is written in JavaScript
// so that SDK users can easily see how to write their own

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

		async storeMedia(mime, buffer) {
			const sha256 = await crypto.subtle.digest("SHA-256", buffer);
			const sha1 = await crypto.subtle.digest("SHA-1", buffer);
			const sha256NiUrl = mkNiUrl("sha-256", sha256);
			await cache.put(sha256NiUrl, new Response(buffer, { headers: { "Content-Type": mime } }));
			if (this.kv) await this.kv.set(mkNiUrl("sha-1", sha1), sha256NiUrl);
			return true;
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

		async hasMedia(hashAlgorithm, hash) {
			const response = await this.getMediaResponse(mkNiUrl(hashAlgorithm, hash));
			return !!response;
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
