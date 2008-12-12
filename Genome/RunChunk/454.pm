package Genome::RunChunk::454;

use strict;
use warnings;

use Genome;

require Genome::Utility::FileSystem;

class Genome::RunChunk::454 {
    is  => 'Genome::RunChunk',
    has => [
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

sub sff_file {
    my $self = shift;

    my $sff_file;
    my $rr_454 = $self->run_region_454;
    eval {
        my $sff_file_object = $rr_454->sff_filesystem_location;
        if ($sff_file_object) {
            $sff_file = $sff_file_object->stringify;
        }
    };

    if ($@ || !defined($sff_file)) {
        $sff_file = sprintf('%s/%s.sff', $self->full_path, $self->seq_id);
    }

    return $sff_file;
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

    unless ( -e $self->sff_file ) {
        unless ($self->create_data_directory_and_link) {
            $self->error_message('Failed to create directory and link');
            return;
        }
        unless (Genome::Utility::FileSystem->lock_resource(
                                                           lock_directory => $self->full_path,
                                                           resource_id => $self->seq_id,
                                                           max_try => 60,
                                                       )) {
            $self->error_message('Failed to lock_resource '. $self->seq_id);
            return;
        }
        unless ($self->run_region_454->dump_sff(filename => $self->sff_file)) {
            $self->error_message('Failed to dump sff file to '. $self->sff_file);
            return;
        }
        unless (Genome::Utility::FileSystem->unlock_resource(
                                                             lock_directory => $self->full_path,
                                                             resource_id => $self->seq_id,
                                                         )) {
            $self->error_message('Failed to unlock_resource '. $self->seq_id);
            return;
        }
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

