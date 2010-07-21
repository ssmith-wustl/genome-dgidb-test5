package Genome::Assembly::Pcap::Tag;

use strict;
use warnings;

use base qw(Class::Accessor::Fast);

use Carp;
use Storable;

Genome::Assembly::Pcap::Tag->mk_accessors
(qw/
    type
    date
    scope
    source
    text
    parent
    start
    stop
    unpad_start
    unpad_stop
    no_trans
    data
    comment
    /);

our $VERSION = 0.01;

sub new
{
    croak "Genome::Assembly::Pcap::Tag->new no class given, quitting" unless @_;

    my ($caller, %arg) = @_;
    
    my $caller_is_obj = ref $caller;

    my $class = $caller_is_obj || $caller;

    return bless \%arg, $class;
}

sub copy
{
    my ($self, $item) = @_;
    
	return Storable::dclone($item);    
}

1;

=pod

=head1 Name

 Genome::Assembly::Pcap::Tag - Represents a tag on a GSC::IO::Assembly::Item

=head1 Synopsis

 my $tag = GSC::IO::ObjectIO::Tag
 (
  parent => 'Contig1',
  type => 'repeat', 
  start => 440,
  stop => 460
  text => 'a tag', 
 );

=head1 Methods

=head2 type

=head2 date

=head2 scope

=head2 source

=head2 text

=head2 parent

=head2 start

 stop or end position of the tag, maybe in padded or unpadded pos

=head2 stop

 stop or end position of the tag, maybe in padded or unpadded pos

=head2 unpad_start

 unpadded start of the tag (needs to be set)
 
=head2 unpad_stop

 unpadded stop of the tag (needs to be set)

=head2 no_trans

=head2 comment

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Lynn Carmicheal <lcarmich@watson.wustl.edu>
 Jon Schindler <jschindl@watson.wustl.edu>
 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
