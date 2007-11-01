
package Genome::Model::Command::Old::Genotype::TopAlignment;

use strict;
use warnings;

use above "Genome";
use Command;

use IO::File;

use constant MATCH              => 0;
use constant MISMATCH           => 1;
use constant REFERENCE_INSERT   => 2;
use constant QUERY_INSERT       => 3;

use Genome::Model::Command::IterateOverRefSeq;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::Tools::Old::Genotype',
    has => [
        result => { type => 'Array', doc => 'If set, results will be stored here instead of printing to STDOUT.' },
        bases_file => { type => 'String', doc => 'The pathname of the binary file containing prb values' },
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


sub execute {
    my($self) = @_;

    our $bases_fh = IO::File->new($self->bases_file);   # Ugly hack until _examine_position can be called as a method
    unless ($bases_fh) {
        $self->error_message("Can't open bases file: $!");
        return undef;
    }

    $self->SUPER::execute();
}

our @TRANSLATE_BASE = ( 'A','C','G','T' );

sub _examine_position {
    my $alignments = shift;

$DB::single=1;
    my $max_base_score_seen = 0;
    my $base = undef;

    foreach my $aln (@$alignments){

        our $bases_fh;
        $aln->{'reads_fh'} = $bases_fh;   # another ugly hack.  $aln's constructor should know about this instead

        my $vectors = $aln->get_read_probability_vectors();
        for (my $i = 0; $i < 4; $i++) {
            
            # we have all the positions since we get them all at once for a read and then cache them ...
            # so just use 'current_position' to take the right one
            my $base_score = $vectors->[ $aln->{'current_position'} ]->[$i] * $aln->{'probability'} ;
            
            next unless defined $base_score;   # The reference positions can go past the read length
            
            if ($base_score > $max_base_score_seen) {
                $max_base_score_seen = $base_score;
                $base = $i;
            }
        }
        
        $aln->{'current_position'}++;
    }

    return defined($base) ? $TRANSLATE_BASE[$base] : 'N';
}


1;

