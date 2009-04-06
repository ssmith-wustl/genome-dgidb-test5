package Genome::Model::Tools::Annotate::TranscriptVariantsSimple;

use strict;
use warnings;

use Genome; 

use Command;
use Data::Dumper;
use IO::File;


class Genome::Model::Tools::Annotate::TranscriptVariantsSimple {
    is => 'Command',
    has => [ 
        snv_file => {
            is => 'Text',
            is_optional => 0,
            doc => "File of single-nucleotide variants. Tab separated columns: chromosome_name start stop reference variant type",
        },
    ],
    has_optional => [
        # IO Params
       output_file => {
            is => 'Text',
            is_optional => 1,
            doc => "Store annotation in the specified file instead of sending it to STDOUT."
        },
        no_headers => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => 'Exclude headers in report output',
        },
        # Transcript Params
        multi_gene_annotation => {
            is => 'boolean',
            is_optional => 1,
            default => 1,
            doc => 'If set to true, this will find the top annotation per gene for a given variant and print one line for each. If this is set to false it will find the top annotation between all genes for a given variant and only print a single line per variant.',
        },
        flank_range => {
            is => 'Integer', 
            is_optional => 1,
            default => 50000,
            doc => 'Range to look around for flanking regions of transcripts',
        },
        reference_transcripts => {
            is => 'String',
            is_optional => 1, 
            doc => 'provide name/version number of the reference transcripts set you would like to use ("NCBI-human.combined-annotation/0").  Leaving off the version number will grab the latest version for the transcript set, and leaving off this option and build_id will default to using the latest combined annotation transcript set. Use this or --build-id to specify a non-default annoatation db (not both)'
        },
        build_id =>{
            is => "Number",
            is_optional => 1,
            doc => 'build id for the imported annotation model to grab transcripts to annotate from.  Use this or --reference-transcripts to specify a non-default annotation db (not both)',
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
gt annotate transcript-variants-simple --snv-file snvs.csv --output-file transcript-changes.csv
EOS
}

sub help_detail {
    return <<EOS 
This launches the variant annotator.  It takes genome sequence variants and outputs transcript variants, 
with details on the gravity of the change to the transcript.

The current version presumes that the SNVs are human, and that positions are relative to Hs36.  The transcript data 
set is a mix of Ensembl 45 and Genbank transcripts.  Work is in progress to support newer transcript sets, and 
variants from a different reference.

This is a bare-bones simplified version of the annotation tool which uses the bare minimum inputs required
to produce annotation.

The variant can be an IUB code, in which case every possible variant base will be annotated.

INPUT COLUMNS (TAB SEPARATED)
chromosome_name start stop reference variant type 

Any number of additional columns may be in the input following these columns, but they will be disregarded

OUTPUT COLUMNS (COMMMA SEPARATED)
chromosome_name start stop reference variant type gene_name transcript_name strand trv_type c_position amino_acid_change ucsc_cons domain
EOS
}

############################################################

sub execute { 
    my $self = shift;
    
    # generate an iterator for the input list of SNVs
    my $variant_file = $self->snv_file;

    # TODO: preserve additional columns from input (currently throwing away)
    my $variant_svr = Genome::Utility::IO::SeparatedValueReader->create(
        input => $variant_file,
        headers => [$self->variant_attributes],
        separator => "\t",
        ignore_extra_columns => 1,
    );
    unless ($variant_svr) {
        $self->error_message("error opening file $variant_file");
        return;
    }
    
    # establish the output handle for the transcript variants
    my $output_fh;
    if (my $output_file = $self->output_file) {
        $output_fh = $self->_create_file($output_file);
    }
    else {
        $output_fh = 'STDOUT';
    }
    $self->_transcript_report_fh($output_fh);
    
    #check to see if reference_transcripts set name and build_id given
    if ($self->build and $self->reference_transcripts){
        $self->error_message("Please provide a build id OR a reference transcript set name, not both");
        return;
    }
    
    #if no build is provided, use the v0 of our generic NCBI-human-36 imported annotation model
    unless ($self->build){
        if ($self->reference_transcripts){
            my ($name, $version) = split(/\//, $self->reference_transcripts);
            my $model = Genome::Model->get(name => $name);
            unless ($model){
                $self->error_message("couldn't get reference transcripts set for $name");
                return;
            }
            if ($version){
                my $build = $model->build_by_version($version);
                unless ($build){
                    $self->error_message("couldn't get version $version from reference transcripts set $name");
                    return;
                }
                $self->build($build);
            }else{ 
                my $build = $model->last_complete_build;  #TODO latest by version
                unless ($build){
                    $self->error_message("couldn't get last complete build from reference transcripts set $name");
                    return;
                }
                $self->build($build);
            }
        }else{
            my $model = Genome::Model->get(name => 'NCBI-human.combined-annotation');
            my $build = $model->build_by_version(0);

            unless ($build){
                $self->error_message("couldn't get build v0 from 'NCBI-human.combined-annotation'");
                return;
            }
            $self->build($build);
        }
    }

    # emit headers as necessary
    $output_fh->print( join(',', $self->transcript_report_headers), "\n" ) unless $self->no_headers;

    # annotate all of the input SNVs...
    my $chromosome_name = '';
    my $annotator = undef;
    while ( my $variant = $variant_svr->next ) {
        # make a new annotator when we begin and when we switch chromosomes
        unless ($variant->{chromosome_name} eq $chromosome_name) {
            $chromosome_name = $variant->{chromosome_name};

            my $transcript_iterator = $self->build->transcript_iterator;
            die Genome::Transcript->error_message unless $transcript_iterator;

            my $transcript_window =  Genome::Utility::Window::Transcript->create (
                iterator => $transcript_iterator, 
                range => $self->flank_range
            );
            die Genome::Utility::Window::Transcript->error_message unless $transcript_window;
            $annotator = Genome::Transcript::VariantAnnotator->create(
                transcript_window => $transcript_window 
            );
            die Genome::Transcript::VariantAnnotator->error_message unless $annotator;
        }

        # If we have an IUB code, annotate once per base... doesnt apply to things that arent snps
        if (uc $variant->{type} eq 'SNP') {
            my @variant_alleles = $self->variant_alleles($variant->{reference}, $variant->{variant});
            for my $variant_allele (@variant_alleles) {
                # annotate variant with this allele
                $variant->{variant} = $variant_allele;

                # get the data and output it
                my @transcripts;
                if ($self->multi_gene_annotation) {
                    # Top annotation per gene
                    @transcripts = $annotator->prioritized_transcripts(%$variant);
                } else {
                    # Top annotation between all genes
                    @transcripts = $annotator->prioritized_transcript(%$variant);
                }
                $self->_print_annotation($variant, \@transcripts);
            }
        } else {
            # get the data and output it
            my @transcripts;
            if ($self->multi_gene_annotation) {
                # Top annotation per gene
                @transcripts = $annotator->prioritized_transcripts(%$variant);
            } else {
                # Top annotation between all genes
                @transcripts = $annotator->prioritized_transcript(%$variant);
            }
            $self->_print_annotation($variant, \@transcripts);
        }
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

sub _transcript_report_fh {
    my ($self, $fh) = @_;
    $self->{_transcript_fh} = $fh if $fh;
    return $self->{_transcript_fh};
}

# attributes
sub variant_attributes {
    my $self = shift;
    return (qw/ chromosome_name start stop reference variant type /);
#    return ("chromosome_name start stop reference variant type");
}

sub transcript_attributes {
    my $self = shift;
    return (qw/ gene_name transcript_name strand trv_type c_position amino_acid_change ucsc_cons domain /);
}

sub transcript_report_headers {
    my $self = shift;
    return ($self->variant_attributes, $self->transcript_attributes);
}

sub _print_annotation {
    my ($self, $snp, $transcripts) = @_;

    # Basic SNP Info
    my $snp_info_string = join
    (
        ',', 
        map { $snp->{$_} } $self->variant_attributes,
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
            ), 
            "\n",
        );
    }
    return 1;
}

# Gets the next variant from the snv file, preserves any "extra" columns in an arrayref
sub get_next_variant {
    my $self = shift;


}

# Takes an iub code, translates it, and returns an array of the possible bases that code represents, excludes the reference
sub variant_alleles {
    my ($self, $ref, $iub) = @_;

    my @alleles = $self->iub_to_alleles($iub);
    my @variants = ();
    foreach my $allele (@alleles) {
        if($allele ne $ref) {
            push @variants, $allele;
        }
    }

    return @variants;
}

# Translates an IUB code, returns the bases
sub iub_to_alleles {
    my ($self, $iub) = @_;

    my %IUB_CODE = (
        A => ['A'],
        C => ['C'],
        G => ['G'],
        T => ['T'],
        M => ['A','C'],
        K => ['G','T'],
        Y => ['C','T'],
        R => ['A','G'],
        W => ['A','T'],
        S => ['G','C'],
        D => ['A','G','T'],
        B => ['C','G','T'],
        H => ['A','C','T'],
        V => ['A','C','G'],
        N => ['A','C','G','T'],
    );

    return @{$IUB_CODE{$iub}};
}

1;

=pod

=head1 Name

Genome::Model::Tools::Annotate::TranscriptVariants

=head1 Synopsis

Goes through each variant in a file, retrieving annotation information from Genome::Transcript::VariantAnnotator.

=head1 Usage

 in the shell:

     gt annotate transcript-variants --snv-file myinput.csv --output-file myoutput.csv --metric-summary metrics.csv

 in Perl:

     $success = Genome::Model::Tools::Annotate::TranscriptVariants->execute(
         snv_file => 'myoutput.csv',
         output_file => 'myoutput.csv',
         flank_range => 10000, # default 50000
     );

=head1 Methods

=over

=item snv_file

An input list of single-nucleotide variants.  The format is:
 chromosome_name
 start
 stop 
 reference
 variant
 type

 Any number of additional columns may be in the input, but they will be disregarded.

=item output_file

The list of transcript changes which would occur as a result of the associated genome sequence changes.

One SNV may result in multiple transcript entries if it intersects multiple transcripts.  One 
transcript may occur multiple times in results if multiple SNVs intersect it.

=item summary_file

A one-row csv "table" with some metrics on the SNVs analyzed.

=item 

=back

=head1 See Also

B<Genome::Transcript::VariantAnnotator>, 

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Tools/Annotate/TranscriptVariants.pm $
#$Id: TranscriptVariants.pm 44679 2009-03-16 17:55:52Z adukes $
