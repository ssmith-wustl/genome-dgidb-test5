package Genome::Model::Tools::Annotate::NovelVariations;

use strict;
use warnings;

use Genome; 

use Command;
use Data::Dumper;
use IO::File;
use Genome::Utility::IO::SeparatedValueReader;
use Genome::Utility::VariantAnnotator;
use Tie::File;
use Fcntl 'O_RDONLY';
use Carp;

class Genome::Model::Tools::Annotate::NovelVariations {
    is => 'Command',
    has => [ 
        snv_file => {
            type => 'Text',
            is_optional => 0,
            doc => "File of single-nucleotide variants.  Tab separated columns: chromosome_name start stop reference variant reference_type type reference_reads variant_reads maq_score",
        },
    ],
    has_optional => [
        output_file => {
            type => 'Text',
            is_optional => 0,
            doc => "Store annotation in the specified file instead of sending it to STDOUT."
        },
        summary_file => {
            type => 'Text',
            is_optional => 1,
            doc => "Store summary metrics about the SNVs analyzed in a file with the specified name."
        },
        no_headers => {
            type => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => 'Exclude headers in report output',
        },
        # Metrix Params
        minimum_maq_score => {
            is => 'Integer',
            is_optional => 1,
            default => 15,
            doc => 'Minimum quality to consider a variant high quality',
        },
        minimum_read_count => {
            is => 'Integer',
            is_optional => 1,
            default => 3,
            doc => 'Minimum number of total reads to consider a variant high quality',
        },
        # Transcript Params
        flank_range => {
            type => 'Integer', 
            is_optional => 1,
            default => 50000,
            doc => 'Range to look around for flaking regions of transcripts',
        },
        # Variation Params
        variation_range => {
           type => 'Integer',
           is_optional => 1,
           default => 0,
           doc => 'Range to look around a variant for known variations',
        },
    ],
};

############################################################


sub help_synopsis { 
    return <<EOS
gt annotate transcript-variations --snv-file snvs.csv --output-file transcript-changes.csv --summary-file myresults.csv
EOS
}

sub help_detail {
    return <<EOS
Separates novel SNVs from previously discovered ones.
EOS
}

############################################################

sub execute { 
    my $self = shift;
    $DB::single =1;
    
    # generate an iterator for the input list of SNVs
    my $variant_file = $self->snv_file;
    my $variant_svr = Genome::Utility::IO::SeparatedValueReader->create(
        input => $variant_file,
        headers => [qw/
            chromosome_name start stop reference variant 
            reference_type type reference_reads variant_reads
            maq_score
        /],
        separator => '\s+',
        is_regex => 1,
    );
    unless ($variant_svr) {
        $self->error_message("error opening file $variant_file");
        return;
    }
    
    # establish the output handle for the transcript variations
    my $output_fh;
    if (my $output_file = $self->output_file) {
        $output_fh = $self->_create_file($output_file);
    }
    else {
        $output_fh = 'STDOUT';
    }
    $self->_variation_report_fh($output_fh);
    
    # emit headers as necessary
    $output_fh->print( join(',', $self->variation_report_headers), "\n" ) unless $self->no_headers;
    
    # annotate all of the input SNVs...
    my $chromosome_name = '';
    my $variation_window = undef;
    while ( my $variant = $variant_svr->next ) {
        # make a new annotator when we begin and when we switch chromosomes
        unless ($variant->{chromosome_name} eq $chromosome_name) {
            $chromosome_name = $variant->{chromosome_name};
            $self->status_message("generating overlap iterator for $chromosome_name");
            
            my $variant_iterator = Genome::Variation->create_iterator(
                where => [ chrom_name => $chromosome_name] 
            );
            $variation_window =  Genome::Utility::Window::Variation->create( 
                iterator => $variant_iterator,
                range => $self->variation_range
            );
            die Genome::Utility::Window::Variation->error_message unless $variation_window;
        }
        # get the data and output it
        my @variations = grep { $_->start eq $_->stop } $variation_window->scroll($variant->{start});
        $self->_print_reports_for_snp($variant, \@variations);
    }

    # produce a summary as needed
    if (my $summary_file = $self->summary_file) {
        my $summary_fh = $self->_create_file($summary_file);
        $summary_fh->print( join(',', $self->metrics_report_headers), "\n" );
        my $metrics = $self->{_metrics};
        my $result = $summary_fh->print(
            join(
                ',',
                map({ $metrics->{$_} || 0 } $self->metrics_report_headers),
            ),
            "\n",
        );
        unless ($result) {
            die "failed to print a summary report?! : $!";
        }
        $summary_fh->close;
    }
    
    $output_fh->close unless $output_fh eq 'STDOUT';
    return 1;
}

sub _create_file {
    my ($self, $output_file) = @_;
    my $output_fh;
    
    unlink $output_file if -e $output_file;
    if (-e $output_file) {
        $self->warning_message("found previous output file, removing $output_file");
        unlink $output_file;
        if (-e $output_file) {
            die "failed to remove previous file: $! ($output_file)";
        }
    }
    $output_fh = IO::File->new("> $output_file");
    unless ($output_fh) {
        die "Can't open file ($output_file) for writing: $!";
    }
    
    return $output_fh;
}

sub _variation_report_fh {
    my ($self, $fh) = @_;
    $self->{_variation_fh} = $fh if $fh;
    return $self->{_variation_fh};
}

# report headers
sub metrics_report_headers {
    return (qw/ total confident distinct /, variation_sources());
}

sub variation_report_headers {
    return ( variant_attributes(), variation_attributes() );
}

# attributes
sub variant_attributes {
    return (qw/ chromosome_name start stop variant variant_reads reference reference_reads maq_score /);
}

sub variation_attributes {
    #return ('in_coding_region', variation_sources());
    return ( variation_sources());
    #return ('genic', variation_sources());
}

sub variation_sources {
    return (qw/ dbsnp-127 watson venter /);
}

#- PRINT REPORTS -#
sub _print_reports_for_snp {
    my ($self, $snp, $variations) = @_;

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
    if ($variations and @$variations )
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

    # Variations
    $self->_variation_report_fh->print
    (
        join
        (
            ',',
            $snp_info_string,
            @snp_exists_in_variations,
        ),
        "\n",
    );

    return 1;
}

1;


=pod

=head1 Name

Genome::Model::Tools::Annotate::TranscriptVariations

=head1 Synopsis

Goes through each variant in a file, retrieving annotation information from Genome::Utility::VariantAnnotator.

=head1 Usage

 in the shell:
 
     gt annotate transcript-variations --snv-file myinput.csv --output-file myoutput.csv --metric-summary metrics.csv

 in Perl:
 
     $success = Genome::Model::Tools::Annotate::TranscriptVariations->execute(
         snv_file => 'myoutput.csv',
         output_file => 'myoutput.csv',
         summary_file => 'metrics.csv', # optional
         flank_range => 10000, # default 50000
         variation_range => 0, # default 0
     );

=head1 Methods

=over

=item snv_file

An input list of single-nucleotide variations.  The format is:
 chromosome
 position
 reference value
 variant value

=item output_file

The list of transcript changes which would occur as a result of the associated genome sequence changes.

One SNV may result in multiple transcript entries if it intersects multiple transcripts.  One 
transcript may occur multiple times in results if multiple SNVs intersect it.

=item summary_file

A one-row csv "table" with some metrics on the SNVs analyzed.

=item 

=back

=head1 See Also

B<Genome::Utility::VariantAnnotator>, 

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

Core Logic:
 
 B<Xiaoqi Shi> I<xshi@genome.wustl.edu>

Optimization, Testing, Data Management:
 
 B<Dave Larson> I<dlarson@genome.wustl.edu>
 B<Eddie Belter> I<ebelter@watson.wustl.edu>
 B<Gabriel Sanderson> I<gsanderes@genome.wustl.edu>
 B<Adam Dukes> I<adukes@genome.wustl.edu>
 B<Anthony Brummett> I<abrummet@genome.wustl.edu>
 
=cut
