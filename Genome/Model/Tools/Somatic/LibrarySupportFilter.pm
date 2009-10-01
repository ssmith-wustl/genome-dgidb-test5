package Genome::Model::Tools::Somatic::LibrarySupportFilter;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Somatic::LibrarySupportFilter {
    is  => [ 'Command' ],
    has => [
    indel_file => {
        is       => 'String',
        is_input => '1',
        doc      => 'The indel file output from somatic sniper',
    },
    preferred_output_file => {
        is        => 'String',
        is_input => '1',
        is_output => '1',
        doc       => 'Output file that contains the "preferred" out of the single and multiple library files. This is mostly for the somatic pipeline workflow only, and is a semi hacky solution for now. We only want to run the pipeline on one of the two outputs and will select the multi lib file if it has any content, otherwise the single.',
    },
    single_lib_output_file => {
        is        => 'String',
        is_input => '1',
        doc       => 'Output file containing indels with single library support. Same columns as indel_file with two new columns: number of libraries that contained the indel, and indel score',
    },
    multi_lib_output_file => {
        is        => 'String',
        is_input => '1',
        doc       => 'Output filecontaining indels with multiple library support. Same columns as indel_file with two new columns: number of libraries that contained the indel, and indel score',
    },
    ],
};

sub help_brief {
    return "Outputs list of indels that have high library support.";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    genome model tools somatic library-support-filter [indel file from somatic sniper]
EOS
}

sub help_detail {                           
    return <<EOS 
    Outputs list of indels that have high library support. The output columns
    are the same as the input indel_file with the addition of one new column containing
    the number of libraries that contained the indel.
EOS
}

sub execute {

    # for each row in the indel output file of somatic sniper,
    # count how many distinct libraries have the same cigar string,
    # reguardless of position, etc.

    my ($self) = @_;
    $DB::single=1;

    my $indel_file = IO::File->new( $self->indel_file() )
    || die "cant read: " . $self->indel_file();

    # Skip this step if output exists 
    # FIXME this will not work, fix or toss out
    if (-e $self->preferred_output_file) {
        $self->status_message("Output file detected, skipping this step");
        return 1;
    }

    my $multi_lib_output = IO::File->new( $self->multi_lib_output_file, '>' )
        || die "Could not open for writing " . $self->multi_lib_output_file();
    my $single_lib_output = IO::File->new( $self->single_lib_output_file, '>' )
        || die "Could not open for writing " . $self->single_lib_output_file();

# stuff below from chris "golden god" harris:
# /gscmnt/sata146/info/medseq/charris/GBM/somatic_indel_finder.pl

    while ( my $line = $indel_file->getline() ) {

        chomp $line;
        my @fields = split /\t/, $line;

        my $chr    = $fields[0];
        my $pos    = $fields[1];
        my $indel1 = $fields[4];
        my $indel2 = $fields[5];
        my $indel1_size = $fields[6];
        my $indel2_size = $fields[7];
        my $tumor_reads_indel1 = $fields[13];
        my $tumor_reads_indel2 = $fields[14];
        my $normal_reads_indel1 = $fields[26]; # number of reads that support indel 1 in normal
        my $normal_reads_indel2 = $fields[27]; # number of reads that support indel 2 in normal
        my $num_libs_match=0;
        my $indel_size=0;
        my $indel_strength=0;
        unless($indel1 eq '*' || $indel2 eq '*') {
            #skip double indel case. probably ref error.
            next;
        }

#        my $cigar_string;
        if($indel1 ne '*') {
            if($normal_reads_indel1 > 0) {
                next;
            }
            if($indel1_size == 1 || $indel1_size == -1) {
                if($tumor_reads_indel2> 0) {
                    if($tumor_reads_indel1/$tumor_reads_indel2 < .1) {
                        next;
                    }
                }
            }
            $indel_strength = $tumor_reads_indel1/($tumor_reads_indel1 + $tumor_reads_indel2) * $tumor_reads_indel1 * $normal_reads_indel2;
            $indel_size=$indel1_size;
            if(defined $fields[34]) {
                $num_libs_match = $fields[34];
            }

        }
        elsif($indel2 ne '*') {
            if($normal_reads_indel2 > 0) {
                next;
            }
            if($indel2_size == 1 || $indel2_size == -1) {
                if($tumor_reads_indel1 > 0) {
                    if($tumor_reads_indel2/$tumor_reads_indel1 < .1) {
                        next;
                    }
                }
            }
            $indel_strength =  $tumor_reads_indel2/($tumor_reads_indel2 + $tumor_reads_indel1)  * $tumor_reads_indel2 * $normal_reads_indel1;
            $indel_size=$indel2_size;



            if(defined $fields[35]) {
                $num_libs_match = $fields[35];
            }
        }
        else { 
            die "indel1 and indel2 ... *\n";
        }

        # number of distinct libraries that contain this indel
        if($num_libs_match< 2) {
            my $indel_score = sprintf( "%.3f", abs($indel_strength * $indel_size ));
            if($indel_score > 0) {
                print $single_lib_output "$line\t$num_libs_match\t$indel_score\n";
            }    
        }
        else {
            my $indel_score = sprintf( "%.3f", abs($indel_strength * $indel_size * $num_libs_match));
            print $multi_lib_output "$line\t$num_libs_match\t$indel_score\n";
        }
    }

    # Decide whether to use the single or multi lib output file
    # For now, we use the multi lib if it has any output at all
    if (-s $self->multi_lib_output_file) {
        $self->preferred_output_file($self->multi_lib_output_file);
    } else {
        $self->preferred_output_file($self->single_lib_output_file);
    }

    return 1; 
}

sub find_read_support {

    my ( $self, $chr, $pos, $indel_cigar ) = @_;
    my %library_hash; 

    # "/gscmnt/sata821/info/model_data/2774314134/build96520626/alignments/H_GP-0124t_merged_rmdup.bam";
    my $sample_alignment_file = $self->sample_alignment_file();

    my @reads = `samtools view $sample_alignment_file $chr:$pos-$pos`;

    for my $read (@reads) {

        chomp($read);
        my @columns = split /\t/, $read;

        my $read_name = $columns[0];
        my ( $foo, $read_start, $read_end ) = split /_/, $read_name;

        my $flag         = $columns[1];
        my $position     = $columns[3];
        my $cigar_string = $columns[5];
        my $sequence     = $columns[9];
        my $read_length  = length( $sequence );
        my $library_name = $columns[11];

        if ( $cigar_string =~ m/$indel_cigar/ ) {
            $library_hash{ $library_name } = 1;
        }
    }

    return scalar(keys %library_hash);
}


1;



