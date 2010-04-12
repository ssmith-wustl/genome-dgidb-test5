package Genome::Capture::Set;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set {
    table_name => q|
        (select
            setup_name name,
            setup_id id,
            setup_status status,
            setup_description description
        from setup@oltp
        where setup_type = 'setup capture set'
        ) capture_set
    |,
    id_by => [
        id => { },
    ],
    has => {
        name => { },
        description => { },
        status => { },
        _capture_set => {
            doc => 'Solexa Lane Summary from LIMS.',
            is => 'GSC::Setup::CaptureSet',
            calculate => q| GSC::Setup::CaptureSet->get($id); |,
            calculate_from => ['id']
        },
    },
    has_many_optional => {
        set_oligos => {
            is => 'Genome::Capture::SetOligo',
            reverse_as => 'set',
        }
    },
    doc         => '',
    data_source => 'Genome::DataSource::GMSchema',
};

sub bed_file_content {
    my $self = shift;
    my $capture_set = $self->_capture_set;
    my $fs = $capture_set->get_file_storage;
    unless ($fs) {
        return;
    }
    return $fs->content;
}

sub print_bed_file {
    my $self = shift;
    my $bed_file = shift;

    my $bed_fh = Genome::Utility::FileSystem->open_file_for_writing($bed_file);
    unless ($bed_fh) {
        die('Failed to open bed file '. $bed_file .' for writing!');
    }
    my $bed_file_content = $self->bed_file_content;
    unless ($bed_file_content) {
        #TODO: create a method that will return the oligos/targets in BED format
        $self->error_message('Failed to find BED format content.');
        return;
    }
    print $bed_fh $self->bed_file_content;
    return 1;
}

1;
