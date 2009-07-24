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
        output_file => {
            is        => 'String',
            is_input => '1',
            is_output => '1',
            doc       =>
            'Same columns as indel_file with one new column: number of libraries that contained the indel',
        },
   ],
};

sub help_brief {
    return "Outputs list of indels that have high library support.";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    genome model tools somatic high-library-support-filter [indel file from somatic sniper]
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

    # We have switched from finding read support within this tool to just reading columns that somatic
    # sniper outputs. So it runs much faster now

    my ($self) = @_;
    $DB::single=1;

    my $indel_file = IO::File->new( $self->indel_file() )
        || die "cant read: " . $self->indel_file();

=cut
    my $sample_alignment_file =
        IO::File->new( $self->sample_alignment_file() )
        || die "cant read: " . $self->sample_alignment_file();
=cut

    # #FIXME Skip this step if output exists... this may not be desireable in production
    if (-e $self->output_file) {
        $self->status_message("Output file detected, skipping this step");
        return 1;
    }

    my $output_file = IO::File->new( $self->output_file, '>' )
        || die "Could not open for writing " . $self->output_file();

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
        my $normal_reads_indel1 = $fields[26]; # number of reads that support indel 1 in normal
        my $normal_reads_indel2 = $fields[27]; # number of reads that support indel 2 in normal
        my $num_libs_match;

        unless($indel1 eq '*' || $indel2 eq '*') {
            #skip double indel case. probably ref error.
            next;
        }
        
#        my $cigar_string;
        if($indel1 ne '*') {
            if($normal_reads_indel1 > 0) {
                next;
            }
            $num_libs_match = $fields[34];

#            if($indel1_size > 0) { 
#                $cigar_string = $indel1_size . "I";
#            }else {
#                $cigar_string = ($indel1_size * -1) . "D"; 
#            }
        }
        elsif($indel2 ne '*') {
            if($normal_reads_indel2 > 0) {
                next;
            }
            $num_libs_match = $fields[35];
            
#            if($indel2_size > 0) { 
#                $cigar_string = $indel2_size . "I";
#            }else {
#                $cigar_string = ($indel2_size * -1) . "D"; 
#            }
        }
        else { 
            die "indel1 and indel2 ... *\n";
        }

        # number of distinct libraries that contain this indel
#        my $num_libs_match = $self->find_read_support( $chr, $pos, $cigar_string );
        next if $num_libs_match < 2;

        print $output_file "$line\t$num_libs_match\n";
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



