package Genome::Model::Command::Tools::ApplyDiffToFasta;

use strict;
use warnings;

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
    diff => { is => 'String', doc => 'path to diff file containing inserts and deletes' },
    output => { is => 'String', doc => 'path to output file for new patched fasta file' },
    chunk => {is => 'String', doc => 'max size of sequence to load into memory', default => 15000 },
    ],
);

sub help_brief {
    "Applies seqeunce inserts and deletes from a sorted diff file to a fasta file, and produces the patched output"; 
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
    $DB::single =1;


    my $output_stream = Genome::Utility::OutputBuffer->new($self->output );
    my $diff_stream = Genome::Utility::DiffStream->new($self->diff ); 
    my $fasta_stream = Genome::Utility::FastaStream->new($self->input ); #file or bioseq object


    my $read_position=0;
    my $buffer;
    my $write_position=0;

#use these for error checking
    my $last_diff_header='';
    my $last_fasta_header='';
    my $last_diff_pos = 0;

#print first header
    $last_fasta_header = $fasta_stream->next_header;
    $output_stream->print_header($fasta_stream->current_header_line);


    while (my $diff = $diff_stream->next_diff){

        my $numeric;
        my $cross;
        #error checking
        #if ($diff->{header} lt $last_diff_header){ #TODO currently last diff header is not set, if we do use this, make sure we take into account the numeric possibility
        #    $self->error_message("Diff header in incorrect order");
        #    return;
        #}

        until ($diff->{header} eq $last_fasta_header) {
            
            if($diff->{header} lt $last_fasta_header) {
                unless ($diff->{header} =~ /^\d+$/ and $last_fasta_header =~ /^\d+$/ and $diff->{header} >= $last_fasta_header){
                    unless (($diff->{header} =~ /^[A-Z]+$/ and $last_fasta_header =~ /^\d+$/) or ($diff->{header} =~ /^\d+$/ and $last_fasta_header =~ /^[A-Z]+$/)){
                            $self->error_message("Header from diff is less than the current/last fasta header! ".$diff->{header}." lt $last_fasta_header");
                            return;
                        }
                    $cross = 1;
                }
                $numeric = 1;
                
            }
            if($diff->{header} gt $last_fasta_header or $cross or ($numeric and $diff->{header} > $last_fasta_header )){

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

                my $current_fasta_header_line = $fasta_stream->current_header_line;
                $read_position =0;
                $write_position=0;
                if ($current_fasta_header lt $last_fasta_header){
                    unless ($cross or ($numeric and $current_fasta_header >= $last_fasta_header)){
                        $self->error_message( "Current fasta header is less than the last fasta header! $current_fasta_header lt $last_fasta_header" );
                        return;
                    }
                }
                $cross = 0;
                $numeric = 0;

                $last_fasta_header = $current_fasta_header;
                $output_stream->print_header($current_fasta_header_line);
                redo;

            }        
        }

        if ($write_position > $diff->{position}) {
            $self->error_msg("Write position is greater than diff postion! We've missed the boat! $write_position > ".$diff->{position});
            return;
        }

        $DB::single = 1;

        while( $write_position <= $diff->{position}){
            unless (defined $buffer){
                $buffer = $fasta_stream->next_line;
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
            $write_position += length $ref;
            my $del = substr($buffer, $first_part_length, length $ref); #check buffer at this point
            unless ($del eq $ref){ #TODO clean up these var names to be clearer, in diffstream.pm as well.
                $self->error_message("deleted seq ref does not equal actual sequence! $del != $ref ");
                return ;
            }

            while ($write_position > $read_position){
                $buffer = $fasta_stream->next_line;
                $read_position += length $buffer;
            }
            $buffer = substr($buffer, (length $buffer) - ($read_position - $write_position) );
        }
        else {
            # nothing removed
            $buffer = substr($buffer,$first_part_length);
        }

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
