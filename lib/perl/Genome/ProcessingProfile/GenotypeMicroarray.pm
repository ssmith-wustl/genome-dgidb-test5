package Genome::ProcessingProfile::GenotypeMicroarray;

use Genome;

class Genome::ProcessingProfile::GenotypeMicroarray {
    is => 'Genome::ProcessingProfile',
    has => [
        job_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        },
    ],
    has_param => [
        input_format => {
            doc => 'file format, defaults to "wugc", which is currently the only format supported',
            valid_values => ['wugc'],
            default_value => 'wugc',
        },
        instrument_type => {
            doc => 'the type of microarray instrument',
            valid_values => [qw/ affymetrix illumina infinium plink unknown /],
        },
    ],
};

sub _execute_build {
    my ($self, $build) = @_;
    
    $self->status_message('Execute genotype microarray build '.$build->__display_name__);

    my $instrument_data = $build->instrument_data;
    if ( not $instrument_data ) { # ok for now
        $self->status_message('OK: No instrument data for genotype microarray build '.$build->__display_name__);
        return 1;
    }

    $self->status_message('Instrument data: '.$instrument_data->id.' '.$instrument_data->sequencing_platform);

    my $reference_sequence_build = $build->model->reference_sequence_build;
    if ( not $reference_sequence_build ) {
        $self->error_message('No reference sequence build for '.$build->__display_name__);
        return;
    }

    $self->status_message('Reference sequence build: '.$reference_sequence_build->__display_name__);

    my $fasta_file = $reference_sequence_build->full_consensus_path('fa');
    if ( ! -s $fasta_file ) {
        $self->error_message("Reference sequence has missing or 0 byte fasta file at $fasta_file.");
        return;
    }
    $self->status_message("Reference fasta file: $fasta_file");


    my $subject_name = $reference_sequence_build->subject_name;
    my $version = $reference_sequence_build->version;
    $self->status_message("Getting genotype microarray file for subject ($subject_name) and version ($version)");

    my $genotype_file = $instrument_data->genotype_microarray_file_for_subject_and_version($subject_name, $version);
    if ( not -s $genotype_file ) { 
        $self->error_message('No genotype microarray file available. This file is expected if genotype models have instrument data'); 
        return;
    }

    $self->status_message('Genotype microarray file: '.$genotype_file);

    # TODO bdericks: I'm guessing that second genotype file is supposed to be the replicate. It should be changed
    # to be the actual replicate when we know how to figure it out.
    my $snp_array_file = $build->formatted_genotype_file_path;
    $self->status_message("Create snp array (gold) file: ".$snp_array_file);
    my $gold_snp = Genome::Model::GenotypeMicroarray::Command::CreateGoldSnpFileFromGenotypes->create(
        genotype_file_1 => $genotype_file,
        genotype_file_2 => $genotype_file,
        output_file => $snp_array_file,
        reference_sequence_build => $reference_sequence_build, 
    );
    if ( not $gold_snp ) {
        $self->error_message("Cannot create gold snp tool.");
        return;
    }
    if ( not $gold_snp->execute ) {
        $self->error_message("Cannot execute gold snp tool");
        return;
    }
    if ( not -s $snp_array_file ) {
        $self->error_message("Executed gold snp tool, but snp array file ($snp_array_file) does not exist");
        return;
    }
    $self->status_message("Create snp array (gold) file...OK");

    my $snvs_bed = $build->snvs_bed;
    $self->status_message('Create gold snp bed file: '.$snvs_bed);
    my $gold_snp_bed = Genome::Model::GenotypeMicroarray::Command::CreateGoldSnpBed->create(
        input_file => $snp_array_file,
        output_file => $snvs_bed,
        reference => $build->model->reference_sequence_build,
    );
    unless ($gold_snp_bed->execute) {
        $self->error_message("Could not generate gold snp bed file at $snvs_bed from snp array file $snp_array_file");
        return;
    }
    if ( not -s $snvs_bed ) {
        $self->error_message("Executed 'create gold snp bed', but snvs bed file ($snvs_bed) does not exist");
        return;
    }
    $self->status_message("Create gold snp bed file...OK");

    $self->status_message('Execute genotype microarray build...OK');

    return 1;
}

1;

