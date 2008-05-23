package Genome::DB::ReadGroup;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('read_group');
__PACKAGE__->add_columns(qw/ 
    read_group_id
    read_group_name
    pp_id
    sample_id
    mg_id
    /);
__PACKAGE__->set_primary_key('read_group_id');
__PACKAGE__->has_many('genotypes', 'Genome::DB::ReadGroupGenotype', 'read_group_id');

sub ordered_genotypes
{
    my $self = shift;

    return $self->genotypes->search(undef, { order_by => [qw/ chrom_id start_ /] });
}

sub ordered_genotypes_for_chromosome
{
    my ($self, $chromosome_name) = @_;

    return $self->genotypes->search
    (
        {
            'chromosome.chromosome_name' => $chromosome_name,
        },
        { 
            join => 'chromosome',
            order_by => 'start_',
            #prefetch => [qw/ chromosome /], 
        },
    );
}

1;

#$HeadURL$
#$Id$
