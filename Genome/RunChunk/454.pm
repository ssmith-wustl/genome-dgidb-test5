package Genome::RunChunk::454;

use strict;
use warnings;

use Genome;
use Genome::RunChunk;

class Genome::RunChunk::454 {
    is  => 'Genome::RunChunk',
    has => [
            sff_file => {
                         doc => 'The sff file associated with the 454 run chunk',
                         calculate_from => [qw/ full_path seq_id /],
                         calculate => q| return sprintf('%s/%s.sff', $full_path, $seq_id); |,
                     },
            run_region_454     => {
                                    doc => 'Lane representation from LIMS.  This class should eventually be a base class for data like this.',
                                    is => 'GSC::RunRegion454',
                                    calculate => q| GSC::RunRegion454->get($seq_id); |,
                                    calculate_from => ['seq_id']
                                },
            library_name        => { via => "run_region_454" },
            total_reads         => { via => "run_region_454", to => "total_key_pass" },
            is_paired_end       => { via => "run_region_454", to => "paired_end" },
    ],
};

sub resolve_sequencing_platform {
    return '454';
}

sub resolve_subset_name {
    my $class = shift;
    my $read_set = shift;
    return $read_set->region_number;
}

sub resolve_full_path {
    my $class = shift;
    my $read_set = shift;

    my $full_path = '/gscmnt/sata363/info/medseq/sample_data/'. $read_set->run_name .'/'. $read_set->region_id .'/';
    return $full_path;
}

sub _dw_class { 'GSC::RunRegion454' }

sub _desc_dw_obj {
    my $class = shift;
    my $obj = shift;
    return $obj->run_name . "/" . $obj->region_number . " (" . $obj->id . ")";
}

# Copied from InstrumentData
sub create_data_directory_and_link {
    my $self = shift;

    my $data_path = $self->full_path;
    Genome::Utility::FileSystem->create_directory($data_path)
          or return;
    Genome::Utility::FileSystem->create_symlink($data_path, $self->data_link)
          or return;
    return $data_path;
}
# Copied from InstrumentData
sub dump_to_file_system {
    my $self = shift;

    $self->create_data_directory_and_link
        or return;
    unless ( -e $self->sff_file ) {
        if (-d $self->full_path . '/processing') {
            $self->error_message('Dump still processing: '. $self->full_path . '/processing');
            return;
        }
        Genome::Utility::FileSystem->create_directory($self->full_path . '/processing')
              or return;
        unless ( $self->run_region_454->dump_sff(filename => $self->sff_file) ) {
            $self->error_message('Failed to dump sff_file to '. $self->sff_file);
            return;
        }
        rmdir $self->full_path . '/processing' or return;
    }
    return 1;
}
# Copied from InstrumentData
sub _links_base_path {
    return '/gscmnt/839/info/medseq/instrument_data_links/';
}
# Copied from InstrumentData
sub data_link {
    return sprintf('%s/%s', _links_base_path(), $_[0]->seq_id);
}

1;

