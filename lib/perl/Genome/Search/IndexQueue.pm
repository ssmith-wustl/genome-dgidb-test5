# TODO
# - change Search observers to add item here instead of committing straight to server

package Genome::Search::IndexQueue;

class Genome::Search::IndexQueue {
    id_generator => '-uuid',
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
    data_source => 'Genome::DataSource::GMSchema',
    table_name => 'search_index_queue',
};
