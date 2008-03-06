package Genome::Utility::FastaStream;

use strict;
use warnings;
use Data::Dumper;

use Finfo::Std;

use IO::File;
#attributes

my %file :name(file:r) :type(file_r);
my %io :name(_io:p);
my %next_header_line :name(_next_header_line);
my %current_chars :name(_current_chars:p);
my %last_position_written :name(_last_position_written:p);

sub START{
    my $self = shift;
    my $io = IO::File->new('< '. $self->file);
    $self->fatal_msg("Can't open io for ".$self->file) unless $io;
    $self->_io($io);
    my $line = $self->io->getline;
    chomp $line;
    $self->fatal_msg("fasta file doesn't start with a header line!") unless $self->_is_header_line($line);
    $self->_next_header_line($line);
    $self->_last_position_written(0);
}

sub next_header{
    my $self = shift;
    my $hl = $self->_next_header_line;
    $self->fatal_msg("Haven't parsed through previous fasta section") unless $hl;
    $self->undef_attribute('_next_header_line');
    return $self->_parse_header($hl);
}

sub next{
    my $self = shift;
    if (scalar @{$self->_current_chars}){
        $self->_last_position_written($self->_last_position_written + 1);
        my $char = shift @{$self->_current_chars};
        return $char;
    }else{
        my $line = $self->_io->getline;
        chomp $line;
        if ($self->_is_header_line($line)){
            $self->_next_header_line($line);
            return undef;
        }else{
            my @chars = split ('', $line);
            $self->_current_chars(\@chars);
            return $self->next;
        }

    }
}

sub last_position{
    my $self = shift;
    return $self->_last_position_written;
}

sub _is_header_line{
    my ($self, $line) = @_;
    return ;#TODO;

}

sub _parse_header{
    my ($self, $line) = @_;
    return ;#TODO

}


