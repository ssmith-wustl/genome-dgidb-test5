package Finishing::Assembly::Project;

use strict;
use warnings;

use base 'Finishing::Assembly::Item';

use Date::Format;
use Data::Dumper;
use File::Copy;
use Findid::Utility;
#use Finishing::Assembly::Phd;
use GSC::IO::Assembly::Phd;
use Finishing::Assembly::Ace::Dir;
use Finishing::Assembly::Ace::Output;
#use Finishing::Assembly::Project::Findid; #TODO Findid doesn't exist

my %offline :name(_offline:p) :isa(boolean) :default(0);
my %findid :name(_findid:p);
my %chromat_dir :name(_chromat_dir:p) :isa(dir_rw);
my %phd_dir :name(_phd_dir:p) :isa(dir_rw);
my %edit_dir :name(_edit_dir:p) :isa(dir_rw);

sub START
{
    my $self = shift;

    my $dir = $self->directory;
    unless ( -d $dir )
    {
        $self->_offline(1);
    }

    return 1;
}

# Dirs
sub consed_directory_names
{
    return (qw/ edit_dir phd_dir chromat_dir /);
}

sub edit_dir
{
    return shift->_dir('edit_dir');
}

sub phd_dir
{
    return shift->_dir('phd_dir');
}

sub chromat_dir
{
    return shift->_dir('chromat_dir');
}

sub _dir : PRIVATE
{
    my ($self, $type) = @_;
    
    return if $self->_offline;

    return sprintf('%s/%s', $self->directory, $type);
}

sub create_consed_directory_structure
{
    my $self = shift;
    
    return if $self->_offline;

    foreach my $dir_name ( $self->consed_directory_names )
    {
        my $dir = $self->$dir_name;
        next if -d $dir;
        mkdir $dir;
        $self->fatal_msg("Could make dir ($dir): $!") unless -d $dir;
    }

    return 1;
}

# Ace
sub acedir
{
    my $self = shift;

    my $edit_dir = $self->edit_dir
        or return;

    return Finishing::Assembly::Ace::Dir->new(dir => $edit_dir);
}

sub recent_ace
{
    my $self = shift;

    my $acedir = $self->acedir
        or return;

    return $acedir->recent_ace;
}

sub recent_acefile
{
    my $self = shift;

    my $acedir = $self->acedir
        or return;

    return $acedir->recent_acefile;
}

sub num_of_aces
{
    my $self = shift;

    my $acedir = $self->acedir
        or return;

    return $acedir->num_of_aces;
}

sub all_aces
{
    my $self = shift;

    my $acedir = $self->acedir
        or return;

    return $acedir->all_aces;
}

sub aceobject
{
    my ($self, $acefile) = @_;
    
    Finfo::Validate->validate
    (
        attr => 'acefile',
        value => $acefile,
        isa => 'file_r',
        msg => 'fatal',
    );

    my $ao = Finishing::Assembly::Ace::Ext->new(input_file => $acefile);

    $self->fatal_msg("Could not create ace for acefile ($acefile)") unless $ao;

    return $ao;
}

sub recent_aceobject
{
    my $self = shift;
    
    my $acefile = $self->recent_acefile
        or return;

    return $self->aceobject($acefile);
}

sub aceext
{
    my ($self, $acefile) = @_;

    my $ao = $self->aceobject($acefile)
        or return;

    return Finishing::Assembly::Ace::Ext->new(aceobject => $ao);
}

sub recent_aceext
{
    my $self = shift;
    
    my $acefile = $self->recent_acefile
        or return;
    
    return $self->aceext($acefile);
}

sub touch_singlets_file_for_acefile
{
    my ($self, $acefile) = @_;

    return if $self->_offline;

    $self->fatal_msg("Need acefile to touch singlets") unless $acefile;
    
    my $singlets_file = $acefile . '.singlets';

    return 1 if -e $singlets_file;

    system("touch $singlets_file");

    return 1 if -e $singlets_file;
    
    $self->info_msg("Failed to create singlets file for acefile ($acefile)");

    return;
}

sub move_scfs_and_phds_in_acefile
{
    my ($self, %p) = @_;

    my $scf_loc = delete $p{scf_loc};
    Finfo::Validate->validate
    (
        attr => 'scf location',
        value => $scf_loc,
        isa => 'dir_r',
        msg =>'fatal', 
    );

    my $phd_loc = delete $p{phd_loc};
    Finfo::Validate->validate
    (
        attr => 'phd location',
        value => $phd_loc,
        isa => 'dir_w',
        msg =>'fatal', 
    );

    my $acefile = delete $p{acefile};
    Finfo::Validate->validate
    (
        attr => 'acefile',
        value => $acefile,
        isa => 'file_r',
        msg =>'fatal', 
    );
    
    my $ace_factory = Finishing::Assembly::Factory->connect("ace", $acefile);
    $self->fatal_msg("Can't connect to ace factory for acefile ($acefile)") unless $ace_factory;
    my $assembly = $ace_factory->get_assembly;
    my $ri = $assembly->get_assembled_read_iterator;
    $self->fatal_msg("No reads found in acefile ($acefile)") unless $ri->count > 0;
    
    # TODO read functions may not work
    while ( my $read = $ri->next )
    {
        $self->_move_file
        (
            from => sprintf('%s/%s', $phd_loc, $read->phd_file),
            to => sprintf('%s/%s', $self->phd_dir, $read->phd_file),
            msg => 'warn',
            overwrite => 0,
        );

        $self->_move_file
        (
            from => sprintf('%s/%s', $scf_loc, $read->chromat_file),
            to => sprintf('%s/%s', $self->chromat_dir, $read->chromat_file),
            msg => 'warn',
            overwrite => 0,
        );
    }

    return 1;
}

sub _move_file : PRIVATE
{
    my ($self, %p) = @_;

    my $from = delete $p{from};
    my $to = delete $p{to};
    my $msg_type = delete $p{msg} || 'fatal';
    my $msg_method = $msg_type . '_msg';
    my $overwrite = ( exists $p{overwrite} ) ? delete $p{overwrite} : 0;

    Finfo::Validate->validate
    (
        attr => 'from file name',
        value => $from,
        isa => 'file_r',
        msg =>'fatal', 
    );
    
    unlink $to if $overwrite and -e $to and not -d $to;

    Finfo::Validate->validate
    (
        attr => 'to file name',
        value => $to,
        isa => 'file_w',
        msg =>'fatal', 
    );
    
    if ( File::Copy::move($from, $to) )
    {
        return 1;
    }
    else
    {
        $self->$msg_method
        (
            sprintf('Can\'t move %s to %s: %s', $from, $to, $!) 
        );
        return;
    }
}

# Pals and printrepeats
sub get_pals_and_prs
{
    my $self = shift;

    return if $self->_offline;

    my $path = $self->dir . "/edit_dir/overlaps/";

    my @files = grep { $_ !~ /positions|align/ } glob("$path/*.pal*"), glob("$path/*.pr*");

    return @files;
}

# Findid
sub parsefindid
{
    my $self = shift;

    return if $self->_offline;
    
    my $parsefindid = $self->directory . "/findid/parsefindid";

    return unless -s $parsefindid;

    return $parsefindid;
}

sub findid
{
    my $self = shift;

    my $parsefindid = $self->parsefindid
        or return;

    unless ( $self->_findid )
    {
        my $organism = $self->organism;
        
        $self->_findid
        (
            Finishing::Assembly::Project::Findid->new
            (
                project_name => $self->name,
                species => Findid::Utility->convert_GSC_to_DB($self->species_name),
                reader => Finisihng::Assembly::Project::Findid->new(io => $self->parsefindid),
            )
        );
    }

    return $self->_findid;
}

sub findid_age
{
    my $self = shift;

    return if $self->_offline;

    return ( $self->findid )
    ? $self->findid->age
    : -1;
}

sub findid_organism_name
{
    my $self = shift;

    return Findid::Utility->convert_GSC_to_DB( $self->organism_name ); # needs better name
}

sub findid_db
{
    my $self = shift;

    my $findid_organism_name = $self->findid_organism_name;

    return "$findid_organism_name,bacterial";
}

1;

=pod

=head1 Name

Finishing::Assembly::Project
 
=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 edit_dir

 Get the edit_dir.  This is where the read prefixes file will be created.

=head2 chromat_dir

 Get the chromat_dir.  This is where the traces will be moved to.
 
=head2 phd_dir

 Get the phd_dir.  This is where the phds will be created.

=head2 read_prefixes_file

 Get the read prefixes file name for consed.

=head2 traces

=head2 phred_traces

=head2 add_tag_to_traces

=head2 gzip_traces

=head2 add_traces_to_readprefixes

=head1 See Also

 TraceArchive, NCBI::TraceArchive::Trace

 http://www.ncbi.nlm.nih.gov/Traces/trace.cgi?cmd=show&f=doc&m=obtain&s=stips

=head1 Disclaimer

 Copyright (C) 2005-2007 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/branches/adukes/AssemblyRefactor/Project.pm $
#$Id: Project.pm 31151 2007-12-18 23:17:24Z ebelter $
