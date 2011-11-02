package Genome::Search::IndexQueue;

use Carp;
use Genome;

class Genome::Search::IndexQueue {
    id_by => [
        subject_class => {
            is => 'Text',
            doc => 'Class of the subject to be indexed by search.',
        },
        subject_id => {
            is => 'Text',
            doc => 'ID of the subject to be indexed by search.',
        },
    ],
    has => [
        timestamp => {
            is => 'Time',
            doc => 'Timestamp of first request. Automatically added if not provided.',
        },
        subject => {
            is => 'UR::Object',
            id_by => 'subject_id',
            id_class_by => 'subject_class',
            doc => 'Subject to be indexed by search.',
        },
        action => {
            is => 'Text',
            valid_values => ['add', 'delete'],
            doc => 'For the given subject, perform this action on the search index.',
        },
    ],
    data_source => 'Genome::DataSource::Main',
    table_name => 'search_index_queue',
};

sub create_or_update {
    my $class = shift;
    my %params = @_;

    unless (exists $params{subject}) {
        Carp::croak "Must provide a subject when calling create_or_update";
    }

    unless (exists $params{action}) {
        Carp::croak "Must provide an action when calling create_or_update";
    }

    unless (Genome::Search->is_indexable($params{subject})) {
        Carp::croak "Subject must be indexable in order to add to IndexQueue";
    }

    # get by "ID"
    my $index_queue = $class->get(subject => $params{subject});

    if ($index_queue) {
        # Only set action, leave timestamp as original so that frequent updates
        # would not always move subject to the end of the index queue.
        $index_queue->action($params{action});
    }
    else {
        unless (exists $params{timestamp}) {
            $params{timestamp} = UR::Context->now;
        }
        $index_queue = $class->create(%params);
    }

    return $index_queue;
}

1;
