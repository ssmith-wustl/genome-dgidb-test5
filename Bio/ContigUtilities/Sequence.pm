package Bio::ContigUtilities::Sequence;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Bio::ContigUtilities::Transform;
my $pkg = "Bio::ContigUtilities::Sequence";
#required params, padded_base_string

#cases where same data is stored twice, and needs to be resolved
##1.  padded_base_string and padded_base_qual - pads are duplicated, solution, build transform. - maybe exclude
#2.  padded_base_string and unpadded_base_string - base values duplicated, solution, build transform
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
 
Bio::ContigUtilities::Sequence manages a sequence and provides convenient conversion functions for padding and unpadding sequences.

=head1 METHODS
 
=cut 

=pod

=head1 new

$sequence = Bio::ContigUtilities::Sequence->new(sequence_state => "padded", padded_base_string => $padded_base_string);           
 
sequence_state - optional, however, required if you want to initialized the sequence during object creation.  There are three sequence states: invalid, padded_sequence, and unpadded_sequence.
 
padded_base_string - optional, however, required if the sequence state is set to "padded" in the argument above.    
 
unpadded_base_string - optional, however, required if the sequence state is set to unpadded in the argument above.    
 
complemented - optional, the default value is false.
    
=cut

sub new {
    croak("$pkg:new:no class given, quitting") if @_ < 1;
    my ($caller, %args) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};
    bless ($self, $class);
    
    $self->invalidate_sequence();  
    if(exists $args{sequence_state} && $args{sequence_state} ne "invalid")
    {
        $self->create_sequence(%args);   
    }     
    return $self;
}

=pod

=head1 create_sequence
 
$sequence->create_sequence(sequence_state => "padded", padded_base_string => $padded_base_string, complemented => 0);           
 
This function will create a sequence.  The sequence is invalidated and then recreated with the new data.  Use this function to rebuild the sequence any time the length, pads, or state of the sequence changes.  
    
=cut

sub create_sequence
{
    my ($self, %args) = @_;
    
    if($self->_sequence_state ne "invalid")
    {
        #die "Sequence state must be invalided before it can be created.\n"
        $self->invalidate_sequence;
    }
    
    if(exists $args{complemented})
    {
        $self->complemented ( $args{complemented});
    }
    else
    {
        $self->complemented (0);
    }    
    #$self->check_consistency(%args);
    if($args{sequence_state} eq "padded")
    {
        $self->{sequence_state} = "padded";
        $self->{padded_base_string} = $args{padded_base_string};
        $self->{init} = 0;
        #$self->padded_base_string ($args{padded_base_string});
        $self->{padded_base_quality} = [];
    }
    
    if($args{sequence_state} eq "unpadded")
    {
        $self->{sequence_state} = "unpadded";
        $self->unpadded_base_string ($args{unpadded_base_string});
    }   
}

sub init
{
    my ($self) = @_;
    $self->{init}=1;
    $self->padded_base_string ($self->{padded_base_string});
    $self->{padded_base_string} = undef;
}
sub _sequence_state
{
    my ($self, $sequence_state) = @_;
    
    $self->{sequence_state} = $sequence_state if (@_ > 1);
    
    return $self->{sequence_state};
}

sub _transform
{
    my ($self, $transform) = @_;
    
    $self->{transform} = $transform if (@_ > 1);
    
    return $self->{transform};
}

=pod

=head1 invalidate_sequence
 
$sequence->invalidate_sequence;

This function will set the sequence_state to invalid and delete all internal data. 
      
=cut

sub invalidate_sequence
{
    my ($self) = @_;
    
    $self->_sequence_state ("invalid");
    $self->_transform( undef);
    
    $self->{unpadded_base_string} = undef;
    $#{$self->{unpadded_base_quality}} = -1;
}
=pod

=head1 get_transform
 
$sequence->get_transform;

This function will return a copy of the sequences transform class.
    
=cut

sub get_transform
{
    my ($self) = @_;
    return undef if($self->_sequence_state ne "padded");
    $self->init() if (!$self->{init});    
    return $self->{transform}->copy($self->{transform});    
}

=pod

=head1 padded_base_string
 
$string = $sequence->padded_base_string($string);

This is a getter setter for the sequences padded_base_string.
    
=cut
sub padded_base_string
{
    my ($self, $padded_base_string) = @_;
    if(!$self->{init}&&($self->_sequence_state eq "padded"))
    {
        return $self->{padded_base_string};
    }
    if(@_ >1)
    {
        if(defined $self->{transform})
        {
            $self->{transform}->check($padded_base_string) or die "need to invalidiate sequence before changing length or padding.\n";
        
        }
        else
        {
            $self->{transform} = Bio::ContigUtilities::Transform->new($padded_base_string);
        }
        $self->{unpadded_base_string} = $self->{transform}->unpad_string($padded_base_string);
        return $padded_base_string;
    }    
    if( defined $self->{transform})
    {
        return $self->{transform}->pad_string($self->{unpadded_base_string});  
    }
    else
    {
        return undef;
    }
}

=pod

=head1 padded_base_quality
 
$qual_array = $sequence->padded_base_quality(\@qual_array);
 
This is a getter setter for the sequences padded_base_quality array.
    
=cut

sub padded_base_quality
{
    my ($self, $padded_base_quality) = @_;
    if(!$self->{init}&&($self->_sequence_state eq "padded"))
    {
        $self->init;
    }
    if(@_>1)
    {
        if(defined $self->{transform})
        {
            if(!$self->{transform}->check($padded_base_quality))
            {
                die "length of padded base quality does not match length of padded sequence.\n";
            }
            $self->{unpadded_base_quality} = $self->{transform}->unpad_array($padded_base_quality);
            return $padded_base_quality;
        } 
        else
        {
            die "padded base quality requires a padded sequence first.";
        }          
    }
    if(defined $self->{transform})
    {
        return $self->{transform}->pad_array($self->{unpadded_base_quality});
    }
    else
    {
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
    my ($self, $unpadded_base_string) = @_;
    if(!$self->{init}&&($self->_sequence_state eq "padded"))
    {
        $self->init;
    }    
    if(@_ > 1)
    {
        if(length ($self->{unpadded_base_string}) != length($unpadded_base_string) &&
           length ($self->{unpadded_base_string}) > 0)
        {
            die "Need to invalidate sequence before changing length of sequence.";
        }
        $self->{unpadded_base_string} = $unpadded_base_string 
    }
    return $self->{unpadded_base_string};
}

=pod

=head1 unpadded_base_quality
 
$qual_array = $sequence->unpadded_base_quality(\@qual_array);
 
This is a getter setter for the sequence's unpadded_base_quality array.
    
=cut

sub unpadded_base_quality
{
    my ($self, $unpadded_base_quality) = @_;
    if(!$self->{init}&&($self->_sequence_state eq "padded"))
    {
        $self->{unpadded_base_quality} = $unpadded_base_quality if (@_>1);
        return $self->{unpadded_base_quality};
    }    
    if(@_ > 1)
    {    
        if(length $self->{unpadded_base_string} != @{$unpadded_base_quality})
        {
            die "Need to invalidate sequence before changing length of sequence.";
        }
        $self->{unpadded_base_quality} = $unpadded_base_quality;
    }
    $self->{unpadded_base_quality} = [] if(!defined $self->{unpadded_base_quality});
    
    return $self->{unpadded_base_quality};
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

=pod

=head1 complemented
 
$sequence->complemented           

Getter/Setter for complemented boolean value.
    
=cut

sub complemented
{
    my ($self, $complemented) = @_;
    
    $self->{complemented} = $complemented if $complemented;
    return $self->{complemented};
}


=pod

=head1 copy
 
my $seq_copy = $sequence->copy($seq_copy);           

Returns a deep copy of the Sequence.
    
=cut

sub copy
{
    my ($self) = @_;
    
    if($self->{sequence_state} eq "padded")
    {
        if(!$self->{init})
        {
            my $new_copy = $self->new(complemented => $self->complemented,
                              sequence_state => "padded",
                              padded_base_string => $self->{padded_base_string});
            $new_copy->{unpadded_base_quality} = [@{$self->unpadded_base_quality}];
            return $new_copy;
        }
        my $new_copy = $self->new();
        $new_copy->{sequence_state} = $self->get_sequence_state;
        $new_copy->_transform ($self->get_transform->copy($self->get_transform));
        $new_copy->{unpadded_base_string} = $self->unpadded_base_string;
        $new_copy->{unpadded_base_quality} = $self->unpadded_base_quality;
        $new_copy->{complemented} = $self->complemented;
        
        return $new_copy;   
               
    }
    elsif($self->{state} eq "unpadded")
    {
        my $new_copy = $self->new();
        $new_copy->{sequence_state} = $self->get_sequence_state;
        $new_copy->{unpadded_base_string} = $self->unpadded_base_string;
        $new_copy->{unpadded_base_quality} = $self->unpadded_base_quality;
        $new_copy->{complemented} = $self->complemented;
        
        return $new_copy;    
    }
    else #invalid
    {   
        return $self->new();    
    }     
    
}

=pod

=head1 get_sequence_state
        
my $seq_state = $sequence->get_sequence_state;

Returns the current sequence state.
    
=cut

sub get_sequence_state
{
    my ($self) = @_;
    
    return $self->{sequence_state};
}

1;
