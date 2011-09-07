package Genome::Task;

use strict;
use warnings;

use Genome;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

class Genome::Task {
    table_name => 'GENOME_TASK',
    id_generator => '-uuid',
    id_by => {
        'id' => {is=>'Text', len=>64}
    },
    has => {
        command_class => {is=>'Text', len=>255},
        params => {is=>'Text', is_optional => 1},
        stdout_pathname => {is => 'Text', len => 255, is_optional => 1},
        stderr_pathname => {is => 'Text', len => 255, is_optional => 1},
        status => {is => 'Text', len => 50},
        user_id => {is => 'Text', len => 255},
        time_submitted => {is => 'TIMESTAMP', column_name => 'SUBMIT_TIME'},
        time_started => {is => 'TIMESTAMP', is_optional => 1},
        time_finished => {is => 'TIMESTAMP', is_optional => 1},
    },
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'scheduled tasks'
};


1;
