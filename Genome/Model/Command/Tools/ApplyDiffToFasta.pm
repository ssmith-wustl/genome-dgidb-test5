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
    ],
    has_optional => [
    output => { is => 'String', doc => 'path to output file for new patched fasta file', is_optional => 1 },
    flank_size => { is => 'Int', doc => 'length of flanking bases on either side of a diff to export', default => 0 },
    diff_flank_file => { is => 'string', doc => 'path to file containing flanking sequence of diff areas and the modified sequence' },
    ref_flank_file => { is => 'string', doc => 'path to file containing flanking sequence of diff areas and the original ref sequence' },
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

#ERROR HANDLE ON FAILURE
    $self->error_messages_callback(
        sub{
            $self->status_message("Removing output files due to error");
            unlink $self->output; 
            unlink $self->diff_flank_file if $self->diff_flank_file;
            unlink $self->ref_flank_file if $self->ref_flank_file;
        }
    );

#INPUT/OUTPUT STREAMS;
    my $fasta_stream    = Genome::Utility::FastaStream->new($self->input);
    my $diff_stream     = Genome::Utility::DiffStream->new($self->diff);

    my $diff_flank_stream;
    my $ref_flank_stream;
    my $output_stream;
    $diff_flank_stream = Genome::Utility::OutputBuffer->new($self->diff_flank_file) if $self->diff_flank_file;
    $ref_flank_stream =  Genome::Utility::OutputBuffer->new($self->ref_flank_file) if $self->ref_flank_file;
    $output_stream   = Genome::Utility::OutputBuffer->new($self->output ) if $self->output;

#LOOP VARIABLES
    my $pre_diff_sequence;
    my $post_diff_sequence;
    my $skip_diff;

    my $read_position = 0;
    my $buffer;
    my $write_position = 0;

    my $flank_header = 1; 
    my $ref_flank_sequence;
    my $diff_flank_sequence;
    
    my $flank_size = $self->flank_size;
    my $min_flank_size; #used to at least grab pre and post diff sequence if they are present
    my $left_flank_position;
    my $right_flank_position;

    my $first_part_length;
    my $first_part;
   
    my $current_fasta_header = '';
    my $current_fasta_header_line;

    my $successful_diffs = 0;
    my $attempted_diffs;
    my @failed_diffs;

###########################################################
#MAIN LOOP
    
    while (my $diff = $diff_stream->next_diff){

        $DB::single = 1;

        # leftover buffer from previous diff
        $output_stream->print($buffer) if $output_stream;
        $buffer = undef;

        #generate flanking positions
        $min_flank_size         = length $diff->{pre_diff_sequence} <=> length $diff->{post_diff_sequence} ? 
                                    length $diff->{post_diff_sequence} : 
                                    length $diff->{pre_diff_sequence};
        $flank_size             = $min_flank_size if $min_flank_size > $flank_size;
        $left_flank_position    = $diff->{position} - $flank_size;
        $left_flank_position    = 0 if $left_flank_position < 0;
        $right_flank_position   = $diff->{position} + ( length $diff->{delete} ) + $flank_size;

    #ADVANCE THROUGH THE FASTA FILE UNTIL CURRENT FASTA SECTION HEADER EQ DIFF HEADER
       until ($current_fasta_header eq $diff->{header}) { 

            #print out entire fasta section if still not at diff->{header} in fasta
            while ($buffer = $fasta_stream->next_line){
                $output_stream->print($buffer) if $output_stream;
            }
            $buffer = undef;
            
            #grab next header and reset write position
            unless ( $current_fasta_header = $fasta_stream->next_header ){
                use Data::Dumper;
                $self->error_message( "Can't get next fasta header and we still have diffs to process!\n".Dumper $diff);
                return;
            }
            
            $write_position = 0;
            $read_position = 0;
            $current_fasta_header_line = $fasta_stream->current_header_line;
            $output_stream->print_header($current_fasta_header_line) if $output_stream;
            
        }        

    #ERROR CHECK
        if ($write_position > $diff->{position}) {
            $self->error_message(
                "Write position is greater than diff(header:".$diff->{header}.") position! We've missed the boat! $write_position > ".$diff->{position}
            );
            return;
        } 

    #ADVANCE FASTA TO LEFT FLANK OF CURRENT DIFF

        while( $write_position <= $left_flank_position){ 
            unless (defined $buffer){
                $buffer = $fasta_stream->next_line;
                unless ($buffer){ 
                    $self->error_message(
                        "hit the end of the section and haven't reached the current diff's(header:".$diff->{header}.") left flank position! $write_position < ".$left_flank_position
                    );
                    return;
                }
                $read_position = $read_position + length $buffer;
            }
            last if $read_position >= $left_flank_position; #current buffered line contains start of flank
            $output_stream->print($buffer) if $output_stream;
            $buffer = undef;
            $write_position = $read_position;
        }

    #ADVANCE THROUGH BUFFER UNTIL FLANK POSITION
        $first_part_length = $left_flank_position - $write_position;
        $first_part = substr($buffer, 0,  $first_part_length, ''); 

        $output_stream->print($first_part) if $output_stream;

        $write_position += $first_part_length;

        $diff_flank_sequence = ''; 
        $ref_flank_sequence = '';

    #STARTING HERE WE CAN REPEAT PROCESS UNTIL WE'VE REACHED THE END OF THE FLANK SECTION IF RIGHT FLANK OF THE CURRENT DIFF OVERLAPS THE LEFT FLANK OF THE NEXT DIFF
        while( defined $diff_flank_sequence and defined $ref_flank_sequence ){

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

                $output_stream->print($buffer) if $output_stream; #otherwise,
                $diff_flank_sequence .= $buffer; 
                $ref_flank_sequence .= $buffer;
                $buffer = undef; 
                $write_position = $read_position;
            }

            $first_part_length = $diff->{position} - $write_position;
            $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

            $output_stream->print($first_part) if $output_stream;
            $write_position += $first_part_length;
            $diff_flank_sequence .= $first_part;
            $ref_flank_sequence .= $first_part;

            if ( $diff->{pre_diff_sequence} ) {
                $pre_diff_sequence = substr($ref_flank_sequence, (0 - length( $diff->{pre_diff_sequence} ) ) );
                unless ( $pre_diff_sequence eq $diff->{pre_diff_sequence} ) {
                    $self->status_message("pre_diff_sequence in diff(header:".$diff->{header}." pos:".$diff->{position}.") does not match actual fasta sequence! fasta:$pre_diff_sequence not eq diff:".$diff->{pre_diff_sequence}."  Diff not processed!" );
                    $skip_diff = 1;
                }
            }

            if ( $diff->{post_diff_sequence} and !$skip_diff ) {
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
                $output_stream->print($diff->{insert}) if $output_stream;
                $diff_flank_sequence .= $diff->{insert};  #diff flank gets the insert
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
                $ref_flank_sequence.=$deletion; 
                
                unless ($deletion eq $to_delete){ 
                    $self->status_message( "deleted seq does not equal actual sequence! $deletion != $to_delete  chrom: $current_fasta_header position: $write_position $first_part - $deletion - $buffer ". ($diff->{position} + 1) ."\n");
                $skip_diff = 1;
                }
                $write_position += length $deletion unless $skip_diff;
            }

            $successful_diffs++ unless $skip_diff;
            
            if ( defined $diff_stream->next_diff_position and $right_flank_position > $diff_stream->next_diff_position - $flank_size ){ #now check if the tail of the flank overlaps the next diff flank
                $diff = $diff_stream->next_diff;
                $skip_diff = 0;

            }else{

#ADVANCE FASTA TO DIFF POSITION, FLANK PRINTING STARTS HERE
                while( $write_position <= $right_flank_position){ 

                    unless (defined $buffer){
                        $buffer = $fasta_stream->next_line;
                        unless ($buffer){ 
                            $buffer = ''; #end of section
                            $right_flank_position = $write_position;
                        }
                        $read_position = $read_position + length $buffer;
                    }

                    last if $read_position >= $right_flank_position; #current buffered line contains diff pos

                    $output_stream->print($buffer) if $output_stream; #otherwise, add to flank and print buffer
                    $diff_flank_sequence .= $buffer; 
                    $ref_flank_sequence .= $buffer;
                    $buffer = undef;
                    $skip_diff = 0;
                    $write_position = $read_position;
                }

                $first_part_length = $right_flank_position - $write_position;
                $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

                $output_stream->print($first_part) if $output_stream;
                $write_position += $first_part_length;
                $diff_flank_sequence .= $first_part;
                $ref_flank_sequence .= $first_part;

                if ( length $diff_flank_sequence and $diff_flank_stream){
                    $diff_flank_stream->print_header(">$current_fasta_header ($flank_header)");
                    $diff_flank_stream->print($diff_flank_sequence);
                }
                if ( length $ref_flank_sequence and $ref_flank_stream){
                    $ref_flank_stream->print_header(">$current_fasta_header|".$diff->{position}." (Diff #$flank_header, flank size $flank_size)");
                    $ref_flank_stream->print($ref_flank_sequence);
                }
                $diff_flank_sequence = undef;
                $ref_flank_sequence = undef;
                $flank_header++;
            }
        }
    }
#FINISH PRINTING BUFFER
    if ($output_stream){
        $output_stream->print($buffer);
        while (my $line= $fasta_stream->next_line){
            $output_stream->print($line);
        }

#FINISH PRINTING FASTA FILE
        while (my $current_header = $fasta_stream->next_header){
            $output_stream->print_header($fasta_stream->current_header_line);
            while (my $line= $fasta_stream->next_line){
                $output_stream->print($line);
            }
        }
    }

    $self->status_message("Diffs processed successfully: $successful_diffs");

    $output_stream->close() if $output_stream;
    $ref_flank_stream->close() if $ref_flank_stream;
    $diff_flank_stream->close() if $diff_flank_stream;

    return 1;
}

=cut

1;
