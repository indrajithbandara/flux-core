#ifndef _FLUX_CORE_MRPC_H
#define _FLUX_CORE_MRPC_H

#include <stdbool.h>
#include <stdarg.h>

#include "handle.h"
#include "rpc.h"

typedef struct flux_mrpc_struct flux_mrpc_t;
typedef void (*flux_mrpc_continuation_f)(flux_mrpc_t *mrpc, void *arg);

/* Send an RPC request to 'nodeset' and return a flux_mrpc_t object to
 * allow responses to be handled.  "all" is a valid shorthand for all
 * ranks in the comms session.  "any" is a valid shorthand for a
 * single mrpc sent to FLUX_NODEID_ANY.  "upstream" is a valid
 * shorthand for a single rpc sent to FLUX_NODEID_UPSTREAM.  On
 * failure return NULL with errno set.
 */
flux_mrpc_t *flux_mrpc (flux_t *h, const char *topic, const char *json_str,
                        const char *nodeset, int flags);

/* Variant of flux_mrpc that encodes a json payload using jansson
 * pack format strings.
 */
flux_mrpc_t *flux_mrpcf (flux_t *h, const char *topic, const char *nodeset,
                         int flags, const char *fmt, ...);

/* Destroy an mrpc, invalidating previous payload returned by flux_mrpc_get().
 */
void flux_mrpc_destroy (flux_mrpc_t *mrpc);

/* Returns true if flux_mrpc_get() can be called without blocking.
 */
bool flux_mrpc_check (flux_mrpc_t *mrpc);

/* Wait for a response if necessary, then decode it.
 * Any returned 'json_str' payload is invalidated by
 * flux_mrpc_destroy() or flux_mrpc_next().
 * Returns 0 on success, or -1 on failure with errno set.
 */
int flux_mrpc_get (flux_mrpc_t *mrpc, const char **json_str);

/* Variant of flux_mrpc_get that decodes json payload using
 * jansson pack/unpack format strings.  Returned items are
 * invalidated by flux_mrpc_destroy() or flux_mrpc_next().
 */
int flux_mrpc_getf (flux_mrpc_t *mrpc, const char *fmt, ...);

/* Wait for response if necessary, then decode nodeid request was sent to.
 * This function succedes even if the RPC service is returning an error.
 * It fails if something goes wrong reading or decoding the response message.
 * Returns 0 on success, or -1 on failure with errno set.
 */
int flux_mrpc_get_nodeid (flux_mrpc_t *mrpc, uint32_t *nodeid);

/* Wait for a response if necessary, then decode it.
 * Any returned 'data' payload is valid until flux_mrpc_destroy()
 * or flux_mrpc_next().
 * Returns 0 on success, or -1 on failure with errno set.
 */
int flux_mrpc_get_raw (flux_mrpc_t *mrpc, const void **data, int *len);

/* Arrange for reactor to handle response and call 'cb' continuation function
 * when a response is received.  The function should call flux_mrpc_get().
 * Returns 0 on success, or -1 on failure with errno set.
 */
int flux_mrpc_then (flux_mrpc_t *mrpc, flux_mrpc_continuation_f cb, void *arg);

/* Prepares for receipt of next response from flux_mrpc().
 * This invalidates previous payload returned by flux_mrpc_get().
 * Returns 0 on success, -1 if all responses have been received, e.g.
 *   do {
 *     flux_mrpc_get (rpc, ...);
 *   } while (flux_mrpc_next (mrpc) == 0);
 */
int flux_mrpc_next (flux_mrpc_t *mrpc);

/* Helper functions for extending flux_mrpc_t.
 */
void *flux_mrpc_aux_get (flux_mrpc_t *mrpc, const char *name);
int flux_mrpc_aux_set (flux_mrpc_t *mrpc, const char *name,
                      void *aux, flux_free_f destroy);

#endif /* !_FLUX_CORE_MRPC_H */

/*
 * vi:tabstop=4 shiftwidth=4 expandtab
 */
