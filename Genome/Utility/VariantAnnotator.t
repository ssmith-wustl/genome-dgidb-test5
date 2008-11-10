#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Data::Dumper;
require Genome::DB::Schema;
use Test::More skip_all => 'bugs introduced in refactoring, fixing...';
use Storable;

use_ok('Genome::Utility::VariantAnnotator');

my $schema = Genome::DB::Schema->connect_to_dwrac;
ok($schema, "Connect to dw");
die unless $schema;

my $file = "/gsc/var/cache/testsuite/data/Genome-Utility-VariantAnnotator/variants.stor";
ok(-s $file, "Storable file ($file) has data!");
my @variants = @{retrieve($file)};
ok(@variants, "Got data from storable file");

my $chromosome = _get_chromosome($variants[0]->{chromosome});
my ($from, $to) = _get_range(@variants);
my $annotator = _get_annotator($chromosome, $from, $to);

for (my $i = 0; $i <= $#variants; $i++) {
    my $variant = $variants[$i];
    unless ( $variant->{chromosome} eq $chromosome->chromosome_name ) {
        $chromosome = _get_chromosome($variant->{chromosome});
        my ($from, $to) = _get_range(@variants[$i..$#variants]);
        $annotator = _get_annotator($chromosome, $from, $to);
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
}

exit;

###

sub _get_range {
    my (@variants) = @_;

    my $chromosome_name = $variants[0]->{chromosome};
    my $from = $variants[0]->{start};
    my $i = 0;
    for my $variant ( @variants ) {
        last if $variant->{chromosome} ne $chromosome_name;
        $i++;
    }

    return ($from, $variants[$i - 1]->{stop});
}

sub _get_chromosome {
    my ($chromosome_name) = @_;

    my $chromosome = $schema->resultset('Chromosome')->find(
        { chromosome_name => $chromosome_name },
    );
    ok($chromosome, "Got chromosome ($chromosome_name)");
    die unless $chromosome;

    return $chromosome;
}

sub _get_annotator {
    my ($chromosome, $from, $to) = @_;

    my $annotator = Genome::Utility::VariantAnnotator->new(
        transcript_window => $chromosome->transcript_window(range => 0),
        #transcript_window => $chromosome->transcript_window(from => $from, to => $to, range => 0),
    );
    ok($annotator, sprintf('Got annotator for chromosome (%s)', $chromosome->chromosome_name));
    die unless $annotator;

    return $annotator;
}

#$HeadURL$
#$Id$
