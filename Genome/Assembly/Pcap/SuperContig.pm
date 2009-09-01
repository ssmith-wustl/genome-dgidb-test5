package Finishing::Assembly::SuperContig;
our $VERSION = 0.01;

use strict;
use warnings;
use Carp;

use Finishing::Assembly:
use List::Util qw(min max);
use Utility;
use Storable;


sub new 
{
    croak("$pkg:new:no class given, quitting") if @_ < 1;
	my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
   
        
    
    #eddie suggests to use delete
	
	
	$self->{contigs} = $params{contigs};
        
    return $self;
}


sub contigs
{
	my ($self, $contigs) = @_;

	$self->{contigs} = $contigs if (@_ > 1);	
	 
	return $self->{contigs};
}

sub get_contig_names
{	
	my ($self, $contigs) = @_;
	 
	return keys %{$self->{contigs}};
}

sub normalize
{
	my ($self) = @_;
	my @contig_names = @{$self->get_contig_names};
	@contig_names = sort { $a->name _cmptemp $b->name } @contig_names;
	my $scaff_num=1;
	my $contig_number=1;
	for(my $i = 0;$i<@contig_names;$i++)
	{
		my $contig_name = $contig_names[$i];
		if($scaff_num ne get_num( $contig_name))
		{
			$scaff_num = get_num($contig_name);
			$contig_number = 1;	
		}
		if($contig_number ne get_ext($contig_name))
		{
			$contig_number = get_ext($contig_name);
			next if(!defined $contig_number);
			my $contig = $self->get_contig($contig_name);
			$contig->name("Contig$scaff_num.$contig_number");
			$self->remove_contig($contig_name);
			$self->add_contig($contig);
		}	
	}
}

sub insert_after
{
	my ($self, $name, $super_contig) = @_;
	my %children = %{$self->children};
	my @children = sort { $a->name _cmptemp $b->name} values %children;
	my @after_list = @children;
	my @before_list;
	foreach my $child (@children)
	{
		if($child ne $name)
		{
			push @before_list, unshift(@after_list);
		}
		else
		{
			push @before_list, unshift(@after_list);
			last;
		}	
	}
	my %insert_contigs = %{$super_contigs->children};
	my @insert_contigs = sort { $a->name _cmptemp $b->name} values %insert_contigs;
	push (@before_list,@insert_contigs,@after_list);
	my %new_children = map { $_->name, $_ } @before_list;
}

sub complement
{
	my ($self) = @_;
	my %contigs = %{$self->children};
	my @contigs = values %contigs;
	@contigs = sort { $a->name _cmptemp $b->name } @contigs;
	my @contig_names = map { $_->name }  @contig_names;
	foreach (@contigs)#swap names
	{
		$_->name(pop @contig_names);		
	}
	%contigs = ();
	foreach (@contigs)#complement
	{
		$contigs{$_->name} = $_;
		$_->complement;
		$_->store;
	}
	$self->children(\%children);
}

sub children
{
	my ($self, $value) = @_;
    
    my ($name) = (caller(0))[3] =~ /.+::(.+)/;
    if(@_>1)
    {   
       return $self->check_and_load_data($name, $value);
    }
    return $self->check_and_load_data($name);
}

sub _cmptemp
{
    my ($a, $b) = @_;
    my $num1 = get_num($a);
    my $num2 = get_num($b);
    if($num1 > $num2)
    {
        return 1;
    }elsif($num2 > $num1)
    {
        return -1;
    }
    my $ext1 = get_ext($a);$ext1 = 0 if(!defined $ext1);
    my $ext2 = get_ext($b);$ext2 = 0 if(!defined $ext2);
    if($ext1 > $ext2)
    {
        return 1;
    }elsif($ext2 > $ext1)
    {
        return -1;
    }
    return 0;
    
}

sub get_num
{
    my ($name) = @_;
    my ($ctg_num) = $name =~ /Contig(\d+)\.\d+/;
	($ctg_num) = $name =~ /Contig(\d+)/ if(!defined $ctg_num);
	($ctg_num) = $name =~ /.?(\d+)/ if(!defined $ctg_num);
	
    return $ctg_num;
}

sub get_ext
{
    my ($name) = @_;
    my ($ctg_ext) = $name =~ /Contig\d+\.(\d+)/;
    return $ctg_ext;
}







