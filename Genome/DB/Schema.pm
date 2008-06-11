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

=pod

=head1 Name

Genome::DB::Schema

=head1 Synopsis

ORM using DBIx::Class for the MG schema

=head1 Usage

 my $schema = Genome::DB::Schema->connect_to_dwrac;
 $self->error_message("Can't connect to dwrac")
    and return unless $schema;

 # Get a resultset
 my $chromosome_rs = $schema->resultset("Chromosome");

 # Iterate
 while ( my $chr = $chromosome_rs->next )
 {
    ...
 }

 # Find by primary key
 my $chr = $chromosome_rs->find(2);

 # Search, by other properties
 # returns, resultset (scalar context)
 my $chr_10_rs = $chromsome_rs->search({ chromosome_name => '10' });
 # or objects (array context)
 my ($chr_10) = $chromsome_rs->search({ chromosome_name => '10' });

 See DBIx::Class on CPAN docs for more info.
 
=head1 Methods

=head2 connect_to_dwrac

=over

=item I<Synopsis>   Connects to the dwrac

=item I<Arguments>  none

=item I<Returns>    schema (scalar, object)

=back

=head1 See Also

B<DBIx::Class>, B<Genome::DB::*>, B<Genome::DB::Window::*>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
