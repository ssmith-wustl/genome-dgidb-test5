#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Data::Dumper;
require Genome::DB::Schema;
use Test::More 'no_plan';
use Storable;

use_ok('Genome::Utility::VariantAnnotator');

my $schema = Genome::DB::Schema->connect_to_dwrac;
ok($schema, "Connect to dw");
die unless $schema;

my $file = "/gsc/var/cache/testsuite/data/Genome-Utility-VariantAnnotator/variants.stor";
ok(-s $file, "Storable file ($file) has data!");
my @variants = @{retrieve($file)};
ok(@variants, "Got data from storable file");

my $chromosome = $variants[0]->{chromosome};
my $window = _get_window($chromosome);
my $annotator = _get_annotator($window);
ok($annotator, "got annotator for chromosome $chromosome");

for (my $i = 0; $i <= $#variants; $i++) {
    my $variant = $variants[$i];
    unless ( $variant->{chromosome} eq $chromosome ) { #uninit val
        $chromosome = $variant->{chromosome};
        $window = _get_window($chromosome);
        $annotator = _get_annotator($window);
        ok($annotator, "got annotator from next chromosome $chromosome");
    }

    my @annotations = $annotator->prioritized_transcripts(
        variant => $variant->{variant},
        reference => $variant->{reference},
        chromosome_name => $variant->{chromosome},
        start => $variant->{start},
        stop => $variant->{stop},
        type => $variant->{variation_type},
    );
    ok(@annotations, sprintf("Got annotations for chrom (%s) pos (%s)", $variant->{chromosome}, $variant->{start}));

    # Get the annotation that meathcesthe gene we got
    my ($annotation)  = grep { $variant->{gene} eq $_->{gene_name} } @annotations;
    ok($annotation, sprintf('Got annotation for gene (%s)', $variant->{gene}));
    #print Dumper([$variant, $lowest_priority_annotation,\@annotations]);
    
    #Verify that these match
    is($variant->{transcript}, $annotation->{transcript_name}, 'Transcript matches');
    is(lc($variant->{called_classification}), lc($annotation->{trv_type}), 'Classification matches');
    # FIXME this is not passing right now, why? Find out, uncomment, and commit
    #is($variant->{protein_string_short}, $annotation->{amino_acid_change}, 'amino acid changes match');
}

exit;

###

sub _get_range {
    my (@variants) = @_;

    my $chromosome_name = $variants[0]->{chromosome};
    my $from = $variants[0]->{start};
    my $i = 0;
    for my $variant ( @variants ) {
        last if $variant->{chromosome} ne $chromosome_name; #uninit_val
        $i++;
    }

    return ($from, $variants[$i - 1]->{stop});
}

sub _get_window{
    my $chromosome = shift;
    my $iter = Genome::Transcript->create_iterator(where => [ chrom_name => $chromosome] );
    my $window =  Genome::DB::Window::Transcript->create ( iterator => $iter, range => 50000);
    return $window
}


sub _get_annotator {
    my ($transcript_window) = @_;

    my $annotator = Genome::Utility::VariantAnnotator->create(
        transcript_window => $transcript_window,
        benchmark => 1,
    );
    ok($annotator, sprintf('Got annotator for chromosome (%s)', $chromosome));
    die unless $annotator;

    return $annotator;
}

#$HeadURL$
#$Id$
