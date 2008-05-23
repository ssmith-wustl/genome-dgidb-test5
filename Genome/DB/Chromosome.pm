package Genome::DB::Chromosome;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';
use Genome::DB::Window::Transcript;
use Genome::DB::Window::Variation;

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('chromosome');
__PACKAGE__->add_columns(qw/ chrom_id chromosome_name /);
__PACKAGE__->set_primary_key('chrom_id');
__PACKAGE__->has_many('transcripts', 'Genome::DB::Transcript', 'chrom_id');
__PACKAGE__->has_many('variations', 'Genome::DB::Variation', 'chrom_id');

# TRANSCRIPTS
sub ordered_transcripts
{
    my $self = shift;

    return $self->transcripts->search
    (
        undef, 
        {
            order_by => [qw/ transcript_start transcript_stop /],
            #prefetch => 'sub_structures',
        }
    );
}

sub transcript_window
{
    my ($self, %window_params) = @_;

    my $transcripts = $self->ordered_transcripts;

    return Genome::DB::Window::Transcript->new
    (
        iterator => $transcripts,
        %window_params,
    );
}

# VARIATIONS
sub ordered_variations
{
    my $self = shift;

    return $self->variations->search
    (
        undef, 
        { order_by => [qw/ start_ /], }
    );
}

sub variation_window
{
    my ($self, %window_params) = @_;

    my $variations = $self->ordered_variations;

    return Genome::DB::Window::Variation->new
    (
        iterator => $variations,
        %window_params,
    );
}

sub snp_window
{
    my ($self, %window_params) = @_;

    my $snps = $self->variations->search
    (
        { variation_type => 'SNP' }, 
        { order_by => [qw/ start_ /], }
    );

    return Genome::DB::Window::Variation->new
    (
        iterator => $snps,
        %window_params,
    );
}


sub indel_window
{
    my ($self, %window_params) = @_;

    my $indels = $self->variations->search
    (
        { variation_type => '??' }, 
        { order_by => [qw/ start_ /], }
    );

    return Genome::DB::Window::Variation->new
    (
        iterator => $indels,
        %window_params,
    );
}

1;

#$HeadURL$
#$Id$
