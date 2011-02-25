package GSC::IO::Assembly::Ace::CoverageFilter::ByQual;

use strict;
use warnings;


use base qw(GSC::IO::Assembly::Ace::CoverageFilter);

sub eval_contig
{ 
    my ($self, $contig) = @_;
    my $name= $contig->name;

    $self->create_map($contig);

    #Go thru the quality
    my $map_edit = -1;
    my $ary_index = -1;
    my $quals = $contig->sequence->padded_base_quality;
    foreach my $base ( split //, $contig->sequence->padded_base_string )
    {
		$ary_index++;
		$map_edit = $ary_index + 1;
   		next if $base eq '*';

		$self->edit_map($name, $map_edit, $map_edit) if  $self->check_qual( $quals->[$ary_index] );
	}

    return;
}

sub check_qual
{
    my ($self, $qual) = @_;

    my ($op, $val) = $self->patterns;
    # my $cf = CF::ByQual->new(["<=", 20]);
    if ($op =~ /lt/)
    {
	return 1 if $op eq "lt" and $qual < $val;
	return 1 if $op eq "lte" and $qual <= $val;
    }
    elsif ($op =~ /gt/)
    {
	return 1 if $op eq "gt" and $qual > $val;
	return 1 if $op eq "gte" and $qual >= $val;
    }
    else # "eq"
    {
	return 1 if $op eq "eq" and $qual == $val;
    }

    return;
}

=pod

=head1 Name

GSC::IO::Assembly::Ace::CoverageFilter::ByQual
 
> Creates a map of each given contig representing the areas covered by
   tags.

   ** Inherits from GSC::IO::Assembly::Ace::CoverageFilter **
   
=head1 Synopsis

my $cf = GSC::IO::Assembly::Ace::CoverageFilter::ByQual->new([<pattern>, <threshold>]);
 * pattern: comparative operation: "lt", "lte", "gt", "gte", "eq"
 * threshold: scalar to compare quality values to

foreach my $contig (@contigs)
{
 $cf->eval_contig($contig);
}

my @maps = $cf->all_maps;

do stuff with the map objects...

=head1 Methods

=head2 eval_contig($contig)

 Evaluates the tags in a GSC::IO::Assembly::Contig and creates a contig map.
 
=head1 See Also

Base class -> GSC::IO::Assembly::CoverageFilter
 
=head1 Author

Adam Dukes <adukes@watson.wustl.edu>

=cut

1;
#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/GSC/IO/Assembly/Ace/CoverageFilter/ByQual.pm $
#$Id: ByQual.pm 9340 2006-08-23 19:37:54Z jschindl $

