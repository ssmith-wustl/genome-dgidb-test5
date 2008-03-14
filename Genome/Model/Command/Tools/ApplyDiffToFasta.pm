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
    $| = 1;

    my $fasta_stream = Genome::Utility::FastaStream->new($self->input ); #file or bioseq object
    my $diff_stream = Genome::Utility::DiffStream->new($self->diff, $self->flank_size); 

    $self->error_messages_callback(
        sub{
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

    my $read_position=0;
    my $buffer;
    my $write_position=0;
    my $flank_header = 1;
    my $ref_flank;
    my $diff_flank;
    my $first_part_length;
    my $first_part;

#print first header
    my $last_fasta_header = $fasta_stream->next_header;
    $output_stream->print_header($fasta_stream->current_header_line);

    while (my $diff = $diff_stream->next_diff){

        $DB::single = 1;

        until ($diff->{header} eq $last_fasta_header) { #advance through the fasta file until section header eq diff header
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

        while( $write_position <= $diff->{left_flank}){ #advance fasta to left flank of current diff
            unless (defined $buffer){
                $buffer = $fasta_stream->next_line;
                unless ($buffer){ #fail condition
                    $self->error_message(
                        "Hit the end of the section and haven't reached the current diff's left flank position! $write_position < ".$diff->{left_flank}
                    );
                    return;
                }
                $read_position = $read_position + length $buffer;
            }
            last if $read_position >= $diff->{left_flank}; #current buffered line contains start of flank
            $output_stream->print($buffer);
            $buffer = undef;
            $write_position = $read_position;
        }

        #advance through buffer until flank position
        $first_part_length = $diff->{left_flank} - $write_position;
        $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

        $output_stream->print($first_part);
        $write_position += $first_part_length;
        $diff_flank = ''; #define flank to start the tight loop
        $ref_flank = '';

        #################starting here we can repeat process until we've reached the end of the flank section
        while( defined $diff_flank and defined $ref_flank ){

            while( $write_position <= $diff->{position}){ #advance fasta to diff position, flank printing starts here
                unless (defined $buffer){
                    $buffer = $fasta_stream->next_line;
                    unless ($buffer){ #fail condition
                        $self->error_message(
                            "Hit the end of the section and haven't reached the current diff's position! $write_position < ".$diff->{position}
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

            if ($diff->{insert} ){
                $output_stream->print($diff->{insert});
                $diff_flank .= $diff->{insert};  #diff flank gets the insert
            }

            if ($diff->{delete}) { #ref flank gets the delete, output_stream doesnt sequence
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
                $write_position += length $deletion;

                unless ($deletion eq $to_delete){ 
                    $self->error_message("deleted seq does not equal actual sequence! $deletion != $to_delete ");
                    return ;
                }
            }

            if ( defined $diff_stream->next_left_flank and $diff->{right_flank} > $diff_stream->next_left_flank ){ #now check if the tail of the flank overlaps the next diff flank
                $diff = $diff_stream->next_diff;
            }else{

                while( $write_position <= $diff->{right_flank}){ #advance fasta to diff position, flank printing starts here
                    unless (defined $buffer){
                        $buffer = $fasta_stream->next_line;
                        unless ($buffer){ 
                            $buffer = ''; #end of section
                            $diff->{right_flank} = $write_position;
                        }
                        $read_position = $read_position + length $buffer;
                    }

                    last if $read_position >= $diff->{right_flank}; #current buffered line contains diff pos

                    $output_stream->print($buffer); #otherwise, add to flank and print buffer
                    $diff_flank .= $buffer; 
                    $ref_flank .= $buffer;
                    $buffer = undef;
                    $write_position = $read_position;
                }

                $first_part_length = $diff->{right_flank} - $write_position;
                $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

                $output_stream->print($first_part);
                $write_position += $first_part_length;
                $diff_flank .= $first_part;
                $ref_flank .= $first_part;

                if ( length $diff_flank ){
                    $diff_flank_stream->print_header(">$flank_header");
                    $diff_flank_stream->print($diff_flank);
                }
                if ( length $ref_flank ){
                    $ref_flank_stream->print_header(">$flank_header");
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

    $output_stream->close();

    return 1;
}

=cut
        while( $write_position <= $diff->{position}){
            unless (defined $buffer){
                $buffer = $fasta_stream->next_line;
                unless ($buffer){
                    $self->error_message(
                        "Hit the end of the section and haven't reached the current diff's position! $write_position < ".$diff->{position}
                    );
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
        my $first_part = substr($buffer, 0,  $first_part_length, '');  #this splices out the first part from the buffer string

        $output_stream->print($first_part);
        $write_position += $first_part_length;

        $output_stream->print($diff->{insert});

        if ($diff->{delete}) {
            # cutting out sequence
            my $delete = $diff->{delete};
            while ( length($delete) > length($buffer) ) {  
              my $nextline = $fasta_stream->next_line;
              unless ($nextline)
                {
                $self->error_message("deletion($delete) substring extends beyond end of sequence, ending ($buffer)");
                return;
                }
              $buffer .= $nextline;
              $read_position += length $nextline;
            }

            my $deletion = substr($buffer, 0, length $delete, ''); #check buffer at this point
            unless ($deletion eq $delete){ #TODO clean up these var names to be clearer, in diffstream.pm as well.
                $self->error_message("deleted seq does not equal actual sequence! $deletion != $delete ");
                return ;
            }
            $write_position += length $delete;
        }
=cut

1;
