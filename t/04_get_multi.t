use strict;
use Test::More;

BEGIN
{
    if (! $ENV{ MEMCACHED_SERVER } ) {
        plan(skip_all => "Define MEMCACHED_SERVER (e.g. localhost:11211) to run this test");
    } else {
        plan(tests => 11);
    }
    use_ok("Cache::Memcached::libmemcached");
}

my $cache = Cache::Memcached::libmemcached->new( {
    servers => [ $ENV{ MEMCACHED_SERVER } ]
} );
isa_ok($cache, "Cache::Memcached::libmemcached");

{
    my @keys = ('a' .. 'z');
    foreach my $key (@keys) {
        $cache->set($key, $key);
    }

    my $h = $cache->get_multi(@keys);
    ok($h);
    isa_ok($h, 'HASH');

    my %expected = map { ($_ => $_) } @keys;
    is_deeply( $h, \%expected, "got all the expected values");
}

TODO: {
    local $TODO = "Memcached::libmemcached flag support required";

    my $key = 'complex-get_multi';
    my %data = (foo => [ qw(1 2 3) ]);

    $cache->set($key, \%data);

    my $h = $cache->get_multi($key);

    is_deeply($h->{$key}, \%data);

}

{
    my $cache2 = Cache::Memcached::libmemcached->new( {
        servers => [ $ENV{ MEMCACHED_SERVER } ],
        namespace => "t$$"
    } );
    isa_ok($cache2, "Cache::Memcached::libmemcached");
    
    my @keys = ('A' .. 'Z');
    foreach my $key (@keys) {
        $cache2->set($key, $key);
    }

    my $h = $cache2->get_multi(@keys);
    ok($h);
    isa_ok($h, 'HASH');

    my %expected = map { ($_ => $_) } @keys;
    is_deeply( $h, \%expected, "got all the expected values");

    my $master_key = 'dummy_master';
    $cache2->set([ $master_key, $_ ], $_) for @keys;
    my @k = map {[ $master_key, $_ ]} @keys;
    my $got = $cache2->get_multi(@k);
    %expected = map { $_ => $_ } @keys;
    is_deeply( $got, \%expected, "get_multi with master key" );
}
