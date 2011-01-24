package Genome::Model::Tools::Fasta::Trim::Lucy;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Copy;
use File::Temp;

class Genome::Model::Tools::Fasta::Trim::Lucy {
    is  => 'Genome::Model::Tools::Fasta::Trim',
    has => [	 
    vector_name => {
        type => 'Text',
        doc => 'Name of the vector to use for screening',
    },
    ],
    has_optional => [
    keep_lucy_file => {
        type => 'Boolean',
        default => 1,
        doc => 'Keep the lucy produced positions file.  It will be named as the output fasta with a ".lucy" extension',
    },
    ],
};

#< Command Interface >#
sub help_detail { 
    return <<EOS 
A wrapper for lucy, a command line executable for trimming quality and vector in FASTAs.  This module not only runs lucy, it will fetch the vector FASTAs, create insert flanking regions, and then mask the FASTA file with the lucy results.

Requirements:
 1. quality file named with the fasta file name with a '.qual' extension
 2. that the vector be in the database
EOS
}

sub executable { 
    return 'lucy';
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->vector_name ) {
        $self->error_message("Vector name is required");
        $self->delete;
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;

    # vec
    $self->_create_vector_fasta_files
        or return;

    # lucy
    my $cmd = sprintf(
        'lucy -v %s %s -minimum %s -debug %s -output %s %s %s %s',
        $self->vector_fasta_file,
        $self->flanking_fasta_file,
        100, # TODO param
        $self->_tmp_lucy_file,
        $self->_tmp_fasta_file,
        $self->_tmp_qual_file,
        $self->fasta_file,
        $self->qual_file,
    );

    if ( system($cmd) ) {
        $self->error_message("Running lucy failed and exited with code ($?)\nCommand: $cmd");
        return;
    }

    # screen
    $self->_screen_fasta_and_qual_files
        or return;

    # copy qual file
    my $output_qual_file = $self->output_qual_file;
    unlink $output_qual_file if $output_qual_file;
    Genome::Sys->copy_file($self->qual_file, $output_qual_file)
        or return;
    
    # positions file
    if ( $self->keep_lucy_file ) {
        my $lucy_file = $self->lucy_file;
        unlink $lucy_file if -e $lucy_file;
        Genome::Sys->copy_file($self->_tmp_lucy_file, $lucy_file)
            or return;
    }

    return 1;
}

#< Tmp Dirs and Files >#
sub _tmpdir {
    my $self = shift;

    unless ( $self->{_tmpdir} ) {
        $self->{_tmpdir} = File::Temp::tempdir(CLEANUP => 1);
    }

    return $self->{_tmpdir};
}

sub _tmp_fasta_file {
    return $_[0]->_tmpdir.'/lucy.fasta';
}

sub _tmp_qual_file {
    return $_[0]->_tmp_fasta_file.'.qual';
}

sub _tmp_lucy_file {
    return $_[0]->_tmp_fasta_file.'.debug';
}

sub lucy_file {
    return $_[0]->output_fasta_file.'.lucy';
}

#< Vector Fastas >#
sub vector_fasta_file { 
    my $self = shift;

    return sprintf('%s/%s.fasta', $self->_tmpdir, $self->vector_name);
}

sub flanking_fasta_file { 
    my $self = shift;

    return sprintf('%s/%s.flanking.fasta', $self->_tmpdir, $self->vector_name);
}

sub _create_vector_fasta_files {
    my $self = shift;

    my $vector_name = $self->vector_name;
    unless ( $vector_name ) {
        $self->error_message("Vector name is required");
        $self->delete;
        return 1;
    }

    my @vectors = GSC::Vector->get(vector_name => $self->vector_name);
    unless ( @vectors ) {
        $self->error_message("Can't get vector for vector name: ".$self->vector_name);
        return;
    }
    
    my $vector_fasta_file = $self->vector_fasta_file;
    my $sequence_writer = $self->get_fasta_writer($vector_fasta_file)
        or return;

    my $flanking_fasta_file = $self->flanking_fasta_file; 
    my $flanking_writer = $self->get_fasta_writer($flanking_fasta_file)
        or return;

    for my $vector ( @vectors ) { 
        $self->_write_vector_sequence($vector, $sequence_writer)
            or return;
        $self->_write_vector_flanking_sequences($vector, $flanking_writer)
            or return;
    }

    return 1;
}

sub _write_vector_sequence {
    my ($self, $vector, $writer) = @_;

    my $vector_name = $vector->vector_name;
    my $vector_linearization = $vector->get_vector_linearization;
    my $seq = $vector_linearization->sequence;
    unless ( $seq ) {
        $self->error_message("No linearized vector sequence for vector ($vector_name)");
        return;
    }
    
    my $bioseq;
    eval {
        $bioseq = Bio::Seq->new(
            '-id' => $vector_name,
            '-alphabet' => 'dna',
            '-seq' => $seq,
        );
    };

    unless ( $bioseq ) {
        $self->error_message("Can't create Bio::Seq for vector sequence: $!");
        return;
    }

    return $writer->write_seq($bioseq);
}

sub _write_vector_flanking_sequences {
    my ($self, $vector, $writer) = @_;

    my $vector_name = $vector->vector_name;
    my $vector_linearization = $vector->get_vector_linearization;

    # 5 prime
    my $five_prime_seq = $vector_linearization->end_sequence_five_prime;
    unless ( $five_prime_seq ) {
        $self->error_message("No linearized vector sequence for vector ($vector_name)");
        return;
    }
    my $length = length($five_prime_seq);
    my $five_prime_flank = substr($vector_linearization->end_sequence_five_prime, (length($five_prime_seq) - 40)); 
    my $five_prime_flank_bioseq;
    my $five_prime_flank_desc = "5 prime flanking";
    eval {
        $five_prime_flank_bioseq = Bio::Seq->new(
            '-id' => $vector_name,
            '-desc' => $five_prime_flank_desc,
            '-alphabet' => 'dna',
            '-force_flush' => 1,
            '-seq' => $five_prime_flank,
        );
    };

    unless ( $five_prime_flank_bioseq ) {
        $self->error_message("Can't create Bio::Seq for vector sequence: $!");
        return;
    }

    $writer->write_seq($five_prime_flank_bioseq);
=cut
    ## No longer writing the revcom seq to the flanking file.  This causes some sequences to be tagged as vector because each 'hit' to the flanking file is seen as evidence of vector - we guess.

    my $revcom_five_prime_flank_bioseq = $five_prime_flank_bioseq->revcom;
    $revcom_five_prime_flank_bioseq->desc($five_prime_flank_desc.' revcom');
    $writer->write_seq($revcom_five_prime_flank_bioseq);
=cut

    # 3 prime
    my $three_prime_seq = $vector_linearization->end_sequence_three_prime;
    unless ( $three_prime_seq ) {
        $self->error_message("No linearized vector sequence for vector ($vector_name)");
        return;
    }
    my $three_prime_flank = substr($vector_linearization->end_sequence_three_prime, 0, 40);
    my $three_prime_flank_bioseq;
    my $three_prime_flank_desc = "3 prime flanking";
    eval {
        $three_prime_flank_bioseq = Bio::Seq->new(
            '-id' => $vector_name,
            '-desc' => $three_prime_flank_desc,
            '-alphabet' => 'dna',
            '-force_flush' => 1,
            '-seq' => $three_prime_flank,
        );
    };

    unless ( $three_prime_flank_bioseq ) {
        $self->error_message("Can't create Bio::Seq for vector sequence: $!");
        return;
    }

    $writer->write_seq($three_prime_flank_bioseq);
=cut
    ## No longer writing the revcom seq to the flanking file.  This causes some sequences to be tagged as vector because each 'hit' to the flanking file is seen as evidence of vector - we guess.
    
    my $revcom_three_prime_flank_bioseq = $three_prime_flank_bioseq->revcom;
    $revcom_three_prime_flank_bioseq->desc($three_prime_flank_desc.' revcom');
    $writer->write_seq($revcom_three_prime_flank_bioseq);
=cut

    return 1;
}

#< Screen Files >#
sub _screen_fasta_and_qual_files {
    my $self = shift;

    #< Original fasta and qual >#
    my $fasta_reader = $self->get_fasta_reader( $self->fasta_file )
        or return;
    my $qual_reader = $self->get_qual_reader( $self->qual_file )
        or return;
    
    #< Lucy positions file >#
    my $lucy_reader = Genome::Model::Tools::Fasta::Trim::LucyReader->create(
        input => $self->_tmp_lucy_file,
    );
    unless ( $lucy_reader ) {
        $self->error_message('Can\'t create lucy position file reader');
        return;
    }

    #< Output fasta - qual does not change >#
    my $output_fasta_file = $self->output_fasta_file;
    unlink $output_fasta_file if -e $output_fasta_file;
    my $fasta_writer = $self->get_fasta_writer($output_fasta_file)
        or return;
 
    LUCY: while ( my $lucy = $lucy_reader->next ) {
        my ($fasta, $qual);
        do {
            $fasta = $fasta_reader->next_seq;
            $qual = $qual_reader->next_seq;
            unless ( $fasta ) {
                $self->error_message("Out of original fastas, but still have one to write from lucy");
                return;
            }
        } until $fasta->id eq $lucy->{id};

        # Skip if both clr values are zero
        next if $lucy->{clr_left} == 0 and $lucy->{clr_right} == 0;
        
        # Trim
        my $left_seq = '';
        my $right_seq = '';
        # Left
        if ( $lucy->{clr_left} ) { # Trim on the left
            if ( $lucy->{clv_left} >= $lucy->{cln_left} ) { # lq then vector
                # Xs up to, not including, clv_left
                $left_seq = 'N' x ( $lucy->{cln_left} - 1 ); # if -1, then nothing happens
                # Ns up to the clr_left value
                $left_seq .= 'X' x ( $lucy->{clr_left} - length($left_seq) - 1 );
            }
            else { # vector then lq
                # Ns up to, not including, cln_left
                $left_seq = 'X' x ( $lucy->{clv_left} - 1 ); # if -1, then nothing happens
                # Xs up to the clr_left value
                $left_seq .= 'N' x ( $lucy->{clr_left} - length($left_seq) - 1 );
            }

            # check left seq length
            unless ( ( $lucy->{clr_left} - 1 ) eq length($left_seq) ) {
                $self->error_message("Miscalculated the left trimmed sequence:");
                print Dumper([{
                        seq => $left_seq, 
                        'length' => length($left_seq) 
                    },
                    $lucy,
                    ]);
                return;
            }
        }

        # Right
        my $fasta_length = $fasta->length;
        if ( $lucy->{clr_right} ) { # Trim on the right
            if ( $lucy->{clv_right} >= $lucy->{cln_right} ) { # lq then vector
                my $number_of_xs = ( $lucy->{clv_right} )
                ? $fasta_length - $lucy->{clv_right}
                : 0;
                # Xs up to the clr_right value
                $right_seq = 'N' x ( $fasta_length - $lucy->{clr_right} - $number_of_xs );
                # Add Ns
                $right_seq .= 'X' x $number_of_xs;
            }
            else { # vector then lq
                # Get number of Ns up to, not including, clv_right
                my $number_of_ns = ( $lucy->{cln_right} )
                ? $fasta_length - $lucy->{cln_right}
                : 0;
                # Xs up to the clr_right value
                $right_seq = 'X' x ( $fasta_length - $lucy->{clr_right} - $number_of_ns );
                # Add Ns
                $right_seq .= 'N' x $number_of_ns;
            }

            # check right seq length
            unless ( ( $fasta_length - $lucy->{clr_right} ) eq length($right_seq) ) {
                $self->error_message("Miscalculated the right trimmed sequence:");
                print Dumper([{ 
                        seq => $right_seq, 
                        'length' => length($right_seq),
                        expected_length => $fasta_length - $lucy->{clr_right},
                        fasta_length => $fasta_length,
                    }, 
                    $lucy,
                    ]);
                return;
            }
        }

        my $seq = join(
            '',
            $left_seq,
            substr(
                $fasta->seq, 
                length($left_seq), 
                $fasta_length - ( length($right_seq) + length($left_seq) ),
            ),
            $right_seq,
        );

        # check the new seq length matches the untrimmed one
        unless ( $fasta_length eq length($seq) ) {
            $self->error_message("Miscalculated the trimmed sequence:");
            print Dumper([{ 
                    'length' => length($seq),
                    expected_length => $fasta_length,
                }, 
                $lucy,
                ]);

            return;
        }

        #print Dumper( { seq_l=>length($seq), right_seq_l=>length($right_seq), left_seq_l=>length($left_seq), fasta_l => $fasta_length, clr_l=>$lucy->{clr_left}, clr_r=>$lucy->{clr_right}, });

        # Write 
        my $newseq = Bio::Seq->new(
            '-id' => $fasta->id,
            '-desc' => $fasta->desc,
            '-alphabet' => 'dna',
            '-seq' => uc($seq),
        );
        $fasta_writer->write_seq($newseq);
    }

    return 1;
}

1;

=pod

=head1 Name

Genome::Model::Tools::Fasta::Trim::Lucy

=head1 Synopsis

A wrapper for lucy, a command line executable for trimming quality and vector in FASTAs.  This module not only runs lucy, it will fetch the vector FASTAs and flanking regions, and mask the FASTA file with the lucy results.

=head1 Usage

my $lucy = Genome::Model::Tools::Fasta::Trim::Lucy->create(
) or die;
$lucy->execute or die;

=head1 Methods

=head2 create

 my $lucy = Genome::Model::Tools::Fasta::Trim::Lucy->create(
    fasta_file => $fasta, # REQUIRED - Fasta file.  Also must have quality file named with a '.qual' extentsion
    vector_name => $vector, # REQUIRED - Name of vector to screen against.
    keep_lucy_file => 1, # OPTIONAL - Keep the lucy 'debug' file.  Default is 0.
 )
    or die;

=over

=item I<Synopsis>   Creates a lucy command object.

=item I<Arguments>  see above

=item I<Returns>    A lucy command object.

=back

=head2 execute

 my $rv = $lucy->execute
    or die;

=over

=item I<Synopsis>   Executes the lucy command.

=item I<Arguments>  None.

=item I<Returns>    Boolean - true for success, false for failure

=back

=head1 See Also

B<lucy>, B<Genome::Model::Tools::Fasta>

=head1 Disclaimer

Copyright (C) 2009 The Genome Center @ Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
