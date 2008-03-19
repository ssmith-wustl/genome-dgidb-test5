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
    flank_size => { is => 'Int', doc => 'length of flanking bases on either side of a diff to export', default => 0 },
    diff_flank_file => { is => 'string', doc => 'path to file containing flanking sequence of diff areas and the modified sequence', is_optional => 1 },
    ref_flank_file => { is => 'string', doc => 'path to file containing flanking sequence of diff areas and the original ref sequence', is_optional => 1 },
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
    my $diff_stream = Genome::Utility::DiffStream->new($self->diff, $self->flank_size); 

    $self->error_messages_callback(
        sub{
            $self->status_message("Removing output files due to error");
            unlink $self->output; 
            unlink $self->diff_flank_file if $self->diff_flank_file;
            unlink $self->ref_flank_file if $self->ref_flank_file;
        }

    );

    my $output_stream = Genome::Utility::OutputBuffer->new($self->output );

    my $diff_file = $self->diff_flank_file || '/dev/null';
    my $ref_file = $self->ref_flank_file || '/dev/null';
    my $diff_flank_stream = Genome::Utility::OutputBuffer->new($diff_file);
    my $ref_flank_stream =  Genome::Utility::OutputBuffer->new($ref_file);

#THESE ARE USED FOR VERIFYING PRE AND POST DIFF SEQUENCE
    my $pre_diff_sequence;
    my $post_diff_sequence;
    my $skip_diff;

    my $read_position = 0;
    my $buffer;
    my $write_position = 0;
    my $flank_header = 1; 
    my $ref_flank;
    my $diff_flank;
    my $first_part_length;
    my $first_part;
    my $successful_diffs = 0;

#PRINT FIRST HEADER
    my $last_fasta_header = $fasta_stream->next_header;
    $output_stream->print_header($fasta_stream->current_header_line);

    while (my $diff = $diff_stream->next_diff){

        $DB::single = 1;


###########################################################
#ADVANCE THROUGH THE FASTA FILE UNTIL SECTION HEADER EQ DIFF HEADER
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
        #
###########################################################

        if ($write_position > $diff->{position}) {
            $self->error_message("Write position is greater than diff(header:".$diff->{header}.") position! We've missed the boat! $write_position > ".$diff->{position});
            return;
        } 

############################################
#ADVANCE FASTA TO LEFT FLANK OF CURRENT DIFF
        while( $write_position <= $diff->{left_flank_position}){ 
            unless (defined $buffer){
                $buffer = $fasta_stream->next_line;
                unless ($buffer){ 
                    $self->error_message(
                        "hit the end of the section and haven't reached the current diff's(header:".$diff->{header}.") left flank position! $write_position < ".$diff->{left_flank_position}
                    );
                    return;
                }
                $read_position = $read_position + length $buffer;
            }
            last if $read_position >= $diff->{left_flank_position}; #current buffered line contains start of flank
            $output_stream->print($buffer);
            $buffer = undef;
            $write_position = $read_position;
        }

############################################
#ADVANCE THROUGH BUFFER UNTIL FLANK POSITION
        $first_part_length = $diff->{left_flank_position} - $write_position;
        $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

        $output_stream->print($first_part);
        $write_position += $first_part_length;
        $diff_flank = ''; #define flank to start the tight loop
        $ref_flank = '';

#############################################################################################
#STARTING HERE WE CAN REPEAT PROCESS UNTIL WE'VE REACHED THE END OF THE FLANK SECTION IF RIGHT FLANK OF THE CURRENT DIFF OVERLAPS THE LEFT FLANK OF THE NEXT DIFF
        while( defined $diff_flank and defined $ref_flank ){

            while( $write_position <= $diff->{position}){ #advance fasta to diff position, flank printing starts here
                unless (defined $buffer){
                    $buffer = $fasta_stream->next_line;
                    unless ($buffer){ #fail condition
                        $self->error_message(
                            "Hit the end of the section and haven't reached the current diff's (header:".$diff->{header}.") position! $write_position < ".$diff->{position}
                        );
                        return;
                    }
                    $read_position = $read_position + length $buffer;
                }

                last if $read_position >= $diff->{position}; #current buffered line contains diff pos

                $output_stream->print($buffer); #otherwise, 
                $diff_flank .= $buffer; 
                $ref_flank .= $buffer;
                $buffer = undef; 
                $write_position = $read_position;
            }

            $first_part_length = $diff->{position} - $write_position;
            $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

            $output_stream->print($first_part);
            $write_position += $first_part_length;
            $diff_flank .= $first_part;
            $ref_flank .= $first_part;

            if ( defined $diff->{pre_diff_sequence} ) {
                $pre_diff_sequence = substr($ref_flank, (0 - length( $diff->{pre_diff_sequence} ) ) );
                unless ( $pre_diff_sequence eq $diff->{pre_diff_sequence} ) {
                    $self->status_message("pre_diff_sequence in diff(header:".$diff->{header}." pos:".$diff->{position}.") does not match actual fasta sequence! fasta:$pre_diff_sequence not eq diff:".$diff->{pre_diff_sequence}."  Diff not processed!" );
                    $skip_diff = 1;
                }
            }

            if ( defined $diff->{post_diff_sequence} and !$skip_diff ) {
                my $length = length ( $diff->{post_diff_sequence} );
                my $del_length = length ( $diff->{delete} );
                while ( ($length + $del_length) > length $buffer ){
                    my $nextline = $fasta_stream->next_line;
                    unless ($nextline){
                        $self->error_message("length of post diff(header:".$diff->{header}." pos:".$diff->{position}.") sequence goes beyond end of file!");
                        return;
                    }
                    $buffer.=$nextline;
                    $read_position += length $nextline;
                }
                $post_diff_sequence = substr($buffer, $del_length, $length);
                unless ( $post_diff_sequence eq $diff->{post_diff_sequence} ){
                    $self->status_message("post_diff_sequence in diff(header:".$diff->{header}." pos:".$diff->{position}.") does not match actual fasta sequence! fasta:$post_diff_sequence not eq diff:".$diff->{post_diff_sequence}."  Diff not processed!" );
                    $skip_diff = 1;
                }
            }

            if ($diff->{insert} and !$skip_diff){
                $output_stream->print($diff->{insert});
                $diff_flank .= $diff->{insert};  #diff flank gets the insert
            }

#REF FLANK GETS THE DELETE, OUTPUT_STREAM DOESNT SEQUENCE
            if ($diff->{delete} and !$skip_diff) { 
                my $to_delete = $diff->{delete};
                while ( length($to_delete) > length($buffer) ) {  
                    my $nextline = $fasta_stream->next_line;
                    unless ($nextline){ #fail condition
                        $self->error_message("deletion($to_delete) substring extends beyond end of sequence, ending ($buffer)");
                        return;
                    }
                    $buffer .= $nextline;
                    $read_position += length $nextline;
                }
                my $deletion = substr($buffer, 0, length $to_delete, ''); #check buffer at this point
                $ref_flank.=$deletion; 
                
                unless ($deletion eq $to_delete){ 
                    $self->status_message( "deleted seq does not equal actual sequence! $deletion != $to_delete  chrom: $last_fasta_header position: $write_position $first_part - $deletion - $buffer ". ($diff->{position} + 1) ."\n");
                $skip_diff = 1;
                }
                $write_position += length $deletion unless $skip_diff;
            }

            $successful_diffs++ unless $skip_diff;
            
            if ( defined $diff_stream->next_left_flank_position and $diff->{right_flank_position} > $diff_stream->next_left_flank_position ){ #now check if the tail of the flank overlaps the next diff flank
                $diff = $diff_stream->next_diff;
                $skip_diff = 0;

            }else{

#ADVANCE FASTA TO DIFF POSITION, FLANK PRINTING STARTS HERE
                while( $write_position <= $diff->{right_flank_position}){ 

                    unless (defined $buffer){
                        $buffer = $fasta_stream->next_line;
                        unless ($buffer){ 
                            $buffer = ''; #end of section
                            $diff->{right_flank_position} = $write_position;
                        }
                        $read_position = $read_position + length $buffer;
                    }

                    last if $read_position >= $diff->{right_flank_position}; #current buffered line contains diff pos

                    $output_stream->print($buffer); #otherwise, add to flank and print buffer
                    $diff_flank .= $buffer; 
                    $ref_flank .= $buffer;
                    $buffer = undef;
                    $skip_diff = 0;
                    $write_position = $read_position;
                }

                $first_part_length = $diff->{right_flank_position} - $write_position;
                $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

                $output_stream->print($first_part);
                $write_position += $first_part_length;
                $diff_flank .= $first_part;
                $ref_flank .= $first_part;

                if ( length $diff_flank ){
                    $diff_flank_stream->print_header(">$last_fasta_header ($flank_header)");
                    $diff_flank_stream->print($diff_flank);
                }
                if ( length $ref_flank ){
                    $ref_flank_stream->print_header(">$last_fasta_header ($flank_header)");
                    $ref_flank_stream->print($ref_flank);
                }
                $diff_flank = undef;
                $ref_flank = undef;
                $flank_header++;
            }
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

    $self->status_message("Diffs processed successfully: $successful_diffs");

    $output_stream->close();

    return 1;
}

=cut

1;
