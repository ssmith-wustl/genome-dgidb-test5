package Genome::Data::Adaptor::Snpeffgatk;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant;
use Genome::Data::Adaptor;
use base 'Genome::Data::Adaptor';

#TODO: This is very basic VCF parsing focused only on snpeff output.  We may want to put some time into
#making sure we cover the whole spec.  Also, this is for version 4.1

sub parse_next_from_file {
    my $self = shift;
    my $fh = $self->_get_fh;
    my $variant;
    if (my $line = $fh->getline) {
        chomp $line;
        my @fields = split(/\t/, $line);
        my @alt_alleles = split(/,/, $fields[4]);
        my @info_fields = split(/;/, $fields[7]);

        my @transcript_annotations;
        my %effect;
        foreach my $info_field (@info_fields) {
            my ($key, $value) = split(/=/,$info_field);
            if ($key eq "SNPEFF_EFFECT") {
                $effect{'effect'} = $value;
            }
            elsif ($key eq "SNPEFF_IMPACT") {
                $effect{'effect_impact'} = $value;
            }
            elsif ($key eq "SNPEFF_CODON_CHANGE") {
                $effect{'codon_change'} = $value;
            }
            elsif ($key eq "SNPEFF_AMINO_ACID_CHANGE") {
                $effect{'amino_acid_change'} = $value;
            }
            elsif ($key eq "SNPEFF_GENE_NAME") {
                $effect{'gene_name'} = $value;
            }
            elsif ($key eq "SNPEFF_GENE_BIOTYPE") {
                $effect{'gene_biotype'} = $value;
            }
            elsif ($key eq "SNPEFF_TRANSCRIPT_ID") {
                $effect{'transcript'} = $value;
            }
            elsif ($key eq "SNPEFF_EXON_ID") {
                $effect{'exon'} = $value;
            }
        }
        if (defined $effect{'effect'}) {
            foreach my $key (keys(%effect)) {
                if (! defined $effect{$key}) {
                    $effect{$key} = "";
                }
            }
            push(@transcript_annotations, \%effect);
        }

        my %annotations;
        $annotations{"id"} = $fields[2];
        $annotations{"qual"} = $fields[5];

        my $type;
        my $start;
        my $end;
        my $ref_allele;
        my @new_alt_alleles;
        foreach my $alt_allele ($alt_alleles[0]) {
            my $new_type;
            my $ref_length = length $fields[3];
            my $alt_length = length $alt_allele;

            if ($ref_length < $alt_length) { #insertion
                $ref_allele = "-";
                $alt_allele = substr($alt_allele, $ref_length);
                $ref_length = 0;
                $alt_length = length $alt_allele;
                $new_type = "INS";
                $start = $fields[1];
                $end = $start+1;
            }
            elsif ($ref_length == $alt_length and $alt_length == 1) { #snv
                $new_type = "SNP";
                $start = $fields[1];
                $end = $start;
                $ref_allele = $fields[3];
            }
            elsif ($ref_length == $alt_length and $alt_length >= 2) { #dnp or mnp
                $ref_allele = substr($fields[3], 1);
                $alt_allele = substr($alt_allele, 1);
                $ref_length = length $ref_allele;
                $alt_length = length $alt_allele;
                if ($alt_length == 2) {
                    $new_type = "DNP";
                    $start = $fields[1]-2;
                    $end = $start + $alt_length;
                }
                else {
                    $new_type = "MNP";
                    $start = $fields[1]-2;
                    $end = $start + 1;
                }
            }
            elsif ($ref_length > $alt_length) { #deletion
                $ref_allele = substr($fields[3], $alt_length);
                $alt_allele = "-";
                $new_type = "DEL";
                $start = $fields[1]+1;
                $ref_length = length $ref_allele;
                $alt_length = 0;
                $end = $start + $ref_length-1;
            }
            else {
                die("unrecognized variant type");
            }
            push @new_alt_alleles, $alt_allele;


            if (! defined $type) {
                $type = $new_type;
            }
            elsif ($new_type ne $type) {
               $type = "SKIP"; 
            }
        }

        $variant = Genome::Data::Variant::AnnotatedVariant->create(
            chrom => $fields[0],
            start => $start,
            end => $end,
            reference_allele => $ref_allele,
            alt_alleles => [$new_alt_alleles[0]],
            type => $type, 
            annotations => \%annotations,
            transcript_annotations => \@transcript_annotations,
        );
    }
    return $variant;
}

sub write_to_file {

}

sub produces {
    return 'Genome::Data::AnnotatedVariant::Snpeff';
}

1;

