package Genome::Model::Command::Report::Variations;

use strict;
use warnings;

use above "Genome"; 

class Genome::Model::Command::Report::Variations
{
    is => 'Command',                       
    has => 
    [ 
    variant_file => 
    {
        type => 'String',
        doc => "?",
        is_optional => 0,
    },
    report_file => 
    {
        type => 'String',
        doc => "?",
        is_optional => 0,
    },
    chromosome_name => 
    {
        type => 'String',
        doc => "?", 
        is_optional => 0,
    },
    #variation_type => 
    #{
    #   type => 'String', 
    #   doc => "?",
    #   is_optional => 0,
    #},
    flank_range => 
    {
        type => 'Integer', 
        doc => "?",
        default => 50000,
        is_optional => 1,
    },
    ], 
};

use Data::Dumper;
use IO::File;
use Genome::DB::Schema;
#use Genome::IndelAnnotator;
use Genome::SnpAnnotator;

sub help_brief {   
    return;
}

sub help_synopsis { 
    return <<EOS
EOS
}

sub help_detail {
    return <<EOS 
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
    
    my $annotator = Genome::SnpAnnotator->new
    (
        transcript_window => $chromosome->transcript_window(range => $self->flank_range),
        variation_window => $chromosome->variation_window(range => 0),
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
            my @non_dbsnp_submitters = join('/', grep { $_ !~ /^dbSNP/ } keys %{ $annotation->{variations} });
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

#$HeadURL$
#$Id$
