package Genome::Site::WUGC::CaptureSet;

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::CaptureSet {
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
            is => 'GSC::Setup::CaptureSet',
            calculate => q| GSC::Setup::CaptureSet->get($id); |,
            calculate_from => ['id']
        },
    },
    has_optional => {
        file_storage_id => {
            calculate_from => ['_capture_set'],
            calculate => q{ $_capture_set->file_storage_id },
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

sub barcodes {
    my $self = shift;
    my $cs = $self->_capture_set;
    my @barcodes = $cs->get_barcodes;
    return map {$_->barcode} @barcodes;
}

1;
