# Swift Driver TLS/SSL Guide

This guide covers the installation requirements and configuration options for connecting to MongoDB over TLS/SSL in the driver. See the [server documentation](https://docs.mongodb.com/manual/tutorial/configure-ssl/) to configure MongoDB to use TLS/SSL.

## Dependencies

The driver relies on the the TLS/SSL library installed on your system for making secure connections to the database. 
 - On macOS, the driver depends on SecureTransport, the native TLS library for macOS, so no additional installation is required.
 - On Linux, the driver depends on OpenSSL, which is usually bundled with your OS but may require specific installation. The driver also supports LibreSSL through the use of OpenSSL compatibility checks.
 
### Ensuring TLS 1.1+

Industry best practices recommend, and some regulations require, the use of TLS 1.1 or newer. Though no application changes are required for the driver to make use of the newest protocols, some operating systems or versions may not provide a TLS library version new enough to support them.

#### ...on Linux

Users of Linux or other non-macOS Unix can check their OpenSSL version like this:
```
$ openssl version
```
If the version number is less than 1.0.1, support for TLS 1.1 or newer is not available. Contact your operating system vendor for a solution, upgrade to a newer distribution, or manually upgrade your installation of OpenSSL.

#### ...on macOS

macOS 10.13 (High Sierra) and newer support TLS 1.1+.


## Basic Configuration

To require that connections to MongoDB made by the driver use TLS/SSL, specify `tls: true` in the `MongoClientOptions` passed to a `MongoClient`'s initializer:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: MongoClientOptions(tls: true))
```

Alternatively, `tls=true` can be specified in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed to the initializer:
```swift
let client = try MongoClient("mongodb://example.com/?tls=true", using: elg)
```
**Note:** Specifying any `tls`-prefixed option in the connection string or `MongoClientOptions` will require all connections made by the driver to use TLS/SSL.

## Specifying a CA File

The driver can be configured to use a specific set of CA certificates. This is most often used with "self-signed" server certificates. 

A path to a file with either a single or bundle of certificate authorities to be considered trusted when making a TLS connection can be specified via the `tlsCAFile` option on `MongoClientOptions`:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: MongoClientOptions(tlsCAFile: URL(string: "/path/to/ca.pem")))
```

Alternatively, the path can be specified via the `tlsCAFile` option in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed to the client's initializer:
```swift
let caFile = "/path/to/ca.pem".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let client = try MongoClient("mongodb://example.com/?tlsCAFile=\(caFile)", using: elg)
```

## Specifying a Client Certificate or Private Key File

The driver can be configured to present the client certificate file or the client private key file via the `tlsCertificateKeyFile` option on `MongoClientOptions`:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: MongoClientOptions(tlsCertificateKeyFile: URL(string: "/path/to/cert.pem")))
```
If the private key is password protected, a password can be supplied via `tlsCertificateKeyFilePassword` on `MongoClientOptions`:
```swift
let client = try MongoClient(
    "mongodb://example.com",
    using: elg,
    options: MongoClientOptions(tlsCertificateKeyFile: URL(string: "/path/to/cert.pem"), tlsCertificateKeyFilePassword: <password>)
)
```

Alternatively, these options can be set via the `tlsCertificateKeyFile` and `tlsCertificateKeyFilePassword` options in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed into the initializer:
```swift
let certificatePath = "/path/to/cert.pem".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let password = "not a secure password".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let client = try MongoClient(
    "mongodb://example.com/?tlsCertificateKeyFile=\(certificatePath)&tlsCertificateKeyFilePassword=\(password)",
    using: elg
)
```
**Note**: In both cases, if both a client certificate and a client private key are needed, the files should be concatenated into a single file which is specified by `tlsCertificateKeyFile`.

## Server Certificate Validation

The driver will automatically verify the validity of the server certificate, such as issued by configured Certificate
Authority, hostname validation, and expiration.

To overwrite this behavior, it is possible to disable hostname validation, OCSP endpoint revocation checking, and revocation
checking entirely, and allow invalid certificates.

This behavior is controlled using the `tlsAllowInvalidHostnames`, `tlsDisableOCSPEndpointCheck`,
`tlsDisableCertificateRevocationCheck`, and `tlsAllowInvalidCertificates` options respectively. By default, all are set
to false.

It is not recommended to change these defaults as it exposes the client to Man In The Middle attacks (when
`tlsAllowInvalidHostnames` is set), invalid certificates (when `tlsAllowInvalidCertificates` is set), or potentially
revoked certificates (when `tlsDisableOCSPEndpointCheck` or `tlsDisableCertificateRevocationCheck` are set).

Note that `tlsDisableCertificateRevocationCheck` and `tlsDisableOCSPEndpointCheck` have no effect on macOS.

### OCSP on Linux/OpenSSL
The Online Certificate Status Protocol (OCSP) (see [RFC 6960](https://tools.ietf.org/html/rfc6960)) is fully supported
when using OpenSSL 1.0.1+

### OCSP on macOS
The Online Certificate Status Protocol (OCSP) (see [RFC 6960](https://tools.ietf.org/html/rfc6960)) is partially
supported with the following notes:

- The Must-Staple extension (see [RFC 7633](https://tools.ietf.org/html/rfc7633)) is ignored. Connection may continue if
  a Must-Staple certificate is presented with no stapled response (unless the client receives a revoked response from an
  OCSP responder).

- Connection will continue if a Must-Staple certificate is presented without a stapled response and the OCSP responder
  is down.
