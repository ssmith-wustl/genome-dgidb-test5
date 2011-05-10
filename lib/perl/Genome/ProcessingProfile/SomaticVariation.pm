package Genome::ProcessingProfile::SomaticVariation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticVariation{
    is => 'Genome::ProcessingProfile',
    doc => "Comprehensive novel somatic variation detection, filtering, novelty determination, and tiering.",
    has_param => [
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
        tiering_version => {
            is => "Text",
            is_many => 0,
            is_optional => 1,
            doc => "Version of tiering bed files to grab from the associated annotation build",
        },
    ],
};

sub help_synopsis_for_create {
    my $self = shift;
    return <<"EOS"
  Complete Examples:

    genome processing-profile create somatic-variation \
      --name 'unfiltered sniper with breakdancer' \
      --snv-detection-strategy 'sniper 0.7.3 [ -q 1 -Q 15 ] intersect samtools r599' \
      --indel-detection-strategy   '(sniper 0.7.3 [-q 1 -Q 15] filtered by library-support v1) union (samtools r599  intersect pindel 0.1)' \
      --sv-detection-strategy 'breakdancer 2010_06_24  filtered by tigra-assembly v1'

    genome processing-profile create somatic-variation \
      --name 'filtered sniper with breakdancer' \
      --snv-detection-strategy '(sniper 0.7.3 [-q 1 -Q 15] filtered by loh v1, somatic-score-mapping-quality v1 [-min_somatic_quality 40 -min_mapping_quality 40]) intersect samtools r599'  \
      --indel-detection-strategy 'sniper 0.7.3 [-q 1 -Q 15] filtered by library-support v1' \
      --sv-detection-strategy 'breakdancer 2010_06_24 filtered by tigra-assembly v1'
  
  Example Strategies usable for SNVs, indels, SVs, or combinations:
  
    'sniper 0.7.3 [-q 1 -Q 15]'
    # Detect with sniper version 0.7.3 with the parameters "-q 1 -Q 15".
    # works for SNVs, indels   

    'sniper 0.7.3 [-q 1 -Q 15] filtered by loh v1 '
    # Detect snvs or indels with sniper version 0.7.3 with the listed parameters and filter the results by running the "loh" filter version "v1".

    'sniper 0.7.3 [-q 1 -Q 15] filtered by loh v1, somatic-score-mapping-quality v1 [-min_somatic_quality 40:-min_mapping_quality 40] intersect samtools r599'  
    # Detect snvs and/or indels with the above as follows:
    # 1) Run sniper version 0.7.3 with parameters
    # 2) Filter the results by running the loh filter version v1
    # 3) Further filter results by running the somatic-score-mapping-quality filter version v1 with parameters.
    # 4) Run samtools version r599 (or steal previous results) 
    # 5) Intersect 3 & 4 
    
    'sniper 0.7.3 [-q 1 -Q 15] union (samtools r599  intersect pindel v1)'
    # Detect indels with: 
    # 1) Run sniper version 0.7.3 with the listed parameters. 
    # 2) Run samtools version r599 
    # 3) Run pindel version v1
    # 4) Intersect 2 and 3
    # 5) Union 1 and 4.
EOS
}

sub help_detail_for_create {
    return <<EOS
  For a detailed explanation of how to writing a variant detection strategy, see: 
    perldoc Genome::Model::Tools::DetectVariants2::Strategy;
EOS
}

sub help_manual_for_create {
    return <<EOS
  
  EXAMPLES
    
    Strategies usable for SNVs, indels, SVs, or combinations:
  
    'sniper 0.7.3 [-q 1 -Q 15]'
    # Detect with sniper version 0.7.3 with the parameters "-q 1 -Q 15".
    # works for SNVs, indels   

    'sniper 0.7.3 [ -q 1 -Q 15 ] filtered by loh v1 '
    # Detect snvs or indels with sniper version 0.7.3 with the listed parameters and filter the results by running the "loh" filter version "v1".

    'sniper 0.7.3 [ -q 1 -Q 15 ] filtered by loh v1 , somatic-score-mapping-quality v1 [-min_somatic_quality 40:-min_mapping_quality 40] intersect samtools r599'  
    # Detect snvs and/or indels with the above as follows:
    # 1) Run sniper version 0.7.3 with parameters
    # 2) Filter the results by running the loh filter version v1, i
    # 3) Further filter results and then the somatic-score-mapping-quality filter version v1 with parameters.
    # 4) Run samtools version r599 (or steal previous results) 
    # 5) Intersect 3 & 4 
    
    'sniper 0.7.3 [ -q 1 -Q 15 ] union (samtools r599  intersect pindel v1 )'
    # Detect indels with: 
    # 1) Run sniper version 0.7.3 with the listed parameters. 
    # 2) Run samtools version r599 
    # 3) Run pindel version v1
    # 4) Intersect 2 and 3
    # 5) Union 1 and 4.

    'sniper 0.7.3 [ -q 1 -Q 15 ]' 
    # Detect snvs or indels or both with sniper version 0.7.3 with the listed parameters. 
    # This expression can be set as an snv detection strategy or an indel detection strategy, 
    # and if both are set to the same value sniper will run just once to do both.
    
    'breakdancer 2010_06_24 ' 
    # Detect structural variation with breakdancer version 2010_06_24.

    'sniper 0.7.3 [ -q 1 -Q 15 ] intersect samtools r599 '
    # Detect snvs: Intersect the results of sniper version 0.7.3 with parameters and samtools version r599.
    
    'sniper 0.7.3 [ -q 1 -Q 15 ] filtered by library-support v1 ' 
    # Detect indels using sniper version 0.7.3 with parameters and filter the results with the library-support filter version v1
    
    'breakdancer 2010_06_24  filtered by tigra-assembly v1 '
    # Detect structural variations using breakdancer version 2010_06_24 and filter the results by applying the tigra-assembly filter version v1

    'sniper 0.7.3 [ -q 1 -Q 15 ] filtered by library-support v1 ' 
    # Detect indels using sniper version 0.7.3 with parameters and filter the results with the library-support filter version v1
    
    'breakdancer 2010_06_24  filtered by tigra-assembly v1 '
    # Detect structural variations using breakdancer version 2010_06_24 and filter the results by applying the tigra-assembly filter version v1

  EXPLANATION

    A strategy consists of the following:
    detector-name version [ params ] filtered by filter-name version [ params ],filter-name version [ params ] ...

    * Detector-name is the name of the variant detector as it follows "gmt detect-variants2". For example, "sniper" would reference the tool located at "gmt detect-variants2 sniper".

    * In the same way, filter-name is the name of the filter as it follows "gmt detect-variants2 filter". For example, "loh" would reference the tool located at gmt detect-variants2 filter loh".

    * Version is a version number that pertains to that detector or filter specifically. For sniper this might be "0.7.3". For samtools this might be "r599".
        Many filters are not currently versioned, but may be in the future. In these cases "v1" should be used to denote version 1.

    * The parameter list is a list of all parameters to be passed to the detector or filter and will be specific to that tool. It is passed as a single string and is optional.

    * Filtered by may contain any number of complete filter specifications (separated by commas), including 0. Each filter must be a complete list of name, version, and an optional param list.

    --- Unions and intersections ---

    * Variant detectors can be intersected or unioned with each other to create variant lists which utilize more than one variant detector. In either case, all variant detectors will be run individually and then processed together.
    * An intersection will run both detectors and then produce a final list of variants that represents where both detectors agree on both the position and the call.
    * A union will run both detectors and then produce a final list of variants that represents every call that both the detectors made, regardless of agreement.
    * Parenthesis may also be utilized around pairs of detectors to specify logical order of operation.

    --- Examples of union and intersection --- 
    --snv-detection-strategy 'sniper 0.7.3 [-q 1 -Q 15] intersect samtools r599
    This represents the desire to run version 0.7.3 of sniper with the above parameter list and version r599 of samtools with no parameters and intersect the results. 
    Both detectors will be run and the final variant list will represent all variants which were called by both detectors.

    --snv-detection-strategy 'sniper 0.7.3 [-q 1 -Q 15] union (samtools r599 intersect pindel v1)
    This represents the desire to run version 0.7.3 of sniper with the above parameters, version r599 of samtools with no parameters, and version v1 of pindel with no parameters.
    Due to the parenthesis, the results of pindel and samtools will first be intersected and then that result will be unioned with the variant calls from sniper.
    In plain language, the resulting set will be any variants that either a) sniper called or b) pindel and samtools both called and agreed on.

EOS
}

sub create {
    my $class = shift;
    my $bx = $class->define_boolexpr(@_);
    my @errors;
    if ($bx->value_for('snv_detection_strategy')) {
        my $snv_strat = Genome::Model::Tools::DetectVariants2::Strategy->get($bx->value_for('snv_detection_strategy'));
        push @errors, $snv_strat->__errors__;
        $snv_strat->delete;
    }
    if ($bx->value_for('sv_detection_strategy')) {
        my $sv_strat = Genome::Model::Tools::DetectVariants2::Strategy->get($bx->value_for('sv_detection_strategy'));
        push @errors, $sv_strat->__errors__;
        $sv_strat->delete;
    }
    if ($bx->value_for('indel_detection_strategy')) {
        my $indel_strat = Genome::Model::Tools::DetectVariants2::Strategy->get($bx->value_for('indel_detection_strategy'));
        push @errors, $indel_strat->__errors__;
        $indel_strat->delete;
    }
    if (scalar(@errors)) { 
        die @errors;
    }

    return $class->SUPER::create($bx);
}

sub _initialize_build {
    my($self,$build) = @_;
    $DB::single=1;
    return 1;
}

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

    # Get the snp file from the tumor and normal models
    my $tumor_snp_file = $tumor_build->snv_file;
    unless (-e $tumor_snp_file) {
        $self->error_message("Tumor snp file $tumor_snp_file does not exist!");
        die $self->error_message;
    }
    my $normal_snp_file = $normal_build->snv_file;
    unless (-e $normal_snp_file) {
        $self->error_message("Normal snp file $normal_snp_file does not exist!");
        die $self->error_message;
    }

    push @inputs, build_id => $build->id;

    return @inputs;
}

1;
