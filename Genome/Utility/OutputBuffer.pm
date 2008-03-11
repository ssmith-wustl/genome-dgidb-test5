package Genome::Utility::OutputBuffer;

use strict;
use warnings;
use Data::Dumper;


use IO::File;
#attributes
=cut
my %file :name(file:r);
my %line_width :name(line_width:o) :isa('int pos') :default(50);

my %io :name(_io:p);
my %count :name(_count:p);

=cut

sub new{
    my $class = shift;
    my $file = shift;
    my $io = IO::File->new("> ".$file);
    die "can't create io" unless $io;
    my $self = bless({_io => $io, current_line_avail => 60},$class);
    return $self;
}

sub print_header{
    my ($self, $header) = @_;
    #don't print leading newline if we're at the top of the file
    $self->{_io}->print("\n") unless $self->{current_line_avail} == 60;
    $self->{_io}->print("$header\n") or $self->fatal_msg("can't write header $header");
    $self->{current_line_avail} = 60;
    return 1;
}

sub print{
    my $self = shift;
    my $avail = $self->{current_line_avail};
    my $io = $self->{_io};
    for (@_) {
        my $next = substr($_,0,$avail);
        $io->print($next);
        $avail -= length($next);
        if ($avail == 0) {
            $io->print("\n");
            $avail = 60;
        }                    
        $_ = substr($_,length($next));
        redo if length($_);        
    }
    $self->{current_line_avail}=$avail;
    return 1;
}

1;
