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

    my $buffer = Genome::Utility::OutputBuffer->new(file => $self->output, line_width => 60 );
    my $diff_stream = Genome::Utility::DiffStream->new(file => $self->diff ); 
    my $fasta_stream = Genome::Utility::FastaStream->new( file => $self->input ); #file or bioseq object
    

    #use these for error checking
    my @seen_headers;
    my $last_diff_pos = 0;
    my $current_header_from_diffs;

    #print first header
    my $current_header_from_fasta_stream = $fasta_stream->next_header;
    $buffer->print_header($fasta_stream->header_line);

    while (my $diff = $diff_stream->next_diff){

        #error checking
        unless ($current_header_from_diffs and $diff->{header} eq $current_header_from_diffs){
            push @seen_headers, $current_header_from_diffs if $current_header_from_diffs;
            $current_header_from_diffs = $diff->{header};
            $last_diff_pos = 0;
        }
        if ($diff->{position} < $last_diff_pos){
            $self->error_message("Diff pos is less that a previous diff position for header $current_header_from_diffs( ".$diff->{position}." $last_diff_pos! These need to be sorted!");
            return;
        }
       
        until ( $current_header_from_fasta_stream eq $diff->{header} ){ 
            
            #make sure diff header is not out of order
            if ( grep { $diff->{header} eq $_ } @seen_headers){
                $self->error_message("Diff header matches a previous chromosome! Diffs should be sorted by chromosome and position!"); 
                return;
            }
            
            #print fasta sections until we get to the right header
            while (my $char = $fasta_stream->next){
                $buffer->print($char);
            }
            $current_header_from_fasta_stream = $fasta_stream->next_header;
            unless ($current_header_from_fasta_stream){
                $self->error_message("Can't get another header from the fasta(probably at EOF) and there are still diffs to process!");
                return;
            }
            $buffer->print_header($fasta_stream->header_line);
        }
       
        my $stream_stop_position = $diff->{position}-1; #we stop before the position given in diff, since we don't want to print a base that is going to be deleted
        until ($fasta_stream->last_position == $stream_stop_position){  
            #print out until we hit have printed to the diff position
            $buffer->print($fasta_stream->next);
        }
       
        if ($diff->{patch}){ #insert

            #print the base @ $diff->{position}
            $buffer->print($fasta_stream->next);
            #print out the insert if there is one
            $buffer->print($diff->{patch});
    
        }elsif ($diff->{ref}){

            my @ref = split('',$diff->{ref});
            while (@ref){
                #shift off input while replacing
                my $replace = shift @ref;
                my $replaced = $fasta_stream->next;
                unless ($replaced and $replaced =~ /^$replace$/i){
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
    while(1){
        while (my $char = $fasta_stream->next){
            $buffer->print($char);
        }
        $current_header_from_fasta_stream = $fasta_stream->next_header;
        unless ($current_header_from_fasta_stream){
            $buffer->print("\n");
            last;
        }
        $buffer->print_header($fasta_stream->header_line);
    }
    return 1;
}

1;
