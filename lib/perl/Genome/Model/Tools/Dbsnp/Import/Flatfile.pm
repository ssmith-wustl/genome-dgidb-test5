package Genome::Model::Tools::Dbsnp::Import::Flatfile;

use strict;
use warnings;

use Genome;

use List::AllUtils qw( :all );

class Genome::Model::Tools::Dbsnp::Import::Flatfile {
    is => 'Genome::Model::Tools::Dbsnp::Import',
    has => 
        [
            flatfile => {
                is => 'Path',
                is_input => 1,
                doc => 'Path to the dbsnp flat file',
            },
            output_file => {
                is => 'Path',
                is_output => 1,
                doc => 'File tsv output is written to',
            },
            reference_coordinates => {
                is => 'Text',
                is_input => 1,
                default => 'GRCh37.p2',
                doc => 'reference_coordinates whose coordinates will be used',
            },
        ],
};

sub help_brief {
    'Create formatted tsv from DbSnp flat file'
}

sub help_synopsis {
    return <<EOS
gmt dbsnp import flatfile --flatfile chr1_flatfile.txt --output-file chr1.tsv
EOS
}

sub help_detail {
    return <<EOS
This command is used for importing flat file based DbSnp files.  It creates a .tsv that can be
merged with other such files and created as an ImportedVariationList build.
EOS
}

my %ds_type_conv = ( 'in-del' => 'INDEL',
                  'microsatellite' => 'MICROSATELLITE',
                  'mixed' => 'MIXED',
                  'multinucleotide-polymorphism' => 'MNP',
                  'named-locus' => 'NAMEDLOCUS',
                  'snp' => 'SNP',
                  'heterozygous' => 'HETEROZYGOUS',
                );
my %val_type_conv = ( 'by2Hit2Allele' => 'is_validated_by_allele',
                      'byCluster' => 'is_validated_by_cluster',
                      'byFrequency' => 'is_validated_by_frequency',
                      'byHapMap' => 'is_validated_by_hap_map',
                      'byOtherPop' => 'is_validated_by_other_pop',
                    );
        
my $csv_delimiter = "\t";
my @fd_order = qw(
    ds_chr
    ds_start
    ds_stop
    ds_allele
    ds_id
    ds_type
    submitter
    rs_id
    strain
    is_validated
    is_validated_by_allele
    is_validated_by_cluster
    is_validated_by_frequency
    is_validated_by_hap_map
    is_validated_by_other_pop
);

sub execute {
    my $self = shift;
    my $flatfile_fh = Genome::Sys->open_file_for_reading($self->flatfile);
    if(-e $self->output_file){
        $self->error_message($self->output_file . " already exists, exiting");
        die ($self->error_message);
    }
    my $output_fh = Genome::Sys->open_file_for_writing($self->output_file);

    my @block = ();
    while (<$flatfile_fh>) {
        chomp;
        next if ($. <= 3); # each file has a 3-line header
            my @split_line = split(/\s*\|\s*/, $_);
        if (@split_line == 0) { # blank line
            $self->process_block($output_fh, @block);
            @block = ();
        } else {
            push @block, \@split_line;
        }
    }
    $flatfile_fh->close;
    $output_fh->close;
}

sub process_block {
    # ensure the ss_pick=YES field is first
    my $self = shift;
    my $output_fh = shift;
    my $reference_coordinates = $self->reference_coordinates;

    my @ss = sort { $b->[-1] cmp $a->[-1] } (grep { $_->[0] =~ /^ss/ } @_);
    my @submitters = uniq map { $_->[1] } @ss;
    my ($snp) = grep { $_->[0] eq 'SNP' } @_;
    my ($val) = grep { $_->[0] eq 'VAL' } @_;
    my @ctgs = grep { $_->[0] eq 'CTG' && $_->[1] eq "assembly=$reference_coordinates" } @_;
    
    my %record = ('ds_id'        => 0,
                  'rs_id'        => $_[0][0],
                  'ds_type'      => $ds_type_conv{$_[0][3]},
                  'is_validated' => ($val->[1] eq 'validated=YES') || 0,
                  'is_validated_by_allele'    => 0,
                  'is_validated_by_cluster'   => 0,
                  'is_validated_by_frequency' => 0,
                  'is_validated_by_hap_map'   => 0,
                  'is_validated_by_other_pop' => 0,
    );


    my ($alleles) = ($snp->[1] =~ /alleles=\'(.*)\'/);
    my @ref_var = split('/', $alleles);
    
    ($record{'ds_allele'}) = ($snp->[1] =~ /alleles=\'(.*)\'/);

    if ($record{'is_validated'}){
        for my $val_type (@$val[5..$#$val]){
            $record{$val_type_conv{$val_type}} = 1;
        }
    }
    
    for my $ctg (@ctgs){
        ($record{'strain'}) = ($ctg->[8] =~ /orient=([-\+])/) or next;
        ($record{'ds_chr'}) = ($ctg->[2] =~ /chr=(.*)/) or next;
        my ($chr_pos)   = ($ctg->[3] =~ /chr-pos=(\d+)/) or next;
        my ($ctg_start) = ($ctg->[5] =~ /ctg-start=(\d+)/) or next;
        my ($ctg_end)   = ($ctg->[6] =~ /ctg-end=(\d+)/) or next;
        my ($loctype)   = ($ctg->[7] =~ /loctype=(\d)/) or next;

        $record{'ds_start'} = $chr_pos-1;
        $record{'ds_stop'}  = $chr_pos + ($ctg_end - $ctg_start);
        
        for my $sub (@submitters){
            $record{'submitter'} = $sub;
            my @vals = map { $record{$_} } @fd_order;
            print $output_fh join($csv_delimiter,@vals), "\n"; 
        }
    }
}

1;
