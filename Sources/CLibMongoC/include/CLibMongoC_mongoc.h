/*
 * Copyright 2013 MongoDB, Inc.
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


#ifndef MONGOC_H
#define MONGOC_H


#include "CLibMongoC_bson.h"

#define MONGOC_INSIDE
#include "CLibMongoC_mongoc-macros.h"
#include "CLibMongoC_mongoc-apm.h"
#include "CLibMongoC_mongoc-bulk-operation.h"
#include "CLibMongoC_mongoc-change-stream.h"
#include "CLibMongoC_mongoc-client.h"
#include "CLibMongoC_mongoc-client-pool.h"
#include "CLibMongoC_mongoc-client-side-encryption.h"
#include "CLibMongoC_mongoc-collection.h"
#include "CLibMongoC_mongoc-config.h"
#include "CLibMongoC_mongoc-cursor.h"
#include "CLibMongoC_mongoc-database.h"
#include "CLibMongoC_mongoc-index.h"
#include "CLibMongoC_mongoc-error.h"
#include "CLibMongoC_mongoc-flags.h"
#include "CLibMongoC_mongoc-gridfs.h"
#include "CLibMongoC_mongoc-gridfs-bucket.h"
#include "CLibMongoC_mongoc-gridfs-file.h"
#include "CLibMongoC_mongoc-gridfs-file-list.h"
#include "CLibMongoC_mongoc-gridfs-file-page.h"
#include "CLibMongoC_mongoc-host-list.h"
#include "CLibMongoC_mongoc-init.h"
#include "CLibMongoC_mongoc-matcher.h"
#include "CLibMongoC_mongoc-handshake.h"
#include "CLibMongoC_mongoc-opcode.h"
#include "CLibMongoC_mongoc-log.h"
#include "CLibMongoC_mongoc-socket.h"
#include "CLibMongoC_mongoc-client-session.h"
#include "CLibMongoC_mongoc-stream.h"
#include "CLibMongoC_mongoc-stream-buffered.h"
#include "CLibMongoC_mongoc-stream-file.h"
#include "CLibMongoC_mongoc-stream-gridfs.h"
#include "CLibMongoC_mongoc-stream-socket.h"
#include "CLibMongoC_mongoc-structured-log.h"
#include "CLibMongoC_mongoc-uri.h"
#include "CLibMongoC_mongoc-write-concern.h"
#include "CLibMongoC_mongoc-version.h"
#include "CLibMongoC_mongoc-version-functions.h"
#ifdef MONGOC_ENABLE_SSL
#include "CLibMongoC_mongoc-rand.h"
#include "CLibMongoC_mongoc-stream-tls.h"
#include "CLibMongoC_mongoc-ssl.h"
#endif
#undef MONGOC_INSIDE


#endif /* MONGOC_H */
