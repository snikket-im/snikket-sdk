package test;

import tink.http.Client.ClientObject;
import tink.http.Request.OutgoingRequest;
import tink.http.Response.IncomingResponse;
import tink.core.Promise;

class FakeHttpClient implements ClientObject {
	public final requests:Array<OutgoingRequest> = [];
	final handler:OutgoingRequest->Promise<IncomingResponse>;

	public function new(handler:OutgoingRequest->Promise<IncomingResponse>) {
		this.handler = handler;
	}

	public function request(request:OutgoingRequest):Promise<IncomingResponse> {
		requests.push(request);
		return handler(request);
	}

	public static function response(statusCode:Int, ?body:String):Promise<IncomingResponse> {
		return Promise.resolve(new IncomingResponse(
			new tink.http.Response.ResponseHeader(statusCode),
			(body ?? "" : tink.io.Source.RealSource)
		));
	}

	public static function bodyFailure(error:tink.core.Error):Promise<IncomingResponse> {
		return Promise.resolve(new IncomingResponse(
			new tink.http.Response.ResponseHeader(201),
			tink.io.Source.ofError(error)
		));
	}

	public static function requestFailure(error:tink.core.Error):Promise<IncomingResponse> {
		return Promise.reject(error);
	}
}
