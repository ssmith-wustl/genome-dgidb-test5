
package Genome::Model::Command::Tools::Indels::Simple;

use strict;
use warnings;

use above "Genome";
use Command;

use constant MATCH => 0;
use constant MISMATCH => 1;
use constant REFERENCE_INSERT => 2;
use constant QUERY_INSERT => 3;

use Genome::Model::Command::IterateOverRefSeq;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::Indels',
    has => [
        result => { type => 'Array', doc => 'If set, results will be stored here instead of printing to STDOUT.' }
    ],
);

sub help_brief {
    ""
}

sub help_synopsis {
    return <<EOS

EOS
}

sub help_detail {
    return <<"EOS"


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

