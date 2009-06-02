package Genome::Model::Tools::Annotate::NovelVariations;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use IO::File;

class Genome::Model::Tools::Annotate::NovelVariations {
    is => 'Genome::Model::Tools::Annotate',
    has => [ 
        variant_file => {
            type => 'Text',
            is_optional => 0,
            doc => "File of variants.  Tab separated columns: chromosome_name start stop reference variant",
        },
    ],
    has_optional => [
        output_file => {
            type => 'Text',
            is_optional => 1,
            doc => "Store annotation in the specified file instead of sending it to STDOUT."
        },
        no_headers => {
            type => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => 'Exclude headers in report output',
        },
        # Variation Params
        indel_range => {
           type => 'Integer',
           is_optional => 1,
           default => 0,
           doc => 'Range to look around an indel for known variations... does not apply to snps',
        },
        submitter_filter => {
            type => 'Text',
            is_optional => 1,
            doc => 'Comma separated list of submitters to consider from dbsnp. Results will not include submitters not mentioned. Default is no filter.',
        },
        build => {
            is => "Genome::Model::Build",
            id_by => 'build_id',
            is_optional => 1, 
        },
    ],
};

############################################################


sub help_synopsis { 
    return <<EOS
gt annotate novel-variations --variant-file snvs.csv --output-file transcript-changes.csv
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
    
    my $variant_file = $self->variant_file;

    my $variant_svr = Genome::Utility::IO::SeparatedValueReader->create(
        input => $variant_file,
        headers => [ $self->variant_attributes ],
        separator => "\t",
        ignore_extra_columns => 1,
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
    
    # omit headers as necessary
    $output_fh->print( join(',', $self->variation_report_headers), "\n" ) unless $self->no_headers;
    
    # annotate all of the input SNVs...
    my $chromosome_name = '';
    my $variation_window = undef;
    while ( my $variant = $variant_svr->next ) {
        # make a new annotator when we begin and when we switch chromosomes
        unless ($variant->{chromosome_name} eq $chromosome_name) {
            $chromosome_name = $variant->{chromosome_name};
            $self->status_message("generating overlap iterator for $chromosome_name");
            
            # Apply the filter on submitters if necessary
            my $variant_iterator;
            if ($self->submitter_filter) {
                my @valid_submitters = split (",", $self->submitter_filter);
                $variant_iterator = Genome::Variation->create_iterator(
                    where => [ 
                    chrom_name => $chromosome_name,
                    build_id => $self->build->build_id,
                    submitters => \@valid_submitters,
                    ]
                );
            } else {
                $variant_iterator = Genome::Variation->create_iterator(
                    where => [ 
                    chrom_name => $chromosome_name,
                    build_id => $self->build->build_id,
                    ]
                );
            }
            $variation_window =  Genome::Utility::Window::Variation->create( 
                iterator => $variant_iterator,
                range => $self->indel_range
            );
            die Genome::Utility::Window::Variation->error_message unless $variation_window;
        }
        # get the data and output it
        my @variations = $variation_window->scroll($variant->{start});

        # Find the valid varations... any indel that was returned and any snp
        # That is at the exact position sought (snps dont have a range, only indels)
        my @valid_variations;
        for my $variation (@variations) {
            if (($self->is_valid_variation($variation))&&
                ($self->variation_in_range($variant, $variation))) {
                    push @valid_variations, $variation;
                }
        }
        
        $self->_print_reports_for_snp($variant, \@valid_variations);
    }

    return 1;
}

# This method filters out invalid variations according to some filter logic...
# Right now it simply filters out "snps" that have a reference or variant length != 1
sub is_valid_variation {
    my ($self, $variation) = @_;

    # No filter on anything but snps for now sooo... anything else is ok
    unless ($variation->variation_type =~ /SNP/i) {
        return 1;
    }

    if ((length($variation->reference) != 1)||
        (length($variation->variant) != 1)) {
        return 0;
    }

    return 1;
}

# This method checks to see if the variation is in range of the current variant considered
# in order to consider this a "hit"
# Indels have some "fudge factor" but snps must be a direct hit
sub variation_in_range {
    my ($self, $variant, $variation) = @_;

    my $type = $variation->variation_type;
    # Indels returned within range should be considered
    # should we check for range here? Should not have to since since window only returns stuff in range anyways...
    if ($type =~ /INS|DEL/i) {
        return 1;
    # SNPs should only be considered if they are on the same position as the original variant, no range here
    } elsif (($type =~ /SNP/i)&&($variation->{start} == $variant->{start})&&($variation->{stop} == $variant->{stop})) {
        return 1;
    # DNPs should only be considered if they are on the same position as the original variant, no range here
    } elsif (($type =~ /DNP|MNP/i)&&($variation->{start} == $variant->{start})&&($variation->{stop} == $variant->{stop})) {
        return 1;
    } else {
        if ($type =~ /INS|DEL|SNP|DNP|MNP/i) {
            $self->warning_message("Junk data from data source (SNP with start and stop not equal?). Variation is: " . Dumper $variation);
        } else {
            $self->warning_message("Variation from data source has type $type, which is not supported. Variation is: " . Dumper $variation);
        }
    }

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

sub variation_report_headers {
    my $self = shift;
    return ( $self->variant_attributes(), $self->variation_attributes() );
}

sub variation_attributes {
    my $self = shift;
    return ( $self->variation_sources());
}

sub variation_sources {
    my $self = shift;
    return (qw/ dbsnp-127 watson venter /);
}

#- PRINT REPORTS -#
sub _print_reports_for_snp {
    my ($self, $variant, $variations) = @_;

    # Basic SNP Info
    my $variant_info_string = join
    (
        ',', 
        map { $variant->{$_} } $self->variant_attributes,
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
            }
            else
            {
                push @snp_exists_in_variations, 0;
            }
        }
    }
    else
    {
        @snp_exists_in_variations = (qw/ 0 0 0 /);
    }

    # Variations
    $self->_variation_report_fh->print
    (
        join
        (
            ',',
            $variant_info_string,
            @snp_exists_in_variations,
        ),
        "\n",
    );

    return 1;
}

1;


=pod

=head1 Name

Genome::Model::Tools::Annotate::NovelVariations

=head1 Synopsis

Goes through each variant in a file, retrieving dbsnp, watson, and venter information.

=head1 Usage

 in the shell:
 
     gt annotate novel-variations --variant-file myinput.csv --output-file myoutput.csv --variation-range 0

 in Perl:
 
     $success = Genome::Model::Tools::Annotate::NovelVariations->execute(
         variant_file => 'myoutput.csv',
         output_file => 'myoutput.csv',
         variation_range => 0, # default 0
     );

=head1 Methods

=over

=item variant_file

An input list of single-nucleotide variations.  The format is:
 chromosome_name
 start
 stop
 reference
 variant

=item output_file

A list of all input variants and whether that variant exists in watson, venter, and dbsnp.

=item 

=back

=head1 See Also

B<Genome::Transcript::NovelVariations>, 

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
