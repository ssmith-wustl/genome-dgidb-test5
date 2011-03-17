package Genome::Model::Tools::Pcap::PhdDB;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;
use base qw(Class::Accessor::Fast);

App::DBI->no_commit(1);
use IO::File;
use IO::String;
use Storable;
use Genome::Model::Tools::Pcap::Phd::Reader;
use Genome::Model::Tools::Pcap::Phd::Writer;

Genome::Model::Tools::Pcap::PhdDB->mk_accessors(qw(assembly_name assembly _reader _writer));

my $pkg = 'Genome::Model::Tools::Pcap::PhdDB';

=pod

=head1 new 

my $phd_object = new Genome::Model::Tools::Pcap::PhdDB::PhdDB(project_name => "my_project");

=cut

sub new {
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
	my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};
    bless ($self, $class);
	$self->_reader( Genome::Model::Tools::Pcap::Phd::Reader->new );
	$self->_writer( Genome::Model::Tools::Pcap::Phd::Writer->new );
	if(exists $params{project_name})
	{
		$self->project_name($params{project_name});
		$self->project(GSC::Setup::Project::Finishing->get(name => $self->project_name));
	}    
    
    return $self;
}

#this doesn't make much sense in the context of the database
#sub get_phd_names
#{
#	my ($self) = @_;
#	if(defined $self->project)
#	{
#		$self->project->
#	
#	}
#}

sub get_latest_phd
{
	my ($self, $name) = @_;
	my ($read_name, $version) = ($name =~ /(.+)\.phd\.(\d+)$/);
	my $db_read_name = $read_name."-$version";
	
	my $nMax = GSC::Sequence::Read->get_current_version_by_name($db_read_name);
	return "$read_name.phd".".$nMax";
}

sub get_phd
{
	my ($self, $name) = @_;
	
	my ($read_name, $version) = ($name =~ /(.+)\.phd\.(\d+)$/);
	my $db_read_name = $read_name."-$version";
	my $read = GSC::Sequence::Item->get(sequence_item_name => "$db_read_name");
	my $reader = $self->_reader;
	die "Could not locate $name\n" if(!defined $read);			
	my $phd_string = $read->phd_content;
	my $fh = IO::String->new($phd_string);
	return $reader->read($fh);
}

sub add_phd
{
	my ($self, $phd) = @_;
	#we shouldn't allow reads to be overwritten using this library	
	my $name = $phd->name;
	my ($read_name, $version) = $name =~ /(.+)\.phd\.(\d+)$/;
	my $db_read_name = $read_name."-$version";	
	my $phd_string;
	$self->_writer->write(IO::String->new($phd_string));
	my $read = GSC::Sequence::Item->get(sequence_item_name => $db_read_name);
	if(!$read)
	{
		$read = GSC::Sequence::ReadEdit->create( sequence_item_name => $db_read_name, );
		$read->phd_content($phd_string);
	}
}

=head1 Author(s)

 Jon Schindler <jschindl@watson.wustl.edu>

=cut

1;
