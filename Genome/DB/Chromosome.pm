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
    my ($self, %transcript_params) = @_;

    my %search_params;
    if ( exists $transcript_params{from} )
    {
        $search_params{transcript_stop} = { '>' => $transcript_params{from} };
    }

    if ( exists $transcript_params{to} )
    {
        $search_params{transcript_start} = { '<' => $transcript_params{to} };
    }
    
    return $self->transcripts->search
    (
        \%search_params,
        {
            order_by => [qw/ transcript_start transcript_stop /],
        }
    );
}

sub transcript_window
{
    my ($self, %params) = @_;

    my $transcripts = $self->ordered_transcripts(%params);

    my %window_params;
    if ( my $range = delete $params{range} )
    {
        $window_params{range} = $range;
    }
    
    return Genome::DB::Window::Transcript->new
    (
        iterator => $transcripts,
        %window_params,
    );
}

# VARIATIONS
sub ordered_variations
{
    my ($self, %variation_params) = @_;

    my %search_params;
    if ( exists $variation_params{from} )
    {
        $search_params{end} = { '>=' => $variation_params{from} };
    }

    if ( exists $variation_params{to} )
    {
        $search_params{start_} = { '<=' => $variation_params{to} };
    }
    
    return $self->variations->search
    (
        \%search_params, 
        { order_by => [qw/ start_ /], }
    );
}

sub variation_window
{
    my ($self, %params) = @_;

    my $variations = $self->ordered_variations(%params);

    my %window_params;
    if ( my $range = delete $params{range} )
    {
        $window_params{range} = $range;
    }
    
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
