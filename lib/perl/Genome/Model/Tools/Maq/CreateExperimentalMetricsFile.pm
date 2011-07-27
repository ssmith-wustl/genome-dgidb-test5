package Genome::Model::Tools::Maq::CreateExperimentalMetricsFile;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Bio::DB::Fasta;
use Readonly;


class Genome::Model::Tools::Maq::CreateExperimentalMetricsFile {
    is => 'Command',
    has => [
       'map_file' => {
           type => 'String',
           is_optional => 0,
           doc => 'Mapfile to generate metrics on',
       },
       'ref_bfa_file' => {
           type => 'String',
           is_optional => 0,
           doc => 'Reference bfa file used to align the map file',
       },
       'location_file' => {
           type => 'String',
           is_optional => 0,
           doc => 'File of locations to gather metrics on. Must be in maq-0.6.8 cns2snp format.',
       },
       'snpfilter_file' => {
           type => 'String',
           is_optional => 0,
           doc => 'File of locations that passed Maq SNPFilter',
       },
       'output_file' => {
           type => 'String',
           is_optional => 0,
           doc => 'File name in which to write output',
       },
       'minq' => {
           type => 'Integer',
           is_optional => 1,
           default => 1,
           doc => 'Minimum mapping quality of reads to be included in the counts',
       },
       'max_read' => {
           type => 'Integer',
           is_optional => 1,
           default => 26,
           doc => 'Artifical read-length cutoff to calculate high quality sites',
       },
       'ref_name' => {
           type => 'String',
           is_optional => 1,
           default => q{},
           doc => 'Chromosome (or gene name if cDNA) to generate metrics for',
       },
       'window_size' => {
           type => 'String',
           is_optional => 1,
           default => 2,
           doc => 'Number of bases on either side of each SNP to generate metrics for',
       },
       'long_read' => {
           type => 'Flag',
           is_optional => 1,
           default => 0,
           doc => 'Whether the map file was generated using a long reads version of maq (0.7 and up)',
       }
       
    ]
};

#----------------------------------
#   CONSTANTS
#----------------------------------

Readonly::Hash my %IUB_CODE => (
    A => ['A'],
    C => ['C'],
    G => ['G'],
    T => ['T'],
    M => ['A','C'],
    K => ['G','T'],
    Y => ['C','T'],
    R => ['A','G'],
    W => ['A','T'],
    S => ['G','C'],
    D => ['A','G','T'],
    B => ['C','G','T'],
    H => ['A','C','T'],
    V => ['A','C','G'],
    N => ['A','C','G','T'],
);

Readonly::Scalar my $MAPSTAT_PROG => '/gscuser/dlarson/src/c-code/src/mapstat2/mapstat';
Readonly::Scalar my $MAPSTAT_PROG_LONG => '/gscuser/dlarson/src/c-code/src/mapstat2/mapstat_long';

Readonly::Array my @mapstat_columns => qw(  name
                                            ref_name
                                            snp_position
                                            position
                                            strand
                                            mapping_quality
                                            alt_mapping_quality
                                            single_stranded_map_quality
                                            flag
                                            snp_offset
                                            length
                                            ref_allele
                                            snp_allele
                                            snp_base_quality
                                            num_mismatches
                                            sum_of_mismatch_qualities
                                            prefix_window_bases
                                            postfix_window_bases
                                            prefix_window_qualities
                                            postfix_window_qualities
                                            sequence
                                       );
                                            

sub execute {
    my $self = shift;
    #test locations file
    my $locations_fh = IO::File->new($self->location_file,"r");
    unless(defined($locations_fh)) {
        $self->error_message("Unable to open " . $self->location_file);
        return;
    }
    

    my $locations_href = $self->build_locations_hash($locations_fh);
    $locations_fh->close;

    #Handle SNPfilter output
    
    my $snpfilter_fh = IO::File->new($self->snpfilter_file,"r");
    unless(defined($snpfilter_fh)) {
        $self->error_message("Unable to open " . $self->snpfilter_file);
        return;
    }

    $self->annotate_snpfilter($locations_href, $snpfilter_fh);
    $snpfilter_fh->close;

    #open mapstat as a pipe to catch it's output
    #this seems to only catch errors properly if we do a regular perl openA
    my $mapstat_cmd;
    my $mapstat_prog_to_use = ($self->long_read) ? $MAPSTAT_PROG_LONG : $MAPSTAT_PROG;
    
    if($self->ref_name ne q{}) {
        $mapstat_cmd = sprintf("$mapstat_prog_to_use -q %d -c %s -l %s -w %d %s %s |",$self->minq,$self->ref_name,$self->location_file,$self->window_size,$self->ref_bfa_file, $self->map_file);
    }
    else {
        $mapstat_cmd = sprintf("$mapstat_prog_to_use -q %d -l %s -w %d %s %s |",$self->minq,$self->location_file,$self->window_size,$self->ref_bfa_file, $self->map_file);
    }
    unless(open(MAPSTAT, $mapstat_cmd)) {
        $self->error_message("Unable to open pipe to $mapstat_prog_to_use");
        return;
    }

    my $header = <MAPSTAT>;
    while( <MAPSTAT> ) {
        chomp;

        #$DB::Single = 1;
        #store read
        my %read;
        @read{@mapstat_columns} = split /\t/;

        #initialize read values, and make sure bases are uppercase
        $read{prefix_window_qualities} ||= q{};
        $read{prefix_window_qualities} = [split /:/, $read{prefix_window_qualities}];
        $read{postfix_window_qualities} ||= q{};
        $read{postfix_window_qualities} = [split /:/, $read{postfix_window_qualities}];
        $read{sequence} = uc($read{sequence});
        $read{snp_allele} = uc($read{snp_allele});

        #sanitize ref_name, add padding for good sorting
        $read{ref_name} =~ s/\s+.*$//;
        if($read{ref_name} =~ /^ \d+ $/x) {
            $read{ref_name} = sprintf("%02d",$read{ref_name});
        }

        $locations_href->{$read{ref_name}}{$read{snp_position}}{total_depth} += 1;
        if(exists($locations_href->{$read{ref_name}}{$read{snp_position}}{$read{snp_allele}})) {
            $locations_href->{$read{ref_name}}{$read{snp_position}}{$read{snp_allele}}->add_read($self->max_read,\%read);
        }
        
    }

    unless(close(MAPSTAT)) {
        $self->error_message("Error running mapstat");
        return;
    }

    my $output_fh = IO::File->new($self->output_file,"w");
    unless($output_fh) {
        $self->error_message("Couldn't open " . $self->output_file . " for writing");
        return;
    }

    $self->write_data($output_fh,$locations_href);
    $output_fh->close;

    return 1;
}

1;

sub help_brief {
    return "This module generates read count metrics for a map file";
}

sub build_locations_hash {
    my ($self, $location_fh) = @_;
    my %locations;
    
    while(my $line = $location_fh->getline) {
        chomp $line;
        my ($chr, $pos, $ref, $iub_code, $quality, @other_metrics) = split /\s+/, $line;
        unless(defined($quality) && $chr && $pos && $ref && $iub_code) {
            $self->error_message("Snp file format does not have the correct number of columns. (Must have at least 5)");
            return;
        }
        if($self->ref_name eq q{} || $self->ref_name eq $chr) {
            $chr =~ s/\s+.*$//; #remove whitespace
            
            #Zero pad chromosome for sorting
            if($chr =~ /^ \d+ $/x) {
                $chr = sprintf "%02d", $chr;
            }

            #store additional information and initialize reference sequence
            $locations{$chr}{$pos} = {  other_metrics => \@other_metrics,
                                        total_depth => 0,
                                        snpfilter => 'NO', #store snpfilter output yes/no
                                        $ref => ExperimentalMetrics::VariantMetrics->new(), #it's ref and thus has no quality
                                     };
            
            #initialize variant allele metrics                         
            foreach my $variant ( @{$IUB_CODE{$iub_code}} ) {
                if(!exists($locations{$chr}{$pos}{$variant})) {
                    $locations{$chr}{$pos}{$variant} = ExperimentalMetrics::VariantMetrics->new($quality);
                }
            }
        }
    }

    return \%locations;
}

sub annotate_snpfilter {
    my ($self,$locations_href, $snpfilter_fh) = @_;
    while(my $line = $snpfilter_fh->getline) {
        chomp $line;
        my ($chr, $pos, ) = split /\s+/, $line;
        if($self->ref_name eq q{} || $self->ref_name eq $chr) {
            $chr =~ s/\s+.*$//; #remove whitespace
            
            #Zero pad chromosome for sorting
            if($chr =~ /^ \d+ $/x) {
                $chr = sprintf "%02d", $chr;
            }

            #store additional information and initialize reference sequence
            $locations_href->{$chr}{$pos}{'snpfilter'} = 'YES';
            
        }
    }
   return;
}
    

sub write_data {
    my ($self, $output_fh, $locations_href) = @_;

    my @ref_header = map {"ref_$_"} ExperimentalMetrics::VariantMetrics->headers($self->max_read);
    shift @ref_header;
    
#the highest mapping quality of the reads covering the position, the minimum consensus quality in the 3bp flanking regions at each side of the site (6bp in total), the second best call, log likelihood ratio of the second best and the third best call, and the third best call.
    
    my @header = (  'chromosome',
        'position',
        'reference_base',
        'variant_base',
        ExperimentalMetrics::VariantMetrics->headers($self->max_read),
        @ref_header,
        'total_depth',
        'cns2_depth',
        'cns2_avg_num_reads',
        'cns2_max_map_quality',
        'cns2_min_flanking_maq_q',
        'cns2_second_best_call',
        'cns2_log_likelihood_second_best',
        'cns2_third_best',
        'snpfilter',
    );
    print $output_fh (join q{,}, @header),"\n"; #print header
    my @bases = qw( A C G T N );

    foreach my $chr (sort (keys %{$locations_href})) {
        my $chromosome = $chr;
        $chromosome =~ s/^0//; #remove leading 0s
        foreach my $pos (sort {$a <=> $b} (keys %{$locations_href->{$chr}})) {
            my $reference;
            my @variants;

            foreach my $base (@bases) {
                next if(!exists($locations_href->{$chr}{$pos}{$base}));

                if($locations_href->{$chr}{$pos}{$base}->maq_quality eq 'ref') {
                    $reference = $base; 
                }
                else {
                    push @variants, $base;
                }
            }

            foreach my $variant (@variants) {
                print $output_fh (join q{,}, $chromosome, $pos, $reference, $variant),q{,};
                print $output_fh (join q{,}, $locations_href->{$chr}{$pos}{$variant}->metrics),q{,};
                my @ref_metrics = $locations_href->{$chr}{$pos}{$reference}->metrics;
                shift @ref_metrics;
                print $output_fh (join q{,}, @ref_metrics), q{,};
                print $output_fh (join q{,}, $locations_href->{$chr}{$pos}{total_depth}),q{,};
                print $output_fh (join q{,}, @{$locations_href->{$chr}{$pos}{other_metrics}});
                print $output_fh q{,},$locations_href->{$chr}{$pos}{snpfilter};
                print $output_fh "\n";
            }


        }

    }
    return 1;
}




#----------------------------------
# Accessory packages
#----------------------------------

package ExperimentalMetrics::VariantMetrics;
use Readonly;
Readonly::Scalar my $MAX_READ => 2;
Readonly::Scalar my $FULL_READ => 1;

sub new {
    my ($class, $quality) = @_;
    my $self = {
                    _maq_quality => defined($quality) ? $quality : 'ref',
                    _unique_reads_by_sequence => {},
                    _unique_start_sites => {},
                    _unique_end_sites => {},
                    _num_reads => 0,
                    _max_bq => 0,
                    _num_max_bq => 0,
                    _sum_of_bq => 0,
                    _max_mapq => 0,
                    _num_max_mapq => 0,
                    _sum_of_mapq => 0,
                    _max_alt_mapq => 0,
                    _num_max_alt_mapq => 0,
                    _sum_of_alt_mapq => 0,
                    _max_windowedq => 0,
                    _num_max_windowedq => 0,
                    _sum_of_windowedq => 0,
                    _num_bases_all_windowedq => 0,
                    _max_sum_mismatch_qualities => 0,
                    _num_max_sum_mismatch_qualities => 0,
                    _max_num_mismatches => 0,
                    _num_max_num_mismatches => 0,
                    _sum_num_mismatch => 0,
                    _sum_of_mismatch_qualities => 0
                    
                };
    bless($self, ref($class) || $class);
    return $self;
}

sub add_read {
    my ($self, $max_read, $read_ref) = @_;

    #TODO some error checking to make sure everything's defined, possibly unnecessary
    $self->{_num_reads} += 1; 
    my $sequence = uc($read_ref->{sequence});

    #Track the unique sequences and start sites
    #Considering strandedness on the start sites
    #
    #TODO Consider moving the $read_ref hash_ref to become a class. It makes good sense.
    if ($read_ref->{strand} eq '+') {
        #store unique reads
        if($read_ref->{snp_offset} < $max_read) {
            $self->{_unique_start_sites}{$read_ref->{position}} = $MAX_READ;
            $self->{_unique_reads_by_sequence}{$sequence} = $MAX_READ; 
        }
        else {
            $self->{_unique_start_sites}{$read_ref->{position}} = $FULL_READ;
            $self->{_unique_reads_by_sequence}{$sequence} = $FULL_READ;
        }
    }
    else {
        #adjust for minus strand
        my $actual_read_start = $read_ref->{position} + $read_ref->{length} - 1;

        #store unique reads
        if($max_read > ($read_ref->{length} - $read_ref->{snp_offset} - 1)) {
            $self->{_unique_end_sites}{$actual_read_start} = $MAX_READ;
            $self->{_unique_reads_by_sequence}{$sequence} = $MAX_READ; 
        }
        else {
            $self->{_unique_end_sites}{$actual_read_start} = $FULL_READ;
            $self->{_unique_reads_by_sequence}{$sequence} = $FULL_READ; 

        }
    }

    #track basequality 
    $self->{_sum_of_bq} += $read_ref->{snp_base_quality};
    $self->_track_max_attribute('bq',$read_ref->{snp_base_quality});

    #track mapping quality
    $self->{_sum_of_mapq} += $read_ref->{mapping_quality};
    $self->_track_max_attribute('mapq',$read_ref->{mapping_quality});

    #track mapping quality
    $self->{_sum_of_alt_mapq} += $read_ref->{alt_mapping_quality};
    $self->_track_max_attribute('alt_mapq',$read_ref->{alt_mapping_quality});
    
    #track Windowed base quality
    foreach my $bq_in_window (@{$read_ref->{prefix_window_qualities}}, @{$read_ref->{postfix_window_qualities}}) {
        $self->{_sum_of_windowedq} += $bq_in_window;
        $self->{_num_bases_all_windowedq} += 1;
        $self->_track_max_attribute('windowedq',$bq_in_window);
    }

    #track number of mismatches
    $self->{_sum_num_mismatch} += $read_ref->{num_mismatches};
    $self->_track_max_attribute('num_mismatches',$read_ref->{num_mismatches});
    
    #track sum of mismatch qualities
    $self->{_sum_of_mismatch_qualities} += $read_ref->{sum_of_mismatch_qualities};
    $self->_track_max_attribute('sum_mismatch_qualities',$read_ref->{sum_of_mismatch_qualities});
    
   return 1; 
}

sub _track_max_attribute {
    my ($self, $key, $value,) = @_;

    #calculate keys for attributes of interest
    my $max_key = "_max_$key";
    my $num_max_key = "_num$max_key";

    my $old_max = $self->{$max_key};
    #TODO Automatically generate keys, add error checking and count properly
    if($old_max < $value) {
        #we have a new max
        $self->{$max_key} = $value;
        $self->{$num_max_key} = 1;
    }
    elsif($old_max == $value) {
        $self->{$num_max_key} += 1;
    }
    return 1;
}

sub headers {
    my ($self, $max_read) = @_;
    my @headers = (   'maq_quality',
                        'supporting_reads',
                        'avg_map_quality',
                        'max_map_quality',
                        'n_max_map_quality',
                        'avg_alt_map_quality',
                        'max_alt_map_quality',
                        'n_max_alt_map_quality',
                        'avg_sum_of_mismatches',
                        'max_sum_of_mismatches',
                        'n_max_sum_of_mismatches',
                        'avg_num_of_mismatches',
                        'max_num_of_mismatches',
                        'n_max_num_of_mismatches',
                        'avg_base_quality',
                        'max_base_quality',
                        'n_max_base_quality',
                        'avg_windowed_quality',
                        'max_windowed_quality',
                        'n_max_windowed_quality',
                        'for_strand_unique_by_start_site',
                        'rev_strand_unique_by_start_site',
                        'unique_by_sequence_content',
                        'for_strand_unique_by_pre' . ($max_read + 1),
                        'rev_strand_unique_by_pre' . ($max_read + 1),
                        'unique_by_sequence_content_pre' . ($max_read + 1),
                    );
    return @headers;                
}

sub metrics {
  my ($self) = @_;
  
  my @start_sites = values %{$self->{_unique_start_sites}};
  my @end_sites = values %{$self->{_unique_end_sites}};
  my @sequences = values %{$self->{_unique_reads_by_sequence}};

  my @metrics = (   $self->{_maq_quality},
                    $self->{_num_reads},
                    $self->{_num_reads} > 0 ? sprintf("%.0f",$self->{_sum_of_mapq} / $self->{_num_reads}) : 0,
                    $self->{_max_mapq},
                    $self->{_num_max_mapq},
                    $self->{_num_reads} > 0 ? sprintf("%.0f",$self->{_sum_of_alt_mapq} / $self->{_num_reads}) : 0,
                    $self->{_max_alt_mapq},
                    $self->{_num_max_alt_mapq},
                    $self->{_num_reads} > 0 ? sprintf("%.0f",$self->{_sum_of_mismatch_qualities} / $self->{_num_reads}) : 0,
                    $self->{_max_sum_mismatch_qualities},
                    $self->{_num_max_sum_mismatch_qualities},
                    $self->{_num_reads} > 0 ? sprintf("%.0f",$self->{_sum_num_mismatch} / $self->{_num_reads}) : 0,
                    $self->{_max_num_mismatches},
                    $self->{_num_max_num_mismatches},
                    $self->{_num_reads} > 0 ? sprintf("%.0f",$self->{_sum_of_bq} / $self->{_num_reads}) : 0,
                    $self->{_max_bq},
                    $self->{_num_max_bq},
                    $self->{_num_reads} > 0 ? sprintf("%.0f",$self->{_sum_of_windowedq} / $self->{_num_bases_all_windowedq}) : 0,
                    $self->{_max_windowedq},
                    $self->{_num_max_windowedq},
                    scalar(@start_sites),
                    scalar(@end_sites),
                    scalar(@sequences),
                    scalar(grep {$_ eq $MAX_READ} @start_sites),
                    scalar(grep {$_ eq $MAX_READ} @end_sites),
                    scalar(grep {$_ eq $MAX_READ} @sequences),
                );
   return @metrics;
}

sub depth {
    my ($self) = @_;
    return $self->{_num_reads};
}

sub maq_quality {
    my ($self) = @_;
    return $self->{_maq_quality};
}
    
