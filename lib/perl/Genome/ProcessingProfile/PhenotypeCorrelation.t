package Genome::ProcessingProfile::PhenotypeCorrelation;

use strict;
use warnings;
use above "Genome";
use Test::More tests => 1;

use Genome::ProcessingProfile::PhenotypeCorrelation;

# these are the ASMS model groups
my @g = Genome::ModelGroup->get([13391, 13392, 13411]);


# create a quantitative processing profile
my $p = Genome::ProcessingProfile::PhenotypeCorrelation->create(
    id                              => -10001,
    name                            => 'September 2011 Quantitative Population Phenotype Correlation',
    alignment_strategy              => 'bwa 0.5.9 [-q 5] merged by picard 1.29',
    snv_detection_strategy          => 'samtools r599 filtered by snp-filter v1',
    indel_detection_strategy        => 'samtools r599 filtered by indel-filter v1',
    sv_detection_strategy           => undef, 
    cnv_detection_strategy          => undef,
    group_samples_for_genotyping_by => 'test_nomenclature.race',
    phenotype_analysis_strategy     => 'quantitative',
);

ok($p, "created a processing profile");



__END__
sub help_synopsis_for_create {
    my $self = shift;
    return <<"EOS"

    genome processing-profile create phenotype-correlation \
      --name 'September 2011 Trio Genotyping and Phenotype Correlation' \
      --alignment-strategy          'bwa 0.5.9 [-q 5] merged by picard 1.29' \
      --snv-detection-strategy      'samtools r599 filtered by snp-filter v1' \
      --indel-detection-strategy    'samtools r599 filtered by indel-filter v1' \
      --genotype-in-groups-by       'sample.patient.some_nomenclature.trio' # or race, or family, or whatever 

    genome propulation-group define 'ASMS-cohort-WUTGI-2011' ASMS1 ASMS2 ASMS3 ASMS4 

    genome model define phenotype-correlation \
        --name                  'ASMS v1' 
        --subject               'ASMS-cohort-WUTGI-2011'
        --processing-profile    'September 2011 Trio Genotyping and Phenotype Correlation'       
        --identify-cases-by     'sample.patient.some_nomenclature.has_asms = 1'
        --identify-controls-by  'sample.patient.some_nomenclature.has_asms = 0'

    # ASMS is not really trios, but just as an example...

EOS
}


