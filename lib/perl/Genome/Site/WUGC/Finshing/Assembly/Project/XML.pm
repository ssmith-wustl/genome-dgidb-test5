package Finishing::Assembly::Project::XML;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;
use Finishing::Assembly::Project::Utils;
use XML::Simple ':strict';

my %file :name(file:r)
    :isa(file_rw)
    :clo('proj-xml=s')
    :desc('Project XML file');

my %xs :name(_xml_simple:p)
    :isa('object XML::Simple');

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
    return {} unless -s $file;
    my $fh = IO::File->new("< $file");
    $self->fatal_msg("Can't open file ($file): $!") unless $fh;
    
    my $projects = {};
    eval
    {
        $projects = $self->_xml_simple->XMLin( join('', $fh->getlines) );
    };

    Finishing::Assembly::Project::Utils->instance->validate_projects_hash($projects);

    return $projects;
}

sub write_projects
{
    my ($self, $projects) = @_;

    Finishing::Assembly::Project::Utils->instance->validate_projects_hash($projects);

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

Finishing::Assembly::Project::XML

=head1 Synopsis

Converts a projects hash to and from xml for file system storage.

=head1 Usage

 use Finishing::Assembly::Project::XML;

 my $project_xml = Finishing::Assembly::Project::XML->new(file => $file);

 # Modify projects
 my $projects = $project_xml->read_projects;
 $project_xml->write_projects($projects);

 # Create Projects
  $project_xml->write_projects
  (
    {
        $name1 =>
        {
            db => 'cmap_admin', #req
            directory => '/home1/projects', #opt, will get/create
        },
        $name2 =>
        {
            db => 'ace',
            file => $acefile_for_project2,
            contigs =>
            [
            {
                name => 'Contig2', #req, original name of contig
                
            },
            ],
        },
        # etc
   }
  );
  
 
=head1 Projects Hash Structure

The projects hash structure is a hash ref with project names as keys and their info as values.  The name must be unique.  Here is the information each project can have:

=over

=item I<db> (req) - Which database to create the project in.

=item I<directory> (opt) - The project directory.  If not given, it will bedetermined  and created automatically.

=item I<contigs> (opt) - The project's contigs to get and put in an acefile in the project's edit_dir.  This will also get the traces and phds for each contig.

=back

=over

Contigs is an array ref of hash refs with these keys/values:

=over

=item I<name> (req) - Name of the original contig

=item I<db> (req) - Database where the contig lives

=item I<file> - Required if the contig lives in an acefile or sqlite db

=item I<start> (opt) - Start position of the original contig (NOT SUPPORTED YET)

=item I<stop> (opt) - Stop position of the original contig (NOT SUPPORTED YET)

=back

Additionally, the contig can be renamed.  If the original name is desired, do not include one of these parameters.

=over

=item I<new_name> - The new name of the contig

=item I<auto_rename> - Auto rename the contig.  Uses the contig count of the new acefile.

=back

=head1 Methods

=head2 read_projects

 my $projects = $project_xml->read_projects;

=over

=item Synopsis  converts the xml stored in file to projects hash

=item Params    none

=item Returns   projects hash

=back

=head2 write_projects

 $project_xml->read_projects($projects);
 
=over

=item Synopsis  converts projects hash to xml, writes to file
    
=item Params    projects hash

=item Returns   true on success

=back

=head1 See Also

=over

=item B<Finishing::Assembly::Project>

=item B<Finishing::Assembly::Factory>

=item B<Finishing::Assembly::Project::Checkout>

=item B<Finishing::Assembly::Project::XML::Checkout>

=back

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Assembly/Project/XML.pm $
#$Id: XML.pm 31534 2008-01-07 22:01:01Z ebelter $
