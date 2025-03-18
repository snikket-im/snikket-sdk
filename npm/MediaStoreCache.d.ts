declare function _default(cacheName: any, { routeHashPath }?: {
    routeHashPath: any;
}): Promise<{
    setKV(kv: any): void;
    storeMedia(mime: any, buffer: any): Promise<boolean>;
    removeMedia(hashAlgorithm: any, hash: any): Promise<boolean>;
    getMediaResponse(uri: any): Promise<any>;
    hasMedia(hashAlgorithm: any, hash: any): Promise<boolean>;
}>;
export default _default;
