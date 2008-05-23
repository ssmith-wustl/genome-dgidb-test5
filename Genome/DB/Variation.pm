package Genome::DB::Variation;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('variation');
__PACKAGE__->add_columns
(qw/
    variation_id 
    chrom_id
    external_variation_id
    allele_string 
    variation_type
    start_
    end 
    /);
__PACKAGE__->set_primary_key('variation_id');
__PACKAGE__->belongs_to('chromosome', 'Genome::DB::Chromosome', 'chrom_id');
__PACKAGE__->has_one('instance', 'Genome::DB::VariationInstance', 'variation_id');
__PACKAGE__->has_many('variation_instances', 'Genome::DB::VariationInstance', 'variation_id');
__PACKAGE__->many_to_many('submitters', 'variation_instances', 'submitter');

sub start
{
    my ($self, $start) = @_;

    $self->start_($start) if defined $start;
    
    return $self->start_;
}

#- SUBMITTER -#
sub submitter_name
{
    my $self = shift;

    my $submitters = $self->submitters;
    return 'NONE' unless $submitters->count;

    return $submitters->first->submitter_name;
}

sub source
{
    my $self = shift;

    my $submitters = $self->submitters;
    return 'NONE' unless $submitters->count;

    return $submitters->first->variation_source;
}

1;

#$HeadURL$
#$Id$
