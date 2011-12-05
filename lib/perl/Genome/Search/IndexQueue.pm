package Genome::Search::IndexQueue;

use Carp;
use Genome;

class Genome::Search::IndexQueue {
    id_generator => '-uuid',
    id_by => [
        id => {
            is => 'Text',
        },
    ],
    has => [
        subject_class => {
            is => 'Text',
            doc => 'Class of the subject to be indexed by search.',
        },
        subject_id => {
            is => 'Text',
            doc => 'ID of the subject to be indexed by search.',
        },
        timestamp => {
            is => 'Time',
            doc => 'Timestamp of first request. Automatically added if not provided.',
        },
        priority => {
            is => 'Number',
            doc => 'Set or increase numeric value to *lower* priority. (-order_by is ascending with undef in first position)',
            default_value => 0,
        },
    ],
    data_source => 'Genome::DataSource::GMSchema',
    table_name => 'SEARCH_INDEX_QUEUE',
};

sub create {
    my $class = shift;

    my $bx = $class->define_boolexpr(@_);

    my $subject_class = $bx->value_for('subject_class');
    unless ($subject_class) {
        Carp::croak "subject_class not specified, cannot check if it is indexable";
    }
    unless (Genome::Search->is_indexable($subject_class)) {
        Carp::croak "subject_class must be indexable in order to add to IndexQueue";
    }

    unless ($bx->specifies_value_for('timestamp')) {
        $bx = $bx->add_filter('timestamp' => UR::Context->now);
    }

    $index_queue = $class->SUPER::create($bx);

    return $index_queue;
}

1;
