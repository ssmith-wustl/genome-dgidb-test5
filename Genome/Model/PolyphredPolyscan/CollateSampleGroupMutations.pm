package Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations;
#:adukes this is pretty ugly/hacked for an emergency, CombineVariants/PolyphredPolyscan and the supporting infrastructure should go through a serious reevaluation before it is attempted to be updated or rerun.

use strict;
use warnings;

use MG::IO::Polyphred;
use MG::IO::Polyscan;
use File::Temp;

class Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations {
    is => ['Command'],
    has => [
        combined_input_columns => {
            is => 'ARRAY',
            value => [qw(
                initialized
                in
                create
            )]
        }
    ],
    has_input => [
        parser_type => { 
            is => 'String', 
            doc => 'must by Polyphred or Polyscan' 
        },
        input_file => {
            is => 'String',
        },
        output_path => {
            is => 'String',
        }
    ],
    has_output => [
        output_file => { 
            is => 'String', 
            is_optional => 1, 
            doc => 'tab delimited output file' 
        }
    ],
};

sub create {
    my $self = shift->SUPER::create(@_);

    my @a = Genome::Model::PolyphredPolyscan->combined_input_columns();

    $self->combined_input_columns(\@a);


    return $self;
}

sub execute {
    my $self = shift;

    my @input_files;
    if (ref($self->input_file) eq 'ARRAY') {
        @input_files = @{ $self->input_file };
    } else {
        @input_files = ($self->input_file);
    }

    my $type = $self->parser_type;
    my ($fh, $output_filename) = File::Temp::tempfile('collate_csv_XXXXXXXX', DIR => $self->output_path, UNLINK => 0);
    $self->output_file($output_filename);

    # Create parsers for each file, append to running lists
    for my $file (@input_files) {
        #my ($cluster_name, $chromosome, $begin_position, $end_position) = $file =~ /\/(([^\/_]+)_(\d+)_(\d+))\.poly(scan|phred)\.(low|high)$/;
        my ($cluster_name, $chromosome, $begin_position, $end_position) = $file =~ /\/(([^\/_]+)_(\d+)_(\d+))\.evaluate_sequence_variation/;
        my $param = lc($type);
        my $module = "MG::IO::$type";

        # TODO TODO TODO FIXME FIXME FIXME TODO FIXME hardcoded goodness
        my $assemblies_dump_dir = '/gscmnt/sata820/info/medseq/tcga_assemblies/';
        my $cluster_path = $assemblies_dump_dir.$cluster_name."/";
        my $fasta_file = "$cluster_path/edit_dir/$cluster_name.c1.refseq.fasta";
        my $parser = $module->new($param => $file,
                                  chromosome => $chromosome,
                                  begin_position => $begin_position,
                                  end_position => $end_position,
                                  fasta => $fasta_file,
                                 );
        my ($snps, $indels) = $parser->collate_sample_group_mutations;

        # Print all of the snps and indels to the combined input file
        for my $variant (@$snps, @$indels) {
            $fh->print( join("\t", map{$variant->{$_} } @{ $self->combined_input_columns } ) );
            $fh->print("\n");
        }
    }
    $fh->close;

    return 1;
}
 
1;
