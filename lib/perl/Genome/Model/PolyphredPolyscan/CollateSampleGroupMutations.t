#!/usr/bin/env perl

use strict;
use warnings;
#use Test::More tests => 30;
use Test::More skip_all => "SLOOOOOOOOOOOOOOW"; 
use above "Genome";

my $data_path = '/gsc/var/cache/testsuite/data/Genome-Model-PolyphredPolyscan-CollateSampleGroupMutations';

use_ok('Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations');

{
    my $command = Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations->create(
        parser_type => 'Polyscan',
        input_file => $data_path . '/Polyscan.input/TCGA_Production_Set_1-0000199_00n-Ensembl-44_36f.polyscan.high',
        output_path => '/tmp'
    );

    ok($command,'got command object');
    ok($command->execute,'executed command object');
    is($command->result,1,'result is 1');

    ok(-e $command->output_file,'output file exists');
    ok(-s $command->output_file,'output file has size');

    system('sort -gk1 -gk2 -k4 ' . $command->output_file . '>' . $command->output_file . '.sorted');

    my $linecount = 0;
    my $lines = '';

    open(FH, 'diff ' . $data_path . '/Polyscan.sorted_output ' . $command->output_file . '.sorted |');
    while (my $line = <FH>) {
        $linecount++;
        $lines .= $line;
    }
    close FH;

    ok(unlink($command->output_file . '.sorted'),'removed sorted output file');
    ok(unlink($command->output_file),'removed output file');

    is($linecount,0,'zero differences between saved result');
    diag($lines) if $linecount > 0;

    my $command_array = Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations->create(
        parser_type => 'Polyscan',
        input_file => [$data_path . '/Polyscan.input/TCGA_Production_Set_1-0000199_00n-Ensembl-44_36f.polyscan.high'],
        output_path => '/tmp'
    );

    ok($command_array,'got command object with array input_file');
    ok($command_array->execute,'executed command object');
    is($command_array->result,1,'result is 1');

    ok(-e $command_array->output_file,'output file exists');
    ok(-s $command_array->output_file,'output file has size');

    ok(unlink($command_array->output_file),'removed output file');
}

SKIP: {
    eval { require Workflow };
    skip "Workflow not installed", 15 if $@;
    
    my $optype = Workflow::OperationType::Command->get('Genome::Model::PolyphredPolyscan::CollateSampleGroupMutations');
    ok($optype,'got operation type');
    
    my $op = Workflow::Operation->create(
        name => 'collate',
        operation_type => $optype
    );
    ok($op,'got operation');

#    ok($op->parallel_by('input_file'),'set parallel');
    
    {
        my $output;
        my $error = 0;

        ok($op->execute(
            input => {
                parser_type => 'Polyscan',
                input_file => [$data_path . '/Polyscan.input/TCGA_Production_Set_1-0000199_00n-Ensembl-44_36f.polyscan.high'],
                output_path => '/tmp'        
            },
            output_cb => sub {
                $output = shift->output;
            },
            error_cb => sub {
                $error = 1;
            },
            store => Workflow::Store::None->get
        ),'execute');

        ok($op->wait,'wait');
        ok(!$error,'no error');
        ok($output,'has output');
        ok($output->{output_file},'has output file');
        my $output_file = $output->{output_file};

        ok(-e $output_file,'output file exists');
        ok(-s $output_file,'output file has size');

        ok(unlink($output_file),'removed output file');
    }
    
    require Workflow::Simple;
    
    my $output = Workflow::Simple::run_workflow_lsf(
        $op,
        'parser_type' => 'Polyscan',
        'input_file' => [$data_path . '/Polyscan.input/TCGA_Production_Set_1-0000199_00n-Ensembl-44_36f.polyscan.high'],
        'output_path' => '/gscmnt/sata835/info/medseq/temporary_data'
    );
    
    ok($output,'has output');
    ok($output->{output_file},'has output file');
    my $output_file = $output->{output_file};
    ok(-e $output_file,'output file exists');
    ok(-s $output_file,'output file has size');    
    ok(unlink($output_file),'removed output file');

}


