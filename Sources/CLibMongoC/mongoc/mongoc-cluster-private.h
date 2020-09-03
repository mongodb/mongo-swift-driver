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

#include "CLibMongoC_mongoc-prelude.h"

#ifndef MONGOC_CLUSTER_PRIVATE_H
#define MONGOC_CLUSTER_PRIVATE_H

#include <CLibMongoC_bson.h>

#include "mongoc-array-private.h"
#include "mongoc-buffer-private.h"
#include "CLibMongoC_mongoc-config.h"
#include "CLibMongoC_mongoc-client.h"
#include "mongoc-list-private.h"
#include "CLibMongoC_mongoc-opcode.h"
#include "mongoc-rpc-private.h"
#include "mongoc-server-stream-private.h"
#include "mongoc-set-private.h"
#include "CLibMongoC_mongoc-stream.h"
#include "mongoc-topology-private.h"
#include "mongoc-topology-description-private.h"
#include "CLibMongoC_mongoc-write-concern.h"
#include "mongoc-scram-private.h"
#include "mongoc-cmd-private.h"
#include "mongoc-crypto-private.h"

BSON_BEGIN_DECLS


typedef struct _mongoc_cluster_node_t {
   mongoc_stream_t *stream;
   char *connection_address;
   uint32_t generation;

   /* TODO CDRIVER-3653, these fields are unused. */
   int32_t max_wire_version;
   int32_t min_wire_version;
   int32_t max_write_batch_size;
   int32_t max_bson_obj_size;
   int32_t max_msg_size;
} mongoc_cluster_node_t;

typedef struct _mongoc_cluster_t {
   int64_t operation_id;
   uint32_t request_id;
   uint32_t sockettimeoutms;
   uint32_t socketcheckintervalms;
   mongoc_uri_t *uri;
   unsigned requires_auth : 1;

   mongoc_client_t *client;

   mongoc_set_t *nodes;
   mongoc_array_t iov;

   mongoc_scram_cache_t *scram_cache;
} mongoc_cluster_t;


void
mongoc_cluster_init (mongoc_cluster_t *cluster,
                     const mongoc_uri_t *uri,
                     void *client);

void
mongoc_cluster_destroy (mongoc_cluster_t *cluster);

void
mongoc_cluster_disconnect_node (mongoc_cluster_t *cluster, uint32_t id);

int32_t
mongoc_cluster_get_max_bson_obj_size (mongoc_cluster_t *cluster);

int32_t
mongoc_cluster_get_max_msg_size (mongoc_cluster_t *cluster);

size_t
_mongoc_cluster_buffer_iovec (mongoc_iovec_t *iov,
                              size_t iovcnt,
                              int skip,
                              char *buffer);

bool
mongoc_cluster_check_interval (mongoc_cluster_t *cluster, uint32_t server_id);

bool
mongoc_cluster_legacy_rpc_sendv_to_server (
   mongoc_cluster_t *cluster,
   mongoc_rpc_t *rpcs,
   mongoc_server_stream_t *server_stream,
   bson_error_t *error);

bool
mongoc_cluster_try_recv (mongoc_cluster_t *cluster,
                         mongoc_rpc_t *rpc,
                         mongoc_buffer_t *buffer,
                         mongoc_server_stream_t *server_stream,
                         bson_error_t *error);

mongoc_server_stream_t *
mongoc_cluster_stream_for_reads (mongoc_cluster_t *cluster,
                                 const mongoc_read_prefs_t *read_prefs,
                                 mongoc_client_session_t *cs,
                                 bson_t *reply,
                                 bson_error_t *error);

mongoc_server_stream_t *
mongoc_cluster_stream_for_writes (mongoc_cluster_t *cluster,
                                  mongoc_client_session_t *cs,
                                  bson_t *reply,
                                  bson_error_t *error);

mongoc_server_stream_t *
mongoc_cluster_stream_for_server (mongoc_cluster_t *cluster,
                                  uint32_t server_id,
                                  bool reconnect_ok,
                                  mongoc_client_session_t *cs,
                                  bson_t *reply,
                                  bson_error_t *error);

bool
mongoc_cluster_stream_valid (mongoc_cluster_t *cluster,
                             mongoc_server_stream_t *server_stream);

bool
mongoc_cluster_run_command_monitored (mongoc_cluster_t *cluster,
                                      mongoc_cmd_t *cmd,
                                      bson_t *reply,
                                      bson_error_t *error);

bool
mongoc_cluster_run_command_parts (mongoc_cluster_t *cluster,
                                  mongoc_server_stream_t *server_stream,
                                  mongoc_cmd_parts_t *parts,
                                  bson_t *reply,
                                  bson_error_t *error);

bool
mongoc_cluster_run_command_private (mongoc_cluster_t *cluster,
                                    mongoc_cmd_t *cmd,
                                    bson_t *reply,
                                    bson_error_t *error);

void
_mongoc_cluster_build_sasl_start (bson_t *cmd,
                                  const char *mechanism,
                                  const char *buf,
                                  uint32_t buflen);

void
_mongoc_cluster_build_sasl_continue (bson_t *cmd,
                                     int conv_id,
                                     const char *buf,
                                     uint32_t buflen);

int
_mongoc_cluster_get_conversation_id (const bson_t *reply);

mongoc_server_stream_t *
_mongoc_cluster_create_server_stream (mongoc_topology_t *topology,
                                      uint32_t server_id,
                                      mongoc_stream_t *stream,
                                      bson_error_t *error /* OUT */);

bool
_mongoc_cluster_get_auth_cmd_x509 (const mongoc_uri_t *uri,
                                   const mongoc_ssl_opt_t *ssl_opts,
                                   bson_t *cmd /* OUT */,
                                   bson_error_t *error /* OUT */);

#ifdef MONGOC_ENABLE_CRYPTO
void
_mongoc_cluster_init_scram (const mongoc_cluster_t *cluster,
                            mongoc_scram_t *scram,
                            mongoc_crypto_hash_algorithm_t algo);

bool
_mongoc_cluster_get_auth_cmd_scram (mongoc_crypto_hash_algorithm_t algo,
                                    mongoc_scram_t *scram,
                                    bson_t *cmd /* OUT */,
                                    bson_error_t *error /* OUT */);
#endif /* MONGOC_ENABLE_CRYPTO */

BSON_END_DECLS


#endif /* MONGOC_CLUSTER_PRIVATE_H */
