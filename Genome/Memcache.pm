
package Genome::Memcache;

use strict;
use warnings;


class Genome::Memcache {
     is => 'UR::Singleton',
    doc => 'methods for accessing memcache',
    has => {
        memcache_server_location => {
            is => 'Text',
            default_value => Genome::Config::dev_mode()
                            ? 'imp:11211'
                            : 'aims-dev:11211',
        },
        _memcache_server => {
            is => 'Cache::Memcached',
            is_transient => 1,
        },
        memcache_server => {
            calculate_from => ['_memcache_server', 'memcache_server_location'],
            calculate => q{ return $_memcache_server || new Cache::Memcached {'servers' => [$memcache_server_location], 'debug' => 0, 'compress_threshold' => 10_000,} }
        },
    }
};




sub server {

    my ($class) = @_;

    my $server = $class->_singleton_object->memcache_server();
    return $server;
}


1;




