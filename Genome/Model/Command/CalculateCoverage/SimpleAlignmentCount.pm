
package Genome::Model::Command::CalculateCoverage::SimpleAlignmentCount;

use strict;
use warnings;

use UR;
use Command;

use constant MATCH => 0;
use constant MISMATCH => 1;
use constant REFERENCE_INSERT => 2;
use constant QUERY_INSERT => 3;

use Genome::Model::Command::CalculateCoverage;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::CalculateCoverage',
    has => [
        result => { type => 'Array', doc => 'If set, results will be stored here instead of printing to STDOUT.' }
    ],
);

sub help_brief {
    "print out the coverage depth for the given alignment file"
}

sub help_synopsis {
    return <<EOS

genome-model calculate-coverage --file myalignments --start 1000 --length 100 >results

EOS
}

sub help_detail {
    return <<"EOS"

--file <path_to_alignment_file>  The prefix of the alignment index and data files, without the '_aln.dat'
--chrom <name>     The single-character name of the chromosome this alignment file covers, to determine
                   the last alignment position to check
--length <count>   In the absence of --chrom, specify how many positions to calculate coverage for
--start <position> The first alignment position to check, default is 1

If neither --chrom or --length are specified, it uses the last position in the alignment file as
the length

EOS
}

sub _examine_position {
    my $alignments = shift;

    my $coverage_depth_at_this_position = 0;
    foreach my $aln (@$alignments){

        # skip over insertions in the reference
        my $mm_code;
        do{
            # Moving what get_current_mismatch_code() to here to remove the overhead of a function call
            #$mm_code = $aln->get_current_mismatch_code();
            $mm_code = substr($aln->{mismatch_string},$aln->{current_position},1);

            $aln->{current_position}++; # an ugly but necessary optimization
        } while (defined($mm_code) && $mm_code == REFERENCE_INSERT);

        $coverage_depth_at_this_position++ unless (!defined($mm_code) || $mm_code == QUERY_INSERT)
    }

    return $coverage_depth_at_this_position;
}

1;

