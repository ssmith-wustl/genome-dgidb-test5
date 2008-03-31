package Genome::Utility::DiffStream;

use strict;
use warnings;
use Data::Dumper;

use IO::File;

#attributes

sub new{
    my ($class, $file) = @_;
    my $io = IO::File->new('< '.$file);
    die "couldn't open io" unless $io;
    my $self = bless({_io => $io }, $class);
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

    my ($subject, $pos, $delete, $insert, $pre_diff_sequence, $post_diff_sequence) = split(/\s+/, $line);

    $diff{header} = $subject;
    $diff{delete} = uc $delete unless $delete eq '-';
    $diff{delete} ||= '';
    $diff{insert} = uc $insert unless $insert eq '-';
    $diff{insert} ||= '';

    $diff{position} = $pos;
    
    if ( $diff{delete} ){ # in ApplyDiffToFasta deletes start AFTER index, like inserts, also adjuct right flank;
        $diff{position}--;
    }
    
    if ($pre_diff_sequence or $post_diff_sequence){
        $diff{pre_diff_sequence} = uc $pre_diff_sequence unless $pre_diff_sequence eq '-';
        $diff{pre_diff_sequence} ||= '';
        $diff{post_diff_sequence} = uc $post_diff_sequence unless $post_diff_sequence eq '-';
        $diff{post_diff_sequence} ||= '';
    }

    $self->{current_diff_header} = $diff{header};
    return \%diff;
}

sub next_diff_position{
    my $self = shift;
    return $self->{next_diff}->{position} if $self->{next_diff} and $self->{next_diff}->{header} eq $self->{current_diff_header};
    return undef;
}

1;

=pod

=head1 Diff File Input Streamer I<(name subject to change)>

=head2 Synopsis

This streams through a diff file, and parses and returns diff objects used in the Tools command ApplyDiffToFasta I<(name subject to change)>

my $ds = Genome::Utility::DiffStream->new( <file_name> )

=head2 Diff File Format
no header
<fasta header identifier> <position> <deletion sequence> <insertion sequence> <pre_diff_seq> <post_diff_seq>

The fasta header identifier should

=head2 Options

1;
