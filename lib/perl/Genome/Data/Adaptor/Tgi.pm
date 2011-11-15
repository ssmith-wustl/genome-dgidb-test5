package Genome::Data::Adaptor::Tgi;

use strict;
use warnings;
use Genome::Data::Variant::AnnotatedVariant;
use base 'Genome::Data::Adaptor';

sub current_var {
    my ($self, $_current_var) = @_;
    if (defined $_current_var) {
        $self->{_current_var} = $_current_var;
    }
    my $var = $self->{_current_var};
    return $var;
}

sub produces {
    return 'Genome::Data::Variant::AnnotatedVariant::Tgi';
}

#Assumes all lines describing annotations of the same variant are adjacent in the file.
sub parse_next_from_file {
    my $self = shift;
    my $fh = $self->_get_fh;


    my $line = $fh->getline;
    my ($chrom, $start, $stop, $reference, $variant, $type, $gene_name,
        $transcript_name, $transcript_species, $transcript_source, $transcript_version,
        $strand, $transcript_status, $trv_type, $c_position, $amino_acid_change,
        $ucsc_cons, $domain, $all_domains, $deletion_substructures, $transcript_error);

    if ($line) {
        chomp $line;
        ($chrom, $start, $stop, $reference, $variant, $type, $gene_name,
            $transcript_name, $transcript_species, $transcript_source, $transcript_version,
            $strand, $transcript_status, $trv_type, $c_position, $amino_acid_change,
            $ucsc_cons, $domain, $all_domains, $deletion_substructures, $transcript_error) = split(/\t/, $line);

        if (!defined $self->current_var) {
            $self->current_var({chrom => $chrom,
                                start => $start,
                                end => $stop,
                                reference_allele => $reference,
                                alt_allele => $variant,
                                type => $type});
            $self->_push_annotation_to_cache($line);
            $line = $fh->getline;
            if ($line) {
                chomp $line;
                ($chrom, $start, $stop, $reference, $variant, $type, $gene_name,
                    $transcript_name, $transcript_species, $transcript_source, $transcript_version,
                    $strand, $transcript_status, $trv_type, $c_position, $amino_acid_change,
                    $ucsc_cons, $domain, $all_domains, $deletion_substructures, $transcript_error) = split(/\t/, $line);
            }
        }

        while ($chrom eq $self->current_var->{"chrom"} && $start eq $self->current_var->{"start"} &&
            $stop eq $self->current_var->{"end"} && $reference eq $self->current_var->{"reference_allele"} &&
            $variant eq $self->current_var->{"alt_allele"}) {

            if (!$line) {
                last;
            }
            $self->_push_annotation_to_cache($line);
            $line = $fh->getline;

            if ($line) {
                chomp $line;
                ($chrom, $start, $stop, $reference, $variant, $type, $gene_name,
                $transcript_name, $transcript_species, $transcript_source, $transcript_version,
                $strand, $transcript_status, $trv_type, $c_position, $amino_acid_change,
                $ucsc_cons, $domain, $all_domains, $deletion_substructures, $transcript_error) = split(/\t/, $line);
            }
        }
    }

    my @cached_annotations = $self->_pop_annotations_from_cache;

    my $annotated_variant;
    if (@cached_annotations) {
        $annotated_variant = Genome::Data::Variant::AnnotatedVariant->create(
            chrom => $self->current_var->{"chrom"},
            start => $self->current_var->{"start"},
            end => $self->current_var->{"end"},
            reference_allele => $self->current_var->{"reference_allele"},
            alt_alleles => [$self->current_var->{"alt_allele"}],
            type => $self->current_var->{"type"},
            transcript_annotations => \@cached_annotations,
        );
    }

    if ($line) {

        $self->current_var({chrom => $chrom,
                                 start => $start,
                                 end => $stop,
                                 reference_allele => $reference,
                                 alt_allele => $variant,
                                 type => $type});
        $self->_push_annotation_to_cache($line);
    }

    return $annotated_variant;
}

sub write_to_file {
    my ($self, @variants) = @_;
    my $fh = $self->_get_fh;
    for my $variant (@variants) {
        #TODO: decide what kind of error checking we want to do.
        #What fields are required to write?
        #If a field is not present, what character do we insert?
        #What fields do we try to calculate?

        my $alt_alleles_out = join(",", @{$variant->alt_alleles});
        my $common = join("\t", $variant->chrom, $variant->start, $variant->end,
                                $variant->reference_allele, $alt_alleles_out, $variant->type);
        foreach my $ta (@{$variant->transcript_annotations}) {
            my $transcript = join("\t", $ta->{'gene_name'}, $ta->{'transcript_name'},
                                  $ta->{'transcript_species'}, $ta->{'transcript_source'}, $ta->{'transcript_version'},
                                  $ta->{'strand'}, $ta->{'transcript_status'}, $ta->{'trv_type'}, $ta->{'c_position'},
                                  $ta->{'amino_acid_change'}, $ta->{'ucsc_cons'}, $ta->{'domain'}, $ta->{'all_domains'},
                                  $ta->{'deletion_substructures'}, $ta->{'transcript_error'});
            $fh->print(join("\t", $common, $transcript));
            $fh->print("\n");
        }
    }
}

sub _pop_annotations_from_cache {
    my $self = shift;
    my @lines;
    if ($self->{_cached_lines}) {
        @lines = @{$self->{_cached_lines}};
    }
    delete $self->{_cached_lines};
    return @lines;
}

sub _push_annotation_to_cache {
    my ($self, $line) = @_;
    my ($chrom, $start, $stop, $reference, $variant, $type, $gene_name,
        $transcript_name, $transcript_species, $transcript_source, $transcript_version,
        $strand, $transcript_status, $trv_type, $c_position, $amino_acid_change,
        $ucsc_cons, $domain, $all_domains, $deletion_substructures, $transcript_error) = split(/\t/, $line);
    my %annotation = (
        gene_name => $gene_name,
        transcript_name => $transcript_name,
        transcript_species => $transcript_species,
        transcript_source => $transcript_source,
        transcript_version => $transcript_version,
        strand => $strand,
        transcript_status => $transcript_status,
        trv_type => $trv_type,
        c_position => $c_position,
        amino_acid_change => $amino_acid_change,
        ucsc_cons => $ucsc_cons,
        domain => $domain,
        all_domains => $all_domains,
        deletion_substructures => $deletion_substructures,
        transcript_error => $transcript_error,
    );
    push (@{$self->{_cached_lines}}, \%annotation);
    return 1;
}

1;

