package Genome::Model::Command::Report::Variations;

use strict;
use warnings;

use above "Genome"; 

use Data::Dumper;
use IO::File;
use Genome::DB::Schema;
#use Genome::IndelAnnotator;
use Genome::SnpAnnotator;
use Tie::File;

class Genome::Model::Command::Report::Variations
{
    is => 'Command',                       
    has => 
    [ 
    variant_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File of variants",
    },
    report_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File to put annotations",
    },
    chromosome_name => 
    {
        type => 'String',
        is_optional => 0,
        doc => "Name of the chromosome AKA ref_seq_id", 
    },
    variation_type => 
    {
       type => 'String', 
       is_optional => 1,
       doc => "Type of variation: snp, indel",
       default => 'snp',
    },
    flank_range => 
    {
        type => 'Integer', 
        is_optional => 1,
        default => 50000,
        doc => "Range to look around for flaking regions of transcripts",
    },
    variation_range => 
    {
       type => 'Integer', 
       is_optional => 0,
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
    Creates an annotation report for variants in a given file.  Uses Genome::SnpAnnotator or Genome::IndelAnnotator (coming soon!) for each given variant, and outputs the annotation infomation to the given report file.
EOS
}

sub execute { 
    my $self = shift;

    my $input = $self->variant_file;
    my $in_fh = IO::File->new("< $input");
    $self->error_message("Can't open variation file ($input) for reading: $!")
        and return unless $in_fh;
    
    my $output = $self->report_file;
    unlink $output if -e $output;
    my $out_fh = IO::File->new("> $output");
    $self->error_message("Can't open report file ($output) for writing: $!")
        and return unless $out_fh;

    my $schema = Genome::DB::Schema->connect_to_dwrac;
    $self->error_message("Can't connect to dwrac")
        and return unless $schema;
    
    my $chromosome_name = $self->chromosome_name;
    my $chromosome = $schema->resultset('Chromosome')->find
    (
        { chromosome_name => $chromosome_name },
    );
    $self->error_message("Can't find chromosome ($chromosome_name)")
        and return unless $chromosome;
    
    tie my @variants, 'Tie::File', $input;
    my $from = ( split(/\s+/, $variants[0]) )[1];
    my $to = ( split(/\s+/, $variants[$#variants]) )[1];
    untie @variants;
    undef @variants;

    my $annotator = Genome::SnpAnnotator->new
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

    while ( my $line = $in_fh->getline )
    {
        my (
            $chromosome_name, $start, $stop, $reference, $variant, 
            $reference_type, $variant_type, $reference_reads, $variant_reads,
            $consensus_quality, $read_count
        ) = split(/\s+/, $line);

        my @annotations = $annotator->get_prioritized_annotations # TODO param whether or not we do prioritized annos?
        (
            position => $start,
            reference => $reference,
            variant => $variant,
        )
            or next;
        
        foreach my $annotation ( @annotations )
        {
            my @non_dbsnp_submitters = grep { $_ !~ /dbsnp|old|none/i } keys %{ $annotation->{variations} };
            my $wv = ( @non_dbsnp_submitters )
            ? join('/', @non_dbsnp_submitters)
            : 0;

            $out_fh->print
            (
                join
                (
                    ',',                   
                    ( exists $annotation->{variations}->{'dbSNP-127'} ? 1 : 0), # dbsnp
                    $annotation->{gene_name},
                    $chromosome_name,
                    $start,
                    $stop,
                    $variant, 
                    $variant_reads, # num of genomic reads supporting variant allele",
                    '0', # # of cdna reads supporting variant allele",
                    $reference,
                    $reference_reads, # num of genomic reads supporting reference allele",
                    '0', # # of cdna reads supporting reference allele",
                    $annotation->{intensity},
                    $annotation->{detection},
                    $annotation->{transcript_name}, # ensembl_transcript_id",
                    $annotation->{strand}, # transcript_stranding",
                    $annotation->{trv_type}, 
                    $annotation->{c_position}, # transcript_position",
                    $annotation->{amino_acid_change} || 'NULL', # amino_acid_change", 
                    'NULL', # polyphen_prediction",
                    0, # submit
                    '', # rgg_id
                    $wv, # watson/ventor
                ), 
                "\n",
            );
        }
    }

    $in_fh->close;
    $out_fh->close;

    return 1;
}

1;

=pod

=head1 Name

Genome::Model::Command::Report::Variations

=head1 Synopsis

Goes through each variant in a file, retrieving annotation information from Genome::SnpAnnotator or Genome::IndelAnnotator (coming soon).

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

B<Genome::SnpAnnotator>, B<Genome::Model::Command::Report::VariationsBatchToLsf>, B<Genome::DB::*>, B<Genome::DB::Window::*>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
