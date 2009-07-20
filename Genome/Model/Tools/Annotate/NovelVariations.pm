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
            is_input => 1,
            doc => "File of variants.  Tab separated columns: chromosome_name start stop reference variant",
        },
        output_file => {
            type => 'Text',
            default => "STDOUT",
            is_input => 1,
            is_output => 1,
            doc => "Store annotation in the specified file instead of sending it to STDOUT."
        },
    ],
    has_optional => [
        report_mode => {
            type => 'Text',
            is_input => 1,
            default => 'all',
            doc => '(DEFAULT VALUE) If set to "all", output every input variant and the (variant database, version, and list of submitter_names) of previously found variations if they were found. These columns will be blank if no variations were found for the given line of input.
            If set to "novel-only", the output will contain only variants that were NOT found previously in dbSNP. Output will be the ORIGINAL LINE of input if the variant was NOT previously found. If the variant was previously found, no output will be given for that variant.
            If set to "known-only", the output will contain only variants that WERE found previously in dbSNP. Output will be the ORIGINAL LINE of input if the variant WAS previously found. If the variant was not previously found, no output will be given for that variant.',
        },
        no_headers => {
            type => 'Boolean',
            is_input => 1,
            default => 0,
            doc => 'Exclude headers in report output',
        },
        # Variation Params
        indel_range => {
           type => 'Integer',
           default => 0,
           doc => 'Range to look around an indel for known variations... does not apply to snps',
        },
        submitter_filter => {
            type => 'Text',
            doc => 'Comma separated (no spaces allowed) list of submitters to consider from dbsnp. Results will only include submitters mentioned. Default is no filter.',
        },
        submitter_filter_not => {
            type => 'Text',
            is_input => 1,
            doc => 'Comma separated (no spaces allowed) list of submitters to IGNORE from dbsnp. Results will only include submitters not mentioned. Default is no filter.',
        },
        build => {
            is => "Genome::Model::Build",
            id_by => 'build_id',
        },
        build_id => {
            is => "Integer",
            doc => 'Build id of imported variations to use. Currently defaults to use DBsnp 130.',
        },
    ],
};

############################################################


sub help_synopsis { 
    return <<EOS
gt annotate novel-variations --variant-file snvs.csv --output-file transcript-changes.csv --submitter-filter HUMANGENOME_JCVI,1000GENOMES --report-mode novel-only
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

    # FIXME shortcutting... should we do this or not post-testing?
    if (-s $self->output_file) {
        $self->status_message("Previous output detected, shortcutting");
        return 1;
    }

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
    
    # establish the output handle for the transcript variants
    my $output_fh;
    my $output_file = $self->output_file;
    if ($self->output_file =~ /STDOUT/i) {
        $output_fh = 'STDOUT';
    }
    else {
        $output_fh = $self->_create_file($output_file);
    }
    $self->_variation_report_fh($output_fh);
    
    #if no build is provided, use dbSNP 130
    unless ($self->build){
        my $model = Genome::Model->get(name => 'dbSNP.imported-variations');
        my $build = $model->build_by_version(130);

        unless ($build){
            $self->error_message("couldn't get build 130 from 'dbSNP.imported-variations'");
            return;
        }
        $self->build($build);
    }
    
    $output_fh->print( join("\t", $self->variation_report_headers), "\n" ) unless ($self->no_headers);
    
    my $chromosome_name = '';
    my $variation_window = undef;

    while ( my $variant = $variant_svr->next ) {

        # make a new annotator when we begin and when we switch chromosomes
        if ($variant->{chromosome_name} ne $chromosome_name) {
            $chromosome_name = $variant->{chromosome_name};
            $self->status_message("generating overlap iterator for $chromosome_name");
            
            # Apply the filter on submitters if necessary
            my $variation_iterator;
            if (($self->submitter_filter)&&($self->submitter_filter_not)) {
                $self->error_message("Specifying both submitter-filter and submitter-filter-not is not allowed (or even logical)... so DONT.");
                die;
            } elsif ($self->submitter_filter) {
                my @valid_submitters = split (",", $self->submitter_filter);
                $variation_iterator = $self->build->variation_iterator(
                    chrom_name => $chromosome_name,
                    submitter_name => \@valid_submitters,
                );
            } elsif ($self->submitter_filter_not) {
                my @invalid_submitters = split (",", $self->submitter_filter_not);
                $variation_iterator = $self->build->variation_iterator(
                    chrom_name => $chromosome_name,
                    submitter_name => { operator => 'not in', value => \@invalid_submitters},
                );
            } else {
                $variation_iterator = $self->build->variation_iterator(
                    chrom_name => $chromosome_name,
                );
            }
            $variation_window =  Genome::Utility::Window::Variation->create( 
                iterator => $variation_iterator,
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
        # If we are only printing previously unknown variations, check to see if it is novel before printing 
        # Otherwise print a line with our findings regardless

        # If in "include only dbsnp concordance" mode, output if we found variations in dbsnp
        if ($self->report_mode eq 'known-only') {
            if (scalar(@valid_variations >= 1)) {
                $output_fh->print($variant_svr->{current_line});
            }    
        # If in "include only novel variations" mode, output if we didnt find variations in dbsnp
        } elsif ($self->report_mode eq 'novel-only') {
            if (scalar(@valid_variations < 1)) {
                $output_fh->print($variant_svr->{current_line});
            }    
        } elsif ($self->report_mode eq 'all') {
            $self->_print_reports_for_snp($variant, \@valid_variations);
        } else {
            $self->error_message("Invalid value for exclude-known-variations: " . $self->report_mode);
            die;
        }
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
            #$self->warning_message("Junk data from data source (SNP with start and stop not equal?). Variation is: " . Dumper $variation);
        # We do not really know what these are right now, but they are present in the data, so skip.
        } elsif ($type =~ /NAMED-LOCUS/i) {
            return 0;
        } else {
            $self->warning_message("Variation from data source has type $type, which is not supported. Variation is: " . Dumper $variation);
        }
    }

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
    return qw(database version submitter_name);
}

#- PRINT REPORTS -#
sub _print_reports_for_snp {

    my ($self, $variant, $variations) = @_;

    # Basic SNP Info
    my $variant_info_string =
        join( "\t", map { $variant->{$_} } $self->variant_attributes );
    my @variation_strings;

    for my $variation (@$variations) {

        my $variation_info_string =
            join( "\t", map { $variation->{$_} } $self->variation_attributes );

        push @variation_strings, join("\t", $variant_info_string, $variation_info_string);
    }

    if (! @variation_strings) {
        push @variation_strings, "$variant_info_string\t\t\t";
    }

    $self->_variation_report_fh->print(join("\n",@variation_strings) . "\n");

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
