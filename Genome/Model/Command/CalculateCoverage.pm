# Rename the final word in the full class name <---
package Genome::Model::Command::CalculateCoverage;

use strict;
use warnings;

use UR;
use Command;

use Fcntl;
use Carp;


use constant MATCH => 0;
use constant MISMATCH => 1;
use constant QUERY_INSERT => 3;
use constant REFERENCE_INSERT => 2;


UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => ['file','aln','chrom','length','start','result'],                   # Specify the command's properties (parameters) <--- 
);

sub help_brief {
    "print out the coverage depth for the given alignment file"                     # Keep this to just a few words <---
}

sub help_detail {                           # This is what the user will see with --help <---
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

sub create {                               # Rarely implemented.  Initialize things before execute <---
    my $class = shift;
    my %params = @_;

    my($aln,$result);

    if ($params{'aln'}) {
        $aln = delete $params{'aln'};
    }
    if ($params{'result'}) {
        $result = delete $params{'result'};
    }
        

    my $self = $class->SUPER::create(%params);

    $self->aln($aln) if ($aln);
    $self->result($result) if ($result);

    return $self;
}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

# FIXME how can we determine these from the DB?
our %CHROM_LEN = (
    1   =>      247249720,
    2   =>      242951150,
    3   =>      199501828,
    4   =>      191273064,
    5   =>      180857867,
    6   =>      170899993,
    7   =>      158821425,
    8   =>      146274827,
    9   =>      140273253,
    10  =>      135374738,
    11  =>      134452385,
    12  =>      132349535,
    13  =>      114142981,
    14  =>      106368586,
    15  =>      100338916,
    16  =>      88827255,
    17  =>      78774743,
    18  =>      76117154,
    19  =>      63811652,
    20  =>      62435965,
    21  =>      46944324,
    22  =>      49691433,
    X   =>      154913755,
    Y   =>      57772955,
);

sub execute {
    my $self = shift;
$DB::single=1;

    require Genome::Model::RefSeqAlignmentCollection;

    my $alignment;
    if ($self->file) {
        $alignment = Genome::Model::RefSeqAlignmentCollection->new(file_prefix => $self->file,
                                                                   mode => O_RDONLY);
        unless ($alignment) {
            $self->error_message("Can't access the alignment data: $!");
            return;
        }
    } elsif ($self->aln) {
        $alignment = $self->aln();
    } else {
        $self->error_message("Either the file or aln arguments are required to execute");
        return;
    }

    my $start_position = $self->start() || 1;
    my $end_position;
    if ($self->length) {
        $end_position = $start_position + $self->length - 1;
    } elsif ($self->chrom) {
        unless ($CHROM_LEN{$self->chrom}) {
            $self->error_message("Can't determine chromosome length for '".$self->chrom."'");
            return;
        }
        $end_position = $CHROM_LEN{$self->chrom};
    } else {
        $end_position = $alignment->max_alignment_pos();
    }

    my $result_coderef;
    if ($self->result) {
        my $coverage_result = $self->result;
        unless (ref($coverage_result) eq 'ARRAY') {
            $self->error_message("result parameter to ",ref($self)," must be an array ref");
            return;
        }
        $result_coderef = sub {  
                                my($pos,$coverage) = @_;
                                push @$coverage_result,$coverage;
                             };
    } else {
        print "Coverage for ",$self->aln," from position $start_position to $end_position\n";
        $result_coderef = \&_print_result;
    } 

    $alignment->foreach_reference_position(\&_calculate_coverage, $result_coderef, $start_position, $end_position);

    return 1;
}


sub _print_result {
my($pos,$coverage) = @_;

    print "$pos:$coverage\n";
}


sub _calculate_coverage{
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

