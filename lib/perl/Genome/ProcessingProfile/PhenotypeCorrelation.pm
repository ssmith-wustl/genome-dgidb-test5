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
      --alignment-strategy              'bwa 0.5.9 [-q 5] merged by picard 1.29' \
      --snv-detection-strategy          'samtools r599 filtered by snp-filter v1' \
      --indel-detection-strategy        'samtools r599 filtered by indel-filter v1' \
      --group-samples-for-genotyping-by 'race' \            # some (optional) phenotypic trait, or 'trio' or 'all'
      --phenotype-analysis-strategy     'quantitative' \    # or 'case-control'

    genome propulation-group define 'ASMS-cohort-WUTGI-2011' ASMS1 ASMS2 ASMS3 ASMS4 

    genome model define phenotype-correlation \
        --name                  'ASMS-v1' \
        --subject               'ASMS-cohort-WUTGI-2011' \
        --processing-profile    'September 2011 Quantitative Phenotype Correlation' \

  # case-control

    genome processing-profile create phenotype-correlation \
      --name 'September 2011 Case-Control Population Phenotype Correlation' \
      --alignment-strategy              'bwa 0.5.9 [-q 5] merged by picard 1.29' \
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

EOS
}

sub help_manual_for_create {
    return <<EOS
  Manual page content for this pipeline goes here.
EOS
}

sub create {
    my $class = shift;
    my $bx = $class->define_boolexpr(@_);
    my @errors;
    if ($bx->value_for('alignment_strategy')) {
        #my $strat = Genome::Model::Tools::DetectVariants2::Strategy->get($bx->value_for('alignment_strategy'));
        #push @errors, $strat->__errors__;
        #$strat->delete;
    }
    for my $strategy ('snv','indel','sv','cnv') {
        my $name = $strategy . '_detection_strategy';
        if ($bx->value_for($name)) {
            my $strat = Genome::Model::Tools::DetectVariants2::Strategy->get($bx->value_for($name));
            push @errors, $strat->__errors__;
            $strat->delete;
        }
    }
    if (scalar(@errors)) { 
        die @errors;
    }
    return $class->SUPER::create($bx);
}

sub _initialize_model {
    my ($self,$model) = @_;
    #warn "defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _initialize_build {
    my($self,$build) = @_;
    #warn "definining new build " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _execute_build {
    my ($self,$build) = @_;

    # TODO: remove this and replace with the workflow logic at the bottom when we have one.
    warn "The logic for building this is not yet in place!  Cannot run " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";

    my $pop = $build->model->subject;
    my @inputs = $build->inputs();
    my $dir = $build->data_directory;

    # get the population group, the individuals and samples
    # make a model per sample
    # make a model-group named after the population group (try to override the convergence model's subject population group to this one)
    
    # let the models run and finish
    # if the alignment API updates are ready, drop it in here, but only remove the smaller models when we don't need them anymore
    #  (they duplicate the standard cron-based sample models)

    # run the DV2 API to do variant detection as we do in somatic, but let it take in N BAMs
    # internally it will:
    #  make VCF
    #  when running in cross-BAM mode, and not using a variant caller which does that automatically, dig up wildtype metrics for the VCF

    # dump pedigree data into a file

    # dump clinical data into a file

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
