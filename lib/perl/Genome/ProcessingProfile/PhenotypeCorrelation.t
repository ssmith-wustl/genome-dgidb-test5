package Genome::ProcessingProfile::PhenotypeCorrelation;

use strict;
use warnings;
use above "Genome";
use Test::More tests => 4;

use Genome::ProcessingProfile::PhenotypeCorrelation;


my $asms_cohort = Genome::PopulationGroup->get(name => 'ASMS-cohort-TGI-2011');

unless ($asms_cohort) {
    # this is how I made the cohort from Will's 3 model groups...
    # it's slow(er) so I did it and let it commit

    my @groups = Genome::ModelGroup->get([13391, 13392, 13411]);
    is(scalar(@groups), 3, "got 3 members");

    my @samples = map { $_->subjects(-hints => [qw/attributes/]) } @groups;
    ok(scalar(@samples), "got " . scalar(@samples) . " samples");

    my @patients = Genome::Individual->get(id => [ map { $_->source_id } @samples ], -hints => [qw/attributes/]);
    ok(scalar(@patients), "got " . scalar(@patients) . " patients");

    $asms_cohort = Genome::PopulationGroup->create(
        id => -1000,
        name => 'ASMS-cohort-TGI-2011',
        members => \@patients,
    );
    ok($asms_cohort, "created the ASMS cohort");
}

# now we do everything just in memory since we're just experimenting...

my @members = $asms_cohort->members();
is(scalar(@members), 304, "got the expected number of patients");

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
ok($p, "created a processing profile") or diag(Genome::ProcessingProfile::PhenotypeCorrelation->error_message);


my $m = $p->add_model(
    name    => 'ssmith-ASMS-test1',
    subject => $asms_cohort,
);
ok($m, "created a model") or diag(Genome::Model->error_message);


my $b = $m->add_build(
    data_directory => "/tmp/foo"
);
ok($b, "created a build") or diag(Genome::Model->error_message);

__END__

$b->start(
    server_dispatch => 'inline',
    job_dispatch    => 'inline',
);
is($b->status, 'Succeeded', "build succeeded!");

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


    if (0) {
        # some of the LIMS clinical data didn't come across so this lets us query that directly
        #my @a = Genome::Site::WUGC::Sample::Attribute->get(sample_id => [ map { $_->id } @samples ], -order_by => 'sample_id');
        #show_table(\@a, qw/sample_id nomenclature name value/);

        # ...once correctly imported it will be here
        #my @a = Genome::SubjectAttribute->get(subject_id => [ map { $_->id } @samples ], -order_by => 'subject_id');
        #show_table(\@a, qw/nomenclature attribute_label attribute_value/);
    }

sub show_table {
    my $olist = shift;
    my @p = @_;
    unless (@p) {
        my $o = $olist->[0];
        if ($olist->[0]->isa("UR::Object")) {
            @p = grep { $_ !~ /^_/ } map { $_->property_name } $olist->[0]->__meta__->properties;
        }
        else {
            @p = grep { $_ !~ /^_/ } $olist->[0]->get_class_object->property_names;
        }
    }
    for my $o (@$olist) {
        print join("\t", map { chomp($_); $_ } map { $o->$_ } @p),"\n";
    }
}

