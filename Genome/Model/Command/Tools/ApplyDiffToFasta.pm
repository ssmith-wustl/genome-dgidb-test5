package Genome::Model::Command::Tools::ApplyDiffToFasta;

use strict;
use warnings;

use Data::Dumper;
use Genome::Utility::OutputBuffer;
use Genome::Utility::DiffStream;
use Genome::Utility::FastaStream;
use above "Genome";
use Command;
use GSCApp;

use IO::File;


UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
    input => { is => 'String', doc => 'path to input fasta file to apply diff to' },
    diff => { is => 'string', doc => 'path to diff file containing inserts and deletes' },
    output => { is => 'String', doc => 'path to output file for new patched fasta file' },
    #diff_flank_file => { is => 'string', doc => 'path to file containing flanking sequence of diff areas and the modified sequence' },
    #ref_flank_file => { is => 'string', doc => 'path to file containing flanking sequence of diff areas and the original ref sequence' },
    ],
);

sub help_brief {
    "Applies sequence inserts and deletes from a sorted diff file to a fasta file, and produces the patched output"; 
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
Given a diff file ( format:<subject> <chromosome> <position> <reference_bases> <patch_bases>)
sorted by sub/chromosome and position, applies these inserts and deletes to a given fasta
file sorted by header.  Writes out the patched fasta data to a new fasta file, output;

quality, find the original fastq's they came from and create a new
fastq with just these reads
EOS
}


sub execute {
    my $self = shift;

    my $fasta_stream = Genome::Utility::FastaStream->new($self->input ); #file or bioseq object
    my $diff_stream = Genome::Utility::DiffStream->new($self->diff ); 

    $self->error_messages_callback(
        sub{ unlink $self->output; }
    );
    my $output_stream = Genome::Utility::OutputBuffer->new($self->output );
    #my $diff_flank_stream = Genome::Utility::OutputBuffer->new($self->diff_flank_file);
    #my $ref_flank_stream =  Genome::Utility::OutputBuffer->new($self->ref_flank_file);

    my $read_position=0;
    my $buffer;
    my $write_position=0;

#print first header
    my $last_fasta_header = $fasta_stream->next_header;
    $output_stream->print_header($fasta_stream->current_header_line);

    while (my $diff = $diff_stream->next_diff){

        $DB::single = 1;

        until ($diff->{header} eq $last_fasta_header) {
            $output_stream->print($buffer);
            $buffer = undef;
            my $row;
            while ($row = $fasta_stream->next_line){
                $output_stream->print($row);
            }

            my $current_fasta_header;
            unless ( $current_fasta_header = $fasta_stream->next_header ){
                use Data::Dumper;
                $self->error_message( "Can't get next fasta header and we still have diffs to process!\n".Dumper $diff);
                return;
            }
            $write_position = 0;
            $read_position = 0;

            my $current_fasta_header_line = $fasta_stream->current_header_line;

            $last_fasta_header = $current_fasta_header;
            $output_stream->print_header($current_fasta_header_line);

        }        

        if ($write_position > $diff->{position}) {
            $self->error_message("Write position is greater than diff postion! We've missed the boat! $write_position > ".$diff->{position});
            return;
        }

        while( $write_position <= $diff->{position}){
            unless (defined $buffer){
                $buffer = $fasta_stream->next_line;
                unless ($buffer){
                    $self->error_message("Hit the end of the section and haven't reached the current diff's position! $write_position < ".$diff->{position});
                    return;
                }
                $read_position = $read_position + length $buffer;
            }

            last if $read_position >= $diff->{position};

            $output_stream->print($buffer);
            $buffer = undef;
            $write_position = $read_position;
        }

        my $first_part_length = $diff->{position} - $write_position;
        my $first_part = substr($buffer, 0,  $first_part_length);
        $output_stream->print($first_part);
        $write_position += $first_part_length;

        $output_stream->print($diff->{patch});

        if ($diff->{ref}) {
            # cutting out sequence
            my $ref = $diff->{ref};
            while (length($ref) > length($buffer) - $first_part_length) {
              my $nextline = $fasta_stream->next_line;
              unless ($nextline)
                {
                $self->error_message("ref($ref) substring extends beyond end of sequence, ending ($buffer)");
                return;
                }
              $buffer .= $nextline;
              $read_position += length $nextline;
            }

            my $del = substr($buffer, $first_part_length, length $ref); #check buffer at this point
            unless ($del eq $ref){ #TODO clean up these var names to be clearer, in diffstream.pm as well.
                $self->error_message("deleted seq ref does not equal actual sequence! $del != $ref ");
                return ;
            }
            $first_part_length += length $ref;
            $write_position    += length $ref;
        }
        $buffer = substr($buffer, $first_part_length);
    }

    $output_stream->print($buffer);
    while (my $line= $fasta_stream->next_line){
        $output_stream->print($line);
    }
    
    while (my $current_header = $fasta_stream->next_header){
        $output_stream->print_header($fasta_stream->current_header_line);
        while (my $line= $fasta_stream->next_line){
            $output_stream->print($line);
        }
    }

    $output_stream->close();

    return 1;
}
1;
