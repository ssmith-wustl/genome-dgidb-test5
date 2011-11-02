package Genome::Search::IndexQueue;

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

sub create {
    my $class = shift;
    my %params = @_;

    unless (exists $params{timestamp}) {
        $params{timestamp} = UR::Context->now;
    }

    return $class->SUPER::create(%params);
}

1;
