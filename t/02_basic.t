use strict;
use Test::More;

BEGIN
{
    if (! $ENV{ MEMCACHED_SERVER } ) {
        plan(skip_all => "Define MEMCACHED_SERVER (e.g. localhost:11211) to run this test");
    } else {
        plan(tests => 26);
    }
    use_ok("Cache::Memcached::libmemcached");
}

my $cache = Cache::Memcached::libmemcached->new( {
    servers => [ $ENV{ MEMCACHED_SERVER } ]
} );
isa_ok($cache, "Cache::Memcached::libmemcached");

{
    $cache->set("foo", "bar", 300);
    my $val = $cache->get("foo");
    is($val, "bar", "simple value");
}

{
    $cache->set("foo", { bar => 1 }, 300);
    my $val = $cache->get("foo");
    is_deeply($val, { bar => 1 }, "got complex values");
}

{
    ok( $cache->get("foo"),  "before delete returns ok");
    ok( $cache->delete("foo") );
    ok( ! $cache->get("foo"),  "delete works");
    ok( ! $cache->delete("foo") );
}

{
    ok( $cache->set("foo", 1), "prep for incr" );
    is( $cache->incr("foo"), 2, "incr returns 1 more than previous" );
    is( $cache->decr("foo"), 1, "decr returns 1 less than previous" );
}

{
    # test accessors
    foreach my $threshold (10_000, 5_000, 0) {
        $cache->set_compress_threshold($threshold);
        is( $cache->get_compress_threshold(), $threshold );
    }

    foreach my $savings qw(0.2 0.5 0.8) {
        $cache->set_compress_savings($savings);
        is( $cache->get_compress_savings(), $savings );
    }

    foreach my $enabled (0, 1, 0, 1) {
        $cache->set_compress_enable($enabled);
        is( !!$cache->get_compress_enable(), !!$enabled );
    }
}

{ # bad constructor call
    $cache = eval { Cache::Memcached::libmemcached->new() };
    like($@, qr/No servers specified/);
}

{ # default value in constructor
    $cache = Cache::Memcached::libmemcached->new({
        servers => [ $ENV{ MEMCACHED_SERVER } ],
        compress_enable => 1,
    });
    my $explicit = $cache->get_compress_enable;

    $cache = Cache::Memcached::libmemcached->new({
        servers => [ $ENV{ MEMCACHED_SERVER } ],
    });
    my $implicit = $cache->get_compress_enable;

    is($explicit, $implicit);

    $cache = Cache::Memcached::libmemcached->new({
        servers => [ $ENV{ MEMCACHED_SERVER } ],
        compress_enable => 0,
    });
    ok(!$cache->get_compress_enable, "check explicit compress_enable => 0");
}

SKIP: {
    if (Cache::Memcached::libmemcached::OPTIMIZE) {
        skip("OPTIMIZE flag is enabled", 1);
    }
    $cache = Cache::Memcached::libmemcached->new({
        servers => [ $ENV{ MEMCACHED_SERVER } ],
        compress_enable => 1,
    });

    my $master_key = 'dummy_master';
    my $key        = 'foo_with_master';
    $cache->set([ $master_key, $key ], 100);
    is( $cache->get([ $master_key, $key ]), 100, "get with master key" );

    my $master_key2 = 'dummy_master2';
    my $key2        = 'foo_with_master';
    $cache->set([ $master_key2, $key2 ], 200);
    is_deeply( $cache->get_multi([ $master_key, $key ], [ $master_key2, $key2 ]), {$key => 100, $key2 => 200}, , "get_multi with master key" );
}

