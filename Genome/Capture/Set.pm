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
    my $fs;
    if ($capture_set->file_storage_id) {
        $fs = $capture_set->get_file_storage;
    }
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
        my $barcode = $self->barcode;
        unless ($barcode) {
            $self->error_message('Failed to find BED from file storage or by barcode.');
            die($self->error_message);
        }
        my $tmp_file = Genome::Utility::FileSystem->create_temp_file_path($barcode .'.bed');
        my $cmd = '/gsc/scripts/bin/capture_file_dumper --barcode='. $barcode .' --output-type=region-bed --output-file='. $tmp_file;
        Genome::Utility::FileSystem->shellcmd(
            cmd => $cmd,
            output_files => [$tmp_file],
        );
        my $tmp_fh = Genome::Utility::FileSystem->open_file_for_reading($tmp_file);
        while (my $line = $tmp_fh->getline) {
            $bed_file_content .= $line;
        }
        $tmp_fh->close;
    }
    #TODO: perform similar parsing/merging that is in Genome::Capture::Set::Command::Import
    
    # Remove the chr globally from the files
    $bed_file_content =~ s/chr//g;
    print $bed_fh $bed_file_content;
    $bed_fh->close;

    return 1;
}

sub barcode {
    my $self = shift;
    my $barcode = $self->get_barcode;
    unless ($barcode) { return; }
    return $barcode->barcode;
}

sub get_barcode {
    my $self = shift;
    my $cs = $self->_capture_set;
    return $cs->get_barcode;
}

1;
