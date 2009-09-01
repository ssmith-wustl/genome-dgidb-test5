use Genome::Assembly::Pcap::CallBacks;
package Genome::Assembly::Pcap::SQLiteItemCallBack;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Genome::Assembly::Pcap::Tag;
use Storable;

use base(qw(Genome::Assembly::Pcap::ItemCallBack));

sub new
{
	croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
	my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = $class->SUPER::new(%params);    
	
	return $self;
}

sub base_count
{

}

package Genome::Assembly::Pcap::SQLiteSequenceCallBack;
our $VERSION = 0.01;

use strict;

use warnings;
use Carp;
use Storable;
use base(qw(Genome::Assembly::Pcap::SequenceCallBack));

sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %args) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    
    my $self = $class->SUPER::new(%args);
    
    return $self;
}

sub padded_base_string
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);      
    
    $object->padded_base_string($sequence);
    return 1;
}

sub padded_base_quality
{
    return 0;
}

sub unpadded_base_string
{
    return 0;
}

sub unpadded_base_quality
{
    return 0;
}

sub has_alignment
{
    return "padded_base_string";
}

package Genome::Assembly::Pcap::SQLiteReadCallBack;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Storable;
use base (qw(Genome::Assembly::Pcap::SequenceItemCallBack));

=cut
Contig Data Structure
Contig:
    sequence (bases and quality)
    children 
    get_child
    padded_base_count
    base_count
    read_count
    complemented
    tags
=cut

sub new 
{
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = $class->SUPER::new(%params);

    return $self;
}

sub get_map {
    my ($self) = @_;
    return { read_position   => [ 'name', 'complemented', 'position' ],
             read => [ 'name', 'padded_base_count', 'length', 'info_count', 'tags' ],
             sequence => [ 'padded_base_string' ],
             qa => [ 'qual_clip_start', 'qual_clip_end', 'align_clip_start', 'align_clip_end'],
             ds => [ 'chromat_file', 'phd_file', 'time', 'chemistry', 'dye' ]
           };
}

#methods inherited from ItemCallBack

sub position 
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    $object->position($obj->{position});
    return 1;    
}


sub length 
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    $object->length($ret_val{padded_base_count});

    return 1;   
}

sub _build_read_tag {
    my ($self, $obj) = @_;
    my $tag = new Genome::Assembly::Pcap::Tag(
        type => $obj->{tag_type},
        date => $obj->{date},
        source => $obj->{program},
        parent => $obj->{read_name},
        scope => 'ACE',
        start => $obj->{start_pos},
        stop => $obj->{end_pos},
    );
    return $tag;
}


sub tags
{
    my ($self,$object) = @_; 
    return 1 unless (@_ > 1); 
    my $input = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    my $name = $self->{name};
    my @tags = @{$index->{reads}{name}{read_tags}};  
    my @read_tags;
    foreach my $tag_index (@tags)
    {
        $input->seek($tag_index->{offset},0);
        my $read_tag = $self->_build_read_tag($reader->next_object);
        push @read_tags, $read_tag;    
    }
    $object->tags( \@read_tags );
    return 1;
}

sub copy
{
    my ($self) = @_;
    return dclone ($self);
}

sub copy_tag 
{
    my ($self, $tag) = @_;
    return dclone $tag;
}

sub start_position
{
    my ($self) = @_;
    return $self->position;
    return 1;    
}

sub end_position 
{
    my ($self) = @_;
    return $self->position + $self->length;
    return 1;
}

#methods inherited from SequenceItemCallBack

sub sequence
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $rs_callback = Genome::Assembly::Pcap::AceReadSequenceCallBack->new(name => $self->{name},
    index => $self->{index}, reader => $self->{reader}, fh => $self->{fh} );
    my $sequence = Genome::Assembly::Pcap::Sequence->new(callbacks => $rs_callback);    
    $object->sequence($sequence); 
    return 1;   
}

sub info_count
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    $fh->seek($index->{reads}{$self->name}{read}{offset},0);
    my $line = <$fh>;
    chomp $line;
    my @tokens = split / /,$line;
    my %ret_val = (
        padded_base_count => $tokens[1],
        info_count => $tokens[2],
        tag_count => $tokens[3]);
    $object->length($ret_val{padded_base_count}) if !$object->already_loaded("length"); ;
    $object->info_count($ret_val{info_count});
    return 1;
}

sub chromat_file 
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    $fh->seek($index->{reads}{$self->name}{ds}{offset},0);
    my $line = <$fh>;
    chomp $line;
     $line =~ s/ (\w+): /|$1|/g; #delimit the key-value pairs
    my @tokens = split(/\|/, $line); 
    shift @tokens; # drop the DS tag
    my %description = @tokens;
    
    $object->chromat_file($description{CHROMAT_FILE});
    $object->phd_file($description{PHD_FILE}) if !$object->already_loaded("phd_file"); ;
    $object->time($description{TIME}) if !$object->already_loaded("time");
    $object->chemistry($description{CHEM}) if !$object->already_loaded("chemistry");
    $object->dyetype($description{DYE}) if !$object->already_loaded("dye");
    return 1;    
}

sub phd_file 
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    $fh->seek($index->{reads}{$self->name}{ds}{offset},0);
    my $line = <$fh>;
    chomp $line;
     $line =~ s/ (\w+): /|$1|/g; #delimit the key-value pairs
    my @tokens = split(/\|/, $line); 
    shift @tokens; # drop the DS tag
    my %description = @tokens;
    
    $object->chromat_file($description{CHROMAT_FILE}) if !$object->already_loaded("chromat_file");
    $object->phd_file($description{PHD_FILE});
    $object->time($description{TIME}) if !$object->already_loaded("time");
    $object->chemistry($description{CHEM}) if !$object->already_loaded("chemistry");
    $object->dyetype($description{DYE}) if !$object->already_loaded("dye");
    return 1;    
}

sub time
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    $fh->seek($index->{reads}{$self->name}{ds}{offset},0);
    my $line = <$fh>;
    chomp $line;
     $line =~ s/ (\w+): /|$1|/g; #delimit the key-value pairs
    my @tokens = split(/\|/, $line); 
    shift @tokens; # drop the DS tag
    my %description = @tokens;
    
    $object->chromat_file($description{CHROMAT_FILE}) if !$object->already_loaded("chromat_file");;
    $object->phd_file($description{PHD_FILE}) if !$object->already_loaded("phd_file");
    $object->time($description{TIME});
    $object->chemistry($description{CHEM}) if !$object->already_loaded("chemistry");
    $object->dyetype($description{DYE}) if !$object->already_loaded("dyetype");
    return 1;    
}

# aa01a01.x1 -> forward, thermoseq
# aaa01a01.g3 ->
# M_BB0392D19PCR12c14_g14.b1 -> pcr 
# M_BB0392D19PCR12c14_g14e2.b1 -> pcr 
# M_BB0392D19PCR12c14_14.b4e1 -> pcr 
# /_(\w+)(\d+)$/

sub chemistry
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    $fh->seek($index->{reads}{$self->name}{ds}{offset},0);
    my $line = <$fh>;
    chomp $line;
     $line =~ s/ (\w+): /|$1|/g; #delimit the key-value pairs
    my @tokens = split(/\|/, $line); 
    shift @tokens; # drop the DS tag
    my %description = @tokens;
    
    $object->chromat_file($description{CHROMAT_FILE}) if !$object->already_loaded("chromat_file");;
    $object->phd_file($description{PHD_FILE}) if !$object->already_loaded("phd_file"); ;
    $object->time($description{TIME}) if !$object->already_loaded("time");
    $object->chemistry($description{CHEM});
    $object->dyetype($description{DYE}) if !$object->already_loaded("dye");
    return 1;    




}

sub dyetype
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    $fh->seek($index->{reads}{$self->name}{ds}{offset},0);
    my $line = <$fh>;
    chomp $line;
     $line =~ s/ (\w+): /|$1|/g; #delimit the key-value pairs
    my @tokens = split(/\|/, $line); 
    shift @tokens; # drop the DS tag
    my %description = @tokens;
    
    $object->chromat_file($description{CHROMAT_FILE}) if !$object->already_loaded("chromat_file");;
    $object->phd_file($description{PHD_FILE}) if !$object->already_loaded("phd_file"); ;
    $object->time($description{TIME}) if !$object->already_loaded("time");
    $object->chemistry($description{CHEM}) if !$object->already_loaded("chemistry");
    $object->dyetype($description{DYE});
    return 1;    


}
sub complemented
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    my $reader = $self->{reader};
    $fh->seek($index->{reads}{$self->name}{read_position}{offset},0);
    my $obj = $reader->next_object;
    $object->position($obj->{position}) if !$object->already_loaded("position");
    $object->complemented($obj->{complemented});
    return 1;
}



package Genome::Assembly::Pcap::SQLiteContigSequenceCallBack;
our $VERSION = 0.01;

use strict;

use warnings;
use Carp;
use Storable;

use Genome::Assembly::Pcap::Transform;
use base(qw(Genome::Assembly::Pcap::SequenceCallBack));

sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %args) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};
    bless ($self, $class); 
    $self->{fh} = $args{fh};
    $self->{index} = $args{index};      
    return $self;
}

sub padded_base_string
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    
    my $consensus;
    my $fh = $self->{fh};
    my $index = $self->{index};
    $fh->seek($index->{offset},0);
    
    my $line = <$fh>;	
	#$fh->read($consensus, 1000);
    while ($line = <$fh>) 
    {
        if (length($line) == 1) 
        {
            last;
        }
		if ( (substr( $_, 0, 1 ) eq " ") ||(substr( $_, 0, 1 ) eq "\t" )) 
		{
        	last if ( $_ =~ /^\s*$/ );
        }		
		
        chomp $line;        
        $consensus .= $line;
    }
    $object->padded_base_string($consensus);
    return 1; 
}

sub padded_base_quality
{
    return 0;           
}

sub unpadded_base_string
{
    return 0;    
}

sub unpadded_base_quality
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->{index};
    $fh->seek($index->{bq_offset},0);       
    while (my $line = <$fh>) 
    {
        if ($line =~ /^BQ/) 
        {
            last;
        }
    }
    my @bq;
    while (my $line = <$fh>) 
    {
        if ($line =~ /^\s*$/) 
        {
            last;
        }
        chomp $line;
        $line =~ s/^ //; # get rid of leading space
        push @bq, split(/ /,$line);
    }
    $object->unpadded_base_quality(\@bq);  
    return 1; 
}

sub has_alignment
{
    return "padded_base_string";
}

package Genome::Assembly::Pcap::SQLiteContigCallBack;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Storable;
use base (qw(Genome::Assembly::Pcap::SequenceItemCallBack));

=cut
Contig Data Structure
Contig:
    sequence (bases and quality)
    children 
    get_child
    padded_base_count
    base_count
    read_count
    complemented
    tags
=cut

sub new 
{
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = $class->SUPER::new(%params);
    
    return $self;   
}

sub get_map {
    my ($self) = @_;
    return { contig   => [ 'name', 'complemented', 'base_count', 'length', 'read_count', 'base_seg_count' ],
             sequence => [ 'padded_base_string' ],
             quality => [ 'unpadded_base_quality' ],
             base_segments => [ 'base_segments' ],
             tags => [ 'tags' ],
             children => [ 'children' ],
           };
}

#methods inherited from ItemCallBack

sub position 
{
    my ($self,$object) = @_;    
    return 0;    
}


sub length 
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->_index;
    my $reader = $self->{reader};
    my $name = $self->{name};
    $fh->seek($index->{offset},0);
    my $line = <$fh>;
    chomp $line;
    my @tokens = <$fh>;
    my %ret_val = (
        base_count => $tokens[2],
        read_count => $tokens[3],
        base_seg_count => $tokens[4],        
        u_or_c => $tokens[5],
    );    
    $object->length($ret_val{base_count});
    $object->base_count($ret_val{base_count}) if !object->already_loaded("base_count");
    $object->read_count($ret_val{read_count}) if !$object->already_loaded("read_count");
    $object->base_segment_count($ret_val{base_seg_count}) if !$object->already_loaded("base_segment_count");
    $object->complemented(lc($ret_val{u_or_c})eq"C"?1:0) if !$object->already_loaded("complemented");
    return 1;   
}

sub _build_read_tag {
    my ($self, $obj) = @_;
    my $tag = new Genome::Assembly::Pcap::Tag(
        type => $obj->{tag_type},
        date => $obj->{date},
        source => $obj->{program},
        parent => $obj->{read_name},
        scope => 'ACE',
        start => $obj->{start_pos},
        stop => $obj->{end_pos},
    );
    return $tag;
}


sub tags
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);  
    my $input = $self->{fh};
    my $index = $self->_index;
    my $reader = $self->{reader};
    my $name = $self->{name};
    my @tags = @{$index->{contig_tags}};  
    my @contig_tags;
    foreach my $tag_index (@tags)
    {
        $input->seek($tag_index->{offset},0);
        my $contig_tag = Genome::Assembly::Pcap::TagParser->new()->parse($input);
        push @contig_tags, $contig_tag;    
    }
    $object->tags( \@contig_tags );
    return 1;
}

sub copy
{
    my ($self) = @_;
    return dclone ($self);
}

sub copy_tag 
{
    my ($self, $tag) = @_;
    return dclone $tag;
}

sub start_position
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    $object->start_position($self->position);
    return 1;    
}

sub end_position 
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    $object->end_position($self->position + $self->length);
    return 1;
}

sub base_count
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->_index;
    my $reader = $self->{reader};
    my $name = $self->{name};
    $fh->seek($index->{offset},0);
    my $line = <$fh>;
    chomp $line;
    my @tokens = split / /, $line;
    my %ret_val = (        
        base_count => $tokens[2],
        read_count => $tokens[3],
        base_seg_count => $tokens[4],        
        u_or_c => $tokens[5],
    );         
    $object->base_count($ret_val{base_count});#probably should add length
    $object->read_count($ret_val{read_count}) if !$object->already_loaded("read_count"); 
    #$object->base_segment_count($ret_val{base_seg_count}) if !$object->already_loaded("base_segment_count");
    $object->complemented(lc($ret_val{u_or_c})eq"C"?1:0) if !$object->already_loaded("complemented");
    return 1;       
}

sub base_segment_count
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    $object->base_segment_count($self->_index->{base_segments}{line_count});
    
    return 1;
}

sub complemented
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->_index;
    my $reader = $self->{reader};
    my $name = $self->{name};
    $fh->seek($index->{offset},0);
    my $line = <$fh>;
    chomp $line;
    my @tokens = split / /,$line;
    my %ret_val = (        
        base_count => $tokens[2],
        read_count => $tokens[3],
        base_seg_count => $tokens[4],        
        u_or_c => $tokens[5],
    );    
    $object->base_count($ret_val{base_count}) if !$object->already_loaded("base_count");
    $object->read_count($ret_val{read_count}) if !$object->already_loaded("read_count"); 
    #$object->base_segment_count($ret_val{base_seg_count}) if !$object->already_loaded("base_segment_count");
    $object->complemented(lc($ret_val{u_or_c})eq"C"?1:0);
    return 1;      
    
}

sub read_count
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->_index;
    my $reader = $self->{reader};
    my $name = $self->{name};
    $fh->seek($index->{offset},0);
    my $line = <$fh>;
    chomp $line;
    my @tokens = split / /,$line;
    my %ret_val = (        
        base_count => $tokens[2],
        read_count => $tokens[3],
        base_seg_count => $tokens[4],        
        u_or_c => $tokens[5],
    );    
    $object->base_count($ret_val{base_count}) if !$object->already_loaded("base_count");
    $object->read_count($ret_val{read_count});
    #$object->base_segment_count($ret_val{base_seg_count}) if !$object->already_loaded("base_segment_count"); 
    $object->complemented(lc($ret_val{u_or_c})eq"C"?1:0) if !$object->already_loaded("complemented");
    return 1;
}
    

sub sequence
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $cs_callback = Genome::Assembly::Pcap::AceContigSequenceCallBack->new(name => $self->{name},
    index => $self->_index, reader => $self->{reader}, fh => $self->{fh} );
    my $sequence = Genome::Assembly::Pcap::Sequence->new(callbacks => $cs_callback);    
    $object->sequence($sequence); 
    return 1;   
}

sub base_segments
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my $fh = $self->{fh};
    my $index = $self->_index;
    my $reader = $self->{reader};
    $fh->seek($index->{base_segments}{offset},0);
    my @base_segments;
    while(my $obj = $reader->next_object)
    {
        last if($obj->{type} ne "base_segment");
        push @base_segments, $obj;
    }
    $object->base_segments(\@base_segments);    
    return 1;
}

sub children
{
    my ($self,$object) = @_;
    return 1 unless (@_ > 1);
    my %children;
    foreach my $read_index (values %{$self->_index->{reads}} )
    {
        my $read_callback = Genome::Assembly::Pcap::AceReadCallBack->new(name => $read_index->{read}{name},
        index => $self->_index, reader => $self->{reader}, fh => $self->{fh} );
        my $read = Genome::Assembly::Pcap::Read->new(callbacks => $read_callback);
        $children{$read_index->{read}{name}} = $read;        
    }
    $object->children(\%children);
    return 1;
}

sub _index
{
	my ($self) = @_;
	#if($self->{index}{contig_indexed})
	#{
		return $self->{index};
	#}
	#else
	#{
	#	$self->{index} = $self->_build_contig_index($self->{fh},$self->{index}{offset});
	#	$self->{index}{contig_indexed} = 1;
	#	return $self->{index};
	#}
}

sub _build_contig_index
{
	my ($self, $fh, $file_offset) = @_;
	my %contigs;
	my @assembly_tag_indexes;
    my $old_hash = undef;
    my $contig = undef;
    my $first_bs = 1;
    my $found_bq = 0;
    my $found_qa = 0;
    my $found_af = 0;
    my $found_rd = 0;
	my $co_count = 0;
	my $line = <$fh>;
    $fh->seek($file_offset,0) if defined $file_offset;
	
	#build contig data structures
	my @tokens = split(/[ {]/,$line);
	my $offset = (tell $fh) - CORE::length( $line);            

	$old_hash = { offset => $offset,
                      name => $tokens[1],
                      read_count => $tokens[3],
                      base_segments => {line_count => $tokens[4]},#\@base_segments,
                      contig_tags => [] ,
                      contig_loaded => 0 ,
					  contig_indexed => 1,
                      length => CORE::length($line),
					  sequence_length => $tokens[2],
                      contig_length => CORE::length($line)};
    $contig = $old_hash;    
    $found_af = 0;
    $found_rd = 0;
	$fh->seek($tokens[2],1);            							  
		
	while(my $line = <$fh>)
	{
		my $first_three = substr($line, 0,3);        
		if($first_three eq "BS ")
		{           
            my $offset = (tell $fh) - CORE::length $line;
            $old_hash = undef;            
            $contig->{base_segments}{offset} = $offset;
			foreach(my $i = 0;$i<$contig->{base_segments}{line_count};$i++)
			{
				my $line = <$fh>;			
			}            
			
			my $offset2 = tell $fh;
	        $contig->{base_segments}{length} = $offset2 - $contig->{base_segments}{offset};
            
		}
		elsif($first_three eq "AF ")
		{
			if($found_bq == 1)
            {
                $contig->{base_qualities}{length} = (tell $fh) - CORE::length($line) - $contig->{base_qualities}{offset};
                $found_bq = 0;
            }
			my @tokens = split(/[ {]/,$line);
            my $end = (tell $fh);			
			my $offset = $end - CORE::length $line;            
            $old_hash = { name => $tokens[1], offset => $offset };
            $contig->{reads}{$tokens[1]}{read_position}= $old_hash;
            $contig->{af_start} = $offset;
			foreach(my $i=1;$i<$contig->{read_count};$i++)
			{
				my $line = <$fh>;
				my @tokens = split(/[ {]/,$line);
            	my $end = (tell $fh);			
				my $offset = $end - CORE::length $line;            
            	$old_hash = { name => $tokens[1], offset => $offset };
            	$contig->{reads}{$tokens[1]}{read_position}= $old_hash;				
            }		
			
            $contig->{af_end} = (tell $fh);
            
		}
		elsif($first_three eq "RD ")
		{
			my @tokens = split(/[ {]/,$line);
			my $offset = (tell $fh) - CORE::length $line;
			if(!$found_rd)
			{
				$contig->{rd_start} = $offset ;			
            	$found_rd = 1;
			}
			$old_hash = { offset => $offset,
                          name => $tokens[1],
                          read_tags => [],
                          length => CORE::length($line)};
                        
                        
            $old_hash->{sequence}{offset} = (tell $fh)+1;
			$fh->seek($tokens[2],1);
			$contig->{reads}{$tokens[1]}{read} = $old_hash;			
			
		}        
		elsif($first_three eq "CO ")
		{
			$contig->{contig_length} = $offset - $contig->{offset};
			$contig->{rd_end} = $offset;
			$fh->seek(- CORE::length($line),1);
			last;
		
		}		
		elsif(substr($first_three,0,2) eq "BQ")
        {
            my $offset = (tell $fh) - CORE::length $line;
            $contig->{base_qualities}{offset} = $offset; 
            $contig->{base_sequence}{length} = ($offset-1)-$contig->{offset};
			$found_bq = 1;
			$fh->seek($contig->{sequence_length}*2,1);
			
        }
		elsif($first_three eq "WA ")
		{
			my $offset = (tell $fh) - CORE::length $line;
            $fh->seek(-CORE::length($line),1);
			last;
		}
		elsif($first_three eq "CT{")
		{
			my $offset = (tell $fh) - CORE::length $line;
			$fh->seek(-CORE::length ($line),1);
			last;
			
		}
		elsif(substr($line,0,3) eq "DS ")
		{
			my $offset = (tell $fh) - CORE::length $line;
        	$old_hash->{ds}{offset} = $offset;  
        	$old_hash->{length} = $offset - $old_hash->{offset};							
		}
		elsif(substr($line,0,3) eq "QA ")
		{
        	my $offset = (tell $fh) - CORE::length $line;
        	$old_hash->{qa}{offset} = $offset;
        	$old_hash->{sequence}{length} = ($offset - 1) - $old_hash->{sequence}{offset};
		    $old_hash->{length} = $offset - $old_hash->{offset};
        }
		elsif($first_three eq "RT{")
		{
			my $offset = (tell $fh) - CORE::length $line;
			my $first_length = CORE::length $line;
			$line = <$fh>;
			my @tokens = split(/[ {]/,$line);            
			$old_hash = {offset => $offset, length => (CORE::length($line)+ $first_length)};
			push (@{$contig->{reads}{$tokens[0]}{read}{read_tags}} ,$old_hash );	
			
		}		        
        else
        {            
            $old_hash->{length} += CORE::length($line) if(defined($old_hash));
        }
	}    
	return $contig;

}


1;


