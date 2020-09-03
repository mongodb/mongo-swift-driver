/*
 * Copyright 2016 MongoDB, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "CLibMongoC_mongoc-prelude.h"

#ifndef MONGOC_SSL_PRIVATE_H
#define MONGOC_SSL_PRIVATE_H

#include <CLibMongoC_bson.h>
#include "mongoc-uri-private.h"


BSON_BEGIN_DECLS

typedef struct {
   bool tls_disable_certificate_revocation_check;
   bool tls_disable_ocsp_endpoint_check;
} _mongoc_internal_tls_opts_t;

char *
mongoc_ssl_extract_subject (const char *filename, const char *passphrase);

void
_mongoc_ssl_opts_from_uri (mongoc_ssl_opt_t *ssl_opt,
                           _mongoc_internal_tls_opts_t *internal,
                           mongoc_uri_t *uri);
void
_mongoc_ssl_opts_copy_to (const mongoc_ssl_opt_t *src,
                          mongoc_ssl_opt_t *dst,
                          bool copy_internal);

bool
_mongoc_ssl_opts_disable_certificate_revocation_check (
   const mongoc_ssl_opt_t *ssl_opt);

bool
_mongoc_ssl_opts_disable_ocsp_endpoint_check (const mongoc_ssl_opt_t *ssl_opt);

void
_mongoc_ssl_opts_cleanup (mongoc_ssl_opt_t *opt, bool free_internal);

BSON_END_DECLS


#endif /* MONGOC_SSL_PRIVATE_H */
