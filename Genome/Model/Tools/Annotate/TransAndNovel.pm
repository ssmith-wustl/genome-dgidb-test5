package Genome::Model::Tools::Annotate::TransAndNovel;

use strict;
use warnings;

use Genome; 

use Command;
use Data::Dumper;
use IO::File;
use Tie::File;
use Fcntl 'O_RDONLY';
use Carp;

class Genome::Model::Tools::Annotate::TransAndNovel {
    is => 'Command',
    has => [ 
        # Input Variant Params
        variant_file => {
            type => 'String',
            is_optional => 0,
            doc => "File of variants.  Tab separated columns: chromosome_name start stop reference variant reference_type type reference_reads variant_reads maq_score",
        },
        variant_type => {
            type => 'String', 
            is_optional => 1,
            doc => "Type of variation: snp, indel",
            default => 'snp',
        },
        # Report File
        report_file_base => {
            type => 'String',
            is_optional => 0,
            doc => "File base for report outputs",
        },
        no_headers => {
            type => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => "Add headers in report outputs",
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
            doc => "Range to look around for flaking regions of transcripts",
        },
        # Variation Params
        variation_range => {
           type => 'Integer',
           is_optional => 1,
           default => 0,
           doc => "Range to look around a variant for known variations",
        },
	    build => {
	        is => "Genome::Model::Build",
	        id_by => 'build_id',
            is_optional => 1, 
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
    Creates an annotation report for variants in a given file.  Uses Genome::Transcript::VariantAnnotator for each given variant, and outputs the annotation infomation to the given report file.
EOS
}

############################################################

sub execute { 
    my $self = shift;
    $DB::single =1;
    
    my $variant_file = $self->variant_file;
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
    
    #if no build is provided, use the v0 of our generic NCBI-human-36 imported annotation model
    unless ($self->build){
        my $model = Genome::Model->get(name => 'NCBI-human.combined-annotation');
        my $build = $model->build_by_version(0);
        
        unless ($build){
            $self->error_message("couldn't get build v0 from 'NCBI-human.combined-annotation'");
            return;
        }
        $self->build($build);
    }

    # determine chromosome to speed annotation and sanity check both ends of the file
    $self->status_message(UR::Time->now . " checking chromosome at beginning and end of file");
    tie my @variants, 'Tie::File', $variant_file , mode => O_RDONLY
        or croak "can't tie $variant_file : $!";
    my ($chromosome_name) = split(/\s+/, $variants[0]);
    my ($chromosome_confirm) =  split(/\s+/, $variants[$#variants]);
    untie @variants;
    undef @variants;
    $self->error_message(
        "Different chromosome at beginning ($chromosome_name) and end ($chromosome_confirm) of variant file ($variant_file)"
    )
        and return unless $chromosome_name eq $chromosome_confirm;
    $self->status_message(UR::Time->now . " done checking chromosome at beginning and end of file");
    
    
    # create windowed iterators to go over transcripts
    
    my $transcript_iterator = $self->build->transcript_iterator(chrom_name => $chromosome_name);
    my $transcript_window =  Genome::Utility::Window::Transcript->create (
        iterator => $transcript_iterator, 
        range => $self->flank_range
    );
    my $annotator = Genome::Transcript::VariantAnnotator->create(
        transcript_window => $transcript_window,
        version => $self->build->build,
    );
    
    my $variant_iterator = Genome::Variation->create_iterator(
        where => [ chrom_name => $chromosome_name,
        build_id => $self->build->build_id,
        ] 
    );
    my $variation_window =  Genome::Utility::Window::Variation->create( 
        iterator => $variant_iterator,
        range => $self->variation_range
    );
    
    # create N files, and store handles to each on this object
    for my $report_type ( $self->report_types ) {
        my $report_file = $self->_report_file($self->report_file_base, $report_type);
        unlink $report_file if -e $report_file;
        if (-e $report_file) {
            $self->warning_message("found previous output file, removing $report_file");
            unlink $report_file;
            if (-e $report_file) {
                die "failed to remove previous file: $! ($report_file)";
            }
        }
        
        my $report_fh = IO::File->new("> $report_file");
        unless ($report_fh) {
            die "Can't open $report_type report file ($report_file) for writing: $!";
        }

        my $headers_method = sprintf('%s_report_headers', $report_type);
        $report_fh->print( join(',', $self->$headers_method), "\n" ) unless $self->no_headers;
        
        my $report_fh_method = sprintf('_%s_report_fh', $report_type);
        $self->$report_fh_method($report_fh);
    }

    # annotate!
    my $variant_type = $self->variant_type;
    my $print_method = sprintf('_print_reports_for_%s', $variant_type);    
    while ( my $variant = $variant_svr->next ) {
        my @transcripts = $annotator->prioritized_transcripts(%$variant);
        my @variations = grep { $_->start eq $_->stop } $variation_window->scroll($variant->{start});
        $self->$print_method($variant, \@transcripts, \@variations);        
    }

    # print metrics report
    my $metrics = $self->{_metrics};
    return $self->_metrics_report_fh->print(
        join(
            ',',
            map({ $metrics->{$_} || 0 } $self->metrics_report_headers),
        ),
        "\n",
    );
    
    # close all of the handles
    for my $report_type ( $self->report_types ) {
        my $report_fh_method = sprintf('_%s_report_fh', $report_type);
        $self->$report_fh_method->close;
    }
    
    return 1;
}


#- REPORTS -#
sub report_types {
    return (qw/ metrics transcript variation /);
}

sub report_file_for_type {
    my ($self, $type) = @_;

    return $self->_report_file($self->report_file_base, $type);
}

sub _report_file {
    my ($self, $directory, $type) = @_;

    return sprintf('%s.%s', $directory, $type);
}

# report fhs
sub _metrics_report_fh {
    my ($self, $fh) = @_;
    $self->{_metrics_fh} = $fh if $fh;
    return $self->{_metrics_fh};
}

sub _transcript_report_fh {
    my ($self, $fh) = @_;
    $self->{_transcript_fh} = $fh if $fh;

    return $self->{_transcript_fh};
}

sub _variation_report_fh {
    my ($self, $fh) = @_;
    $self->{_variation_fh} = $fh if $fh;
    return $self->{_variation_fh};
}

# report headers
sub metrics_report_headers {
    return (qw/ total confident distinct genic /, variation_sources());
}

sub transcript_report_headers {
    return ( variant_attributes(), transcript_attributes(), variation_attributes() );
}

sub variation_report_headers {
    return ( variant_attributes(), variation_attributes() );
}

# attributes
sub variant_attributes {
    return (qw/ chromosome_name start stop variant variant_reads reference reference_reads maq_score /);
}

sub transcript_attributes {
    return (qw/ gene_name intensity detection transcript_name strand trv_type c_position amino_acid_change ucsc_cons domain /);
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


    $self->{_metrics}->{genic}++ if @$transcripts;
    
    # Variations
    $self->_variation_report_fh->print
    (
        join
        (
            ',',
            $snp_info_string,
            ( @$transcripts ) ? 1 : 0, # genic
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

#- CALC METRICS -#
# TODO move metric calcing here

1;

=pod

=head1 Name

Genome::Model::Tools::Annotate::TransAndNovel

=head1 Synopsis

Goes through each variant in a file, retrieving annotation information from Genome::Transcript::VariantAnnotator.

=head1 Usage

 $success = Genome::Model::Tools::Annotate::TransAndNovel->execute
 (
     chromosome_name => $chromosome, # required
     variant_type => 'snp', # opt, default snp, valid types: snp, indel
     variant_file => $detail_file, # required
     report_file => sprintf('%s/variant_report_for_chr_%s', $reports_dir, $chromosome), # required
     flank_range => 10000, # default 50000
     variation_range => 0, # default 0
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

B<Genome::Transcript::VariantAnnotator>, B<Genome::Model::Tools::Annotate::TransAndNovel>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: /gscpan/perl_modules/trunk/Genome/Model/Command/Report/Variations.pm $
#$Id: /gscpan/perl_modules/trunk/Genome/Model/Command/Report/Variations.pm 44321 2009-03-05T21:25:17.704205Z adukes  $
