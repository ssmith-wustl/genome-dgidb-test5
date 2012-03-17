package Genome::ProcessingProfile::GenotypeMicroarray;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::GenotypeMicroarray {
    is => 'Genome::ProcessingProfile',
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
    if ( not $instrument_data ) {
        $self->error_message('No instrument data for genotype microarray build '.$build->__display_name__);
        return;
    }
    $self->status_message('Instrument data: '.$instrument_data->id.' '.$instrument_data->sequencing_platform);

    my $reference_sequence_build = $build->model->reference_sequence_build;
    if ( not $reference_sequence_build ) {
        $self->error_message('No reference sequence build for '.$build->__display_name__);
        return;
    }
    $self->status_message('Reference sequence build: '.$reference_sequence_build->__display_name__);

    my $dbsnp_build = $build->dbsnp_build;
    if ( not $dbsnp_build ) {
        $dbsnp_build = Genome::Model::ImportedVariationList->dbsnp_build_for_reference($reference_sequence_build);
        if ( not $dbsnp_build ) {
            $self->error_message('No dbsnp build for '.$build->__display_name__);
            return;
        }
        $build->dbsnp_build($dbsnp_build);
        $build->model->dbsnp_build($dbsnp_build);
    }
    $self->status_message('DB SNP build: '.$dbsnp_build->__display_name__);

    my $fasta_file = $reference_sequence_build->full_consensus_path('fa');
    if ( ! -s $fasta_file ) {
        $self->error_message("Reference sequence has missing or 0 byte fasta file at $fasta_file.");
        return;
    }
    $self->status_message("Reference fasta file: $fasta_file");

    $self->status_message('Create genotype file...');
    my $genotype_file = $build->genotype_file_path;
    $self->status_message('Genotype file: '.$genotype_file);
    # FIXME move filters to profile params
    my @filters = (qw/ gc_score:min=0.7 /); 
    push @filters, 'invalid_iscan_ids' if $reference_sequence_build->version eq '36';
    my $extract = Genome::InstrumentData::Command::Microarray::Extract->create(
        instrument_data => $instrument_data,
        variation_list_build => $dbsnp_build,
        fields => [qw/ chromosome position alleles /],
        separator => 'tab',
        filters => \@filters,
        output => $genotype_file,
    );
    if ( not $extract ) {
        $self->error_message('Failed to create microarray extract for instrument data! '.$instrument_data->id);
        return;
    }
    $extract->dump_status_messages(1);
    if ( not $extract->execute ) {
        $self->error_message('Failed to execute microarray extract for instrument data! '.$instrument_data->id);
        return;
    }
    if ( not -s $genotype_file ) {
        $self->error_message('Executed microarray extract for instrument data, but genotype file is empty! '.$genotype_file);
        return;
    }
    $self->status_message('Create genotype file...OK');

    # Nutter made this file name, so we will link to it
    $self->status_message('Link genotpe file to gold2geno file...');
    $self->status_message('Genotype file: '.$genotype_file);
    my $gold2geno_file = $build->gold2geno_file_path;
    $self->status_message('Gold2geno file: '.$gold2geno_file);
    Genome::Sys->create_symlink($genotype_file, $gold2geno_file);
    if ( not -l $gold2geno_file  or not -s $gold2geno_file ) {
        $self->error_message('Failed to link genotype file to gold2geno file!');
        return;
    }
    $self->status_message('Link genotpe file to gold2geno file...OK');

    $self->status_message('Create copy number file...');
    my $copy_number_file = $build->copy_number_file_path;
    $self->status_message('Copy number file: '.$copy_number_file);
    $extract = Genome::InstrumentData::Command::Microarray::Extract->create(
        instrument_data => $instrument_data,
        variation_list_build => $dbsnp_build,
        fields => [qw/ chromosome position log_r_ratio /],
        separator => 'tab',
        filters => \@filters,
        output => $copy_number_file,
    );
    if ( not $extract ) {
        $self->error_message('Failed to create microarray extract for instrument data! '.$instrument_data->id);
        return;
    }
    $extract->dump_status_messages(1);
    if ( not $extract->execute ) {
        $self->error_message('Failed to execute microarray extract for instrument data! '.$instrument_data->id);
        return;
    }
    if ( not -s $copy_number_file ) {
        $self->error_message('Executed microarray extract for instrument data, but copy number file is empty! '.$copy_number_file);
        return;
    }
    $self->status_message('Create copy number file...OK');

    # TODO bdericks: I'm guessing that second genotype file is supposed to be the replicate. It should be changed
    # to be the actual replicate when we know how to figure it out.
    # abrummet: This is the only place in the tree where this Command is used.  I've stripped out the second input
    # file to fix a bug where it would not read from the "second" file when switching chromosomes and the next position
    # is numerically higher than the last position
    my $snp_array_file = $build->formatted_genotype_file_path;
    $self->status_message("Create snp array (gold) file: ".$snp_array_file);
    my $gold_snp = Genome::Model::GenotypeMicroarray::Command::CreateGoldSnpFileFromGenotypes->create(
        genotype_file => $genotype_file,
        output_file => $snp_array_file,
        reference_sequence_build => $reference_sequence_build, 
    );
    if ( not $gold_snp ) {
        $self->error_message("Cannot create gold snp tool.");
        return;
    }
    $gold_snp->dump_status_messages(1);
    if ( not $gold_snp->execute ) {
        $self->error_message("Cannot execute gold snp tool");
        return;
    }
    if ( not -s $snp_array_file ) {
        $self->error_message("Executed gold snp tool, but snp array file ($snp_array_file) does not exist");
        return;
    }
    $self->status_message("Create snp array (gold) file...OK");

    $self->status_message('Create gold snp bed file...');
    my $snvs_bed = $build->snvs_bed;
    $self->status_message('Gold snp bed file: '.$snvs_bed);
    my $gold_snp_bed = Genome::Model::GenotypeMicroarray::Command::CreateGoldSnpBed->create(
        input_file => $snp_array_file,
        output_file => $snvs_bed,
        reference => $reference_sequence_build,
    );
    if ( not $gold_snp_bed ) {
        $self->error_message('Failed to create gold snp bed tool!');
        return;
    }
    $gold_snp_bed->dump_status_messages(1);
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

