package Genome::Site::WUGC::Finishing::Project::XML;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use XML::Simple ':strict';

my %file :name(file:r)
    :type(rw_file)
    :clo('proj-xml=s')
    :desc('Project XML file');

my %xs :name(_xml_simple:p)
    :type(inherits_from)
    :options([qw/ XML::Simple /]);

sub START
{
    my $self = shift;

    my $xs = XML::Simple->new
    (
        rootname => 'project',
        KeyAttr => { project => 'name' },
        ForceArray => [qw/ project ctgs tags /],
    );
   
    $self->fatal_msg("Can't create XML::Simple object") unless $xs;

    $self->_xml_simple($xs);

    return 1;
}

sub read_projects
{
    my $self = shift;
    
    my $file = $self->file;
    my $fh = IO::File->new("< $file");
    $self->fatal_msg("Can't open file ($file): $!") unless $fh;
    
    my $projects;
    eval
    {
        $projects = $self->_xml_simple->XMLin( join('', $fh->getlines) );
    };

    Finfo::Validate->validate
    (
        attr => "projects hash",
        value => $projects,
        type => 'non_empty_hashref',
        err_cb => sub{ $self->fatal_msg("Error in reading xml file ($file): $_[0]"); },
    );

    return $projects;
}

sub write_projects
{
    my ($self, $projects) = @_;

    Finfo::Validate->validate
    (
        attr => 'project hash',
        value => $projects,
        type => 'non_empty_hashref',
        err_cb => $self,
    );

    my $xml;
    eval
    {
        $xml = $self->_xml_simple->XMLout($projects);
    };

    $self->fatal_msg("Error translating projects hash into xml: $!") unless $xml;
    
    my $file = $self->file;

    unlink $file;

    my $fh = IO::File->new("> $file");
    $self->fatal_msg("Can't open file ($file): $!") unless $fh;

    $fh->print($xml);

    return $fh->close;
}

1;

=pod

=head1 Name

Genome::Site::WUGC::Finishing::Project::XML

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 See Also

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/XML.pm $
#$Id: XML.pm 29849 2007-11-07 18:58:55Z ebelter $

