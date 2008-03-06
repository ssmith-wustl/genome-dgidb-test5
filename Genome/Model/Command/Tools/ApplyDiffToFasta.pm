PACKAge Genome::Model::Command::Tools::ApplyDiffToFasta;

use strict;
use warnings;

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

    my $buffer = Genome::Utility::Buffer->new(file => $self->output );
    my $diff_handle = Genome::Utility::Diff->new(file => $self->diff );
    my $input_stream = Genome::Utility::FastaStream->new( file => $self->input ); #file or bioseq object
    

    #use these for error checking
    my @seen_headers;
    my $last_diff_pos;
    my $last_header;

    #print first header
    my $current_header = $input_stream->next_header;
    push @seen_headers, $current_header;
    $buffer->print($current_header);

    while (my $diff = $diff_handle->next_diff){

        #error checking
        unless ($diff->{header} eq $last_header){
            $last_header = $diff->{header};
            $last_diff_pos = 0;
        }
        $self->fatal_msg("Diff pos is less that a previous diff position for header $last_header( ".$diff->{position}." $last_diff_pos! These need to be sorted!") if $diff->{position}<$last_diff_position;
       
        until ($diff->{header} eq $current_header){
            
            #sorted file error checking
            $self->fatal_msg("Diff header matches a previous chromosome! Diffs should be sorted by chromosome and position!") if grep {$diff->{header} eq $_} @seen_headers;
            
            #print fasta sections until we get to the right header
            $buffer->print($char) while my $char = $input_stream->next;
            $current_header = $input_stream->next_header;
            $buffer->print($current_header);
        }
       
        until ($input_stream->last_position = $diff->{position}){
            #print out until we hit have printed to the diff position
            $buffer->print($input_stream->next);
        }
       
        if ($diff->{patch}){
            #print out the insert if there is one
            $buffer->print($diff->{patch});
    
        }elsif ($diff->{ref}){
            my @ref = split('',$diff->{ref});
            while (@ref){
                #shift off input while replacing
                my $replace = shift @ref;
                my $replaced = $input_string->next;
                unless $replaced and $replaced eq $replace){
                    $self->error_message("ref sequence to be replaced did not match fasta sequence");
                    return;
                }
            }
        }else{
            $self->error_message("no patch sequence to insert or reference sequence to remove for diff line ".$diff->{line});
            return;
        }
        #diff processed, resume printing to buffer;
    }
    return 1;
}


1;
