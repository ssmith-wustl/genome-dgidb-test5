package Genome::Utility::DiffStream;

use strict;
use warnings;
use Data::Dumper;

use IO::File;

#attributes

sub new{
    my ($class, $file, $flank) = @_;
    $flank ||= 0;
    my $io = IO::File->new('< '.$file);
    die "couldn't open io" unless $io;
    my $self = bless({_io => $io, flank => $flank}, $class);
    $self->{next_diff} = $self->make_diff($self->{_io}->getline);
    $self->{current_diff_header} = '';
    return $self;
}

sub next_diff{
    my $self = shift;
    my $diff = $self->{next_diff};
    $self->{next_diff} = $self->make_diff($self->{_io}->getline);
    return unless $diff;
    $self->{current_diff_header} = $diff->{header};
    return $diff;
}

sub make_diff{
    my ($self, $line) = @_;
    return unless $line;
    my %diff;
    my $flank_adjust = 0;
    my ($subject, $chromosome, $pos, $delete, $insert) = split(/\s+/, $line);

    $diff{header} = $subject;
    $diff{delete} = $delete unless $delete =~/-/;
    $diff{insert} = $insert unless $insert =~/-/;

    $diff{position} = $pos;
    
    if ( $diff{delete} ){ # in ApplyDiffToFasta deletes start AFTER index, like inserts, also adjuct right flank;
        $diff{position}--;
        $flank_adjust += length $diff{delete};
    }

    $diff{left_flank} = $diff{position} - $self->{flank};
    $diff{left_flank} = 0 if $diff{left_flank} < 0;
    $diff{right_flank} = $diff{position} + $flank_adjust + $self->{flank};

    $self->{current_diff_header} = $diff{header};
    return \%diff;
}


sub _generate_header{
    my ($self, $subject, $chromosome) = @_;
    return $subject;#TODO this only applies for human, need a more generalized method

}

sub next_left_flank{
    my $self = shift;
    return $self->{next_diff}->{left_flank} if $self->{next_diff} and $self->{next_diff}->{header} eq $self->{current_diff_header};
    return undef;
}


1;


