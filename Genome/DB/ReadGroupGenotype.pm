package Genome::DB::ReadGroupGenotype;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('read_group_genotype');
__PACKAGE__->add_columns(qw/ 
    rgg_id 
    read_group_id
    genotype_id
    rgg_id
    chrom_id
    start_
    end
    allele1
    allele2
    allele1_type
    allele2_type
    num_reads1
    num_reads2
    pile_up_depth
    /);
__PACKAGE__->set_primary_key('rgg_id');
__PACKAGE__->belongs_to('chromosome', 'Genome::DB::Chromosome', 'chrom_id');

sub start
{
    my ($self, $start) = @_;

    $self->start_($start) if defined $start;
    
    return $self->start_;
}

sub chromosome_name
{
    return shift->chromosome->chromosome_name;
}

1;

#$HeadURL$
#$Id$
