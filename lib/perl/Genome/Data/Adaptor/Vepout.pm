package Genome::Data::Adaptor::Vepout;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant;
use Genome::Data::Adaptor;
use base 'Genome::Data::Adaptor';

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
        $effect{"gene"} = $fields[3];
        $effect{"feature"} = $fields[4];
        $effect{"feature_type"} = $fields[5];
        $effect{"consequence"} = $fields[6];
        $effect{"cDNA_position"} = $fields[7];
        $effect{"CDS_position"} = $fields[8];
        $effect{"Protein_position"} = $fields[9];
        $effect{"Amino_acids"} = $fields[10];
        $effect{"Codons"} = $fields[11];
        $effect{"Existing_variation"} = $fields[12];
        if ($fields[13]) {
            my @extras = split(/;/, $fields[13]);
            foreach my $extra (@extras) {
                my ($key, $value) = split(/=/, $extra);
                $effect{$key} = $value;
            }
        }
        push(@transcript_annotations, \%effect);

        my %annotations;

        my $type;
        my $start;
        my $end;

        my ($chrom,$pos) = split(/:/, $fields[1]);
        my ($in_start,$in_end) = split(/-/,$pos);
        my ($in_chrom, $in_pos, $in_alleles) = split(/_/,$fields[0]);
        my ($ref_allele, $alt_allele) = split(/\//,$in_alleles);

        if ($ref_allele eq "-") { #insertion
            $type = "INS";
            $start = $in_start;
            $end = $in_end;
        }
        elsif ($alt_allele eq "-") { #deletion
            $type = "DEL";
            $start = $in_start;
            if ($in_end) {
                $end = $in_end;
            }
            else {
                $end = $start;
            }
        }
        elsif (length($alt_allele) == length($ref_allele) and length($alt_allele) == 1) { #snv
            $type = "SNV";
            $start = $in_start;
            $end = $start;
        }
        elsif (length($alt_allele) == length($ref_allele) and length($alt_allele) == 2) { #DNP
            $type = "DNP";
            $start = $in_start;
            $end = $in_end;
        }
        elsif (length($alt_allele) == length($ref_allele)) { #MNP
            $type = "SKIP";
            $start = $in_start;
            $end = $in_end;
        }
        else {
            die("unrecognized variant type");
        }

        $variant = Genome::Data::Variant::AnnotatedVariant->create(
            chrom => $chrom,
            start => $start,
            end => $end,
            reference_allele => $ref_allele,
            alt_alleles => [$alt_allele],
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
    return 'Genome::Data::AnnotatedVariant::Vep';
}

1;

