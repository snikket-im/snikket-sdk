declare function _default(cacheName: any): Promise<{
    setKV(kv: any): void;
    storeMedia(mime: any, buffer: any): Promise<boolean>;
    removeMedia(hashAlgorithm: any, hash: any): Promise<boolean>;
    routeHashPathSW(): void;
    getMediaResponse(uri: any): Promise<Response>;
    hasMedia(hashAlgorithm: any, hash: any): Promise<boolean>;
}>;
export default _default;
