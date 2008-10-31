#!/gsc/bin/perl

use strict;
use warnings;

#use Genome;
#use above "Genome";

require Genome::DB::Schema;
use Test::More 'no_plan';
use Storable;

#use_ok('Genome::Utility::VariantAnnotator');

my $schema = Genome::DB::Schema->connect_to_dwrac;
ok($schema, "Connect to dw");
die unless $schema;

my $file = "/gsc/var/cache/testsuite/data/Genome-Utility-VariantAnnotator/variants.stor";
ok(-s $file, "Storable file ($file) has data!");
my $variants = retrieve($file);
ok($variants, "Got data from storable file");

my $chromosome = _get_chromosome($variants->[0]->{chromosome});
my $annotator = _get_annotator_for_chromosome($chromosome);

for my $variant ( @$variants ) {
    unless ( $variant->{chromosome} eq $chromosome->name ) {
        $chromosome = _get_chromosome($variants->[0]->{chromosome});
        $annotator = _get_annotator_for_chromosome($chromosome);
    }

    my @annotations = $annotator->prioritized_transcripts_for_snp(
        variant => $variant->{variant},
        reference => $variant->{reference},
        chromosome_name => $variant->{chromosome},
        start => $variant->{start},
        stop => $variant->{stop},
        type => $variant->{variation_type},
    );

    # Print the annotation with the best (lowest) priority
    my $lowest_priority_annotation = $annotations[0];
    for my $annotation ( @annotations ) {
        if ( $annotation->{priority} < $lowest_priority_annotation->{priority} ) {
            $lowest_priority_annotation = $annotation;
        }
    }
    print Dumper([$variant, $lowest_priority_annotation]);
    last;

    $lowest_priority_annotation->{variations} = join (",",keys %{$lowest_priority_annotation->{variations}});

    #ok();
    #is_deeply();
}

$schema->disconnect;

exit;

###

sub _get_chromosome {
    my ($chromosome_name) = @_;

    my $chromosome = $schema->resultset('Chromosome')->find(
        { chromosome_name => $chromosome_name },
    );
    ok($chromosome, "Got chromosome ($chromosome_name)");
    die unless $chromosome;

    return $chromosome
}

sub _get_annotator {
    my ($chromosome) = @_;

    my $annotator = Genome::Utility::VaraintAnnotator->new(
        transcript_window => $chromosome->transcript_window(range => 50000),
        variation_window => $chromosome->variation_window(range => 0),
    );
    ok($annotator, sprintf('Got annotator for chromosome (%s)', $chromosome->_name));
    die unless $annotator;

    return $annotator;
}

#$HeadURL$
#$Id$
