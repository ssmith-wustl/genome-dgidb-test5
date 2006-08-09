package Bio::ContigUtilities::PhdObject;
our $VERSION = 0.01;

=pod

=head1 NAME

PhdObject - Object oriented phd/phd.ball file reader/writer

=head1 SYNOPSIS

my $phd_object = Bio::ContigUtilities::PhdObject->new(input_file => "inputfilename", input_directory => "inputdirname");

 my @phd_names = $phd_object->get_phd_names();
 my $phd = $phd_object->get_phd("vef07");

    
=head1 DESCRIPTION

Bio::ContigUtilities::PhdObject takes either a Phd file, and allows the user to get Contig objects from the ace file, edit them, and write the file back to the hard disk when finished.

=head1 METHODSAssembly::Phd::Reader->new );

=cut
use strict;
use warnings;
use Carp;
use base qw(Class::Accessor);

use GSC::IO::Assembly::Phd::Reader;
use GSC::IO::Assembly::Phd::Writer;
use IO::File;
use Compress::Zlib;
use IO::String;
use Storable;

Bio::ContigUtilities::PhdObject->mk_accessors(qw(_reader _writer _input _output _input_file _output_file _index conserve_memory));

my $pkg = 'Bio::ContigUtilities::AceObject';

=pod

=head1 new 

my $ace_object = new Bio::ContigUtilities::AceObject(input_file => $input_file, output_file => $output_file);

input_file - required, the name of the input ace file.

output_file - option, the name of output ace file.  You can give ace_object the file handle when you create it, or later when you write it.  If you are reading, then you don't need to specify the file handle.

conserve_memory - optional, lets ace ojbect know whether it should store cached data on the file system or keep it in memory for fast access.

load_index_from_file - optional, tells AceObject to load the index from the file, and the user is required to specify the index file name.

=cut

sub new {
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
	my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};
    bless ($self, $class);
	if(exists $params{input})
	{
		$self->_input ( $params{input});		
	}
	elsif(exists $params{input_file})
	{
		$self->_input_file ($params{input_file});
		$self->_input(IO::File->new($self->_input_file));
	}
	
	if(exists $params{input_directory})
	{
		$self->_input_directory($params{input_directory});	
	}
	if(exists $params{database})
	{
		$self->_use_database($params{database});	
	}
	
	if(!defined($self->_use_database) && 
	   !defined($self->_input) && 
	   !defined($self->_input_directory))
	{
		die "Need either a handle to the database, a phd.ball, or a phd_dir\n";
	}
	
	if(exists $params{conserve_memory})
	{
		$self->conserve_memory($params{conserve_memory});	
	}
	else
	{
		$self->conserve_memory(0);
	}
	
	$self->_reader( GSC::IO::Assembly::Phd::Reader->new );
	$self->_writer( GSC::IO::Assembly::Phd::Writer->new );
	if(exists $params{index_file})
	{
		my $fh = IO::File->new($params{index_file});
		$self->_load_index_from_file($fh);
	}
	elsif(exists $params{index})
	{
		my $fh = $params{index};
		$self->_load_index_from_file($fh);
    }
	else
	{
		$self->_build_index();
	}

    return $self;
}

sub _build_index
{
	my ($self) = @_;	

	my $input = $self->_input;
	my %index;
	my $temp=[qw(0)];
	while(<$input>)
	{
       	if(/BEGIN_SEQUENCE/)
        {
            my @tokens = split / /;
            my $offset = tell ($input) - length ($_);
            chomp $tokens[1];
			$$temp[1] = $offset-$$temp[0];#calculate length
			$temp = [$offset];
			$index{$tokens[1]} = $temp;                
        }
	}
	$$temp[1] = ((stat ($input))[7])-$$temp[0];#calculate length
	$self->_index(\%index);

}

sub _load_index_from_file
{
	my ($self, $fh) = @_;
		
	my %index;
	my $input = $self->_input;
	my $temp=[qw(0)];
	while(<$fh>)
	{
		chomp;
		my @tokens = split / /;
		$$temp[1] = $tokens[1]-$$temp[0];#calculate length
		$temp = [$tokens[1]];
		$index{$tokens[0]} = $temp;
	}
	$$temp[1] = ((stat ($input))[7])-$$temp[0];#calculate length
	$self->_index(\%index);		
}

sub get_phd_names
{
	my ($self) = @_;

	return [keys %{$self->_index}];
}

sub get_phd
{
	my ($self, $name) = @_;
	
	my $phd_ball = $self->_input;
	my $index = $self->_index;
	my $reader = $self->_reader;
	my ($read_name, $version) = ($name =~ /(.+)\.phd\.(\d+)$/);

	if(exists $$index{$read_name})
	{
		$phd_ball->seek($$index{$read_name}[0],0);
		my $phd_string;
		read $phd_ball, $phd_string, $$index{$read_name}[1];	
		my $fh = IO::String->new($phd_string);
		return $reader->read($fh);
	}
	elsif(defined $self->_input_directory && -e "$self->_input_directory/$name")
	{
		my $fh = IO::File->new("$self->_input_directory/$name");
		return 	$reader->read($fh);
	}
	elsif(defined $self->_use_database)
	{
	
		if($self->_use_database == 1)
		{
			my $db_read_name = $read_name."-$version";
			my $read = GSC::Sequence::Item->get(sequence_item_name => "$db_read_name");
			die "Could not locate $name\n" if(!defined $read);			
			my $phd_string = $read->phd_content;
			$phd_string = Compress::Zlib::memGunzip($phd_string);
			my $fh = IO::String->new("$phd_string");
			return $reader->read($fh);
		}
		else
		{
			my $proj_name = $self->_use_database;
			my $db_read_name = $proj_name.":$read_name-$version";
			my $read = GSC::Sequence::Item->get(sequence_item_name => "$db_read_name");
			die "Could not locate $name\n" if(!defined $read);			
			my $phd_string = $read->phd_content;
			$phd_string = Compress::Zlib::memGunzip($phd_string);
			my $fh = IO::String->new("$phd_string");
			return $reader->read($fh);		
		}	
	}
	else
	{
		die "Could not locate $name\n";
	}	
}

sub get_latest_phd
{
	my ($self, $read_name) = @_;
	
	my $phd_dir = $self->_input_directory;
	opendir THISDIR, "$phd_dir";
	my @allFiles = readdir THISDIR;

	my $nMax = 1;
	for(my $i = 0;$i<@allFiles;$i++)
	{
		if($allFiles[$i] =~ /$read_name/)
		{
			my ( $Name, $Ext ) = $allFiles[$i] =~ /^(.+\.)(.+)$/;
			if(int($Ext)>$nMax)
			{
				$nMax=int($Ext);
			}
		}
	}
	$nMax++;
	return "$read_name.phd".".$nMax";
}

sub write_phd
{
	my ($self, $name) = @_;

	#figure out the latest read edit
	my $read_name  = ($name =~ /(.+)\.phd\.\d+$/);
	
	my $latest_phd = $self->get_latest_phd($read_name);
	my $phd_dir = $self->_input_directory;
	my $writer = $self->_writer;
	
	if(-e $phd_dir) {die "We need a phd_dir to write new phd files to.\n";}
	
	$writer->write(">IO::File->new($latest_phd)");
}
		
