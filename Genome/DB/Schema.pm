package Genome::DB::Schema;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

use Data::Dumper;
use Finfo::Logging 'fatal_msg';
use Finfo::Validate;
use XML::Simple;

require Genome::DB::Chromosome;
require Genome::DB::ExternalGeneId;
require Genome::DB::Gene;
require Genome::DB::GeneExpression;
require Genome::DB::GeneGeneExpression;
require Genome::DB::Protein;
require Genome::DB::ProcessProfile;
require Genome::DB::ReadGroup;
require Genome::DB::ReadGroupGenotype;
require Genome::DB::Submitter;
require Genome::DB::Transcript;
require Genome::DB::TranscriptSubStructure;
require Genome::DB::Variation;
require Genome::DB::VariationInstance;

__PACKAGE__->register_class('Chromosome', 'Genome::DB::Chromosome');
__PACKAGE__->register_class('ExternalGeneId', 'Genome::DB::ExternalGeneId');
__PACKAGE__->register_class('Gene', 'Genome::DB::Gene');
__PACKAGE__->register_class('GeneExpression', 'Genome::DB::GeneExpression');
__PACKAGE__->register_class('GeneGeneExpression', 'Genome::DB::GeneGeneExpression');
__PACKAGE__->register_class('ProcessProfile', 'Genome::DB::ProcessProfile');
__PACKAGE__->register_class('ProcessProfile', 'Genome::DB::ProcessProfile');
__PACKAGE__->register_class('ProcessProfile', 'Genome::DB::ProcessProfile');
__PACKAGE__->register_class('Protein', 'Genome::DB::Protein');
__PACKAGE__->register_class('ReadGroup', 'Genome::DB::ReadGroup');
__PACKAGE__->register_class('ReadGroupGenotype', 'Genome::DB::ReadGroupGenotype');
__PACKAGE__->register_class('Submitter', 'Genome::DB::Submitter');
__PACKAGE__->register_class('Transcript', 'Genome::DB::Transcript');
__PACKAGE__->register_class('TranscriptSubStructure', 'Genome::DB::TranscriptSubStructure');
__PACKAGE__->register_class('Variation', 'Genome::DB::Variation');
__PACKAGE__->register_class('VariationInstance', 'Genome::DB::VariationInstance');

sub connect_to_dwrac
{
    return __PACKAGE__->connect
    (
        'dbi:Oracle:dwrac',
        'mguser',
        'mguser_prd',
        {
            FetchHashKeyName => "NAME_lc",
            ShowErrorStatement => 1,
            ChopBlanks => 1,
            AutoCommit => 0,
            LongReadLen => 1000000,
        }
    );
}

sub disconnect
{
    my $self = shift;

    return $self->storage->disconnect if $self->storage;

    return 1;
}

sub DESTROY
{
    my $self = shift;

    return $self->disconnect;
}

1;

#$HeadURL$
#$Id$
