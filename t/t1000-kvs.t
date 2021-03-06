#!/bin/sh
#

test_description='Test flux-kvs usage in flux session

This differs from basic KVS tests as it tests the flux-kvs command
line interface to KVS and not necessarily the KVS functionality.  Some
tests may be identical.
'

. `dirname $0`/sharness.sh

if test "$TEST_LONG" = "t"; then
    test_set_prereq LONGTEST
fi

# Size the session to one more than the number of cores, minimum of 4
SIZE=$(test_size_large)
test_under_flux ${SIZE} kvs
echo "# $0: flux session size will be ${SIZE}"

DIR=test.a.b
KEY=test.a.b.c
SUBDIR1=test.a.b.d
SUBDIR2=test.a.b.e

test_kvs_key() {
	flux kvs get "$1" >output
	echo "$2" >expected
	test_cmp output expected
}

#
# Basic put, get, mkdir, dir, unlink tests
#

test_expect_success 'kvs: integer put' '
	flux kvs put $KEY.integer=42
'
test_expect_success 'kvs: double put' '
	flux kvs put $KEY.double=3.14
'
test_expect_success 'kvs: string put' '
	flux kvs put $KEY.string=foo
'
test_expect_success 'kvs: empty string put' '
	flux kvs put $KEY.emptystring=
'
test_expect_success 'kvs: null is converted to json null' '
	flux kvs put $KEY.jsonnull=null
'
test_expect_success 'kvs: quoted null is converted to string' '
	flux kvs put $KEY.strnull=\"null\"
'
test_expect_success 'kvs: boolean true put' '
	flux kvs put $KEY.booleantrue=true
'
test_expect_success 'kvs: boolean false put' '
	flux kvs put $KEY.booleanfalse=false
'
test_expect_success 'kvs: array put' '
	flux kvs put $KEY.array="[1,3,5]"
'
test_expect_success 'kvs: object put' '
	flux kvs put $KEY.object="{\"a\":42}"
'
test_expect_success 'kvs: mkdir' '
	flux kvs mkdir $SUBDIR1
'
test_expect_success 'kvs: integer get' '
	test_kvs_key $KEY.integer 42
'
test_expect_success 'kvs: double get' '
	test_kvs_key $KEY.double 3.140000
'
test_expect_success 'kvs: string get' '
	test_kvs_key $KEY.string foo
'
test_expect_success 'kvs: empty string get' '
	test_kvs_key $KEY.emptystring ""
'
test_expect_success 'kvs: null is converted to json null' '
        test_kvs_key $KEY.jsonnull nil
'
test_expect_success 'kvs: quoted null is converted to string' '
        test_kvs_key $KEY.strnull null
# '
test_expect_success 'kvs: boolean true get' '
	test_kvs_key $KEY.booleantrue true
'
test_expect_success 'kvs: boolean false get' '
	test_kvs_key $KEY.booleanfalse false
'
test_expect_success 'kvs: array get' '
	test_kvs_key $KEY.array "[1, 3, 5]"
'
test_expect_success 'kvs: object get' '
	test_kvs_key $KEY.object "{\"a\": 42}"
'
test_expect_success 'kvs: dir' '
	flux kvs dir $DIR | sort >output &&
	cat >expected <<EOF &&
$DIR.c.
$DIR.d.
EOF
	test_cmp expected output
'
test_expect_success 'kvs: dir -R' '
	flux kvs dir -R $DIR | sort >output &&
	cat >expected <<EOF &&
$KEY.array = [1, 3, 5]
$KEY.booleanfalse = false
$KEY.booleantrue = true
$KEY.double = 3.140000
$KEY.emptystring = 
$KEY.integer = 42
$KEY.jsonnull = nil
$KEY.object = {"a": 42}
$KEY.string = foo
$KEY.strnull = null
EOF
	test_cmp expected output
'
test_expect_success 'kvs: dir -R -d' '
	flux kvs dir -R -d $DIR | sort >output &&
	cat >expected <<EOF &&
$KEY.array
$KEY.booleanfalse
$KEY.booleantrue
$KEY.double
$KEY.emptystring
$KEY.integer
$KEY.jsonnull
$KEY.object
$KEY.string
$KEY.strnull
EOF
	test_cmp expected output
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.integer &&
	  test_must_fail flux kvs get $KEY.integer
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.double &&
	  test_must_fail flux kvs get $KEY.double
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.string &&
	  test_must_fail flux kvs get $KEY.string
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.emptystring &&
	  test_must_fail flux kvs get $KEY.emptystring
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.jsonnull &&
	  test_must_fail flux kvs get $KEY.jsonnull
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.strnull &&
	  test_must_fail flux kvs get $KEY.strnull
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.booleantrue &&
	  test_must_fail flux kvs get $KEY.booleantrue
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.booleanfalse &&
	  test_must_fail flux kvs get $KEY.booleanfalse
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.array &&
	  test_must_fail flux kvs get $KEY.array
'
test_expect_success 'kvs: unlink works' '
	flux kvs unlink $KEY.object &&
	  test_must_fail flux kvs get $KEY.object
'
test_expect_success 'kvs: unlink dir works' '
        flux kvs unlink $SUBDIR1 &&
          test_must_fail flux kvs dir $SUBDIR1
'
test_expect_success 'kvs: unlink -R works' '
        flux kvs unlink -R $DIR &&
          test_must_fail flux kvs dir $DIR
'

#
# Basic put, get, mkdir, dir, unlink tests w/ multiple key inputs
#

test_expect_success 'kvs: put (multiple)' '
	flux kvs put $KEY.a=42 $KEY.b=3.14 $KEY.c=foo $KEY.d=true $KEY.e="[1,3,5]" $KEY.f="{\"a\":42}"
'
test_expect_success 'kvs: get (multiple)' '
	flux kvs get $KEY.a $KEY.b $KEY.c $KEY.d $KEY.e $KEY.f >output &&
	cat >expected <<EOF &&
42
3.140000
foo
true
[1, 3, 5]
{"a": 42}
EOF
	test_cmp expected output
'
test_expect_success 'kvs: mkdir (multiple)' '
	flux kvs mkdir $SUBDIR1 $SUBDIR2
'
test_expect_success 'kvs: dir' '
	flux kvs dir $DIR | sort >output &&
	cat >expected <<EOF &&
$DIR.c.
$DIR.d.
$DIR.e.
EOF
	test_cmp expected output
'
test_expect_success 'kvs: dir -R' '
	flux kvs dir -R $DIR | sort >output &&
	cat >expected <<EOF &&
$KEY.a = 42
$KEY.b = 3.140000
$KEY.c = foo
$KEY.d = true
$KEY.e = [1, 3, 5]
$KEY.f = {"a": 42}
EOF
	test_cmp expected output
'
test_expect_success 'kvs: unlink (multiple)' '
	flux kvs unlink $KEY.a $KEY.b $KEY.c $KEY.d $KEY.e $KEY.f &&
          test_must_fail flux kvs get $KEY.a &&
          test_must_fail flux kvs get $KEY.b &&
          test_must_fail flux kvs get $KEY.c &&
          test_must_fail flux kvs get $KEY.d &&
          test_must_fail flux kvs get $KEY.e &&
          test_must_fail flux kvs get $KEY.f
'
test_expect_success 'kvs: unlink -R works' '
        flux kvs unlink -R $DIR &&
          test_must_fail flux kvs dir $DIR
'
test_expect_success 'kvs: create a dir with keys and subdir' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a=69 &&
        flux kvs put $DIR.b=70 &&
        flux kvs put $DIR.c.d.e.f.g=3.14 &&
        flux kvs put $DIR.d=\"snerg\" &&
        flux kvs put $DIR.e=true &&
	flux kvs dir -R $DIR | sort >output &&
	cat >expected <<EOF &&
$DIR.a = 69
$DIR.b = 70
$DIR.c.d.e.f.g = 3.140000
$DIR.d = snerg
$DIR.e = true
EOF
	test_cmp expected output
'

test_expect_success 'kvs: directory with multiple subdirs' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a=69 &&
        flux kvs put $DIR.b.c.d.e.f.g=70 &&
        flux kvs put $DIR.c.a.b=3.14 &&
        flux kvs put $DIR.d=\"snerg\" &&
        flux kvs put $DIR.e=true &&
	flux kvs dir -R $DIR | sort >output &&
	cat >expected <<EOF &&
$DIR.a = 69
$DIR.b.c.d.e.f.g = 70
$DIR.c.a.b = 3.140000
$DIR.d = snerg
$DIR.e = true
EOF
	test_cmp expected output
'

#
# ls tests
#
test_expect_success 'kvs: ls -1F DIR works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a=69 &&
	flux kvs mkdir $DIR.b &&
	flux kvs link b $DIR.c &&
	flux kvs ls -1F $DIR >output &&
	cat >expected <<-EOF &&
	a
	b.
	c@
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls -1Fd DIR.a DIR.b DIR.c works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a=69 &&
	flux kvs mkdir $DIR.b &&
	flux kvs link b $DIR.c &&
	flux kvs ls -1Fd $DIR.a $DIR.b $DIR.c >output &&
	cat >expected <<-EOF &&
	$DIR.a
	$DIR.b.
	$DIR.c@
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls -1RF shows directory titles' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a=69 &&
	flux kvs put $DIR.b.d=42 &&
	flux kvs link b $DIR.c &&
	flux kvs ls -1RF $DIR | grep : | wc -l >output &&
	cat >expected <<-EOF &&
	2
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls with no options adjusts output width to 80' '
	flux kvs unlink -Rf $DIR &&
	${FLUX_BUILD_DIR}/t/kvs/dtree -p$DIR -h1 -w50 &&
	flux kvs ls $DIR | wc -wl >output &&
	cat >expected <<-EOF &&
	      5      50
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls -w40 adjusts output width to 40' '
	flux kvs unlink -Rf $DIR &&
	${FLUX_BUILD_DIR}/t/kvs/dtree -p$DIR -h1 -w50 &&
	flux kvs ls -w40 $DIR | wc -wl >output &&
	cat >expected <<-EOF &&
	     10      50
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls with COLUMNS=20 adjusts output width to 20' '
	flux kvs unlink -Rf $DIR &&
	${FLUX_BUILD_DIR}/t/kvs/dtree -p$DIR -h1 -w50 &&
	COLUMNS=20 flux kvs ls $DIR | wc -wl >output &&
	cat >expected <<-EOF &&
	     25      50
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls -R lists deep directory hierarchy' '
	flux kvs unlink -Rf $DIR &&
	${FLUX_BUILD_DIR}/t/kvs/dtree -p$DIR -h8 -w1 &&
	flux kvs ls -R $DIR >output &&
	cat >expected <<-EOF &&
	$DIR:
	0000

	$DIR.0000:
	0000

	$DIR.0000.0000:
	0000

	$DIR.0000.0000.0000:
	0000

	$DIR.0000.0000.0000.0000:
	0000

	$DIR.0000.0000.0000.0000.0000:
	0000

	$DIR.0000.0000.0000.0000.0000.0000:
	0000

	$DIR.0000.0000.0000.0000.0000.0000.0000:
	0000
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls key. works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs mkdir $DIR.a &&
	flux kvs ls -d $DIR.a. >output &&
	cat >expected <<-EOF &&
	$DIR.a
	EOF
	test_cmp expected output
'
test_expect_success 'kvs: ls key. fails if key is not a directory' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a=42 &&
	test_must_fail flux kvs ls -d $DIR.a.
'
test_expect_success 'kvs: ls key. fails if key does not exist' '
	flux kvs unlink -Rf $DIR &&
	test_must_fail flux kvs ls $DIR.a
'

#
# get corner case tests
#

test_expect_success 'kvs: get a nonexistent key' '
	test_must_fail flux kvs get NOT.A.KEY
'
test_expect_success 'kvs: try to retrieve a directory as key should fail' '
        flux kvs mkdir $DIR.a.b.c &&
	test_must_fail flux kvs get $DIR
'

#
# put corner case tests
#

test_expect_success 'kvs: put with invalid input' '
	test_must_fail flux kvs put NOVALUE
'
test_expect_success 'kvs: put key of . fails' '
	test_must_fail flux kvs put .=1
'

#
# dir corner case tests
#

test_empty_directory() {
	OUTPUT=`flux kvs dir -R $1 | wc -l` &&
	test "x$OUTPUT" = "x0"
}

test_expect_success 'kvs: try to retrieve key as directory should fail' '
        flux kvs put $DIR.a.b.c.d=42 &&
	test_must_fail flux kvs dir $DIR.a.b.c.d
'
test_expect_success 'kvs: empty directory can be created' '
	flux kvs unlink -Rf $DIR &&
	flux kvs mkdir $DIR &&
	test_empty_directory $DIR
'

#
# unlink corner case tests
#

test_expect_success 'kvs: unlink nonexistent key fails' '
        test_must_fail flux kvs unlink NOT.A.KEY
'
test_expect_success 'kvs: unlink nonexistent key with -f does not fail' '
        flux kvs unlink -f NOT.A.KEY
'
test_expect_success 'kvs: unlink nonexistent dir with -f does not fail' '
        flux kvs unlink -Rf NOT.A.KEY
'
test_expect_success 'kvs: unlink non-empty dir fails' '
        flux kvs mkdir $SUBDIR1 $SUBDIR2 &&
	test_must_fail flux kvs unlink $DIR
'
test_expect_success 'kvs: unlink -R works' '
        flux kvs unlink -R $DIR &&
          test_must_fail flux kvs dir $SUBDIR1 &&
          test_must_fail flux kvs dir $SUBDIR2 &&
          test_must_fail flux kvs dir $DIR
'
test_expect_success 'kvs: empty directory remains after key removed' '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a=1 &&
        test_kvs_key $DIR.a 1 &&
        flux kvs unlink $DIR.a &&
	test_empty_directory $DIR
'

#
# test key normalization
#
test_expect_success 'kvs: put with leading path separators works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put ......$DIR.a.b.c=42 &&
	test_kvs_key $DIR.a.b.c 42
'
test_expect_success 'kvs: put with trailing path separators works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.c........=43 &&
	test_kvs_key $DIR.a.b.c 43
'
test_expect_success 'kvs: put with extra embedded path separators works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.....a....b...c=44 &&
	test_kvs_key $DIR.a.b.c 44
'
test_expect_success 'kvs: get with leading path separators works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.c=42 &&
	test_kvs_key ......$DIR.a.b.c 42
'
test_expect_success 'kvs: get with trailing path separators works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.c=43 &&
	test_kvs_key $DIR.a.b.c........ 43
'
test_expect_success 'kvs: get with extra embedded path separators works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.c=44 &&
	test_kvs_key $DIR.....a....b...c 44
'

#
# link/readlink tests
#

test_expect_success 'kvs: link works' '
	TARGET=$DIR.target &&
	flux kvs put $TARGET=\"foo\" &&
	flux kvs link $TARGET $DIR.link &&
	OUTPUT=$(flux kvs get $DIR.link) &&
	test "$OUTPUT" = "foo"
'
test_expect_success 'kvs: readlink works' '
	TARGET=$DIR.target &&
	flux kvs put $TARGET=\"foo\" &&
	flux kvs link $TARGET $DIR.link &&
	OUTPUT=$(flux kvs readlink $DIR.link) &&
	test "$OUTPUT" = "$TARGET"
'
test_expect_success 'kvs: readlink works (multiple inputs)' '
	TARGET1=$DIR.target1 &&
	TARGET2=$DIR.target2 &&
	flux kvs put $TARGET1=\"foo1\" &&
	flux kvs put $TARGET2=\"foo2\" &&
	flux kvs link $TARGET1 $DIR.link1 &&
	flux kvs link $TARGET2 $DIR.link2 &&
	flux kvs readlink $DIR.link1 $DIR.link2 >output &&
	cat >expected <<EOF &&
$TARGET1
$TARGET2
EOF
	test_cmp output expected
'
test_expect_success 'kvs: readlink fails on regular value' '
        flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.target=42 &&
	! flux kvs readlink $DIR.target
'
test_expect_success 'kvs: readlink fails on directory' '
        flux kvs unlink -Rf $DIR &&
	flux kvs mkdir $DIR.a.b.c &&
	! flux kvs readlink $DIR.a.b.
'
test_expect_success 'kvs: link: path resolution when intermediate component is a link' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.c=42 &&
	flux kvs link $DIR.a.b $DIR.Z.Y &&
	OUTPUT=$(flux kvs get $DIR.Z.Y.c) &&
	test "$OUTPUT" = "42"
'
test_expect_success 'kvs: link: path resolution with intermediate link and nonexistent key' '
	flux kvs unlink -Rf $DIR &&
	flux kvs link $DIR.a.b $DIR.Z.Y &&
	test_must_fail flux kvs get $DIR.Z.Y
'
test_expect_success 'kvs: link: intermediate link points to another link' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.c=42 &&
	flux kvs link $DIR.a.b $DIR.Z.Y &&
	flux kvs link $DIR.Z.Y $DIR.X.W &&
	test_kvs_key $DIR.X.W.c 42
'
test_expect_success 'kvs: link: intermediate links are followed by put' '
	flux kvs unlink -Rf $DIR &&
	flux kvs mkdir $DIR.a &&
	flux kvs link $DIR.a $DIR.link &&
	flux kvs readlink $DIR.link >/dev/null &&
	flux kvs put $DIR.link.X=42 &&
	flux kvs readlink $DIR.link >/dev/null &&
	test_kvs_key $DIR.link.X 42 &&
	test_kvs_key $DIR.a.X 42
'

# This will fail if individual ops are applied out of order
test_expect_success 'kvs: link: kvs_copy removes linked destination' '
	flux kvs unlink -Rf $DIR &&
	flux kvs mkdir $DIR.a &&
	flux kvs link $DIR.a $DIR.link &&
	flux kvs put $DIR.a.X=42 &&
	flux kvs copy $DIR.a $DIR.link &&
	! flux kvs readlink $DIR.link >/dev/null &&
	test_kvs_key $DIR.link.X 42
'

# This will fail if individual ops are applied out of order
test_expect_success 'kvs: link: kvs_move works' '
	flux kvs unlink -Rf $DIR &&
	flux kvs mkdir $DIR.a &&
	flux kvs link $DIR.a $DIR.link &&
	flux kvs put $DIR.a.X=42 &&
	flux kvs move $DIR.a $DIR.link &&
	! flux kvs readlink $DIR.link >/dev/null &&
	test_kvs_key $DIR.link.X 42 &&
	! flux kvs dir $DIR.a >/dev/null
'

test_expect_success 'kvs: link: kvs_copy does not follow links (top)' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.X=42 &&
	flux kvs link $DIR.a $DIR.link &&
	flux kvs copy $DIR.link $DIR.copy &&
	LINKVAL=$(flux kvs readlink $DIR.copy) &&
	test "$LINKVAL" = "$DIR.a"
'

test_expect_success 'kvs: link: kvs_copy does not follow links (mid)' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.X=42 &&
	flux kvs link $DIR.a.b $DIR.a.link &&
	flux kvs copy $DIR.a $DIR.copy &&
	LINKVAL=$(flux kvs readlink $DIR.copy.link) &&
	test "$LINKVAL" = "$DIR.a.b"
'

test_expect_success 'kvs: link: kvs_copy does not follow links (bottom)' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.X=42 &&
	flux kvs link $DIR.a.b.X $DIR.a.b.link &&
	flux kvs copy $DIR.a $DIR.copy &&
	LINKVAL=$(flux kvs readlink $DIR.copy.b.link) &&
	test "$LINKVAL" = "$DIR.a.b.X"
'

# Keep the next two tests in order
test_expect_success 'kvs: link: dangling link' '
	flux kvs unlink -Rf $DIR &&
	flux kvs link $DIR.dangle $DIR.a.b.c
'
test_expect_success 'kvs: link: readlink on dangling link' '
	OUTPUT=$(flux kvs readlink $DIR.a.b.c) &&
	test "$OUTPUT" = "$DIR.dangle"
'
test_expect_success 'kvs: link: readlink works on non-dangling link' '
	flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.a.b.c="foo" &&
	flux kvs link $DIR.a.b.c $DIR.link &&
	OUTPUT=$(flux kvs readlink $DIR.link) &&
	test "$OUTPUT" = "$DIR.a.b.c"
'

# Check for limit on link depth

test_expect_success 'kvs: link: error on link depth' '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a=1 &&
	flux kvs link $DIR.a $DIR.b &&
	flux kvs link $DIR.b $DIR.c &&
	flux kvs link $DIR.c $DIR.d &&
	flux kvs link $DIR.d $DIR.e &&
	flux kvs link $DIR.e $DIR.f &&
	flux kvs link $DIR.f $DIR.g &&
	flux kvs link $DIR.g $DIR.h &&
	flux kvs link $DIR.h $DIR.i &&
	flux kvs link $DIR.i $DIR.j &&
	flux kvs link $DIR.j $DIR.k &&
	flux kvs link $DIR.k $DIR.l &&
        test_must_fail flux kvs get $DIR.l
'

test_expect_success 'kvs: link: error on link depth, loop' '
	flux kvs unlink -Rf $DIR &&
	flux kvs link $DIR.link1 $DIR.link2 &&
	flux kvs link $DIR.link2 $DIR.link1 &&
        test_must_fail flux kvs get $DIR.link1
'

#
# copy/move tests
#
test_expect_success 'kvs: copy works' '
        flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.src=\"foo\" &&
        flux kvs copy $DIR.src $DIR.dest &&
	OUTPUT1=$(flux kvs get $DIR.src) &&
	OUTPUT2=$(flux kvs get $DIR.dest) &&
	test "$OUTPUT1" = "foo" &&
	test "$OUTPUT2" = "foo"
'

test_expect_success 'kvs: move works' '
        flux kvs unlink -Rf $DIR &&
	flux kvs put $DIR.src=\"foo\" &&
        flux kvs move $DIR.src $DIR.dest &&
	test_must_fail flux kvs get $DIR.src &&
	OUTPUT=$(flux kvs get $DIR.dest) &&
	test "$OUTPUT" = "foo"
'

#
# dropcache tests
#

test_expect_success 'kvs: dropcache works' '
	flux kvs dropcache
'
test_expect_success 'kvs: dropcache --all works' '
	flux kvs dropcache --all
'

#
# version/wait tests
#

test_expect_success NO_CHAIN_LINT 'kvs: version and wait' '
	VERS=$(flux kvs version)
        VERS=$((VERS + 1))
        flux kvs wait $VERS &
        kvswaitpid=$! &&
        flux kvs put $DIR.xxx=99 &&
        test_expect_code 0 wait $kvswaitpid
'

#
# watch tests
#

# Various loops to wait for conditions before moving on.  Have
# observed racing between backgrounding watch process and foreground
# activities.
#
# Loop count is just to make sure we don't spin forever on error, 50
# loops/5 seconds seems like a decent maximum.

wait_watch_put() {
        i=0
        while [ "$(flux kvs get $1 2> /dev/null)" != "$2" ] && [ $i -lt 50 ]
        do
                sleep 0.1
                i=$((i + 1))
        done
        if [ $i -eq 50 ]
        then
            return 1
        fi
        return 0
}

wait_watch_empty() {
        i=0
        while flux kvs get $1 2> /dev/null && [ $i -lt 50 ]
        do
                sleep 0.1
                i=$((i + 1))
        done
        if [ $i -eq 50 ]
        then
            return 1
        fi
        return 0
}

wait_watch_current() {
        i=0
        while [ "$(tail -n 1 watch_out 2> /dev/null)" != "$1" ] && [ $i -lt 50 ]
        do
                sleep 0.1
                i=$((i + 1))
        done
        if [ $i -eq 50 ]
        then
            return 1
        fi
        return 0
}

# Note that we do not && after the final call to wait_watch_put or
# wait_watch_empty.  We want that as a barrier before launching our
# background watch process.
#
# We rm -f watch_out to remove any potential race with backgrounding
# of kvs watch process and a previous test's watch_out file.

test_expect_success NO_CHAIN_LINT 'kvs: watch a key'  '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.foo=0 &&
        wait_watch_put "$DIR.foo" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR.foo >watch_out &
        watchpid=$! &&
        wait_watch_current "0"
        flux kvs put $DIR.foo=1 &&
        wait $watchpid
	cat >expected <<-EOF &&
	0
	1
	EOF
        test_cmp watch_out expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a key that at first doesnt exist'  '
	flux kvs unlink -Rf $DIR &&
        wait_watch_empty "$DIR.foo"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR.foo >watch_out &
        watchpid=$! &&
        wait_watch_current "nil" &&
        flux kvs put $DIR.foo=1 &&
        wait $watchpid
	cat >expected <<-EOF &&
	nil
	1
	EOF
        test_cmp watch_out expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a key that gets removed'  '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.foo=0 &&
        wait_watch_put "$DIR.foo" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR.foo >watch_out &
        watchpid=$!
        wait_watch_current "0" &&
        flux kvs unlink $DIR.foo &&
        wait $watchpid
	cat >expected <<-EOF &&
	0
	nil
	EOF
        test_cmp watch_out expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a key that becomes a dir'  '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.foo=0 &&
        wait_watch_put "$DIR.foo" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR.foo >watch_out &
        watchpid=$! &&
        wait_watch_current "0" &&
        flux kvs put $DIR.foo.bar.baz=1 &&
        wait $watchpid
	cat >expected <<-EOF &&
	0
	======================
	$DIR.foo.bar.
	======================
	EOF
        test_cmp watch_out expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a dir'  '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a.a=0 $DIR.a.b=0 &&
        wait_watch_put "$DIR.a.a" "0" &&
        wait_watch_put "$DIR.a.b" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR >watch_out &
        watchpid=$! &&
        wait_watch_current "======================" &&
        flux kvs put $DIR.a.a=1 &&
        wait $watchpid
	cat >expected <<-EOF &&
	$DIR.a.
	======================
	$DIR.a.
	======================
	EOF
        test_cmp watch_out expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a dir that at first doesnt exist'  '
	flux kvs unlink -Rf $DIR &&
        wait_watch_empty "$DIR"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR >watch_out &
        watchpid=$! &&
        wait_watch_current "nil" &&
        flux kvs put $DIR.a.a=1 &&
        wait $watchpid
	cat >expected <<-EOF &&
	nil
	======================
	$DIR.a.
	======================
	EOF
        test_cmp watch_out expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a dir that gets removed'  '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a.a.a=0 $DIR.a.a.b=0 &&
        wait_watch_put "$DIR.a.a.a" "0" &&
        wait_watch_put "$DIR.a.a.b" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR.a >watch_out &
        watchpid=$! &&
        wait_watch_current "======================" &&
        flux kvs unlink -R $DIR.a &&
        wait $watchpid
	cat >expected <<-EOF &&
	$DIR.a.a.
	======================
	nil
	======================
	EOF
        test_cmp watch_out expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a dir, converted into a key'  '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a.a.a=0 $DIR.a.a.b=0 &&
        wait_watch_put "$DIR.a.a.a" "0" &&
        wait_watch_put "$DIR.a.a.b" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR.a >watch_out &
        watchpid=$! &&
        wait_watch_current "======================" &&
        flux kvs put $DIR.a=1 &&
        wait $watchpid
	cat >expected <<-EOF &&
	$DIR.a.a.
	======================
	1
	EOF
        test_cmp watch_out expected
'

# Difference between this test and prior one is we are converting $DIR
# to a key instead of $DIR.a to a key.  Since we are watching $DIR.a,
# prior test should see conversion of a $DIR.a to a key.  This time,
# $DIR.a is no longer valid and we should see 'nil' as a result.
test_expect_success NO_CHAIN_LINT 'kvs: watch a dir, prefix path converted into a key'  '
        flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a.a.a=0 $DIR.a.a.b=0 &&
        wait_watch_put "$DIR.a.a.a" "0" &&
        wait_watch_put "$DIR.a.a.b" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -o -c 1 $DIR.a >watch_out &
        watchpid=$! &&
        wait_watch_current "======================" &&
        flux kvs put $DIR=1 &&
        wait $watchpid
	cat >expected <<-EOF &&
	$DIR.a.a.
	======================
	nil
	======================
	EOF
        test_cmp watch_out expected
'

# Output of watch_out could be unsorted/out of order compared to
# expected output.  This function will re-order the output in each
# appropriate section (i.e. between ====================== lines)
sort_watch_output() {
        rm -f watch_out_sorted
        rm -f tmp_watch_file
        while read line
        do
            if [ "$line" = "======================" ]
            then
                cat tmp_watch_file | sort >> watch_out_sorted
                echo "======================" >> watch_out_sorted
                rm -f tmp_watch_file
            else
                echo "$line" >> tmp_watch_file
            fi
        done <watch_out
        return 0
}

test_expect_success NO_CHAIN_LINT 'kvs: watch a dir with -R'  '
        flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a.a=0 $DIR.a.b=0 &&
        wait_watch_put "$DIR.a.a" "0" &&
        wait_watch_put "$DIR.a.b" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -R -o -c 1 $DIR >watch_out &
        watchpid=$! &&
        wait_watch_current "======================" &&
        flux kvs put $DIR.a.a=1 &&
        wait $watchpid
        sort_watch_output
	cat >expected <<-EOF &&
	$DIR.a.a = 0
	$DIR.a.b = 0
	======================
	$DIR.a.a = 1
	$DIR.a.b = 0
	======================
	EOF
        test_cmp watch_out_sorted expected
'

test_expect_success NO_CHAIN_LINT 'kvs: watch a dir with -R and -d'  '
	flux kvs unlink -Rf $DIR &&
        flux kvs put $DIR.a.a=0 $DIR.a.b=0 &&
        wait_watch_put "$DIR.a.a" "0" &&
        wait_watch_put "$DIR.a.b" "0"
        rm -f watch_out
	stdbuf -oL flux kvs watch -R -d -o -c 1 $DIR >watch_out &
        watchpid=$! &&
        wait_watch_current "======================" &&
        flux kvs put $DIR.a.a=1 &&
        wait $watchpid
        sort_watch_output
	cat >expected <<-EOF &&
	$DIR.a.a
	$DIR.a.b
	======================
	$DIR.a.a
	$DIR.a.b
	======================
	EOF
        test_cmp watch_out_sorted expected
'

test_done
