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

    my $buffer = Buffer->new($self->output);
    my $diff_handle = IO::File->new('< '.$self->diff);
    
    my $input_stream = Stream->new( ); #file or bioseq object
    my $current_header = $input_stream->next_header;
    $buffer->print($current_header);
    while (my $diff = $diff_handle->next){
       
        until ($diff->{header} eq $current_header){
            $buffer->print($char) while my $char = $input_stream->next;
            $current_header = $input_stream->next_header;
            $buffer->print($current_header);
        }
       
        until ($input_stream->last_position = $diff->{position}){
            $buffer->print($input_stream->next);
        }
       
        if ($diff->{patch}){
            $buffer->print($diff->{patch});
    
        }elsif ($diff->{ref}){
            my @ref = split('',$diff->{ref});
            while (@ref){
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
    }
    return 1;
}

#=====
sub print_fasta_section{
    my ($header, $diff_handle, $seq, $buffer);



1;
