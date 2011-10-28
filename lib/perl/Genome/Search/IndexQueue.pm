package Genome::Search::IndexQueue;

class Genome::Search::IndexQueue {
    id_generator => '-uuid',
    id_by => [
        id => {
            is => 'Text',
        },
    ],
    has => [
        timestamp => {
            is => 'Time',
        },
        subject_id => {
            is => 'Text',
        },
        subject_class => {
            is => 'Text',
        },
        subject => {
            is => 'UR::Object',
            id_by => 'subject_id',
            id_class_by => 'subject_class',
        },
        action => {
            is => 'Text',
            valid_values => ['add', 'delete'],
        },
    ],
    data_source => 'Genome::DataSource::SearchIndexQueue',
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
