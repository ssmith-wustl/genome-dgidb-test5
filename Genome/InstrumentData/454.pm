package Genome::InstrumentData::454;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::454 {
    is  => 'Genome::InstrumentData',
    table_name => <<'EOS'
        (
            select 
                to_char(region_id) id,
                region_id genome_model_run_id, --legacy
                region_number limit_regions, --legacy
                r.* 
            from run_region_454@dw r
        ) x454_detail
EOS
    ,
    has_optional => [
        _sff_file => {
                      is => 'String',
                      is_transient => 1,
                      is_mutable => 1,
                  },
        #< Run Region 454 from DW Attrs >#
        run_region_454     => {
            doc => '454 Run Region from LIMS.',
            is => 'GSC::RunRegion454',
            calculate => q| GSC::RunRegion454->get($id); |,
            calculate_from => ['id']
        },
        region_id           => { },
        region_number       => { },
        total_reads         => { column_name => "TOTAL_KEY_PASS" },
        is_paired_end       => { column_name => "PAIRED_END" },

        # deprecated, compatible with Genome::RunChunk::Solexa
        genome_model_run_id => {},
        limit_regions       => {},

    ],
};

sub _default_full_path {
    my $self = shift;
    return sprintf('%s/%s/%s', $self->_data_base_path, $self->run_name, $self->id);
}

sub resolve_sff_path {
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
        $sff_file = sprintf('%s/%s.sff', $self->resolve_full_path, $self->seq_id);
    }
    return $sff_file;
}

sub sff_file {
    my $self = shift;

    unless ($self->_sff_file) {
        $self->_sff_file($self->resolve_sff_path);
    }
    return $self->_sff_file;
}

sub sff_basename {
    my $self = shift;
    return File::Basename::basename($self->sff_file,'.sff');
}

#< Dump to File System >#
sub dump_to_file_system {
    my $self = shift;

    unless ( -e $self->sff_file ) {
        unless ($self->create_data_directory_and_link) {
            $self->error_message('Failed to create directory and link');
            return;
        }
        unless (Genome::Utility::FileSystem->lock_resource(
                                                           lock_directory => $self->resolve_full_path,
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
                                                             lock_directory => $self->resolve_full_path,
                                                             resource_id => $self->seq_id,
                                                         )) {
            $self->error_message('Failed to unlock_resource '. $self->seq_id);
            return;
        }
    }
    return 1;
}


1;

#$HeadURL$
#$Id$
