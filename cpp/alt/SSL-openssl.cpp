#include <string.h>

#ifdef HX_WINDOWS
#	include <winsock2.h>
#	include <wincrypt.h>
#else
#	include <sys/socket.h>
#	include <strings.h>
#	include <errno.h>
typedef int SOCKET;
#endif

#include <hxcpp.h>
#include <hx/OS.h>

#if defined(NEKO_MAC) && !defined(IPHONE) && !defined(APPLETV)
#include <Security/Security.h>
#endif

typedef size_t socket_int;

#define SOCKET_ERROR (-1)
#define NRETRYS 20

// --- OpenSSL Headers ---
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <openssl/pem.h>
#include <openssl/evp.h>
#include <openssl/rand.h>

#define val_ssl(o)	((sslctx*)o.mPtr)
#define val_conf(o)	((sslconf*)o.mPtr)
#define val_cert(o) ((sslcert*)o.mPtr)
#define val_pkey(o) ((sslpkey*)o.mPtr)

struct SocketWrapper : public hx::Object
{
	HX_IS_INSTANCE_OF enum { _hx_ClassId = hx::clsIdSocket };
	SOCKET socket;
};

struct sslctx : public hx::Object
{
	HX_IS_INSTANCE_OF enum { _hx_ClassId = hx::clsIdSsl };

	SSL *s;

	void create(SSL_CTX *ctx)
	{
		s = SSL_new(ctx);
		_hx_set_finalizer(this, finalize);
	}

	void destroy()
	{
		if( s )
		{
			SSL_free(s);
			s = NULL;
		}
	}

	static void finalize(Dynamic obj)
	{
		((sslctx *)(obj.mPtr))->destroy();
	}

	String toString() { return HX_CSTRING("sslctx"); }
};

struct sslconf : public hx::Object
{
	HX_IS_INSTANCE_OF enum { _hx_ClassId = hx::clsIdSslConf };

	SSL_CTX *c;

	void create(bool server)
	{
		// Use general purpose TLS methods
		const SSL_METHOD *method = server ? TLS_server_method() : TLS_client_method();
		c = SSL_CTX_new(method);
		_hx_set_finalizer(this, finalize);
	}

	void destroy()
	{
		if( c )
		{
			SSL_CTX_free(c);
			c = NULL;
		}
	}

	static void finalize(Dynamic obj)
	{
		((sslconf *)(obj.mPtr))->destroy();
	}

	String toString() { return HX_CSTRING("sslconfig"); }
};

struct sslcert : public hx::Object
{
	HX_IS_INSTANCE_OF enum { _hx_ClassId = hx::clsIdSslCert };

	STACK_OF(X509) *chain;
	int current_index;
	bool head;

	void create(X509 *inC, STACK_OF(X509) *inChain = NULL, int index = 0)
	{
		current_index = index;
		if( inChain ) {
			chain = inChain;
			head = false;
		} else {
			chain = sk_X509_new_null();
			if (inC) sk_X509_push(chain, inC);
			head = true;
		}
		_hx_set_finalizer(this, finalize);
	}

	void destroy()
	{
		if( chain && head )
		{
			sk_X509_pop_free(chain, X509_free);
			chain = NULL;
		}
	}

	X509* get_current() {
		if (!chain || current_index >= sk_X509_num(chain)) return NULL;
		return sk_X509_value(chain, current_index);
	}

	static void finalize(Dynamic obj)
	{
		((sslcert *)(obj.mPtr))->destroy();
	}

	String toString() { return HX_CSTRING("sslcert"); }
};

struct sslpkey : public hx::Object
{
	HX_IS_INSTANCE_OF enum { _hx_ClassId = hx::clsIdSslKey };

	EVP_PKEY *k;

	void create(EVP_PKEY *inK = NULL)
	{
		k = inK;
		_hx_set_finalizer(this, finalize);
	}

	void destroy()
	{
		if( k )
		{
			EVP_PKEY_free(k);
			k = NULL;
		}
	}

	static void finalize(Dynamic obj)
	{
		((sslpkey *)(obj.mPtr))->destroy();
	}

	String toString() { return HX_CSTRING("sslpkey"); }
};

static void ssl_error(const char* prefix = NULL){
	unsigned long errCode = ERR_get_error();
	char buf[256];
	ERR_error_string_n(errCode, buf, sizeof(buf));
	String msg = String(buf);
	if (prefix) msg = String(prefix) + HX_CSTRING(": ") + msg;
	hx::Throw( msg );
}

static bool is_ssl_blocking( SSL* ssl, int r ) {
	int err = SSL_get_error(ssl, r);
	return err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE;
}

Dynamic _hx_ssl_new( Dynamic hconf ) {
	sslctx *ssl = new sslctx();
	sslconf *conf = val_conf(hconf);
	ssl->create(conf->c);
	if (!ssl->s) {
		ssl->destroy();
		ssl_error("SSL_new failed");
	}
	return ssl;
}

void _hx_ssl_close( Dynamic hssl ) {
	sslctx *ssl = val_ssl(hssl);
	ssl->destroy();
}

void _hx_ssl_debug_set (int i) {
	// OpenSSL debug is typically handled differently, often compiled in.
	// For standard builds, we leave this as a no-op or wire to tracing.
}

void _hx_ssl_handshake( Dynamic hssl ) {
	int r;
	sslctx *ssl = val_ssl(hssl);
	POSIX_LABEL(handshake_again);

	hx::EnterGCFreeZone();
	r = SSL_do_handshake( ssl->s );
	hx::ExitGCFreeZone();

	if (r <= 0) {
		if ( is_ssl_blocking(ssl->s, r) ) {
			HANDLE_EINTR(handshake_again);
			hx::Throw(HX_CSTRING("Blocking"));
		} else {
			ssl_error("Handshake failed");
		}
	}
}

void _hx_ssl_set_socket( Dynamic hssl, Dynamic hsocket ) {
	sslctx *ssl = val_ssl(hssl);
	SocketWrapper *socket = (SocketWrapper *)hsocket.mPtr;
	// OpenSSL native file descriptor binding
	SSL_set_fd( ssl->s, (int)socket->socket );
}

void _hx_ssl_set_hostname( Dynamic hssl, String hostname ){
	sslctx *ssl = val_ssl(hssl);
	hx::strbuf buf;
	if( SSL_set_tlsext_host_name(ssl->s, hostname.utf8_str(&buf)) != 1 )
		ssl_error("Failed setting hostname SNI");
}

Dynamic _hx_ssl_get_peer_certificate( Dynamic hssl ){
	sslctx *ssl = val_ssl(hssl);
	X509 *crt = SSL_get_peer_certificate(ssl->s);
	if( crt == NULL )
		return null();
	sslcert *cert = new sslcert();
	cert->create( crt );
	return cert;
}

bool _hx_ssl_get_verify_result( Dynamic hssl ){
	sslctx *ssl = val_ssl(hssl);
	long r = SSL_get_verify_result( ssl->s );
	if( r == X509_V_OK )
		return true;
	return false;
}

void _hx_ssl_send_char( Dynamic hssl, int c ) {
	if( c < 0 || c > 255 )
		hx::Throw( HX_CSTRING("invalid char") );
	sslctx *ssl = val_ssl(hssl);
	const unsigned char cc = c;
	int r = SSL_write( ssl->s, &cc, 1 );
	if (r <= 0) ssl_error("Send char failed");
}

int _hx_ssl_send( Dynamic hssl, Array<unsigned char> buf, int p, int l ) {
	sslctx *ssl = val_ssl(hssl);
	int dlen = buf->length;
	if( p < 0 || l < 0 || p > dlen || p + l > dlen )
		hx::Throw( HX_CSTRING("ssl_send bounds") );

	POSIX_LABEL(send_again);
	const unsigned char *base = (const unsigned char *)&buf[0];

	hx::EnterGCFreeZone();
	dlen = SSL_write( ssl->s, base + p, l );
	hx::ExitGCFreeZone();

	if (dlen <= 0) {
		if ( is_ssl_blocking(ssl->s, dlen) ) {
			HANDLE_EINTR(send_again);
			hx::Throw(HX_CSTRING("Blocking"));
		} else {
			hx::Throw(HX_CSTRING("ssl network error"));
		}
	}
	return dlen;
}

void _hx_ssl_write( Dynamic hssl, Array<unsigned char> buf ) {
	sslctx *ssl = val_ssl(hssl);
	int len = buf->length;
	unsigned char *cdata = &buf[0];
	while( len > 0 ) {
		POSIX_LABEL( write_again );

		hx::EnterGCFreeZone();
		int slen = SSL_write( ssl->s, cdata, len );
		hx::ExitGCFreeZone();

		if (slen <= 0) {
			if ( is_ssl_blocking(ssl->s, slen) ) {
				HANDLE_EINTR( write_again );
				hx::Throw(HX_CSTRING("Blocking"));
			} else {
				hx::Throw(HX_CSTRING("ssl network error"));
			}
		}
		cdata += slen;
		len -= slen;
	}
}

int _hx_ssl_recv_char( Dynamic hssl ) {
	sslctx *ssl = val_ssl(hssl);
	unsigned char cc;
	int r = SSL_read( ssl->s, &cc, 1 );
	if( r <= 0 )
		hx::Throw( HX_CSTRING("ssl_recv_char") );
	return (int)cc;
}

int _hx_ssl_recv( Dynamic hssl, Array<unsigned char> buf, int p, int l ) {
	sslctx *ssl = val_ssl(hssl);
	int dlen = buf->length;
	if( p < 0 || l < 0 || p > dlen || p + l > dlen )
		hx::Throw( HX_CSTRING("ssl_recv bounds") );

	unsigned char *base = &buf[0];
	POSIX_LABEL(recv_again);

	hx::EnterGCFreeZone();
	dlen = SSL_read( ssl->s, base + p, l );
	hx::ExitGCFreeZone();

	if (dlen <= 0) {
		int err = SSL_get_error(ssl->s, dlen);
		if (err == SSL_ERROR_ZERO_RETURN) { // Peer closed connection
			return 0;
		} else if (err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE) {
			HANDLE_EINTR(recv_again);
			hx::Throw(HX_CSTRING("Blocking"));
		} else {
			hx::Throw(HX_CSTRING("ssl network error"));
		}
	}
	return dlen;
}

Array<unsigned char> _hx_ssl_read( Dynamic hssl ) {
	sslctx *ssl = val_ssl(hssl);
	Array<unsigned char> result = Array_obj<unsigned char>::__new();
	unsigned char buf[256];

	while( true ) {
		POSIX_LABEL(read_again);

		hx::EnterGCFreeZone();
		int len = SSL_read( ssl->s, buf, 256 );
		hx::ExitGCFreeZone();

		if (len <= 0) {
			int err = SSL_get_error(ssl->s, len);
			if (err == SSL_ERROR_ZERO_RETURN) {
				break; // Graceful shutdown
			} else if (err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE) {
				HANDLE_EINTR(read_again);
				hx::Throw(HX_CSTRING("Blocking"));
			} else {
				hx::Throw(HX_CSTRING("ssl network error"));
			}
		}
		result->memcpy(result->length, buf, len);
	}
	return result;
}

Dynamic _hx_ssl_conf_new( bool server ) {
	sslconf *conf = new sslconf();
	conf->create(server);
	if( !conf->c ){
		conf->destroy();
		ssl_error("SSL_CTX_new failed");
	}
	return conf;
}

void _hx_ssl_conf_close( Dynamic hconf ) {
	sslconf *conf = val_conf(hconf);
	conf->destroy();
}

void _hx_ssl_conf_set_ca( Dynamic hconf, Dynamic hcert ) {
	sslconf *conf = val_conf(hconf);
	if( hcert.mPtr ){
		sslcert *cert = val_cert(hcert);
		X509_STORE *store = SSL_CTX_get_cert_store(conf->c);
		for(int i=0; i < sk_X509_num(cert->chain); i++) {
			X509_STORE_add_cert(store, sk_X509_value(cert->chain, i));
		}
	}
}

void _hx_ssl_conf_set_verify( Dynamic hconf, int mode ) {
	sslconf *conf = val_conf(hconf);
	if( mode == 2 ) // Optional
		SSL_CTX_set_verify(conf->c, SSL_VERIFY_PEER, NULL);
	else if( mode == 1 ) // Required
		SSL_CTX_set_verify(conf->c, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, NULL);
	else
		SSL_CTX_set_verify(conf->c, SSL_VERIFY_NONE, NULL);
}

void _hx_ssl_conf_set_cert( Dynamic hconf, Dynamic hcert, Dynamic hpkey ) {
	sslconf *conf = val_conf(hconf);
	sslcert *cert = val_cert(hcert);
	sslpkey *pkey = val_pkey(hpkey);

	if (SSL_CTX_use_certificate(conf->c, cert->get_current()) != 1)
		ssl_error("Failed to use certificate");

	if (SSL_CTX_use_PrivateKey(conf->c, pkey->k) != 1)
		ssl_error("Failed to use private key");

	if (SSL_CTX_check_private_key(conf->c) != 1)
		ssl_error("Private key does not match certificate");
}

// Callback for Server Name Indication (SNI)
static int sni_callback(SSL *s, int *al, void *arg) {
	const char *servername = SSL_get_servername(s, TLSEXT_NAMETYPE_host_name);
	if( servername && arg ){
		Dynamic cb = new Dynamic();
		cb.mPtr = (hx::Object*)arg;
		Dynamic ret = cb->__run( String(servername) );
		if( ret != null() ){
			Dynamic hcert = ret->__Field(HX_CSTRING("cert"), hx::paccDynamic);
			Dynamic hpkey = ret->__Field(HX_CSTRING("key"), hx::paccDynamic);
			sslcert *cert = val_cert(hcert);
			sslpkey *pk = val_pkey(hpkey);

			SSL_use_certificate(s, cert->get_current());
			SSL_use_PrivateKey(s, pk->k);
			return SSL_TLSEXT_ERR_OK;
		}
	}
	return SSL_TLSEXT_ERR_NOACK;
}

void _hx_ssl_conf_set_servername_callback( Dynamic hconf, Dynamic cb ){
	sslconf *conf = val_conf(hconf);
	SSL_CTX_set_tlsext_servername_callback(conf->c, sni_callback);
	SSL_CTX_set_tlsext_servername_arg(conf->c, (void*)cb.mPtr);
}

Dynamic _hx_ssl_cert_load_defaults(){
#if defined(NEKO_WINDOWS)
	HCERTSTORE store;
	PCCERT_CONTEXT cert = NULL;
	sslcert *chain = NULL;
	if( store = CertOpenSystemStore(0, (LPCSTR)"Root") ){
		while( cert = CertEnumCertificatesInStore(store, cert) ){
			if( chain == NULL ){
				chain = new sslcert();
				chain->create( NULL );
			}
			const unsigned char *p = (const unsigned char *)cert->pbCertEncoded;
			X509 *x = d2i_X509(NULL, &p, cert->cbCertEncoded);
			if (x) sk_X509_push(chain->chain, x);
		}
		CertCloseStore(store, 0);
	}
	if( chain != NULL )
		return chain;
#elif defined(NEKO_MAC) && !defined(IPHONE) && !defined(APPLETV)
	CFMutableDictionaryRef search;
	CFArrayRef result;
	SecKeychainRef keychain;
	SecCertificateRef item;
	CFDataRef dat;
	sslcert *chain = NULL;

	if( SecKeychainOpen("/System/Library/Keychains/SystemRootCertificates.keychain",&keychain) != errSecSuccess )
		return null();

	search = CFDictionaryCreateMutable( NULL, 0, NULL, NULL );
	CFDictionarySetValue( search, kSecClass, kSecClassCertificate );
	CFDictionarySetValue( search, kSecMatchLimit, kSecMatchLimitAll );
	CFDictionarySetValue( search, kSecReturnRef, kCFBooleanTrue );
	CFDictionarySetValue( search, kSecMatchSearchList, CFArrayCreate(NULL, (const void **)&keychain, 1, NULL) );

	if( SecItemCopyMatching( search, (CFTypeRef *)&result ) == errSecSuccess ){
		CFIndex n = CFArrayGetCount( result );
		for( CFIndex i = 0; i < n; i++ ){
			item = (SecCertificateRef)CFArrayGetValueAtIndex( result, i );
			dat = SecCertificateCopyData( item );
			if( dat ){
				if( chain == NULL ){
					chain = new sslcert();
					chain->create( NULL );
				}
				const unsigned char *p = (const unsigned char *)CFDataGetBytePtr(dat);
				X509 *x = d2i_X509(NULL, &p, CFDataGetLength(dat));
				if(x) sk_X509_push(chain->chain, x);
				CFRelease( dat );
			}
		}
	}
	CFRelease(keychain);
	if( chain != NULL )
		return chain;
#endif
	return null();
}

Dynamic _hx_ssl_cert_load_file( String file ){
	sslcert *cert = new sslcert();
	cert->create( NULL );
	hx::strbuf buf;
	FILE *fp = fopen(file.utf8_str(&buf), "r");
	if (!fp) {
		cert->destroy();
		hx::Throw(HX_CSTRING("File not found"));
	}

	X509 *x;
	while ((x = PEM_read_X509(fp, NULL, NULL, NULL)) != NULL) {
		sk_X509_push(cert->chain, x);
	}
	fclose(fp);

	if(sk_X509_num(cert->chain) == 0) {
		cert->destroy();
		ssl_error("Failed reading cert file");
	}
	return cert;
}

Dynamic _hx_ssl_cert_load_path( String path ){
	// Usually implemented by loading all certs in a directory. OpenSSL handles this differently.
	// For exact match of functionality, you could use X509_LOOKUP_hash_dir
	hx::Throw( HX_CSTRING("Path loading needs explicit implementation in OpenSSL") );
	return null();
}

String _hx_ssl_cert_get_subject( Dynamic hcert, String objname ){
	sslcert *cert = val_cert(hcert);
	X509 *c = cert->get_current();
	if (!c) hx::Throw( HX_CSTRING("cert_get_subject") );

	hx::strbuf buf;
	int nid = OBJ_txt2nid(objname.utf8_str(&buf));
	X509_NAME *subj = X509_get_subject_name(c);
	int loc = X509_NAME_get_index_by_NID(subj, nid, -1);
	if (loc == -1) return String();

	X509_NAME_ENTRY *entry = X509_NAME_get_entry(subj, loc);
	ASN1_STRING *data = X509_NAME_ENTRY_get_data(entry);

	return String((const char*)ASN1_STRING_get0_data(data), ASN1_STRING_length(data));
}

String _hx_ssl_cert_get_issuer( Dynamic hcert, String objname ){
	sslcert *cert = val_cert(hcert);
	X509 *c = cert->get_current();
	if (!c) hx::Throw( HX_CSTRING("cert_get_issuer") );

	hx::strbuf buf;
	int nid = OBJ_txt2nid(objname.utf8_str(&buf));
	X509_NAME *issuer = X509_get_issuer_name(c);
	int loc = X509_NAME_get_index_by_NID(issuer, nid, -1);
	if (loc == -1) return String();

	X509_NAME_ENTRY *entry = X509_NAME_get_entry(issuer, loc);
	ASN1_STRING *data = X509_NAME_ENTRY_get_data(entry);

	return String((const char*)ASN1_STRING_get0_data(data), ASN1_STRING_length(data));
}

Array<String> _hx_ssl_cert_get_altnames( Dynamic hcert ){
	sslcert *cert = val_cert(hcert);
	X509 *c = cert->get_current();
	Array<String> result(0,1);

	STACK_OF(GENERAL_NAME) *altnames = (STACK_OF(GENERAL_NAME)*)X509_get_ext_d2i(c, NID_subject_alt_name, NULL, NULL);
	if (altnames) {
		int num = sk_GENERAL_NAME_num(altnames);
		for (int i = 0; i < num; ++i) {
			GENERAL_NAME *val = sk_GENERAL_NAME_value(altnames, i);
			if (val->type == GEN_DNS) {
				result.Add(String((const char*)ASN1_STRING_get0_data(val->d.dNSName), ASN1_STRING_length(val->d.dNSName)));
			}
		}
		sk_GENERAL_NAME_pop_free(altnames, GENERAL_NAME_free);
	}
	return result;
}

static Array<int> asn1_time_to_array( const ASN1_TIME *time ){
	Array<int> result(6,6);
	struct tm tm_info;

	if (ASN1_TIME_to_tm(time, &tm_info)) {
		result[0] = tm_info.tm_year + 1900;
		result[1] = tm_info.tm_mon + 1;
		result[2] = tm_info.tm_mday;
		result[3] = tm_info.tm_hour;
		result[4] = tm_info.tm_min;
		result[5] = tm_info.tm_sec;
	}
	return result;
}

Array<int> _hx_ssl_cert_get_notbefore( Dynamic hcert ){
	sslcert *cert = val_cert(hcert);
	X509 *c = cert->get_current();
	if( !c ) hx::Throw( HX_CSTRING("cert_get_notbefore") );
	return asn1_time_to_array( X509_get0_notBefore(c) );
}

Array<int> _hx_ssl_cert_get_notafter( Dynamic hcert ){
	sslcert *cert = val_cert(hcert);
	X509 *c = cert->get_current();
	if( !c ) hx::Throw( HX_CSTRING("cert_get_notafter") );
	return asn1_time_to_array( X509_get0_notAfter(c) );
}

Dynamic _hx_ssl_cert_get_next( Dynamic hcert ){
	sslcert *cert = val_cert(hcert);
	if (cert->current_index + 1 >= sk_X509_num(cert->chain)) {
		return null();
	}
	sslcert *next_cert = new sslcert();
	next_cert->create(NULL, cert->chain, cert->current_index + 1);
	return next_cert;
}

Dynamic _hx_ssl_cert_add_pem( Dynamic hcert, String data ){
	#ifdef HX_SMART_STRINGS
	if (data.isUTF16Encoded())
		hx::Throw( HX_CSTRING("Invalid data encoding") );
	#endif
	sslcert *cert = val_cert(hcert);
	if( !cert ){
		cert = new sslcert();
		cert->create( NULL );
	}

	BIO *bio = BIO_new_mem_buf(data.raw_ptr(), data.length);
	X509 *x;
	int added = 0;
	while ((x = PEM_read_bio_X509(bio, NULL, NULL, NULL)) != NULL) {
		sk_X509_push(cert->chain, x);
		added++;
	}
	BIO_free(bio);

	if( added == 0 ){
		if (cert->current_index == 0) cert->destroy();
		ssl_error("Failed to parse PEM cert");
	}
	return cert;
}

Dynamic _hx_ssl_cert_add_der( Dynamic hcert, Array<unsigned char> buf ){
	sslcert *cert = val_cert(hcert);
	if( !cert ){
		cert = new sslcert();
		cert->create( NULL );
	}

	const unsigned char *p = &buf[0];
	X509 *x = d2i_X509(NULL, &p, buf->length);
	if( !x ){
		if (cert->current_index == 0) cert->destroy();
		ssl_error("Failed to parse DER cert");
	}
	sk_X509_push(cert->chain, x);
	return cert;
}

Dynamic _hx_ssl_key_from_der( Array<unsigned char> buf, bool pub ){
	sslpkey *pk = new sslpkey();

	const unsigned char *p = &buf[0];
	EVP_PKEY *key = NULL;
	if (pub) {
		key = d2i_PUBKEY(NULL, &p, buf->length);
	} else {
		key = d2i_AutoPrivateKey(NULL, &p, buf->length);
	}

	if( !key ){
		ssl_error("Failed parsing DER key");
	}
	pk->create(key);
	return pk;
}

Dynamic _hx_ssl_key_from_pem( String data, bool pub, String pass ){
	#ifdef HX_SMART_STRINGS
	if (data.isUTF16Encoded())
		hx::Throw( HX_CSTRING("Invalid data encoding") );
	#endif
	sslpkey *pk = new sslpkey();

	BIO *bio = BIO_new_mem_buf(data.raw_ptr(), data.length);
	EVP_PKEY *key = NULL;

	if (pub) {
		key = PEM_read_bio_PUBKEY(bio, NULL, NULL, NULL);
	} else {
		if (pass == null()) {
			key = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
		} else {
			Array<unsigned char> pbytes(0,0);
			__hxcpp_bytes_of_string(pbytes,pass);
			key = PEM_read_bio_PrivateKey(bio, NULL, NULL, (void*)pbytes->GetBase());
		}
	}
	BIO_free(bio);

	if( !key ){
		ssl_error("Failed parsing PEM key");
	}
	pk->create(key);
	return pk;
}

Array<unsigned char> _hx_ssl_dgst_make( Array<unsigned char> buf, String alg ){
	hx::strbuf ubuf;
	const EVP_MD *md = EVP_get_digestbyname(alg.utf8_str(&ubuf));
	if( md == NULL ) hx::Throw( HX_CSTRING("Invalid hash algorithm") );

	unsigned int size = EVP_MD_size(md);
	Array<unsigned char> out = Array_obj<unsigned char>::__new(size,size);

	EVP_MD_CTX *ctx = EVP_MD_CTX_new();
	EVP_DigestInit_ex(ctx, md, NULL);
	EVP_DigestUpdate(ctx, &buf[0], buf->length);
	EVP_DigestFinal_ex(ctx, &out[0], &size);
	EVP_MD_CTX_free(ctx);

	return out;
}

Array<unsigned char> _hx_ssl_dgst_sign( Array<unsigned char> buf, Dynamic hpkey, String alg ){
	sslpkey *pk = val_pkey(hpkey);
	hx::strbuf ubuf;
	const EVP_MD *md = EVP_get_digestbyname( alg.utf8_str(&ubuf) );
	if( md == NULL ) hx::Throw( HX_CSTRING("Invalid hash algorithm") );

	EVP_MD_CTX *ctx = EVP_MD_CTX_new();
	if( EVP_DigestSignInit(ctx, NULL, md, NULL, pk->k) <= 0 ) {
		EVP_MD_CTX_free(ctx);
		ssl_error("DigestSignInit failed");
	}

	size_t req_len = 0;
	EVP_DigestSign(ctx, NULL, &req_len, &buf[0], buf->length);

	Array<unsigned char> result = Array_obj<unsigned char>::__new(req_len, req_len);
	if( EVP_DigestSign(ctx, &result[0], &req_len, &buf[0], buf->length) <= 0 ) {
		EVP_MD_CTX_free(ctx);
		ssl_error("DigestSign failed");
	}

	EVP_MD_CTX_free(ctx);
	result->__SetSize(req_len);
	return result;
}

bool _hx_ssl_dgst_verify( Array<unsigned char> buf, Array<unsigned char> sign, Dynamic hpkey, String alg ){
	sslpkey *pk = val_pkey(hpkey);
	hx::strbuf ubuf;
	const EVP_MD *md = EVP_get_digestbyname( alg.utf8_str(&ubuf) );
	if( md == NULL ) hx::Throw( HX_CSTRING("Invalid hash algorithm") );

	EVP_MD_CTX *ctx = EVP_MD_CTX_new();
	if( EVP_DigestVerifyInit(ctx, NULL, md, NULL, pk->k) <= 0 ) {
		EVP_MD_CTX_free(ctx);
		return false;
	}

	int r = EVP_DigestVerify(ctx, &sign[0], sign->length, &buf[0], buf->length);
	EVP_MD_CTX_free(ctx);

	return r == 1;
}

static bool _hx_ssl_inited = false;
void _hx_ssl_init() {
	if (_hx_ssl_inited) return;
	_hx_ssl_inited = true;
}
