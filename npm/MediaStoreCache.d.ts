declare function _default(cacheName: any): {
    setKV(kv: any): void;
    storeMedia(mime: any, buffer: any): Promise<boolean>;
    removeMedia(hashAlgorithm: any, hash: any): void;
    routeHashPathSW(): void;
    getMediaResponse(uri: any): Promise<any>;
    hasMedia(hashAlgorithm: any, hash: any): Promise<boolean>;
};
export default _default;
