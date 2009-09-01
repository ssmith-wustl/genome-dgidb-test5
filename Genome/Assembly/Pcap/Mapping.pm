
# Copyright (C) 2004 Washington University Genome Sequencing Center
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

# Last modified: <Thu, 2006/07/06 18:49:05 ebelter linus108>

our $VERSION = 0.01;

=head1 NAME
Genome::Assembly::Pcap::Mapping - Mapping of a child's position in its parent.

=head1 SYNOPSIS

$mapping = new Genome::Assembly::Pcap::Mapping(parent_start => 2340, parent_stop => 2600, child_start => 55, child_stop => 545);

=head1 DESCRIPTION

=head1 METHODS

    parent_start
    parent_stop
    child_start
    child_stop

=cut

use strict;
use warnings;
use Carp;

package Genome::Assembly::Pcap::Mapping;

sub new {
    croak("Genome::Assembly::Pcap::Mapping:new:no class given, quitting") if @_ < 1;
    my ($caller, %arg) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = \%arg;
    bless ($self, $class);
    return $self;
}

sub parent_name 
{
    my ($self, $name) = @_;
    
    $self->{parent_name} = $name if defined $name;

    return $self->{parent_name};
}

sub parent_start {
    my ($self, $p_start) = @_;
    if (defined $p_start) {
        $self->{parent_start} = $p_start;
    }
    return $self->{parent_start};
}

sub parent_stop {
    my ($self, $p_stop) = @_;
    if (defined $p_stop) {
        $self->{parent_stop} = $p_stop;
    }
    return $self->{parent_stop};
}

sub name 
{
    my ($self, $name) = @_;
    
    $self->{parent_name} = $name if defined $name;

    return $self->{parent_name};
}

sub start
{
    my ($self, $start) = @_;
    
    $self->{parent_start} = $start if defined $start;

    return $self->{parent_start};
}

sub stop
{
    my ($self, $stop) = @_;
    
    $self->{parent_stop} = $stop if defined $stop;

    return $self->{parent_stop};
}

sub child_start {
    my ($self, $c_start) = @_;
    if (defined $c_start) {
        $self->{child_start} = $c_start;
    }
    return $self->{child_start};
}

sub child_stop {
    my ($self, $c_stop) = @_;
    if (defined $c_stop) {
        $self->{child_stop} = $c_stop;
    }
    return $self->{child_stop};
}

sub is_complemented {
    my $self = shift;
    return $self->child_start > $self->child_stop;
}

1;
#$Header$
