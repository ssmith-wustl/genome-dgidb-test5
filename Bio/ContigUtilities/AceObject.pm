package Bio::ContigUtilities::AceObject;
our $VERSION = 0.01;

=pod

=head1 NAME

AceObject - Object oriented ace file reader/writer

=head1 SYNOPSIS

my $ace_object = Bio::ContigUtilities::AceObject->new(input_file => "inputfilename", output_file => "outputfilename", conserve_memory => 1, input_file_index => "inputfileindex");

 my @contig_names = $ace_object->get_contig_names();
 my $contig = $ace_object->get_contig("Contig0.1");
 $ace_object->remove_contig("Contig0.1");

 $ace_object->write_file;
    
=head1 DESCRIPTION

Bio::ContigUtilities::AceObject indexes an ace file, and allows the user to get Contig objects from the ace file, edit them, and write the file back to the hard disk when finished.

=head1 METHODS

=cut

use strict;
use warnings;
use Carp;
use base qw(Class::Accessor);

use GSC::IO::Assembly::Ace::Reader;
use GSC::IO::Assembly::Ace::Writer;
use Bio::ContigUtilities::Item;
use Bio::ContigUtilities::Sequence;
use Bio::ContigUtilities::SequenceItem;
use Bio::ContigUtilities::Contig;
use Bio::ContigUtilities::Read;
use IO::File;
use Storable;

Bio::ContigUtilities::AceObject->mk_accessors(qw(_reader _writer _input _output _input_file _output_file));

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
	if(exists $params{output})
	{
		$self->_output ( $params{output});		
	}
	elsif(exists $params{output_file})
	{
		$self->_output_file ($params{output_file});
		$self->_output(IO::File->new(">".$self->_output_file));
	}
	if(exists $params{conserve_memory})
	{
		$self->conserve_memory($params{conserve_memory});	
	}
	else
	{
		$self->conserve_memory(0);
	}
	
	$self->_reader ( GSC::IO::Assembly::Ace::Reader->new($self->_input));	
	$self->_build_index($self->_input);
    #$self->_load_index_from_file($self->_input_file.".index");
    
    return $self;
}

sub _build_index
{
	my ($self, $fh) = @_;
	my @contigs;
	my @assembly_tag_indexes;
    my $old_hash = undef;
    my $old_contig = undef;
	
	while(my $line = <$fh>)
	{
		if($line =~ /^AF /)
		{
			my @tokens = split(/[ {]/,$line);			
			my $offset = (tell $fh) - length $line;
            #my $newstring = substr(
            #@{$contigs[$#contigs]{read_position}} = [] if (!defined @{$contigs[$#contigs]{read_position}});
            $old_contig->{contig_length} += length($line) if (defined $old_contig);
            $old_hash = { name => $tokens[1], offset => $offset, length => length($line) };
            push (@{$contigs[$#contigs]{read_positions}}, $old_hash);
		}
		elsif($line =~ /^CO /)
		{
			my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - length $line;
			#my @base_segments;#pre allocate memory
            #$base_segments[$tokens[4]] = 1;
            #delete $base_segments[$tokens[4]];
            $old_contig->{contig_length} = $offset - $old_contig->{offset} if (defined $old_contig);
            $old_hash = { offset => $offset,
                              name => $tokens[1],
                              read_positions => [],
                              reads => [],
                              base_segment => [],#\@base_segments,
                              contig_tags => [] ,
                              contig_loaded => 0 ,
                              length => length($line),
                              contig_length => length($line)};
            $old_contig = $old_hash;
            push (@contigs, $old_hash);
            							  
		}
		elsif($line =~ /^RD /)
		{
			my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - length $line;
            $old_contig->{contig_length} += length($line) if (defined $old_contig);
            $old_hash = { offset => $offset,
                          name => $tokens[1],
                          read_tags => [],
                          length => length($line)};
			push (@{$contigs[$#contigs]{reads}}, $old_hash);
		}
		elsif($line =~ /^WA /)
		{
			my $offset = (tell $fh) - length $line;
            $old_hash = { offset => $offset, length => length($line) };
            $old_contig->{contig_length} = $offset - $old_contig->{offset} if (defined $old_contig);
			$old_contig = undef;
			push (@assembly_tag_indexes, $old_hash);
		}
		elsif($line =~ /^CT{/)
		{
			my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - length $line;
            if(defined $old_contig)
            {
                $old_contig->{contig_length} = $offset - $old_contig->{offset};
			    $old_contig = undef;
            }
            foreach my $contig (@contigs)
			{
				if($contig->{name} eq $tokens[1])
				{
                    $old_hash = {offset => $offset, length => length($line)};
					push (@{$contig->{contig_tags}}, $old_hash);
					last;
				}
			}
		}
		elsif($line =~ /^RT /)
		{
			my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - length $line;
            $old_contig->{contig_length} += length($line) if (defined $old_contig);
			foreach my $read (@{$contigs[$#contigs]{reads}})
			{
				if($read->{name} eq $tokens[1])
				{
                    $old_hash = {offset => $offset, length => length($line)};
					push (@{$read->{read_tags}},$old_hash );
					last;
				}
			}
		}
		elsif($line =~ /^BS /)
		{
			#my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - length $line;
            $old_hash = undef;
            $old_contig->{contig_length} += length($line) if (defined $old_contig);
            push(@{$contigs[$#contigs]{base_segments}}, $offset);
		}
        else
        {
            $old_contig->{contig_length} += length($line) if (defined $old_contig);
            $old_hash->{length} += length($line) if(defined($old_hash));
        }
	}
    #$old_contig->{contig_length} = $old_contig->{length} if(!defined($old_contig->{contig_length})||$old_contig->{length}>$old_contig->{contig_length});
	$self->{contigs} = \@contigs;
	$self->{assembly_tags} = {};
	$self->{assembly_tags}{tags_loaded} = 0;
	$self->{assembly_tags}{tag_indexes} = \@assembly_tag_indexes;	
}

=pod

=head1  get_contig_names 

my @contig_names = $ace_object->get_contig_names();

returns a list of contig names in the ace file.
    
=cut

sub get_contig_names
{
	my $self = shift;
	return [map {$_->{name}} @{$self->{contigs}}] ;
}

=pod

=head1 get_contig 

my $contig = $ace_object->get_contig("Contig0.1");
    
returns a Bio::ContigUtilites::Contig object to the user.

=cut

sub get_contig
{
	my ($self, $contig_name) = @_;
	my @contigs = @{$self->{contigs}};
	my $contig_index;
	my $contig_found = 0;
	foreach my $temp_contig_index (@contigs)
	{
		if($temp_contig_index->{name} eq $contig_name)
		{
            $contig_index = $temp_contig_index;
			$contig_found = 1;
			last;	
		}
	}
	
	return undef if(!$contig_found);	
	if($contig_index->{contig_loaded})
	{
        if($self->conserve_memory)
        {
		    return retrieve $self->_out_file.$contig_name;
        }
        else
        {   
            return $self->_copy_contig($contig_index->{contig_object});
        }
	}
	
	my $input = $self->_input;
	my $reader = $self->_reader;
	my $ace_contig;
	my %reads; #contins read_positions and read_tags
	my @base_segments;
	my @contig_tags;
	
	my $result = $input->seek($contig_index->{offset},0);
	$ace_contig = $reader->next_object;
	#grab reads
	foreach my $read_index (@{$contig_index->{reads}})
	{
		$input->seek($read_index->{offset},0);
		my $ace_read = $reader->next_object;
		$reads{$ace_read->{name}} = Bio::ContigUtilities::Read->new(ace_read => $ace_read);	
	}
	#grab read_positions
	foreach my $read_position_index (@{$contig_index->{read_positions}})
	{
		$input->seek($read_position_index->{offset},0);
		my $ace_read_position = $reader->next_object;
		$reads{$ace_read_position->{read_name}}->ace_read_position ($ace_read_position);	
	}	
	#grab read_tags
	foreach my $read_tag_index (@{$contig_index->{read_tags}})
	{
		$input->seek($read_tag_index->{offset},0);
		my $read_tag = $reader->next_object;
		$reads{$read_tag->{name}}->add_tag($read_tag);	
	}	
	#grab contig_tags
	foreach my $contig_tag_index (@{$contig_index->{contig_tags}})
	{
		$input->seek($contig_tag_index->{offset},0);
		my $contig_tag = $reader->next_object;
		push @contig_tags, $contig_tag;	
	}
	#grab base_segments
	foreach my $base_segment_index (@{$contig_index->{base_segments}})
	{
		$input->seek($base_segment_index,0);
		my $base_segment = $reader->next_object;
		push @base_segments, $base_segment;	
	}
	#glue everything together
    my $contig = Bio::ContigUtilities::Contig->new(ace_contig => $ace_contig,
                                                reads => \%reads,
                                                contig_tags => \@contig_tags,
                                                base_segments => \@base_segments);
	
	
	return $contig;	
}

sub conserve_memory
{
    my ($self, $conserve_memory) = @_;
    
    if(@_>1)
    {
        $self->{conserve_memory} = $conserve_memory;
    }
    return $self->{conserve_memory};
}

=pod

=head1 add_contig 

 my $contig = $ace_object->get_contig("Contig0.1");
 ...
 $ace_object->add_contig($contig);
    
inserts a contig into the ace file.  If a contig with that name already exists, then it is overwritten by the data in the newly added contig.

=cut

sub add_contig
{
	my ($self, $contig) = @_;
	my @contigs = @{$self->{contigs}};
	my $contig_index;
	my $contig_found = 0;
	foreach $contig_index (@contigs)
	{
		if($contig_index->{name} eq $contig->name)
		{
			$contig_found = 1;
			last;	
		}
	}
	
	if ($contig_found)
	{
		$contig_index->{offset} = -1;
		$contig_index->{contig_loaded} = 1;
        if($self->conserve_memory)
        {
            store $contig, $self->_output_file.$contig->name;
        }
        else
        {
		    $contig_index->{contig_object} = $contig->copy($contig);
        }
	}
	else
	{
        if($self->conserve_memory)
        {
            store $contig, $self->_output_file.$contig->name;   
		    $contig_index = { offset => -1, contig_loaded => 1, name => $contig->name, contig_object => undef };
        	push(@{$self->{contigs}},$contig_index);
		}
        else
        {
            $contig_index = { offset => -1, contig_loaded => 1, name => $contig->name, contig_object => $contig->copy($contig) };
	    	push(@{$self->{contigs}},$contig_index);
		}   
    }	
}

=pod

=head1 remove_contig 

$ace_object->remove_contig("Contig0.1");
    
returns a Contig from the ace file.

=cut

sub remove_contig
{
	my ($self, $contig_name) = @_;
	my @contig_indexes = @{$self->{contigs}};	
	for(my $i=0;$i< @contig_indexes;$i++)
	{		
		if($contig_indexes[$i]->{name} eq $contig_name)
		{
			splice (@{$self->{contigs}}, $i, 1);
			last;	
		}
	}
}

=pod

=head1 get_assembly_tags 

my @assembly_tags = $ace_object->get_assembly_tags;
    
returns an array off assembly tags to the user.

=cut

sub get_assembly_tags
{
	my ($self) = @_;
	my $input = $self->_input;
	my $reader = $self->_reader;
	
	if(!($self->{assembly_tags}{tags_loaded}))
	{
        my @assembly_tags;
		foreach my $assembly_tag_index (@{$self->{assembly_tags}{tag_indexes}})
		{		
			$input->seek($assembly_tag_index->{offset},0);
			my $assembly_tag = $reader->next_object;
			push @assembly_tags, $assembly_tag;
		}
        $self->{assembly_tags}{tags} = \@assembly_tags;
        $self->{assembly_tags}{tags_loaded} = 1; 
	}
    return [ map {$self->_copy_assembly_tag($_)} @{$self->{assembly_tags}{tags}} ];	
	
}
=pod

=head1 set_assembly_tags 

$ace_object->set_assembly_tags(\@assembly_tags);
    
replaces the current array of assembly tags in the ace file with a new list of assembly tags.

=cut

sub set_assembly_tags
{
	my ($self, $assembly_tags) = @_;	
	$self->{assembly_tags}{tags} = [ map {$self->_copy_assembly_tag($_)} @{$assembly_tags}];
	$self->{assembly_tags}{tags_loaded} = 1;
}

=pod

=head1 write_file

$ace_object->write_file;
    
This function will write the ace object in it's current state to the output ace file specified during object construction.

=cut

sub write_file
{
    my ($self, %params) = @_;
	#reopen output file
	
	if(exists $params{output})
	{
		$self->_output ( $params{output});				
	}
	elsif(exists $params{output_file})
	{
		$self->_output_file ($params{output_file});
		$self->_output(IO::File->new(">".$self->_output_file));
	}
	elsif(defined $self->_output)
	{
		$self->_output->seek(0,0) or die "Could not seek to beginning of write file\n";		
	}
	else
	{
		die "Could not find find file to write to.\n";
	}
	$self->_writer (GSC::IO::Assembly::Ace::Writer->new($self->_output));
    #first, come up with a list of read and contig counts
	my $read_count;
	my $contig_count;
	my @contigs = @{$self->{contigs}};
	$contig_count = @contigs;
	
	foreach my $contig (@contigs)
	{
		if($contig->{offset} != -1)
		{
			$read_count += @{$contig->{reads}}; 
		}
		else
		{
			$read_count += keys %{$contig->{contig_object}->reads};
		}
	}
	my $ace_assembly = { type => 'assembly', 
	                      contig_count => $contig_count,
						  read_count => $read_count };
	$self->_writer->write_object($ace_assembly);
	#write out contigs
	foreach my $contig_index (@contigs)
	{
		if($contig_index->{offset} == -1)
		{
			$self->_write_contig_from_object($contig_index->{contig_object});
		}
		else
		{
			$self->_write_contig_from_file($contig_index);
		}	
	}
	#write out assembly tags
	if($self->{assembly_tags}{tags_loaded})
	{
		foreach my $assembly_tag (@{$self->{assembly_tags}{tags}})
		{
			$self->_writer->write_object($assembly_tag);
		}	
	}
	else
	{
		foreach my $assembly_tag_index (@{$self->{assembly_tags}{tag_indexes}})
		{
			$self->_input->seek($assembly_tag_index->{offset},0);
			my $assembly_tag = $self->_reader->next_object;
			$self->_writer->write_object($assembly_tag);	
		}
	}
	#$self->_output->close;	
	$self->_output->autoflush(1);
}

sub _write_contig_from_object
{
	my ($self, $contig) = @_;
	my $writer = $self->_writer;
	my %reads = %{$contig->reads}; #contins read_positions and read_tags
	my @base_segments = @{$contig->{base_segments}};
	my @contig_tags = @{$contig->{tags}};
	
	#first write contig	hash
    $writer->write_object($contig->ace_contig);
	
	#write out read positions
	foreach my $read (values %reads)
	{
		$writer->write_object($read->ace_read_position);
	}
	#write out base segments
	foreach my $base_segment (@base_segments)
	{
		$writer->write_object($base_segment);
	}
	#write out read and read tags
	foreach my $read (values %reads)
	{
		$writer->write_object($read->ace_read);
		foreach my $read_tag (@{$read->tags})
		{
			$writer->write_object($read_tag);
		}
	}
	
	#write out contig tags
	foreach my $contig_tag (@contig_tags)
	{
		$writer->write_object($contig_tag);
	}
}

sub _write_contig_from_file
{
	my ($self, $contig_index) = @_;
	my $input = $self->_input;
    my $output = $self->_output;
	my $writer = $self->_writer;
	my $reader = $self->_reader;
	my @reads_index = @{$contig_index->{reads}}; #contins read_positions and read_tags
    my @read_positions_index = @{$contig_index->{read_positions}};
	my @base_segments_index = @{$contig_index->{base_segments}};
	my @contig_tags_index = @{$contig_index->{contig_tags}};
	if(0)
    {
	#first write contig	hash
	$input->seek($contig_index->{offset},0);
	my $contig = $reader->next_object;
	$writer->write_object($contig);
	#write out read positions
	foreach my $read_position_index (@read_positions_index)
	{
		$input->seek($read_position_index->{offset},0);
		my $read_position = $reader->next_object;
		$writer->write_object($read_position);
	}
	#write out base segments
	foreach my $base_segment_index (@base_segments_index)
	{
		$input->seek($base_segment_index,0);
		my $base_segment = $reader->next_object;
		$writer->write_object($base_segment);
	}
	#write out read and read tags
	foreach my $read_index (@reads_index)
	{
		$input->seek($read_index->{offset},0);
		my $read = $reader->next_object;
		$writer->write_object($read);
		foreach my $read_tag_index (@{$read_index->{read_tags}})
		{
			$input->seek($read_tag_index->{offset},0);
			my $read_tag = $reader->next_object;
			$writer->write_object($read_tag);
		}
	}
	}
    
    #write out contig
    my $contig_string;
    $input->seek($contig_index->{offset},0);
    $input->read($contig_string, $contig_index->{contig_length});
    print $output $contig_string;	
	#write out contig tags
	foreach my $contig_tag_index (@contig_tags_index)
	{
		$input->seek($contig_tag_index->{offset},0);
		my $contig_tag = $reader->next_object;
		$writer->write_object($contig_tag);
	}
}

sub _write_index_to_file
{
    my ($self, $file_name) = @_;
    
    my $hindex = {};
    $hindex->{contigs} = $self->{contigs};
    $hindex->{assembly_tags} = $self->{assembly_tags};
    
    store $hindex, $file_name;
    return;
    
    my $fh = IO::File->new(">$file_name");
    
    my @contig_indexes = @{$self->{contigs}};
    my @assembly_tag_indexes = @{$self->{assembly_tags}{tag_indexes}};
    foreach my $contig_index (@contig_indexes)
    {
        print $fh "CO $contig_index->{name} $contig_index->{offset} $contig_index->{length} $contig_index->{contig_length}\n";
        foreach my $read_index (@{$contig_index->{reads}})
        {
            print $fh "RD $read_index->{name} $read_index->{offset} $read_index->{length}\n";
            foreach my $read_tag_index (@{$read_index->{read_tags}})
            {
                print $fh "RT $read_tag_index->{name} $read_tag_index->{offset} $read_tag_index->{length}\n"
            }
        }
        foreach my $read_position_index (@{$contig_index->{read_positions}})
        {
            print $fh "AF $read_position_index->{name} $read_position_index->{offset} $read_position_index->{length}\n";
        }        
        foreach my $base_segment_index (@{$contig_index->{base_segments}})
        {
            print $fh "BS $base_segment_index\n";
        }
        foreach my $contig_tag_index (@{$contig_index->{contig_tags}})
        {
            print $fh "CT $contig_tag_index->{offset} $contig_tag_index->{length}\n";
        }        
    }
    foreach my $assembly_tag_index (@assembly_tag_indexes)
    {
        print $fh "WA $assembly_tag_index->{offset} $assembly_tag_index->{length}\n";
    }
    $fh->close;    
}

sub _load_index_from_file
{
    my ($self, $file_name) = @_;
    
    my $hindex = retrieve $file_name;
    
    $self->{contigs} = $hindex->{contigs};
    $self->{assembly_tags} = $hindex->{assembly_tags};
    return;
    
    my $fh = IO::File->new("$file_name");
    my @contig_indexes;
    my @assembly_tag_indexes;
    while(my $line = <$fh>)
    {
        chomp $line;
        if($line =~ /^AF/)
        {
            my @tokens = split(' ',$line);           
            
            push (@{$contig_indexes[$#contig_indexes]->{read_positions}}, { name => $tokens[1], offset => $tokens[2], length => $tokens[3] });
        }
        elsif($line =~ /^CO/)
        {
            my @tokens = split(' ',$line);            
            
            push (@contig_indexes, { offset => $tokens[2],
                              name => $tokens[1],
                              read_positions => [],
                              reads => [],
                              base_segment => [],#\@base_segments,
                              contig_tags => [] ,
                              contig_loaded => 0 ,
                              length => $tokens[3],
                              contig_length => $tokens[4]});        
                                          
        }
        elsif($line =~ /^RD/)
        {
            my @tokens = split(' ',$line);                       
            
            push (@{$contig_indexes[$#contig_indexes]{reads}}, { offset => $tokens[2],
                          name => $tokens[1],
                          read_tags => [],
                          length => $tokens[3]});
        }
        elsif($line =~ /^WA/)
        { 
            my @tokens = split(' ',$line);           
            push (@assembly_tag_indexes, { offset => $tokens[1], length => $tokens[2]});
        }
        elsif($line =~ /^CT{/)
        {
            my @tokens = split(' ',$line);            
            
            push (@{$contig_indexes[$#contig_indexes]{contig_tags}}, {offset => $tokens[1], length => $tokens[2]});            
        }
        elsif($line =~ /^RT/)
        {
            #my @tokens = split(/[ {]/,$line);
            #my $reads = {{$contigs[$#contigs]{reads}[{read_tags}}                   
            #push (@{{$contigs[$#contigs]{reads}[{read_tags}}, {offset => $offset, length => length($line)} );
                    
        }
        elsif($line =~ /^BS/)
        {
            my @tokens = split(' ',$line);                        
            push(@{$contig_indexes[$#contig_indexes]{base_segments}}, $tokens[1]);
        }   
    
    }
    $fh->close;
}

sub _copy_assembly_tag
{
	my ($self, $assembly_tag) = @_;
	return { type => 'assembly_tag',
	         program => $assembly_tag->{tag_type},
			 date => $assembly_tag->{date},
			 data => $assembly_tag->{data}};
}



1;
