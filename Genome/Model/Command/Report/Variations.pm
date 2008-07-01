package Genome::Model::Command::Report::Variations;

use strict;
use warnings;

use above "Genome"; 

use Command;
use Data::Dumper;
use IO::File;
use Genome::DB::Schema;
use Genome::VariantAnnotator;
#use Genome::IndelAnnotator;
#use Genome::SnpAnnotator;
use Tie::File;

class Genome::Model::Command::Report::Variations
{
    is => 'Command',                       
    has => 
    [ 
    # Input Variant Params
    variant_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File of variants",
    },
    variant_type => 
    {
        type => 'String', 
        is_optional => 1,
        doc => "Type of variation: snp, indel",
        default => 'snp',
    },
    # Report File
    report_file_base => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File base for report outputs",
    },
    no_headers =>
    {
        type => 'Boolean',
        is_optional => 1,
        default => 0,
        doc => "Add headers in report outputs",
    },
    # Metrix Params
    minimum_maq_score => 
    {
        is => 'Integer',
        is_optional => 1,
        default => 15,
        doc => 'Minimum quality to consider a variant high quality',
    },
    minimum_read_count => 
    {
        is => 'Integer',
        is_optional => 1,
        default => 3,
        doc => 'Minimum number of total reads to consider a variant high quality',
    },
    # Transcript Params
    flank_range => 
    {
        type => 'Integer', 
        is_optional => 1,
        default => 50000,
        doc => "Range to look around for flaking regions of transcripts",
    },
    # Variation Params
    variation_range => 
    {
       type => 'Integer', 
       is_optional => 1,
       default => 0,
       doc => "Range to look around a variant for known variations",
    },
    ], 
};

############################################################

sub help_brief {   
    return;
}

sub help_synopsis { 
    return;
}

sub help_detail {
    return <<EOS 
    Creates an annotation report for variants in a given file.  Uses Genome::VariantAnnotator or Genome::IndelAnnotator (coming soon!) for each given variant, and outputs the annotation infomation to the given report file.
EOS
}

############################################################

sub execute { 
    my $self = shift;

    my $variant_fh = $self->_open_variant_file;
    my $annotator = $self->_create_annotator;
    $self->_open_report_files;
    my ($transcripts_method, $variations_method, $print_method) = $self->_determine_methods_for_variant_type;

    while ( my $line = $variant_fh->getline )
    {
        chomp $line;
        my %variant;
        @variant{qw/ 
            chromosome_name start stop reference variant 
            reference_type variant_type reference_reads variant_reads
            maq_score
            /} = split(/\s+/, $line);

        my @transcripts = $annotator->$transcripts_method(%variant);
        my @variations = $annotator->$variations_method(%variant);
        $self->$print_method(\%variant, \@transcripts, \@variations);
    }

    $self->_print_metrics_report;
    $self->_close_report_fhs;

    return 1;
}

sub _open_variant_file
{
    my $self = shift;

    my $variant_file = $self->variant_file;
    my $variant_fh = IO::File->new("< $variant_file");
    $self->error_message("Can't open variation file ($variant_file) for reading: $!")
        and return unless $variant_fh;

    return $variant_fh;
}

sub _create_annotator
{
    my $self = shift;

    my $variant_file = $self->variant_file;
    tie my @variants, 'Tie::File', $variant_file;
    my ($chromosome_name, $from) = ( split(/\s+/, $variants[0]) )[0..1];
    my ($chromosome_confirm, $to) = ( split(/\s+/, $variants[$#variants]) )[0..1];
    untie @variants;
    undef @variants;
    $self->error_msg
    (
        "Different chromosome at beginning ($chromosome_name) and end ($chromosome_confirm) of variant file ($variant_file)"
    )
        and return unless $chromosome_name eq $chromosome_confirm;
    
    my $schema = Genome::DB::Schema->connect_to_dwrac;
    $self->error_message("Can't connect to dwrac")
        and return unless $schema;

    my $chromosome = $schema->resultset('Chromosome')->find
    (
        { chromosome_name => $chromosome_name },
    );
    $self->error_message("Can't find chromosome ($chromosome_name)")
        and return unless $chromosome;

    my $annotator = Genome::VariantAnnotator->new
    (
        transcript_window => $chromosome->transcript_window
        (
            from => $from - $self->flank_range,
            to => $to + $self->flank_range,
            range => $self->flank_range
        ),
        variation_window => $chromosome->variation_window
        (
            from => $from,
            to => $to,
            range => $self->variation_range,
        ),
    );

    return $annotator;
}

#- REPORTS -#
sub report_types
{
    return (qw/ metrics transcript variation /);
}

sub report_file_for_type
{
    my ($self, $type) = @_;

    return $self->_report_file($self->report_file_base, $type);
}

sub _report_file
{
    my ($self, $directory, $type) = @_;

    return sprintf('%s.%s', $directory, $type);
}

sub _open_report_files
{
    my $self = shift;

    for my $report_type ( $self->report_types )
    {
        my $report_file = $self->_report_file($self->report_file_base, $report_type);
        unlink $report_file if -e $report_file;
        
        my $report_fh = IO::File->new("> $report_file");
        $self->error_message("Can't open $report_type report file ($report_file) for writing: $!")
            and return unless $report_fh;

        my $headers_method = sprintf('%s_report_headers', $report_type);
        $report_fh->print( join(',', $self->$headers_method), "\n" ) unless $self->no_headers;
        
        my $report_fh_method = sprintf('_%s_report_fh', $report_type);
        $self->$report_fh_method($report_fh);
    }

    return 1;
}

sub _close_report_fhs
{
    my $self = shift;

    for my $report_type ( $self->report_types )
    {
        my $report_fh_method = sprintf('_%s_report_fh', $report_type);
        $self->$report_fh_method->close;
    }
    
    return 1;
}

# report fhs
sub _metrics_report_fh
{
    my ($self, $fh) = @_;

    $self->{_metrics_fh} = $fh if $fh;

    return $self->{_metrics_fh};
}

sub _transcript_report_fh
{
    my ($self, $fh) = @_;

    $self->{_transcript_fh} = $fh if $fh;

    return $self->{_transcript_fh};
}

sub _variation_report_fh
{
    my ($self, $fh) = @_;

    $self->{_variation_fh} = $fh if $fh;

    return $self->{_variation_fh};
}

# report headers
sub metrics_report_headers
{
    return (qw/ total confident distinct /, variation_sources());
}

sub transcript_report_headers
{
    return ( variant_attributes(), transcript_attributes(), variation_attributes() );
}

sub variation_report_headers
{
    return ( variant_attributes(), variation_attributes() );
}

# attributes
sub variant_attributes
{
    return (qw/ chromosome_name start stop variant variant_reads reference reference_reads maq_score /);
}

sub transcript_attributes
{
    return (qw/ gene_name intensity detection transcript_name strand trv_type c_position amino_acid_change /);
}

sub variation_attributes
{
    return ('in_coding_region', variation_sources());
}

sub variation_sources
{
    return (qw/ dbsnp-127 watson venter /);
}

#- METHODS BASED ON TYPE OF VARIANT -#
sub _determine_methods_for_variant_type
{
    my $self = shift;

    my $variant_type = $self->variant_type;

    return
    (
        sprintf('prioritized_transcripts_for_%s', $variant_type),
        sprintf('variations_for_%s', $variant_type),
        sprintf('_print_reports_for_%s', $variant_type),
    );
}

#- PRINT REPORTS -#
sub _print_reports_for_snp
{
    my ($self, $snp, $transcripts, $variations) = @_;

    # Calculate Metrics
    my $is_hq_snp = ( $snp->{maq_score} >= $self->minimum_maq_score 
            and $snp->{reference_reads} + $snp->{variant_reads} >= $self->minimum_read_count )
    ? 1
    : 0;

    $self->{_metrics}->{total}++;
    $self->{_metrics}->{confident}++ if $is_hq_snp;

    # Basic SNP Info
    my $snp_info_string = join
    (
        ',', 
        map { $snp->{$_} } $self->variant_attributes,
    );

    # Variation Report
    my @snp_exists_in_variations;
    if ( @$variations )
    {
        for my $db_source ( $self->variation_sources )
        {
            if ( grep { lc($_->source) eq $db_source } @$variations )
            {
                push @snp_exists_in_variations, 1;
                $self->{_metrics}->{$db_source}++ if $is_hq_snp;
            }
            else
            {
                push @snp_exists_in_variations, 0;
            }
        }
    }
    else
    {
        $self->{_metrics}->{distinct}++ if $is_hq_snp;
        @snp_exists_in_variations = (qw/ 0 0 0 /);
    }

    $self->_variation_report_fh->print
    (
        join
        (
            ',',
            $snp_info_string,
            ( @$transcripts ) ? 1 : 0, # coding
            @snp_exists_in_variations,
        ),
        "\n",
    );

    # Transcripts
    for my $transcripts ( @$transcripts )
    {
        $self->_transcript_report_fh->print
        (
            join
            (
                ',',                   
                $snp_info_string,
                map({ $transcripts->{$_} } $self->transcript_attributes),
                @snp_exists_in_variations,
            ), 
            "\n",
        );
    }

    return 1;
}

sub _print_reports_for_indel
{
    my ($self, $indel, $annotations, $variations) = @_;

    return 1;
}

sub _print_metrics_report
{
    my $self = shift;

    my $metrics = $self->{_metrics};
    print Dumper($metrics);
    
    return $self->_metrics_report_fh->print
    (
        join
        (
            ',',
            map({ $metrics->{$_} || 0 } $self->metrics_report_headers),
        ),
        "\n",
    );
}

1;

=pod

=head1 Name

Genome::Model::Command::Report::Variations

=head1 Synopsis

Goes through each variant in a file, retrieving annotation information from Genome::VariantAnnotator or Genome::IndelAnnotator (coming soon).

=head1 Usage

 $success = Genome::Model::Command::Report::Variations->execute
 (
     chromosome_name => $chromosome, # required
     variant_type => 'snp', # opt, default snp, valid types: snp, indel
     variant_file => $detail_file, # required
     report_file => sprintf('%s/variant_report_for_chr_%s', $reports_dir, $chromosome), # required
     flank_range => 10000, # default 50000
     variant_range => 0, # default 0
 );

 if ( $success )
 { 
    ...
 }
 else 
 {
    ...
 }
 
=head1 Methods

=head2 execute, or create then execute

=over

=item I<Synopsis>   Gets all annotations for a snp

=item I<Arguments>  snp (hash; see 'SNP' below)

=item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

=back

=head1 See Also

B<Genome::VariantAnnotator>, B<Genome::Model::Command::Report::VariationsBatchToLsf>, B<Genome::DB::*>, B<Genome::DB::Window::*>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
