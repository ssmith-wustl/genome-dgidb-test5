package Finishing::Assembly::Commands::ProjectCheckout;

use strict;
use warnings;

use base 'Finishing::Assembly::Commands::Base';

use Cwd 'abs_path';
use Data::Dumper;
use File::Basename;
use Finishing::Assembly::Ace::Exporter;
use Finishing::Assembly::Commands::ExportReads;
use Finishing::Assembly::Commands::SyncAcePhds;
use Finishing::Assembly::Project::Utils;
use IO::File;

my %name :name(name:r);
my %base_dir :name(base_directory:o);
my %organism_name :name(organism_name:o) :default('unknown');
my %contigs :name(contigs:o) :ds(aryref);
my %missed_reads :name(_missed_read:p) :ds(aryref) empty_ok(1);
my %missed_phds :name(_missed_phd:p) :ds(aryref) empty_ok(1);


my %rd_srcs :name(read_sources:o) 
    :ds(aryref) 
    :isa([ 'in_list', __PACKAGE__->valid_read_sources ])
    :default([ __PACKAGE__->valid_read_sources ]);
my %sync_phds :name(sync_phds:o) 
    :isa(boolean) 
    :default(0)
    :desc('Sync the phd info in the resulting acefile to match the phds');

sub valid_read_sources
{
    return Finishing::Assembly::Commands::ExportReads->valid_read_sources;
}
    
sub project_utils
{
    return Finishing::Assembly::Project::Utils->instance;
}

sub execute
{
    my $self = shift;

    my $name = $self->name;
    my $project = $self->_factory->get_project($name);
    unless ( $project ) 
    {
        $project = $self->_factory->create_project
        (
            name => $name,
            base_directory => abs_path($self->base_directory),
            organism_name => $self->organism_name,
        )
            or $self->fatal_msg("Can't get or create project ($name)");
    }

    $project->create_consed_directory_structure;

    my $read_names;
    if ( $self->contigs )
    {
        my $acefile = sprintf('%s/%s.ace', $project->edit_dir, $project->name);
        $project->touch_singlets_file_for_acefile($acefile); 
        my $xporter = Finishing::Assembly::Ace::Exporter->new
        (
            file => $acefile,
        );

        foreach my $contig_info ( @{ $self->contigs } )
        {
            my $name = $contig_info->{name};
            my $db = $contig_info->{db};
            my $factory = Finishing::Assembly::Factory->connect 
            (
                $db,
                ( exists $contig_info->{file} ) ? $contig_info->{file} : undef,
            );

            my $assembly = $factory->get_assembly
            (
                ( $contig_info->{assembly_params} )
                ? %{ $contig_info->{assembly_params} }
                : undef
            );
            $self->fatal_msg("Can't get assembly from factory (db: $db)") unless $assembly;

            my $contig = $assembly->get_contig($name);
            $self->fatal_msg("Can't get contig ($name) from assembly (factory db: $db)") unless $contig;

            $xporter->export_contig
            (
                contig => $contig,
                new_name => $contig_info->{new_name},
                auto_rename => $contig_info->{auto_rename},
            );

            push @{ $read_names }, map { $_->name } $contig->reads->all;
        }

        $xporter->close;
    }

    if ( $read_names )
    {
        $self->_export_reads($read_names, $project->chromat_dir, $project->phd_dir);
        $self->_sync_phds(sprintf('%s/%s.ace', $project->edit_dir, $project->name), $project->phd_dir) if $self->sync_phds;
    }

    return $project;
}

sub missed_names {
    #type must be either read or phd
    my ($self, $type) = @_;
    my $method = '_missed_'.$type;
    return $self->$method;
}


sub _export_reads
{
    my ($self, $read_names, $chromat_dir, $phd_dir) = @_;

    my $read_xporter = Finishing::Assembly::Commands::ExportReads->new
    (
        read_names => $read_names,
        chromat_dir => $chromat_dir,
        phd_dir => $phd_dir,
    );
    $read_xporter->execute;
    $self->_missed_read($read_xporter->missed_names);

    return 1;
}

sub _sync_phds
{
    my ($self, $acefile, $phd_dir) = @_;

    my $syncr = Finishing::Assembly::Commands::SyncAcePhds->new
    (
        file => $acefile,
        phd_dir => $phd_dir,
    );
    $syncr->execute;
    $self->_missed_phd($syncr->missed_names);

    return 1;
}

1;

=pod

=head1 Name

Finishing::Assembly::Project::Checkout

=head1 Synopsis

Given a project's attributes, creates the project in a given database, creates it's directory (w/ consed structure).  If contigs are given, they will be retrieved from their original source and written to a new acefile in the proejct's edit_dir.  The scfs and phds for these contigs will also be retrieved, first looking in the GSC warehouse, then going to the NCBI trace archive. 

=head1 Usage

 use Finishing::Assembly::Project::Checkout;

 my $checkout = Finishing::Assembly::Project::Checkout->new
 (
    # base command params
    db => $db_to_crete_project_in, #req, see Finishing::Assembly::Factory->available_dbs
    db_file => $db_file, #req for some dbs like ace and sqlite
    # checkout project 
    name => $project_name, #req
    organism => $organism_name, #opt, default will be 'unknown' 
    base_directory => $dir, #opt, will be determine and create automatically,
    contigs => \@contigs, #opt, contigs to get
 );

 $checkout->execute;

=head1 Contigs Data Structure

Contigs is an array ref of hash refs with these keys/values:

=over

=item I<name> (req) - Name of the original contig

=item I<db> (req) - Database where the contig lives

=item I<file> - Required if the contig lives in an acefile or sqlite db

=item I<start> (opt) - Start position of the original contig (NOT SUPPORTED YET)

=item I<stop> (opt) - Stop position of the original contig (NOT SUPPORTED YET)

=back

=head1 Methods

head2 execute

 $checkout->execute;
 
=over

=item Synopsis  checks out the project
    
=item Params    none

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

#$HeadURL
#$Id$
