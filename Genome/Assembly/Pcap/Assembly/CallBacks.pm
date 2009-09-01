package Finishing::Assembly::ItemCallBack;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

#my $pkg = "Finishing::Assembly::ItemCallBack";

sub new 
{
	my $name = (caller(0))[3];
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
	my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;      
	my $self = \%params; 
	bless ($self, $class);
	return $self;
}

sub freeze
{
	my ($self) = @_;
	$self->{fh} = undef;
	$self->{reader}->{'input'} = undef;
}

sub thaw
{
	my ($self, $obj, $file_name, $fh) = @_;
	if(defined $file_name && $file_name eq $self->{file_name})
	{
		$self->{fh} = $fh;
	}
	else
	{
		$self->{fh} = $obj->get_fh($self->{file_name});
	}
	$self->{reader}->{'input'} = $self->{fh};
}

sub get_map {
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";	
}

sub children 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";	
}

sub name 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub position 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";	
}


sub length 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub tags
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub copy
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub add_tag
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
} 

sub copy_tag 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub start_position
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub end_position 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

package Finishing::Assembly::SequenceCallBack;
our $VERSION = 0.01;

use strict;

use warnings;
use Carp;
use Storable;

use Finishing::Assembly::Transform;
#my $pkg = "Finishing::Assembly::SequenceCallBack";

sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %args) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = \%args;
    bless ($self, $class);		
	     
    return $self;
}

#sub freeze
#{
#	my ($self) = @_;
#	$self->{fh} = undef;
#}

#sub thaw
#{
#	my ($self) = @_;
#	$self->{fh} = $fh;
#}
sub freeze
{
	my ($self) = @_;
	$self->{fh} = undef;
	$self->{reader}->{'input'} = undef;
}

sub thaw
{
	my ($self, $obj, $file_name, $fh) = @_;
	if(defined $file_name && $file_name eq $self->{file_name})
	{
		$self->{fh} = $fh;
	}
	else
	{
		$self->{fh} = $obj->get_fh($self->{file_name});
	}
	$self->{reader}->{'input'} = $self->{fh};
}

sub get_map {
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub _transform
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub get_transform
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub _load_transform
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub _has_alignment
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub padded_base_string
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub padded_base_quality
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub unpadded_base_string
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub unpadded_base_quality
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub get_padded_base_quality
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub get_padded_base_value
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub has_alignment
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub copy
{
    my ($self,$item) = @_;
    
	return Storable::dclone($item);    
}

sub length
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

package Finishing::Assembly::SequenceItemCallBack;
our $VERSION = 0.01;

use strict;

use warnings;
use Carp;
use Storable;

use Finishing::Assembly::Transform;
use base(qw(Finishing::Assembly::ItemCallBack));
#my $pkg = "Finishing::Assembly::SequenceItemCallBack";

sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %args) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = \%args;
    bless ($self, $class);		
	     
    return $self;
}

sub get_map {
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub length 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub sequence
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

package Finishing::Assembly::ReadCallBack;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Storable;
use base (qw(Finishing::Assembly::SequenceItemCallBack));

#my $pkg = "Finishing::Assembly::ReadCallBack";

=head1 NAME

Read - Read Callback Object.

=cut
#Read Data Structure
#Read:
#	sequence (bases and quality)
#	align_clip_start
#	align_clip_end
#	qual_clip_start
#	qual_clip_end
#	padded_base_count
#	base_count
#	complemented
#	tags
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
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub complemented
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub align_clip_start 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub align_clip_end 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub qual_clip_start 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub qual_clip_end 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub info_count 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub chromat_file 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub phd_file 
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub time
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

package Finishing::Assembly::ContigCallBack;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Storable;
use base (qw(Finishing::Assembly::SequenceItemCallBack));

#my $pkg = "Finishing::Assembly::ContigCallBack";


#Contig Data Structure
#Contig:
#	sequence (bases and quality)
#	children 
#	get_child
#	padded_base_count
#	base_count
#	read_count
#	complemented
#	tags


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
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub base_count
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub base_segment_count
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

sub complemented
{
	my $name = (caller(0))[3];
    croak "$name is an abstract base method!\n";
}

1;
