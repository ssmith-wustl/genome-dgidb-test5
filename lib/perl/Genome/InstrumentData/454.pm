package Genome::InstrumentData::454;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::454 {
    is => 'Genome::InstrumentData',
    has_constant => [
        sequencing_platform => { value => '454' },
    ],
    has_optional => [
        beads_loaded => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'beads_loaded' ],
            is_mutable => 1,
        },
        copies_per_bead => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'copies_per_bead' ],
            is_mutable => 1,
        },
        fc_id => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'fc_id' ],
            is_mutable => 1,
        },
        incoming_dna_name => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'incoming_dna_name' ],
            is_mutable => 1,
        },
        key_pass_wells => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'key_pass_wells' ],
            is_mutable => 1,
        },
        predicted_recovery_beads => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'predicted_recovery_beads' ],
            is_mutable => 1,
        },
        region_id => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'region_id' ],
            is_mutable => 1,
        },
        region_number => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'region_number' ],
            is_mutable => 1,
        },
        research_project => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'research_project' ],
            is_mutable => 1,
        },
        sample_set => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'sample_set' ],
            is_mutable => 1,
        },
        ss_id => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'ss_id' ],
            is_mutable => 1,
        },
        supernatant_beads => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'supernatant_beads' ],
            is_mutable => 1,
        },
        total_key_pass => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'total_key_pass' ],
            is_mutable => 1,
        },
        total_raw_wells => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'total_raw_wells' ],
            is_mutable => 1,
        },
        index_sequence => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'index_sequence' ],
            is_mutable => 1,
        },
        total_reads => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'total_reads' ],
            is_mutable => 1,
        },
        total_bases_read => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'total_bases_read' ],
            is_mutable => 1,
        },
        is_paired_end => {
            via => 'attributes',
            to => 'attribute_value',
            where => [ attribute_label => 'paired_end' ],
            is_mutable => 1,
        },
        # TODO Need to refactor these objects away
        run_region_454 => {
            is => 'GSC::RunRegion454',
            calculate_from => ['region_id'],
            calculate => q| GSC::RunRegion454->get($region_id); |,
            doc => '454 Run Region from LIMS.',
        },
        region_index_454 => {
            is => 'GSC::RegionIndex454',
            calculate_from => ['id'],
            calculate => q| GSC::RegionIndex454->get($id); |,
            doc => 'Region Index 454 from LIMS.',
        },
    ],
    has_optional_transient => [
        _fasta_file => { is => 'FilePath', is_mutable => 1, },
        _qual_file => { is => 'FilePath', is_mutable => 1, },
    ],
};

BEGIN: {
    Genome::InstrumentData::Solexa->class;
    no warnings 'once';
    *dump_trimmed_fastq_files = \&Genome::InstrumentData::Solexa::dump_trimmed_fastq_files;
}

sub full_path {
    Carp::confess("Full path is not valid for 454 instrument data");
}

sub bam_path {
    my $self = shift;
    $self->warning_message("Asked this 454 instrument data for bam path, but this is not implemented yet.");
    return undef;
}

sub _default_full_path {
    my $self = shift;
    return sprintf('%s/%s/%s', $self->_data_base_path, $self->run_name, $self->region_id);
}

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    return 500000;
}

sub is_external {
    return;
}

#< Fastq, Fasta, Qual ... >#
sub dump_sanger_fastq_files {
    my $self = shift;
    
    my %params = @_;
    
    unless (-s $self->sff_file) {
        $self->error_message(sprintf("SFF file (%s) doesn't exist for 454 instrument data %s", $self->sff_file, $self->id));
        die $self->error_message;
    }
    
    my $dump_directory = delete $params{'directory'} || Genome::Sys->base_temp_directory();
    
    my $output_file = sprintf("%s/%s-output.fastq", $dump_directory, $self->id);
    
    my $cmd = Genome::Model::Tools::454::Sff2Fastq->create(sff_file => $self->sff_file,
                                                           fastq_file => $output_file);
    
    unless ($cmd->execute) {
        $self->error_message("Sff2Fastq failed while dumping fastq file for instrument data " . $self->id);
        die $self->error_message;
    }
    
    unless (-s $output_file) {
        $self->error_message("Sff2Fastq claims it worked, but the output file was gone or empty length while dumping fastq file for instrument data "
                             . $self->id . " expected output file was $output_file");
        die $self->error_message;
    }
    
    return ($output_file);
}

sub dump_fasta_file {
    my ($self, %params) = @_;
    $params{type} = 'fasta';
    return $self->_run_sffinfo(%params);
}

sub dump_qual_file {
    my ($self, %params) = @_;
    $params{type} = 'qual';
    return $self->_run_sffinfo(%params);
}

sub _run_sffinfo {
    my ($self, %params) = @_;

    # Type 
    my $type = delete $params{type};
    my %types_params = (
        fasta => '-s',
        qual => '-q',
    );
    unless ( defined $type and grep { $type eq $_ } keys %types_params ) { # should not happen
        Carp::confess("No or invalid type (".($type || '').") to run sff info.");
    }

    # Verify 64 bit
    unless ( Genome::Config->arch_os =~ /x86_64/ ) {
        Carp::confess(
            $self->error_message('Dumping $type file must be run on 64 bit machine.')
        );
    }
    
    # SFF
    my $sff_file = $self->sff_file;
    unless ( -s $sff_file ) {
        Carp::confess(
            $self->error_message(
                "SFF file ($sff_file) doesn't exist for 454 instrument data (".$self->id.")"
            )
        );
    }

    # File
    my $directory = delete $params{'directory'} 
        || Genome::Sys->base_temp_directory();
    my $file = sprintf("%s/%s.%s", $directory, $self->id, $type);
    unlink $file if -e $file;
    
    # SFF Info
    my $sffinfo = Genome::Model::Tools::454::Sffinfo->create(
        sff_file => $sff_file,
        output_file => $file,
        params => $types_params{$type},
    );
    unless ( $sffinfo ) {
        Carp::confess(
            $self->error_message("Can't create SFF Info command.")
        );
    }
    unless ( $sffinfo->execute ) {
        Carp::confess(
            $self->error_message("SFF Info command failed to dump $type file for instrument data (".$self->id.")")
        );
    }

    # Verify
    unless ( -s $file ) {
        Carp::confess(
            $self->error_message("SFF info executed, but a fasta was not produced for instrument data (".$self->id.")")
        );
    }

    return $file;
}

#< SFF >#
sub sff_file {
    # FIXME this was updated, but legacy code automatically dumped the region
    #  sff if it didn't exist
    my $self = shift;

    # Use the region index first.
    my $region_index_454 = $self->region_index_454;
    # If the region index has an index sequence, it's indexed. Use its sff file
    if ( $region_index_454 and $region_index_454->index_sequence ) {
        my $sff_file_object = $region_index_454->get_index_sff;
        return unless $sff_file_object;
        return $sff_file_object->stringify;
        # get_index_sff does 2 checks:
        #  is there an index sequence?  we know this is true here
        #  are there reads?
        #  If there aren't any reads, this method reurns undef, and that is ok.
        #  If there are reads, the sff file should exist. If it doesn't, it dies
    }

    # If no index sequence, this is the 'parent' region
    my $sff_file;
    eval {
        $sff_file = $self->run_region_454->sff_filesystem_location_string;
    };

    # It this is defined, the file should exist
    return $sff_file if defined $sff_file;

    # Check if it is dumped
    my $disk_allocation = Genome::Disk::Allocation->get(
        owner_id => $self->id,
        owner_class_name => $self->class,
    );
    if ( $disk_allocation ) {
        $sff_file = $disk_allocation->absolute_path.'/'.$self->id.'.sff';
        return $sff_file if -s $sff_file;
    }

    # Gotta dump...lock, creat allocation (if needed), dump, unlock
    # lock
    my $lock_id = '/gsc/var/lock/inst_data_454/'.$self->id;
    my $lock = Genome::Sys->lock_resource(
        resource_lock => $lock_id, 
        max_try => 1,
    );
    unless ( $lock ) {
        $self->error_message(
            "Failed to get a lock for 454 instrument data ".$self->id.". This means someone|thing else is already attempting to dump the sff file. Please wait a moment, and try again. If you think that this model is incorrectly locked, please put a ticket into the apipe support queue."
        );
        return;
    }

    # create disk allocation if needed
    unless ( $disk_allocation ) {
        $disk_allocation = Genome::Disk::Allocation->allocate(
            disk_group_name => 'info_alignments',
            allocation_path => '/instrument_data/454_'.$self->id,
            kilobytes_requested => 10240, # 10 Mb TODO
            owner_class_name => $self->class,
            owner_id => $self->id
        );
        unless ( $disk_allocation ) {
            Carp::confess(
                $self->error_message('Failed to create disk allocation for 454 instrument data '.$self->id)
            );
        }
    }

    # dump
    $sff_file = $disk_allocation->absolute_path.'/'.$self->id.'.sff';
    unless ( $self->run_region_454->dump_sff(filename => $sff_file) ) {
        $self->error_message('Failed to dump sff file to '. $sff_file.' for 454 instrument data '.$self->id);
        return;
    }
    unless ( -s $sff_file ) {
        $self->error_message("Successfully dumped sff from run region 454, but sff file ($sff_file) is empty for 454 instrument data ".$self->id);
        return;
    }

    # unlock
    my $unlock = Genome::Sys->unlock_resource(
        resource_lock => $lock_id,
    );
    unless ( $unlock ) {
        $self->error_message('Failed to unlock resource '. $self->id);
        return;
    }

    return $sff_file;
}
#<>#

#< Run Info >#
sub run_identifier {
my $self = shift;

my $ar_454 = $self->run_region_454->get_analysis_run_454;

my $pse = GSC::PSE->get($ar_454->pse_id);
my $loadpse = $pse->get_load_pse;
my $barcode = $loadpse->picotiter_plate;

return $barcode->barcode->barcode;
}

sub run_start_date_formatted {
    my $self = shift;

    my ($y, $m, $d) = $self->run_name =~ m/R_(\d{4})_(\d{2})_(\d{2})/;

    my $dt_format = UR::Time->config('datetime');
    UR::Time->config(datetime=>'%Y-%m-%d');
    my $dt = UR::Time->numbers_to_datetime(0, 0, 0, $d, $m, $y);
    UR::Time->config(datetime=>$dt_format);

    return $dt; 
}
#<>#

1;

