package Genome::ProcessingProfile::PhenotypeCorrelation;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::PhenotypeCorrelation {
    is => 'Genome::ProcessingProfile',
    doc => "genotype-phenotype correlation of a population group",
    has_param => [
        alignment_strategy => {
            is => "Text",
            is_many => 0,
            doc => "Strategy align sequence reads.",
        },
        snv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect snvs.",
        },
        indel_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect indels.",
        },
        sv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect svs.",
        },
        cnv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect cnvs.",
        },
        group_samples_for_genotyping_by => {
            is => "Text",
            is_many => 0,
            is_optional => 1,
            default_value => 'all',
            doc => "group samples together when genotyping, using this attribute, instead of examining genomes independently (use \"all\" or \"trio\")",
        },
        phenotype_analysis_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            valid_values => ['case-control','quantitative'],
            doc => "Strategy to use to look at phenotypes.",
        },
    ],
};

sub help_synopsis_for_create {
    my $self = shift;
    return <<"EOS"

  # quantitative

    genome processing-profile create phenotype-correlation \
      --name 'September 2011 Quantitative Population Phenotype Correlation' \
      --alignment-strategy              'instrument_data aligned to reference_sequence_build using bwa 0.5.9 [-q 5] then merged using picard 1.29 then deduplicated using picard 1.29' \
      --snv-detection-strategy          'samtools r599 filtered by snp-filter v1' \
      --indel-detection-strategy        'samtools r599 filtered by indel-filter v1' \
      --group-samples-for-genotyping-by 'race' \            # some (optional) phenotypic trait, or 'trio' or 'all'
      --phenotype-analysis-strategy     'quantitative' \    # or 'case-control'

    genome propulation-group define 'ASMS-cohort-WUTGI-2011' ASMS1 ASMS2 ASMS3 ASMS4

    genome model define phenotype-correlation \
        --name                      'ASMS-v1' \
        --subject                   'ASMS-cohort-WUTGI-2011' \
        --processing-profile        'September 2011 Quantitative Phenotype Correlation' \

  # case-control

    genome processing-profile create phenotype-correlation \
      --name 'September 2011 Case-Control Population Phenotype Correlation' \
      --alignment-strategy              'instrument_data aligned to reference_sequence_build using bwa 0.5.9 [-q 5] then merged using picard 1.29 then deduplicated using picard 1.29' \
      --snv-detection-strategy          'samtools r599 filtered by snp-filter v1' \
      --indel-detection-strategy        'samtools r599 filtered by indel-filter v1' \
      --group-samples-for-genotyping-by 'trio', \
      --phenotype-analysis-strategy     'case-control'

    genome propulation-group define 'Ceft-Lip-cohort-WUTGI-2011' CL001 CL002 CL003

    genome model define phenotype-correlation \
        --name                  'Cleft-Lip-v1' \
        --subject               'Cleft-Lip-cohort-WUTGI-2011' \
        --processing-profile    'September 2011 Case-Control Phenotype Correlation' \
        --identify-cases-by     'some_nomenclature.has_cleft_lip = "yes"' \
        --identify-controls-by  'some_nomenclature.has_cleft_lip = "no"' \

    # If you leave off the subject, it would find all patients matching the case/control logic
    # and make a population group called ASMS-v1-cohort automatically???


EOS
}

sub help_detail_for_create {
    return <<EOS
  For a detailed explanation of how to write an alignmen strategy see:
    TBD

  For a detailed explanation of how to write a variant detection strategy, see:
    perldoc Genome::Model::Tools::DetectVariants2::Strategy;

  All builds will have a combined vcf in their variant detection directory.

EOS
}

sub help_manual_for_create {
    return <<EOS
  Manual page content for this pipeline goes here.
EOS
}

sub __errors__ {
    my $self = shift;
    my @errors;
    if ($self->alignment_strategy) {
        #my $strat = Genome::Model::Tools::DetectVariants2::Strategy->get($bx->value_for('alignment_strategy'));
        #push @errors, $strat->__errors__;
        #$strat->delete;
    }
    for my $strategy ('snv','indel','sv','cnv') {
        my $method_name = $strategy . '_detection_strategy';
        if (my $strategy_text = $self->$method_name) {
            my $strat = Genome::Model::Tools::DetectVariants2::Strategy->get($strategy_text);
            push @errors,
                map {
                    UR::Object::Tag->create(
                        type => 'invalid',
                        properties => [$method_name],
                        desc => $_
                    )
                }
                $strat->__errors__;
        }
    }
    return @errors;
}

sub _execute_build {
    my ($self,$build) = @_;

    # TODO: remove this and replace with the workflow logic at the bottom when we have one.
    # Version 1 of this pipeline will run in a linear way only if the underlying samples have already
    # had independent alignment and variant detection completed in other models.

    warn "The logic for building this is not yet in place!  The following is initial data gathering...";

    #
    # get the subject (population group), the individual members and their samples
    #

    my $population_group = $build->model->subject;
    $build->status_message("subject is " . $population_group->__display_name__);

    my @patients = $population_group->members();
    $build->status_message("found " . scalar(@patients) . " patients");

    my @samples = $population_group->samples;
    $build->status_message("found " . scalar(@samples) . " samples");

    my @instdata_assn = $build->inputs(name => 'instrument_data');
    $build->status_message("found " . scalar(@instdata_assn) . " assignments for the current build");

    my @instdata = Genome::InstrumentData->get(id => [ map { $_->value_id } @instdata_assn ]);
    $build->status_message("found " . scalar(@instdata) . " instdata");

    $self->status_message('Gathering alignments...');
    my $reference_sequence_build = $build->inputs(name => 'reference_sequence_build')->value;
    my $reference_fasta = $reference_sequence_build->full_consensus_path('fa');
    unless(-e $reference_fasta){
        die $self->error_message("fasta file for reference build doesn't exist!");
    }

    #
    # get the bam for each sample
    # this will only work right now if the per-sample model has already run
    # once Tom's new alignment thing is in place, it would actually generate them in parallel
    #
    
    my $result = Genome::InstrumentData::Composite->get_or_create(
        inputs => {
            instrument_data => \@instdata,
            reference_sequence_build => $reference_sequence_build,
        },
        strategy => $self->alignment_strategy,
    );

    my @bams = $result->bam_paths;
    unless (@bams == @samples) {
        die $self->error_message("Failed to find alignment results for all samples!");
    }
    $self->status_message('Found ' . scalar(@bams) . ' merged BAMs.');
    for my $bam (@bams){
        unless (-e $bam){
            die $self->error_message("Bam file could not be reached at: ".$bam);
        }
    }

    #
    # run the DV2 API to do variant detection as we do in somatic, but let it take in N BAMs
    # _internally_ it will (for the first pass):
    #  notice it's running on multiple BAMs
    #  get the single-BAM results
    #  merge them with joinx and make a combined VCF (tolerating the fact that per-bam variants are not VCF)
    #  run bamreadcount to fill-in the blanks
    #

    $self->status_message("Executing detect variants step");

    my %params;
    $params{snv_detection_strategy} = $self->snv_detection_strategy if $self->snv_detection_strategy;
    $params{indel_detection_strategy} = $self->indel_detection_strategy if $self->indel_detection_strategy;
    $params{sv_detection_strategy} = $self->sv_detection_strategy if $self->sv_detection_strategy;
    $params{cnv_detection_strategy} = $self->cnv_detection_strategy if $self->cnv_detection_strategy;

    $params{reference_build_id} = $reference_sequence_build->id;
    $params{multiple_bams} = \@bams;

    my $output_dir = $build->data_directory."/variants";
    $params{output_directory} = $output_dir;

    eval { Genome::Model::Tools::DetectVariants2::Dispatcher->execute(%params); };
    if ($@) {
        $self->warning_message("Failed to execute detect variants with multiple BAMs!\n");
        #die $self->warning_message("Failed to execute detect variants dispatcher(err:$@) with params:\n" . Data::Dumper::Dumper \%params);
    }
    else {
        $self->status_message("detect variants command completed successfully");
    }

    # dump pedigree data into a file

    # dump clinical data into a file

    # we'll figure out what to do about the analysis_strategy next...

    return 1;
}

sub _validate_build {
    my $self = shift;
    my $dir = $self->data_directory;

    my @errors;
    unless (1) {
        my $e = $self->error_message("Something is wrong!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

1;

__END__

# TODO: replace the above _execute_build with an actual workflow

sub _resolve_workflow_for_build {
    my $self = shift;
    $DB::single = 1;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');

    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);

    #I think this ideally should be handled
    $operation->name($build->workflow_name);

    return $operation;
}

sub _map_workflow_inputs {
    my $self = shift;
    $DB::single = 1;
    my $build = shift;

    my @inputs = ();

    # Verify the somatic model
    my $model = $build->model;

    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        die $self->error_message;
    }

    my $tumor_build = $build->tumor_build;
    my $normal_build = $build->normal_build;

    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor_build associated with this somatic capture build!");
        die $self->error_message;
    }

    unless ($normal_build) {
        $self->error_message("Failed to get a normal_build associated with this somatic capture build!");
        die $self->error_message;
    }

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        die $self->error_message;
    }

    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        die $self->error_message;
    }

    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        die $self->error_message;
    }

    push @inputs, build_id => $build->id;

    return @inputs;
}

1;
