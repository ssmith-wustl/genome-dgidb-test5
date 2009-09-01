package Finishing::Assembly::Sequence;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;
use Storable;

use Finishing::Assembly::Transform;
use base(qw(Finishing::Assembly::DataAccessor));
my $pkg = "Finishing::Assembly::Sequence";
#required params, padded_base_string

#cases where same data is stored twice, and needs to be resolved
##1.  padded_base_string and padded_base_qual - pads are duplicated, solution, build transform. - maybe exclude
#2.  padded_base_string and unpadded_base_string -$self->check_and_load_data("unpadded_base_quality",$self->check_and_load_data("unpadded_base_quality")); base values duplicated, solution, build transform
#3.  padded and unpadded base qual - qual values are duplicatedif transform does not exist, create and store both as       #     unpadded_base_quals, if it's not possible to create transform, then die
#cases which don't make sense
#4.   padded_base_quals and unpadded_base_string with no transform - give error and die
#cases with no duplicate data
#a.  padded_base_string and unpadded_base_qual (transform implied in padded base string)
#b.  unpadded_base_string and unpadded_base_qual (with or without transform) 

# the sequence object tries to get the programmer to do things that make sense.  If you have any reason to
# suspect that your data is invalid, then don't use this object, because it will complain and barf on you.
# the sequence object tries to be a container first, conversion tool second.  If the user merely wants to
# read data from one file format and load that into the sequence, then it will act as a container.  The reason
# is that if the programmer is merely loading data, then itIf
# the user wants to load data from multiple places that may have conflicts, then the sequence object will
# go into a stricter mode where it will check for conflicts before accepting that data.  
 
=pod

=head1 NAME
 
Sequence - Sequence class.

=head1 DESCRIPTION
 
Finishing::Assembly::Sequence manages a sequence and provides convenient conversion functions for padding and unpadding sequences.

=head1 METHODS
 
=cut 

=pod

=head1 new

$sequence = Finishing::Assembly::Sequence->new(sequence_state => "padded", padded_base_string => $padded_base_string);           
 
sequence_state - optional, however, required if you want to initialized the sequence during object creation.  There are three sequence states: invalid, padded_sequence, and unpadded_sequence.
 
padded_base_string - optional, however, required if the sequence state is set to "padded" in the argument above.    
 
unpadded_base_string - optional, however, required if the sequence state is set to unpadded in the argument above.    
 
complemented - optional, the default value is false.
    
=cut

sub new {
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};
    bless ($self, $class);
	$self->{recent_bases} = 'both';
	$self->{recent_quals} = 'both';
	$self->{recent_chrom} = 'both';
	$self->{recent_align} = 'both';
	$self->{always_update} = 1;
	if(exists $params{callbacks})
	{
		$self->callbacks($params{callbacks});
	}	
	     
    return $self;
}

=pod

=head1 create_sequence
 
$sequence->create_sequence(sequence_state => "padded", padded_base_string => $padded_base_string, complemented => 0);           
 
This function will create a sequence.  The sequence is invalidated and then recreated with the new data.  Use this function to rebuild the sequence any time the length, pads, or state of the sequence changes.  
    
=cut

sub _transform
{
    my ($self, $transform) = @_;
    
    $self->{transform} = $transform if (@_ > 1);
    
    if($self->{recent_align} eq "transform")
	{
		return $self->{transform};
	}
	else
	{
		$self->{transform} = Finishing::Assembly::Transform->new if(!defined $self->{transform});
		$self->_load_transform;
		$self->{recent_align} = "transform";
        return $self->{transform};
	}
}

=pod

=head1 get_transform
 
$sequence->get_transform;

This function will return a copy of the sequences transform class.
    
=cut

sub get_transform
{
    my ($self) = @_;
	$self->load_data("padded_base_string");
	return $self->_transform->copy($self->_transform);    
}

sub _load_transform
{
    my ($self) = @_;
	
	if(my $string = $self->check_and_load_data("padded_base_string"))
	{
		$self->{transform}->derive_from_base_string($string,'*');
	}		
	else
	{
		die "Could not derive Alignment Information!\n";
	}	
}

sub _has_alignment
{
	my ($self) = @_;
	if($self->{transform}||$self->padded_base_string)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

=pod

=head1 padded_base_string
 
$string = $sequence->padded_base_string($string);

This is a getter setter for the sequences padded_base_string.
    
=cut
sub padded_base_string
{
    my ($self, $value) = @_;
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;
    if(@_ >1)
    {
		#this is a hack, need to add a mechanism for verification of transforms after they have change,
		#until then, the only solution for updating transforms is to nullify the padded versions of
		#the quality arrays
		$self->{recent_quals} = 'unpadded_base_quality' if($self->{recent_quals} =~/both/);
		if($self->{recent_quals}=~/^padded_base_quality/)#should probably check recent_quals instead
		{$self->check_and_load_data("unpadded_base_quality",$self->check_and_load_data("unpadded_base_quality"));}
#		if(defined $self->{padded_chromat_positions})
#		{$self->check_and_load_data("unpadded_chromat_positions",$self->check_and_load_data("unpadded_chromat_positions"));}		
		$self->check_and_load_data($name, $value);
        $self->{recent_bases} = $name;
		$self->{recent_align} = $name;
		
				
    }  
	my $string;  
    if(($self->{recent_bases} =~ /^$name|both/) && ($string = $self->check_and_load_data($name)))
	{
		return $string;
	}
	elsif(($self->{recent_bases} =~ /^$name|both/)&& 
		  ($string = $self->check_and_load_data("unpadded_base_string"))&&
		  $self->_has_alignment) 
	{
		$self->{recent_bases} = 'both';
		$self->{just_load} = 1;#don't want to register a derivation as a data change
		my $temp = $self->check_and_load_data("padded_base_string", $self->_transform->pad_string($string));
		$self->{just_load} = 0;
		return $temp;
    	#return $self->_transform->pad_string($string);		
    }
	elsif(!$self->{always_update}&& ($string = $self->check_and_load_data($name)))
	{
		return $string;
	}
    else
    {
 		warn "Data is undefined\n";
        return "";
    }    
}

=pod

=head1 padded_base_quality
 
$qual_array = $sequence->padded_base_quality(\@qual_array);
 
This is a getter setter for the sequences padded_base_quality array.
    
=cut

sub padded_base_quality
{
    my ($self, $value) = @_;
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;
    if(@_>1)
    {        	    
        $self->check_and_load_data($name, $value);
		$self->check_and_load_data("unpadded_base_quality", []);
		$self->{recent_quals} = $name;                           
    }
	my $base_qual;
	if($self->{recent_quals} =~ /^$name|both/ && 
	   ($base_qual = $self->check_and_load_data($name)))
	{
		return $base_qual;
	}
	elsif($self->{recent_quals} =~ /unpadded_base_quality|both/ && 
		  ($base_qual = $self->check_and_load_data("unpadded_base_quality")) )
	{
		$self->{recent_quals} = 'both';
		$self->{just_load} = 1;#don't want to register a derivation as a data change
		my $temp = $self->check_and_load_data("padded_base_quality", $self->_transform->pad_array($base_qual));
    	$self->{just_load} = 0;
		return $temp;
		#return $self->_transform->pad_array($base_qual);		
    }
	elsif(!$self->{always_update}&&
		  ($base_qual = $self->check_and_load_data($name)))
	{
		return $base_qual;
	}
    else
    {
		die "Data is undefined\n";
        return [];
    }        
}

sub padded_chromat_positions
{
	my ($self, $value) = @_;
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;
    if(@_>1)
    {        	    
        $self->check_and_load_data($name, $value);
		$self->check_and_load_data("unpadded_chromat_positions", undef);
		$self->{recent_chrom} = $name;                           
    }
	my $chrom;
	if($self->{recent_chrom} =~ /^$name|both/ && 
	   ($chrom = $self->check_and_load_data($name)))
	{
		return $chrom;
	}
	elsif($self->{recent_chrom} =~ /unpadded_chromat_positions|both/ && 
	     ($chrom = $self->check_and_load_data("unpadded_chromat_positions"))&&
		 $self->_has_alignment )
	{
		$self->{recent_chrom} = 'both';
    	return $self->_transform->pad_array($chrom);
    }
	elsif($self->{always_update} && ($chrom = $self->check_and_load_data($name)))
	{
		return $chrom;
	}
    else
    {
		die "$name is undefined\n";
        return [];
    }	
}


=pod

=head1 unpadded_base_string
 
$unpadded_base_string = $sequence->unpadded_base_string($unpadded_base_string);

This is a getter setter for the sequence's unpadded_base_string.
    
=cut

sub unpadded_base_string
{
    my ($self, $value) = @_;
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;
    if(@_ > 1)
    {
        $self->check_and_load_data($name,$value);
		$self->_transform if(defined $self->check_and_load_data("padded_base_string")); #go ahead and derive and save transform info if it's there
		$self->check_and_load_data("padded_base_string",undef);
		$self->{recent_bases} = $name;
    }
	my $string;
    if($self->{recent_bases} =~ /^$name|both/ && ($string = $self->check_and_load_data("unpadded_base_string")))
    {
        return $string;        
    }
    elsif($self->{recent_bases} =~ /padded_base_string|both/ && ($string = $self->check_and_load_data("padded_base_string")))
    {
		$self->{recent_bases} = 'both';
		$self->{just_load} = 1;#don't want to register a derivation as a data change
		my $temp = return $self->check_and_load_data("unpadded_base_string", $self->_transform->unpad_string($string));
        $self->{just_load} = 0;
		return $temp;
		#return $self->_transform->unpad_string($string);        
    }
	elsif(!$self->{always_update}&&($string = $self->check_and_load_data("unpadded_base_string")) )
	{
		return $string;	
	}
    else
    {
		die "$name is undefined\n";
        return '';
    }
}

=pod

=head1 unpadded_base_quality
 
$qual_array = $sequence->unpadded_base_quality(\@qual_array);
 
This is a getter setter for the sequence's unpadded_base_quality array.
    
=cut

sub unpadded_base_quality
{
    my ($self, $value) = @_;
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;   
    if(@_ > 1)
    { 
	    $self->check_and_load_data($name,$value);
		#$self->_transform if(defined $self->check_and_load_data("padded_base_quality"));
		#$self->check_and_load_data("padded_base_quality", undef);
		$self->{recent_quals} = $name;
    }
	my $base_qual;
	if($self->{recent_quals} =~ /^$name|both/ &&
	   ($base_qual = $self->check_and_load_data("unpadded_base_quality")))
    {
        return $base_qual;        
    }
    elsif($self->{recent_quals} =~ /padded_base_quality|both/ &&
	      ($base_qual = $self->check_and_load_data("padded_base_quality"))&&
		  $self->_has_alignment)
    {
		$self->{recent_quals} = 'both';
		$self->{just_load} = 1;#don't want to register a derivation as a data change,
		my $temp = $self->check_and_load_data("unpadded_base_quality", $self->_transform->unpad_array($base_qual));
        $self->{just_load} = 0;
		return $temp;
		#return $self->_transform->unpad_array($base_qual);        
    }
	elsif(!$self->{always_update}&&($base_qual = $self->check_and_load_data("unpadded_base_quality")))
	{	
		if($base_qual = $self->check_and_load_data("unpadded_base_quality"))
    	{
    	    return $base_qual;        
    	}		
	}
    else
    {
		die "$name is undefined!\n";
        return [];
    }    
}

sub unpadded_chromat_positions
{
    my ($self, $value) = @_;
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;   
    if(@_ > 1)
    { 
	    $self->check_and_load_data($name,$value);
		#$self->_transform if(defined $self->check_and_load_data("padded_chromat_positions"));
		#$self->check_and_load_data("padded_chromat_positions", undef);
		$self->{recent_chrom} = $name;
    }
	my $chrom;
	if($self->{recent_chrom} =~ /^$name|both/ &&
	   ($chrom = $self->check_and_load_data($name)))
    {
        return $chrom;        
    }
    elsif($self->{recent_chrom} =~ /padded_chromat_positions|both/ &&
	      ($chrom = $self->check_and_load_data("padded_chromat_positions"))&&
		  $self->_has_alignment)
    {
		$self->{recent_chrom} = "both";
        return $self->_transform->unpad_array($chrom);        
    }
	elsif(!$self->{always_update}&&($chrom = $self->check_and_load_data("unpadded_chromat_positions")))
	{	
		if($chrom = $self->check_and_load_data("unpadded_chromat_positions"))
    	{
    	    return $chrom;        
    	}		
	}
    else
    {
		die "$name is undefined!\n";
        return [];
    }    
}

sub get_padded_base_quality
{
	my ($self, $padded_base_position) = @_;
	my $position = ${$self->_transform->{padded_to_unpadded}}[$padded_base_position];
	return 0 if $position eq '*';
	return ${$self->{unpadded_base_quality}}[$position];
}

sub get_padded_base_value
{
	my ($self, $padded_base_position) = @_;
	my $position = ${$self->_transform->{padded_to_unpadded}}[$padded_base_position];
	return "*" if $position eq '*';
	return substr($self->{unpadded_base_string},$position, 1);
}

#new functions

sub replace_chromat_pads
{
	my ($self, $padded_chromat_positions) = @_;
	$padded_chromat_positions = [@{$padded_chromat_positions}];
	my $on_pad = 0;
	my $pad_start_pos = 0;
	my $pad_end_pos = 0;
	for(my $i=0;$i<@{$padded_chromat_positions};$i++)
	{
		if($padded_chromat_positions->[$i] eq '*')
		{
			if($on_pad)
			{
				$pad_end_pos = $i;
			}
			else
			{
				$pad_start_pos = $i;
				$pad_end_pos = $i;
			}
			$on_pad = 1;		
		}
		else 
		{
			if($on_pad)
			{
				$pad_start_pos--;
				$pad_end_pos++;
				my $start_chromat_value = 0;
				my $increment = 0;
				if($pad_start_pos < 0)
				{
					$increment = 5;					
					$start_chromat_value = 5;
					
					
				}
				else
				{
					$increment = ($padded_chromat_positions->[$pad_end_pos] - 
					$padded_chromat_positions->[$pad_start_pos])/($pad_end_pos - $pad_start_pos);
					$start_chromat_value = $padded_chromat_positions->[$pad_start_pos] + $increment;
				}
				for(my $j=($pad_start_pos+1);$j<$pad_end_pos;$j++)
				{
					$padded_chromat_positions->[$j]=int($start_chromat_value + $increment*($j-($pad_start_pos+1)));
				}				
				$on_pad = 0;
			}		
		}	
	}
	if($on_pad)
	{
		$pad_start_pos--;
		$pad_end_pos++;		
		my $start_chromat_value = 0;
		my $increment = 0;
		if($pad_start_pos < 0)
		{				
			$increment = 5;
			$start_chromat_value = 0;
		}
		else
		{
			$increment = 5;
			$start_chromat_value = $padded_chromat_positions->[$pad_start_pos] + $increment;
		}
		for(my $j=($pad_start_pos+1);$j<$pad_end_pos;$j++)
		{
			$padded_chromat_positions->[$j]=int($start_chromat_value + $increment*($j-($pad_start_pos+1)));
		}				
		$on_pad = 0;
	}
	return $padded_chromat_positions;
}

=pod

=head1 copy
 
my $seq_copy = $sequence->copy($seq_copy);           

Returns a deep copy of the Sequence.
    
=cut

sub copy
{
    my ($self,$item) = @_;
    
	return Storable::dclone($item);    
}

=pod

=head1 length

Returns the length of the sequence.

=cut

sub length
{
	my ($self, $type) = @_;
	
	if(defined $type)
	{
		if($type eq "unpadded")
		{
			return $self->_transform->unpad_length;									
		}
		else
		{
			return $self->_transform->pad_length;
		}	
	}
}

1;
