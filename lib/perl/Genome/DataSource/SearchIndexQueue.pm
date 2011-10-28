package Genome::DataSource::SearchIndexQueue;

use strict;
use warnings;

class Genome::DataSource::SearchIndexQueue {
    is => 'UR::DataSource::SQLite',
};

sub server {
    my $class_file = __FILE__;
    (my $sqlite_file = $class_file) =~ s/\.pm$/\.sqlite3/;
};

1;

