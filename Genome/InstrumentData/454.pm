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
                '454' sequencing_platform,
                region_id genome_model_run_id, --legacy
                region_number limit_regions, --legacy
                r.* 
            from run_region_454@dw r
        ) x454_detail
EOS
    ,
    has_constant => [
        sequencing_platform => { value => '454' },
    ],    
    has_optional => [
        _sff_file => {
                      is => 'String',
                      is_transient => 1,
                      is_mutable => 1,
                  },
        _fasta_file => {
                        is => 'String',
                        is_transient => 1,
                        is_mutable => 1,
                  },
        _qual_file => {
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

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    return 500000;
}

sub is_external {
    return;
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
        $sff_file = sprintf('%s/%s.sff', $self->resolve_full_path, $self->id);
    }
    return $sff_file;
}

sub resolve_fasta_path {
    my $self = shift;
    my $full_path = $self->full_path;
    unless ($full_path) {
        $full_path = $self->resolve_full_path;
    }
    unless (Genome::Utility::FileSystem->create_directory($full_path)) {
        $self->error_message("Failed to create instrument data directory '$full_path'");
        return;
    }
    return $full_path .'/'. $self->subset_name .'.fa';
}

sub resolve_qual_path {
    my $self = shift;
    my $full_path = $self->full_path;
    unless ($full_path) {
        $full_path = $self->resolve_full_path;
    }
    unless (Genome::Utility::FileSystem->create_directory($full_path)) {
        $self->error_message("Failed to create instrument data directory '$full_path'");
        return;
    }
    return $full_path .'/'. $self->subset_name .'.qual';
}

sub qual_file {
    my $self = shift;

    unless ($self->_qual_file) {
        $self->_qual_file($self->resolve_qual_path);
    }
    unless (-s $self->_qual_file) {
        unless (-e $self->sff_file) {
            $self->error_message('Failed to find sff_file: '. $self->sff_file);
            die($self->error_message);
        }
        #FIXME ALLOCATE 
        unless (Genome::Model::Tools::454::Sffinfo->execute(
                                                            sff_file => $self->sff_file,
                                                            output_file => $self->_qual_file,
                                                            params => '-q',
                                                        )) {
            $self->error_message('Failed to convert sff to qual file');
            die($self->error_message);
        }
    }
    return $self->_qual_file;
}

sub fasta_file {
    my $self = shift;

    unless ($self->_fasta_file) {
        $self->_fasta_file($self->resolve_fasta_path);
    }
    unless (-s $self->_fasta_file) {
        unless (-e $self->sff_file) {
            $self->error_message('Failed to find sff_file: '. $self->sff_file);
            die($self->error_message);
        }
        #FIXME ALLOCATE 
        unless (Genome::Model::Tools::454::Sffinfo->execute(
                                                            sff_file => $self->sff_file,
                                                            output_file => $self->_fasta_file,
                                                            params => '-s',
                                                        )) {
            $self->error_message('Failed to convert sff to fasta file');
            die($self->error_message);
        }
    }
    return $self->_fasta_file;
}

#FIXME MOVE TO BUILD 
sub trimmed_sff_file {
    my $self = shift;
    my $full_path = $self->resolve_full_path;
    unless (-d $full_path) {
        Genome::Utility::FileSystem->create_directory($full_path);
    }
    return $full_path .'/'. $self->sff_basename .'_trimmed.sff';
}

sub sff_file {
    my $self = shift;

    unless ($self->_sff_file) {
        $self->_sff_file($self->resolve_sff_path);
    }
    unless ($self->dump_to_file_system) {
        $self->error_message('Failed to dump sff file to filesystem');
        return;
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

    unless ( -e $self->_sff_file ) {
        #FIXME ALLOCATE 
        unless ($self->create_data_directory_and_link) {
            $self->error_message('Failed to create directory and link');
            return;
        }
        unless (Genome::Utility::FileSystem->lock_resource(
                                                           lock_directory => $self->resolve_full_path,
                                                           resource_id => $self->id,
                                                           max_try => 60,
                                                       )) {
            $self->error_message('Failed to lock_resource '. $self->id);
            return;
        }
        unless ($self->run_region_454->dump_sff(filename => $self->_sff_file)) {
            $self->error_message('Failed to dump sff file to '. $self->_sff_file);
            return;
        }
        unless (Genome::Utility::FileSystem->unlock_resource(
                                                             lock_directory => $self->resolve_full_path,
                                                             resource_id => $self->id,
                                                         )) {
            $self->error_message('Failed to unlock_resource '. $self->id);
            return;
        }
    }
    return 1;
}

sub amplicon_header_file {
    my $self = shift;
    my $amplicon_header_file = $self->full_path .'/amplicon_headers.txt';
    unless (-e $amplicon_header_file) {
        my $fh = $self->create_file('amplicon_header_file',$amplicon_header_file);
        $fh->close;
        unlink($amplicon_header_file);
        my $amplicon = Genome::Model::Command::Report::Amplicons->create(
                                                                         sample_name => $self->sample_name,
                                                                         output_file => $amplicon_header_file,
                                                                     );
        unless ($amplicon) {
            $self->error_message('Failed to create amplicon report tool');
            return;
        }
        unless ($amplicon->execute) {
            $self->error_message('Failed to execute command '. $amplicon->command_name);
            return;
        }
    }
    return $amplicon_header_file;
}


1;

#$HeadURL$
#$Id$
