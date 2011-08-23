package Genome::ProcessingProfile::PhenotypeCorrelation;

use strict;
use warnings;
use above "Genome";
use Test::More skip_all => "under development";
#use Test::More tests => 1;

use Genome::ProcessingProfile::PhenotypeCorrelation;

my $p = Genome::ProcessingProfile::PhenotypeCorrelation->create(
    name                     => 'September 2011 Mixed-Race Genotyping and Phenotype Correlation',
    alignment_strategy       => 'bwa 0.5.9 [_q 5] merged by picard 1.29',
    snv_detection_strategy   => 'samtools r599 filtered by snp_filter v1',
    indel_detection_strategy => 'samtools r599 filtered by indel_filter v1',
    sv_detection_strategy    => undef, 
    cnv_detection_strategy   => undef,
    genotype_in_groups_by    => 'sample.patient.test_nomenclature.race',
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


