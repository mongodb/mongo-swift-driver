/*
 * Copyright 2013-present MongoDB, Inc.
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


#include "mongoc-aggregate-private.h"
#include "mongoc-client-private.h"
#include "CLibMongoC_mongoc-collection.h"
#include "mongoc-collection-private.h"
#include "CLibMongoC_mongoc-cursor.h"
#include "mongoc-cursor-private.h"
#include "CLibMongoC_mongoc-database.h"
#include "mongoc-database-private.h"
#include "CLibMongoC_mongoc-error.h"
#include "CLibMongoC_mongoc-log.h"
#include "mongoc-trace-private.h"
#include "mongoc-util-private.h"
#include "mongoc-write-concern-private.h"
#include "mongoc-change-stream-private.h"

#undef MONGOC_LOG_DOMAIN
#define MONGOC_LOG_DOMAIN "database"


/*
 *--------------------------------------------------------------------------
 *
 * _mongoc_database_new --
 *
 *       Create a new instance of mongoc_database_t for @client.
 *
 *       @client must stay valid for the life of the resulting
 *       database structure.
 *
 * Returns:
 *       A newly allocated mongoc_database_t that should be freed with
 *       mongoc_database_destroy().
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

mongoc_database_t *
_mongoc_database_new (mongoc_client_t *client,
                      const char *name,
                      const mongoc_read_prefs_t *read_prefs,
                      const mongoc_read_concern_t *read_concern,
                      const mongoc_write_concern_t *write_concern,
                      int64_t timeout_ms)
{
   mongoc_database_t *db;

   ENTRY;

   BSON_ASSERT_PARAM (client);
   BSON_ASSERT_PARAM (name);

   db = (mongoc_database_t *) bson_malloc0 (sizeof *db);
   db->client = client;
   db->write_concern = write_concern ? mongoc_write_concern_copy (write_concern)
                                     : mongoc_write_concern_new ();
   db->read_concern = read_concern ? mongoc_read_concern_copy (read_concern)
                                   : mongoc_read_concern_new ();
   db->read_prefs = read_prefs ? mongoc_read_prefs_copy (read_prefs)
                               : mongoc_read_prefs_new (MONGOC_READ_PRIMARY);

   db->name = bson_strdup (name);
   db->timeout_ms = timeout_ms;

   RETURN (db);
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_destroy --
 *
 *       Releases resources associated with @database.
 *
 * Returns:
 *       None.
 *
 * Side effects:
 *       Everything.
 *
 *--------------------------------------------------------------------------
 */

void
mongoc_database_destroy (mongoc_database_t *database)
{
   ENTRY;

   if (!database) {
      EXIT;
   }

   if (database->read_prefs) {
      mongoc_read_prefs_destroy (database->read_prefs);
      database->read_prefs = NULL;
   }

   if (database->read_concern) {
      mongoc_read_concern_destroy (database->read_concern);
      database->read_concern = NULL;
   }

   if (database->write_concern) {
      mongoc_write_concern_destroy (database->write_concern);
      database->write_concern = NULL;
   }

   bson_free (database->name);
   bson_free (database);

   EXIT;
}


mongoc_cursor_t *
mongoc_database_aggregate (mongoc_database_t *db,                 /* IN */
                           const bson_t *pipeline,                /* IN */
                           const bson_t *opts,                    /* IN */
                           const mongoc_read_prefs_t *read_prefs) /* IN */
{
   return _mongoc_aggregate (db->client,
                             db->name,
                             MONGOC_QUERY_NONE,
                             pipeline,
                             opts,
                             read_prefs,
                             db->read_prefs,
                             db->read_concern,
                             db->write_concern);
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_copy --
 *
 *       Returns a copy of @database that needs to be freed by calling
 *       mongoc_database_destroy.
 *
 * Returns:
 *       A copy of this database.
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

mongoc_database_t *
mongoc_database_copy (mongoc_database_t *database)
{
   ENTRY;

   BSON_ASSERT_PARAM (database);

   RETURN (_mongoc_database_new (database->client,
                                 database->name,
                                 database->read_prefs,
                                 database->read_concern,
                                 database->write_concern,
                                 database->timeout_ms));
}

mongoc_cursor_t *
mongoc_database_command (mongoc_database_t *database,
                         mongoc_query_flags_t flags,
                         uint32_t skip,
                         uint32_t limit,
                         uint32_t batch_size,
                         const bson_t *command,
                         const bson_t *fields,
                         const mongoc_read_prefs_t *read_prefs)
{
   char *ns;
   mongoc_cursor_t *cursor;

   BSON_ASSERT_PARAM (database);
   BSON_ASSERT_PARAM (command);

   ns = bson_strdup_printf ("%s.$cmd", database->name);

   /* Server Selection Spec: "The generic command method has a default read
    * preference of mode 'primary'. The generic command method MUST ignore any
    * default read preference from client, database or collection
    * configuration. The generic command method SHOULD allow an optional read
    * preference argument."
    */

   /* flags, skip, limit, batch_size, fields are unused */
   cursor = _mongoc_cursor_cmd_deprecated_new (
      database->client, ns, command, read_prefs);
   bson_free (ns);
   return cursor;
}


bool
mongoc_database_command_simple (mongoc_database_t *database,
                                const bson_t *command,
                                const mongoc_read_prefs_t *read_prefs,
                                bson_t *reply,
                                bson_error_t *error)
{
   BSON_ASSERT_PARAM (database);
   BSON_ASSERT_PARAM (command);

   /* Server Selection Spec: "The generic command method has a default read
    * preference of mode 'primary'. The generic command method MUST ignore any
    * default read preference from client, database or collection
    * configuration. The generic command method SHOULD allow an optional read
    * preference argument."
    */

   return _mongoc_client_command_with_opts (database->client,
                                            database->name,
                                            command,
                                            MONGOC_CMD_RAW,
                                            NULL /* opts */,
                                            MONGOC_QUERY_NONE,
                                            read_prefs,
                                            NULL, /* user prefs */
                                            NULL /* read concern */,
                                            NULL /* write concern */,
                                            reply,
                                            error);
}


bool
mongoc_database_read_command_with_opts (mongoc_database_t *database,
                                        const bson_t *command,
                                        const mongoc_read_prefs_t *read_prefs,
                                        const bson_t *opts,
                                        bson_t *reply,
                                        bson_error_t *error)
{
   return _mongoc_client_command_with_opts (database->client,
                                            database->name,
                                            command,
                                            MONGOC_CMD_READ,
                                            opts,
                                            MONGOC_QUERY_NONE,
                                            read_prefs,
                                            database->read_prefs,
                                            database->read_concern,
                                            database->write_concern,
                                            reply,
                                            error);
}


bool
mongoc_database_write_command_with_opts (mongoc_database_t *database,
                                         const bson_t *command,
                                         const bson_t *opts,
                                         bson_t *reply,
                                         bson_error_t *error)
{
   return _mongoc_client_command_with_opts (database->client,
                                            database->name,
                                            command,
                                            MONGOC_CMD_WRITE,
                                            opts,
                                            MONGOC_QUERY_NONE,
                                            NULL, /* user prefs */
                                            database->read_prefs,
                                            database->read_concern,
                                            database->write_concern,
                                            reply,
                                            error);
}


bool
mongoc_database_read_write_command_with_opts (
   mongoc_database_t *database,
   const bson_t *command,
   const mongoc_read_prefs_t *read_prefs /* IGNORED */,
   const bson_t *opts,
   bson_t *reply,
   bson_error_t *error)
{
   return _mongoc_client_command_with_opts (database->client,
                                            database->name,
                                            command,
                                            MONGOC_CMD_RW,
                                            opts,
                                            MONGOC_QUERY_NONE,
                                            read_prefs,
                                            database->read_prefs,
                                            database->read_concern,
                                            database->write_concern,
                                            reply,
                                            error);
}


bool
mongoc_database_command_with_opts (mongoc_database_t *database,
                                   const bson_t *command,
                                   const mongoc_read_prefs_t *read_prefs,
                                   const bson_t *opts,
                                   bson_t *reply,
                                   bson_error_t *error)
{
   return _mongoc_client_command_with_opts (database->client,
                                            database->name,
                                            command,
                                            MONGOC_CMD_RAW,
                                            opts,
                                            MONGOC_QUERY_NONE,
                                            read_prefs,
                                            NULL, /* default prefs */
                                            database->read_concern,
                                            database->write_concern,
                                            reply,
                                            error);
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_drop --
 *
 *       Requests that the MongoDB server drops @database, including all
 *       collections and indexes associated with @database.
 *
 *       Make sure this is really what you want!
 *
 * Returns:
 *       true if @database was dropped.
 *
 * Side effects:
 *       @error may be set.
 *
 *--------------------------------------------------------------------------
 */

bool
mongoc_database_drop (mongoc_database_t *database, bson_error_t *error)
{
   return mongoc_database_drop_with_opts (database, NULL, error);
}


bool
mongoc_database_drop_with_opts (mongoc_database_t *database,
                                const bson_t *opts,
                                bson_error_t *error)
{
   bool ret;
   bson_t cmd;

   BSON_ASSERT_PARAM (database);

   bson_init (&cmd);
   bson_append_int32 (&cmd, "dropDatabase", 12, 1);

   ret = _mongoc_client_command_with_opts (database->client,
                                           database->name,
                                           &cmd,
                                           MONGOC_CMD_WRITE,
                                           opts,
                                           MONGOC_QUERY_NONE,
                                           NULL, /* user prefs */
                                           database->read_prefs,
                                           database->read_concern,
                                           database->write_concern,
                                           NULL, /* reply */
                                           error);
   bson_destroy (&cmd);

   return ret;
}


bool
mongoc_database_remove_user (mongoc_database_t *database,
                             const char *username,
                             bson_error_t *error)
{
   bson_t cmd;
   bool ret;

   ENTRY;

   BSON_ASSERT_PARAM (database);
   BSON_ASSERT_PARAM (username);

   bson_init (&cmd);
   BSON_APPEND_UTF8 (&cmd, "dropUser", username);
   ret = mongoc_database_command_simple (database, &cmd, NULL, NULL, error);
   bson_destroy (&cmd);

   RETURN (ret);
}


bool
mongoc_database_remove_all_users (mongoc_database_t *database,
                                  bson_error_t *error)
{
   bson_t cmd;
   bool ret;

   ENTRY;

   BSON_ASSERT_PARAM (database);

   bson_init (&cmd);
   BSON_APPEND_INT32 (&cmd, "dropAllUsersFromDatabase", 1);
   ret = mongoc_database_command_simple (database, &cmd, NULL, NULL, error);
   bson_destroy (&cmd);

   RETURN (ret);
}


/**
 * mongoc_database_add_user:
 * @database: A #mongoc_database_t.
 * @username: A string containing the username.
 * @password: (allow-none): A string containing password, or NULL.
 * @roles: (allow-none): An optional bson_t of roles.
 * @custom_data: (allow-none): An optional bson_t of data to store.
 * @error: (out) (allow-none): A location for a bson_error_t or %NULL.
 *
 * Creates a new user with access to @database.
 *
 * Returns: None.
 * Side effects: None.
 */
bool
mongoc_database_add_user (mongoc_database_t *database,
                          const char *username,
                          const char *password,
                          const bson_t *roles,
                          const bson_t *custom_data,
                          bson_error_t *error)
{
   bson_t cmd;
   bson_t ar;
   bool ret = false;

   ENTRY;

   BSON_ASSERT_PARAM (database);
   BSON_ASSERT_PARAM (username);

   bson_init (&cmd);
   BSON_APPEND_UTF8 (&cmd, "createUser", username);
   BSON_APPEND_UTF8 (&cmd, "pwd", password);

   if (custom_data) {
      BSON_APPEND_DOCUMENT (&cmd, "customData", custom_data);
   }
   if (roles) {
      BSON_APPEND_ARRAY (&cmd, "roles", roles);
   } else {
      bson_append_array_begin (&cmd, "roles", 5, &ar);
      bson_append_array_end (&cmd, &ar);
   }

   ret = mongoc_database_command_simple (database, &cmd, NULL, NULL, error);

   bson_destroy (&cmd);

   RETURN (ret);
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_get_read_prefs --
 *
 *       Fetch the read preferences for @database.
 *
 * Returns:
 *       A mongoc_read_prefs_t that should not be modified or freed.
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

const mongoc_read_prefs_t *
mongoc_database_get_read_prefs (const mongoc_database_t *database) /* IN */
{
   BSON_ASSERT_PARAM (database);
   return database->read_prefs;
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_set_read_prefs --
 *
 *       Sets the default read preferences for @database.
 *
 * Returns:
 *       None.
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

void
mongoc_database_set_read_prefs (mongoc_database_t *database,
                                const mongoc_read_prefs_t *read_prefs)
{
   BSON_ASSERT_PARAM (database);

   if (database->read_prefs) {
      mongoc_read_prefs_destroy (database->read_prefs);
      database->read_prefs = NULL;
   }

   if (read_prefs) {
      database->read_prefs = mongoc_read_prefs_copy (read_prefs);
   }
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_get_read_concern --
 *
 *       Fetches the read concern for @database.
 *
 * Returns:
 *       A mongoc_read_concern_t that should not be modified or freed.
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

const mongoc_read_concern_t *
mongoc_database_get_read_concern (const mongoc_database_t *database)
{
   BSON_ASSERT_PARAM (database);

   return database->read_concern;
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_set_read_concern --
 *
 *       Set the default read concern for @database.
 *
 * Returns:
 *       None.
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

void
mongoc_database_set_read_concern (mongoc_database_t *database,
                                  const mongoc_read_concern_t *read_concern)
{
   BSON_ASSERT_PARAM (database);

   if (database->read_concern) {
      mongoc_read_concern_destroy (database->read_concern);
      database->read_concern = NULL;
   }

   if (read_concern) {
      database->read_concern = mongoc_read_concern_copy (read_concern);
   }
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_get_write_concern --
 *
 *       Fetches the write concern for @database.
 *
 * Returns:
 *       A mongoc_write_concern_t that should not be modified or freed.
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

const mongoc_write_concern_t *
mongoc_database_get_write_concern (const mongoc_database_t *database)
{
   BSON_ASSERT_PARAM (database);

   return database->write_concern;
}


/*
 *--------------------------------------------------------------------------
 *
 * mongoc_database_set_write_concern --
 *
 *       Set the default write concern for @database.
 *
 * Returns:
 *       None.
 *
 * Side effects:
 *       None.
 *
 *--------------------------------------------------------------------------
 */

void
mongoc_database_set_write_concern (mongoc_database_t *database,
                                   const mongoc_write_concern_t *write_concern)
{
   BSON_ASSERT_PARAM (database);

   if (database->write_concern) {
      mongoc_write_concern_destroy (database->write_concern);
      database->write_concern = NULL;
   }

   if (write_concern) {
      database->write_concern = mongoc_write_concern_copy (write_concern);
   }
}


/**
 * mongoc_database_has_collection:
 * @database: (in): A #mongoc_database_t.
 * @name: (in): The name of the collection to check for.
 * @error: (out) (allow-none): A location for a #bson_error_t, or %NULL.
 *
 * Checks to see if a collection exists within the database on the MongoDB
 * server.
 *
 * This will return %false if their was an error communicating with the
 * server, or if the collection does not exist.
 *
 * If @error is provided, it will first be zeroed. Upon error, error.domain
 * will be set.
 *
 * Returns: %true if @name exists, otherwise %false. @error may be set.
 */
bool
mongoc_database_has_collection (mongoc_database_t *database,
                                const char *name,
                                bson_error_t *error)
{
   bson_iter_t col_iter;
   bool ret = false;
   const char *cur_name;
   bson_t opts = BSON_INITIALIZER;
   bson_t filter;
   mongoc_cursor_t *cursor;
   const bson_t *doc;

   ENTRY;

   BSON_ASSERT_PARAM (database);
   BSON_ASSERT_PARAM (name);

   if (error) {
      memset (error, 0, sizeof *error);
   }

   BSON_APPEND_DOCUMENT_BEGIN (&opts, "filter", &filter);
   BSON_APPEND_UTF8 (&filter, "name", name);
   bson_append_document_end (&opts, &filter);

   cursor = mongoc_database_find_collections_with_opts (database, &opts);
   while (mongoc_cursor_next (cursor, &doc)) {
      if (bson_iter_init (&col_iter, doc) &&
          bson_iter_find (&col_iter, "name") &&
          BSON_ITER_HOLDS_UTF8 (&col_iter) &&
          (cur_name = bson_iter_utf8 (&col_iter, NULL))) {
         if (!strcmp (cur_name, name)) {
            ret = true;
            GOTO (cleanup);
         }
      }
   }

   (void) mongoc_cursor_error (cursor, error);

cleanup:
   mongoc_cursor_destroy (cursor);
   bson_destroy (&opts);

   RETURN (ret);
}


mongoc_cursor_t *
mongoc_database_find_collections (mongoc_database_t *database,
                                  const bson_t *filter,
                                  bson_error_t *error)
{
   bson_t opts = BSON_INITIALIZER;
   mongoc_cursor_t *cursor;

   BSON_ASSERT_PARAM (database);

   if (filter) {
      if (!BSON_APPEND_DOCUMENT (&opts, "filter", filter)) {
         bson_set_error (error,
                         MONGOC_ERROR_BSON,
                         MONGOC_ERROR_BSON_INVALID,
                         "Invalid 'filter' parameter.");
         bson_destroy (&opts);
         return NULL;
      }
   }

   cursor = mongoc_database_find_collections_with_opts (database, &opts);

   bson_destroy (&opts);

   /* this deprecated API returns NULL on error */
   if (mongoc_cursor_error (cursor, error)) {
      mongoc_cursor_destroy (cursor);
      return NULL;
   }

   return cursor;
}


mongoc_cursor_t *
mongoc_database_find_collections_with_opts (mongoc_database_t *database,
                                            const bson_t *opts)
{
   mongoc_cursor_t *cursor;
   bson_t cmd = BSON_INITIALIZER;

   BSON_ASSERT_PARAM (database);

   BSON_APPEND_INT32 (&cmd, "listCollections", 1);

   /* Enumerate Collections Spec: "run listCollections on the primary node in
    * replicaset mode" */
   cursor = _mongoc_cursor_cmd_new (
      database->client, database->name, &cmd, opts, NULL, NULL, NULL);
   if (cursor->error.domain == 0) {
      _mongoc_cursor_prime (cursor);
   }
   bson_destroy (&cmd);

   return cursor;
}


char **
mongoc_database_get_collection_names (mongoc_database_t *database,
                                      bson_error_t *error)
{
   return mongoc_database_get_collection_names_with_opts (
      database, NULL, error);
}


char **
mongoc_database_get_collection_names_with_opts (mongoc_database_t *database,
                                                const bson_t *opts,
                                                bson_error_t *error)
{
   bson_t opts_copy;
   bson_iter_t col;
   const char *name;
   char *namecopy;
   mongoc_array_t strv_buf;
   mongoc_cursor_t *cursor;
   const bson_t *doc;
   char **ret;

   BSON_ASSERT_PARAM (database);

   if (opts) {
      bson_copy_to (opts, &opts_copy);
   } else {
      bson_init (&opts_copy);
   }

   /* nameOnly option is faster in MongoDB 4+, ignored by older versions,
    * see Enumerating Collections Spec */
   if (!bson_has_field (&opts_copy, "nameOnly")) {
      bson_append_bool (&opts_copy, "nameOnly", 8, true);
   }

   cursor = mongoc_database_find_collections_with_opts (database, &opts_copy);

   _mongoc_array_init (&strv_buf, sizeof (char *));

   while (mongoc_cursor_next (cursor, &doc)) {
      if (bson_iter_init (&col, doc) && bson_iter_find (&col, "name") &&
          BSON_ITER_HOLDS_UTF8 (&col) && (name = bson_iter_utf8 (&col, NULL))) {
         namecopy = bson_strdup (name);
         _mongoc_array_append_val (&strv_buf, namecopy);
      }
   }

   /* append a null pointer for the last value. also handles the case
    * of no values. */
   namecopy = NULL;
   _mongoc_array_append_val (&strv_buf, namecopy);

   if (mongoc_cursor_error (cursor, error)) {
      _mongoc_array_destroy (&strv_buf);
      ret = NULL;
   } else {
      ret = (char **) strv_buf.data;
   }

   mongoc_cursor_destroy (cursor);
   bson_destroy (&opts_copy);

   return ret;
}


mongoc_collection_t *
mongoc_database_create_collection (mongoc_database_t *database,
                                   const char *name,
                                   const bson_t *opts,
                                   bson_error_t *error)
{
   mongoc_collection_t *collection = NULL;
   bson_iter_t iter;
   bson_t cmd;
   bool capped = false;

   BSON_ASSERT_PARAM (database);
   BSON_ASSERT_PARAM (name);

   if (strchr (name, '$')) {
      bson_set_error (error,
                      MONGOC_ERROR_NAMESPACE,
                      MONGOC_ERROR_NAMESPACE_INVALID,
                      "The namespace \"%s\" is invalid.",
                      name);
      return NULL;
   }

   if (opts) {
      if (bson_iter_init_find (&iter, opts, "capped")) {
         if (!BSON_ITER_HOLDS_BOOL (&iter)) {
            bson_set_error (error,
                            MONGOC_ERROR_COMMAND,
                            MONGOC_ERROR_COMMAND_INVALID_ARG,
                            "The argument \"capped\" must be a boolean.");
            return NULL;
         }
         capped = bson_iter_bool (&iter);
      }

      if (bson_iter_init_find (&iter, opts, "size")) {
         if (!BSON_ITER_HOLDS_INT (&iter)) {
            bson_set_error (error,
                            MONGOC_ERROR_COMMAND,
                            MONGOC_ERROR_COMMAND_INVALID_ARG,
                            "The argument \"size\" must be an integer.");
            return NULL;
         }
         if (!capped) {
            bson_set_error (
               error,
               MONGOC_ERROR_COMMAND,
               MONGOC_ERROR_COMMAND_INVALID_ARG,
               "The \"size\" parameter requires {\"capped\": true}");
            return NULL;
         }
      }

      if (bson_iter_init_find (&iter, opts, "max")) {
         if (!BSON_ITER_HOLDS_INT (&iter)) {
            bson_set_error (error,
                            MONGOC_ERROR_COMMAND,
                            MONGOC_ERROR_COMMAND_INVALID_ARG,
                            "The argument \"max\" must be an integer.");
            return NULL;
         }
         if (!capped) {
            bson_set_error (
               error,
               MONGOC_ERROR_COMMAND,
               MONGOC_ERROR_COMMAND_INVALID_ARG,
               "The \"max\" parameter requires {\"capped\": true}");
            return NULL;
         }
      }

      if (bson_iter_init_find (&iter, opts, "storageEngine")) {
         if (!BSON_ITER_HOLDS_DOCUMENT (&iter)) {
            bson_set_error (
               error,
               MONGOC_ERROR_COMMAND,
               MONGOC_ERROR_COMMAND_INVALID_ARG,
               "The \"storageEngine\" parameter must be a document");

            return NULL;
         }

         if (bson_iter_find (&iter, "wiredTiger")) {
            if (!BSON_ITER_HOLDS_DOCUMENT (&iter)) {
               bson_set_error (error,
                               MONGOC_ERROR_COMMAND,
                               MONGOC_ERROR_COMMAND_INVALID_ARG,
                               "The \"wiredTiger\" option must take a document "
                               "argument with a \"configString\" field");
               return NULL;
            }

            if (bson_iter_find (&iter, "configString")) {
               if (!BSON_ITER_HOLDS_UTF8 (&iter)) {
                  bson_set_error (
                     error,
                     MONGOC_ERROR_COMMAND,
                     MONGOC_ERROR_COMMAND_INVALID_ARG,
                     "The \"configString\" parameter must be a string");
                  return NULL;
               }
            } else {
               bson_set_error (error,
                               MONGOC_ERROR_COMMAND,
                               MONGOC_ERROR_COMMAND_INVALID_ARG,
                               "The \"wiredTiger\" option must take a document "
                               "argument with a \"configString\" field");
               return NULL;
            }
         }
      }
   }


   bson_init (&cmd);
   BSON_APPEND_UTF8 (&cmd, "create", name);

   if (_mongoc_client_command_with_opts (database->client,
                                         database->name,
                                         &cmd,
                                         MONGOC_CMD_WRITE,
                                         opts,
                                         MONGOC_QUERY_NONE,
                                         NULL, /* user prefs */
                                         database->read_prefs,
                                         database->read_concern,
                                         database->write_concern,
                                         NULL, /* reply */
                                         error)) {
      collection = _mongoc_collection_new (database->client,
                                           database->name,
                                           name,
                                           database->read_prefs,
                                           database->read_concern,
                                           database->write_concern,
                                           database->timeout_ms);
   }

   bson_destroy (&cmd);

   return collection;
}


mongoc_collection_t *
mongoc_database_get_collection (mongoc_database_t *database,
                                const char *collection)
{
   BSON_ASSERT_PARAM (database);
   BSON_ASSERT_PARAM (collection);

   return _mongoc_collection_new (database->client,
                                  database->name,
                                  collection,
                                  database->read_prefs,
                                  database->read_concern,
                                  database->write_concern,
                                  database->timeout_ms);
}


const char *
mongoc_database_get_name (mongoc_database_t *database)
{
   BSON_ASSERT_PARAM (database);

   return database->name;
}


mongoc_change_stream_t *
mongoc_database_watch (const mongoc_database_t *db,
                       const bson_t *pipeline,
                       const bson_t *opts)
{
   return _mongoc_change_stream_new_from_database (db, pipeline, opts);
}

bool
mongoc_database_set_timeout_ms (mongoc_database_t *db,
                                int64_t timeout_ms,
                                bson_error_t *error)
{
   BSON_ASSERT_PARAM (db);

   if (timeout_ms < 0) {
      bson_set_error (error,
                      MONGOC_ERROR_TIMEOUT,
                      MONGOC_ERROR_TIMEOUT_INVALID,
                      "timeoutMS must be a non-negative integer");
      return false;
   }

   db->timeout_ms = timeout_ms;
   return true;
}

int64_t
mongoc_database_get_timeout_ms (const mongoc_database_t *db)
{
   BSON_ASSERT_PARAM (db);

   return db->timeout_ms;
}
