#include <inttypes.h>
#include <czmq.h>
#include <flux/core.h>

#include "src/common/libutil/shortjson.h"
#include "src/common/libutil/nodeset.h"
#include "src/common/libtap/tap.h"

#include "util.h"

static uint32_t fake_size = 1;
static uint32_t fake_rank = 0;

/* request nodeid and flags returned in response */
static int nodeid_fake_error = -1;
void rpctest_nodeid_cb (flux_t *h, flux_msg_handler_t *w,
                        const flux_msg_t *msg, void *arg)
{
    int errnum = 0;
    uint32_t nodeid;
    json_object *o = NULL;
    int flags;

    if (flux_request_decode (msg, NULL, NULL) < 0
            || flux_msg_get_nodeid (msg, &nodeid, &flags) < 0) {
        errnum = errno;
        goto done;
    }
    if (nodeid == nodeid_fake_error) {
        nodeid_fake_error = -1;
        errnum = EPERM; /* an error not likely to be seen */
        goto done;
    }
    o = Jnew ();
    Jadd_int (o, "nodeid", nodeid);
    Jadd_int (o, "flags", flags);
done:
    (void)flux_respond (h, msg, errnum, Jtostr (o));
    Jput (o);
}

void rpcftest_nodeid_cb (flux_t *h, flux_msg_handler_t *w,
                         const flux_msg_t *msg, void *arg)
{
    int errnum = 0;
    uint32_t nodeid = 0;
    int flags = 0;

    if (flux_request_unpack (msg, NULL, "{}") < 0
            || flux_msg_get_nodeid (msg, &nodeid, &flags) < 0) {
        errnum = errno;
        goto done;
    }
    if (nodeid == nodeid_fake_error) {
        nodeid_fake_error = -1;
        errnum = EPERM; /* an error not likely to be seen */
        goto done;
    }

done:
    (void)flux_respond_pack (h, msg, "{ s:i s:i s:i }", "errnum", errnum,
                             "nodeid", nodeid, "flags", flags);
}

/* request payload echoed in response */
void rpctest_echo_cb (flux_t *h, flux_msg_handler_t *w,
                      const flux_msg_t *msg, void *arg)
{
    int errnum = 0;
    const char *json_str;

    if (flux_request_decode (msg, NULL, &json_str) < 0) {
        errnum = errno;
        goto done;
    }
    if (!json_str) {
        errnum = EPROTO;
        goto done;
    }
done:
    (void)flux_respond (h, msg, errnum, json_str);
}

/* no-payload response */
static int hello_count = 0;
void rpctest_hello_cb (flux_t *h, flux_msg_handler_t *w,
                       const flux_msg_t *msg, void *arg)
{
    int errnum = 0;
    const char *json_str;

    if (flux_request_decode (msg, NULL, &json_str) < 0) {
        errnum = errno;
        goto done;
    }
    if (json_str) {
        errnum = EPROTO;
        goto done;
    }
    hello_count++;
done:
    (void)flux_respond (h, msg, errnum, NULL);
}

void rpcftest_hello_cb (flux_t *h, flux_msg_handler_t *w,
                        const flux_msg_t *msg, void *arg)
{
    int errnum = 0;

    if (flux_request_unpack (msg, NULL, "{ ! }") < 0) {
        errnum = errno;
        goto done;
    }
    hello_count++;
done:
    if (errnum)
        (void)flux_respond (h, msg, errnum, NULL);
    else
        (void)flux_respond_pack (h, msg, "{}");
}

static struct flux_msg_handler_spec htab[] = {
    { FLUX_MSGTYPE_REQUEST,   "rpctest.hello",          rpctest_hello_cb, 0, NULL},
    { FLUX_MSGTYPE_REQUEST,   "rpcftest.hello",         rpcftest_hello_cb, 0, NULL},
    { FLUX_MSGTYPE_REQUEST,   "rpctest.echo",           rpctest_echo_cb, 0, NULL},
    { FLUX_MSGTYPE_REQUEST,   "rpctest.nodeid",         rpctest_nodeid_cb, 0, NULL},
    { FLUX_MSGTYPE_REQUEST,   "rpcftest.nodeid",        rpcftest_nodeid_cb, 0, NULL},
    FLUX_MSGHANDLER_TABLE_END,
};
const int htablen = sizeof (htab) / sizeof (htab[0]);

int test_server (flux_t *h, void *arg)
{
    if (flux_msg_handler_addvec (h, htab, NULL) < 0) {
        diag ("flux_msg_handler_addvec failed");
        return -1;
    }
    if (flux_reactor_run (flux_get_reactor (h), 0) < 0) {
        diag ("flux_reactor_run failed");
        return -1;
    }
    flux_msg_handler_delvec (htab);
    return 0;
}

/* then test - add nodeid to 'then_ns' */
static nodeset_t *then_ns = NULL;
static int then_count = 0;
static flux_mrpc_t *then_r;
static void then_cb (flux_mrpc_t *r, void *arg)
{
    flux_t *h = arg;
    uint32_t nodeid;

    if (flux_mrpc_get_nodeid (r, &nodeid) < 0
            || flux_mrpc_get (r, NULL) < 0
            || !nodeset_add_rank (then_ns, nodeid)
            || ++then_count == 128) {
        flux_reactor_stop (flux_get_reactor (h));
    }
}

static void thenf_cb (flux_mrpc_t *r, void *arg)
{
    flux_t *h = arg;
    uint32_t nodeid;

    if (flux_mrpc_get_nodeid (r, &nodeid) < 0
            || flux_mrpc_getf (r, "{}") < 0
            || !nodeset_add_rank (then_ns, nodeid)
            || ++then_count == 128) {
        flux_reactor_stop (flux_get_reactor (h));
    }
}

static bool fatal_tested = false;
static void fatal_err (const char *message, void *arg)
{
    if (fatal_tested)
        BAIL_OUT ("fatal error: %s", message);
    else
        fatal_tested = true;
}

static void rpctest_set_rank (flux_t *h, uint32_t newrank)
{
    fake_rank = newrank;
    char s[16];
    uint32_t rank = 42;
    snprintf (s, sizeof (s), "%"PRIu32, fake_rank);
    flux_attr_fake (h, "rank", s, FLUX_ATTRFLAG_IMMUTABLE);
    flux_get_rank (h, &rank);
    cmp_ok (rank, "==", fake_rank,
        "successfully faked flux_get_rank() of %d", fake_rank);
}

static void rpctest_set_size (flux_t *h, uint32_t newsize)
{
    fake_size = newsize;
    char s[16];
    uint32_t size = 0;
    snprintf (s, sizeof (s), "%"PRIu32, fake_size);
    flux_attr_fake (h, "size", s, FLUX_ATTRFLAG_IMMUTABLE);
    flux_get_size (h, &size);
    cmp_ok (size, "==", fake_size,
        "successfully faked flux_get_size() of %d", fake_size);
}

void test_mrpc (flux_t *h)
{
    uint32_t nodeid;
    int count;
    int old_count;
    int check_count;
    flux_mrpc_t *r;
    const char *json_str;

    rpctest_set_size (h, 1);

    errno = 0;
    ok (!(r = flux_mrpc (h, NULL, "{}", "all", 0)) && errno == EINVAL,
        "flux_mrpc with NULL topic fails with EINVAL");
    errno = 0;
    ok (!(r = flux_mrpc (h, "bar", "{}", NULL, 0)) && errno == EINVAL,
        "flux_mrpc with NULL nodeset fails with EINVAL");
    errno = 0;
    ok (!(r = flux_mrpc (h, "bar", "{}", "xyz", 0)) && errno == EINVAL,
        "flux_mrpc with bad nodeset fails with EINVAL");

    /* working no-payload RPC */
    old_count = hello_count;
    ok ((r = flux_mrpc (h, "rpctest.hello", NULL, "all", 0)) != NULL,
        "flux_mrpc (all) works");
    if (!r)
        BAIL_OUT ("can't continue without successful rpc call");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    ok (flux_mrpc_get (r, NULL) == 0,
        "flux_mrpc_get works");
    ok (flux_mrpc_check (r) == true,
        "flux_mrpc_check still true");
    ok (hello_count == old_count + 1,
        "rpc was called once");
    flux_mrpc_destroy (r);

    /* working no-payload RPC for "any" */
    old_count = hello_count;
    ok ((r = flux_mrpc (h, "rpctest.hello", NULL, "any", 0)) != NULL,
        "flux_mrpc (any) works");
    if (!r)
        BAIL_OUT ("can't continue without successful rpc call");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    ok (flux_mrpc_get (r, NULL) == 0,
        "flux_mrpc_get works");
    ok (hello_count == old_count + 1,
        "rpc was called once");
    flux_mrpc_destroy (r);

    /* working no-payload RPC for "upstream" */
    old_count = hello_count;
    ok ((r = flux_mrpc (h, "rpctest.hello", NULL, "upstream", 0)) != NULL,
        "flux_mrpc (upstream) works");
    if (!r)
        BAIL_OUT ("can't continue without successful rpc call");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    ok (flux_mrpc_get (r, NULL) == 0,
        "flux_mrpc_get works");
    ok (hello_count == old_count + 1,
        "rpc was called once");
    flux_mrpc_destroy (r);

    /* cause remote EPROTO (unexpected payload) - picked up in _get() */
    ok ((r = flux_mrpc (h, "rpctest.hello", "{}", "all", 0)) != NULL,
        "flux_mrpc (all) with unexpected payload works, at first");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    errno = 0;
    ok (flux_mrpc_get (r, NULL) < 0
        && errno == EPROTO,
        "flux_mrpc_get fails with EPROTO");
    ok (flux_mrpc_check (r) == true,
        "flux_mrpc_check is still true");
    flux_mrpc_destroy (r);

    /* fake that we have a larger session */
    rpctest_set_size (h, 128);

    /* repeat working no-payload RPC test (now with 128 nodes) */
    old_count = hello_count;
    ok ((r = flux_mrpc (h, "rpctest.hello", NULL, "all", 0)) != NULL,
        "flux_mrpc [0-%d] with no payload when none is expected works",
        fake_size - 1);
    count = 0;
    do {
        if (flux_mrpc_get (r, NULL) < 0)
            break;
        count++;
    } while (flux_mrpc_next (r) == 0);
    ok (count == fake_size,
        "flux_mrpc_get succeded %d times", fake_size);

    cmp_ok (hello_count - old_count, "==", fake_size,
        "rpc was called %d times", fake_size);
    flux_mrpc_destroy (r);

    /* same with a subset */
    old_count = hello_count;
    ok ((r = flux_mrpc (h, "rpctest.hello", NULL, "[0-63]", 0)) != NULL,
        "flux_mrpc [0-%d] with no payload when none is expected works",
        64 - 1);
    count = 0;
    do {
        if (flux_mrpc_get_nodeid (r, &nodeid) < 0
                || flux_mrpc_get (r, NULL) < 0 || nodeid != count)
            break;
        count++;
    } while (flux_mrpc_next (r) == 0);
    ok (count == 64,
        "flux_mrpc_get succeded %d times, with correct nodeid map", 64);

    cmp_ok (hello_count - old_count, "==", 64,
        "rpc was called %d times", 64);
    flux_mrpc_destroy (r);

    /* same with echo payload */
    ok ((r = flux_mrpc (h, "rpctest.echo", "{}", "[0-63]", 0)) != NULL,
        "flux_mrpc [0-%d] ok",
        64 - 1);
    count = 0;
    do {
        if (flux_mrpc_get (r, &json_str) < 0
                || !json_str || strcmp (json_str, "{}") != 0)
            break;
        count++;
    } while (flux_mrpc_next (r) == 0);
    ok (count == 64,
        "flux_mrpc_get succeded %d times, with correct return payload", 64);
    flux_mrpc_destroy (r);

    /* detect partial failure without response */
    nodeid_fake_error = 20;
    ok ((r = flux_mrpc (h, "rpctest.nodeid", NULL, "[0-63]", 0)) != NULL,
        "flux_mrpc [0-%d] ok",
        64 - 1);
    int fail_count = 0;
    uint32_t fail_nodeid_last = FLUX_NODEID_ANY;
    int fail_errno_last = 0;
    do {
        if (flux_mrpc_get_nodeid (r, &nodeid) < 0
                || flux_mrpc_get (r, NULL) < 0) {
            fail_errno_last = errno;
            fail_nodeid_last = nodeid;
            fail_count++;
        }
    } while (flux_mrpc_next (r) == 0);
    ok (fail_count == 1 && fail_nodeid_last == 20 && fail_errno_last == EPERM,
        "flux_mrpc_get correctly reports single error");
    flux_mrpc_destroy (r);

    /* test that a fatal handle error causes flux_mrpc_next () to fail */
    flux_fatal_set (h, NULL, NULL); /* reset handler and flag */
    ok (flux_fatality (h) == false,
        "flux_fatality says all is well");
    ok ((r = flux_mrpc (h, "rpctest.nodeid", NULL, "[0-1]", 0)) != NULL,
        "flux_mrpc [0-1] ok");
    flux_fatal_error (h, __FUNCTION__, "Foo");
    ok (flux_fatality (h) == true,
        "flux_fatality shows simulated failure");
    ok (flux_mrpc_next (r) == -1,
        "flux_mrpc_next fails");
    flux_fatal_set (h, fatal_err, NULL); /* reset handler and flag  */
    flux_mrpc_destroy (r);

    diag ("completed synchronous mrpc test");
}

void test_mrpc_then (flux_t *h)
{
    rpctest_set_size (h, 128);

    ok ((then_ns = nodeset_create ()) != NULL,
        "nodeset created ok");
    then_count = 0;
    ok ((then_r = flux_mrpc (h, "rpctest.hello", NULL, "[0-127]", 0)) != NULL,
        "flux_mrpc [0-127] ok");
    ok (flux_mrpc_then (then_r, then_cb, h) == 0,
        "flux_mrpc_then works");
    ok (flux_reactor_run (flux_get_reactor (h), 0) == 0,
        "flux_reactor_run worked");
    ok (nodeset_count (then_ns) == 128,
        "then callback worked with correct nodemap");
    nodeset_destroy (then_ns);
    flux_mrpc_destroy (then_r);

    diag ("completed asynchronous mrpc test");
}

void test_mrpcf (flux_t *h)
{
    uint32_t nodeid;
    int count;
    int old_count;
    flux_mrpc_t *r;
    const char *json_str;
    int check_count;

    rpctest_set_size (h, 1);

    errno = 0;
    ok (!(r = flux_mrpcf (h, NULL, "all", 0, "{}")) && errno == EINVAL,
        "flux_mrpcf with NULL topic fails with EINVAL");
    errno = 0;
    ok (!(r = flux_mrpcf (h, "bar", NULL, 0, "{}")) && errno == EINVAL,
        "flux_mrpcf with NULL nodeset fails with EINVAL");
    errno = 0;
    ok (!(r = flux_mrpcf (h, "bar", "xyz", 0, "{}")) && errno == EINVAL,
        "flux_mrpcf with bad nodeset fails with EINVAL");
    errno = 0;
    ok (!(r = flux_mrpcf (h, "bar", "all", 0, NULL)) && errno == EINVAL,
        "flux_mrpcf with NULL fmt fails with EINVAL");
    errno = 0;
    ok (!(r = flux_mrpcf (h, "bar", "all", 0, "")) && errno == EINVAL,
        "flux_mrpcf with empty string fmt fails with EINVAL");
    errno = 0;
    ok (!(r = flux_mrpcf (h, "bar", "all", 0, "{ s }", "foo")) && errno == EINVAL,
        "flux_mrpcf with bad string fmt fails with EINVAL");

    /* working empty payload RPC */
    old_count = hello_count;
    ok ((r = flux_mrpcf (h, "rpcftest.hello", "all", 0, "{}")) != NULL,
        "flux_mrpcf all works");
    if (!r)
        BAIL_OUT ("can't continue without successful rpc call");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    ok (flux_mrpc_getf (r, "{}") == 0,
        "flux_mrpc_getf works");
    ok (hello_count == old_count + 1,
        "rpc was called once");
    flux_mrpc_destroy (r);

    /* working empty payload RPC for "any" */
    old_count = hello_count;
    ok ((r = flux_mrpcf (h, "rpcftest.hello", "any", 0, "{}")) != NULL,
        "flux_mrpcf any works");
    if (!r)
        BAIL_OUT ("can't continue without successful rpc call");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    ok (flux_mrpc_getf (r, "{}") == 0,
        "flux_mrpc_getf works");
    ok (hello_count == old_count + 1,
        "rpc was called once");
    flux_mrpc_destroy (r);

    /* working empty payload RPC for "upstream" */
    old_count = hello_count;
    ok ((r = flux_mrpcf (h, "rpcftest.hello", "upstream", 0, "{}")) != NULL,
        "flux_mrpcf upstream works");
    if (!r)
        BAIL_OUT ("can't continue without successful rpc call");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    ok (flux_mrpc_getf (r, "{}") == 0,
        "flux_mrpc_getf works");
    ok (hello_count == old_count + 1,
        "rpc was called once");
    flux_mrpc_destroy (r);

    /* cause remote EPROTO (unexpected payload) - picked up in _getf() */
    ok ((r = flux_mrpcf (h, "rpcftest.hello", "all", 0,
                              "{ s:i }", "foo", 42)) != NULL,
        "flux_mrpcf all works");
    check_count = 0;
    while (flux_mrpc_check (r) == false)
        check_count++;
    diag ("flux_mrpc_check returned true after %d tries", check_count);
    errno = 0;
    ok (flux_mrpc_getf (r, "{}") < 0
        && errno == EPROTO,
        "flux_mrpc_getf fails with EPROTO (unexpected payload)");
    flux_mrpc_destroy (r);

    /* fake that we have a larger session */
    rpctest_set_size (h, 128);

    /* repeat working empty-payload RPC test (now with 128 nodes) */
    old_count = hello_count;
    ok ((r = flux_mrpcf (h, "rpcftest.hello", "all", 0, "{}")) != NULL,
        "flux_mrpcf [0-%d] works",
        fake_size - 1);
    count = 0;
    do {
        if (flux_mrpc_getf (r, "{}") < 0)
            break;
        count++;
    } while (flux_mrpc_next (r) == 0);
    ok (count == fake_size,
        "flux_mrpc_getf succeded %d times", fake_size);

    cmp_ok (hello_count - old_count, "==", fake_size,
        "rpc was called %d times", fake_size);
    flux_mrpc_destroy (r);

    /* same with a subset */
    old_count = hello_count;
    ok ((r = flux_mrpcf (h, "rpcftest.hello", "[0-63]", 0, "{}")) != NULL,
        "flux_mrpcf [0-%d] works", 64 - 1);
    count = 0;
    do {
        if (flux_mrpc_get_nodeid (r, &nodeid) < 0
                || flux_mrpc_getf (r, "{}") < 0 || nodeid != count)
            break;
        count++;
    } while (flux_mrpc_next (r) == 0);
    ok (count == 64,
        "flux_mrpc_getf succeded %d times, with correct nodeid map", 64);

    cmp_ok (hello_count - old_count, "==", 64,
        "rpc was called %d times", 64);
    flux_mrpc_destroy (r);

    /* same with echo payload */
    ok ((r = flux_mrpcf (h, "rpctest.echo", "[0-63]", 0, "{}")) != NULL,
        "flux_mrpcf [0-%d] ok", 64 - 1);
    count = 0;
    do {
        if (flux_mrpc_get (r, &json_str) < 0
                || !json_str || strcmp (json_str, "{}") != 0)
            break;
        count++;
    } while (flux_mrpc_next (r) == 0);
    ok (count == 64,
        "flux_mrpc_get succeded %d times, with correct return payload", 64);
    flux_mrpc_destroy (r);

    /* detect partial failure without response */
    nodeid_fake_error = 20;
    ok ((r = flux_mrpcf (h, "rpcftest.nodeid", "[0-63]", 0, "{}")) != NULL,
        "flux_mrpcf [0-%d] ok", 64 - 1);
    int fail_count = 0;
    uint32_t fail_nodeid_last = FLUX_NODEID_ANY;
    int fail_errno_last = 0;
    int errnum;
    int flags;
    do {
        if (flux_mrpc_get_nodeid (r, &nodeid) < 0
            || flux_mrpc_getf (r, "{ s:i s:i s:i !}",
                              "errnum", &errnum,
                              "nodeid", &nodeid,
                              "flags", &flags) < 0
            || errnum) {
            fail_errno_last = errnum;
            fail_nodeid_last = nodeid;
            fail_count++;
        }
    } while (flux_mrpc_next (r) == 0);
    ok (fail_count == 1 && fail_nodeid_last == 20 && fail_errno_last == EPERM,
        "flux_mrpc_getf correctly reports single error");
    flux_mrpc_destroy (r);

    /* test that a fatal handle error causes flux_mrpc_next () to fail */
    flux_fatal_set (h, NULL, NULL); /* reset handler and flag */
    ok (flux_fatality (h) == false,
        "flux_fatality says all is well");
    ok ((r = flux_mrpcf (h, "rpctest.nodeid", "[0-1]", 0, "{}")) != NULL,
        "flux_mrpcf [0-1] ok");
    flux_fatal_error (h, __FUNCTION__, "Foo");
    ok (flux_fatality (h) == true,
        "flux_fatality shows simulated failure");
    ok (flux_mrpc_next (r) == -1,
        "flux_mrpc_next fails");
    flux_fatal_set (h, fatal_err, NULL); /* reset handler and flag  */
    flux_mrpc_destroy (r);

    diag ("completed synchronous mrpcf test");
}

void test_mrpcf_then (flux_t *h)
{
    rpctest_set_size (h, 128);

    ok ((then_ns = nodeset_create ()) != NULL,
        "nodeset created ok");
    then_count = 0;
    ok ((then_r = flux_mrpcf (h, "rpcftest.hello", "[0-127]", 0, "{}")) != NULL,
        "flux_mrpcf [0-127] ok");
    ok (flux_mrpc_then (then_r, thenf_cb, h) == 0,
        "flux_mrpc_then works");
    ok (flux_reactor_run (flux_get_reactor (h), 0) == 0,
        "flux_reactor_run worked");
    ok (nodeset_count (then_ns) == 128,
        "then callback worked with correct nodemap");
    nodeset_destroy (then_ns);
    flux_mrpc_destroy (then_r);

    diag ("completed asynchronous mrpcf test");
}

int main (int argc, char *argv[])
{
    flux_t *h;

    plan (NO_PLAN);

    zsys_init ();
    zsys_set_logstream (stderr);
    zsys_set_logident ("mrpc-test");
    zsys_handler_set (NULL);
    zsys_set_linger (5); // msec

    h = test_server_create (test_server, NULL);
    ok (h != NULL,
        "created test server thread");
    if (!h)
        BAIL_OUT ("can't continue without test server");
    flux_fatal_set (h, fatal_err, NULL);

    flux_fatal_set (h, fatal_err, NULL);
    flux_fatal_error (h, __FUNCTION__, "Foo");
    ok (fatal_tested == true,
        "flux_fatal function is called on fatal error");
    flux_fatal_set (h, fatal_err, NULL); /* reset */

    rpctest_set_rank (h, 0);

    test_mrpc (h);
    test_mrpc_then (h);
    test_mrpcf (h);
    test_mrpcf_then (h);

    ok (test_server_stop (h) == 0,
        "stopped test server thread");
    flux_close (h); // destroys test server

    done_testing();
    return (0);
}

/*
 * vi:tabstop=4 shiftwidth=4 expandtab
 */

