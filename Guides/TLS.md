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

To require that connections to MongoDB made by the driver use TLS/SSL, simply specify `tls: true` in the `ClientOptions` passed to a `MongoClient`'s initializer:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: ClientOptions(tls: true))
```

Alternatively, `tls=true` can be specified in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed to the initializer:
```swift
let client = try MongoClient("mongodb://example.com/?tls=true", using: elg)
```
**Note:** Specifying any `tls`-prefixed option in the connection string or `ClientOptions` will require all connections made by the driver to use TLS/SSL.

## Specifying a CA File

The driver can be configured to use a specific set of CA certificates. This is most often used with "self-signed" server certificates. 

A path to a file with either a single or bundle of certificate authorities to be considered trusted when making a TLS connection can be specified via the `tlsCAFile` option on `ClientOptions`:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: ClientOptions(tlsCAFile: URL(string: "/path/to/ca.pem")))
```

Alternatively, the path can be specified via the `tlsCAFile` option in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed to the client's initializer:
```swift
let caFile = "/path/to/ca.pem".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let client = try MongoClient("mongodb://example.com/?tlsCAFile=\(caFile)", using: elg)
```

## Specifying a Client Certificate or Private Key File

The driver can be configured to present the client certificate file or the client private key file via the `tlsCertificateKeyFile` option on `ClientOptions`:
```swift
let client = try MongoClient("mongodb://example.com", using: elg, options: ClientOptions(tlsCertificateKeyFile: URL(string: "/path/to/cert.pem")))
```
If the private key is password protected, a password can be supplied via `tlsCertificateKeyFilePassword` on `ClientOptions`:
```swift
let client = try MongoClient(
    "mongodb://example.com",
    using: elg,
    options: ClientOptions(tlsCertificateKeyFile: URL(string: "/path/to/cert.pem"), tlsCertificateKeyFilePassword: <password>)
)
```

Alternatively, these options can be set via the `tlsCertificateKeyFile` and `tlsCertificateKeyFilePassword` options in the [MongoDB Connection String](https://docs.mongodb.com/manual/reference/connection-string/) passed into the initializer:
```swift
let certificatePath = "/path/to/cert.pem".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let password = "not a secure password".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
let client = try MongoClient(
    "mongodb://example.com/?tlsCertificateKeyFile=\(certificatePath)&tlsCertificateKeyFilePassword=\(password)"
    using: elg
)
```
**Note**: In both cases, if both a client certificate and a client private key are needed, the files should be concatenated into a single file which is specified by `tlsCertificateKeyFile`.

