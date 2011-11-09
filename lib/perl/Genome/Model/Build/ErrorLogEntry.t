use strict;
use warnings;
use above 'Genome';
package Genome::Model::Build::ErrorLogEntry::Test;
use Test::More;

$ENV{UR_DBI_NO_COMMIT}=1;

ok(my $log_entry = Genome::Model::Build::ErrorLogEntry->create(
    message => _generate_long_message(),
    inferred_message => _generate_long_message(),
), 'created log entry');

is($log_entry->message, 'a' x 4000, 'truncated message to 4000');
is($log_entry->inferred_message, 'a' x 4000, 'truncated inferred message to 4000');

done_testing();

sub _generate_long_message {
    return 'a' x 8000;
}
