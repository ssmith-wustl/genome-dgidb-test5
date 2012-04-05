package Genome::Model::RnaSeq::DetectFusionsResult::ChimerascanResult::Index;

use strict;
use warnings;

use Genome;

class Genome::Model::RnaSeq::DetectFusionsResult::ChimerascanResult::Index {
    is => 'Genome::Model::RnaSeq::DetectFusionsResult::Index::Base',
    has_param => [
        version => {
            is => 'Text',
            doc => 'the version of chimerascan to use to make the index',
        },
        bowtie_version => {
            is => 'Text',
            doc => 'the version of bowtie to use to make the index',
        },
    ],
    has_calculated => [
        gene_file => {
            is => 'Text',
            is_optional => 1,
            calculate => sub { $_[0] . "/gene_file";},
            calculate_from => [ "temp_staging_directory" ],
        },
    ],

    doc => 'This holds the bowtie indices and modified FASTA required to run chimerascan',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_) or return;

    $self->_prepare_staging_directory;

    $self->prepare_gene_file;
    $self->run_indexer;

    $self->_prepare_output_directory;
    $self->_promote_data;
    $self->_reallocate_disk_allocation;

    return $self;
}

sub resolve_allocation_subdirectory {
    my $self = shift;
    return 'build_merged_alignments/chimerascan-index/' . $self->id;
}

#rumour has it future versions of chimerascan will support different formats for this
sub prepare_gene_file {
    my $self = shift;
    for(qw(knownGene.txt.gz kgXref.txt.gz)){
        $self->_download_ucsc_table($_, $self->temp_staging_directory);
    }

    my $known_gene_file = $self->temp_staging_directory . "/knownGene.txt";
    my $kgXref_file = $self->temp_staging_directory . "/kgXref.txt";

    my $joined_output = $self->temp_staging_directory . "/gene_file";

    my $cmd = qq{bash -c "join -t\$'\t' -j1 -o1.1,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,2.3  <(sort $known_gene_file) <(sort $kgXref_file) | grep -v '	\$' > $joined_output"};

    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$known_gene_file, $kgXref_file],
        output_files => [$joined_output]
    );

    unlink($known_gene_file, $kgXref_file);

    return 1;
}

sub run_indexer {
    my $self = shift;
    my $fasta = $self->reference_build->full_consensus_path('fa');
    my $gene_file = $self->gene_file;
    my $output_dir = $self->temp_staging_directory;
    (my $bowtie_dir =  Genome::Model::Tools::Bowtie->path_for_bowtie_version($self->bowtie_version)) =~  s/\/bowtie$//;
    my $cmd_path = Genome::Model::RnaSeq::DetectFusionsResult::ChimerascanResult->_path_for_version($self->version);

    my $cmd = "python $cmd_path/chimerascan_index.py --bowtie-dir=$bowtie_dir $fasta $gene_file $output_dir";

    local $ENV{PYTHONPATH} =  ($ENV{PYTHONPATH} ? $ENV{PYTHONPATH} . ":" : "")  .
        Genome::Model::RnaSeq::DetectFusionsResult::ChimerascanResult->_python_path_for_version($self->version);

    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$fasta, $gene_file],

    );

}

1;
