# review jlolofie
# cant find this being used anywhere... delete?
#:adukes I wrote this with the idea of providing a non-list based entry point to the annotator, specifically for providing an object interface to the annotator for small sets of variants.  This hasn't happened, and I doubt it will anytime soon, so feel free to get rid of it

package Genome::Variant;

use strict;
use warnings;
use Genome;

class Genome::Variant{
    is => 'UR::Object',
    has =>[
    variant_sequence => {
        is => 'String',
        doc => 'variant base(s), null for variant type deletion',
        is_optional => 1,
    },
    reference_sequence =>{
        is => 'String',
        doc => 'reference base(s), null for variant type insertion',
        is_optional => 1,
    },
    chromosome => {
        is => 'String',
        doc => 'chromosome name',
    },
    start => {
        is => 'Number',
        doc => 'start position of variation',
    },
    stop => {
        is => 'Number',
        doc => 'stop position of variation',
    },
    type => {
        is => 'String',
        doc => 'type of variant (SNP, DNP, INS, DEL)',
    },
    ],
};

sub create{
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    
    my $type = $self->type;
    my $start = $self->start;
    my $stop = $self->stop;
    my $ref = $self->reference_sequence;
    my $var = $self->variant_sequence;
    if ($type eq 'SNP'){
        unless ($start == $stop){
            $self->error_message("start($start) and stop($stop) positions do not match for variant $type");
            die;
        }
        unless ($ref and $var){
            $self->error_message("Reference(".($ref?$ref:'NULL').") and Variant(".($var?$var:'NULL').") must both be defined for variant type $type");
            die;
        }
        unless (length($var) == 1 and length($ref) == 1){
            $self->error_message("Reference($ref) and Variant($var) must both be length 1 for variant type $type");
        }
    }elsif($type eq 'DNP'){
        unless ($start == $stop+1){
            $self->error_message("start($start) and stop($stop) positions are not consecutive for variant $type");
            die;
        }
        unless ($ref and $var){
            $self->error_message("Reference(".($ref?$ref:'NULL').") and Variant(".($var?$var:'NULL').") must both be defined for variant type $type");
            die;
        }
        unless (length($var) == 2 and length($ref) == 2){
            $self->error_message("Reference($ref) and Variant($var) must both be length 2 for variant type $type");
        }
    }elsif($type eq 'INS'){
        unless ($start <= $stop){
            $self->error_message("Start($start) must be less than Stop($stop)");
        }
        if ($ref){
            $self->error_message("Reference defined for variant type $type");
            die;
        }
        unless ($var){
            $self->error_message("Variant must be defined for variant type $type");
            die;
        }
    }elsif($type eq 'DEL'){
        unless ($start <= $stop){
            $self->error_message("Start($start) must be less than Stop($stop)");
        }
        if ($var){
            $self->error_message("Variant defined for variant type $type");
            die;
        }
        unless ($ref){
            $self->error_message("Reference must be defined for variant type $type");
            die;
        }
        unless (length($ref) == $stop-$start+1){
            $self->error_message("length of deletion(Reference $ref) must match number of bases replaced from $start to $stop");
        }
    }else{
        $self->error_message("Type $type must be SNP, DNP, INS, or DEL");
        die;
    }
}
=pod

=head1 NAME

Genome::Variant

=head1 SYNOPSIS

my $variant = genome::variant->create(
    type => 'snp',
    chromosome => 1,
    start => 115,
    stop => 115,
    reference_sequence => 'A',
    variant_sequence => 'T',
);

my $variant = Genome::Variant->create(
    type => 'DNP',
    chromosome => 1,
    start => 115,
    stop => 116,
    reference_sequence => 'AC',
    variant_sequence => 'TG',
);

my $variant = Genome::Variant->create(
    type => 'DEL',
    chromosome => 1,
    start => 120,
    stop => 125,
    reference_sequence => 'ACGTAC',
);

my $variant = Genome::Variant->create(
    type => 'INS',
    chromosome => 1,
    start => 130,
    stop => 130,
    variant_sequence => 'ACGT',
);

=head1 DESCRIPTION

This class represents a Variant for use in annotation.  There are four supported variant types:

=over 1

=item SNP

Single Nucleotide Polymorphism is a single base variation from the reference. Start and stop must be equal.  Variant and reference must be length 1.

=item DNP

Di-Nucleotide Polymorphism is a two base substitution to the reference. Start and stop must be adjacent.  Variant and reference must be length 2.

=item DEL

Deletion is a deleted portion of the reference sequence. Variant is undefined. Start and stop are the first and last bases of the deletion, respectively.  Length of reference must match start - stop + 1.

=item INS

Insertion is an inserted sequence into the reference sequence. Reference is undefined. Start and stop should be equal. 

=back 1

=head 1 PROPERTIES

=item variant_sequence - variant base(s), null for variant type deletion

=item reference_sequence - reference base(s), null for variant type insertion

=item chromosome - chromosome name
    
=item start - start position of variation

=item stop - stop position of variation

=item type - type of variant (SNP, DNP, INS, DEL)

=cut

1;

