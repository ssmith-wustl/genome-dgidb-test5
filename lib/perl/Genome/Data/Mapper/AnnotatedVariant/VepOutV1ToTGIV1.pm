package Genome::Data::Mapper::AnnotatedVariant::VepOutV1ToTGIV1;

use strict;
use warnings;
use Genome::Data::Mapper;
use Genome::Data::Variant::AnnotatedVariant::Vep;
use Genome::Data::Variant::AnnotatedVariant::Tgi;
use base 'Genome::Data::Mapper::AnnotatedVariant';

use constant {
    NO_VALUE => '-',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create("Genome::Data::Variant::AnnotatedVariant::Vep", "Genome::Data::Variant::AnnotatedVariant::Tgi");
}

sub calculate_annotation_field {
    my ($self, $field, $old_annotation) = @_;
    die ("unknown input to calculate_annotation_field");
}

sub calculate_transcript_annotation_field {
    my ($self, $field, $old_ta, $variant) = @_;
    my $ret_val;
    if ($field eq 'gene_name') {
        $ret_val =  $old_ta->{'gene'};
    }
    elsif ($field eq 'transcript_name') {
        $ret_val = $old_ta->{'feature'};
    }
    elsif ($field eq 'transcript_species') {
    }
    elsif ($field eq 'transcript_source') {
    }
    elsif ($field eq 'transcript_version') {
    }
    elsif ($field eq 'strand') {
    }
    elsif ($field eq 'transcript_status') {
    }
    elsif ($field eq 'trv_type') {
        if ($old_ta->{'consequence'} =~ /5PRIME_UTR/) {
            $ret_val = "5_prime_untranslated_region";
        }
        elsif ($old_ta->{'consequence'} =~ /INTRONIC/) {
            $ret_val = "intronic";
        }
        elsif ($old_ta->{'consequence'} =~ /3PRIME_UTR/) {
            $ret_val = "3_prime_untranslated_region";
        }
        elsif ($old_ta->{'consequence'} =~ /SPLICE_SITE/) {
            $ret_val = "splice_site";
        }
        elsif ($old_ta->{'consequence'} =~ /DOWNSTREAM/) {
            $ret_val = "3_prime_flanking_region";
        }
        elsif ($old_ta->{'consequence'} =~ /UPSTREAM/) {
            $ret_val = "5_prime_flanking_region";
        }
        elsif ($old_ta->{'consequence'} =~ /NON_SYNONYMOUS_CODING/) {
            $ret_val = "missense";
        }
        elsif ($old_ta->{'consequence'} =~ /STOP_GAINED/) {
            $ret_val = "nonsense";
        }
        elsif ($old_ta->{'consequence'} =~ /WITHIN_MATURE_miRNA/) {
            $ret_val = "rna";
        }
        elsif ($old_ta->{'consequence'} =~ /SYNONYMOUS_CODING/) {
            $ret_val = "silent";
        }
        elsif ($old_ta->{'consequence'} =~ /STOP_LOST/) {
            $ret_val = "non_stop";
        }
        elsif ($old_ta->{'consequence'} =~ /FRAMESHIFT/) {
            if ($variant->type eq "INS") {
                $ret_val = "frame_shift_ins";
            }
            elsif ($variant->type eq "DEL") {
                $ret_val = "frame_shift_del";
            }
            else {
                $ret_val = "SKIP";
                warn ("frame shift is not insertion or deletion\n");
            }
        }
        else {
            $ret_val = "SKIP";
            warn ("Effect not known ".$old_ta->{'consequence'}."\n");
        }
    }
    elsif ($field eq 'c_position') {
    }
    elsif ($field eq 'amino_acid_change') {
        if (! defined $old_ta->{'amino_acid_change'}) {
            $ret_val = "NULL";
        }
        else {
            $ret_val = $old_ta->{'amino_acid_change'};
        }
    }
    elsif ($field eq 'ucsc_cons') {
    }
    elsif ($field eq 'domain') {
    }
    elsif ($field eq 'all_domains') {
    }
    elsif ($field eq 'deletion_substructures') {
    }
    elsif ($field eq 'transcript_error') {
    }
    else {
        die ("unknown input to calculate_transcript_annotation_field");
    }

    if (! defined $ret_val) {
        $ret_val = NO_VALUE;
    }
    return $ret_val;
}

1;

