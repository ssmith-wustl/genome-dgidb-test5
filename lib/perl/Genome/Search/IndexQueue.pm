# TODO
# - change Search observers to add item here instead of committing straight to server

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
    ],
    data_source => 'Genome::DataSource::Queue',
    table_name => 'search_index_queue',
};
