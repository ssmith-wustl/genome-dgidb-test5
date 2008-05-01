package Genome::Model::GenotypeProcessor::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use IO::File;

use lib "/gsc/scripts/gsc/medseq/lib";
use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;

class Genome::Model::GenotypeProcessor::Maq {
    has => [
        ref_seq_id => { is => 'Integer', is_optional => 1, doc => 'reference sequence id to operate against' },
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
};

# This part is stolen and refactored from Brian's original G::M::Command::Write::GenotypeSubmission::Maq
# Maybe it should be moved to a Maq-specific tools module at some point?

# This used to be a command-line arg to the submitter.  Looks like it's pretty much
# always 0.  If that's true, then it can be removed.  If it changes, then it should be made an
# attribute of the model
our $QC_CUTOFF = 0;

sub get_mutations {
    my $self = shift;

    my $model = Genome::Model->get(id => $self->model_id);
$DB::single=1;
  
    my $variations = {};

    my $snp_resource_name = sprintf("snips%s.filtered",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");
    my $pileup_resource_name = sprintf("pileup%s",
                                    defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                              : "");
    my $snip_output_file = sprintf("%s/identified_variations/%s", $model->data_directory,$snp_resource_name);
    my $pileup_output_file = sprintf("%s/identified_variations/%s", $model->data_directory,$pileup_resource_name);

    foreach my $file ( $snip_output_file, $pileup_output_file) {
        unless (-f $file and -s $file) {
            $self->error_message("File $file dosen't exist or has no data.  It should have been filled-in in a prior step");
            return;
        }
    }

    foreach my $resource ( $snp_resource_name, $pileup_resource_name) {
        unless ($model->lock_resource(resource_id => $resource)) {
            $self->error_message("Can't get lock for resource $resource");
            return undef;
        }
    }

    $self->status_message("Parsing snip file $snip_output_file");
    $self->_parse_snip_file($snip_output_file, $variations);

    $self->status_message("Parsing pileup file $pileup_output_file");
    $self->_parse_pileup_file($pileup_output_file, $variations);
    
    my $output = $self->_convert_variations_to_output($variations);

    my $mutations = $self->_convert_output_to_mutations($output);

     foreach my $resource ( $snp_resource_name, $pileup_resource_name) {
        unless ($model->unlock_resource(resource_id => $resource)) {
            $self->error_message("Can't release lock for resource $resource");
            return undef;
        }
    }

    return $mutations;
}




sub _convert_output_to_mutations {
    my($self,$output) = @_;

    my $mutations = [];

$DB::single=1;

    # FIXME Is this right?  They used to be command line args
    my $software = 'maq';
    my $build = '36';
    my $model = Genome::Model->get($self->model_id);
    #my $sample_temp = $model->sample_name;  
    #$sample_temp =~ s/454_EST_S_//x;
    #my ($sample_a, $sample_b) = split('-',$sample_temp);
    ##$sample_b = sprintf "%05d",$sample_b;
    #my $sample_id = $sample_a . '-' . $sample_b;

    my $sample_id = $model->sample_name;

    #my @sample_parts = split('-',$model->sample_name);
    #my $sample_id = join('-', @sample_parts[0,-1]);


    my $count = 1;
    foreach my $chr ( sort (keys %$output)) {
        my $chromosome = $chr;
        $chromosome =~ s/^0//;

        foreach my $pos (sort { $a <=> $b } (keys %{$output->{$chr}})) {
            my $this_data = $output->{$chr}->{$pos};

            my $ref_sequence = $this_data->{'ref_sequence'};
            my $var_sequence = $this_data->{'var_sequence'};

            next unless (defined $ref_sequence && defined $var_sequence);

            my $plus_minus = defined($this_data->{'orientation'}) ? $this_data->{'orientation'} : '+';
            my($start,$end,$genotype_allele1,$genotype_allele2,$cns_sequence,$depth) = 
                   @$this_data{'start','end','ref_sequence','var_sequence','cns_sequence','depth'};


            my $ref_reads = $output->{$chr}->{$pos}->{'reference_reads'};
            if (defined($cns_sequence) && $cns_sequence ne '') {
                if (exists($this_data->{'variant_reads'}->{$cns_sequence})) {
                    $ref_reads = $this_data->{variant_reads}->{$cns_sequence};
                }
            } else {
                if (exists($this_data->{'variant_reads'}->{$ref_sequence})) {
                    $ref_reads = $this_data->{'variant_reads'}->{$ref_sequence};
                }
            }

            my $variant_reads;
            if (exists($this_data->{'variant_reads'}->{$var_sequence})) {
                $variant_reads = $this_data->{'variant_reads'}->{$var_sequence};
            }


            my @scores = ( $this_data->{'quality_score'} || '');
            if (defined($ref_reads) && $ref_reads != 0) {
                push @scores, ("reads1=$ref_reads");
            }

            if (defined($variant_reads) && $variant_reads != 0) {
                push @scores, ("reads2=$variant_reads");
            }

            if (defined($depth)) {
                push @scores, ("depth=$depth");
            }
            if (defined($cns_sequence)) {
                push @scores, ("cns=$cns_sequence");
            }

            push @$mutations,  { software => $software,
                                 build    => $build,
                                 chromosome => $chromosome,
                                 plus_minus => $plus_minus,
                                 start => "$start",
                                 end   => "$end",
                                 sample_id => $sample_id,
                                 genotype_allele1 => $genotype_allele1,
                                 genotype_allele2 => $genotype_allele2,
                                 scores => \@scores,
                                 count => $count++};
        } # end foreach $pos
    } # end foreach $chr

    return $mutations;
}


# Is there a better name for what it's converted into other than 'output'?
sub _convert_variations_to_output {
    my($self,$variations) = @_;

    
    my $model = Genome::Model->get($self->model_id);
    
    # resolve coordinate translation file for transcriptome-based genome models
    # this file will not exist in the case of a whole genome model
    # the transcript-to-genomic translator constructor will function if the file does not exist
    # and will just return coordinates as they were passed in w/o translation
    my $coord_translation_file_name = sprintf("coord_translation%s.tsv",
                                         defined $self->ref_seq_id ? "_".$self->ref_seq_id
                                                                   : "");
    my $coord_file = $model->reference_sequence_path . "/" . $coord_translation_file_name;
    my $genomic_coords = MG::Transform::Coordinates::TranscriptToGenomic->new(coordinate_file => $coord_file);

    my $output = {};

    foreach my $key (keys %$variations) {
        next unless (exists($variations->{$key}->{'start'}));

        my ($id, $rel_position) = split("\t",$key);
        my $chromosome;

        if ($id =~ /NC_0000(.{2})/x ) {
            $chromosome = $1;
        } elsif ($id =~ /chr(.*)$/x) {
            $chromosome = $1;
        } elsif ($id =~ /^ \d+ $/x || $id =~ /^ [XY] $/x) {
            $chromosome = $id;
        }

        my $coord_id = $id;
        if ($id =~ /\( \s* CCDS/) {
            $coord_id =~ s/\( \s* CCDS.*$//;
        } elsif($id =~ /CCDS/ ) {
            $coord_id =~ s/\|.*$//;
        }
        
        # if $coord_file was undef when the transcript-to-genomic translator was created,
        # then this will return back the original parameters with no translations
        # (e. g. in case of wg run)
        my ($c_chromosome, $position, $offset, $c_orient) = $genomic_coords->Translate($coord_id,$rel_position);

        # FIXME there's currently no way to pass in a coord_offset.  It used to be a command line
        # option.  Is it even needed anymore?
        #$position += $coord_offset; # add a user supplied offset--the position is still undef  if undef
        #$rel_position += $coord_offset; # add a user supplied offset--the rel_position is still undef  if undef
        #$offset += $coord_offset; # add a user supplied offset--the offset is still undef  if undef

        if (defined($c_chromosome) && defined($rel_position)) {
            if ($c_chromosome =~ /^ \d+ $/x ) {
                $c_chromosome = sprintf "%02d", $c_chromosome;
            }

            $chromosome ||= $c_chromosome;
            $position ||= $rel_position;
            $output->{$chromosome}->{$position}->{'orientation'} = $c_orient;
        }

        unless (defined($chromosome)) {
            $self->error_message("Could not find coordinate translation for id $id");
            next;
        }

        # left pad with zero so sorting is easy
        if ($chromosome =~ /^ \d+ $/x ) {
            $chromosome = sprintf "%02d", $chromosome;
        }

        $output->{$chromosome}->{$position}->{'id'} = $id;

        foreach my $valuekey (keys %{$variations->{$key}}) {
            if ($valuekey eq 'start' || $valuekey eq 'end') {
                $output->{$chromosome}->{$position}->{$valuekey} = $variations->{$key}->{$valuekey} + $offset;
            } elsif (exists($variations->{$key}->{$valuekey})) {
                $output->{$chromosome}->{$position}->{$valuekey} = $variations->{$key}->{$valuekey};
            }
        }

        # delete $variation{$key};  # Is this necessary?
    }

    return $output;
}




# The variations hashref is modified in-place, not returned
sub _parse_pileup_file {
    my($self,$filename,$variations) = @_;

    my $fh = IO::File->new($filename);
    unless ($fh) {
        $self->error_message("Can't open snip file $filename: $!");
        return;
    }

    while(<$fh>) {
        chomp;
        my($id, $position, $ref_base, $depth, $bases) = split("\t");
        next unless ($depth > 0);

        my $key = "$id\t$position";

        if (defined($variations->{$key})) {
            $variations->{$key}->{'depth'} = $depth;

            my $bases_length = length($bases);
            
            my $tb = $bases;
            $tb =~ s/[\,\.]//gx;       
            
            $variations->{$key}->{reference_reads} = $bases_length - length($tb);

            foreach my $base ( 'A', 'C', 'G', 'T' ) {
                if ($bases =~ m/$base/ix) {
                    my $temp_bases = $bases;
                    $temp_bases =~ s/$base//gix;
                    $variations->{$key}->{'variant_reads'}->{$base} = $bases_length - length($temp_bases);
                }
            }
        }
    }

    return 1;
}
       


# The variations hashref is modified in-place, not returned
sub _parse_snip_file {
    my($self,$filename,$variations) = @_;

    my $fh = IO::File->new($filename);
    unless ($fh) {
        $self->error_message("Can't open snip file $filename: $!");
        return;
    }

    while(<$fh>) {
        chomp;
        my ($id, $start, $ref_sequence, $iub_sequence, $quality_score,
            $depth, $avg_hits, $high_quality, $unknown) = split("\t");

        next if ($quality_score < $QC_CUTOFF );

        my $key = "$id\t$start";

        my $genotype = $self->_lookup_iub_code($iub_sequence);
        my $cns_sequence = substr($genotype,0,1);
        my $var_sequence = (length($genotype) > 2) ? 'X' : substr($genotype,1,1);

        next if ($ref_sequence eq $cns_sequence &&
                 $ref_sequence eq $var_sequence);    # no variation

        $variations->{$key}->{'start'} = $start;
        $variations->{$key}->{'end'} = $start;
        $variations->{$key}->{'ref_sequence'} = $ref_sequence;
        $variations->{$key}->{'var_sequence'} = $var_sequence;

        if ($var_sequence eq $cns_sequence) {
            # homozygous rare
            $variations->{$key}->{'cns_sequence'} = $cns_sequence;
        } elsif ($ref_sequence ne $cns_sequence) {
            if ($ref_sequence eq $var_sequence) {
                $variations->{$key}->{'var_sequence'} = $cns_sequence;
            } else {
                $variations->{$key}->{'cns_sequence'} = $cns_sequence;
            }
        }

        $variations->{$key}->{'quality_score'} = $quality_score;
        $variations->{$key}->{'total_reads'} = $depth;
        $variations->{$key}->{'avg_hits'} = $avg_hits;
        $variations->{$key}->{'high_quality'} = $high_quality;
        $variations->{$key}->{'unknown'} = $unknown;
    } # end reading from snip file
    
    return 1;
}
        


    



sub _lookup_iub_code {
    my($self,$code) = @_;

    $self->{'_iub_code_table'} ||= {
             A=>'AA',
             C=>'CC',
             G=>'GG',
             T=>'TT',
             M=>'AC',
             K=>'GT',
             Y=>'CT',
             R=>'AG',
             W=>'AT',
             S=>'GC',
             D=>'AGT',
             B=>'CGT',
             H=>'ACT',
             V=>'ACG',
             N=>'ACGT',
          };

    return $self->{'_iub_code_table'}->{$code};
}


1;
