package Genome::DataSource::Queue;

use strict;
use warnings;

class Genome::DataSource::Queue {
    is => 'UR::DataSource::SQLite',
};

sub server {
    my $class_file = __FILE__;
    (my $sqlite_file = $class_file) =~ s/\.pm$/\.sqlite3/;
};

1;

